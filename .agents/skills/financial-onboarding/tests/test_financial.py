"""Offline validation/regression tests. No SQL, approvals or onboarding execution."""
from decimal import Decimal
import ast
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

SKILL = Path(__file__).resolve().parents[1]
ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(SKILL / "scripts"))
import validate_financial as v


def budget_row():
    return dict(Plan_Number="TEST999X", Fund_Name="Administrative Fund", Account_Name="Test fee",
                Account_Type="expenditure", Budget_EndDate="2031-06-30", Amount="20.15")


class ValidationTests(unittest.TestCase):
    def test_content_classification(self):
        for title, kind in (("LEVY STATEMENT - 001", "levy"),
                            ("INCOME AND EXPENDITURE - TRANSACTION LIST", "income"),
                            ("Proposed Annual Budget Administrative Fund", "budget")):
            r = v.classify_text("Owners Corporation for Plan No. TEST999X\n" + title)
            self.assertTrue(r["valid"])
            self.assertEqual(r["type"], kind)

    def test_unrelated_ambiguous_and_mixed_plan_pdf(self):
        self.assertFalse(v.classify_text("Minutes: discussed budget, income and levy arrears.")["valid"])
        self.assertFalse(v.classify_text("LEVY STATEMENT - 1\nAnnual Budget\nPlan No. TEST999X")["valid"])
        self.assertFalse(v.classify_text("Annual Budget\nPlan No. TEST999X\nPlan No. TEST888X")["valid"])
        self.assertFalse(v.classify_text("")["valid"])

    def check_rows(self, rows):
        return v.validate_rows("budget", rows, "TEST999X", ["Administrative Fund"])

    def test_conversion_validation_exact_values(self):
        r = self.check_rows([budget_row(), dict(budget_row(), Amount="-0.05", Account_Name="Credit")])
        self.assertTrue(r["valid"])
        self.assertEqual(r["validated_total"], Decimal("20.10"))
        self.assertFalse(self.check_rows([])["valid"])

    def test_conversion_rejects_defects(self):
        changes = [{"Plan_Number": "TEST 999X"}, {"Fund_Name": "Invented fund"},
                   {"Budget_EndDate": "2031-02-30"}, {"Budget_EndDate": "30/06/2031"},
                   {"Account_Type": "other"}, {"Amount": "NaN"}, {"Amount": "Infinity"},
                   {"Amount": "20.151"}, {"Amount": True}, {"Amount": "1,000.00"}]
        for change in changes:
            with self.subTest(change=change):
                self.assertFalse(self.check_rows([dict(budget_row(), **change)])["valid"])
        missing = budget_row()
        missing.pop("Fund_Name")
        self.assertFalse(self.check_rows([missing])["valid"])
        self.assertFalse(self.check_rows([dict(budget_row(), MCHID=42)])["valid"])

    def test_duplicates_are_preserved_and_reported(self):
        r = self.check_rows([budget_row(), budget_row()])
        self.assertEqual(r["row_count"], 2)
        self.assertEqual(r["validated_total"], Decimal("40.30"))
        self.assertTrue(r["requires_review"])
        self.assertEqual(r["duplicate_row_ordinals"], [[1, 2]])

    def mapping(self, candidates, current=None, after=False, account_type="expenditure"):
        return v.mapping_gate("budget", [{"source_id": "row:1", "account_type": account_type,
                                          "candidate_mchids": candidates, "MCHID": current}], after)

    def test_same_mapping_duplicates_deduplicate(self):
        r = self.mapping([42, 42])
        self.assertTrue(r["valid"])
        self.assertEqual(r["rows"][0]["authoritative_mchid"], 42)

    def test_mapping_conflicts_null_candidates_and_wrong_existing_value(self):
        for candidates in ([42, 43], [], [None], [42, None], [0], [True], ["42"]):
            with self.subTest(candidates=candidates):
                self.assertFalse(self.mapping(candidates)["valid"])
        self.assertFalse(self.mapping([42], current=43)["valid"])
        self.assertFalse(self.mapping([42], account_type="unknown")["valid"])
        self.assertEqual(v.ledger_type("income", "Revenue"), "income")
        with self.assertRaises(ValueError):
            v.ledger_type("budget", "Revenue")

    def test_post_mapping_null_gate_and_empty_raw(self):
        self.assertFalse(self.mapping([42], after=True)["valid"])
        self.assertTrue(self.mapping([42, 42], current=42, after=True)["valid"])
        self.assertFalse(v.mapping_gate("income", [], True)["valid"])

    def test_coverage_allows_grouping_but_not_multiplication(self):
        matches = [{"source_id": n, "target_key": [8, 9]} for n in (1, 2)]
        self.assertTrue(v.check_coverage([1, 2], matches)["valid"])
        self.assertFalse(v.check_coverage([1, 2], matches + matches[:1])["valid"])
        self.assertFalse(v.check_coverage([1, 2, 3], matches)["valid"])
        self.assertFalse(v.check_coverage([1], matches)["valid"])
        self.assertFalse(v.check_coverage([1, 2], matches + [{"source_id": 1, "target_key": None}])["valid"])
        self.assertFalse(v.check_coverage([1], [{"source_id": 1, "target_key": [8, None]}])["valid"])

    def test_multiset_reconciliation_preserves_duplicates(self):
        row = {"fund": "A", "Amount": "10.00"}
        self.assertTrue(v.reconcile([row, row], [row, row], ["fund"])["valid"])
        self.assertFalse(v.reconcile([row, row], [{"fund": "A", "Amount": "20"}], ["fund"])["valid"])

    def test_grouping_matches_once_and_rejects_offsetting_errors(self):
        expected = [{"MCHID": 42, "Amount": "200"}, {"MCHID": 42, "Amount": "50"},
                    {"MCHID": 43, "Amount": "10"}]
        actual = [{"MCHID": 42, "Amount": "250"}, {"MCHID": 43, "Amount": "10"}]
        self.assertTrue(v.reconcile(expected, actual, ["MCHID"], grouped=True)["valid"])
        wrong = [{"MCHID": 42, "Amount": "249"}, {"MCHID": 43, "Amount": "11"}]
        r = v.reconcile(expected, wrong, ["MCHID"], grouped=True)
        self.assertFalse(r["valid"])
        self.assertEqual(r["difference"], 0)
        self.assertFalse(v.reconcile(expected, expected, ["MCHID"], grouped=True)["valid"])
        self.assertFalse(v.reconcile(expected, actual + [{"MCHID": 44, "Amount": "0"}], ["MCHID"], grouped=True)["valid"])
        self.assertFalse(v.reconcile(expected, [dict(actual[0], Amount="250.0001"), actual[1]], ["MCHID"], grouped=True)["valid"])

    def test_state_and_unsafe_resume(self):
        def state(raw="ABSENT", mapping="NOT_CHECKED", intermediate="ABSENT", final="ABSENT", **kw):
            return v.state_from_evidence("budget", raw, mapping, intermediate, final, **kw)
        self.assertEqual(state(), "NOT_STARTED")
        self.assertEqual(state("MATCH"), "RAW_LOADED")
        self.assertEqual(state("MATCH", "PASS"), "MAPPED")
        self.assertEqual(state("MATCH", "PASS", "MATCH"), "INTERMEDIATE_COMPLETE")
        self.assertEqual(state("MATCH", "PASS", "MATCH", "MATCH"), "FINAL_COMPLETE")
        self.assertEqual(state("MATCH", "BLOCKED"), "BLOCKED")
        self.assertEqual(state("MATCH", "PASS", "MATCH", blockers=["Missing FY anchor"]), "BLOCKED")
        for evidence in ({"uncertain_write": True}, {"incomplete_company_effects": True},
                         {"final": "MISMATCH"}, {"raw": "UNVERIFIED"}, {"final": "MATCH"}):
            self.assertEqual(state(**evidence), "PARTIAL_INCONSISTENT")
        self.assertEqual(v.state_from_evidence("levy", "MATCH", "NOT_REQUIRED", "MATCH", "ABSENT"), "PARTIAL_INCONSISTENT")
        with self.assertRaises(ValueError):
            state(mapping="NOT_REQUIRED")

    def test_dev_fixture_cli_boundary(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "dev_only" / "seed.json"
            p.parent.mkdir()
            p.write_text("{}", encoding="utf-8")
            with self.assertRaisesRegex(ValueError, "DEV/test"):
                v.input_path(p)


class UniversalizationTests(unittest.TestCase):
    """Offline arbitrary-company evidence; no property lookup or import execution."""

    def test_two_companies_use_distinct_authoritative_mapping_evidence(self):
        contexts = [
            dict(PlanNumber="SP482190", PropertyID=317, CompanyID=842,
                 ManagingCompanyCode="NORTHSTRATA", source="dbo.North_Account_Map", leaf=19021),
            dict(PlanNumber="DP610275Z", PropertyID=926, CompanyID=570,
                 ManagingCompanyCode="COASTMGMT", source="accounts.Coast_COA", leaf=28034),
        ]
        for context in contexts:
            with self.subTest(company=context["ManagingCompanyCode"]):
                code = context["ManagingCompanyCode"]
                contract = dict(ManagingCompanyCode=code, source=context["source"],
                                authority="Captured existing company-to-source binding")
                for kind in ("income", "budget"):
                    rows = [dict(source_id="row:1", account_type="expenditure",
                                 candidate_mchids=[context["leaf"], context["leaf"]],
                                 MCHID=context["leaf"], **{k: context[k] for k in (
                                     "PlanNumber", "PropertyID", "CompanyID", "ManagingCompanyCode")})]
                    result = v.mapping_gate(kind, rows, True, code, contract)
                    self.assertTrue(result["valid"], result)
                    self.assertEqual(result["rows"][0]["authoritative_mchid"], context["leaf"])
                    self.assertEqual(rows[0]["MCHID"], context["leaf"])
                    self.assertFalse(v.mapping_gate(kind, rows, True, code,
                                     dict(contract, ManagingCompanyCode="UNRELATED"))["valid"])
                    missing = v.mapping_gate(kind, rows, True, code, {})
                    self.assertEqual(missing["status"], "BLOCKED")
                    self.assertIn("Missing authoritative COA mapping contract source", missing["contract_issues"])
                    for invalid in (["not a contract"], dict(contract, authority=" "), dict(contract, source=None)):
                        self.assertEqual(v.mapping_gate(kind, rows, True, code, invalid)["status"], "BLOCKED")
                    self.assertEqual(v.state_from_evidence(kind, "MATCH", "BLOCKED", "ABSENT", "ABSENT"), "BLOCKED")

                # Identity and totals are supplied data, independent for each company.
                expected = [dict(PropertyID=context["PropertyID"], CompanyID=context["CompanyID"],
                                 MCHID=context["leaf"], Amount="7.21"),
                            dict(PropertyID=context["PropertyID"], CompanyID=context["CompanyID"],
                                 MCHID=context["leaf"], Amount="3.17")]
                actual = [dict(expected[0], Amount="10.38")]
                keys = ["PropertyID", "CompanyID", "MCHID"]
                self.assertTrue(v.reconcile(expected, actual, keys, grouped=True)["valid"])
                self.assertFalse(v.reconcile(expected, [dict(actual[0], CompanyID=999)], keys, grouped=True)["valid"])

    def test_arbitrary_reports_use_existing_converter_contracts(self):
        sys.path.insert(0, str(ROOT / "scripts"))
        import extract_urbanise_accounts as income
        import urbanise_budget_to_sql as budget
        import levy_arrears_parser as levy
        plan = "DP610275Z"
        # Extracted PDF text fixtures use arbitrary report names, periods and amounts.
        income_text = (f"Owners Corporation for Plan No. {plan}\n"
                       "INCOME AND EXPENDITURE - TRANSACTION LIST\n"
                       "CAPITAL WORKS FUND\nFor the period 1 July 2032 to 30 June 2033\n"
                       "EXPENDITURE\nTotal for Roof inspection 17.29")
        budget_text = (f"Owners Corporation for Plan No. {plan}\nAnnual Budget\n"
                       "1 July 2032 to 30 June 2033\nCapital Works Fund\n"
                       "Expenditure\nRoof inspection 28.36\nTotal Expenditure 28.36")
        levy_text = (f"Owners Corporation for Plan No. {plan}\nLEVY STATEMENT - B27\n"
                     "Balance of account as at 30/06/2033 $ -41.53 0.00 0.00 0.00 0.00 0.00")
        for kind, text in (("income", income_text), ("budget", budget_text), ("levy", levy_text)):
            classified = v.classify_text(text)
            self.assertTrue(classified["valid"], classified)
            self.assertEqual(classified["type"], kind)
            self.assertEqual(classified["plans"], [plan])

        page = Mock()
        page.extract_text.return_value = income_text
        with patch.object(income, "PdfReader", return_value=Mock(pages=[page])):
            records = income.extract_accounts(Path("unrelated-name-a.pdf"))
        rows = [dict(Plan_Number=r.plan_number, Fund_Name=r.fund_name, Account_Name=r.account_name,
                     AccountType=r.account_type, Amount=r.amount, Period_Start=r.period_start.isoformat(),
                     Period_End=r.period_end.isoformat()) for r in records]
        self.assertTrue(v.validate_rows("income", rows, plan, ["CAPITAL WORKS FUND"])["valid"])
        self.assertIn(plan, income.render_sql(records, "unrelated-name-a.pdf"))

        budget_plan = budget.parse_plan_number(budget_text)
        budget_rows, totals = budget.parse_fund_page(budget_text, budget_plan, budget.parse_end_date(budget_text))
        budget.validate_totals(budget_rows, totals)
        rows = [dict(Plan_Number=r.plan_number, Fund_Name=r.fund_name, Account_Name=r.account_name,
                     Account_Type=r.account_type, Budget_EndDate=r.budget_end_date, Amount=r.amount)
                for r in budget_rows]
        self.assertTrue(v.validate_rows("budget", rows, plan, ["Capital Works Fund"])["valid"])
        self.assertIn(plan, budget.render_sql(budget_rows, "unrelated-name-b.pdf"))

        page.extract_text.return_value = levy_text
        actual_plan, lot, balances = levy.extract_identity_and_balances([page])
        states = levy.replay([levy.Transaction(due_date="2033-06-30", description="Levies - normal",
                             levy_start_date="2033-04-01", levy_end_date="2033-06-30",
                             admin=Decimal("-41.53"), admin_penalty=None, maintenance=None,
                             maintenance_penalty=None)])
        levy.validate(states, balances)
        item = states["Administration"].open_items[0]
        rows = [dict(PlanNumber=actual_plan, LotNumber=lot, Fund="Administration",
                     **{"Levy type": item.levy_type, "Levy category": item.category, "Due date": item.due_date},
                     LevyStartDate=item.levy_start_date, LevyEndDate=item.levy_end_date, Outstanding=item.amount)]
        self.assertTrue(v.validate_rows("levy", rows, plan, ["Administration"])["valid"])
        self.assertIn(plan, levy.generate_sql("dbo.URBANISE_LevyArrearsByLevyType", actual_plan, lot, states))

    def test_state_classification_has_no_saved_state_or_cross_call_effects(self):
        for kind in ("income", "budget", "levy"):
            mapping = "NOT_REQUIRED" if kind == "levy" else "PASS"
            self.assertEqual(v.state_from_evidence(kind, "MATCH", mapping, "MATCH", "MATCH"), "FINAL_COMPLETE")
            self.assertEqual(v.state_from_evidence(kind, "ABSENT", "NOT_REQUIRED" if kind == "levy" else
                             "NOT_CHECKED", "ABSENT", "ABSENT"), "NOT_STARTED")
            self.assertEqual(v.state_from_evidence(kind, "MATCH", mapping, "MATCH", "MISMATCH"), "PARTIAL_INCONSISTENT")
        for kind in ("income", "budget"):
            self.assertEqual(v.state_from_evidence(kind, "ABSENT", "PASS", "ABSENT", "ABSENT"), "PARTIAL_INCONSISTENT")
            self.assertEqual(v.state_from_evidence(kind, "MATCH", "PASS", "MATCH", "ABSENT",
                             blockers=["Missing authoritative company FY anchor"]), "BLOCKED")

    def test_mapping_cli_requires_company_provenance(self):
        evidence = dict(kind="income", rows=[dict(source_id=1, account_type="revenue",
                        candidate_mchids=[19021], MCHID=19021)], require_mapped=True)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "mapping.json"
            path.write_text(json.dumps(evidence), encoding="utf-8")
            before = path.read_bytes()
            output = io.StringIO()
            with patch.object(sys, "argv", ["validate_financial.py", "mapping", str(path)]), redirect_stdout(output):
                self.assertEqual(v.main(), 2)
            self.assertEqual(json.loads(output.getvalue())["status"], "BLOCKED")
            self.assertEqual(path.read_bytes(), before)
            self.assertEqual(list(Path(tmp).iterdir()), [path])

    def test_dev_paths_rejected_before_read_including_resolved_alias(self):
        for directory in ("dev_only", "DEV_ONLY", "tests", "fixtures"):
            with self.subTest(directory=directory), patch.object(Path, "resolve") as resolve:
                with self.assertRaisesRegex(ValueError, "DEV/test"):
                    v.input_path(Path("output") / directory / "nonexistent.json")
                resolve.assert_not_called()
        # Model a resolved filesystem alias without needing Windows symlink privileges.
        with patch.object(Path, "resolve", return_value=Path("output/dev_only/captured.json")):
            with self.assertRaisesRegex(ValueError, "DEV/test"):
                v.input_path("visible-alias.json")

    def test_runtime_guidance_and_validator_have_no_sample_defaults(self):
        for relative in ("SKILL.md", "references/workflow.md", "references/validation.md", "scripts/validate_financial.py"):
            source = (SKILL / relative).read_text(encoding="utf-8")
            for forbidden in ("PS732663R", "20460.70", "52004.35", "367561.77"):
                self.assertNotIn(forbidden.casefold(), source.casefold(), relative)

        skill = (SKILL / "SKILL.md").read_text(encoding="utf-8")
        self.assertIn("ABOVEOCM", skill)
        self.assertIn("dbo.Above_OCM_COA_Finalized", skill)
        self.assertIn("operator-friendly", skill)
        self.assertIn("native SQL MCP gate", skill)
        self.assertIn("do not repair it", skill)

    def test_validator_has_only_stateless_validation_capabilities(self):
        tree = ast.parse((SKILL / "scripts/validate_financial.py").read_text(encoding="utf-8"))
        allowed = {"__future__", "argparse", "collections", "datetime", "decimal", "json", "pathlib", "re", "pypdf"}
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                self.assertTrue(all(alias.name.split(".")[0] in allowed for alias in node.names))
            elif isinstance(node, ast.ImportFrom):
                self.assertIn(node.module.split(".")[0], allowed)
            elif isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
                self.assertNotIn(node.func.attr, {"execute", "execute_sql", "execute_sql_file", "run", "Popen",
                                                 "write_text", "write_bytes", "mkdir", "unlink", "rename"})


@unittest.skipUnless(all((ROOT / "pdf" / name).exists() for name in (
    "proposedAnnualBudget_120897289.pdf", "incomeAndExpenditureTransactionList_120897208.pdf",
    "levyStatement_120897251.pdf")), "Local reference PDFs unavailable")
class ExistingParserRegressionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        sys.path.insert(0, str(ROOT / "scripts"))

    def test_classify_existing_pdfs(self):
        from pypdf import PdfReader
        expected = {"levyStatement_120897251.pdf": "levy",
                    "incomeAndExpenditureTransactionList_120897208.pdf": "income",
                    "proposedAnnualBudget_120897289.pdf": "budget"}
        for name, kind in expected.items():
            text = "\n".join(p.extract_text() or "" for p in PdfReader(ROOT / "pdf" / name).pages)
            result = v.classify_text(text)
            self.assertTrue(result["valid"])
            self.assertEqual(result["type"], kind)
            self.assertEqual(result["plans"], ["PS732663R"])

    def test_income_reference_converter(self):
        from extract_urbanise_accounts import extract_accounts
        records = extract_accounts(ROOT / "pdf/incomeAndExpenditureTransactionList_120897208.pdf")
        rows = [dict(Plan_Number=r.plan_number, Fund_Name=r.fund_name, Account_Name=r.account_name,
                     AccountType=r.account_type, Amount=r.amount, Period_Start=r.period_start.isoformat(),
                     Period_End=r.period_end.isoformat()) for r in records]
        result = v.validate_rows("income", rows, "PS732663R", ["ADMINISTRATIVE FUND", "MAINTENANCE FUND", "CAPITAL WORKS FUND"])
        self.assertTrue(result["valid"], result)
        self.assertEqual(result["row_count"], 3)
        self.assertEqual(result["validated_total"], Decimal("52004.35"))

    def test_levy_reference_converter(self):
        import pdfplumber
        import levy_arrears_parser as levy
        rows = []
        with pdfplumber.open(ROOT / "pdf/levyStatement_120897251.pdf") as pdf:
            for _, pages in levy.group_pages_by_lot(pdf):
                plan, lot, balances = levy.extract_identity_and_balances(pages)
                states = levy.replay(levy.extract_transactions(pages))
                levy.validate(states, balances)
                for fund, state in states.items():
                    for item in state.open_items:
                        rows.append(dict(PlanNumber=plan, LotNumber=lot, Fund="Administration" if fund.startswith("Administration") else "Maintenance",
                                         **{"Levy type": item.levy_type, "Levy category": item.category, "Due date": item.due_date},
                                         LevyStartDate=item.levy_start_date, LevyEndDate=item.levy_end_date, Outstanding=item.amount))
        result = v.validate_rows("levy", rows, "PS732663R", ["Administration", "Maintenance"])
        self.assertTrue(result["valid"], result)
        self.assertEqual(result["row_count"], 22)
        self.assertEqual(result["validated_total"], Decimal("20460.70"))

    def test_budget_reference_grouping(self):
        import urbanise_budget_to_sql as budget
        from unittest.mock import patch
        captured = []
        original_render = budget.render_sql
        def capture(rows, name):
            captured.extend(rows)
            return original_render(rows, name)
        with tempfile.TemporaryDirectory() as tmp, patch.object(budget, "render_sql", capture):
            count, plan = budget.convert(ROOT / "pdf/proposedAnnualBudget_120897289.pdf", Path(tmp) / "budget.sql")
        rows = [dict(Plan_Number=r.plan_number, Fund_Name=r.fund_name, Account_Name=r.account_name,
                     Account_Type=r.account_type, Budget_EndDate=r.budget_end_date, Amount=r.amount) for r in captured]
        checked = v.validate_rows("budget", rows, plan, ["Administrative Fund"])
        self.assertTrue(checked["valid"], checked)
        self.assertEqual(count, 24)
        self.assertEqual(checked["validated_total"], Decimal("367561.77"))
        # Historical authoritative mapping and reconciled amounts: test data only.
        baseline = [
            (55, "General Repairs", "11000"), (71, "Budgeted levies to be raised", "191753.43"),
            (260, "Car Stacker", "5000"), (866, "Electrical Repairs", "7000"),
            (871, "Strata Manager - disbursements", "1760.09"), (2890, "Lift Maintenance", "12000"),
            (2970, "Administration", "930"), (3048, "Strata Manager - management fees", "9368.25"),
            (3051, "Garage Door Maintenance", "3500"), (4871, "Insurance Premiums", "36000"),
            (5012, "Accountant - BAS/IAS fees", "2000"), (5018, "Bank Fees & Charges - account keeping fees", "200"),
            (5018, "Bank Fees & Charges - DEFT fees", "50"), (5022, "Strata Manager - outgoings as per management authority", "7000"),
            (5032, "Automatic Door Maintenance", "1000"), (5033, "Fire Protection Services - monitoring", "2000"),
            (5034, "Fire Protection Services - inspection/testing services", "6500"), (5035, "Fire Protection Services - general repairs", "6000"),
            (5040, "Cleaning Service", "17000"), (5047, "Waste Management Services", "11500"),
            (5065, "Hot Water Systems", "3000"), (5066, "Plumbing & Drainage", "25000"),
            (5070, "Electricity", "4500"), (5073, "Water", "3500")]
        by_name = {name: mch for mch, name, _ in baseline}
        source = [{"MCHID": by_name[r["Account_Name"]], "Amount": r["Amount"]} for r in rows]
        final = [{"MCHID": mch, "Amount": total} for mch, _, total in baseline if mch != 5018]
        final.append({"MCHID": 5018, "Amount": "250.00"})
        checked = v.reconcile(source, final, ["MCHID"], grouped=True)
        self.assertTrue(checked["valid"], checked)
        self.assertEqual(checked["actual_rows"], 23)
        self.assertEqual(checked["difference"], Decimal(0))
        self.assertEqual(sorted(r["Amount"] for r in source if r["MCHID"] == 5018), [Decimal("50"), Decimal("200")])


if __name__ == "__main__":
    unittest.main(verbosity=2)
