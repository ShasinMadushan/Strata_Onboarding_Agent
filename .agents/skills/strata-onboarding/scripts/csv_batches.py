"""Bounded local CSV operations; no model calls and no database access."""
import csv
import hashlib
import io
import json
import os
from pathlib import Path
import re
from validate_outputs import KINDS, SCHEMAS, LOT_ADDRESS, require, lot_of, validate

SKILL = Path(__file__).resolve().parents[1]
SKILLS = SKILL.parent
ROOT = SKILL.parents[2]
POLICY = SKILL / "references" / "data-exclusions.json"
ACTIVE_LOT_OWNER_PROMPT = ROOT / "prompts" / "strata_conversion_system_prompt_v2.9.md"
MAX_CHARS = 24000
SIGNATURES = {
    "owners": {"Lot_No", "Unit", "Lot_Liab", "Lot_Ent", "Owners_Name", "Owners_Address",
               "Owners_Phone", "Owners_Email", "Committee_Member", "Balance", "Payment_Reference"},
    "contacts": {"plan_no", "building_no", "floor", "lot", "unit", "type", "contact", "name", "address",
                 "suburb", "pcode", "phone", "email", "levy_delivery", "correspondence_delivery"},
    "committee": {"member_name", "Lot", "date_of_appointment", "class", "position", "address", "phone", "email", "subcommname"},
    "occupiers": {"Lot_No", "Unit", "Owner_Occupier", "Name", "Mailing_Address", "Lease_Type", "Lease_Period", "Lease_Date", "Owners_Phone", "Owners_Email"},
}
SPEC_SKILLS = {"lot_owner": "strata-lot-owner", "compref": "strata-communication-preferences",
               "committee": "strata-committee", "tenant": "strata-tenants"}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def safe_token(value):
    require(isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,63}", value), "Unsafe or empty plan/run identifier")
    return value


def local_path(value, base=None):
    p = Path(value)
    p = (base or ROOT) / p if not p.is_absolute() else p
    p = p.resolve()
    require(p.is_relative_to(ROOT.resolve()), "Path outside workspace")
    return p


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def atomic_json(path, data):
    atomic_text(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def atomic_text(path, value):
    path = local_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + ".tmp")
    # Refuse an existing temp rather than overwrite another call's pending artifact.
    with temp.open("x", encoding="utf-8", newline="") as stream:
        stream.write(value)
    os.replace(temp, path)


def read_csv(path):
    with Path(path).open(encoding="utf-8-sig", newline="") as stream:
        reader = csv.DictReader(stream)
        headers = reader.fieldnames or []
        require(headers and len(set(headers)) == len(headers), "Missing/duplicate CSV headers")
        rows = []
        for row in reader:
            require(None not in row and all(v is not None for v in row.values()), "Malformed CSV row width")
            if any(v.strip() for v in row.values()):
                rows.append(row)
        return headers, rows


def resources():
    paths = [POLICY, SKILL / "references" / "schemas.json"]
    paths += [SKILLS / skill / "references" / "conversion-spec.md" for skill in SPEC_SKILLS.values()]
    # The canonical v2.9 prompt is a run dependency, not a passive copy.
    paths.append(ACTIVE_LOT_OWNER_PROMPT)
    return {str(p): digest(p) for p in paths}


