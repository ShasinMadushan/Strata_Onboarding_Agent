"""Mechanical validation only. Conversion semantics remain in the four skills."""
from collections import Counter
from datetime import datetime
import json
from pathlib import Path
import re

KINDS = ("lot_owner", "compref", "committee", "tenant")
TYPES = ("Owner", "Agent", "Other1", "Other2", "Other3")
SCHEMAS = json.loads((Path(__file__).resolve().parents[1] / "references" / "schemas.json").read_text(encoding="utf-8"))
LOT_ADDRESS = [c for c in SCHEMAS["lot_owner"] if c.startswith("Lot_Address_")]


def require(condition, message):
    if not condition:
        raise ValueError(message)


def lot_of(row, role):
    return row["Lot" if role == "committee" else "lot" if role == "contacts" else "Lot_No"]


def pivot(rows):
    result = []
    for lot in dict.fromkeys(r["Lot_No"] for r in rows):
        out = {"Lot_No": lot}
        for ct in TYPES:
            for comm, prefix in (("Fee Notice", "FeeNotice"), ("Correspondence", "Correspondence")):
                delivery = {r["Contact_Delivery_Type"] for r in rows
                            if r["Lot_No"] == lot and r["Contact_Type"] == ct
                            and r["Contact_Communication_Type"] == comm}
                require(delivery <= {"Email", "Post"}, "Unexpected delivery method")
                out[prefix + "_" + ct] = "".join(c for v, c in (("Email", "E"), ("Post", "P")) if v in delivery)
            out["Notice_" + ct] = out["Correspondence_" + ct]
        result.append(out)
    return result


