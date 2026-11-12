---
name: sql-mcp-dev
description: Explore and develop the V2_SNG_ERP_DEV SQL Server database through the sql-mcp execute_sql and execute_sql_file tools using the sng_erp source. Read before querying data, executing stored procedures, writing data, or deploying procedure changes; includes deployment approval, local mirrors, backup-name filtering, and change logging.
---

# SNG ERP SQL Server Development via MCP

## Connection and available tools

The connected server exposes one database:

| Source | Database |
|---|---|
| `sng_erp` | `V2_SNG_ERP_DEV` |

Use `sng_erp` as the source for every call, following the connected tool's actual argument schema. Access tables, views, functions, and stored procedures directly in this database; no cross-database synonym layer is required.

| Tool | Purpose |
|---|---|
| `execute_sql` | Execute inline T-SQL: queries, stored-procedure calls, DML, and DDL. |
| `execute_sql_file` | Execute T-SQL from a SQL file using the path argument supported by the server. Prefer this for complete procedure definitions that risk truncation inline; confirm the server can access the file path. |

These are the only available SQL tools. Discover objects and registrations with SQL queries, not dedicated lookup tools or database-suffixed tool names. Inspect the tool schema before calling; do not invent argument names.

**All database access goes through these MCP tools.** Do not request or hardcode direct connection strings or use sqlcmd/SSMS as a fallback. Do not assume that generic execution tools provide automatic backups, auditing, or before/after data diffs.

## Hard rules

1. **Stored-procedure execution is allowed.** Use `EXEC` through `execute_sql` or `execute_sql_file` for the requested work and verification. Inspect the procedure definition and parameters first. A procedure that writes data or changes schema follows the approval gate in Rule 3, just like direct DML or DDL; an `EXEC` is not automatically read-only.

2. **Direct reads and writes are allowed in `V2_SNG_ERP_DEV` via `sng_erp`.** This includes `INSERT`, `UPDATE`, `DELETE`, and approved schema changes. Scope writes to the intended rows and follow Rule 3. DEV access does not grant permission for unrelated changes.

3. **Deploying is a three-step workflow:** write the change to `sql_mirror/<proc_name>.sql` -> show the user what changed and why, then **stop and ask** -> deploy with `CREATE OR ALTER PROCEDURE` only after explicit approval of the concrete change. Describing the change in the same message that deploys it does not count as asking. The same gate applies to any `INSERT` / `UPDATE` / `DELETE` / `DROP` / `TRUNCATE`, other schema mutations, and procedures with those effects. Prepare and show the SQL and intended impact before requesting approval. Existing explicit approval of that concrete action remains valid; do not ask again.

