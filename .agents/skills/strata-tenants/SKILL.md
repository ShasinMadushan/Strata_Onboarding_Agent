---
name: strata-tenants
description: Convert verified occupiers records with Owner_Occupier NO into the exact 29-column tenant CSV.
---

# strata-tenants

Read [the full conversion specification](references/conversion-spec.md) before conversion. Preserve field semantics and exact column order; examples are not defaults.

Use eligible occupiers only. Exactly one row per NO record; skip/count YES; unknown values need review. Keep co-occupier names combined. SM_Is_TenantContact=1. Unit separate from street number; phone notes blank unless explicitly attributed. Respect exclusions: unavailable is not a successful zero-tenant import.

Use [onboarding tools](../strata-onboarding/references/tool-contract.md), kind="tenant". Process at most three complete lots per batch. Perform semantic conversion directly in Codex, then submit source-linked records and flags. Never silently drop, merge, invent or fill missing source records. Ambiguous interpretations remain review flags. Validators cannot prove all semantic decisions correct.

Assemble only after every expected batch validates. Preserve CSV/flags/provenance and verify source hashes on resume. Follow [known limitations](../strata-onboarding/references/known-limitations.md).

Before ANY database INSERT, UPDATE, DELETE, EXEC, CREATE, ALTER, DROP, TRUNCATE or BULK INSERT: show exact SQL/effects then STOP for explicit approval. This skill grants no database-write permission. Native SQL approval_mode="prompt" and approvals_reviewer="user" must be proven first; skill text alone is insufficient.
