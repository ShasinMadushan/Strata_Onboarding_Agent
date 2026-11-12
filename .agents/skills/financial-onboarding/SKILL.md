---
name: financial-onboarding
description: Coordinate Levy Arrears, Income/Expense and Budget PDFs through existing converters, approved stock SQL imports and row-level reconciliation; resume safely or report exact blockers.
---

# Financial onboarding

Codex is the coordinating agent: read this skill and call the existing financial MCP converters and SQL MCP directly. Reuse conversion files and freshly verified database evidence; do not introduce a pipeline, workflow engine, runner, agent.py, orchestrator, manifest/receipts framework, MCP server or staging architecture. Leave mature CSV onboarding unchanged.

## Scope and modes

Honor the requested mode; clarify ambiguous execution scope before any write:

- **Conversion only:** identify PDFs, convert and validate SQL files; do not load or import.
- **Raw load:** convert/validate, inspect raw compatibility, obtain approval, load and reconcile; stop before mapping and procedures.
- **Full financial import:** raw load, type-specific downstream checks/mapping, approved stock procedures and final reconciliation.

Raw-loaded is not financially imported. An explicitly requested raw-only load may proceed when its own contract is compatible despite downstream blockers. For a full-import request, disclose known downstream blockers before proposing writes; do not silently downgrade it to a partial raw load.

## Runtime context and boundaries

Resolve canonical plan and source identity from the request and PDF contents, not filenames alone. For database work, use read-only SQL MCP inspection to resolve property ID, managing company, authorized function scope, active database, raw/COA locations, synonyms and procedure dependencies. Inspect actual function/parameter signatures; user scope is not a company code. Never use example property IDs, scopes, companies or database names as defaults.

Read [sql-mcp-dev](../sql-mcp-dev/SKILL.md) before database work for SQL-tool and approval discipline. Connection examples are not universal financial contracts. Use exposed tool arguments; SQL MCP is the only database route. Never use Python drivers or shell database clients.

Missing columns, tables, synonyms, reference data or deployment contracts block the affected step. Never create/alter/drop objects, retarget synonyms, seed reference data, add mapping columns or change stock procedures to satisfy prerequisites. Do not redirect deployment references or assume similarly named local objects are equivalent. Report the exact missing/incompatible dependency for authoritative resolution.

Resolve CompanyID as well as Plan Number, PropertyID and ManagingCompanyCode through the existing property workflow's `F_SNG_Properties_L3_CORE`, using its inspected scope/signature. Require a unique matching association and inspect current raw, intermediate and final state at the start, including procedure-consumed periods outside the selected PDF. Read [workflow and SQL checks](references/workflow.md) before full import or resume; it supplies type-specific dependencies, state rules and reconciliation keys. Use [local validation](references/validation.md) for optional deterministic checks on captured evidence; it cannot execute tools or confer approval.

Inventory only the current property's requested input set, excluding DEV/test paths before opening files. Identify Levy, Income/Expense and Budget by PDF contents, never fixed filenames or a previous property's outputs. Match each detected canonical plan to the current resolved PlanNumber. Report other-property, unrelated, ambiguous and unreadable PDFs. Report absent types as unavailable and continue independent available types unless the requested mode explicitly requires all three before execution. Do not select overlapping reports/periods silently.

**DEV fixtures are excluded from normal execution.** Never discover, execute, copy or use `output/dev_only/`, other `dev_only/` paths, test fixtures, review/setup/cleanup SQL or prior synthetic values as normal sources or reference fallbacks. Do not treat an already present synthetic DEV record as authoritative company configuration. Missing master/fund/FY setup blocks the affected stage. Local adaptation requires a separate explicit DEV-testing request and concrete approval. The unchanged stock procedure may generate company hierarchies from authoritative existing master nodes; that is a disclosed procedure effect, not permission to seed absent master/reference records. Do not inherit local CSV-workflow exceptions as financial authorization.

Synthetic fund/entity rows, classifications/hierarchies, OBAL/DRAFT records and financial-year values, local schema ALTERs, DEV-only synonyms/tables and environment-specific procedure patches are development evidence only, never automatic onboarding actions. Do not replay local setup or deployment SQL to satisfy prerequisites. Missing equivalent authoritative dependencies mean BLOCKED with the exact object/key, observed absence or incompatibility, affected rows/stage and required external configuration/deployment action.

## Conversion and raw loading

