# Stock financial contracts and reconciliation

Read only the selected type's section after the shared discovery/mapping rules. Names below are the inspected team contract, not authority to create objects or redirect a different deployment. Read live schemas, procedure/function definitions, parameters and synonym targets through SQL MCP each time their freshness is uncertain. Include nested mutating calls and executable three/four-part references; comments mentioning another database are not executable dependencies.

## Shared discovery and resume

Resolve server/database, PlanNumber, PropertyID, ManagingCompanyCode and CompanyID through the existing property lookup. Inspect `F_SNG_Properties_L3_CORE` and the scope used by stock procedures; never substitute ManagingCompanyCode for a numeric function scope. Filter by the requested identity and require exactly one matching property/company with all four fields populated. If CompanyID is not exposed, follow the inspected property-to-company relation; never infer an ID. Missing/multiple associations mean BLOCKED with the lookup/signature, scope and returned rows. Inspect column types/nullability, keys, computed fields and triggers before load/mapping. Do not use sample IDs or hardcoded dates. An inaccessible object means BLOCKED with evidence, not an empty result.

Inventory raw, intermediate, final and related generated company records before *each* mutation. Match the whole period/fund/account/lot scope and duplicate multiplicities. Also inspect any other property/period reachable by the procedure: its parameter list alone does not prove write isolation. A procedure that would consume unintended rows is an exact scope blocker. Missing reference data, incompatible schema, unexpected synonym destinations and executable cross-database references outside the authorized environment are blockers. No synonym, schema or stock logic repair is part of this workflow.

| Observed, reconciled state | Report / permitted continuation after normal approvals |
|---|---|
| No scoped raw/intermediate/final data | NOT_STARTED; convert/validate and propose raw load |
| Exact raw multiset, later stages absent | RAW_LOADED; reuse raw, inspect mapping/dependencies |
| Exact raw and authoritative mapping complete, later stages absent | MAPPED; preflight procedure 1 |
| Income/Budget intermediate exactly reconciled, final absent | INTERMEDIATE_COMPLETE; preflight procedure 2; never rerun procedure 1 just to populate helper ID columns |
| All applicable stages/final groups reconciled | FINAL_COMPLETE; report PASS and do not rerun |
| Existing partial, conflicting, extra, unverified or unexplained rows | PARTIAL_INCONSISTENT; stop, show IDs/counts/amounts and what a rerun would duplicate |
| Missing source/dependency/mapping/configuration | BLOCKED with the last verified state and exact affected step |

For the one-step Levy procedure, intermediate-only rows or final-only rows are PARTIAL, not a normal resume point. For a known interrupted Income/Budget procedure 2, company records without required financial output are also PARTIAL until reviewed. Do not adopt such records as proof of completion. A verified pre-existing company hierarchy that predates the import is a reusable prerequisite, not automatically a partial run.

After a timeout, native rejection or disconnect, first inspect live state. Never automatically repeat a possibly committed write. A native approval rejection is not authorization to switch tools. Scope any later correction separately; describe it concretely before approval.

## Mapping evidence and guarded UPDATE preparation

Income raw: `URBANISE_Revenue_Expenditure_Accounts`, `AccountType`.
Budget raw: `URBANISE_Budge_Details_INTERIM`, `Account_Type`.
Both converters intentionally omit the nullable `MCHID` column. Missing/incompatible MCHID is a team-schema blocker; no ALTER fallback.

Codex resolves the authoritative COA binding for the current ManagingCompanyCode read-only:

