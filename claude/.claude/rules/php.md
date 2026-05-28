---
alwaysApply: false
paths: **/*.php, composer.json, composer.lock
---

# PHP

- Use the `php-modernization` skill for PHP 8.1+ work (strict types, PHPStan/Rector/PHP-CS-Fixer, enums/DTOs/readonly, PHP 8.4 property hooks).
- Use the `security-audit` skill for PHP security reviews (OWASP Top 10, CWE Top 25).
- For projects running in Docker, run `composer` inside the container — not on the host (see `rules/toolchain.md`).