4. **Proc working copies live in `sql_mirror/<proc_name>.sql` at the project root.** Pull the live definition straight there as the first write, never through a scratch file. Check freshness at approximately one day; see [Local mirror](#local-mirror-for-continued-dev-work). Preserve pending local edits before refreshing.

5. **Put dev rationale in a real T-SQL comment, outside string literals.** If a procedure emits HTML, scripts, or JSON through `@HTML` / `@HTML_Content` / `@HTML_Script` / `@JsonData`, comments inside those literals ship to consumers. Keep development explanations outside the emitted content.

6. **Every proc-name search must exclude backup snapshots.** Add these predicates to procedure-name searches, qualifying `name` with the catalog alias when needed:

   ```sql
   AND name NOT LIKE '%backup%' AND name NOT LIKE '%[_]Copy%' AND name NOT LIKE '%[_]old'
   AND name NOT LIKE '%[_]V1' AND name NOT LIKE '%[_]V2'
   AND name NOT LIKE '%[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]%'
   AND name NOT LIKE '%[0-9][0-9][_][0-9][0-9][_][0-9][0-9][0-9][0-9]%'
   ```

   `[_]` matches a literal underscore in SQL Server `LIKE`. Do not create backup-named procedures. Retain the pre-change definition locally or in version control for recovery; rely on server backups only when that behavior has been confirmed.

7. **Log every proc change in `sp_changelog/CHANGELOG.md`, newest at top.** Record the date, schema-qualified procedure name, what changed, why, and verification outcome. Distinguish locally prepared changes from successful deployments; record failed or pending deployments accurately.

## Finding database objects

Use SQL Server catalog views through `execute_sql`:

- `sys.procedures` joined to `sys.schemas`: find procedures by schema and name, applying Rule 6.
- `sys.tables`, `sys.views`, and `sys.objects`: discover tables, views, and functions.
- `sys.columns` joined to `sys.types`: inspect column names, types, and nullability.
- `sys.parameters` joined to `sys.types`: inspect procedure and function parameters.
- `sys.sql_modules` or `OBJECT_DEFINITION`: read definitions.
- `sys.synonyms`: inspect synonym targets only when an actual dependency requires it.

For example, find live procedures by a supplied name fragment:

```sql
SELECT s.name AS schema_name, p.name, p.modify_date
FROM sys.procedures AS p
JOIN sys.schemas AS s ON s.schema_id = p.schema_id
WHERE p.name LIKE N'%<name_fragment>%'
  AND p.name NOT LIKE '%backup%'
  AND p.name NOT LIKE '%[_]Copy%'
  AND p.name NOT LIKE '%[_]old'
  AND p.name NOT LIKE '%[_]V1'
  AND p.name NOT LIKE '%[_]V2'
  AND p.name NOT LIKE '%[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]%'
  AND p.name NOT LIKE '%[0-9][0-9][_][0-9][0-9][_][0-9][0-9][0-9][0-9]%'
ORDER BY s.name, p.name;
```

If the task starts with an application registration key, first discover whether the relevant registration table exists in this database and inspect its columns. Query it directly using the supplied or observed key. Do not assume portal registration tables exist or infer undocumented keys.

Common naming hints include `T_SNG_*` tables, `V_SNG_*` views, `F_SNG_*` functions, and `P_SNG_*` procedures. Confirm object types and parameter signatures from the live catalog.

The existing files under `references/` are legacy background and have not been synchronized to this connection. Their database/tool inventories, access restrictions, registration examples, and server-backup claims are not authoritative. Use this skill for the connection and workflow, and the live catalog for schema facts.

## Reading, editing, and deploying a procedure

1. **Pull the live definition before starting a change:**

   ```sql
   SELECT OBJECT_DEFINITION(OBJECT_ID(N'dbo.<proc_name>')) AS definition;
   ```

   Use the actual schema. A NULL result may indicate a missing object, insufficient metadata permissions, or an encrypted definition; resolve it before editing.

2. **Save and edit in `sql_mirror/<proc_name>.sql`.** Retain the pre-change definition or diff for review and recovery before replacing it with the proposed version. Keep complete SQL and escape embedded string literals correctly.
3. **Show the concrete change and obtain approval** under Rule 3. Prepare the full deployable file before asking.
4. **Check for concurrent changes** against the captured live definition before deployment. Reconcile unexpected changes and seek renewed approval if the approved change materially changes.
5. **Deploy with `CREATE OR ALTER PROCEDURE`** through `execute_sql` or `execute_sql_file`.
6. **Verify through an appropriate direct `EXEC` and focused queries.** Inspect required parameters and side effects first; get approval for write-producing verification unless already covered. Use application-level verification too when relevant.
7. **Log the change and result** under Rule 7.

## Executing procedures and writing data

- Build calls from the actual signature, including output parameters and table-valued parameters where required. Use realistic, scoped inputs from the task.
- For direct DML, inspect the target rows first and show the SQL, affected scope, and intended result for approval.
- Treat dynamic SQL and nested procedure calls as potential side effects when deciding whether an execution needs write approval.
- Use transactions when appropriate for the operation. Do not assume a transaction persists across separate MCP calls or that rollback reverses external side effects.
- Verify affected rows and resulting state after an approved write. Report errors or incomplete verification explicitly.

## Local mirror for continued dev work

- Store maintained procedure files in `sql_mirror/<proc_name>.sql` at the project root. If schemas contain duplicate procedure names, use schema-qualified filenames consistently.
- **Freshness gate:** pull the live definition at the start of a new change. During continued work, refresh a missing copy or one older than approximately one day; preserve pending edits and reconcile them with live changes before replacing the local file.
- A recently modified local file does not prove the live procedure is unchanged. Compare with the captured baseline before deployment.
- Deploy with `CREATE OR ALTER PROCEDURE`, and keep the mirror aligned with the successfully deployed definition.
- Keep mirror files committed when version control is available. They are maintained working copies, not scratch output.