1. Inspect existing repository mapping contracts and live deployed mapping definitions, synonym targets or company configuration/registrations where such objects actually exist. Do not invent a registry table, derive a source name from the company code, or use DEV fixtures/local patches as a binding.
2. Require explicit evidence associating that company with the exact database/schema/object and account-name, ledger-type and leaf-MCHID columns. A shared source also requires its inspected company discriminator/predicate. A dedicated source requires evidence of its company association. Object existence/column compatibility alone does not establish authority.
3. Verify the object/columns and authorization/destination through SQL MCP. The existing mapping contract uses `[Urbanise Name]`, `LedgerType`, `LEVE3_MCHID`, plus descriptive/parent evidence. Bind these roles through the authoritative contract; incompatible roles block rather than trigger guessed translations or schema changes.
4. If no unique authoritative binding exists, report BLOCKED for Income/Budget with ManagingCompanyCode, inspected contract locations/catalog evidence and the exact missing company-to-source/column/filter contract. No fallback to another company's table, mapping UPDATE or downstream EXEC is permitted. Report the required external authoritative configuration.

The comparison is `raw.Account_Name = coa.[Urbanise Name]` with SQL Server's actual collation/comparison behavior. Do not normalize account names in Python, use fuzzy matching or match only by a code absent from the raw contract.

Validate supported types *before* deriving LedgerType:

- Income: expenditure -> expense; revenue/income -> income.
- Budget: expenditure -> expense; income -> income.
- Any other type blocks; the stock IIF's else branch must not turn an unknown type into income.

Use a LEFT JOIN/read-only candidate query so unmatched rows remain visible. Give each source row a stable inspection ordinal (including legitimate duplicate rows). For every row retain account, type, fund, period/date, amount, current MCHID and all candidate LEVE3_MCHIDs. Scope through the resolved property/company using verified bindings, including the COA company predicate when shared. When using the mapping helper for onboarding, supply the resolved managing_company_code and mapping_contract provenance. The helper validates supplied evidence only; it never chooses a source, queries the database or reimplements SQL collation.

For each account/ledger key calculate COUNT(*), COUNT(LEVE3_MCHID), COUNT(DISTINCT LEVE3_MCHID) and the distinct IDs. COUNT(DISTINCT) alone hides NULL targets. Require at least one candidate, no NULL/invalid target and exactly one distinct positive ID. Equivalent COA code variants may collapse to one mapping; their source detail remains evidence. Conflicting IDs or an existing non-NULL raw MCHID differing from the authoritative ID block all affected rows. Do not silently overwrite existing assignments.

Prepare the mutation only after candidate preflight passes:

1. Bind exact inspected raw/COA/property object names; present concrete SQL, no unresolved placeholders.
2. Guard the current database, unique property/company, expected raw multiset and authoritative candidate snapshot inside one transaction. Recheck conflicts/NULL targets rather than rely on a stale preview.
3. Build one mapping row per account/ledger key with SELECT DISTINCT *after* proving all candidate IDs agree. Join through the resolved property/company and update only this raw scope with `MCHID IS NULL`. No unconstrained COA join, arbitrary TOP 1 or overwriting populated values.
4. Obtain native SQL approval, execute once, then immediately compare all raw IDs with the authoritative mapping and list every remaining NULL MCHID. Include zero-amount rows in the mapping gate; later procedure exclusions are separate.

Missing matches, NULL candidates, conflicts and existing disagreements should be reported in one batch across selected Income/Budget types. Each blocker includes source row ordinal, account, ledger, fund, date, amount and reason. A zero-row raw set is not 100% coverage. No procedures for that type run until the gate passes.

## Levy Arrears

Flow: existing converter -> `URBANISE_LevyArrearsByLevyType` -> `syn_ERP_T_SNG_ImportLevyArrearsByLevyType` -> `P_SNG_IMPORT_OB_Levies` -> `T_SNG_ImportLevyArrearsByLevyType` -> `T_SNG_OBAL_Levies`.

The procedure creates both intermediate and final rows. There is no Income/Budget MCHID mapping stage. Preflight every input's lot/owner/legal-entity relation, fund resolution, levy category/type, master hierarchy path and company hierarchy. Inspect the actual fund fallback logic and require uniqueness even when stock code uses TOP 1. Require existing OBAL property setup and exactly one appropriate DRAFT occurrence for each property reached. Do not invent fund, OBAL, levy-type or classification records.

