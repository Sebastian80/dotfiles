---
name: index-lookup
description: MANDATORY for every PHP codebase fact in a project that is open in PhpStorm. You MUST invoke this skill instead of Bash grep, rg, find or reading files yourself whenever the question is about the code graph or framework wiring - who calls, uses, implements or extends X, where a class, file, symbol or method is defined, which methods a class has, which factory, provider or service id wires a class and with which tags, which fields or relations a Doctrine entity has, where a Twig template is used, or a project-wide text search for a service id, route name or YAML key. It forks the read-only oro-index-lookup subagent, the only session with the index server, so the answer arrives in your context without the tool output. Not for editing, renaming, reformatting, running tests, IDE lifecycle or runtime container state; questions that need Oro Mate runtime data (container state, extend fields, merged datagrids) go to the oro-index-crawler agent.
context: fork
agent: oro-index-lookup
---

Project root: !`pwd`
(If the question below names a different absolute project root, use that one instead.)

QUESTION: $ARGUMENTS

Answer rules for this task:
- If the question needs a write, a refactoring, an IDE lifecycle action or runtime data, answer
  `OUT OF SCOPE: <what it needs>` on one line and stop; do not attempt a partial answer.
- Fully qualified class names only where a tool result gave the namespace; otherwise the short name.
- Every bullet: FQCN, file path (project-relative), service id or "none", creator FQCN and file path.
- "none (text search)" when a text search under `vendor/` came back empty, never "does not exist".
- Mark anything not backed by a tool result "(inferred)".
- Last line: `TOOLS USED: <tool x count, ...>`.
