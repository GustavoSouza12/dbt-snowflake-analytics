"""Calls the metrics MCP server the same way an AI client would, to test it without one."""

import asyncio
import sys
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

SERVER = Path(__file__).resolve().with_name("metrics_server.py")


async def main():
    params = StdioServerParameters(command=sys.executable, args=[str(SERVER)])
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            await session.initialize()

            tools = await session.list_tools()
            print("tools:", [t.name for t in tools.tools])

            metrics = await session.call_tool("list_metrics", {})
            print("\nmetrics:")
            for item in metrics.content:
                print(item.text)

            result = await session.call_tool("query_metrics", {
                "metrics": ["number_of_orders", "completed_orders", "completion_rate", "completed_order_amount"],
                "group_by": ["organization", "organization__organization_name"],
            })
            print("\nquery_metrics:")
            for item in result.content:
                print(item.text)


asyncio.run(main())
