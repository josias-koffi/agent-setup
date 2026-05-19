# Project-local Codex CLI config — MCP servers mirrored from .mcp.json (Claude Code).
# Codex merges this with ~/.codex/config.toml; the closer file wins.
# Project-local config only loads when the project is marked trusted.

[mcp_servers.context7]
command = "npx"
args = ["-y", "@upstash/context7-mcp"]

[mcp_servers.cve-mcp]
command = "{{CVE_MCP_PYTHON}}"
args = ["-m", "cve_mcp.server"]
cwd = "{{CVE_MCP_HOME}}"
