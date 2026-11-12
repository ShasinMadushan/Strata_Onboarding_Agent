# Schema exploration without a lookup key

There is no `search_objects` tool (the sql-mcp server's own docs claim one; it is not exposed here — confirmed by direct tool lookup). Schema discovery is therefore plain SQL via `execute_sql_strata_manager` / `execute_sql_sng_erp`.

Use this when you're starting from a vague feature description rather than one of the four registration keys. If you *do* have a page name, Module, ObjType, or RefCode, use the dedicated lookup tool instead — see the main skill.

## Query cookbook

```sql
-- Procedures by name pattern
-- ALWAYS append the backup filter from the skill's Hard rules — see below.
SELECT name FROM sys.procedures WHERE name LIKE '%Jobs%' ORDER BY name;

-- Full definition of a known proc (no 4000-char truncation)
SELECT OBJECT_DEFINITION(OBJECT_ID('dbo.P_SNG_GetHTML_UIF_PG_Jobs_JobList'));

-- Table/view columns
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'T_SNG_Jobs' ORDER BY ORDINAL_POSITION;

-- A table-type's shape (t_QueryString, t_KeyValuePair, t_Cookies, t_PageElements — see intellistrata-dev)
SELECT c.name, ty.name AS DataType, c.max_length
FROM sys.table_types t
JOIN sys.columns c ON c.object_id = t.type_table_object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
WHERE t.name = 't_QueryString' ORDER BY c.column_id;

-- A proc's parameter list (fast way to confirm its real signature/category)
SELECT p.name, ty.name AS DataType, p.is_output
FROM sys.parameters p JOIN sys.types ty ON ty.user_type_id = p.user_type_id
WHERE p.object_id = OBJECT_ID('dbo.p_SNG_API_GetHTML_Jobs_ListData') ORDER BY p.parameter_id;
```

## Why the backup filter exists

A real census of `strata_manager` found **3,180 backup procedures** — more than any single "live" category. They are named `*_backup`, `*_backup 'YYYY-MM-DD HH:MM:SS'`, `*_Backup_DD_MM_YYYY`, `*_Copy_DD_MM_YYYY`, `*_V1`/`*_V2`, `*_old`, and similar. The same pollution exists on the `sng_erp` side (e.g. `V_SNG_Activities_L1_Copy_10_01_2023`).

The schema is being used as ad-hoc version control. An unfiltered `LIKE` search will return a dead snapshot alongside — or instead of — the live proc, and editing that snapshot silently does nothing to the running system. This is why the filter is a Hard rule rather than a suggestion, and why the paste-ready clause lives in the skill body rather than here.

**Do not add to the pile.** The MCP server automatically backs up a proc body before any `ALTER PROCEDURE`/`ALTER FUNCTION`, writing to `./backups/procedures/YYYY-MM-DD/` on the server — not into the live schema. Never `sp_rename` or duplicate a live proc into a `_backup`/`_Copy` name yourself, and never leave a `_TEST`/`_POC`/scratch proc deployed (a real one, `p_SNG_GetHTML_WebApi_PostMethodTest2`, was found still live).

## The schema also holds native DNN platform procs

`strata_manager` is a DotNetNuke CMS install. Procs like `DeletePortalGroup`, `CoreMessaging_*`, `sp_renamediagram`, `UpdateUrlTracking`, `SaveUserRelationship`, `ConvertTabToNeutralLanguage`, and `GetIPFilter` are DNN platform internals, not SNG application code.

A name search will surface these. Don't mistake them for app procs to modify, and don't expect them to follow SNG naming conventions (see [naming-conventions.md](naming-conventions.md)).

## Registration coverage is partial

Not every GetHTML/GetJsonData/DML proc has a row in the four registration tables — only ones a page calls directly by name from client-side JS (or via the `ModifyData` POST) need one. A proc reached only via an internal `EXEC` from another proc (e.g. a Content SP calling a helper) doesn't.

The reverse *does* hold: every registered Module/ObjType/RefCode should resolve to a real, matching stored procedure. If a lookup tool returns a row but the proc doesn't exist or is a stub, that's a bug worth flagging to the user.
