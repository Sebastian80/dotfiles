# Oro Commerce / PROJX — Dockerized Xdebug

Stack-specific detail for the preflight and container guidance in SKILL.md. Read
this when the project is Oro Commerce or an PROJX customer stack. Xdebug is never
on by default here, and the way you enable it differs *between* these projects —
enabling the wrong thing produces a session that starts and never pauses.

## Contents

- [Which family is this project](#which-family-is-this-project)
- [Per-service family (PROJX)](#per-service-family-shop)
- [Global family (Oro reference stacks)](#global-family-oro-reference-stacks)
- [Verifying](#verifying)
- [Debugging a web request](#debugging-a-web-request)
- [Debugging CLI, tests and consumers](#debugging-cli-tests-and-consumers)

## Which family is this project

```bash
ls make/xdebug.mk 2>/dev/null && echo "per-service (PROJX)" || echo "global (Oro reference)"
```

## Per-service family (PROJX)

`shop`, `shop-61.docker.local`. State lives in `php.env` as
`<SERVICE>_XDEBUG_ENABLED`. Services are independent, and **you must enable the one
that will actually run your code**:

| Target | Service | Debugs |
|---|---|---|
| `make xdebug-phpfpm-on` | phpfpm | web / storefront / admin requests |
| `make xdebug-tb-on` | toolbox | CLI: `bin/console`, PHPUnit, Behat |
| `make xdebug-mq-on` | message-queue | consumers, async jobs |
| `make xdebug-off` | all | turn everything off |
| `make xdebug-status` | — | configured state, and whether each container is up |

Three traps specific to this family:

- **Enabling the wrong service is the commonest failure.** Debugging a Behat or
  PHPUnit run with only `phpfpm` on gives a session that never pauses — tests and
  console commands run in *toolbox*.
- **`xdebug-tb-on` takes effect on the next toolbox start.** That target
  deliberately does not restart anything, so a toolbox container already running
  keeps the old setting.
- **More than one message-queue replica means most jobs miss the breakpoint.**
  Xdebug connects to one instance at a time, so with N replicas roughly 1 in N
  jobs pauses — which reads exactly like a flaky breakpoint. The target prints a
  warning. Fix with `replicas: 1` under `message-queue.deploy` in
  `docker-compose.override.yml`.

## Global family (Oro reference stacks)

`oro-6.1-dev`, `oro-5.1-dev`. One switch for everything:

```bash
make xdebug-enable      # uncomments COMPOSE_FILE_XDEBUG= in .env
make xdebug-disable
```

That pulls in `docker-compose.xdebug.yml` (and `docker-compose.xdebug-toolbox.yml`
where present), so containers have to be recreated for it to take effect.

## Verifying

`make xdebug-status` on the per-service family; otherwise ask the container:

```bash
docker compose exec phpfpm php -m | grep -i xdebug
docker compose exec toolbox php -m | grep -i xdebug
```

This is the container-is-ground-truth rule from SKILL.md's preflight section, in
its Oro form: the IDE will keep reporting Xdebug as loaded after you have switched
it off.

## Debugging a web request

Xdebug in the phpfpm container is triggered by a cookie rather than by the run
configuration, so the flow differs from an IDE-launched session:

1. `make xdebug-phpfpm-on`
2. Set the session cookie in the browser:
   ```bash
   agent-browser eval "document.cookie = 'XDEBUG_SESSION=PHPSTORM; path=/'"
   ```
3. Set the breakpoint through the MCP with the project root as `project_path`.
4. Trigger the request via agent-browser, then read state with
   `get_debug_session_status` (`include_variables: true`).

Stepping, frame selection and session control are the same as any other session —
see SKILL.md, including the rules on borrowed pauses and on sessions that report
`started` without running.

## Debugging CLI, tests and consumers

Same mechanics, different service, no cookie: the toolbox and message-queue
containers carry their own Xdebug config and the trigger comes from the
environment. Enable `xdebug-tb-on` (then restart toolbox) or `xdebug-mq-on`, and
run the command as usual.

Turn Xdebug off when finished — it is a large cost on every request, and on
message-queue it noticeably slows consumers.