| Type | Existing financial MCP tool | Converter raw target |
|---|---|---|
| Levy Arrears | `convert_levy_arrears` | `dbo.URBANISE_LevyArrearsByLevyType` |
| Income/Expense | `convert_urbanise_accounts` | `dbo.URBANISE_Revenue_Expenditure_Accounts` |
| Budget | `convert_urbanise_budget` | `dbo.URBANISE_Budge_Details_INTERIM` |

### Financial raw database routing

Before loading financial raw data, resolve and verify
the company staging database using read-only SQL MCP.

The SQL MCP default database may be the ERP database.
Never assume unqualified dbo table names refer to
the company staging database.

Use the existing verified company raw tables.

For the current ABOVEOCM DEV environment:

Staging database: AboveOCM_Local_Test
ERP database: V2_SNG_ERP_DEV

Raw targets:
- [AboveOCM_Local_Test].[dbo].[URBANISE_LevyArrearsByLevyType]
- [AboveOCM_Local_Test].[dbo].[URBANISE_Revenue_Expenditure_Accounts]
- [AboveOCM_Local_Test].[dbo].[URBANISE_Budge_Details_INTERIM]

The financial converters may generate INSERT statements
using unqualified dbo table names.

For execution, prepare a reviewed copy of the generated
SQL with only the verified raw target table references
fully qualified to the correct staging database.

Do not change the converter's data values, columns,
business logic or original converter implementation.

This is a database-routing correction only.

For other companies or environments, discover the actual
company staging database and procedure-consumed synonym
targets. Never hardcode AboveOCM_Local_Test universally.

Before loading, verify target schema compatibility,
existing rows and the exact synonym destinations.

Never create, drop, alter or replace tables, synonyms
or stored procedures.

Request native SQL approval separately for every write.
After loading, reconcile complete row contents and totals.

If dependencies do not match, stop and report the issue.

1. Select the correct report for each requested type; check plan and periods across relevant PDF sections. Ambiguous/mixed identity stops that conversion.
2. Call the existing converter with explicit `pdf_path` and `output_sql_path`. Preserve sources and previous outputs; use a fresh output path. Conversion does not grant database permission.
3. Inspect converter results and SQL: expected statements/target/columns, canonical plan, dates, funds, account types, amounts and complete source coverage. Count value rows, not INSERT statements. Preserve duplicate multiplicity; never silently deduplicate or change business values. Reconcile report totals using the converter's documented rules.
4. For Budget, validate canonical plan identity and actual encoding. The current converter already normalizes plan spacing and writes UTF-8; historical spacing/BOM failures are regression cases, not presumed current defects. Block any actual defect until a separately authorized correction is verified. Do not silently rewrite identifiers or business values. Validate subtotals and documented GST treatment separately.
5. Show each selected file's path, row count and validation status before loading anything. Stop here for conversion-only mode.
6. Inspect actual raw columns/types and existing rows read-only. Require compatibility with the generated INSERTs and an unambiguous approved row scope. Unexpected existing rows or incompatible SQL/schema stop the load; never truncate/delete to retry.
7. Obtain approval for each load, then execute its validated file through SQL MCP `execute_sql_file`. Verify actual rows/values against the generated data, accounting for pre-existing rows. Stop here for raw-load mode and report known downstream blockers separately.

## Levy full import

After reconciled raw loading:

1. Verify `syn_ERP_T_SNG_ImportLevyArrearsByLevyType`, its target and the deployed procedure's dependencies, including `T_SNG_ImportLevyArrearsByLevyType`. Inspect actual destination databases and lot/owner, fund, levy-type, classification and opening-balance occurrence joins. Missing, ambiguous or multiplying joins stop import.
2. Obtain approval and execute `P_SNG_IMPORT_OB_Levies` using the resolved managing-company code and property ID, following its live signature. Do not alter its logic.
3. Verify intermediate and final coverage, amounts and stock date/GST transformations by lot/fund/category. Report credits outside the arrears INSERT contract separately; do not claim they were imported. A valid zero-arrears report needs no invented rows or procedure execution.

Levy has no separate Income/Budget account-to-MCHID UPDATE. Its stock classification dependencies still must resolve.

## Income/Expense and Budget mapping gate

After reconciled raw loading, before their stock procedures:

