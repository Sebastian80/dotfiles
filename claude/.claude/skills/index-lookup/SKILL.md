---
name: index-lookup
description: Use when you need any PHP codebase fact from a project open in PhpStorm - who calls, uses, implements or extends X; where a class, file, symbol or method is defined; which service id, factory or tags wire a class; Doctrine entity fields; Twig template usages; a project-wide search for a service id, route or YAML key. MANDATORY instead of Bash grep, rg or reading files yourself. Forks the read-only index worker. Not for edits, refactoring, tests or runtime container data.
context: fork
agent: oro-index-lookup
---

Project root: !`pwd`
(If the question below names a different absolute project root, use that one instead.)

QUESTION: $ARGUMENTS
