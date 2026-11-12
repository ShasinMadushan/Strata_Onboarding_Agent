---
name: strata-import
description: Prepare and execute explicitly approved strata staging, flattening and imports through SQL MCP using verified live contracts.
---

# Strata import

Read [sql-mcp-dev](../sql-mcp-dev/SKILL.md), [staging and import](references/staging-and-import.md), [limitations](../strata-onboarding/references/known-limitations.md) and [approval checkpoint](../strata-onboarding/references/approval-checkpoint.md). Do not modify existing SQL skill or financial MCP.

Before ANY INSERT, UPDATE, DELETE, EXEC, CREATE, ALTER, DROP, TRUNCATE or BULK INSERT through execute_sql or execute_sql_file, show exact SQL/file hash, property/objects, scope and effects; then STOP for explicit user approval. Same-turn presentation/execution is not approval. Every EXEC needs approval. Changed SQL requires renewed approval. File-build approval is not onboarding approval.

Keep native approval_mode="prompt" for both SQL tools and approvals_reviewer="user". Read-only SELECT and metadata queries may run without a native approval popup. Do not require SELECT 1 AS approval_gate_test as a prerequisite to import preparation. For every database write or EXEC, show the exact SQL and SHA-256, wait for explicit user approval, and require native SQL MCP approval during execution. If native approval is missing for an actual write, stop and report. Do not bypass SQL MCP.


Use existing SQL MCP only. Do not use direct database drivers.

For ABOVEOCM local DEV onboarding:
- AboveOCM_Local_Test is the company staging/master database.
- V2_SNG_ERP_DEV is the ERP DEV import database.

Verify both databases using read-only SQL before preparing writes.
Never assume the SQL MCP connection's default database is the
correct staging destination.

For other companies or environments, discover and verify the
approved staging and ERP databases; do not reuse ABOVEOCM defaults.

Inspect actual tool arguments and live procedure dependencies.
Property-specific names must come from verified property details
and the approved company SQL templates.
Inspect actual arguments; no invented source argument. Never use direct drivers. Property-specific table/plan names come from actual run inputs and object map. Resolve fixed procedure dependencies from live metadata.


