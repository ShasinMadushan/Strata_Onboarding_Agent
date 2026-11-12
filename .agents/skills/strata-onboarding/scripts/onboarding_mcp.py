"""Strata file tools. No autonomous orchestration, model/API calls or SQL execution."""
from mcp.server.mcpserver import MCPServer
import csv_batches as batches
import prepare_sql

mcp = MCPServer("Strata Onboarding Files")


@mcp.tool()
def inspect_plan(plan_folder: str, plan_number: str) -> dict:
    """Read source inventory and exclusion policy; no files or database are written."""
    return batches.inspect_plan(plan_folder, plan_number)







@mcp.tool()
def initialize_run(plan_folder: str, plan_number: str, property_id: int, managing_scope: int,
                   run_id: str, building_address: dict | None = None,
                   contacts_missing_accepted: bool = False, tenant_communication_decision: str = "") -> dict:
    """Create a LOCAL run manifest and bounded batches; never execute SQL or call a model."""
    return batches.initialize_run(plan_folder, plan_number, property_id, managing_scope, run_id,
                                  building_address, contacts_missing_accepted, tenant_communication_decision)


@mcp.tool()
def inspect_run(run_path: str) -> dict:
    """Read run progress and verify source/spec hashes without writing files."""
    return batches.inspect_run(run_path)


@mcp.tool()
def read_batch(run_path: str, kind: str, batch_id: int) -> dict:
    """Read one complete bounded batch and exact output schema; no writes."""
    return batches.read_batch(run_path, kind, batch_id)


@mcp.tool()
def convert_lot_owner_batch(run_path: str, batch_id: int) -> dict:
    """Convert one bounded Lot/Owner batch using the canonical v2.9 prompt implementation; local only."""
    return batches.convert_lot_owner_batch(run_path, batch_id)


@mcp.tool()
def save_validated_batch(run_path: str, kind: str, batch_id: int, records: list[dict], flags: list[dict]) -> dict:
    """Validate provenance/schema then save a LOCAL batch; invalid batches are rejected."""
    return batches.save_validated_batch(run_path, kind, batch_id, records, flags)


@mcp.tool()
def assemble_outputs(run_path: str) -> dict:
    """Revalidate all batches and write LOCAL CSVs, flags and reconciliation; never import."""
    return batches.assemble_outputs(run_path)


@mcp.tool()
def prepare_staging_sql(run_path: str, kind: str, schema_name: str, approved_review: str = "") -> dict:
    """Prepare local staging SQL; include explicit user-approved review text when review flags exist. Never executes SQL."""
    return prepare_sql.prepare_staging_sql(run_path, kind, schema_name, approved_review)


if __name__ == "__main__":
    mcp.run(transport="stdio")
