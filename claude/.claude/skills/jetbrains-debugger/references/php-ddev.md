# PHP / Xdebug / DDEV specifics

Stack-specific detail for the preflight and container guidance in SKILL.md. Read
this when the project is PHP and the interpreter is a DDEV or Docker Compose
container. For other stacks the *principles* in SKILL.md still apply — only the
commands below are PHP/DDEV-shaped.

## Contents

- [The preflight call](#the-preflight-call)
- [Verifying against the container](#verifying-against-the-container)
- [Where the interpreter selection actually lives](#where-the-interpreter-selection-actually-lives)
- [ddev xdebug on does not survive ddev restart](#ddev-xdebug-on-does-not-survive-ddev-restart)
- [Xdebug on makes shell PHP hang](#xdebug-on-makes-shell-php-hang)
- [Path mappings bind breakpoints](#path-mappings-bind-breakpoints)
- [Static analysis may use a different interpreter](#static-analysis-may-use-a-different-interpreter)

## The preflight call

```
mcp__phpstorm__execute_tool  command="get_php_project_config"  projectPath=<root>
```

Returns the selected interpreter (including `isRemote` and a `docker-compose://`
`homePath` when containerised), the PHP version, `loadedExtensions`, the ini files
in play, and a `debuggers` array. If `xdebug` is missing from `loadedExtensions`,
no breakpoint will ever be hit.

`can_debug: true` from `list_run_configurations` is not this. It reflects
`debugger_id="php.debugger.XDebug"` being *configured* on the interpreter, not
Xdebug being *installed* on the PHP that runs.

## Verifying against the container

The IDE caches remote `phpinfo` and does not revalidate when the container changes
underneath. Measured 2026-07-26: with Xdebug provably off — `ddev xdebug status`
disabled, `php -m` showing no xdebug, `20-xdebug.ini` absent from disk —
`get_php_project_config` still reported `xdebug` in `loadedExtensions`,
`20-xdebug.ini` among the ini files, and `debuggers: [xdebug 3.5.3]`.

Ground truth:

```bash
ddev xdebug status
ddev exec XDEBUG_MODE=off php -m | grep -i xdebug
```

Self-falsification test, no second tool needed: check whether the paths in
`additionalIniFiles` exist in the container. A cached answer keeps listing
`.../conf.d/20-xdebug.ini` after `ddev xdebug off` has deleted it. An IDE naming an
ini file that is not on disk is reporting a memory, and every other field in that
response is equally old.

`idea.log` is not a fallback — its `Xdebug not found among available debuggers`
line can be hours old and refer to a previous run.

## Where the interpreter selection actually lives

| What | Where |
|---|---|
| *Which* interpreter the project selected | `.idea/workspace.xml` → `<component name="PhpWorkspaceProjectConfiguration" interpreter_name="…">` |
| What that interpreter *is* (path, container, debugger id) | `.idea/php.xml` → `<interpreter name="…" home="…">` |

A checker looking for `interpreter_name` in `php.xml` finds nothing and reports "no
interpreter selected" for a project that debugs fine. One such script was written
and deleted on 2026-07-26 for exactly that. Prefer the preflight call over reading
either file.

## ddev xdebug on does not survive ddev restart

`ddev xdebug on` is a runtime toggle. `.ddev/config.yaml` ships
`xdebug_enabled: false`, so any restart silently turns Xdebug back off and sessions
start without ever pausing. If a setup that worked an hour ago stops pausing, check
`ddev xdebug status` before anything else.

Set `xdebug_enabled: true` in `config.yaml` to make it stick, at the cost of a
permanent performance hit on every request.

## Xdebug on makes shell PHP hang

With `xdebug.start_with_request=yes` (DDEV's default once Xdebug is enabled) *every*
CLI PHP process opens a DBGp session against the listening IDE. `ddev exec php -m`
then blocks until it times out and leaves a paused session named `stdin` holding its
process. Symptoms: shell one-liners taking >60 s, and `list_debug_sessions` filling
with entries nobody started.

One-off: `ddev exec XDEBUG_MODE=off php -m`.

Permanent — `.ddev/php/zzz-xdebug-trigger.ini`, named to sort after DDEV's own
`20-xdebug.ini`:

```ini
xdebug.start_with_request=trigger
```

Xdebug then connects only when `XDEBUG_TRIGGER`/`XDEBUG_SESSION` is present. IDE
debugging is unaffected — PhpStorm passes its own
`-dxdebug.start_with_request=yes` when launching a run configuration — and browser
debugging still works via the cookie. Verified: after the change `ddev exec php -v`
runs in 0.48 s and a breakpoint in the PHPUnit bootstrap still pauses.

## Path mappings bind breakpoints

Not `DOCKER_REMOTE_PROJECT_PATH`. A DDEV interpreter can record
`DOCKER_REMOTE_PROJECT_PATH="/opt/project"` while the active mapping is
`$PROJECT_DIR$ → /var/www/html`. The mapping wins and matches the real mount. If a
`verified: true` breakpoint never binds, check the mappings first.

## Static analysis may use a different interpreter

PHPStan and Psalm settings can point at a different PHP than the debugger. On this
machine they use the host `/home/linuxbrew/.linuxbrew/bin/php` (8.5, no Xdebug)
while the debugger and tests use the container's 8.3. Neither is wrong; just don't
infer one interpreter's extensions from the other's.
