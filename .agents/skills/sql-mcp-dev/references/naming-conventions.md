# SNG database object naming conventions

This is the documented convention, annotated with real prevalence data pulled from `strata_manager`/`sng_erp` via MCP (August 2026). **Treat the documented pattern as the target to write new objects against, not as a reliable filter for finding existing ones** — see the drift notes under each section.

## 1. Tables (`T_`)

Format: `[dbo].[T_SNG_TableName]` — prefix `T_`, project identifier `SNG`, singular descriptive name.

Confirmed live examples: `T_SNG_API_GetHTML`, `T_SNG_API_GetJsonData`, `T_SNG_API_ModifyData`, `T_SNG_GETHTML`, `T_SNG_ZoneFlags`, `T_SNG_API_AI_FunctionCalling` (AI-specific — see §5).

## 2. Views (`V_`)

Format: `[dbo].[V_SNG_ViewName_L1]` — prefix `V_`, matches the source table name where based on one, suffix `_L1` indicates the view "level."

Confirmed live examples: `V_SNG_AccessDevice_L1`, `V_SNG_Activities_L1`. Not all views carry a level suffix (`V_SNG_3rdPartyIntegrations` has none) — don't assume `_L1` is universal.

## 3. Functions (`F_`)

Format: `[dbo].[F_SNG_FunctionName_L2]` — prefix `F_`, often tied to a table name, suffix usually `_L2` but also seen as `_L3`, `_T1`, or `_L2_CORE` for versioning/layering.

Confirmed live examples: `F_SNG_AccessDevice_L2`, `F_SNG_Activities_Sub_L3`, `F_SNG_GetUserDetailsByDnnUserID_CORE` (used in DML procs), `F_SNG_GetUserDetailsByDnnUserID` (used in read paths — note both a plain and a `_CORE` variant exist for the same lookup; check which one a proc you're modeling after actually uses).

## 4. Synonyms (`syn_`)

Format: `[dbo].[syn_ERP_FunctionOrViewOrProcName]` — prefix `syn_ERP_` marks a synonym that points into the `sng_erp` database. This is the **only** sanctioned way `strata_manager` code touches ERP data.

Confirmed live examples: `syn_ERP_F_SNG_Jobs_FILTERED_JobData` (table-valued function, read path), `syn_ERP_P_SNG_Jobs_UpdateJobEmailInfo` (procedure, write path), `syn_ERP_P_SNG_STRATA_AddSystemSQLErrors` (shared error-logging proc — see intellistrata-dev's error-handling pattern).

## 5. Stored procedures (`P_`/`p_`)

### A. Get HTML — `[dbo].[P_SNG_API_GetHTML_SPName]`
SPs that return HTML output for AJAX consumption, registered in `T_SNG_API_GetHTML` under a `Module` code. See sql-mcp-dev's main SKILL.md for the lookup flow.

### B. Get JSON — `[dbo].[P_SNG_API_GetJsonData_SPName]`
SPs that return JSON, registered in `T_SNG_API_GetJsonData` under an `ObjType` code.

### C. DML — `[dbo].[P_SNG_DML_SPName]`
SPs performing INSERT/UPDATE/DELETE, registered in `T_SNG_API_ModifyData` under a `RefCode`.

### Real-world drift from the documented pattern (confirmed census, `strata_manager`, backups excluded)

| Documented pattern | Count | Common real-world variant | Count |
|---|---|---|---|
| `*UIF_PG_*` (page entry) | 359 | `*_UI_PG_*` (missing the `F`) | 66 |
| `*UIF_Content*` | 391 | `*_UI_Content*` (missing the `F`) | 260 |
| `*UIF_DML*` | 266 | `*GETHTML_DML*` (no `UIF` at all) | **651** ← more common than the "documented" form |
| — | — | `P_SNG_DML_*` (plain, matches doc §5C exactly) | 32 |

**Practical implication:** never assume a proc follows the `UIF` convention just because it "should." When you need to find a specific proc, resolve it through the registration tables (`T_SNG_GETHTML`/`T_SNG_API_*`) or a broad `LIKE` search with backup-exclusion, not a narrow prefix match.

### 5.5 Special cases

- **Third-party integrations**: append `API_INT` after `SNG` — e.g. `P_SNG_API_INT_GetJsonData_InsuranceRenewalsList`. Confirmed 50 live procs follow this.
- **AI-specific objects**: append `AI` after `SNG` — e.g. `T_SNG_API_AI_FunctionCalling`. Only 4 procs confirmed live; this is an emerging pattern, not yet heavily used.

## HTML replacement tokens

Inside `@HTML`/`@HTML_Content`/`@HTML_PAGE` string literals, unresolved values are left as `[[SOME_VARIABLE_NAME]]` and closed out with a final `REPLACE()` chain before the proc returns — either resolved by the same proc, or left for a *calling* proc to resolve (e.g. widget-local tokens like `[[Scope]]`/`[[ChartCat]]` are frequently left unresolved by a Content SP and finished by the page-level PG proc). See intellistrata-dev's page-lifecycle reference for the concrete two-layer example.