def validate(batch, records, flags):
    kind = batch["kind"]
    require(kind in KINDS, "Unknown kind")
    require(isinstance(records, list) and isinstance(flags, list), "records/flags must be lists")
    available = {r["id"]: r for rows in batch["sources"].values() for r in rows}
    for flag in flags:
        require(set(flag) == {"severity", "source_ids", "message"}, "Invalid flag fields")
        require(flag["severity"] in ("info", "review", "blocking"), "Invalid flag severity")
        require(isinstance(flag["message"], str) and bool(flag["message"].strip()), "Empty flag")
        require(isinstance(flag["source_ids"], list) and all(i in available for i in flag["source_ids"]), "Unknown flag source ID")
        require(flag["severity"] != "blocking", "Blocking flag: " + flag["message"])

    for rec in records:
        require(set(rec) == {"values", "source_ids", "synthetic_reason"}, "Invalid record envelope")
        require(isinstance(rec["values"], dict), "values must be an object")
        require(set(rec["values"]) == set(SCHEMAS[kind]), "Missing or extra output columns")
        require(all(isinstance(v, str) for v in rec["values"].values()), "All cells must be strings")
        require(isinstance(rec["source_ids"], list) and bool(rec["source_ids"]), "Source IDs required")
        require(all(isinstance(i, str) and i in available for i in rec["source_ids"]), "Unknown source ID")
        require(len(set(rec["source_ids"])) == len(rec["source_ids"]), "Duplicate ID in one record")
        require(isinstance(rec["synthetic_reason"], str), "Invalid synthetic reason")

    generated_flags = []
    if kind == "compref":
        require(not any(r["synthetic_reason"] for r in records), "Pivot rows cannot be synthetic")
        inputs = batch["sources"]["lot_owner"]
        rows = [r["values"] for r in inputs]
        tenants = [r for r in inputs if r["values"]["Contact_Type"] == "Tenant"]
        require(not tenants or batch["tenant_communication_decision"] == "exclude",
                "Tenant communications require explicit user disposition before pivot")
        expected = pivot(rows)
        require([r["values"] for r in records] == expected, "ComPref differs from the exact source pivot/order")
        for rec in records:
            ids = [r["id"] for r in inputs if r["values"]["Lot_No"] == rec["values"]["Lot_No"]]
            require(rec["source_ids"] == ids, "ComPref must account for ALL source rows of its lot")
            val = rec["values"]
            if not val["FeeNotice_Owner"] and not val["Correspondence_Owner"]:
                generated_flags.append({"severity": "review", "source_ids": ids, "message": "Owner has no communication method"})
        if tenants:
            generated_flags.append({"severity": "info", "source_ids": [r["id"] for r in tenants],
                                    "message": "Tenant communication rows explicitly excluded by user decision"})
        mixed = [r for r in records if "EP" in r["values"].values()]
        if mixed:
            generated_flags.append({"severity": "review", "source_ids": [i for r in mixed for i in r["source_ids"]],
                                    "message": "Mixed email/post cells: " + str(sum(list(r["values"].values()).count("EP") for r in mixed))})
    else:
        source_role = {"lot_owner": "owners", "committee": "committee", "tenant": "occupiers"}[kind]
        inputs = batch["sources"][source_role]
        if kind == "tenant":
            require(all(r["values"]["Owner_Occupier"].strip().upper() in ("YES", "NO") for r in inputs),
                    "Unrecognized occupancy: resolve before converting tenants")
            inputs = [r for r in inputs if r["values"]["Owner_Occupier"].strip().upper() == "NO"]
        expected_ids = [r["id"] for r in inputs]
        normal = [r for r in records if not r["synthetic_reason"]]
        require(all(len(r["source_ids"]) == 1 for r in normal), "Each normal record maps to exactly one source row")
        actual_ids = [r["source_ids"][0] for r in normal]
        require(Counter(actual_ids) == Counter(expected_ids), "Source rows dropped, duplicated or merged")
        require(actual_ids == expected_ids, "Source order changed")
        require(kind == "lot_owner" or len(normal) == len(records), "Only Agent additions can be synthetic")
        for rec in normal:
            row = rec["values"]
            source = available[rec["source_ids"][0]]["values"]
            key = "Lot No" if kind == "committee" else "Lot_No"
            require(row[key] == lot_of(source, source_role), "Lot ID changed")
            if kind == "committee":
                require(row["Plan No"] == batch["plan_number"], "Wrong plan")
                require(row["SM_Committee_ContactName"] == source["member_name"], "Committee name altered")
                require(row["SM_Is_CommitteeContact"] == "1" and row["SNG_CommitteeContactID"] == "", "Invalid committee flags/ID")
                require(row["SM_Committee_IsBusinessContact"] in ("0", "1"), "Invalid committee business bit")
                date = source["date_of_appointment"].strip()
                if date:
                    try:
                        expected_date = datetime.strptime(date, "%d/%m/%Y").strftime("%d/%m/%Y")
                    except ValueError:
                        raise ValueError("Appointment date format needs explicit resolution")
                    require(row["SM_Committee_ManagementStartDate"] == expected_date, "Appointment date changed")
                else:
                    require(row["SM_Committee_ManagementStartDate"] == "", "Invented appointment date")
                require("/" not in row["SM_Committee_StreetNumber"], "Committee unit folded into street number")
            elif kind == "tenant":
                require(row["Plan_No"] == batch["plan_number"] and row["Unit_No"] == source["Unit"], "Tenant plan/unit changed")
                require(row["SM_Is_TenantContact"] == "1" and row["SM_Tenant_IsBusinessContact"] in ("0", "1"), "Invalid tenant bits")
                require(row["SM_Tenant_OtherNames"] == "", "Do not split co-occupier names")
                require("/" not in row["SM_Tenant_StreetNumber"], "Tenant unit folded into street number")
                street = re.search(r"/\s*([0-9]+[A-Za-z]?(?:\s*-\s*[0-9]+[A-Za-z]?)?)", source["Mailing_Address"])
                if street:
                    require(row["SM_Tenant_StreetNumber"] == re.sub(r"\s+", "", street.group(1)), "Tenant street number differs from source")
                if row["SM_Tenant_IsBusinessContact"] == "0":
                    require(row["SM_Tenant_ContactName"] == source["Name"], "Tenant name/co-occupiers altered")
                else:
                    require(row["SM_Tenant_BusinessName"] == source["Name"], "Tenant business name altered")

        if kind == "lot_owner":
            rows = [r["values"] for r in records]
            first = {}
            for item in inputs:
                first.setdefault(item["values"]["Lot_No"], item)
            for rec in normal:
                val = rec["values"]
                src = available[rec["source_ids"][0]]["values"]
                primary = first[val["Lot_No"]]
                if rec["source_ids"][0] == primary["id"]:
                    require(val["Contact_Type"] == "Owner" and not val["Contact_Communication_Type"]
                            and not val["Contact_Delivery_Type"], "Primary Owner omitted or changed")
                    require(val["Contact_Name"] == src["Owners_Name"], "Primary owner name changed")
                else:
                    label = src["Owners_Name"]
                    comm = "Fee Notice" if label.startswith("Fee Notice") else "Correspondence" if label.startswith("Correspondence") else None
                    require(comm is not None, "Unrecognized routing label needs resolution")
                    require(val["Contact_Communication_Type"] == comm, "Routing communication changed")
                    require(val["Contact_Delivery_Type"] == ("Email" if "via email" in label.lower() else "Post"), "Routing delivery changed")
                for col in ("Unit", "Lot_Liab", "Lot_Ent", "Payment_Reference"):
                    require(val[col] == primary["values"][col], "Lot-level field changed: " + col)
            for rec in records:
                val = rec["values"]
                require(val["Lot_No"] in first, "Unexpected output lot")
                require(val["Contact_Type"] in TYPES + ("Tenant",), "Unsupported contact type/overflow")
                require(val["Contact_State_Code"] == val["Contact_Address_Street_State"], "Contact state copies differ")
                require(val["IsOwnerOccupied"] in ("", "0", "1"), "Invalid occupancy bit")
                for field, typ in (("IsPropertyAgent", "Agent"), ("IsTenant", "Tenant"),
                                   ("IsOtherContact1", "Other1"), ("IsOtherContact2", "Other2"), ("IsOtherContact3", "Other3")):
                    require(val[field] == str(int(val["Contact_Type"] == typ)), "Contact flag mismatch: " + field)
                require(val["IsOtherContact"] == str(int(val["Contact_Type"] in ("Other1", "Other2", "Other3"))), "Other flag mismatch")
                require(val["IsCommitteeContact"] in ("0", "1"), "Invalid committee bit")
                if rec["synthetic_reason"]:
                    require(val["Contact_Type"] == "Agent" and not val["Contact_Communication_Type"]
                            and not val["Contact_Delivery_Type"], "Invalid synthesized row")
                    require(all(i.startswith("contacts:") and available[i]["values"]["lot"] == val["Lot_No"]
                                and available[i]["values"]["type"] == "Letting Agent" for i in rec["source_ids"]),
                            "Synthetic Agent needs matching Contacts evidence")
                    require(any(available[i]["values"]["name"].strip() == val["Contact_Name"].strip() for i in rec["source_ids"]),
                            "Synthetic Agent name lacks source evidence")
                    generated_flags.append({"severity": "info", "source_ids": rec["source_ids"],
                                            "message": "Synthesized Agent: " + rec["synthetic_reason"]})
            for lot in first:
                lr = [r for r in rows if r["Lot_No"] == lot]
                require(sum(r["Contact_Type"] == "Owner" and not r["Contact_Communication_Type"] for r in lr) == 1, "Primary Owner cardinality")
                require(len({r["Contact_Name"].strip() for r in lr if r["Contact_Type"] == "Agent"}) <= 1, "More than one Agent per lot")
                synthetic = [r for r in records if r["values"]["Lot_No"] == lot and r["synthetic_reason"]]
                require(len(synthetic) <= 1, "More than one synthesized Agent per lot")
                if synthetic:
                    require(not any(r["Contact_Type"] == "Agent" and r["Contact_Communication_Type"] for r in lr), "Unneeded synthesized Agent")
                has_agent = any(r["values"]["lot"] == lot and r["values"]["type"] == "Letting Agent"
                                for r in batch["sources"].get("contacts", []))
                require(not has_agent or any(r["Contact_Type"] == "Agent" for r in lr), "Contacts-only Agent omitted")
                for field in LOT_ADDRESS + ["IsOwnerOccupied"]:
                    require(len({r[field] for r in lr}) == 1, "Inconsistent lot field: " + field)
                if not batch["occupiers_available"]:
                    require(batch["building_address"], "User-provided building address required")
                    require(all(lr[0][k] == v for k, v in batch["building_address"].items()), "Building fallback mismatch")
                    require(lr[0]["IsOwnerOccupied"] == "", "Occupancy must be unknown without occupiers")
                for comm, prefix in (("Fee Notice", "FeeNotice"), ("Correspondence", "Correspondence")):
                    cr = [r for r in lr if r["Contact_Communication_Type"] == comm]
                    types = {r["Contact_Type"] for r in cr}
                    share = "" if not types else next(iter(types)) if len(types) == 1 else "Both"
                    delivery = {r["Contact_Delivery_Type"] for r in cr}
                    if comm == "Fee Notice" and not cr:
                        delivery = {r["Contact_Delivery_Type"] for r in lr if r["Contact_Communication_Type"] == "Correspondence"}
                    issue = "".join(c for v, c in (("Email", "E"), ("Post", "P")) if v in delivery)
                    require(all(r[prefix + "ContactShare"] == share and r[prefix + "Issue"] == issue for r in lr), "Lot share/issue mismatch")
                require(all(r["NoticeShare"] == r["CorrespondenceContactShare"] and r["NoticeIssue"] == r["CorrespondenceIssue"] for r in lr),
                        "Notice copies differ")
    return flags + generated_flags