Confirm source arrears count/amount by lot/fund/category/date and compare the exact intermediate projection. Final join coverage must be one per eligible source row, without dropped lots or multiplied owners/funds/occurrences. Reconcile `Outstanding` to final `Amount`; inspect the live procedure's AppliedDate/DueDate/OriginalDueDate, description and GST derivations rather than expecting all date columns to copy verbatim. Report unapplied credits outside the converter's arrears INSERT contract separately. A PDF proven to contain zero arrears requires no invented row/EXEC; retain converter/source evidence for the no-op result.

## Income / Expense

Flow: existing accounts converter -> `URBANISE_Revenue_Expenditure_Accounts` -> mapping/NULL gate -> `syn_ERP_T_SNG_IMPORT_OB_Revenue_Expenditure` -> `P_SNG_IMPORT_OB_Revenue_Expenditure` -> `T_SNG_IMPORT_OB_Revenue_Expenditure` -> `P_SNG_IMPORT_OB_RevenueDetails` -> `T_SNG_OBAL_CompanyClassificationHierarchies`.

Before procedure 1 verify synonym/target, intermediate schema, existing fund/entity/entitlement dependencies and source multiplicities. The inspected procedure has stock fund-creation INSERTs: missing required fund configuration still blocks normal automation; do not use those statements to fabricate a missing prerequisite. Inspect their candidate SELECTs and include all actual effects in approval.

The inspected intermediate anti-join uses Plan_Number + Account_Name, omitting fund and period. Inspect existing rows with that broad key: an earlier fund/period can suppress a needed input. A repeat account across funds/periods is not itself an error on a clean load; evaluate the *actual* SELECT against existing rows and require exact source coverage. Do not patch the key or delete old rows. Verify count, amounts, identity, periods, MCHID and CompanyEntityID immediately after procedure 1, before procedure 2.

Before procedure 2:

- For each selected MCHID, require an existing `T_SNG_Master_ClassificationHierarchies` row whose ManagingCompany passes the stock filter, a matching master classification, and all parent/ancestor nodes returned by `F_SNG_GET_Master_Parent_Hierarchies`. Check parent pointers, GUIDs and paths for broken/shared/multiplying relationships; a leaf integer alone is insufficient.
- Inspect existing company classifications by CompanyID/GUID and company hierarchies by CompanyID/MCHID. Each must resolve once. If absent, project the stock DISTINCT/NOT EXISTS inserts from existing authoritative masters and the hierarchy-path function; do not manually seed them. Check that parent company paths would resolve after those inserts. Partial/conflicting existing company records block.
- Require the fund/entity resolution to agree with each intermediate row, existing `T_SNG_OBAL_Property`, and one correct DRAFT `T_SNG_OBAL_Property_Occurrences` row. No arbitrary latest/TOP 1 occurrence selection. Inspect executable database qualifiers even for these two tables.
- Check existing final rows for the property/occurrence/fund/classification groups. Fully reconciled output is reused; partial output blocks. The inspected final insert is not a safe rerun operation.

After procedure 2, reconstruct every eligible input's joins with actual generated IDs, count one match per source row, and account separately for zero-value exclusions. The inspected grouping is property + occurrence + fund + company hierarchy + classification description + ledger account; verify against the current definition. Compare each resulting sum and multiplicity with final rows. Source Account_Name is not necessarily the saved description. Use the saved classification name as stock code does. Total final rows need not always equal source count. The procedure's mismatch branch may PRINT and skip financial insertion while other work commits; tool success is insufficient.

## Budget

Flow: existing Budget converter -> `URBANISE_Budge_Details_INTERIM` -> mapping/NULL gate -> `syn_ERP_T_SNG_Master_Budge_Details` and, where referenced, `syn_ERP_T_SNG_Import_Budget` -> `P_SNG_IMPORT_MasterData_BudgetDetail_ImportIntoIntelliMasterTable` -> `T_SNG_Master_Budge_Details` -> `P_SNG_IMPORT_MasterData_BudgetDetails` -> `T_SNG_Budgets` / `T_SNG_BudgetDetails`.

