# Local validation helper

`scripts/validate_financial.py` is a stateless checker, not an orchestrator. It reads an explicitly supplied PDF or JSON and prints a result; it has no SQL/MCP client, write, subprocess, retry, approval, saved-state or scheduling capability. Codex still selects tools, verifies live contracts and seeks native SQL approval. No helper result authorizes a mutation.

Run from the repository with its existing Python environment:

```text
.venv/Scripts/python.exe -B .agents/skills/financial-onboarding/scripts/validate_financial.py classify <source.pdf>
.venv/Scripts/python.exe -B .agents/skills/financial-onboarding/scripts/validate_financial.py rows <conversion-rows.json>
.venv/Scripts/python.exe -B .agents/skills/financial-onboarding/scripts/validate_financial.py mapping <sql-mapping-evidence.json>
.venv/Scripts/python.exe -B .agents/skills/financial-onboarding/scripts/validate_financial.py coverage <sql-join-evidence.json>
.venv/Scripts/python.exe -B .agents/skills/financial-onboarding/scripts/validate_financial.py reconcile <comparison.json>
.venv/Scripts/python.exe -B .agents/skills/financial-onboarding/scripts/validate_financial.py state <inspected-stage-evidence.json>
```

Paths are explicit. The normal CLI refuses files within `dev_only`, `tests` or `fixtures` directories, including resolved symlink/junction targets. It never searches output directories for executable SQL. Do not copy a fixture outside its directory to bypass this boundary. Test code invokes pure functions separately and cannot be used as an import command.

## Evidence contracts

JSON decimal strings are preferred; JSON decimal numbers are read as Decimal. No currency symbols, comma formatting, non-finite values or silent rounding. Missing/malformed fields fail the check. Stable source IDs are row ordinals from the source/query, not MCHIDs/account names: two identical business rows still have different IDs. Keep the source snapshot unchanged across related queries; reacquire evidence if the database changes.

| Check | JSON arguments / scope |
|---|---|
| `classify` | Takes a PDF directly. Reads titles across all pages, returns type/candidates and detected canonical plans. Unknown/ambiguous titles, no text or multiple plans do not pass. It does not prove full content coverage or resolve a property. Filename is ignored. |
| `rows` | `kind` = levy/income/budget; `rows` = literal converted rows; `plan` = independently resolved canonical plan; `allowed_funds` = source funds supported by the converter and verified against the report. This list is not invented DB fund configuration. |
| `mapping` | `kind`, `rows`, `require_mapped`. For normal onboarding also supply `managing_company_code` from the resolved property and `mapping_contract` containing `ManagingCompanyCode`, `source` (exact qualified mapping object) and `authority` (inspected binding evidence reference). Wrong-company/missing provenance fails. Row-only calls remain available for offline checks and do not prove company authority. Each row includes `source_id`, `account_type`, `candidate_mchids` (all SQL LEFT JOIN candidates, retaining NULL), current `MCHID` and contextual fields (account, fund, date, amount). With `require_mapped=false` it checks proposed assignments; with `true` it also blocks remaining NULL raw IDs. It returns evidence, not UPDATE SQL. Codex verifies the binding and candidate scope itself. |
| `coverage` | `source_ids` = all eligible input ordinals; `matches` = SQL query rows with `source_id` and `target_key`. Use actual target IDs (a scalar or list of non-NULL IDs), not guessed future IDs. A NULL target means an unmatched LEFT JOIN row. Missing, extra and multiple query rows are detected, even if their amounts cancel. Several sources may legitimately share one grouped final target. |
| `reconcile` | `expected`, `actual`, `key_columns`, `amount_column` (default Amount), `grouped` (default false). Multiset mode preserves duplicate row multiplicities and compares amounts within each full business key. Grouped mode sums only expected rows; actual must have exactly one row per expected group, matching its exact amount. Unexpected groups and duplicate final rows fail even when the grand total matches. |
| `state` | `kind`, `raw`, `mapping`, `intermediate`, `final`; optional `blockers`, `uncertain_write`, `incomplete_company_effects`. Raw/intermediate/final values are ABSENT/MATCH/MISMATCH/UNVERIFIED, established by live reconciliation. Mapping is NOT_CHECKED/PASS/BLOCKED or NOT_REQUIRED for Levy only. Returns an evidence label; there are no run/next/execute operations. |

