"""Deterministic implementation of prompts/strata_conversion_system_prompt_v2.9.md.

This module is deliberately local-only: it consumes one existing onboarding batch and
returns source-linked records/flags for the normal save_validated_batch step.  It does
not access a database, make web calls, or change the staging/import workflow.
"""
from __future__ import annotations

from collections import defaultdict
import json
from pathlib import Path
import re


PROMPT_VERSION = "strata_conversion_system_prompt_v2.9"
_SCHEMAS = json.loads((Path(__file__).resolve().parents[1] / "references" / "schemas.json").read_text(encoding="utf-8"))
SCHEMA = _SCHEMAS["lot_owner"]
LOT_ADDRESS = [name for name in SCHEMA if name.startswith("Lot_Address_")]
_TITLES = {"mr", "mrs", "ms", "miss", "dr", "mx"}
_BUSINESS_WORDS = ("property", "real estate", "realty", "strata", "placeholder", "pty", "agency", "group", "management", "estate agents")
_STATES = {"NSW", "VIC", "QLD", "WA", "SA", "TAS", "ACT", "NT"}


def _text(value: str | None) -> str:
    return (value or "").strip()


def _canon(value: str | None) -> str:
    value = re.sub(r"\([^)]*\)", "", _text(value)).casefold()
    value = re.sub(r"\b(?:mr|mrs|ms|miss|dr|mx)\.?\b", "", value)
    return " ".join(re.findall(r"[a-z0-9]+", value))


def _words(value: str | None) -> list[str]:
    return _canon(value).split()


def _is_business(value: str) -> bool:
    low = value.casefold()
    return " - " in value or any(word in low for word in _BUSINESS_WORDS)


def _person_parts(value: str) -> list[list[str]]:
    cleaned = re.sub(r"\([^)]*\)", "", value)
    cleaned = re.sub(r"\b(?:mr|mrs|ms|miss|dr|mx)\.?\b", "", cleaned, flags=re.I)
    return [_words(part) for part in re.split(r"\s*(?:&|\band\b)\s*", cleaned, flags=re.I) if _words(part)]


def _token_match(left: str, right: str) -> bool:
    return left == right or (min(len(left), len(right)) >= 3 and (left.startswith(right) or right.startswith(left)))


def _person_full_match(left: list[str], right: list[str]) -> bool:
    if not left or not right:
        return False
    # A person needs both an equivalent given token and an exact surname token.
    return left[-1] == right[-1] and any(_token_match(a, b) for a in left[:-1] for b in right[:-1])


def owner_name_match(routing: str, owner: str) -> bool:
    """The v2.9 Owner rule: one name component is not enough."""
    if not _text(routing) or not _text(owner):
        return False
    if _is_business(owner):
        return _canon(routing) == _canon(owner)
    owners, routes = _person_parts(owner), _person_parts(routing)
    if len(owners) > 1:
        # A routing row naming only one of several registered people is partial.
        return len(routes) == len(owners) and all(any(_person_full_match(r, o) for r in routes) for o in owners)
    return len(routes) == 1 and len(owners) == 1 and _person_full_match(routes[0], owners[0])


def name_match(left: str, right: str) -> bool:
    """Name match for Contacts/Committee lookups; not an Owner classification."""
    if not _text(left) or not _text(right):
        return False
    if _canon(left) == _canon(right):
        return True
    if _is_business(left) or _is_business(right):
        return False
    return any(_person_full_match(a, b) for a in _person_parts(left) for b in _person_parts(right))


def _state_from_postcode(postcode: str) -> str:
    if not re.fullmatch(r"\d{4}", postcode):
        return ""
    value = int(postcode)
    if value == 200 or 2600 <= value <= 2618 or 2900 <= value <= 2920:
        return "ACT"
    if 800 <= value <= 999:
        return "NT"
    if 1000 <= value <= 1999 or 2000 <= value <= 2599 or 2619 <= value <= 2899 or 2921 <= value <= 2999:
        return "NSW"
    if 3000 <= value <= 3999 or 8000 <= value <= 8999:
        return "VIC"
    if 4000 <= value <= 4999 or 9000 <= value <= 9999:
        return "QLD"
    if 5000 <= value <= 5799:
        return "SA"
    if 6000 <= value <= 6999:
        return "WA"
    if 7000 <= value <= 7999:
        return "TAS"
    return ""


