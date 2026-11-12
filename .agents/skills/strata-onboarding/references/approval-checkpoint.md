# Native approval checkpoint

1. Show actual SQL-tool configuration sections without authentication headers. Obtain explicit approval to change them.
2. Set execute_sql and execute_sql_file approval_mode="prompt" and top-level approvals_reviewer="user".
3. Verify client activation/reload; editing TOML alone does not change the active registry. Request a new session if needed.
4. Read-only SELECT and metadata queries do not require a mandatory approval-gate test. Do not use `SELECT 1 AS approval_gate_test;` as a blocker.
5. Before each database write or EXEC, show the exact SQL, SHA-256, target objects and property scope. Stop for explicit user approval.
6. Keep native SQL MCP approval enabled for all writes. If the required native approval does not appear, stop and report. Never bypass SQL MCP or treat chat approval as native approval.
7. Read-only discovery and existing conversion work may continue without a special approval-gate test. Resume the existing onboarding run without restarting completed stages.

Use actual tool arguments. Connection is sng_erp / V2_SNG_ERP_DEV; if the exposed tool has no source argument, do not invent one.

Official references:
- https://learn.chatgpt.com/docs/extend/mcp?surface=cli
- https://learn.chatgpt.com/docs/config-file/config-reference
