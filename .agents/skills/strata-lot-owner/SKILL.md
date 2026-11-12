---
name: strata-lot-owner
description: Convert strata owner and routing CSV records into the exact 54-column long format in complete lot batches.
---

# strata-lot-owner

Read [the full conversion specification](references/conversion-spec.md) before conversion. Preserve field semantics and exact column order; examples are not defaults.

Owners is structural truth; Contacts classifies Agent/Tenant and provides Agent fallbacks only. Preserve every source routing row, including duplicates. Exactly one primary Owner per lot; synthesized Agents have separate provenance. Apply full spec for matching, Agent caps and Other allocation. Preserve literal spaces in Contact_Mobile 2 and Lot address details. Missing occupiers needs user-provided building address; missing Contacts needs explicit acceptance.

Use [onboarding tools](../strata-onboarding/references/tool-contract.md), kind="lot_owner". Process at most three complete lots per batch. Perform semantic conversion directly in Codex, then submit source-linked records and flags. Never silently drop, merge, invent or fill missing source records. Ambiguous interpretations remain review flags. Validators cannot prove all semantic decisions correct.

Assemble only after every expected batch validates. Preserve CSV/flags/provenance and verify source hashes on resume. Follow [known limitations](../strata-onboarding/references/known-limitations.md).

Before ANY database INSERT, UPDATE, DELETE, EXEC, CREATE, ALTER, DROP, TRUNCATE or BULK INSERT: show exact SQL/effects then STOP for explicit approval. This skill grants no database-write permission. Native SQL approval_mode="prompt" and approvals_reviewer="user" must be proven first; skill text alone is insufficient.
