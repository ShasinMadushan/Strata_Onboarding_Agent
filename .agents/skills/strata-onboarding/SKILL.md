---
name: strata-onboarding
description: Coordinate strata onboarding from property CSV exports through four conversion skills and approved SQL MCP imports with complete lot batches and durable validation.
---

# Strata onboarding

Codex coordinates this workflow. Local MCP helpers parse, validate and serialize; they never call a model or database. Do not use agent.py.

For financial PDFs or a request including Levy Arrears, Income/Expense or Budget, use [financial-onboarding](../financial-onboarding/SKILL.md). Reuse the resolved property context, then verify it read-only in the current target. The CSV inventory tools do not classify financial PDFs. Financial stages use the existing financial MCP converters and SQL MCP, not this CSV batching/run machinery. A financial blocker does not cancel independent CSV or other financial stages. Local DEV exceptions in the CSV references do not authorize financial fixtures, schema changes or procedure patches.

Read [known limitations](references/known-limitations.md), [tool contract](references/tool-contract.md) and [approval checkpoint](references/approval-checkpoint.md). Use installed onboarding MCP tools; if unavailable request client reload, not a fallback to the old agent.

## Approval boundary

Before ANY database INSERT, UPDATE, DELETE, EXEC, CREATE, ALTER, DROP, TRUNCATE or BULK INSERT through execute_sql or execute_sql_file, show exact SQL, file contents/hash, property, objects, scope and effects; then STOP for explicit user approval. Showing and executing in the same turn is not approval. File creation or architecture approval is not database approval. Every EXEC requires approval, including verification. Changed SQL needs renewed approval. Never bypass SQL MCP with drivers or shell database clients.

Native write control: Keep approval_mode="prompt" for both SQL tools and approvals_reviewer="user". Read-only SELECT and metadata queries do not require a special approval-gate test. Do not block onboarding because SELECT 1 returned without a native popup. Before every database write or EXEC, show the exact SQL and SHA-256 and wait for separate user approval. The actual write must still pass native SQL MCP approval. If native approval is missing for a write, stop and report. Never bypass the SQL MCP approval mechanism.

## Run sequence

1. Resolve plan_folder, plan_number, property_id, managing_scope and fresh run_id from the task, never sample defaults. inspect_plan identifies files by headers, preserves strings/order and reports exclusions. Folder placement is not proof of identity. Do not investigate excluded-file identity.
2. Read strata-lot-owner, strata-communication-preferences, strata-committee and strata-tenants plus their full conversion references. Missing supplementary sources follow explicit fallback/confirmation rules. Excluded files count as unavailable.
3. initialize_run stores hashes, exclusions and batches under output/<plan>/<run>/. If occupiers are unavailable, get a building address from the user; never infer it from owner correspondence addresses. Missing Contacts requires explicit acceptance of changed classification semantics.
4. Read at most three COMPLETE lots per batch, retaining all primary/routing rows and matching supplementary rows. A size ceiling reduces batches. An oversized single lot fails explicitly: do not truncate, split or process a whole property in one pass. Committee/Tenant use their own source populations, not an owners-only filter.
5. For Lot/Owner, call `convert_lot_owner_batch`; it is the active deterministic implementation of `prompts/strata_conversion_system_prompt_v2.9.md`. Submit its returned source-linked records and flags unchanged to `save_validated_batch`. Committee/Tenant conversion remains semantic as specified by their skills. Correct only failed batches, at most two retries, then stop on unresolved errors. Never keep a "best" invalid attempt or suppress flags.
6. Communication preferences use validated Lot/Owner batches. Tenant communications require a user decision. Record tenant_communication_decision="exclude" only after explicit user choice; remapping requires correcting the reviewed upstream conversion.
7. assemble_outputs revalidates complete coverage and unchanged inputs, writes exact CSV headers plus flags and sidecars. Missing/excluded Committee or Tenant produces a header-only artifact marked unavailable, not a successful empty import. Existing outputs are shape references only.
8. Read strata-import and sql-mcp-dev. After the approval checkpoint is released, inspect contracts, prepare SQL, obtain approval, stage, flatten/reconcile, resolve property and import in order. All property-specific table names come from the run object map.
9. Report conversion, staging and each import separately. Distinct Committee/Tenant contact import remains unsupported.

## Resume

inspect_run/read_batch recover status from durable artifacts, not chat. Persisted validation is not authorization. Source/spec hashes invalidate stale batches. Reassemble after corrections and regenerate reviewed SQL. After database timeout inspect state before proposing retry; never automatically replay, truncate or delete.