`MATCH` for final state requires the complete header/occurrence, all eligible inputs, exact groups/totals and no missing/multiplying matches. A header-only result is MISMATCH, not MATCH or ABSENT. `incomplete_company_effects` describes a known interrupted step, not every pre-existing hierarchy. Never set flags based merely on successful EXEC or tool output. Missing external dependencies are reported alongside the last reconciled stage. No state label stores approval or replaces live reinspection.

Labels are NOT_STARTED, RAW_LOADED, MAPPED, INTERMEDIATE_COMPLETE, FINAL_COMPLETE, PARTIAL_INCONSISTENT and BLOCKED. Capture fresh database evidence separately per property/company/type/period. Generated JSON is a transient validation input, never a resume authority or run file. The helper neither manages state nor determines which procedure to call.

The row checker requires exact converter columns:

- Levy: PlanNumber, LotNumber, Fund, Levy type, Levy category, Due date, LevyStartDate, LevyEndDate, Outstanding.
- Income: Plan_Number, Fund_Name, Account_Name, AccountType, Amount, Period_Start, Period_End.
- Budget: Plan_Number, Fund_Name, Account_Name, Account_Type, Budget_EndDate, Amount.

Extract literal VALUES from the actual generated SQL, retaining all statements and multiplicities. If converting SQL CONVERT/CAST literals to JSON, preserve the represented value exactly and account for every source expression. SQL validation still requires inspecting the whole file's target, column list and executable statements before approval. The helper is deliberately not an SQL parser or execution sandbox. Do not use its row result to approve uninspected SQL text. Cross-check PDF totals/sections independently of these rows; the same mistakenly omitted source row must not disappear from both sides of a comparison.

`valid=false` fails validation. `requires_review=true` lists duplicate conversion row ordinals without deleting them; determine from the PDF whether multiplicity is intentional before proceeding. Exit status 2 reports invalid/review-required input. A state command's exit success means the evidence was classified, not that its state permits execution. Empty row sets never establish full-import success; the skill's separately evidenced zero-arrears no-op is handled by Codex.

## Reconciliation usage

For raw/intermediate comparisons select all relevant business fields: plan, fund, account/type or lot/category, dates, amount and mapping/fund IDs where applicable. Resolve expected stock transformations explicitly before comparison. Do not substitute aggregate totals for row evidence.

For final Income/Budget, first run coverage against every eligible source row. Then compare expected grouped source amounts with **base final table rows**, using the deployed procedure's actual grouping keys. Do not supply a source-joined copy of final rows to the grouped check: that would count a shared final row repeatedly. Account for zero/excluded rows in a separate source list. A grouped PASS alone does not prove one-to-one join coverage; both checks are required.

Before mutation, missing company hierarchy IDs may be projected only from unique existing master/GUID nodes and the stock insert semantics, explicitly marked as a projection. After mutation use actual IDs from SQL. No helper creates projections, IDs, mappings or reference values.

## Offline tests

```text
.venv/Scripts/python.exe -B -m unittest discover -s .agents/skills/financial-onboarding/tests -v
.venv/Scripts/python.exe -B -m unittest discover -s .agents/skills/strata-onboarding/scripts -p test_onboarding.py -v
```

Tests include unknown/mixed PDFs, exact columns/dates/funds, decimal amounts, duplicate candidate mappings, conflicting/NULL targets, existing mapping disagreement, unsafe rerun states, missing/multiplying joins and offsetting reconciliation errors. Local PDF regression values live only in tests. Those tests use the existing parsers unchanged, create conversion output only in temporary test directories, and skip if local reference PDFs are unavailable. Arbitrary-property/company tests exercise all three converter contracts, company-specific mapping evidence and independent state classifications without reference PDFs. Tests do not call SQL, run imports or seed data; offline results are not live import certification.
