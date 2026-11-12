"""Stateless local checks on PDF text/rows and SQL MCP evidence. Never execute SQL.

No database, MCP, model, subprocess, orchestration, authorization or persistence API.
The CLI reads explicitly supplied files and prints evidence; it never writes files.
"""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
from datetime import date
from decimal import Decimal, InvalidOperation
import json
from pathlib import Path
import re


CONTRACTS = {
    "levy": ("PlanNumber", "LotNumber", "Fund", "Levy type", "Levy category",
             "Due date", "LevyStartDate", "LevyEndDate", "Outstanding"),
    "income": ("Plan_Number", "Fund_Name", "Account_Name", "AccountType", "Amount",
               "Period_Start", "Period_End"),
    "budget": ("Plan_Number", "Fund_Name", "Account_Name", "Account_Type",
               "Budget_EndDate", "Amount"),
}
TITLES = {
    "levy": r"^\s*LEVY\s+STATEMENT\s*-\s*\S+",
    "income": r"^\s*INCOME\s+(?:AND|&)\s+EXPENDITURE\s*-?\s*TRANSACTION\s+LIST\b",
    "budget": r"^\s*(?:PROPOSED\s+)?ANNUAL\s+BUDGET\b",
}


def amount(value):
    if isinstance(value, bool) or value is None:
        raise ValueError("Amount must be a finite decimal")
    try:
        result = Decimal(str(value))
    except InvalidOperation as exc:
        raise ValueError("Amount must be a finite decimal") from exc
    if not result.is_finite():
        raise ValueError("Amount must be a finite decimal")
    return result


def iso_date(value):
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}(?:T00:00:00(?:\.000)?Z?)?", value):
        raise ValueError("Expected ISO date or midnight ISO datetime")
    return date.fromisoformat(value[:10])


def ledger_type(kind, account_type):
    if kind not in ("income", "budget") or not isinstance(account_type, str):
        raise ValueError("Unsupported mapping type")
    value = account_type.casefold()
    if value == "expenditure":
        return "expense"
    if value == "income" or (kind == "income" and value == "revenue"):
        return "income"
    raise ValueError("Unsupported account type: " + account_type)


def classify_text(text):
    """Conservative report-title classification, not keyword/filename guessing."""
    candidates = [k for k, pattern in TITLES.items() if re.search(pattern, text, re.I | re.M)]
    plans = sorted(set(re.sub(r"\s+", "", p).upper() for p in re.findall(
        r"Plan No\.\s*([A-Za-z]+\s*\d+[A-Za-z]*)", text, re.I)))
    kind = candidates[0] if len(candidates) == 1 else ("AMBIGUOUS" if candidates else "UNKNOWN")
    valid = len(candidates) == 1 and len(plans) == 1
    return {"valid": valid, "type": kind, "candidates": candidates, "plans": plans}


def validate_rows(kind, rows, plan, allowed_funds):
    """Check literal conversion rows. PDF completeness and SQL text require separate review."""
    columns = CONTRACTS[kind]
    plan_col, fund_col, money_col = ("PlanNumber", "Fund", "Outstanding") if kind == "levy" else ("Plan_Number", "Fund_Name", "Amount")
    issues, duplicates, totals = [], defaultdict(list), defaultdict(Decimal)
    if not rows:
        issues.append({"row": None, "reason": "No rows; cannot infer a successful conversion"})
    if not isinstance(plan, str) or not plan or not allowed_funds:
        raise ValueError("Explicit canonical plan and supported source funds are required")
    for index, row in enumerate(rows, 1):
        try:
            if set(row) != set(columns):
                raise ValueError("Column mismatch: missing=" + str(sorted(set(columns) - set(row))) +
                                 "; extra=" + str(sorted(set(row) - set(columns))))
            if row[plan_col] != plan:
                raise ValueError("Plan mismatch: " + str(row[plan_col]))
            if row[fund_col] not in allowed_funds:
                raise ValueError("Unsupported fund: " + str(row[fund_col]))
            value = amount(row[money_col])
            if value != value.quantize(Decimal("0.01")):
                raise ValueError("Conversion amount has more than two decimal places")
            if kind == "levy":
                if value <= 0:
                    raise ValueError("Arrears INSERT must be positive; credits need separate accounting")
                for col in ("LotNumber", "Levy type", "Levy category"):
                    if not isinstance(row[col], str) or not row[col].strip():
                        raise ValueError("Missing string " + col)
                if row["Levy category"] not in {"Regular", "Interest", "DR charge", "Special", "Sub metering", "Owner invoice"}:
                    raise ValueError("Unsupported levy category")
                iso_date(row["Due date"])
                start, end = row["LevyStartDate"], row["LevyEndDate"]
                if (start is None) != (end is None):
                    raise ValueError("Incomplete levy period")
                if start is not None and iso_date(start) > iso_date(end):
                    raise ValueError("Reversed levy period")
                breakdown = (row[fund_col], row["LotNumber"], row["Levy category"])
            else:
                if not isinstance(row["Account_Name"], str) or not row["Account_Name"].strip():
                    raise ValueError("Missing account name")
                typ = row["AccountType" if kind == "income" else "Account_Type"]
                ledger_type(kind, typ)
                if kind == "income":
                    if iso_date(row["Period_Start"]) > iso_date(row["Period_End"]):
                        raise ValueError("Reversed account period")
                    period = (row["Period_Start"], row["Period_End"])
                else:
                    iso_date(row["Budget_EndDate"])
                    period = (row["Budget_EndDate"],)
                breakdown = (row[fund_col], row["Account_Name"], typ, *period)
            totals[breakdown] += value
            duplicates[tuple(value if c == money_col else row[c] for c in columns)].append(index)
        except (ValueError, TypeError, InvalidOperation) as exc:
            issues.append({"row": index, "reason": str(exc)})
    repeated = [v for v in duplicates.values() if len(v) > 1]
    return {"valid": not issues, "requires_review": bool(repeated), "issues": issues,
            "duplicate_row_ordinals": repeated, "row_count": len(rows),
            "validated_total": sum(totals.values(), Decimal(0)),
            "breakdown": [{"key": k, "amount": v} for k, v in sorted(totals.items())]}