def _box(value: str) -> tuple[str, str]:
    pattern = re.compile(r"^\s*(p\.?\s*o\.?\s*box|gpo\s*box|locked\s*bag|private\s*bag)\s*#?\s*([a-z0-9-]+)\b\s*,?\s*", re.I)
    found = pattern.match(value)
    if not found:
        return "", value.strip()
    label = re.sub(r"[.\s]+", " ", found.group(1)).strip().casefold()
    label = {"p o box": "PO Box", "po box": "PO Box", "gpo box": "GPO Box", "locked bag": "Locked Bag", "private bag": "Private Bag"}.get(label, label.title())
    return label + " " + found.group(2), value[found.end():].strip()


def parse_address(value: str, *, lot_address: bool = False) -> tuple[dict[str, str], list[str]]:
    """v2.9 address parser for contact or lot address fields."""
    original = _text(value)
    result = dict(Building_Name="", Street_Number="", Street_Name="", Street_Suburb="", Street_State="", Street_PostCode="", POBOX="", Country="")
    flags: list[str] = []
    if not original:
        return result, ["Blank address"]
    result["POBOX"], remainder = _box(original)
    segments = [item.strip() for item in remainder.split(",") if item.strip()]
    if not segments:
        return result, flags
    tail = segments.pop()
    postcode_match = re.search(r"(\d+)\s*$", tail)
    if postcode_match:
        postcode = postcode_match.group(1)
        suburb_state = tail[:postcode_match.start()].strip()
        # Sources sometimes put postcode in its own comma segment.
        if not suburb_state and segments:
            suburb_state = segments.pop().strip()
        result["Street_PostCode"] = postcode
        state_match = re.search(r"\b(NSW|VIC|QLD|WA|SA|TAS|ACT|NT)\b\s*$", suburb_state, re.I)
        if state_match:
            result["Street_State"] = state_match.group(1).upper()
            suburb_state = suburb_state[:state_match.start()].strip()
        elif len(postcode) == 4:
            result["Street_State"] = _state_from_postcode(postcode)
            if not result["Street_State"]:
                flags.append("State could not be determined from postcode")
        else:
            flags.append("Non-4-digit postcode; country/state need confirmation")
        result["Street_Suburb"] = suburb_state
        if len(postcode) == 4:
            result["Country"] = "Australia"
    else:
        result["Street_Suburb"] = tail
        flags.append("Address has no trailing postcode")
    street = ", ".join(segments).strip()
    if not street:
        return result, flags
    if re.search(r"\bc\s*/\s*-?\b|\bc\s*/\s*o\b", street, re.I):
        result["Street_Name"] = street
        flags.append("C/- address retained as free text")
        return result, flags
    # Worded sub-dwelling forms retain their wording for contact address numbers.
    worded = re.match(r"^(unit|apartment|apt|flat|villa|suite|u)\s*\.?\s*(\d+)\s*(?:/|,|\s+)\s*(.*)$", street, re.I)
    if worded:
        label = "Unit" if worded.group(1).casefold() == "u" else worded.group(1).title()
        unit, rest = label + " " + worded.group(2), worded.group(3).strip()
        number = re.match(r"^(\d+[A-Za-z]?(?:\s*-\s*\d+[A-Za-z]?)?)\s*(.*)$", rest)
        if lot_address:
            if number:
                result["Street_Number"] = re.sub(r"\s+", "", number.group(1))
                result["Street_Name"] = number.group(2).strip()
            else:
                result["Street_Name"] = rest
                flags.append("Lot unit prefix has no following street number")
        elif number:
            result["Street_Number"] = unit + "/" + re.sub(r"\s+", "", number.group(1))
            result["Street_Name"] = number.group(2).strip()
        else:
            result["Street_Number"] = unit
            result["Street_Name"] = rest
            flags.append("Unit prefix has no following street number")
        return result, flags
    numeric_unit = re.match(r"^(\d+)\s*/\s*(\d+[A-Za-z]?(?:\s*-\s*\d+[A-Za-z]?)?)\s*(.*)$", street)
    if numeric_unit:
        result["Street_Number"] = re.sub(r"\s+", "", numeric_unit.group(2) if lot_address else numeric_unit.group(1) + "/" + numeric_unit.group(2))
        result["Street_Name"] = numeric_unit.group(3).strip()
        return result, flags
    number = re.match(r"^(\d+[A-Za-z]?(?:\s*-\s*\d+[A-Za-z]?)?)\s*(.*)$", street)
    if number:
        result["Street_Number"] = re.sub(r"\s+", "", number.group(1))
        result["Street_Name"] = number.group(2).strip()
    else:
        result["Street_Name"] = street
        flags.append("Street number could not be split")
    return result, flags


