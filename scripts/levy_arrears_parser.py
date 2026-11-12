#!/usr/bin/env python3
"""Extract open levy items from an Urbanise levy statement PDF.

The parser reads the positioned text in the standard Urbanise statement layout,
replays debits and credits within each fund, categorises the remaining items,
validates them against the statement's closing balances, and emits SQL Server
INSERT statements.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import deque
from dataclasses import dataclass, field
from datetime import datetime
from decimal import Decimal
from pathlib import Path
from typing import Iterable

import pdfplumber


MONEY = re.compile(r"^-?\d[\d,]*\.\d{2}$")
DATE = re.compile(r"^\d{2}-\d{2}-\d{2}$")
ZERO = Decimal("0.00")


@dataclass
class Transaction:
    due_date: str | None
    description: str
    levy_start_date: str | None = None
    levy_end_date: str | None = None
    admin: Decimal | None = None
    admin_penalty: Decimal | None = None
    maintenance: Decimal | None = None
    maintenance_penalty: Decimal | None = None


@dataclass
class OpenItem:
    due_date: str | None
    levy_type: str
    category: str
    amount: Decimal
    levy_start_date: str | None = None
    levy_end_date: str | None = None


@dataclass
class FundState:
    open_items: deque[OpenItem] = field(default_factory=deque)
    credit: Decimal = ZERO

    def add_debit(self, item: OpenItem) -> None:
        amount = item.amount
        if self.credit:
            applied = min(amount, self.credit)
            amount -= applied
            self.credit -= applied
        if amount:
            item.amount = amount
            self.open_items.append(item)

    def add_credit(self, amount: Decimal, category: str | None = None) -> None:
        # A waiver/reversal should cancel the newest matching charge first.
        if category:
            for item in reversed(self.open_items):
                if item.category == category and amount:
                    applied = min(item.amount, amount)
                    item.amount -= applied
                    amount -= applied
            self.open_items = deque(i for i in self.open_items if i.amount)

        # Ordinary payments and any remainder are applied oldest-first.
        while amount and self.open_items:
            item = self.open_items[0]
            applied = min(item.amount, amount)
            item.amount -= applied
            amount -= applied
            if not item.amount:
                self.open_items.popleft()
        self.credit += amount


def money(text: str) -> Decimal:
    return Decimal(text.replace(",", ""))


def parse_date(text: str | None) -> str | None:
    if not text:
        return None
    return datetime.strptime(text, "%d-%m-%y").date().isoformat()


def document_pages(document) -> list:
    """Return pages from either a pdfplumber PDF or an in-memory page list."""
    return document.pages if hasattr(document, "pages") else list(document)


def statement_start_date(document) -> str:
    pages = document_pages(document)
    first_page_text = pages[0].extract_text() or ""
    match = re.search(
        r"For the period\s+(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\s+to\s+",
        first_page_text,
        re.IGNORECASE,
    )
    if not match:
        raise ValueError("Could not locate the statement period start date.")
    return datetime.strptime(match.group(1), "%d %b %Y").date().isoformat()


def parse_period(text: str) -> tuple[str | None, str | None]:
    match = re.search(
        r"(\d{2}-\d{2}-\d{2})\s+to\s+(\d{2}-\d{2}-\d{2})",
        text,
        re.IGNORECASE,
    )
    if not match:
        return None, None
    return parse_date(match.group(1)), parse_date(match.group(2))


def group_lines(words: list[dict], tolerance: float = 1.6) -> list[list[dict]]:
    lines: list[list[dict]] = []
    for word in sorted(words, key=lambda w: (w["top"], w["x0"])):
        if not lines or abs(word["top"] - lines[-1][0]["top"]) > tolerance:
            lines.append([word])
        else:
            lines[-1].append(word)
    return [sorted(line, key=lambda w: w["x0"]) for line in lines]


def text_in(words: Iterable[dict], left: float, right: float) -> str:
    return " ".join(w["text"] for w in words if left <= w["_x"] < right)


def amount_in(words: Iterable[dict], left: float, right: float) -> Decimal | None:
    # Monetary values are right-aligned. Use the right edge so large values
    # (for example 21,870.96) remain in the correct fund column even when
    # their left edge extends beyond the nominal column boundary.
    candidates = [
        w["text"]
        for w in words
        if left <= w["_x1"] < right and MONEY.match(w["text"])
    ]
    return money(candidates[-1]) if candidates else None


def extract_transactions(document) -> list[Transaction]:
    transactions: list[Transaction] = []
    current: Transaction | None = None
    pages = document_pages(document)
    report_start = statement_start_date(pages)

    for page in pages:
        words = page.extract_words(x_tolerance=1, y_tolerance=2)
        for word in words:
            scale = 842.0 / page.width
            word["_x"] = word["x0"] * scale
            word["_x1"] = word["x1"] * scale

        body = [
            w for w in words
            if 145 <= w["top"] * (595.0 / page.height) <= 555
        ]
        for line in group_lines(body):
            full = " ".join(w["text"] for w in line)
            if "Balance of account as at" in full:
                current = None
                break

            left_dates = [
                w for w in line
                if w["_x"] < 200 and DATE.match(w["text"])
            ]
            description = text_in(line, 205, 340).strip()
            is_brought_forward = description.lower() == "brought forward"
            starts_transaction = bool(left_dates) or is_brought_forward

            if starts_transaction:
                due = next(
                    (w["text"] for w in line if w["_x"] < 55 and DATE.match(w["text"])),
                    None,
                )
                transaction_date = next(
                    (w["text"] for w in line if w["_x"] < 200 and DATE.match(w["text"])),
                    None,
                )
                levy_start_date, levy_end_date = parse_period(text_in(line, 340, 440))
                current = Transaction(
                    due_date=(
                        report_start
                        if is_brought_forward
                        else parse_date(due or transaction_date)
                    ),
                    description=description,
                    levy_start_date=levy_start_date,
                    levy_end_date=levy_end_date,
                    admin=amount_in(line, 440, 500),
                    admin_penalty=amount_in(line, 500, 560),
                    maintenance=amount_in(line, 560, 625),
                    maintenance_penalty=amount_in(line, 625, 690),
                )
                transactions.append(current)
            elif current:
                continuation = text_in(line, 205, 340).strip()
                if continuation and not continuation.lower().startswith(("levy statement", "printed")):
                    current.description = f"{current.description} {continuation}".strip()

    return transactions


def category_for(description: str) -> str:
    value = description.lower()
    if value == "brought forward":
        return "Regular"
    if "penalty" in value and "debt recovery" not in value:
        return "Interest"
    if "debt recovery" in value:
        return "DR charge"
    if "special" in value or "capital work" in value:
        return "Special"
    if "sub meter" in value or "sub-meter" in value or "metering" in value:
        return "Sub metering"
    if "levies - normal" in value or "levy - normal" in value:
        return "Regular"
    return "Owner invoice"


def clean_levy_type(description: str) -> str:
    value = re.sub(r"\s+", " ", description).strip()
    return "Brought forward" if value.lower() == "brought forward" else value


def is_reversal(description: str) -> bool:
    value = description.lower()
    return any(word in value for word in ("waive", "waiver", "reverse", "reversal", "refund"))


def replay(transactions: list[Transaction]) -> dict[str, FundState]:
    states = {
        "Administration": FundState(),
        "Administration penalty": FundState(),
        "Maintenance": FundState(),
        "Maintenance penalty": FundState(),
    }
    fields = (
        ("Administration", "admin"),
        ("Administration penalty", "admin_penalty"),
        ("Maintenance", "maintenance"),
        ("Maintenance penalty", "maintenance_penalty"),
    )

    for tx in transactions:
        description_category = category_for(tx.description)
        description_levy_type = clean_levy_type(tx.description)
        for fund_name, attr in fields:
            value = getattr(tx, attr)
            if value is None or value == ZERO:
                continue
            state = states[fund_name]
            is_penalty_fund = fund_name.endswith(" penalty")
            category = "Interest" if is_penalty_fund else description_category
            levy_type = (
                "Overdue interest" if is_penalty_fund else description_levy_type
            )
            if value < ZERO:
                state.add_debit(
                    OpenItem(
                        tx.due_date,
                        levy_type,
                        category,
                        -value,
                        tx.levy_start_date,
                        tx.levy_end_date,
                    )
                )
            else:
                matched_category = category if is_reversal(tx.description) else None
                state.add_credit(value, matched_category)
    return states


def extract_identity_and_balances(document) -> tuple[str, str, dict[str, Decimal]]:
    pages = document_pages(document)
    first = pages[0].extract_text() or ""
    last = pages[-1].extract_text() or ""

    plan_match = re.search(r"Plan No\.\s+([A-Za-z0-9]+)", first)
    lot_match = re.search(r"LEVY STATEMENT\s*-\s*(\S+)", first)
    balance_match = re.search(
        r"Balance of account as at .*?\$\s+"
        r"(-?[\d,]+\.\d{2})\s+(-?[\d,]+\.\d{2})\s+"
        r"(-?[\d,]+\.\d{2})\s+(-?[\d,]+\.\d{2})\s+"
        r"(-?[\d,]+\.\d{2})\s+(-?[\d,]+\.\d{2})",
        last,
    )
    if not plan_match or not lot_match or not balance_match:
        raise ValueError("Could not locate the plan, lot, or closing balance row.")

    values = [money(value) for value in balance_match.groups()]
    balances = {
        "Administration": values[0],
        "Administration penalty": values[1],
        "Maintenance": values[2],
        "Maintenance penalty": values[3],
    }
    return plan_match.group(1), lot_match.group(1), balances


def validate(states: dict[str, FundState], balances: dict[str, Decimal]) -> None:
    errors = []
    for fund, closing_balance in balances.items():
        parsed_arrears = sum((item.amount for item in states[fund].open_items), ZERO)
        parsed_balance = states[fund].credit - parsed_arrears
        if parsed_balance != closing_balance:
            errors.append(
                f"{fund}: parsed balance {parsed_balance:.2f}, "
                f"statement balance {closing_balance:.2f}"
            )
    if errors:
        raise ValueError("Allocation did not reconcile:\n  " + "\n  ".join(errors))


def group_pages_by_lot(pdf: pdfplumber.PDF) -> list[tuple[str, list]]:
    """Split a single- or multi-lot PDF into contiguous in-memory lot groups."""
    groups: list[tuple[str, list]] = []
    seen: set[str] = set()

    for page_number, page in enumerate(pdf.pages, 1):
        text = page.extract_text() or ""
        match = re.search(r"LEVY STATEMENT\s*-\s*(\S+)", text)
        if not match:
            raise ValueError(f"Could not locate a lot number on page {page_number}.")
        lot = match.group(1)

        if groups and groups[-1][0] == lot:
            groups[-1][1].append(page)
            continue
        if lot in seen:
            raise ValueError(f"Lot {lot} appears in multiple non-contiguous sections.")
        seen.add(lot)
        groups.append((lot, [page]))

    return groups


def sql_string(value: str) -> str:
    return "N'" + value.replace("'", "''") + "'"


def sql_date(value: str | None) -> str:
    return f"CONVERT(date, '{value}', 23)" if value else "NULL"


def generate_sql(
    table: str,
    plan: str,
    lot: str,
    states: dict[str, FundState],
) -> str:
    rows: list[str] = []
    for state_name in (
        "Administration",
        "Administration penalty",
        "Maintenance",
        "Maintenance penalty",
    ):
        output_fund = "Administration" if state_name.startswith("Administration") else "Maintenance"
        for item in states[state_name].open_items:
            if not item.due_date:
                raise ValueError(f"Open item has no due date: {item.levy_type}")
            rows.append(
                "    ("
                + ", ".join(
                    (
                        sql_string(plan),
                        sql_string(lot),
                        sql_string(output_fund),
                        sql_string(item.levy_type),
                        sql_string(item.category),
                        sql_date(item.due_date),
                        sql_date(item.levy_start_date),
                        sql_date(item.levy_end_date),
                        f"CAST({item.amount:.2f} AS decimal(18,2))",
                    )
                )
                + ")"
            )
    if not rows:
        return f"-- {plan} / Lot {lot}: no outstanding levy items.\n"

    return (
        f"INSERT INTO {table}\n"
        "(\n"
        "    PlanNumber, LotNumber, Fund, [Levy type],\n"
        "    [Levy category], [Due date], LevyStartDate, LevyEndDate, Outstanding\n"
        ")\nVALUES\n"
        + ",\n".join(rows)
        + ";\n"
    )


def print_summary(plan: str, lot: str, states: dict[str, FundState]) -> None:
    print(f"Plan {plan} / Lot {lot}")
    print("Fund\tCategory\tDue date\tLevy start\tLevy end\tOutstanding\tLevy type")
    total = ZERO
    for state_name, state in states.items():
        output_fund = "Administration" if state_name.startswith("Administration") else "Maintenance"
        for item in state.open_items:
            total += item.amount
            print(
                f"{output_fund}\t{item.category}\t{item.due_date or ''}\t"
                f"{item.levy_start_date or ''}\t{item.levy_end_date or ''}\t"
                f"{item.amount:.2f}\t{item.levy_type}"
            )
    print(f"Total\t\t\t\t\t{total:.2f}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Allocate Urbanise levy arrears by levy type and generate SQL inserts."
    )
    parser.add_argument("pdf", type=Path, help="Urbanise levy statement PDF")
    parser.add_argument(
        "--table",
        default="[AboveOCM_Local_Test].[dbo].[URBANISE_LevyArrearsByLevyType]",
        help="SQL Server destination table",
    )
    parser.add_argument(
        "--sql-output",
        type=Path,
        help=(
            "Write SQL to this file. By default, the SQL file is created beside "
            "the input PDF with the same base filename."
        ),
    )
    args = parser.parse_args()

    try:
        with pdfplumber.open(args.pdf) as pdf:
            lot_groups = group_pages_by_lot(pdf)
            sql_sections: list[str] = []
            total_rows = 0
            lots_with_arrears = 0
            combined_outstanding = ZERO

            for detected_lot, pages in lot_groups:
                plan, lot, balances = extract_identity_and_balances(pages)
                if lot != detected_lot:
                    raise ValueError(
                        f"Lot boundary mismatch: detected {detected_lot}, parsed {lot}."
                    )
                transactions = extract_transactions(pages)
                states = replay(transactions)
                validate(states, balances)

                items = [item for state in states.values() for item in state.open_items]
                if items:
                    lots_with_arrears += 1
                    total_rows += len(items)
                    combined_outstanding += sum((item.amount for item in items), ZERO)
                    print_summary(plan, lot, states)
                    sql_sections.append(
                        f"-- {plan} / Lot {lot}\n"
                        + generate_sql(args.table, plan, lot, states)
                    )
                else:
                    print(f"Plan {plan} / Lot {lot}: no outstanding levy items")
                    sql_sections.append(
                        f"-- {plan} / Lot {lot}: no outstanding levy items.\n"
                    )

        sql = "\n".join(sql_sections)
        print(
            f"\nProcessed {len(lot_groups)} lot(s); "
            f"{lots_with_arrears} with fund-level arrears; "
            f"{total_rows} SQL row(s); total ${combined_outstanding:.2f}."
        )
        sql_output = args.sql_output or args.pdf.with_suffix(".sql")
        sql_output.write_text(sql, encoding="utf-8")
        print(f"SQL written to: {sql_output}")
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
