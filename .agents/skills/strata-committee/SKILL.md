---
name: strata-committee
description: Convert committee CSV records into the exact 31-column schema while preserving each member.
---

# strata-committee

Read [the full conversion specification](references/conversion-spec.md) before conversion. Preserve field semantics and exact column order; examples are not defaults.

Use Committee source only. Preserve every member and verbatim name spacing. Preserve lot IDs; plan comes from verified run. SM_Is_CommitteeContact=1; SNG_CommitteeContactID blank. Unit is separate from street number. Do not choose one of multiple members during flattening.

Use [onboarding tools](../strata-onboarding/references/tool-contract.md), kind="committee". Process at most three complete lots per batch. Perform semantic conversion directly in Codex, then submit source-linked records and flags. Never silently drop, merge, invent or fill missing source records. Ambiguous interpretations remain review flags. Validators cannot prove all semantic decisions correct.

Assemble only after every expected batch validates. Preserve CSV/flags/provenance and verify source hashes on resume. Follow [known limitations](../strata-onboarding/references/known-limitations.md).

Before ANY database INSERT, UPDATE, DELETE, EXEC, CREATE, ALTER, DROP, TRUNCATE or BULK INSERT: show exact SQL/effects then STOP for explicit approval. This skill grants no database-write permission. Native SQL approval_mode="prompt" and approvals_reviewer="user" must be proven first; skill text alone is insufficient.
