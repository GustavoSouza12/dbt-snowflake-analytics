"""MCP server that lets an AI list and query the dbt semantic layer metrics."""

import csv
import json
import subprocess
import sys
import tempfile
from pathlib import Path

from mcp.server.mcpserver import MCPServer

PROJECT_DIR = Path(__file__).resolve().parent.parent
DBT_DIR = PROJECT_DIR / "src" / "dbt"
MANIFEST = DBT_DIR / "target" / "semantic_manifest.json"
MF = Path(sys.executable).with_name("mf")

server = MCPServer(name="metrics-server")


def snowflake_env() -> dict:
    loaded = subprocess.run(
        ["bash", "-c", "set -a; . ./.env; set +a; env -0"],
        cwd=PROJECT_DIR, capture_output=True, text=True, check=True,
    )
    return dict(item.split("=", 1) for item in loaded.stdout.split("\0") if "=" in item)


@server.tool()
def list_metrics() -> list[dict]:
    """List the business metrics available, with their descriptions.
    Use this first to find which metric answers the question."""
    manifest = json.loads(MANIFEST.read_text())
    return [
        {"name": m["name"], "description": m.get("description", "")}
        for m in manifest["metrics"]
    ]


@server.tool()
def query_metrics(metrics: list[str], group_by: list[str] | None = None) -> list[dict]:
    """Query business metrics, optionally grouped.
    Group by 'organization' (the id) and 'organization__organization_name' for names,
    because names are not unique. Use 'metric_time__month' to group by month."""
    with tempfile.TemporaryDirectory() as tmp:
        output = Path(tmp) / "result.csv"
        command = [str(MF), "query", "--metrics", ",".join(metrics), "--csv", str(output)]
        if group_by:
            command += ["--group-by", ",".join(group_by)]
        run = subprocess.run(command, cwd=DBT_DIR, env=snowflake_env(), capture_output=True, text=True)
        if run.returncode != 0 or not output.exists():
            return [{"error": run.stdout[-1500:] + run.stderr[-1500:]}]
        with output.open() as f:
            return list(csv.DictReader(f))


if __name__ == "__main__":
    server.run()
