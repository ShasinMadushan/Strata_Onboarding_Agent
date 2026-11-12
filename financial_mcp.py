from mcp.server.mcpserver import MCPServer
import sys
import subprocess
import os


mcp = MCPServer("Financial Scripts Server")

SCRIPTS_FOLDER = "scripts"
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

@mcp.tool()
def convert_urbanise_accounts(pdf_path: str, output_sql_path: str) -> str:
    """Extract Urbanise revenue/expenditure account totals from a PDF into a SQL file."""
    if not os.path.exists(pdf_path):
        return f"Error: PDF not found at {pdf_path}"
    
    script_path = os.path.join(BASE_DIR, SCRIPTS_FOLDER, "extract_urbanise_accounts.py")
    cmd = [sys.executable, script_path, pdf_path, "--output", output_sql_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode == 0:
        return f"Success! SQL file generated at {output_sql_path}\nLog: {result.stdout}"
    else:
        return f"Failed to generate SQL.\nError: {result.stderr}"

@mcp.tool()
def convert_levy_arrears(pdf_path: str, output_sql_path: str) -> str:
    """Extract open levy items from an Urbanise levy statement PDF and generate SQL inserts."""
    if not os.path.exists(pdf_path):
        return f"Error: PDF not found at {pdf_path}"
    
    script_path = os.path.join(BASE_DIR, SCRIPTS_FOLDER, "levy_arrears_parser.py")
    cmd = [sys.executable, script_path, pdf_path, "--sql-output", output_sql_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode == 0:
        return f"Success! SQL file generated at {output_sql_path}\nLog: {result.stdout}"
    else:
        return f"Failed to generate SQL.\nError: {result.stderr}"

@mcp.tool()
def convert_urbanise_budget(pdf_path: str, output_sql_path: str) -> str:
    """Convert an Urbanise annual-budget PDF into normalized SQL INSERT rows."""
    if not os.path.exists(pdf_path):
        return f"Error: PDF not found at {pdf_path}"
    
    script_path = os.path.join(BASE_DIR, SCRIPTS_FOLDER, "urbanise_budget_to_sql.py")
    cmd = [sys.executable, script_path, pdf_path, "--output", output_sql_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode == 0:
        return f"Success! SQL file generated at {output_sql_path}\nLog: {result.stdout}"
    else:
        return f"Failed to generate SQL.\nError: {result.stderr}"

if __name__ == "__main__":
    mcp.run(transport='stdio')