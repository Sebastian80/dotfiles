---
name: oro-xdebug
description: Use when debugging Oro Commerce PHP code with Xdebug in a Docker environment — working out which service needs Xdebug (php-fpm for web requests, toolbox for CLI and tests, message-queue for consumers), enabling it via the project's make targets, setting the XDEBUG_SESSION cookie via agent-browser, and driving the session through the PhpStorm debugger MCP. Reach for this on any Oro or PROJX project before setting a breakpoint, because Xdebug is off by default, the enable command differs between projects, and enabling the wrong service produces a session that starts and never pauses.
---

# Xdebug in Dockerized Oro projects

Xdebug is never on by default here, and how you enable it differs between stacks.
Getting it wrong produces the failure the `jetbrains-debugger` skill warns about:
the run configuration looks fine, `start_debug_session` reports `started`, and no
breakpoint is ever hit.

## First: which family is this project?

```bash
ls make/xdebug.mk 2>/dev/null && echo "per-service (PROJX)" || echo "global (Oro reference)"
```

### Per-service — `make/xdebug.mk` present (shop, shop-61.docker.local)

State lives in `php.env` as `<SERVICE>_XDEBUG_ENABLED`. Services are independent,
and **you must enable the one that will actually run your code**:

| Target | Service | Debugs |
|---|---|---|
| `make xdebug-phpfpm-on` | phpfpm | web / storefront / admin requests |
| `make xdebug-tb-on` | toolbox | CLI: `bin/console`, PHPUnit, Behat |
| `make xdebug-mq-on` | message-queue | consumers, async jobs |
| `make xdebug-off` | all | turn everything off |
| `make xdebug-status` | — | what is configured, and whether each container is up |

Three traps this family has that the global one does not:

- **Enabling the wrong service is the commonest failure.** Debugging a Behat or
  PHPUnit run with only `phpfpm` on gives a session that never pauses — tests and
  console commands run in *toolbox*.
- **`xdebug-tb-on` takes effect on the next toolbox start**, not immediately;
  that target deliberately does not restart anything. A toolbox container already
  running keeps the old setting.
- **More than one message-queue replica means most jobs miss the breakpoint.**
  Xdebug connects to one instance at a time, so with N replicas roughly 1 in N
  pauses. The target prints a warning. Fix with `replicas: 1` under
  `message-queue.deploy` in `docker-compose.override.yml`.

### Global — no `make/xdebug.mk` (oro-6.1-dev, oro-5.1-dev)

```bash
make xdebug-enable      # uncomments COMPOSE_FILE_XDEBUG= in .env
make xdebug-disable
```

That pulls in `docker-compose.xdebug.yml` (and `docker-compose.xdebug-toolbox.yml`
where present), so the containers have to be recreated for it to take effect.

## Verify, don't assume

`make xdebug-status` on the per-service family; otherwise ask the container
directly:

```bash
docker compose exec phpfpm php -m | grep -i xdebug
docker compose exec toolbox php -m | grep -i xdebug
```

This matters for the reason the `jetbrains-debugger` preflight section gives:
PhpStorm caches its view of a remote interpreter and will keep reporting Xdebug as
loaded after you have switched it off. The container is ground truth.

## Debugging a web request

1. Enable the right service (`make xdebug-phpfpm-on`).
2. Set the `XDEBUG_SESSION` cookie in the browser:
   ```bash
   agent-browser eval "document.cookie = 'XDEBUG_SESSION=PHPSTORM; path=/'"
   ```
3. Set a breakpoint through the PhpStorm MCP, with the project root as
   `project_path`:
   ```
   mcp__phpstorm-debugger__set_breakpoint
     file_path: <absolute path to file>.php
     line: <line>
     project_path: <project root>
   ```
4. Trigger the request via agent-browser, then read the state:
   ```
   mcp__phpstorm-debugger__get_debug_session_status
     project_path: <project root>
     include_variables: true
   ```
5. For stepping, variable inspection and session control, follow the
   `jetbrains-debugger` skill — including its rules on pauses that belong to
   someone else's breakpoint, and on sessions that report `started` without
   ever running.
6. Remove the breakpoints you set when finished.

## Debugging CLI, tests and consumers

Same mechanics, different service, no cookie: the toolbox and message-queue
containers carry their own Xdebug config and the trigger comes from the
environment rather than the browser. Enable `xdebug-tb-on` (then restart toolbox)
or `xdebug-mq-on`, and run the command as usual.

Turn Xdebug off again when you are done. It is a large cost on every request, and
on message-queue it noticeably slows consumers.