def _scan(plan_folder, plan_number):
    folder = local_path(plan_folder)
    safe_token(plan_number)
    require(folder.is_dir(), "Plan folder does not exist")
    rules = read_json(POLICY)["excluded_sources"]
    files, data, excluded, warnings, ignored = {}, {}, [], [], []
    for path in sorted(folder.rglob("*.csv")):
        path = local_path(path)
        sha = digest(path)
        rel = path.relative_to(ROOT.resolve()).as_posix()
        rule = next((r for r in rules if r["sha256"] == sha or r["workspace_path"].casefold() == rel.casefold()), None)
        if rule:
            excluded.append({"path": str(path), "sha256": sha, "reason": rule["reason"], "status": "team_identity_question"})
            continue
        headers, rows = read_csv(path)
        role = next((k for k, required in SIGNATURES.items() if set(headers) == required), None)
        if not role:
            ignored.append(str(path))
            continue
        require(role not in files, "Multiple candidate files for " + role + "; choose an unambiguous source folder")
        key = "Lot" if role == "committee" else "lot" if role == "contacts" else "Lot_No"
        require(all(r[key].strip() for r in rows), "Blank lot identifier in " + role)
        if role == "contacts":
            require(all(r["plan_no"].strip() == plan_number for r in rows), "Contacts plan mismatch")
        files[role] = {"path": str(path), "sha256": sha, "rows": len(rows), "headers": headers}
        data[role] = [{"id": role + ":" + str(n), "values": r} for n, r in enumerate(rows, 1)]
    require("owners" in files and files["owners"]["rows"] > 0, "Owners report required and must contain data")
    owners_lots = list(dict.fromkeys(r["values"]["Lot_No"] for r in data["owners"]))
    seen, previous = set(), None
    for item in data["owners"]:
        lot = item["values"]["Lot_No"]
        if lot != previous:
            require(lot not in seen, "Noncontiguous duplicate owners lot block: " + lot)
            seen.add(lot)
            previous = lot
    for role in ("committee", "occupiers", "contacts"):
        unexpected = sorted({lot_of(r["values"], role) for r in data.get(role, [])} - set(owners_lots))
        if unexpected:
            warnings.append(role + " has lots absent from owners: " + ", ".join(unexpected))
    if "occupiers" not in files:
        warnings.append("Occupiers unavailable: building address must come from user; tenant staging blocked")
    if "committee" not in files:
        warnings.append("Committee unavailable: standalone committee staging blocked; use inline owner fields only as specified")
    return {"plan_number": plan_number, "plan_folder": str(folder), "sources": files,
            "excluded_sources": excluded, "warnings": warnings, "ignored_csvs": ignored, "lots": owners_lots}, data


def inspect_plan(plan_folder, plan_number):
    return _scan(plan_folder, plan_number)[0]


def _source_subset(data, lots, kind):
    roles = ("owners", "contacts", "committee", "occupiers") if kind == "lot_owner" else (("committee",) if kind == "committee" else ("occupiers",))
    return {role: [r for r in data.get(role, []) if lot_of(r["values"], role) in lots] for role in roles}


def _schedule(data, kind):
    role = {"lot_owner": "owners", "committee": "committee", "tenant": "occupiers"}[kind]
    lots = list(dict.fromkeys(lot_of(r["values"], role) for r in data.get(role, [])))
    groups, current = [], []
    for lot in lots:
        candidate = current + [lot]
        size = len(json.dumps(_source_subset(data, candidate, kind), ensure_ascii=False))
        if len(candidate) > 3 or size > MAX_CHARS:
            if current:
                groups.append(current)
            current = [lot]
            require(len(json.dumps(_source_subset(data, current, kind), ensure_ascii=False)) <= MAX_CHARS,
                    "Single lot exceeds batch character ceiling; no truncation permitted: " + lot)
        else:
            current = candidate
    if current:
        groups.append(current)
    return groups


def initialize_run(plan_folder, plan_number, property_id, managing_scope, run_id,
                   building_address=None, contacts_missing_accepted=False, tenant_communication_decision=""):
    safe_token(run_id)
    require(type(property_id) is int and property_id > 0, "Positive actual property_id required")
    require(type(managing_scope) is int and managing_scope > 0, "Positive actual managing_scope required")
    require(tenant_communication_decision in ("", "exclude"), "Invalid Tenant communication decision")
    inventory, data = _scan(plan_folder, plan_number)
    require(not inventory["ignored_csvs"], "Unrecognized CSVs require explicit source selection")
    # Unmatched supplementary records are retained in inventory; do not silently stage them.
    require(not any("has lots absent" in w for w in inventory["warnings"]), "Supplementary lot mismatch requires source identity resolution")
    building_address = building_address or {}
    require(not building_address or (set(building_address) == set(LOT_ADDRESS)
            and all(isinstance(v, str) for v in building_address.values())), "Invalid building address fields")
    require("contacts" in data or contacts_missing_accepted, "Missing Contacts requires user's explicit acceptance")
    schedules = {k: _schedule(data, k) for k in ("lot_owner", "committee", "tenant")}
    schedules["compref"] = schedules["lot_owner"]
    token = re.sub(r"[^A-Za-z0-9_]", "_", plan_number)[:30]
    suffix = hashlib.sha256((plan_number + "\0" + str(property_id) + "\0" + run_id).encode()).hexdigest()[:16]
    table_map = {k: "onb_" + token + "_" + str(property_id) + "_" + suffix + "_" + k for k in KINDS + ("master",)}
    run = local_path(ROOT / "output" / plan_number / run_id)
    require(not run.exists(), "Run already exists; inspect/resume or choose a new run_id")
    manifest = dict(inventory, version=2, property_id=property_id, managing_scope=managing_scope,
                    run_id=run_id, resources=resources(), schedules=schedules, table_map=table_map,
                    building_address=building_address, contacts_missing_accepted=contacts_missing_accepted,
                    tenant_communication_decision=tenant_communication_decision,
                    lot_owner_conversion_prompt=str(ACTIVE_LOT_OWNER_PROMPT),
                    lot_owner_conversion_prompt_sha256=digest(ACTIVE_LOT_OWNER_PROMPT))
    run.mkdir(parents=True)
    atomic_json(run / "manifest.json", manifest)
    return {"run_path": str(run), "schedules": schedules, "warnings": inventory["warnings"],
            "excluded_sources": inventory["excluded_sources"], "table_map": table_map}


