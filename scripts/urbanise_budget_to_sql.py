"""Convert an Urbanise annual-budget PDF into normalized SQL INSERT rows.

Usage:
    python urbanise_budget_to_sql.py "budget.pdf"
    python urbanise_budget_to_sql.py "budget.pdf" --output "budget.sql"

The generated rows target dbo.URBANISE_Budge_Details_INTERIM.
"""

from __future__ import annotations

import argparse
import calendar
import re
from dataclasses import dataclass
from datetime import datetime
from decimal import Decimal
from pathlib import Path

import pdfplumber


TABLE_NAME = "[AboveOCM_Local_Test].[dbo].[URBANISE_Budge_Details_INTERIM]"
FUND_PATTERN = re.compile(
    r"^(Administrative Fund|Capital Works Fund|Maintenance Fund)$",
    re.MULTILINE,
)
MONEY_TOKEN = r"(?:-|\(?[\d,]+\.\d{2}\)?|\(?\d+\)?)"
PERIOD_TOKEN = re.compile(r"\b\d{2}/\d{2}\s*-\s*\d{2}/\d{2}\b")
ROW_WITH_VARIANCE = re.compile(
    rf"^(?P<account>.+?)\s+"
    rf"(?P<actual>{MONEY_TOKEN})\s+"
    rf"(?P<previous>{MONEY_TOKEN})\s+"
    rf"(?P<current>{MONEY_TOKEN})\s+"
    rf"(?P<variance>{MONEY_TOKEN})$"
)
ROW_WITHOUT_VARIANCE = re.compile(
    rf"^(?P<account>.+?)\s+"
    rf"(?P<actual>{MONEY_TOKEN})\s+"
    rf"(?P<previous>{MONEY_TOKEN})\s+"
    rf"(?P<current>{MONEY_TOKEN})$"
)
ROW_SINGLE_BUDGET = re.compile(
    rf"^(?P<account>.+?)\s+(?P<current>{MONEY_TOKEN})$"
)


@dataclass(frozen=True)
class BudgetRow:
    plan_number: str
    fund_name: str
    account_name: str
    account_type: str
    budget_end_date: str
    amount: Decimal


def money(value: str) -> Decimal:
    """Convert an Urbanise money cell to Decimal; a dash means zero."""
    value = value.strip()
    if value == "-":
        return Decimal("0.00")
    negative = value.startswith("(") and value.endswith(")")
    value = value.strip("()").replace(",", "")
    result = Decimal(value)
    return -result if negative else result


def sql_string(value: str) -> str:
    return "N'" + value.replace("'", "''") + "'"


def previous_end_date(current_end_date: datetime) -> datetime:
    year = current_end_date.year - 1
    day = min(current_end_date.day, calendar.monthrange(year, current_end_date.month)[1])
    return current_end_date.replace(year=year, day=day)


def parse_end_date(text: str) -> datetime:
    match = re.search(
        r"\b\d{1,2}\s+[A-Za-z]+\s+\d{4}\s+to\s+"
        r"(?P<end>\d{1,2}\s+[A-Za-z]+\s+\d{4})\b",
        text,
    )
    if not match:
        raise ValueError("Could not find the annual budget start/end dates.")
    return datetime.strptime(match.group("end"), "%d %B %Y")


def parse_plan_number(text: str) -> str:
    match = re.search(
        r"Plan No\.\s*(?P<plan>[A-Za-z]+\s*\d+[A-Za-z]*)",
        text,
        re.IGNORECASE,
    )
    if not match:
        raise ValueError("Could not find the plan number.")
    raw = match.group("plan").upper()
    return re.sub(r"\s+", "", raw)


def parse_detail_line(line: str, column_count: int, has_variance: bool):
    if column_count == 1:
        match = ROW_SINGLE_BUDGET.match(line.strip())
        if not match:
            return None
        return match.group("account").strip(), None, money(match.group("current"))

    pattern = ROW_WITH_VARIANCE if has_variance else ROW_WITHOUT_VARIANCE
    match = pattern.match(line.strip())
    if not match:
        return None
    return (
        match.group("account").strip(),
        money(match.group("previous")),
        money(match.group("current")),
    )


