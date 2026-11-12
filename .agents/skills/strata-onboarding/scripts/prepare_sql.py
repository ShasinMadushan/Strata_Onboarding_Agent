"""Generate reviewable SQL artifacts. This module has no database client."""
import json
import re
from csv_batches import _load, digest, read_json, atomic_text, inspect_run
from validate_outputs import KINDS, SCHEMAS, require


def identifier(name):
    require(isinstance(name, str) and 0 < len(name) <= 128 and "\x00" not in name, "Invalid SQL identifier")
    return "[" + name.replace("]", "]]") + "]"


def literal(value):
    require(isinstance(value, str) and "\x00" not in value, "Invalid SQL cell")
    return "N'" + value.replace("'", "''") + "'"


def prepare_staging_sql(run_path, kind, schema_name, approved_review=""):
    require(kind in KINDS, "Invalid kind")
    require(isinstance(schema_name, str) and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]{0,127}", schema_name), "Supply a verified schema name")
    require(isinstance(approved_review, str), "Review approval must be text")
    run, manifest, _ = _load(run_path)
    status = inspect_run(run_path)["status"]
    receipt = read_json(run / "reconciliation.json")
    require(receipt["manifest_hash"] == digest(run / "manifest.json"), "Manifest changed; reassemble")
    for k in KINDS:
        require(len(status[k]["valid_batches"]) == status[k]["expected_batches"], "Missing batches")
        for p, sha in receipt["outputs"][k]["batch_hashes"].items():
            require(digest(p) == sha, "Batch changed; reassemble outputs")
        require(digest(run / (k + ".csv")) == receipt["outputs"][k]["csv_sha256"], "CSV changed; reassemble outputs")
    entry = receipt["outputs"][kind]
    require(entry["status"] == "validated", "Missing/excluded source cannot be staged")
    review_flags = entry["review_flags"]
    if kind == "compref":
        review_flags += receipt["outputs"]["lot_owner"]["review_flags"]
    if review_flags:
        require(approved_review.strip(), "review flags require explicit user-approved review text")
    from csv_batches import read_csv
    header, rows = read_csv(run / (kind + ".csv"))
    require(header == SCHEMAS[kind] and len(rows) == entry["rows"], "CSV schema/count mismatch")
    table = identifier(schema_name) + "." + identifier(manifest["table_map"][kind])
    cols = ", ".join(identifier(c) for c in header)
    sql = [
        "-- PREPARED ONLY. Explicit user approval required before execution.",
        "-- Raw text staging: inspect downstream types and blank/NULL mapping before approval.",
        "-- PropertyID: " + str(manifest["property_id"]) + "; plan: " + manifest["plan_number"],
        "-- Input CSV SHA-256: " + entry["csv_sha256"],
        "SET XACT_ABORT ON;",
        "BEGIN TRY",
        "BEGIN TRANSACTION;",
        "CREATE TABLE " + table + " (\n" + ",\n".join("    " + identifier(c) + " nvarchar(max) NOT NULL" for c in header) + "\n);",
    ]
    if approved_review.strip():
        require("\n" not in approved_review and "\r" not in approved_review, "Review approval must be one line")
        sql.insert(4, "-- User-approved review: " + approved_review.strip())
    for start in range(0, len(rows), 500):
        values = ",\n".join("(" + ", ".join(literal(row[c]) for c in header) + ")" for row in rows[start:start + 500])
        sql.append("INSERT INTO " + table + " (" + cols + ") VALUES\n" + values + ";")
    sql += [
        "IF (SELECT COUNT_BIG(*) FROM " + table + ") <> " + str(len(rows)),
        "    THROW 51000, 'Staging row count mismatch', 1;",
        "COMMIT TRANSACTION;",
        "END TRY",
        "BEGIN CATCH",
        "IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;",
        "THROW;",
        "END CATCH;",
    ]
    path = run / "sql" / (kind + "_staging.sql")
    atomic_text(path, "\n".join(sql) + "\n")
    return {"file_path": str(path), "sha256": digest(path), "target": table,
            "rows": len(rows), "executed": False, "requires_explicit_database_approval": True}