def _load(run_path):
    run = local_path(run_path)
    require(run.is_relative_to((ROOT / "output").resolve()), "Run must be under workspace output")
    manifest = read_json(run / "manifest.json")
    require(manifest["version"] == 2, "Unsupported manifest; start a v2.9 conversion run")
    require(manifest["resources"] == resources(), "Specs/schema/exclusion policy changed; start a new run")
    inventory, data = _scan(manifest["plan_folder"], manifest["plan_number"])
    require(inventory["sources"] == manifest["sources"] and inventory["excluded_sources"] == manifest["excluded_sources"],
            "Source files changed; start a new run")
    return run, manifest, data


def _batch(run, manifest, data, kind, batch_id):
    require(kind in KINDS and type(batch_id) is int, "Invalid kind/batch_id")
    schedule = manifest["schedules"][kind]
    require(1 <= batch_id <= len(schedule), "Batch unavailable or index out of range")
    lots = schedule[batch_id - 1]
    if kind == "compref":
        previous = _read_saved(run, manifest, data, "lot_owner", batch_id)
        sources = {"lot_owner": [{"id": "lot_owner:" + str(batch_id) + ":" + str(i), "values": {c: r["values"][c] for c in ("Lot_No", "Contact_Type", "Contact_Communication_Type", "Contact_Delivery_Type")}}
                                for i, r in enumerate(previous["records"], 1)]}
    else:
        sources = _source_subset(data, lots, kind)
    result = {"kind": kind, "batch_id": batch_id, "plan_number": manifest["plan_number"], "lots": lots,
              "schema": SCHEMAS[kind], "sources": sources, "building_address": manifest["building_address"],
              "occupiers_available": "occupiers" in manifest["sources"],
              "tenant_communication_decision": manifest["tenant_communication_decision"],
              "lot_owner_conversion_prompt": manifest["lot_owner_conversion_prompt"],
              "lot_owner_conversion_prompt_sha256": manifest["lot_owner_conversion_prompt_sha256"]}
    require(len(json.dumps(sources, ensure_ascii=False)) <= MAX_CHARS, "Source payload exceeds ceiling; no truncated read")
    return result


def read_batch(run_path, kind, batch_id):
    run, manifest, data = _load(run_path)
    return _batch(run, manifest, data, kind, batch_id)


def convert_lot_owner_batch(run_path, batch_id):
    """Run the canonical v2.9 lot/contact converter for one existing bounded batch."""
    run, manifest, data = _load(run_path)
    batch = _batch(run, manifest, data, "lot_owner", batch_id)
    from lot_owner_v29 import PROMPT_VERSION, convert
    result = convert(batch)
    require(result["prompt_version"] == PROMPT_VERSION, "Unexpected lot-owner conversion implementation")
    return result


def _saved_path(run, kind, batch_id):
    require(kind in KINDS and type(batch_id) is int and batch_id >= 1, "Invalid batch path")
    return run / "batches" / kind / (str(batch_id) + ".json")


