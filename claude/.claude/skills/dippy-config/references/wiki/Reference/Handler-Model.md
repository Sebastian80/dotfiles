## What Handlers Do

Handlers provide tool-specific classification logic. While Dippy's built-in allowlist covers simple read-only commands (`cat`, `ls`, `grep`), many tools need subcommand-aware analysis:

- `git status` is safe, `git push --force` is not
- `docker ps` is safe, `docker run` needs review
- `kubectl get pods` is safe, `kubectl delete` is not

Handlers encode this knowledge. Each handler claims one or more command names and classifies invocations as safe or requiring approval.

## The Interface

A handler is a Python module in `src/dippy/cli/` that exports:

```python
COMMANDS: list[str]  # Command names this handler claims

def classify(ctx: HandlerContext) -> Classification
```

The `HandlerContext` and `Classification` types:

```python
@dataclass(frozen=True)
class HandlerContext:
    tokens: list[str]

@dataclass(frozen=True)
class Classification:
    action: Literal["allow", "ask", "delegate"]
    inner_command: str | None = None       # Required when action="delegate"
    description: str | None = None         # Override default description
    redirect_targets: tuple[str, ...] = () # File paths to check
    remote: bool = False                   # Inner command runs in remote context
```

## Classification Actions

| Action     | Meaning                       | When to Use                                 |
| ---------- | ----------------------------- | ------------------------------------------- |
| `allow`    | Command is safe               | Read-only operations, inspections           |
| `ask`      | Needs user approval           | Mutations, deletions, network writes        |
| `delegate` | Analyze inner command instead | Wrapper commands like `uv run`, `script -c` |

**Delegation** lets wrappers defer to the wrapped command:

```python
# uv.py
def classify(ctx: HandlerContext) -> Classification:
    tokens = ctx.tokens
    if tokens[1] == "run":
        inner = " ".join(tokens[3:])  # e.g., "pytest tests/"
        return Classification("delegate", inner_command=inner)
    # ...
```

The analyzer recursively classifies the inner command with full config/redirect checking.

## Handler Discovery

Handlers are auto-discovered at import time:

```python
for file in cli_dir.glob("*.py"):
    module = import(file)
    for cmd in module.COMMANDS:
        handlers[cmd] = module
```

No registration step required — drop a file in `src/dippy/cli/`, export `COMMANDS` and `classify`, and it's active.

## Priority in the Analysis Pipeline

Handlers are step 5 of 6 in command analysis:

1. **Config rules** — User overrides (highest priority)
2. **Wrapper commands** — `time`, `timeout` unwrapped
3. **Built-in allowlist** — Known safe commands
4. **Version/help flags** — `--help`, `--version` auto-approved
5. **CLI handlers** — Tool-specific logic ← *handlers run here*
6. **Default: ask** — Unknown commands prompt

Config rules take precedence. If a user writes `deny git push`, the git handler never sees `git push` commands.

## Redirect Targets

Handlers can declare file paths that should be checked against redirect rules:

```python
def classify(ctx: HandlerContext) -> Classification:
    tokens = ctx.tokens
    if tokens[1] == "export" and "-o" in tokens:
        output_file = tokens[tokens.index("-o") + 1]
        return Classification(
            "allow",
            redirect_targets=(output_file,)
        )
```

The analyzer checks these paths against `allow-redirect` / `deny-redirect` config rules, same as shell redirects.

## Writing a Handler

Minimal example (`src/dippy/cli/mytool.py`):

```python
from dippy.cli import Classification, HandlerContext

COMMANDS = ["mytool"]

SAFE_ACTIONS = frozenset({"list", "show", "status", "info"})

def classify(ctx: HandlerContext) -> Classification:
    tokens = ctx.tokens
    if len(tokens) < 2:
        return Classification("ask", description="mytool")

    action = tokens[1]

    if action in SAFE_ACTIONS:
        return Classification("allow", description=f"mytool {action}")

    return Classification("ask", description=f"mytool {action}")
```

## Common Patterns

**Flag skipping** — Find the action past global flags:

```python
def _find_action(tokens: list[str]) -> str | None:
    i = 1
    while i < len(tokens):
        if tokens[i] in FLAGS_WITH_ARG:
            i += 2
        elif tokens[i].startswith("-"):
            i += 1
        else:
            return tokens[i]
    return None
```

**Subcommand handling** — Multi-level commands like `docker image ls`:

```python
SAFE_SUBCOMMANDS = {
    "image": {"ls", "inspect", "history"},
    "container": {"ls", "inspect", "logs"},
}

def classify(ctx: HandlerContext) -> Classification:
    tokens = ctx.tokens
    action = tokens[1]
    if action in SAFE_SUBCOMMANDS and len(tokens) > 2:
        subaction = tokens[2]
        if subaction in SAFE_SUBCOMMANDS[action]:
            return Classification("allow", description=f"docker {action} {subaction}")
    return Classification("ask")
```

**Delegation** — Wrapper commands:

```python
def classify(ctx: HandlerContext) -> Classification:
    tokens = ctx.tokens
    # Skip flags to find inner command
    inner_tokens = tokens[2:]
    if not inner_tokens:
        return Classification("ask")
    return Classification("delegate", inner_command=" ".join(inner_tokens))
```

## Handler Styles

These are informal patterns, not formal types. They describe common approaches handlers take to classify commands.

**Subcommand** — Multi-level CLIs where safety depends on which subcommand is invoked. The handler checks the subcommand against safe/unsafe lists.

- `git`: `git status` safe, `git push` unsafe
- `docker`: `docker ps` safe, `docker run` unsafe
- `kubectl`: `kubectl get` safe, `kubectl delete` unsafe

**Flag-check** — Commands that are safe by default but have specific flags that enable writes or other side effects.

- `sed`: Safe for transforms, `-i` modifies files in place
- `curl`: Safe for GET requests, `-d`/`-X POST` sends data
- `tar`: `-t` lists contents, `-x` extracts files

**Delegate** — Wrapper commands that execute other commands. The handler extracts the inner command and delegates classification to the analyzer.

- `xargs`: `xargs rm` delegates to `rm` classification
- `env`: `env FOO=bar python script.py` delegates to `python`
- `docker exec`: `docker exec container ls` delegates to `ls`

**Arg-count** — Simple commands where the number of arguments determines safety. Typically viewing vs. modifying.

- `ifconfig`: `ifconfig eth0` views, `ifconfig eth0 192.168.1.1` modifies
- `sysctl`: `sysctl kern.maxfiles` reads, `sysctl kern.maxfiles=1024` writes

**Ask** — Commands with no safe mode. Every invocation requires confirmation.

- `rm`: Always deletes
- `mktemp`: Always creates files
- `pbcopy`: Always modifies clipboard

Most handlers combine patterns. The `git` handler is primarily subcommand-based but uses flag-checking within subcommands (`git branch -d` is unsafe, `git branch --list` is safe).

## Existing Handlers

80+ handlers cover common tools:

| Category         | Handlers                                       |
| ---------------- | ---------------------------------------------- |
| Version control  | git                                            |
| Containers       | docker, kubectl, helm                          |
| Cloud            | aws, gcloud, azure, terraform, cdk, packer     |
| Package managers | pip, npm, cargo, brew, uv                      |
| Python tools     | python, pytest, ruff, black, isort, pre-commit |
| Text processing  | awk, sed, sort, xargs, yq                      |
| Network          | curl, wget                                     |
| System           | find, fd, tar, 7z, tee, env                    |

See `src/dippy/cli/` for implementations.
