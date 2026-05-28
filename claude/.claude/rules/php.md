---
alwaysApply: false
paths: **/*.php, composer.json, composer.lock, ext_emconf.php
---

# PHP

- Use the `php-modernization` skill for PHP 8.1+ work (strict types, PHPStan/Rector/PHP-CS-Fixer, enums/DTOs/readonly, PHP 8.4 property hooks).
- Use the `security-audit` skill for PHP/TYPO3 security reviews (OWASP, TYPO3 v14.3 LTS `#109585`, HashService removal, Authorize/RateLimit).
- Use the `enterprise-readiness` skill for TYPO3 CI matrix decisions (PHP 8.2–8.5 × TYPO3 12.4/13.4/14.3 LTS).
- For projects running in Docker, run `composer` inside the container — not on the host (see `rules/toolchain.md`).
- TYPO3 extension detection: presence of `ext_emconf.php` marks an extension root.