def _read_saved(run, manifest, data, kind, batch_id):
    saved = read_json(_saved_path(run, kind, batch_id))
    batch = _batch(run, manifest, data, kind, batch_id)
    fingerprint = hashlib.sha256(json.dumps(batch, sort_keys=True, ensure_ascii=False).encode()).hexdigest()
    require(saved["input_hash"] == fingerprint, "Batch input changed; reconvert dependent batch")
    checked_flags = validate(batch, saved["records"], saved["submitted_flags"])
    require(saved["flags"] == checked_flags, "Stored flags differ from validation; resave batch")
    return saved


def save_validated_batch(run_path, kind, batch_id, records, flags):
    run, manifest, data = _load(run_path)
    batch = _batch(run, manifest, data, kind, batch_id)
    all_flags = validate(batch, records, flags)
    saved = {"input_hash": hashlib.sha256(json.dumps(batch, sort_keys=True, ensure_ascii=False).encode()).hexdigest(),
             "records": records, "submitted_flags": flags, "flags": all_flags}
    atomic_json(_saved_path(run, kind, batch_id), saved)
    # An assembly receipt is only valid for its exact output/batch hashes.
    return {"batch_id": batch_id, "kind": kind, "rows": len(records), "review_flags": sum(f["severity"] == "review" for f in all_flags)}


def inspect_run(run_path):
    run, manifest, data = _load(run_path)
    statuses = {}
    for kind in KINDS:
        completed = []
        for i in range(1, len(manifest["schedules"][kind]) + 1):
            if _saved_path(run, kind, i).exists():
                _read_saved(run, manifest, data, kind, i)
                completed.append(i)
        statuses[kind] = {"expected_batches": len(manifest["schedules"][kind]), "valid_batches": completed}
    return {"run_path": str(run), "status": statuses, "warnings": manifest["warnings"],
            "excluded_sources": manifest["excluded_sources"]}


def assemble_outputs(run_path):
    run, manifest, data = _load(run_path)
    pending = {}
    for kind in KINDS:
        records, flags, hashes = [], [], {}
        for i in range(1, len(manifest["schedules"][kind]) + 1):
            saved = _read_saved(run, manifest, data, kind, i)
            records.extend(saved["records"])
            flags.extend(saved["flags"])
            p = _saved_path(run, kind, i)
            hashes[str(p)] = digest(p)
        available = kind in ("lot_owner", "compref") or {"committee": "committee", "tenant": "occupiers"}[kind] in manifest["sources"]
        info = {"kind": kind, "status": "validated" if available else "unavailable", "rows": len(records),
                "review_flags": sum(f["severity"] == "review" for f in flags),
                "batch_hashes": hashes, "excluded_sources": manifest["excluded_sources"],
                "intentionally_skipped_yes": sum(r["values"]["Owner_Occupier"].strip().upper() == "YES"
                                               for r in data.get("occupiers", [])) if kind == "tenant" else 0}
        if kind == "lot_owner":
            info["source_rows"] = len(data["owners"])
            info["synthesized_rows"] = sum(bool(r["synthetic_reason"]) for r in records)
        output = io.StringIO(newline="")
        writer = csv.DictWriter(output, fieldnames=SCHEMAS[kind], lineterminator="\r\n")
        writer.writeheader()
        writer.writerows(r["values"] for r in records)
        report = "# Validation and flags\n\n" + json.dumps(info, indent=2) + "\n\n"
        report += "\n".join("- " + f["severity"] + ": " + f["message"] + " [" + ", ".join(f["source_ids"]) + "]" for f in flags)
        report += "\n\nRun observations:\n" + "\n".join("- " + w for w in manifest["warnings"]) + "\n"
        pending[kind] = (output.getvalue(), report, info, records)
    receipt = {"manifest_hash": digest(run / "manifest.json"), "outputs": {}}
    for kind, (output, report, info, records) in pending.items():
        csv_path = run / (kind + ".csv")
        atomic_text(csv_path, output)
        atomic_text(run / (kind + "_Flags.md"), report)
        atomic_json(run / (kind + "_provenance.json"), records)
        info["csv_sha256"] = digest(csv_path)
        receipt["outputs"][kind] = info
    atomic_json(run / "reconciliation.json", receipt)
    return receipt