def parse_phone(value: str) -> dict[str, str]:
    out = {"Contact_Mobile": "", "Contact_Mobile 2": "", "Contact_Mobile_Notes": "", "Contact_Landline1": "", "Contact_Landline1_Notes": "", "Contact_Landline2": "", "Contact_Landline2_Notes": ""}
    mobiles, lands, overflow = [], [], []
    for chunk in re.split(r"[;,]", value or ""):
        chunk = chunk.strip()
        if not chunk:
            continue
        label, number = (chunk.split(":", 1) + [""])[:2] if ":" in chunk else ("", chunk)
        label, number = label.strip(), number.strip()
        digits = re.sub(r"[\s-]", "", number)
        mobile = "mobile" in label.casefold() or digits.startswith(("04", "4"))
        (mobiles if mobile else lands).append((label, number))
    for index, (_, number) in enumerate(mobiles[:2]):
        out["Contact_Mobile" if index == 0 else "Contact_Mobile 2"] = number
    if len(mobiles) > 2:
        out["Contact_Mobile_Notes"] = "; ".join((label + ": " if label else "") + number for label, number in mobiles[2:])
    for index, (label, number) in enumerate(lands[:2]):
        out["Contact_Landline" + str(index + 1)] = number
        out["Contact_Landline" + str(index + 1) + "_Notes"] = label
    return out


def parse_email(value: str) -> dict[str, str]:
    entries = [item.strip() for item in (value or "").split(",") if item.strip()]
    return {"Contact_Email1": entries[0] if len(entries) > 0 else "", "Contact_Email2": entries[1] if len(entries) > 1 else "", "Contact_Email3": entries[2] if len(entries) > 2 else ""}


def _address_from_contact(row: dict[str, str]) -> str:
    return ", ".join(part for part in (_text(row.get("address")), _text(row.get("suburb")), _text(row.get("pcode"))) if part)


def _agent_candidates(contacts: list[dict], name: str) -> list[dict]:
    return [item for item in contacts if item["values"]["type"].casefold() == "letting agent" and name_match(name, item["values"]["name"])]


def _agent_fallback(candidates: list[dict]) -> tuple[dict[str, str], list[str], list[str]]:
    """Postal Address beats Address per field, with v2.9 field-level fallback."""
    postal = next((item for item in candidates if item["values"]["contact"].casefold() == "postal address"), None)
    address = next((item for item in candidates if item["values"]["contact"].casefold() == "address"), None)
    ids = [item["id"] for item in candidates]
    out, falls = {}, []
    for field in ("address", "suburb", "pcode", "phone", "email"):
        primary = _text(postal["values"].get(field)) if postal else ""
        secondary = _text(address["values"].get(field)) if address else ""
        out[field] = primary or secondary
        if postal and not primary and secondary:
            falls.append(field)
    out["combined_address"] = ", ".join(part for part in (out["address"], out["suburb"], out["pcode"]) if part)
    return out, ids, falls


