# Local tool contract

scripts/onboarding_mcp.py uses the existing environment's Python, MCPServer, @mcp.tool() and stdio, matching financial_mcp.py. No API key or .env access is needed.

- inspect_plan(plan_folder, plan_number): read-only inventory and exclusions.
- initialize_run(plan_folder, plan_number, property_id, managing_scope, run_id, building_address={}, contacts_missing_accepted=false, tenant_communication_decision=""): local artifacts only; refuses overwrite.
- inspect_run(run_path): verified status.
- read_batch(run_path, kind, batch_id): complete groups, source IDs and exact schema.
- convert_lot_owner_batch(run_path, batch_id): applies the canonical `prompts/strata_conversion_system_prompt_v2.9.md` logic to one bounded Lot/Owner batch; returns source-linked records and flags for `save_validated_batch`, never writes a database.
- save_validated_batch(run_path, kind, batch_id, records, flags): validate first, persist only valid batches.
- assemble_outputs(run_path): revalidate all batches; write four CSVs, flags and reconciliation.
- prepare_staging_sql(run_path, kind, schema_name, approved_review=""): create reviewable raw-text staging SQL, never execute. When review flags exist, pass the already explicit user-approved business decision; it is preserved in the prepared SQL artifact. Verify downstream compatibility before execution.

kind: lot_owner, compref, committee or tenant. batch_id: one-based.
records: [{"source_ids":["owners:1"],"values":{"Lot_No":"1",...all exact columns...},"synthetic_reason":""}].
IDs count parsed data records, excluding blank physical lines. Normal Lot/Owner rows map one-to-one to Owners IDs; synthesized Agent rows reference Contacts IDs with a nonempty reason and blank communication/delivery. ComPref records reference ALL validated output IDs for that lot. Committee/Tenant map one-to-one to their source IDs. YES occupiers are counted exclusions; unknown values block Tenant conversion.

flags: [{"severity":"info|review|blocking","source_ids":["owners:1"],"message":"..."}].
Blocking flags refuse persistence. Review flags remain visible and prevent automatic SQL preparation. Resolve with the user; do not delete flags. After explicit user approval, Codex may prepare the reviewed SQL with that approval text under strata-import.

All cells must be strings, including bits/numeric IDs; missing/extra columns are errors.
building_address: exactly the eight Lot_Address_* fields from the Lot/Owner schema, supplied by the user when occupiers are unavailable.
Limits: maximum three complete lots and 24,000 serialized source characters per batch. Oversized single lots stop rather than truncate.
Every operation verifies source, exclusion-policy and conversion-reference hashes.
New runs also persist the SHA-256 of the canonical v2.9 prompt. The prompt is therefore an active conversion dependency; changing it invalidates a stale run rather than silently applying different rules.
Artifacts validate structural/mechanical invariants, not every semantic interpretation, and never confer database authorization.