def find_money_after_label(lines: list[str], label: str) -> Decimal | None:
    for line in lines:
        if label.lower() not in line.lower():
            continue
        tail = line.lower().split(label.lower(), 1)[1]
        match = re.search(r"[\d,]+\.\d{2}", tail)
        if match:
            return money(match.group())
    return None


def parse_fund_page(
    page_text: str,
    plan_number: str,
    current_end: datetime,
) -> tuple[list[BudgetRow], dict[tuple[str, str, str], Decimal]]:
    lines = [line.strip() for line in page_text.splitlines() if line.strip()]
    fund_match = FUND_PATTERN.search(page_text)
    if not fund_match:
        return [], {}

    fund_name = fund_match.group(1)
    # Urbanise uses several headings for the fourth numeric column, including
    # "Var %" and "Variance $". In both cases the trailing value is variance,
    # not a budget amount.
    has_variance = any(
        line.startswith("Actuals ")
        and re.search(r"\b(?:Var|Variance)\b", line, re.IGNORECASE)
        for line in lines
    )
    expenditure_header = next(
        (line for line in lines if line.startswith("Expenditure ")),
        "",
    )
    column_count = len(
        re.findall(r"\b\d{2}/\d{2}\s*-\s*\d{2}/\d{2}\b", expenditure_header)
    )
    if column_count not in (1, 3):
        # Some extraction variants separate the date headings from Expenditure.
        column_count = 3 if any("Actuals Budget Budget" in line for line in lines) else 1
    previous_end = previous_end_date(current_end)
    rows: list[BudgetRow] = []
    declared_totals: dict[tuple[str, str, str], Decimal] = {}
    section: str | None = None

    for line in lines:
        if line == "Expenditure" or (
            line.startswith("Expenditure ") and PERIOD_TOKEN.search(line)
        ):
            section = "expenditure"
            continue
        if line == "Additional Revenue" or (
            line.startswith("Additional Revenue ") and PERIOD_TOKEN.search(line)
        ):
            section = "income"
            continue
        if line.startswith("Total ") and section:
            parsed_total = parse_detail_line(line, column_count, has_variance)
            if parsed_total:
                _, previous_total, current_total = parsed_total
                if previous_total is not None:
                    declared_totals[(fund_name, section, previous_end.date().isoformat())] = previous_total
                declared_totals[(fund_name, section, current_end.date().isoformat())] = current_total
            section = None
            continue
        if section is None:
            continue

        parsed = parse_detail_line(line, column_count, has_variance)
        if not parsed:
            continue
        account, previous_amount, current_amount = parsed
        if previous_amount is not None:
            rows.append(
                BudgetRow(
                    plan_number,
                    fund_name,
                    account,
                    section,
                    previous_end.date().isoformat(),
                    previous_amount,
                )
            )
        rows.append(
            BudgetRow(
                plan_number,
                fund_name,
                account,
                section,
                current_end.date().isoformat(),
                current_amount,
            )
        )

    # The levy is displayed in the fund summary, not the detail table.
    gross_levy = find_money_after_label(lines, "Budgeted levies to be raised $")
    if gross_levy is not None:
        gst_allowance = find_money_after_label(lines, "Allowance for GST on levies")
        gst_exclusive_levy = gross_levy - (gst_allowance or Decimal("0.00"))
        rows.append(
            BudgetRow(
                plan_number,
                fund_name,
                "Budgeted levies to be raised",
                "income",
                current_end.date().isoformat(),
                gst_exclusive_levy,
            )
        )

    return rows, declared_totals


