# Staging and import

## Inspect before preparing

Live contracts were not inspected during file creation. After release of the approval checkpoint, inspect schemas, columns/types, parameters, module definitions and synonyms via read-only SQL MCP. Resolve actual schemas for function/procedures.

Apply sql-mcp-dev backup filters to exploratory procedure searches. The explicitly requested ImportCommunicationPreferences_V2 is an exact dependency: inspect it and its dedicated synonym directly rather than dropping it via generic _V2 filtering. Creating/retargeting synonyms needs separate DDL approval. Recheck target before import.

Verify source identity, complete CSV reconciliation and review dispositions. Excluded Tenant artifacts cannot be staged or treated as successful imports.

## Stage

prepare_staging_sql produces one run-specific raw-text table per eligible kind in a caller-selected existing schema. Explicit columns, escaped Unicode literals, SQL SHA-256. CREATE and INSERT always need approval.

Names derive from plan_number, property_id, run_id and collision-resistant digest. If downstream requires typed staging, prepare reviewed conversion SQL using live metadata: explicit blank/NULL policy, dd/MM/yyyy dates, decimal/bit/key types. Conversion errors stop; never silently turn errors into NULL.

Load all four eligible CSVs through SQL MCP; missing/excluded kinds stay blocked. Reconcile rows and keys after each load. BULK INSERT requires confirmed server-path access, quoting/encoding and approval.


### Company staging database selection

Before staging, verify the intended database and schema.

For ABOVEOCM local DEV, prepare company-compatible staging in
AboveOCM_Local_Test, not V2_SNG_ERP_DEV.

The existing prepare_staging_sql tool generates schema-qualified
raw-text tables, not database-qualified company staging tables.
Its schema_name argument is not a database selector.

If raw staging is required, explicitly verify its destination
and use only a reviewed, correctly database-scoped execution copy.

For Lot/Owner flattening, use the approved company staging
structure defined by:
manual_sql/non_financial/01_create_staging_and_load.sql

Prepare a property-specific execution copy with the verified
database, table name and source data. Preserve the original
54-column schema, types and required NULL behaviour.

When loading converted data through SQL INSERT instead of
BULK INSERT, preserve the approved company schema and blank/NULL
semantics. Verify the actual stored values against the CSV.

Do not assume generic onb_* raw-text staging is compatible
with the company flatten mapping.

Use template 02 for the property-specific master table and
template 03 for flattening directly into that verified table.

Keep ComPref and Committee separate. Verify their actual
approved destination contracts before staging or importing.

Never modify the original company SQL templates.
Every database write requires separate approval.

## Flatten

Use the existing company-approved flattening SQL when available.

Before reporting that a mapping is missing, inspect:
manual_sql/non_financial/03_flatten_to_master.sql




The existing ABOVEOCM company SQL templates are approved
mapping references for ABOVEOCM properties, not only PS732663R.

The PS732663R table names in the original SQL are examples
of property-specific identifiers.

For each new ABOVEOCM property, inspect the original company
SQL templates 01, 02 and 03, verify the actual source and
target schemas, and prepare property-specific execution copies.

Do not request a new business mapping solely because the
original SQL contains PS732663R.

If the schemas or business requirements are incompatible,
stop and report the exact issue.


Before flattening, verify that the company staging table
contains the approved Lot/Owner data from the current run,
including any approved staging corrections.

Matching row counts alone are not sufficient.

If the run-specific staging and company staging differ,
stop and report the differences. Do not silently overwrite,
reload or substitute either table.

Any required data transfer or correction needs separate
review and SQL approval.

The original mapping converts Lot/Owner staging data into
one master row per lot.

Committee and ComPref are separate staging/import processes.
Do not require them to be included in the Lot/Owner master.

Preserve the original company SQL business logic, column
mapping, joins and aggregation rules.

Verify source data, duplicate contacts, contact slots,
join multiplicity and target schema before execution.
Flag conflicts instead of silently changing mapping rules.


Do not recreate a master table if the verified master table
for the CURRENT property already exists. A master table
belonging to another property does not count.


Do not repeat completed staging or overwrite existing
master records.

Prepare a reviewed execution copy using verified property,
company and database identifiers.

For any ABOVEOCM property, use the verified CompanyCode
and confirm that the original company SQL literal is
compatible with the ERP import contract.

Handle GO as a SQL client batch separator when executing
through SQL MCP. Keep the original company SQL unchanged.

