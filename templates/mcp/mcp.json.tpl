{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp"]
    },
    "cve-mcp": {
      "command": "{{CVE_MCP_PYTHON}}",
      "args": ["-m", "cve_mcp.server"],
      "cwd": "{{CVE_MCP_HOME}}"
    }
  }
}