def mapping_gate(kind, rows, require_mapped=False, managing_company_code=None, mapping_contract=None):
    """Candidates must come from the authoritative SQL name/ledger join, retaining NULLs."""
    # Compare supplied provenance only. Codex resolves/inspects the binding.
    # Row-only calls remain usable for offline candidate regression checks.
    contract_issues = []
    if managing_company_code is not None or mapping_contract is not None:
        contract = mapping_contract or {}
        if not isinstance(contract, dict):
            contract_issues.append("Invalid authoritative COA mapping contract; expected an object")
            contract = {}
        if not isinstance(managing_company_code, str) or not managing_company_code.strip():
            contract_issues.append("Missing resolved ManagingCompanyCode")
        if contract.get("ManagingCompanyCode") != managing_company_code:
            contract_issues.append("COA mapping contract belongs to a different managing company")
        for field in ("source", "authority"):
            if not isinstance(contract.get(field), str) or not contract[field].strip():
                contract_issues.append("Missing authoritative COA mapping contract " + field)
    results = []
    for row in rows:
        reasons, target = list(contract_issues), None
        try:
            ledger = ledger_type(kind, row["account_type"])
        except ValueError as exc:
            ledger = None
            reasons.append(str(exc))
        candidates = row["candidate_mchids"]
        if not candidates:
            reasons.append("No authoritative account/ledger match")
        elif any(type(v) is not int or v <= 0 for v in candidates):
            reasons.append("NULL or invalid authoritative LEVE3_MCHID")
        elif len(set(candidates)) != 1:
            reasons.append("Conflicting authoritative LEVE3_MCHIDs")
        else:
            target = candidates[0]
        current = row.get("MCHID")
        if current is not None and (type(current) is not int or current != target):
            reasons.append("Existing MCHID disagrees with authoritative mapping; do not overwrite")
        if require_mapped and current is None:
            reasons.append("NULL MCHID remains after mapping")
        results.append({**row, "ledger_type": ledger, "authoritative_mchid": target,
                        "reasons": reasons})
    ids = [r["source_id"] for r in rows]
    if len(ids) != len(set(ids)):
        raise ValueError("Source row IDs must be unique, including duplicate business rows")
    valid = bool(rows) and not contract_issues and not any(r["reasons"] for r in results)
    return {"valid": valid, "status": "PASS" if valid else "BLOCKED",
            "contract_issues": contract_issues,
            "row_count": len(rows), "null_mchid_count": sum(r.get("MCHID") is None for r in rows),
            "rows": results}


def check_coverage(source_ids, matches):
    """One query match per source ordinal; several sources may share one grouped target."""
    if len(source_ids) != len(set(source_ids)):
        raise ValueError("Source IDs must uniquely identify rows, not account/group names")
    counts, occurrences = Counter(), Counter()
    extras = []
    for row in matches:
        occurrences[row["source_id"]] += 1
        if row["source_id"] not in source_ids:
            extras.append(row["source_id"])
        target = row["target_key"]
        present = target is not None and (not isinstance(target, list) or (bool(target) and all(v is not None for v in target)))
        if present:
            counts[row["source_id"]] += 1
    missing = [s for s in source_ids if counts[s] == 0]
    multiplied = [s for s in source_ids if occurrences[s] > 1]
    return {"valid": bool(source_ids) and not (missing or multiplied or extras),
            "source_rows": len(source_ids), "matched_rows": sum(counts[s] for s in source_ids),
            "missing": missing, "multiplying": multiplied, "unexpected_source_ids": extras}


