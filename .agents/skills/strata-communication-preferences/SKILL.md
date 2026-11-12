---
name: strata-communication-preferences
description: Pivot validated strata Lot/Owner rows into the exact 16-column communication-preference CSV.
---

# strata-communication-preferences

Read [the full conversion specification](references/conversion-spec.md) before conversion. Preserve field semantics and exact column order; examples are not defaults.

Read validated Lot/Owner only. Preserve lot order and all input output-row IDs. Codes blank/E/P/EP; Notice copies Correspondence. Tenant rows need explicit user decision, never silent exclusion or remapping. Report blank owner communications and EP cells.

Use [onboarding tools](../strata-onboarding/references/tool-contract.md), kind="compref". Process at most three complete lots per batch. Perform semantic conversion directly in Codex, then submit source-linked records and flags. Never silently drop, merge, invent or fill missing source records. Ambiguous interpretations remain review flags. Validators cannot prove all semantic decisions correct.

Assemble only after every expected batch validates. Preserve CSV/flags/provenance and verify source hashes on resume. Follow [known limitations](../strata-onboarding/references/known-limitations.md).

Before ANY database INSERT, UPDATE, DELETE, EXEC, CREATE, ALTER, DROP, TRUNCATE or BULK INSERT: show exact SQL/effects then STOP for explicit approval. This skill grants no database-write permission. Native SQL approval_mode="prompt" and approvals_reviewer="user" must be proven first; skill text alone is insufficient.
