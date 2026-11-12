#!/usr/bin/env python3
"""Extract Urbanise revenue/expenditure account totals from a PDF into SQL."""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from pathlib import Path

try:
    from pypdf import PdfReader
except ImportError as exc:  # pragma: no cover - depends on the caller's environment
    raise SystemExit(
        "Missing dependency 'pypdf'. Install it with: python -m pip install pypdf"
    ) from exc


TABLE_NAME = "[AboveOCM_Local_Test].[dbo].[URBANISE_Revenue_Expenditure_Accounts]"
PLAN_RE = re.compile(r"Owners Corporation for Plan No\.\s*(.+?)\s*$", re.IGNORECASE)
FUND_RE = re.compile(r"^(.+\bFUND)\s*$", re.IGNORECASE)
PERIOD_RE = re.compile(
    r"^For the period\s+(.+?)\s+to\s+(.+?)\s*$",
    re.IGNORECASE,
)
ACCOUNT_TYPES = {"REVENUE": "Revenue", "EXPENDITURE": "Expenditure"}
TOTAL_RE = re.compile(
    r"^Total for\s+(.+?)\s+([$(]?\s*-?[\d,]+(?:\.\d{2})?\s*\)?)\s*$",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class AccountTotal:
    plan_number: str
    fund_name: str
    account_name: str
    account_type: str
    amount: Decimal
    period_start: date
    period_end: date


def normalize_space(value: str) -> str:
    return " ".join(value.split())


def parse_amount(raw_amount: str) -> Decimal:
    value = raw_amount.strip().replace("$", "").replace(",", "").replace(" ", "")
    negative = value.startswith("(") and value.endswith(")")
    if negative:
        value = value[1:-1]

    try:
        amount = Decimal(value)
    except InvalidOperation as exc:
        raise ValueError(f"Invalid amount: {raw_amount!r}") from exc

    return -amount if negative else amount


def parse_report_date(raw_date: str) -> date:
    value = normalize_space(raw_date)
    for date_format in ("%d %B %Y", "%d %b %Y"):
        try:
            return datetime.strptime(value, date_format).date()
        except ValueError:
            pass
    raise ValueError(f"Invalid report period date: {raw_date!r}")


def extract_accounts(pdf_path: Path, plan_override: str | None = None) -> list[AccountTotal]:
    reader = PdfReader(str(pdf_path))
    plan_number = normalize_space(plan_override) if plan_override else None
    current_fund: str | None = None
    current_period: tuple[date, date] | None = None
    current_account_type: str | None = None
    records: list[AccountTotal] = []

    for page_number, page in enumerate(reader.pages, start=1):
        text = page.extract_text() or ""
        for raw_line in text.splitlines():
            line = normalize_space(raw_line)
            if not line:
                continue

            if plan_number is None:
                plan_match = PLAN_RE.search(line)
                if plan_match:
                    plan_number = normalize_space(plan_match.group(1))

            fund_match = FUND_RE.fullmatch(line)
            if fund_match and line == line.upper():
                next_fund = normalize_space(fund_match.group(1)).upper()
                if next_fund != current_fund:
                    current_account_type = None
                current_fund = next_fund
                current_period = None
                continue

            period_match = PERIOD_RE.fullmatch(line)
            if period_match:
                period_start = parse_report_date(period_match.group(1))
                period_end = parse_report_date(period_match.group(2))
                if period_start > period_end:
                    raise ValueError(
                        f"Period start is after period end on page {page_number}: {line}"
                    )
                current_period = (period_start, period_end)
                continue

            if line.upper() in ACCOUNT_TYPES:
                current_account_type = ACCOUNT_TYPES[line.upper()]
                continue

            total_match = TOTAL_RE.fullmatch(line)
            if not total_match:
                continue

            if plan_number is None:
                raise ValueError(f"Could not determine the plan number by page {page_number}")
            if current_fund is None:
                raise ValueError(
                    f"Found an account total before a fund heading on page {page_number}: {line}"
                )
            if current_period is None:
                raise ValueError(
                    f"Found an account total before a report period on page {page_number}: {line}"
                )
            if current_account_type is None:
                raise ValueError(
                    f"Found an account total before an account type on page {page_number}: {line}"
                )

            records.append(
                AccountTotal(
                    plan_number=plan_number,
                    fund_name=current_fund,
                    account_name=normalize_space(total_match.group(1)),
                    account_type=current_account_type,
                    amount=parse_amount(total_match.group(2)),
                    period_start=current_period[0],
                    period_end=current_period[1],
                )
            )

    if plan_number is None:
        raise ValueError(
            "Could not find 'Owners Corporation for Plan No.' in the PDF. "
            "Use --plan-number to supply it explicitly."
        )
    if not records:
        raise ValueError("No 'Total for ...' account rows were found in the PDF")

    return records


def sql_string(value: str) -> str:
    return "N'" + value.replace("'", "''") + "'"


def render_sql(records: list[AccountTotal], source_name: str) -> str:
    lines = [
        f"-- Generated from {source_name}",
        "SET XACT_ABORT ON;",
        "BEGIN TRANSACTION;",
        "",
    ]

    for record in records:
        amount = format(record.amount, ".2f")
        lines.extend(
            [
                f"INSERT INTO {TABLE_NAME}",
                "    ([Plan_Number], [Fund_Name], [Account_Name], [AccountType], [Amount], "
                "[Period_Start], [Period_End])",
                "VALUES",
                "    ("
                f"{sql_string(record.plan_number)}, "
                f"{sql_string(record.fund_name)}, "
                f"{sql_string(record.account_name)}, "
                f"{sql_string(record.account_type)}, "
                f"{amount}, "
                f"'{record.period_start.isoformat()}', "
                f"'{record.period_end.isoformat()}'"
                ");",
                "",
            ]
        )

    lines.append("COMMIT TRANSACTION;")
    lines.append("")
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Extract Urbanise account totals from an income/expenditure PDF into SQL INSERTs."
    )
    parser.add_argument("pdf", type=Path, help="Path to the Urbanise PDF")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="Output .sql path (default: the PDF filename with a .sql extension)",
    )
    parser.add_argument(
        "--plan-number",
        help="Override the plan number instead of reading it from the PDF",
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Write SQL to standard output instead of a file",
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    pdf_path = args.pdf.resolve()
    if not pdf_path.is_file():
        print(f"Error: PDF not found: {pdf_path}", file=sys.stderr)
        return 2

    try:
        records = extract_accounts(pdf_path, args.plan_number)
        sql = render_sql(records, pdf_path.name)
    except (OSError, ValueError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    if args.stdout:
        sys.stdout.write(sql)
    else:
        output_path = (args.output or pdf_path.with_suffix(".sql")).resolve()
        output_path.write_text(sql, encoding="utf-8", newline="\n")
        print(
            f"Created {output_path} with {len(records)} INSERT statements "
            f"for plan {records[0].plan_number}."
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