Before execution:
- Confirm the correct source and target.
- Resolve pending staging corrections.
- Confirm the master target is empty.
- Preview the expected master rows.
- Show exact executable SQL and SHA-256.
- Request separate native SQL approval.

Execute only after approval and verify imported content.


### Reuse ABOVEOCM flatten mapping for new properties


For any verified ABOVEOCM property, use the approved company mapping in
`manual_sql/non_financial/03_flatten_to_master.sql`.
Its PS732663R references are property-specific identifiers, not a
restriction of the business mapping to that property.

Use `01_create_staging_and_load.sql` and `02_create_master_table.sql`
from the same approved company folder to verify the required staging
and master schemas.

For a new ABOVEOCM property, prepare per-run execution copies.
Replace only verified PlanNumber, source/target table references,
input paths and database context. Preserve all business mapping logic
and keep the original SQL files unchanged.

Verify that the actual staging data, column types and NULL handling
are compatible before flattening. If not, report the exact
incompatibility rather than declaring the company mapping missing.

A shared ERP synonym still pointing to PS732663R is not evidence
that the ABOVEOCM flatten mapping is unavailable. Do not change
synonyms without separate review and approval.

For other managing companies, require their own approved mappings.

Show the prepared SQL and request approval before any database write.


### Property-specific master staging safety

For every new ABOVEOCM property, the flatten target must be
verified for that property's PlanNumber and PropertyID.

Never use the shared ERP master synonym as the flatten
INSERT target. Always use the verified, property-specific
master table directly.

Inspect the synonym separately before ERP import.

A synonym pointing to another property's master table must
not be treated as the current property's master staging table.

Use the approved company template:
manual_sql/non_financial/02_create_master_table.sql

Prepare a run-specific execution copy to create the new
property's master table if it does not already exist.




Never use a fixed property number or another property's
existing master table as the target.


Then use:
manual_sql/non_financial/03_flatten_to_master.sql

Prepare a property-specific execution copy that inserts
DIRECTLY into the verified property-specific master table,
not into an old property synonym.

Before execution:
- Confirm the correct staging database.
- Verify the source and master table schemas.
- Check whether the target table already exists.
- Verify that the target belongs to the current property.
- Confirm the current property has no existing master rows.
- Preserve all original company SQL mapping expressions.
- Show exact SQL and SHA-256 for approval.

Never insert a new property's flattened rows into another
property's master table.

Do not modify or retarget existing ERP synonyms during
flattening.

Synonym requirements for later ERP import must be inspected
and approved separately.

Do not repeat completed Lot/Owner, ComPref or Committee staging.
Never modify the original company SQL templates.
Every database write requires separate explicit approval.


The agent must dynamically identify the current property's
verified PlanNumber, PropertyID, company, source staging table
and master table.

For ABOVEOCM properties, reuse the approved company SQL
templates 01, 02 and 03 without changing their business logic.

For other managing companies, use only their own verified
company-approved SQL templates.

Never assume that a previous property's table names,
identifiers, data or synonym destinations apply to a new property.

If the required company schema or mapping is incompatible,
stop and report the exact issue before execution.

For ABOVEOCM, derive the target table name from the
verified PlanNumber and the naming convention in
02_create_master_table.sql:

dbo.T_SNG_IMPORT_MasterData_{VerifiedPlanNumber}

Confirm the resulting table name and database against
the approved company SQL before execution.



## Resolve property and import

Inspect function signature; query the actual schema's F_SNG_Properties_L3_CORE(managing_scope), filtering PropertyID=property_id. 69 was the user's example, not a default. No row means stop for missing property linkage. Manual linking remains a separate temporary local-dev utility.

Inspect actual signatures/nested effects, prepare calls and execute ONLY after approval, in order:
1. ImportIntoIntelliMasterTable
2. ImportLots
3. ImportOwners
4. ImportLotEntitlements
5. ImportCommunicationPreferences_V2 through its own verified synonym.

Use actual parameter names/types/output parameters. Show Committee/Tenant retagging limitation before ImportOwners approval; never create contacts or IDs yourself.

Verify scope, rows, identifiers, entitlements and communication preferences after each step. Stop on mismatch/error. Transactions must fit one call where appropriate; never assume session/transaction persistence across MCP calls or rollback of external effects.

## Resume

Record SQL hash, explicit approval, execution and verification separately. Timeout requires state inspection before retry. No automatic replay/deletes/truncates. Procedure changes need separate scope; existing mirror/changelog rules apply.