1. Verify the MCHID-capable contract. Original converter INSERTs omit `MCHID`; the supplied downstream mapping expects raw `MCHID`. Inspect its actual availability and compatibility. If absent, report an unresolved schema prerequisite and STOP mapping/import. Do not add the column, invent an intermediate stage or issue a NULL-count query against a nonexistent column.
2. Resolve this ManagingCompanyCode's authoritative COA binding from an existing repository/database contract using the evidence rules in [workflow.md](references/workflow.md). For a property whose **resolved** `ManagingCompanyCode` is `ABOVEOCM`, the authoritative company-level binding is `dbo.Above_OCM_COA_Finalized`: join raw `Account_Name` to `[Urbanise Name]`; derive `LedgerType` as `expenditure -> expense` and `revenue`/`income -> income`; and assign raw `MCHID` from `LEVE3_MCHID`. This binding applies to all ABOVEOCM properties and is never evidence for a plan, PropertyID, or CompanyID outside the live property resolution. For every other managing company, require its own authoritative source, company association/filter and account/ledger/leaf columns; table existence alone is not authority and no universal or company-name-derived fallback applies. Missing, ambiguous or incompatible binding means BLOCKED for that financial stage with the missing mapping contract reported. Deduplicate only candidates with the same account/ledger key and identical non-NULL `LEVE3_MCHID`. Conflicting IDs, NULL candidate IDs, unmatched keys and disagreements with existing non-NULL raw MCHIDs block; never use TOP 1/MIN/MAX to hide conflicts. `LEVE2_MCHID` and the COA column named `MCHID` are not the assigned leaf ID. Inspect destination master/ancestor readiness separately: a populated raw MCHID does not establish an existing hierarchy.
3. Use the supplied authoritative mapping approach with verified object bindings and approved property scope: `b.Account_Name = f.[Urbanise Name]`, matching `f.LedgerType`, then `b.MCHID = f.LEVE3_MCHID` for rows where `b.MCHID IS NULL`. Retain the supplied property-function join and company filter with resolved runtime values. Derive ledger type with `IIF(b.AccountType = 'expenditure', 'expense', 'income')` for Income, or `Account_Type` for Budget. Validate supported account types and actual comparison semantics first; unexpected types must not silently become income. Do not substitute another mapping algorithm or overwrite existing non-NULL values silently.
4. If the contract permits mapping, present the exact UPDATE, obtain native approval and execute once. Read back results; count remaining NULL MCHIDs and identify invalid or ambiguous mappings. Zero unresolved rows is not success when expected raw rows are absent.
5. Report all inspectable unresolved Income/Budget results in one batch when both are selected: type, plan, fund, account/type, period/date, amount, count and reason. Preserve row-level detail. STOP affected downstream procedures until manual resolution; never ignore or guess required mappings.
6. On resume, inspect authoritative corrections and current raw rows again. Obtain user approval for another mapping UPDATE only if needed, recheck completeness, then continue from the next uncompleted step. Do not reload raw rows or blindly rerun completed procedures.

## Income/Expense and Budget procedures

Proceed only after successful mapping and dependency checks. Verify each synonym's actual target and every referenced intermediate/final object from live definitions; do not repair missing objects.

- **Income/Expense:** verify `syn_ERP_T_SNG_IMPORT_OB_Revenue_Expenditure` and `T_SNG_IMPORT_OB_Revenue_Expenditure`. Obtain approval and run `P_SNG_IMPORT_OB_Revenue_Expenditure`; verify intermediate coverage, MCHIDs and fund associations. Then obtain separate approval and run `P_SNG_IMPORT_OB_RevenueDetails`; reconcile final opening-balance amounts by the procedure's fund/classification/occurrence grouping.
- **Budget:** verify `syn_ERP_T_SNG_Master_Budge_Details` and `T_SNG_Master_Budge_Details`, plus `syn_ERP_T_SNG_Import_Budget` when referenced by the deployed definition; do not guess its target. Obtain approval and run `P_SNG_IMPORT_MasterData_BudgetDetail_ImportIntoIntelliMasterTable`; verify intermediate coverage, MCHIDs and fund associations. Then obtain separate approval and run `P_SNG_IMPORT_MasterData_BudgetDetails`; reconcile budget headers by fund/year and grouped details, accounting for documented zero-value exclusions.

Use actual company/property parameters and live signatures. A procedure's existence does not prove its references resolve or that its internal scope/destination matches the authorized environment.

