#!/usr/bin/env bash
# PreToolUse hook (matcher: mcp__phpstorm__execute_tool) for read-only subagents.
#
# The JetBrains built-in MCP server exposes ~80 sub-tools behind ONE MCP tool,
# `execute_tool`, whose `command` string starts with the sub-tool name. Claude's
# permission rules cannot see inside that string, so a subagent allowed to call
# execute_tool could also run execute_terminal_command, apply_patch, SQL or Xdebug.
# This gate allows an explicit list of read-only sub-tools and blocks the rest.
#
# analyze_calls is deliberately NOT on the list: it runs the same usage search
# that pins PhpStorm for minutes on library scope.
#
# Contract: stdin = hook JSON; exit 0 = allow; exit 2 + stderr = block.

INPUT=$(cat)
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null)
[ -z "$CMD" ] && exit 0

# First token of the command string, ignoring leading whitespace.
TOOL=$(printf '%s' "$CMD" | sed -E 's/^[[:space:]]+//' | awk '{print $1}')

ALLOW='^(locate_symfony_service|search_symbol|search_text|search_regex|search_file|search_structural|get_symbol_info|get_file_problems|get_inspections|get_composer_dependencies|get_project_dependencies|get_project_modules|get_php_project_config|get_all_open_file_paths|get_run_configurations|get_repositories|get_structural_patterns|git_status|list_directory_tree|list_doctrine_entities|list_doctrine_entity_fields|list_symfony_commands|list_symfony_forms|list_symfony_form_options|list_symfony_routes_url_controllers|list_twig_components|list_twig_extensions|list_twig_template_usages|list_twig_template_variables|list_symfony_profiler|get_symfony_profiler_details|read_file|lint_files|describe_magento_cli_environment|get_magento_root_path)$'

if printf '%s' "$TOOL" | grep -qE "$ALLOW"; then
  exit 0
fi

echo "BLOCK: '$TOOL' is not a read-only lookup tool. This agent may only call: locate_symfony_service, search_symbol, search_text, search_regex, search_file, search_structural, get_symbol_info, get_file_problems, get_inspections, get_composer_dependencies, get_project_dependencies, get_project_modules, get_php_project_config, list_directory_tree, list_doctrine_entities, list_doctrine_entity_fields, list_symfony_commands, list_symfony_forms, list_symfony_form_options, list_symfony_routes_url_controllers, list_twig_*, read_file, lint_files, git_status. analyze_calls is excluded because it runs a library-wide usage search; use search_text on the call expression instead." >&2
exit 2
