#!/usr/bin/env bash
# Claude Code configuration
# Experimental flags for MCP token optimization

# Enable Tool Search - Claude discovers MCP tools on-demand instead of loading all at startup
# Saves 30-100k tokens depending on MCP server count
# Note: Experimental, may change in future versions
export ENABLE_TOOL_SEARCH=true