def _agent_business(name: str, contacts: list[dict]) -> str:
    if _is_business(name):
        return name
    business = next((item["values"]["name"] for item in contacts if item["values"]["type"].casefold() == "letting agent" and _is_business(item["values"]["name"])), "")
    return business


def _routing_label(value: str) -> tuple[str, str]:
    low = value.casefold()
    if low.startswith("fee notice"):
        return "Fee Notice", "Email" if "via email" in low else "Post"
    if low.startswith("correspondence"):
        return "Correspondence", "Email" if "via email" in low else "Post"
    raise ValueError("Unrecognized routing label: " + value)


def _split_contact(value: str) -> tuple[str, str]:
    name, sep, address = (value or "").partition(",")
    return name.strip(), address.strip() if sep else ""


def _flag(flags: list[dict], severity: str, ids: list[str], message: str) -> None:
    item = {"severity": severity, "source_ids": ids, "message": message}
    if item not in flags:
        flags.append(item)


def convert(batch: dict) -> dict:
    if batch.get("kind") != "lot_owner":
        raise ValueError("v2.9 converter accepts only lot_owner batches")
    owners = batch["sources"].get("owners", [])
    by_lot: dict[str, list[dict]] = defaultdict(list)
    for item in owners:
        by_lot[item["values"]["Lot_No"]].append(item)
    contacts = batch["sources"].get("contacts", [])
    occupiers = batch["sources"].get("occupiers", [])
    committee = batch["sources"].get("committee", [])
    records: list[dict] = []
    flags: list[dict] = []
    synthesized = 0

    if not occupiers and batch.get("batch_id") == 1:
        _flag(flags, "review", [owners[0]["id"]], "Current Lot Occupiers missing: user-supplied building address applied; occupancy is blank")
    if not contacts and batch.get("batch_id") == 1:
        _flag(flags, "review", [owners[0]["id"]], "Current Contacts List missing: Agent/Tenant classification and Agent fallback are unavailable")

    for lot, block in by_lot.items():
        primary = block[0]
        source = primary["values"]
        lot_contacts = [item for item in contacts if item["values"]["lot"] == lot]
        lot_occupiers = [item for item in occupiers if item["values"]["Lot_No"] == lot]
        lot_committee = [item for item in committee if item["values"]["Lot"] == lot]
        known_people = [source["Owners_Name"]] + [item["values"]["Name"] for item in lot_occupiers]
        if lot_occupiers:
            occ = lot_occupiers[0]["values"]
            occ_value = occ["Owner_Occupier"].strip().upper()
            occupancy = "1" if occ_value == "YES" else "0" if occ_value == "NO" else ""
            if not occupancy:
                _flag(flags, "review", [lot_occupiers[0]["id"]], "Unrecognised Owner_Occupier value; left blank")
            raw_lot_address = occ["Mailing_Address"]
            first, comma, rest = raw_lot_address.partition(",")
            if comma and any(name_match(first, known) for known in known_people if known):
                raw_lot_address = rest.strip()
            postcode = re.search(r"\b\d{4}\b", raw_lot_address)
            if postcode:
                raw_lot_address = raw_lot_address[:postcode.end()]
            lot_parts, lot_notes = parse_address(raw_lot_address, lot_address=True)
            for note in lot_notes:
                _flag(flags, "review", [lot_occupiers[0]["id"]], "Lot address: " + note)
        else:
            occupancy = ""
            lot_parts = {name.removeprefix("Lot_Address_"): batch["building_address"].get(name, "") for name in LOT_ADDRESS}
            raw_lot_address = ", ".join(part for part in (
                (lot_parts["Street_Number"] + " " + lot_parts["Street_Name"]).strip(),
                (lot_parts["Street_Suburb"] + " " + lot_parts["Street_State"] + " " + lot_parts["Street_PostCode"]).strip(),
            ) if part)
        committee_names = [item["values"]["member_name"] for item in lot_committee]
        committee_positions = [item["values"]["position"] for item in lot_committee if _text(item["values"]["position"])]
        if not committee_names and _text(source["Committee_Member"]):
            pos, sep, name = source["Committee_Member"].partition(",")
            committee_positions = [_text(pos)] if _text(pos) else []
            committee_names = [_text(name)] if sep else [_text(pos)]
            _flag(flags, "info", [primary["id"]], "Committee report missing; inline Committee_Member used")
        executive = "; ".join(committee_positions)
        committee_name = "; ".join(committee_names)
        established_addresses = {_canon(source["Owners_Address"])} if _text(source["Owners_Address"]) else set()
        established_emails = {_canon(source["Owners_Email"])} if _text(source["Owners_Email"]) else set()
        other_types: dict[str, str] = {}
        agent_point: tuple[str, str, str] | None = None

        def values_for(contact_name: str, contact_type: str, communication: str, delivery: str,
                       address: str, phone: str, email: str, source_ids: list[str]) -> dict[str, str]:
            parsed, notes = parse_address(address)
            for note in notes:
                _flag(flags, "review", source_ids, "Contact address: " + note)
            values = {column: "" for column in SCHEMA}
            values.update(Lot_No=lot, Unit=source["Unit"], Lot_Liab=source["Lot_Liab"], Lot_Ent=source["Lot_Ent"],
                          Contact_Name=contact_name, Contact_Type=contact_type,
                          Contact_Communication_Type=communication, Contact_Delivery_Type=delivery,
                          Payment_Reference=source["Payment_Reference"], **{"Lot address details": raw_lot_address},
                          IsOwnerOccupied=occupancy, ExecutivePosition=executive, Committee_ContactName=committee_name)
            for key, value in parsed.items():
                values["Contact_Address_" + key] = value
            values["Contact_State_Code"] = parsed["Street_State"]
            values.update(parse_phone(phone), **parse_email(email))
            for key, value in lot_parts.items():
                values["Lot_Address_" + key] = value
            values["Agent_BusinessName"] = _agent_business(contact_name, lot_contacts) if contact_type == "Agent" else ""
            values["IsCommitteeContact"] = str(int(any(name_match(contact_name, item) for item in committee_names)))
            values["IsPropertyAgent"] = str(int(contact_type == "Agent"))
            values["IsTenant"] = str(int(contact_type == "Tenant"))
            for number in (1, 2, 3):
                values["IsOtherContact" + str(number)] = str(int(contact_type == "Other" + str(number)))
            values["IsOtherContact"] = str(int(contact_type.startswith("Other")))
            return values

        # Primary owner is unconditional and remains source-linked.
        records.append({"source_ids": [primary["id"]], "values": values_for(source["Owners_Name"], "Owner", "", "", source["Owners_Address"], source["Owners_Phone"], source["Owners_Email"], [primary["id"]]), "synthetic_reason": ""})

        for routing in block[1:]:
            row, source_id = routing["values"], routing["id"]
            communication, delivery = _routing_label(row["Owners_Name"])
            contact_name, address = _split_contact(row["Owners_Address"])
            email, phone = row["Owners_Email"], row["Owners_Phone"]
            if owner_name_match(contact_name, source["Owners_Name"]):
                address_ok = not _text(address) or _canon(address) in established_addresses
                email_ok = not _text(email) or _canon(email) in established_emails
                contact_type = "Owner" if address_ok and email_ok else ""
                if contact_type:
                    if _text(address):
                        established_addresses.add(_canon(address))
                    if _text(email):
                        established_emails.add(_canon(email))
                else:
                    _flag(flags, "review", [source_id], "Owner name matched but address/email is a new contact point; classified as Other")
            else:
                contact_type = ""
            agent_matches = _agent_candidates(lot_contacts, contact_name)
            if not contact_type and agent_matches:
                point = (_text(contact_name), _text(email), _text(address))
                if agent_point is None or point == agent_point:
                    contact_type = "Agent"
                    agent_point = point
                    fallback, fallback_ids, fallthrough = _agent_fallback(agent_matches)
                    if not _text(address):
                        address = fallback["combined_address"]
                    if not _text(phone):
                        phone = fallback["phone"]
                    if not _text(email):
                        email = fallback["email"]
                    if fallthrough:
                        _flag(flags, "review", [source_id] + fallback_ids, "Agent fallback used Address values for blank Postal Address field(s): " + ", ".join(fallthrough))
                    if (not _text(address) or not _text(phone) or not _text(email)) and not fallback_ids:
                        _flag(flags, "review", [source_id], "Agent fallback unavailable for blank contact field(s)")
                else:
                    contact_type = ""
                    _flag(flags, "review", [source_id], "Second distinct Agent contact point classified as Other under v2.9 Agent cap")
            if not contact_type and any(item["values"]["type"].casefold() == "tenant" and name_match(contact_name, item["values"]["name"]) for item in lot_contacts):
                contact_type = "Tenant"
            if not contact_type:
                key = _canon(contact_name) or ("blank-" + source_id)
                if key not in other_types:
                    other_types[key] = "Other" + str(min(len(other_types) + 1, 3))
                    if len(other_types) > 3:
                        _flag(flags, "review", [source_id], "More than three distinct Other contacts; Other3 slot reused to preserve routing row")
                contact_type = other_types[key]
            records.append({"source_ids": [source_id], "values": values_for(contact_name, contact_type, communication, delivery, address, phone, email, [source_id]), "synthetic_reason": ""})

        agent_sources = [item for item in lot_contacts if item["values"]["type"].casefold() == "letting agent"]
        if agent_sources and not any(record["values"]["Lot_No"] == lot and record["values"]["Contact_Type"] == "Agent" for record in records):
            agent = agent_sources[0]
            fallback, ids, fallthrough = _agent_fallback(_agent_candidates(lot_contacts, agent["values"]["name"]))
            values = values_for(agent["values"]["name"], "Agent", "", "", fallback["combined_address"], fallback["phone"], fallback["email"], ids)
            records.append({"source_ids": ids or [agent["id"]], "values": values, "synthetic_reason": "Contacts List Letting Agent had no classified routing row"})
            synthesized += 1
            if fallthrough:
                _flag(flags, "review", ids, "Synthesized Agent fallback used Address values for blank Postal Address field(s): " + ", ".join(fallthrough))

        lot_records = [record for record in records if record["values"]["Lot_No"] == lot]
        for communication, prefix in (("Fee Notice", "FeeNotice"), ("Correspondence", "Correspondence")):
            routed = [record["values"] for record in lot_records if record["values"]["Contact_Communication_Type"] == communication]
            kinds = {item["Contact_Type"] for item in routed}
            share = "" if not kinds else next(iter(kinds)) if len(kinds) == 1 else "Both"
            delivery_set = {item["Contact_Delivery_Type"] for item in routed}
            if communication == "Fee Notice" and not routed:
                delivery_set = {item["values"]["Contact_Delivery_Type"] for item in lot_records
                                if item["values"]["Contact_Communication_Type"] == "Correspondence"}
            issue = "".join(code for value, code in (("Email", "E"), ("Post", "P")) if value in delivery_set)
            for record in lot_records:
                record["values"][prefix + "ContactShare"] = share
                record["values"][prefix + "Issue"] = issue
        for record in lot_records:
            record["values"]["NoticeShare"] = record["values"]["CorrespondenceContactShare"]
            record["values"]["NoticeIssue"] = record["values"]["CorrespondenceIssue"]

    return {"prompt_version": PROMPT_VERSION, "records": records, "flags": flags,
            "summary": {"lots": len(by_lot), "source_owner_rows": len(owners), "output_rows": len(records), "synthesized_agents": synthesized}}