def validate_totals(
    rows: list[BudgetRow],
    declared_totals: dict[tuple[str, str, str], Decimal],
) -> None:
    levy_account = "Budgeted levies to be raised"
    for (fund, account_type, end_date), expected in declared_totals.items():
        actual = sum(
            (
                row.amount
                for row in rows
                if row.fund_name == fund
                and row.account_type == account_type
                and row.budget_end_date == end_date
                and row.account_name != levy_account
            ),
            Decimal("0.00"),
        )
        if actual != expected:
            raise ValueError(
                f"Total mismatch for {fund}, {account_type}, {end_date}: "
                f"parsed {actual:.2f}, PDF says {expected:.2f}."
            )


def render_sql(rows: list[BudgetRow], source_name: str) -> str:
    values = []
    for row in rows:
        values.append(
            "    ("
            f"{sql_string(row.plan_number)}, "
            f"{sql_string(row.fund_name)}, "
            f"{sql_string(row.account_name)}, "
            f"{sql_string(row.account_type)}, "
            f"CONVERT(datetime, '{row.budget_end_date}T00:00:00', 126), "
            f"{row.amount:.2f})"
        )

    return (
        f"-- Source: {source_name}\n"
        "-- Printed '-' budget values are represented as 0.00.\n"
        "-- Total and summary rows are excluded to prevent double-counting.\n"
        "-- 'Budgeted levies to be raised' is stored GST exclusive.\n\n"
        f"INSERT INTO {TABLE_NAME}\n"
        "(\n"
        "    [Plan_Number],\n"
        "    [Fund_Name],\n"
        "    [Account_Name],\n"
        "    [Account_Type],\n"
        "    [Budget_EndDate],\n"
        "    [Amount]\n"
        ")\n"
        "VALUES\n"
        + ",\n".join(values)
        + ";\n"
    )


def convert(source: Path, output: Path) -> tuple[int, str]:
    with pdfplumber.open(source) as pdf:
        page_texts = [page.extract_text(x_tolerance=2, y_tolerance=3) or "" for page in pdf.pages]

    full_text = "\n".join(page_texts)
    plan_number = parse_plan_number(full_text)
    current_end = parse_end_date(full_text)
    rows: list[BudgetRow] = []
    totals: dict[tuple[str, str, str], Decimal] = {}

    # Join consecutive pages belonging to the same fund. Urbanise can split a
    # detail section across pages without repeating its section heading, so
    # parsing each PDF page independently can silently omit continuation rows.
    fund_sections: list[str] = []
    current_fund: str | None = None
    current_pages: list[str] = []
    for page_text in page_texts:
        fund_match = FUND_PATTERN.search(page_text)
        page_fund = fund_match.group(1) if fund_match else None
        if page_fund is None:
            if current_pages:
                fund_sections.append("\n".join(current_pages))
                current_fund = None
                current_pages = []
            continue
        if current_fund == page_fund:
            current_pages.append(page_text)
        else:
            if current_pages:
                fund_sections.append("\n".join(current_pages))
            current_fund = page_fund
            current_pages = [page_text]
    if current_pages:
        fund_sections.append("\n".join(current_pages))

    for section_text in fund_sections:
        page_rows, page_totals = parse_fund_page(section_text, plan_number, current_end)
        rows.extend(page_rows)
        totals.update(page_totals)

    if not rows:
        raise ValueError("No budget detail rows were found.")

    detail_rows = [
        row for row in rows if row.account_name != "Budgeted levies to be raised"
    ]
    if not detail_rows:
        raise ValueError(
            "The PDF contained levy summaries but no recognized budget detail rows."
        )

    validate_totals(rows, totals)
    output.write_text(render_sql(rows, source.name), encoding="utf-8")
    return len(rows), plan_number


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Convert an Urbanise annual-budget PDF to normalized SQL INSERT rows."
    )
    parser.add_argument("pdf", type=Path, help="Input Urbanise budget PDF")
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        help="Output SQL file (default: input filename with .sql extension)",
    )
    args = parser.parse_args()
    output = args.output or args.pdf.with_name(args.pdf.stem + "_inserts.sql")

    if not args.pdf.is_file():
        parser.error(f"Input file does not exist: {args.pdf}")

    count, plan = convert(args.pdf, output)
    print(f"Generated {count} rows for {plan}: {output}")


if __name__ == "__main__":
    main()
