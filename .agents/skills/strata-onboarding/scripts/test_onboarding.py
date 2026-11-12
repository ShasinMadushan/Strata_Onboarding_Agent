"""Local synthetic tests only. Never connect to SQL or run real onboarding."""
import copy
import csv
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import csv_batches as b
from validate_outputs import SCHEMAS, LOT_ADDRESS, pivot, validate
from prepare_sql import identifier, literal, prepare_staging_sql


class OnboardingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name).resolve()
        self.old_root = b.ROOT
        b.ROOT = self.root
        self.folder = self.root / "sources"
        self.folder.mkdir()
        self.address = {c: "" for c in LOT_ADDRESS}
        self.address.update(Lot_Address_Street_Number="15", Lot_Address_Street_Name="Example Road",
                            Lot_Address_Street_Suburb="Example", Lot_Address_Street_State="VIC",
                            Lot_Address_Street_PostCode="3000", Lot_Address_Country="Australia")
        owner = {c: "" for c in b.SIGNATURES["owners"]}
        owner.update(Lot_No="001", Unit="A", Lot_Liab="1", Lot_Ent="2", Owners_Name="O'Brien",
                     Owners_Address="15 Example Road, Example 3000", Owners_Email="owner@example.invalid",
                     Payment_Reference="00001")
        self.owner = owner
        self.write("owners", [owner])
        self.write("contacts", [])

    def tearDown(self):
        b.ROOT = self.old_root
        self.tmp.cleanup()

    def write(self, role, rows):
        p = self.folder / (role + ".csv")
        with p.open("w", encoding="utf-8", newline="") as stream:
            writer = csv.DictWriter(stream, fieldnames=sorted(b.SIGNATURES[role]))
            writer.writeheader()
            writer.writerows(rows)
        return p

    def run_path(self, run_id="test"):
        return b.initialize_run(str(self.folder), "TEST", 123, 69, run_id, self.address)["run_path"]

    def owner_record(self, source_id="owners:1", **changes):
        val = {c: "" for c in SCHEMAS["lot_owner"]}
        val.update(self.address)
        val.update(Lot_No="001", Unit="A", Lot_Liab="1", Lot_Ent="2", Payment_Reference="00001",
                   Contact_Type="Owner", Contact_Name="O'Brien", Contact_Email1="owner@example.invalid",
                   IsCommitteeContact="0", IsPropertyAgent="0", IsTenant="0",
                   IsOtherContact="0", IsOtherContact1="0", IsOtherContact2="0", IsOtherContact3="0")
        val.update(changes)
        return {"source_ids": [source_id], "values": val, "synthetic_reason": ""}

    def finish(self, run):
        b.save_validated_batch(run, "lot_owner", 1, [self.owner_record()], [])
        batch = b.read_batch(run, "compref", 1)
        rows = [r["values"] for r in batch["sources"]["lot_owner"]]
        rec = {"source_ids": [r["id"] for r in batch["sources"]["lot_owner"]],
               "values": pivot(rows)[0], "synthetic_reason": ""}
        b.save_validated_batch(run, "compref", 1, [rec], [])
        return b.assemble_outputs(run)

    def test_schema_sizes(self):
        self.assertEqual([len(SCHEMAS[k]) for k in ("lot_owner", "compref", "committee", "tenant")], [54, 16, 31, 29])

    def test_no_rows_dropped_or_merged(self):
        run = self.run_path()
        with self.assertRaisesRegex(ValueError, "dropped"):
            b.save_validated_batch(run, "lot_owner", 1, [], [])
        with self.assertRaisesRegex(ValueError, "dropped"):
            b.save_validated_batch(run, "lot_owner", 1, [self.owner_record(), self.owner_record()], [])

    def test_reject_missing_columns_and_nonstring_cells(self):
        run = self.run_path()
        bad = self.owner_record()
        bad["values"].pop("Contact_Mobile 2")
        with self.assertRaisesRegex(ValueError, "columns"):
            b.save_validated_batch(run, "lot_owner", 1, [bad], [])
        bad = self.owner_record()
        bad["values"]["Lot_Ent"] = 2
        with self.assertRaisesRegex(ValueError, "strings"):
            b.save_validated_batch(run, "lot_owner", 1, [bad], [])

    def test_complete_lots_and_leading_zero_preserved(self):
        rows = []
        for lot in ("001", "002", "003", "004"):
            primary = dict(self.owner, Lot_No=lot)
            rows += [primary, dict(primary, Owners_Name="Correspondence via email")]
        self.write("owners", rows)
        run = self.run_path()
        first = b.read_batch(run, "lot_owner", 1)
        second = b.read_batch(run, "lot_owner", 2)
        self.assertEqual(first["lots"], ["001", "002", "003"])
        self.assertEqual(len(first["sources"]["owners"]), 6)
        self.assertEqual(second["lots"], ["004"])

    def test_source_changes_invalidate_resume(self):
        run = self.run_path()
        self.write("owners", [dict(self.owner, Owners_Name="Changed")])
        with self.assertRaisesRegex(ValueError, "changed"):
            b.inspect_run(run)

    def test_incomplete_assembly_refused(self):
        with self.assertRaises(FileNotFoundError):
            b.assemble_outputs(self.run_path())

    def test_unavailable_tenant_cannot_stage(self):
        run = self.run_path()
        receipt = self.finish(run)
        self.assertEqual(receipt["outputs"]["tenant"]["status"], "unavailable")
        with self.assertRaisesRegex(ValueError, "excluded"):
            prepare_staging_sql(run, "tenant", "dbo")

    def test_sql_is_prepared_only_and_escaped(self):
        run = self.run_path()
        self.finish(run)
        result = prepare_staging_sql(run, "lot_owner", "dbo")
        sql = Path(result["file_path"]).read_text(encoding="utf-8")
        self.assertIn("O''Brien", sql)
        self.assertIn("N'001'", sql)
        self.assertIn("[Contact_Mobile 2]", sql)
        self.assertFalse(result["executed"])
        self.assertIn("BEGIN TRANSACTION", sql)
        self.assertNotIn("DROP TABLE", sql)

    def test_compref_exact_pivot_and_review_gate(self):
        run = self.run_path()
        b.save_validated_batch(run, "lot_owner", 1, [self.owner_record()], [])
        batch = b.read_batch(run, "compref", 1)
        rec = {"source_ids": ["lot_owner:1:1"], "values": pivot([self.owner_record()["values"]])[0], "synthetic_reason": ""}
        rec["values"]["Notice_Owner"] = "E"
        with self.assertRaisesRegex(ValueError, "pivot"):
            b.save_validated_batch(run, "compref", 1, [rec], [])
        self.finish(run)
        with self.assertRaisesRegex(ValueError, "review flags"):
            prepare_staging_sql(run, "compref", "dbo")
        result = prepare_staging_sql(run, "compref", "dbo", "User approved agent-only routing")
        sql = Path(result["file_path"]).read_text(encoding="utf-8")
        self.assertIn("User-approved review: User approved agent-only routing", sql)

    def test_failed_save_preserves_previous_batch(self):
        run = self.run_path()
        b.save_validated_batch(run, "lot_owner", 1, [self.owner_record()], [])
        path = Path(run) / "batches/lot_owner/1.json"
        before = path.read_bytes()
        with self.assertRaises(ValueError):
            b.save_validated_batch(run, "lot_owner", 1, [], [])
        self.assertEqual(before, path.read_bytes())

    def test_oversized_single_lot_fails_without_truncation(self):
        self.write("owners", [dict(self.owner, Owners_Address="X" * 25000)])
        with self.assertRaisesRegex(ValueError, "Single lot"):
            self.run_path()

    def test_contacts_only_agent_must_not_disappear(self):
        agent = {c: "" for c in b.SIGNATURES["contacts"]}
        agent.update(plan_no="TEST", lot="001", type="Letting Agent", name="Agency")
        self.write("contacts", [agent])
        run = self.run_path()
        with self.assertRaisesRegex(ValueError, "Agent omitted"):
            b.save_validated_batch(run, "lot_owner", 1, [self.owner_record()], [])

    def test_v29_lot201_routing_agent_fallback_and_contact_point_cap(self):
        primary = dict(self.owner, Lot_No="201", Owners_Name="Ian Richard Galloway & Catherine Elizabeth Galloway",
                       Owners_Address="10 Savannah Place, Chadstone VIC 3148", Owners_Email="owners@example.invalid")
        routing_owner = dict(primary, Owners_Name="Fee Notice via email",
                             Owners_Address="Ian Richard Galloway & Catherine Elizabeth Galloway, 10 Savannah Place, Chadstone VIC 3148")
        routing_new_owner_point = dict(primary, Owners_Name="Correspondence to",
                                       Owners_Address="Ian Richard Galloway & Catherine Elizabeth Galloway, 10 Savannah Place, Chadstone VIC 3148",
                                       Owners_Email="different@example.invalid")
        routing_agent = dict(primary, Owners_Name="Fee Notice via email", Owners_Address="Alice Agent,", Owners_Phone="", Owners_Email="")
        routing_second_agent = dict(primary, Owners_Name="Correspondence via email", Owners_Address="Alice Agent, 8 Different Road, Clayton VIC 3168",
                                    Owners_Phone="", Owners_Email="agent2@example.invalid")
        self.write("owners", [primary, routing_owner, routing_new_owner_point, routing_agent, routing_second_agent])
        occupier = {c: "" for c in b.SIGNATURES["occupiers"]}
        occupier.update(Lot_No="201", Unit="A", Owner_Occupier="NO", Name="Ian Galloway",
                        Mailing_Address="Ian Galloway, Unit 9 / 99 Example Street, Clayton VIC 3168")
        self.write("occupiers", [occupier])
        postal = {c: "" for c in b.SIGNATURES["contacts"]}
        postal.update(plan_no="TEST", lot="201", type="Letting Agent", contact="Postal Address", name="Alice Agent", suburb="Clayton", pcode="3168")
        address = dict(postal, contact="Address", address="5 Agent Road", phone="Home: 0412 000 000", email="agent@example.invalid")
        self.write("contacts", [postal, address])
        run = self.run_path("v29-lot201")
        converted = b.convert_lot_owner_batch(run, 1)
        self.assertEqual(converted["prompt_version"], "strata_conversion_system_prompt_v2.9")
        self.assertEqual(converted["summary"]["source_owner_rows"], 5)
        rows = [record["values"] for record in converted["records"]]
        self.assertEqual([row["Contact_Type"] for row in rows], ["Owner", "Owner", "Other1", "Agent", "Other2"])
        self.assertEqual(rows[3]["Contact_Address_Street_Number"], "5")
        self.assertEqual(rows[3]["Contact_Mobile"], "0412 000 000")
        self.assertEqual(rows[0]["Lot_Address_Street_Number"], "99")
        self.assertEqual(rows[3]["Lot_Address_Street_Number"], "99")
        self.assertTrue(any("Second distinct Agent" in flag["message"] for flag in converted["flags"]))
        b.save_validated_batch(run, "lot_owner", 1, converted["records"], converted["flags"])

    def test_v29_synthesized_agent_and_missing_supplementary_inputs(self):
        agent = {c: "" for c in b.SIGNATURES["contacts"]}
        agent.update(plan_no="TEST", lot="001", type="Letting Agent", contact="Address", name="Example Realty",
                     address="8 Agency Road", suburb="Example", pcode="3000", phone="Mobile: 0400 111 222", email="agent@example.invalid")
        self.write("contacts", [agent])
        run = self.run_path("v29-synth")
        converted = b.convert_lot_owner_batch(run, 1)
        synthetic = [record for record in converted["records"] if record["synthetic_reason"]]
        self.assertEqual(len(synthetic), 1)
        self.assertEqual(synthetic[0]["values"]["Contact_Type"], "Agent")
        self.assertEqual(synthetic[0]["values"]["Contact_Name"], "Example Realty")
        self.assertEqual(synthetic[0]["values"]["Agent_BusinessName"], "Example Realty")
        b.save_validated_batch(run, "lot_owner", 1, converted["records"], converted["flags"])
        Path(self.folder / "contacts.csv").unlink()
        missing_run = b.initialize_run(str(self.folder), "TEST", 123, 69, "v29-missing", self.address,
                                        contacts_missing_accepted=True)["run_path"]
        missing = b.convert_lot_owner_batch(missing_run, 1)
        self.assertEqual(missing["records"][0]["values"]["Lot address details"], "15 Example Road, Example VIC 3000")
        self.assertTrue(any("Current Contacts List missing" in flag["message"] for flag in missing["flags"]))

    def test_v29_prompt_hash_is_a_manifest_dependency(self):
        run = self.run_path("v29-hash")
        manifest = b.read_json(Path(run) / "manifest.json")
        self.assertEqual(manifest["lot_owner_conversion_prompt_sha256"], b.digest(b.ACTIVE_LOT_OWNER_PROMPT))

    def test_tenant_no_filter_and_street_validation(self):
        source = {c: "" for c in b.SIGNATURES["occupiers"]}
        source.update(Lot_No="001", Unit="A", Owner_Occupier="NO", Name="Person One & Person Two",
                      Mailing_Address="Person One, 3 / 15 Example Road, Example 3000")
        yes = dict(source, Owner_Occupier="YES")
        self.write("occupiers", [source, yes])
        run = self.run_path()
        values = {c: "" for c in SCHEMAS["tenant"]}
        values.update(Lot_No="001", Unit_No="A", Plan_No="TEST", SM_Is_TenantContact="1",
                      SM_Tenant_IsBusinessContact="0", SM_Tenant_ContactName=source["Name"], SM_Tenant_StreetNumber="15")
        rec = {"source_ids": ["occupiers:1"], "values": values, "synthetic_reason": ""}
        b.save_validated_batch(run, "tenant", 1, [rec], [])
        bad = copy.deepcopy(rec)
        bad["source_ids"] = ["occupiers:2"]
        with self.assertRaisesRegex(ValueError, "dropped"):
            b.save_validated_batch(run, "tenant", 1, [rec, bad], [])
        bad = copy.deepcopy(rec)
        bad["values"]["SM_Tenant_StreetNumber"] = "3"
        with self.assertRaisesRegex(ValueError, "street number"):
            b.save_validated_batch(run, "tenant", 1, [bad], [])

    def test_exclusion_matches_hash_even_when_renamed(self):
        from unittest.mock import patch
        path = self.folder / "renamed.csv"
        path.write_text("excluded fixture\n", encoding="utf-8")
        policy = self.root / "policy.json"
        policy.write_text(json.dumps({"excluded_sources": [{"workspace_path": "elsewhere.csv", "sha256": b.digest(path),
                                                          "reason": "Team identity question"}]}), encoding="utf-8")
        with patch.object(b, "POLICY", policy):
            result = b.inspect_plan(str(self.folder), "TEST")
        self.assertEqual(len(result["excluded_sources"]), 1)
        self.assertNotIn("occupiers", result["sources"])

    def test_paths_identifiers_and_new_run_names(self):
        with self.assertRaises(ValueError):
            b.local_path(self.root.parent)
        self.assertEqual(identifier("a]b"), "[a]]b]")
        self.assertEqual(literal("a'b"), "N'a''b'")
        first = self.run_path("one")
        second = self.run_path("two")
        self.assertNotEqual(b.read_json(Path(first) / "manifest.json")["table_map"],
                            b.read_json(Path(second) / "manifest.json")["table_map"])


    def test_edited_csv_refuses_sql_preparation(self):
        run = self.run_path()
        self.finish(run)
        path = Path(run) / "lot_owner.csv"
        path.write_text(path.read_text(encoding="utf-8") + "\n", encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "CSV changed"):
            prepare_staging_sql(run, "lot_owner", "dbo")

    def test_stored_flags_cannot_be_removed(self):
        run = self.run_path()
        flag = {"severity": "review", "source_ids": ["owners:1"], "message": "Review this interpretation"}
        b.save_validated_batch(run, "lot_owner", 1, [self.owner_record()], [flag])
        path = Path(run) / "batches/lot_owner/1.json"
        saved = b.read_json(path)
        saved["flags"] = []
        path.write_text(json.dumps(saved), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Stored flags"):
            b.inspect_run(run)

    def test_committee_preserves_multiple_members_and_name_spacing(self):
        source = {c: "" for c in b.SIGNATURES["committee"]}
        source.update(Lot="001", member_name="First  Member", date_of_appointment="22/02/2024")
        self.write("committee", [source, dict(source, member_name="Second Member")])
        run = self.run_path()
        records = []
        for i, name in enumerate(("First  Member", "Second Member"), 1):
            val = {c: "" for c in SCHEMAS["committee"]}
            val.update({"Lot No": "001", "Plan No": "TEST", "SM_Committee_ContactName": name,
                        "SM_Is_CommitteeContact": "1", "SM_Committee_IsBusinessContact": "0",
                        "SM_Committee_ManagementStartDate": "22/02/2024"})
            records.append({"source_ids": ["committee:" + str(i)], "values": val, "synthetic_reason": ""})
        b.save_validated_batch(run, "committee", 1, records, [])
        bad = copy.deepcopy(records)
        bad[0]["values"]["SM_Committee_ContactName"] = "First Member"
        with self.assertRaisesRegex(ValueError, "name altered"):
            b.save_validated_batch(run, "committee", 1, bad, [])

    def test_mcp_tool_module_loads(self):
        import onboarding_mcp
        self.assertIsNotNone(onboarding_mcp.mcp)


if __name__ == "__main__":
    unittest.main(verbosity=2)