Before procedure 2, follow the complete gates in [workflow.md](references/workflow.md): existing master/classification/ancestor records, company/fund cardinality, unique DRAFT opening-balance occurrence for Income, and the actual company financial-year inputs/functions for Budget. Missing FY configuration is a blocker; do not infer a financial lock date from a PDF. Project stock company-hierarchy generation without seeding records manually. Inspect every executable cross-database reference; wrong/unavailable destinations block rather than trigger automatic qualifier patches.

## State and rerun decisions

Classify each type separately for the resolved PlanNumber/PropertyID/CompanyID/ManagingCompanyCode and actual source periods/funds, using fresh read-only SQL MCP inspection: `NOT_STARTED`, `RAW_LOADED`, `MAPPED`, `INTERMEDIATE_COMPLETE`, `FINAL_COMPLETE`, `PARTIAL_INCONSISTENT`, or `BLOCKED`. See the decision table in [workflow.md](references/workflow.md). Generated state/run files, earlier captured evidence and successful EXEC are never the source of truth. The stateless helper may classify a current database snapshot; Codex establishes its scope/freshness and selects the next authorized tool call. Exact final reconciliation means **do not rerun**. Existing but incomplete/mismatched raw/intermediate/final rows, a header without expected details, or partial company records from a failed step require a stop with the existing rows and duplication risk explained before proposing corrective SQL. Levy creates intermediate and final rows in one procedure, so intermediate-only Levy is not a safe resume point. Do not issue an automatic cleanup, reload or retry.

## Approval, verification and stopping

For normal onboarding, keep each pre-write approval message operator-friendly. State the action, resolved property/plan, target table or existing procedure, expected affected row count, and that no shared schema, reference/master data, synonym, procedure or configuration will be changed. STOP for concrete user approval through the existing native SQL MCP gate; it remains the execution gate.

Do not paste large generated SQL into normal chat unless the user asks to review it, the action is unusual, validation has failed, or the action is not a standard approved onboarding operation. The native gate must still receive the exact SQL or generated-file contents/hash, target objects, row scope and expected effects; retain that evidence for verification. For normal existing-procedure executions, showing the procedure name and resolved parameters is sufficient in chat. Existing approval for that unchanged concrete action remains valid; do not ask twice. Conversion or skill approval is not database approval. Changed SQL needs renewed approval. Honor a confirmed working gate; do not repeat historical activation tests or bypass it with another client. Configuration text alone is not proof of activation. Never simulate SQL approval with helper code, a chat confirmation or a shell prompt.

Normal onboarding never modifies, replaces, alters, drops, creates or patches database procedures, schemas, synonyms, reference/master data, or shared configuration. If an existing object is incorrect or any dependency is missing, STOP and report `BLOCKED` with the exact object and reason; do not repair it.

After every approved step, use read-only SQL MCP queries to verify rows, identifiers, coverage and amounts. Preserve intentional duplicate multiplicity and stock grouping rules. A successful tool return, procedure PRINT or matching count alone is insufficient. Stop on missing rows, unexplained extras, amount differences, invalid mappings or changed dependencies.

After timeout/uncertain execution, never automatically replay a write. Inspect raw, intermediate and final state to establish what committed before proposing any next action. Recheck source/generated files and live contracts on resume; changed inputs or ambiguous state require review, not automatic cleanup.

Report conversion, raw loading, mapping, each procedure and final reconciliation separately, with affected blockers. Claim completed financial import only when required downstream effects and final reconciliation succeed. Otherwise state exactly what succeeded and where work stopped.

For final checks, reconstruct the live joins without insertion-only NOT EXISTS predicates, prove each eligible source row has exactly one match, and compare every grouped amount plus the base final-table total. Preserve/document zero-value exclusions. Budget may legitimately have fewer final details than intermediate rows. Never sum final amounts through a many-source-to-one-final join. The validation helper supplies exact-decimal multiset, join-coverage and grouped-amount checks but cannot prove that the chosen SQL scope/grouping was correct.

For each type report **PASS / BLOCKED**, marking verified reused steps and unavailable sources explicitly:
- Levy: conversion, raw load, procedure, reconciliation.
- Income/Expense: conversion, raw load, mapping coverage/NULL count, procedure 1, procedure 2, reconciliation.
- Budget: conversion, raw load, mapping coverage/NULL count, procedure 1, FY/reference readiness, procedure 2, source/group reconciliation.

For a blocker include exact object/dependency, affected step and source rows, measured evidence and next required external action (authoritative configuration/mapping or deployment correction). Continue independent types; do not fabricate missing production data to turn BLOCKED into PASS.
