#!/usr/bin/env python3
"""
Unified Frontmatter Validator for Claude Code Components

Validates YAML frontmatter in skills, agents, and commands against
the official Anthropic schema.

Usage:
    uv run --with pyyaml validate.py [OPTIONS] PATH...

Examples:
    validate.py ~/.claude/agents/                    # Validate all agents
    validate.py ~/.claude/                           # Validate all components
    validate.py --json --strict .claude/             # CI mode
    validate.py --type agent custom-agent.md        # Force type detection
"""

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Optional

import yaml


# Schema definitions based on official Anthropic docs
SCHEMAS = {
    "skill": {
        "required": {"name", "description"},
        "optional": {"license", "allowed-tools", "metadata"},
        "rules": {
            "name": {"max_length": 64, "pattern": r"^[a-z0-9][a-z0-9-]*[a-z0-9]$|^[a-z0-9]$"},
            "description": {"max_length": 1024, "no_angle_brackets": True},
        },
    },
    "agent": {
        "required": {"name", "description"},
        "optional": {"tools", "model", "permissionMode", "skills", "color"},
        "rules": {
            "name": {"max_length": 50, "pattern": r"^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]$|^[a-zA-Z0-9]$"},
            "model": {"enum": ["sonnet", "opus", "haiku", "inherit"]},
            "permissionMode": {"enum": ["default", "acceptEdits", "bypassPermissions", "plan", "ignore"]},
            "color": {"enum": ["blue", "cyan", "green", "yellow", "magenta", "red"]},
        },
    },
    "command": {
        "required": set(),
        "optional": {"description", "allowed-tools", "argument-hint", "model", "disable-model-invocation", "name"},
        "rules": {
            "disable-model-invocation": {"type": "bool"},
        },
    },
}


class ValidationResult:
    def __init__(self, path: str, component_type: str):
        self.path = path
        self.type = component_type
        self.errors: list[str] = []
        self.warnings: list[str] = []

    @property
    def valid(self) -> bool:
        return len(self.errors) == 0

    def to_dict(self) -> dict:
        return {
            "path": self.path,
            "type": self.type,
            "valid": self.valid,
            "errors": self.errors,
            "warnings": self.warnings,
        }


def detect_component_type(path: Path, frontmatter: dict) -> str:
    """Detect component type from path or frontmatter."""
    path_str = str(path)

    # Path-based detection
    if "/agents/" in path_str or path_str.endswith("/agents"):
        return "agent"
    if "/commands/" in path_str or path_str.endswith("/commands"):
        return "command"
    if path.name == "SKILL.md" or "/skills/" in path_str:
        return "skill"

    # Fallback: inspect frontmatter fields
    fields = set(frontmatter.keys())

    if "model" in fields and "tools" in fields:
        return "agent"
    if "argument-hint" in fields or "disable-model-invocation" in fields:
        return "command"
    if "license" in fields or "metadata" in fields:
        return "skill"

    # Default based on required fields
    if "name" in fields and "description" in fields:
        return "skill"  # Most restrictive default

    return "command"  # Most permissive


def extract_frontmatter(content: str) -> tuple[Optional[dict], Optional[str]]:
    """Extract YAML frontmatter from markdown content."""
    if not content.startswith("---"):
        return None, "File does not start with YAML frontmatter (---)"

    match = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not match:
        return None, "Frontmatter not properly closed (missing second ---)"

    try:
        frontmatter = yaml.safe_load(match.group(1))
        if not isinstance(frontmatter, dict):
            return None, "Frontmatter must be a YAML dictionary"
        return frontmatter, None
    except yaml.YAMLError as e:
        return None, f"Invalid YAML: {e}"


def validate_field_rules(field: str, value, rules: dict, result: ValidationResult):
    """Validate a field against its rules."""
    if field not in rules:
        return

    field_rules = rules[field]

    # Type check
    if "type" in field_rules:
        expected = field_rules["type"]
        if expected == "bool" and not isinstance(value, bool):
            result.errors.append(f"'{field}' must be a boolean, got {type(value).__name__}")
            return

    # String validations
    if isinstance(value, str):
        # Max length
        if "max_length" in field_rules and len(value) > field_rules["max_length"]:
            result.errors.append(
                f"'{field}' exceeds max length ({len(value)} > {field_rules['max_length']})"
            )

        # Pattern
        if "pattern" in field_rules and not re.match(field_rules["pattern"], value):
            result.errors.append(
                f"'{field}' has invalid format (must be hyphen-case alphanumeric)"
            )

        # No angle brackets
        if field_rules.get("no_angle_brackets") and ("<" in value or ">" in value):
            result.errors.append(f"'{field}' cannot contain angle brackets (< or >)")

        # Enum
        if "enum" in field_rules and value not in field_rules["enum"]:
            result.errors.append(
                f"'{field}' must be one of: {', '.join(field_rules['enum'])}"
            )