Before procedure 1 verify both actual synonym targets, intermediate schema, procedure and existing unique funds/entities/entitlements. Inspect any stock fund-creation branches as for Income. Its inspected retry key is Plan_Number + Account_Name + Budget_EndDate, omitting fund: compare the actual candidate SELECT against source rows and existing intermediate data; block suppressed or multiplying rows. After execution require exact source/intermediate coverage, count, total and zero NULL MCHID/CompanyEntityID.

Before procedure 2, perform the same master/ancestor and projected company-hierarchy checks as Income. Every intermediate MCHID must resolve exactly once through the eventual company hierarchy. Read FY configuration from the objects used by the live definition, not a presumed business field:

- In the inspected version `F_SNG_Companies_L2` exposes `T_SNG_Companies.LastLocked_FinancialYearEnd`.
- The procedure passes `MONTH(C.LastLocked_FinancialYearEnd)` and each actual `Budget_EndDate` to `F_SNG_Calculate_FYEndCode` and `F_SNG_Calculate_FYStartDate`.
- It sets BudgetName to `'Budget for ' + FYEndCode`. `FinancialYear_EndMonth` is not the input in this version. A NULL anchor gives NULL name/code/start; BudgetName is NOT NULL. Missing configuration therefore blocks. Do not choose a prior-year date, financial month or default from the PDF to fix it.
- Evaluate the live expressions read-only for every fund/end-date candidate. Require non-NULL valid start/end/code/name and one company/entity/fund join. Inspect duplicate `(CompanyEntityID,FYEndCode)` headers and the separate `(CompanyEntityID,BudgetEndDate)` detail join. A header with conflicting name/dates, or multiple matching headers, blocks.
- Existing complete header/details means reconcile/reuse; partial headers/details or interrupted company inserts block. A normal proposal contains only the stock EXEC after prerequisites pass, not FY/reference fixture SQL.

After execution, verify exact expected header groups (not universally one), fields and status. Reconstruct the procedure's detail joins without its insertion-only NOT EXISTS predicate. Require one complete join per eligible source row and document excluded zero rows. Current final grouping uses BudgetID, CompanyClassificationHierarchyID, AccountNumber, IsActive, SortOrder and LastEditUserID; inspect the definition if changed.

Aggregate expected source amounts on those keys and compare to base final rows with a full outer comparison. Require one final row per expected group, no unexpected/missing group, exact amount per group and exact base-table grand total. Never sum final amounts after joining them back to multiple source rows. Intermediate CCH_ID/SNG_BudgetID/SNG_BudgetDetailID can remain NULL after a successful final procedure; these are not proof of missing final output, and not permission to rerun procedure 1.

## Verification method and reporting

Use small scoped read-only queries, retaining unmatched rows with LEFT JOIN / OUTER APPLY, and an explicit expected source multiset. Equal grand totals can hide offsetting differences; equal row counts can hide missing and multiplying joins. Check both. If a large repeated-CTE query times out, split it into bounded source/join/final reads and reconcile captured rows locally; never retry a write as a verification method.

Use the helper's `coverage` check with stable source ordinals and target IDs, then `reconcile` with the actual stock grouping keys. For raw/intermediate comparisons use multiset mode and all business key fields so duplicate multiplicity is preserved. All helper PASS results still require independently verified SQL scope and PDF coverage.

Report blockers with: financial type, exact failed stage, object/key, affected row ordinals/accounts/funds/amounts, expected versus observed cardinality/values, and the external action needed. For completed types report source/intermediate count, eligible/excluded inputs, final/group count, totals and difference, duplicate/missing counts, occurrence or header IDs. No new database writes are required for a verification-only request.
