/**
 * start_stack: when an Oro Mate data tool cannot reach a service, the agent asks the user in the
 * pi TUI whether to start the project's Docker stack. On yes it runs `make up` (or `make start`)
 * when the project's Makefile defines that target, else `docker compose up -d`, and waits until no
 * container is still starting.
 *
 * The project is the working directory pi runs in; CRAWL_PROJECT overrides it for a session
 * started elsewhere. Runs with no UI (`pi -p`, and any background child) only report the stack
 * down: herdr's pi integration listens for `herdr:blocked`, so emitting it around the dialog makes
 * the pane read as blocked and an orchestrator waiting on the agent notices the question.
 */
import { existsSync } from "node:fs";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const MAKE_TARGETS = ["up", "start"];
const ANSWER_TIMEOUT_MS = 5 * 60_000;
const START_TIMEOUT_MS = 10 * 60_000;
const READY_TIMEOUT_MS = 3 * 60_000;

const text = (t: string) => ({ content: [{ type: "text" as const, text: t }], details: {} });
const tail = (s: string, lines = 20) => s.trim().split("\n").slice(-lines).join("\n");
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export default function (pi: ExtensionAPI) {
	// Parallel tool calls share one dialog and one start.
	let pending: Promise<string> | undefined;

	// Real targets from make's rule database. `make -q <target>` cannot tell a missing target from
	// an out-of-date one when the Makefile has a catch-all rule.
	async function makeTarget(root: string): Promise<string | undefined> {
		if (!["GNUmakefile", "makefile", "Makefile"].some((f) => existsSync(join(root, f)))) return undefined;
		const db = await pi.exec("make", ["-pRrq", ":"], { cwd: root, timeout: 15_000 });
		const targets = new Set<string>();
		let notATarget = false;
		for (const line of db.stdout.split("\n")) {
			if (line.startsWith("# Not a target")) {
				notATarget = true;
				continue;
			}
			const m = /^([A-Za-z0-9][A-Za-z0-9_.-]*):/.exec(line);
			if (m && !notATarget) targets.add(m[1]);
			notATarget = false;
		}
		return MAKE_TARGETS.find((t) => targets.has(t));
	}

	// `docker compose ps --format json` prints an array on older releases and one object per line on
	// newer ones.
	function containers(out: string): Array<{ Service?: string; State?: string; Health?: string }> {
		const s = out.trim();
		if (!s) return [];
		if (s.startsWith("[")) return JSON.parse(s);
		return s.split("\n").map((l) => JSON.parse(l));
	}

	async function waitReady(root: string, signal?: AbortSignal): Promise<string> {
		const deadline = Date.now() + READY_TIMEOUT_MS;
		for (;;) {
			const ps = await pi.exec("docker", ["compose", "ps", "--format", "json"], { cwd: root, signal, timeout: 30_000 });
			const all = containers(ps.stdout);
			const starting = all.filter((c) => c.Health === "starting" || c.State === "restarting");
			if (all.length > 0 && starting.length === 0) {
				const unhealthy = all.filter((c) => c.Health === "unhealthy").map((c) => c.Service);
				return `${all.length} containers up${unhealthy.length ? `, unhealthy: ${unhealthy.join(", ")}` : ""}.`;
			}
			if (Date.now() > deadline) {
				return `Still starting after ${READY_TIMEOUT_MS / 1000}s: ${starting.map((c) => c.Service).join(", ") || "no containers"}.`;
			}
			await sleep(3000);
		}
	}

	async function askAndStart(reason: string, signal: AbortSignal | undefined, ctx: any, onUpdate: any): Promise<string> {
		const root = process.env.CRAWL_PROJECT ?? process.cwd();

		const target = await makeTarget(root);
		const [cmd, args] = target ? ["make", [target]] : ["docker", ["compose", "up", "-d"]];
		const shown = [cmd, ...args].join(" ");

		pi.events.emit("herdr:blocked", { active: true, label: "start stack?" });
		let ok: boolean;
		try {
			ok = await ctx.ui.confirm("Start the project stack?", `${reason}\n\nRuns \`${shown}\` in ${root}`, {
				timeout: ANSWER_TIMEOUT_MS,
			});
		} finally {
			pi.events.emit("herdr:blocked", { active: false });
		}
		if (!ok) {
			return "The user declined or did not answer. Do not call start_stack again; answer from code and config and say which data you could not check.";
		}

		onUpdate?.(text(`Running ${shown} in ${root} ...`));
		const run = await pi.exec(cmd, args, { cwd: root, signal, timeout: START_TIMEOUT_MS });
		if (run.code !== 0) {
			throw new Error(`${shown} exited with ${run.code}:\n${tail(`${run.stdout}\n${run.stderr}`)}`);
		}
		onUpdate?.(text("Waiting for containers to become ready ..."));
		return `Started the stack with \`${shown}\`. ${await waitReady(root, signal)} Retry the tool that failed.`;
	}

	pi.registerTool({
		name: "start_stack",
		label: "Start stack",
		description:
			"Ask the user whether to start the project's Docker stack and start it on yes. Only for when an Oro Mate data tool failed because the database, broker or search engine was unreachable.",
		promptSnippet: "Ask the user to start the project's Docker stack when a Mate data tool finds a service down",
		promptGuidelines: [
			"Call start_stack at most once per question, only after an Oro Mate tool failed because a service was unreachable, then retry that tool.",
		],
		parameters: Type.Object({
			reason: Type.String({ description: "The tool that failed and its error, shown to the user in the dialog" }),
		}),
		async execute(_toolCallId, params, signal, onUpdate, ctx) {
			if (!ctx.hasUI) {
				return text(
					"This run has no UI, so the user cannot be asked. Do not retry the failed tool; report that the stack is down and answer from code and config.",
				);
			}
			pending ??= askAndStart(params.reason, signal, ctx, onUpdate).finally(() => {
				pending = undefined;
			});
			return text(await pending);
		},
	});
}