def validate_frontmatter(
    path: Path,
    frontmatter: dict,
    component_type: str
) -> ValidationResult:
    """Validate frontmatter against schema."""
    result = ValidationResult(str(path), component_type)
    schema = SCHEMAS[component_type]

    fields = set(frontmatter.keys())
    allowed = schema["required"] | schema["optional"]

    # Check required fields
    for field in schema["required"]:
        if field not in frontmatter:
            result.errors.append(f"Missing required field: '{field}'")
        elif not frontmatter[field]:
            result.errors.append(f"Required field '{field}' is empty")

    # Check for unknown fields
    unknown = fields - allowed
    if unknown:
        result.warnings.append(f"Unknown field(s): {', '.join(sorted(unknown))}")

    # Validate field rules
    for field, value in frontmatter.items():
        if field in allowed:
            validate_field_rules(field, value, schema.get("rules", {}), result)

    # Component-specific warnings
    if component_type == "agent":
        desc = frontmatter.get("description", "")
        if isinstance(desc, str) and "<example>" not in desc:
            result.warnings.append("Description missing <example> blocks (recommended for auto-triggering)")

    if component_type == "skill":
        desc = frontmatter.get("description", "")
        if isinstance(desc, str) and len(desc) < 20:
            result.warnings.append("Description too short (< 20 chars)")

    return result


def validate_file(path: Path, force_type: Optional[str] = None) -> Optional[ValidationResult]:
    """Validate a single markdown file."""
    if not path.is_file() or path.suffix != ".md":
        return None

    try:
        content = path.read_text()
    except Exception as e:
        result = ValidationResult(str(path), "unknown")
        result.errors.append(f"Cannot read file: {e}")
        return result

    frontmatter, error = extract_frontmatter(content)
    if error:
        result = ValidationResult(str(path), "unknown")
        result.errors.append(error)
        return result

    component_type = force_type or detect_component_type(path, frontmatter)
    return validate_frontmatter(path, frontmatter, component_type)


def find_files(path: Path) -> list[Path]:
    """Find all markdown files to validate."""
    if path.is_file():
        return [path]

    files = []

    # Skills: look for SKILL.md
    for skill_md in path.rglob("SKILL.md"):
        files.append(skill_md)

    # Agents: *.md in agents/
    for agents_dir in path.rglob("agents"):
        if agents_dir.is_dir():
            files.extend(agents_dir.glob("*.md"))
            files.extend(agents_dir.rglob("*.md"))

    # Commands: *.md in commands/
    for commands_dir in path.rglob("commands"):
        if commands_dir.is_dir():
            files.extend(commands_dir.glob("*.md"))
            files.extend(commands_dir.rglob("*.md"))

    # Deduplicate
    return list(set(files))


def print_human_output(results: list[ValidationResult], quiet: bool = False):
    """Print human-readable output."""
    if not quiet:
        print(f"\n\033[1m\033[94m🔍 Validating {len(results)} file(s)...\033[0m\n")

    for r in results:
        if quiet and r.valid and not r.warnings:
            continue

        # File header
        type_color = {"skill": "35", "agent": "36", "command": "33"}.get(r.type, "0")
        print(f"\033[1m{r.path}\033[0m \033[{type_color}m[{r.type.capitalize()}]\033[0m")

        if r.valid and not r.warnings:
            print(f"  \033[32m✅ Valid\033[0m")
        elif r.valid:
            print(f"  \033[32m✅ Valid\033[0m")
            for w in r.warnings:
                print(f"  \033[33m⚠️  {w}\033[0m")
        else:
            for e in r.errors:
                print(f"  \033[31m❌ {e}\033[0m")
            for w in r.warnings:
                print(f"  \033[33m⚠️  {w}\033[0m")
        print()

    # Summary
    total = len(results)
    errors = sum(1 for r in results if not r.valid)
    warnings = sum(len(r.warnings) for r in results)

    print("\033[1m" + "━" * 50 + "\033[0m")
    status = "\033[32m✅" if errors == 0 else "\033[31m❌"
    print(f"{status} Summary: {total} files, {errors} error(s), {warnings} warning(s)\033[0m")


def print_json_output(results: list[ValidationResult]):
    """Print JSON output."""
    output = {
        "files": [r.to_dict() for r in results],
        "summary": {
            "total": len(results),
            "errors": sum(1 for r in results if not r.valid),
            "warnings": sum(len(r.warnings) for r in results),
        },
    }
    print(json.dumps(output, indent=2))


def main():
    parser = argparse.ArgumentParser(
        description="Validate YAML frontmatter in Claude Code components",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s ~/.claude/agents/              Validate all agents
  %(prog)s ~/.claude/                     Validate all components
  %(prog)s --json --strict .claude/       CI mode with JSON output
  %(prog)s --type agent custom.md         Force type detection
        """,
    )
    parser.add_argument("paths", nargs="+", type=Path, help="Files or directories to validate")
    parser.add_argument("--json", action="store_true", help="Output JSON instead of human-readable")
    parser.add_argument("--strict", action="store_true", help="Treat warnings as errors")
    parser.add_argument("--type", choices=["skill", "agent", "command"], help="Force component type")
    parser.add_argument("--quiet", "-q", action="store_true", help="Only show errors/warnings")

    args = parser.parse_args()

    # Collect all files
    all_files = []
    for p in args.paths:
        if not p.exists():
            print(f"Error: Path not found: {p}", file=sys.stderr)
            sys.exit(1)
        all_files.extend(find_files(p))

    if not all_files:
        if args.json:
            print_json_output([])
        else:
            print("No markdown files found to validate.")
        sys.exit(0)

    # Validate
    results = []
    for f in sorted(all_files):
        result = validate_file(f, args.type)
        if result:
            results.append(result)

    # Output
    if args.json:
        print_json_output(results)
    else:
        print_human_output(results, args.quiet)

    # Exit code
    has_errors = any(not r.valid for r in results)
    has_warnings = any(r.warnings for r in results)

    if has_errors:
        sys.exit(1)
    if args.strict and has_warnings:
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