def reconcile(expected, actual, key_columns, amount_column="Amount", grouped=False):
    """Exact multiset or grouped comparison. Never round away differences or drop duplicates."""
    if not key_columns or len(set(key_columns)) != len(key_columns) or amount_column in key_columns:
        raise ValueError("Explicit unique business/group key columns, excluding amount, are required")
    def collect(rows):
        groups = defaultdict(list)
        for row in rows:
            groups[tuple(row[c] for c in key_columns)].append(amount(row[amount_column]))
        return groups
    left, right = collect(expected), collect(actual)
    differences = []
    for key in left.keys() | right.keys():
        wanted, found = left.get(key, []), right.get(key, [])
        if grouped:
            same = bool(wanted) and len(found) == 1 and sum(wanted) == found[0]
        else:
            same = Counter(wanted) == Counter(found)
        if not same:
            differences.append({"key": key, "expected_rows": len(wanted), "actual_rows": len(found),
                                "expected_amounts": wanted, "actual_amounts": found})
    source_total = sum((amount(r[amount_column]) for r in expected), Decimal(0))
    final_total = sum((amount(r[amount_column]) for r in actual), Decimal(0))
    return {"valid": bool(expected) and not differences, "source_rows": len(expected),
            "expected_groups": len(left), "actual_rows": len(actual),
            "source_total": source_total, "final_total": final_total,
            "difference": final_total - source_total, "exceptions": differences}


def state_from_evidence(kind, raw, mapping, intermediate, final, blockers=(), uncertain_write=False,
                        incomplete_company_effects=False):
    """Label inspected evidence only. This function never schedules or retries operations."""
    if kind not in CONTRACTS:
        raise ValueError("Unknown financial type")
    if any(s not in {"ABSENT", "MATCH", "MISMATCH", "UNVERIFIED"} for s in (raw, intermediate, final)):
        raise ValueError("Stage evidence must be ABSENT, MATCH, MISMATCH or UNVERIFIED")
    if mapping not in {"NOT_CHECKED", "PASS", "BLOCKED", "NOT_REQUIRED"}:
        raise ValueError("Unknown mapping evidence")
    if (mapping == "NOT_REQUIRED") != (kind == "levy"):
        raise ValueError("Only Levy omits the mapping stage")
    ready = mapping in {"PASS", "NOT_REQUIRED"}
    partial = uncertain_write or incomplete_company_effects or any(
        s in {"MISMATCH", "UNVERIFIED"} for s in (raw, intermediate, final))
    partial |= intermediate == "MATCH" and (raw != "MATCH" or not ready)
    partial |= final == "MATCH" and intermediate != "MATCH"
    partial |= kind == "levy" and intermediate == "MATCH" and final == "ABSENT"
    partial |= kind != "levy" and mapping == "PASS" and raw != "MATCH"
    if partial:
        return "PARTIAL_INCONSISTENT"
    if blockers or mapping == "BLOCKED":
        return "BLOCKED"
    if final == "MATCH":
        return "FINAL_COMPLETE"
    if intermediate == "MATCH":
        return "INTERMEDIATE_COMPLETE"
    if raw == "MATCH":
        return "MAPPED" if kind != "levy" and mapping == "PASS" else "RAW_LOADED"
    return "NOT_STARTED"


def input_path(value):
    supplied = Path(value)
    if any(p.casefold() in {"dev_only", "tests", "fixtures"} for p in supplied.parts):
        raise ValueError("DEV/test artifacts are not normal onboarding inputs")
    path = supplied.resolve(strict=True)
    if any(p.casefold() in {"dev_only", "tests", "fixtures"} for p in path.parts):
        raise ValueError("DEV/test artifacts are not normal onboarding inputs")
    if not path.is_file():
        raise ValueError("An explicit input file is required")
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("check", choices=("classify", "rows", "mapping", "coverage", "reconcile", "state"))
    parser.add_argument("input", help="PDF for classify; captured JSON evidence for other checks")
    args = parser.parse_args()
    try:
        path = input_path(args.input)
        if args.check == "classify":
            if path.suffix.casefold() != ".pdf":
                raise ValueError("Classification requires a PDF")
            from pypdf import PdfReader
            result = classify_text("\n".join(p.extract_text() or "" for p in PdfReader(str(path)).pages))
        else:
            evidence = json.loads(path.read_text(encoding="utf-8"), parse_float=Decimal)
            if args.check == "mapping":
                # CLI evidence must identify the company and authoritative source.
                evidence["managing_company_code"] = evidence.get("managing_company_code") or ""
                evidence["mapping_contract"] = evidence.get("mapping_contract") or {}
            checks = {"rows": validate_rows, "mapping": mapping_gate, "coverage": check_coverage,
                      "reconcile": reconcile, "state": state_from_evidence}
            result = checks[args.check](**evidence)
            if args.check == "state":
                result = {"state": result}  # Evidence label only, never execution permission.
        print(json.dumps(result, default=str, indent=2))
        return 2 if result.get("valid") is False or result.get("requires_review") else 0
    except (OSError, ValueError, TypeError, KeyError, InvalidOperation) as exc:
        print(json.dumps({"valid": False, "error": str(exc)}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
