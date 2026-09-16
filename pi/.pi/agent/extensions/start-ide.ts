/**
 * start_ide: an agent whose code tools come from the PhpStorm index is left with `read` alone when
 * the IDE is dead or does not have the project open, where its line numbers drift by a few in
 * either direction and the answer still reads as authoritative. This tool turns that into a
 * question instead of a guess: it asks whether to start PhpStorm and open the project, and on yes
 * runs the JetBrains launcher with the project path, which both starts a dead IDE and opens the
 * project in a running one.
 *
 * The project is the working directory pi runs in; CRAWL_PROJECT overrides it for a session started
 * elsewhere.
 *
 * Who gets asked follows who is watching. A launcher that sets PI_DECISION_FILE is saying it will
 * put the question to the user itself, so the tool writes the request there, returns it as a
 * NEEDS-DECISION marker and tells the agent to stop and make that its whole answer. A background
 * run without a UI does the same, file or not. Only a session someone is looking at, started
 * without that variable, asks in place: a dialog wrapped in `herdr:blocked`, so the pane reads as
 * blocked and an orchestrator waiting on the agent notices it.
 *
 * The file is the reliable half. A model told to repeat the marker verbatim paraphrases it anyway
 * (measured twice), which reads fine to a human and defeats every caller that greps the answer for
 * it. A parent that knows the marker starts the IDE and runs the agent again; one that does not
 * still sees why the answer is missing.
 */
import { existsSync, writeFileSync } from "node:fs";
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

const INDEX_URL = "http://127.0.0.1:29175/";
const PROBE_TIMEOUT_MS = 2_000;
const ANSWER_TIMEOUT_MS = 5 * 60_000;
const READY_TIMEOUT_MS = 3 * 60_000;

const TOOLBOX_LAUNCHER = join(homedir(), ".local/share/JetBrains/Toolbox/scripts/phpstorm");

const text = (t: string) => ({ content: [{ type: "text" as const, text: t }], details: {} });
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

const noGuessing =
	"Answer from what the other sources give you and say plainly that the index was unavailable. " +
	"Never report a line number you took from `read` as if the index had confirmed it.";

export default function (pi: ExtensionAPI) {
	// Parallel tool calls share one dialog and one launch.
	let pending: Promise<string> | undefined;

	// A run that hands the question up stops straight afterwards, and an agent that stops reads as
	// idle, which looks like an answer. Mark it blocked so a listener waiting on the pane wakes, and
	// release it as soon as the turn settles. Holding the state is not an option: to herdr, blocked
	// means the terminal is waiting for a keypress, so `herdr agent prompt` answers agent_blocked and
	// refuses to deliver. The parent could then never send the rerun the decision exists to enable,
	// and nothing else would clear the state either, because clearing it needs a turn that can no
	// longer start.
	let handedUp = false;
	const release = () => {
		if (!handedUp) return;
		handedUp = false;
		pi.events.emit("herdr:blocked", { active: false });
	};
	pi.on("agent_settled", release);
	pi.on("agent_start", release);

	// The endpoint antivirus accepts connections on dead local ports, so a reachable socket is not a
	// running IDE. Only a real HTTP response counts, whatever its status.
	async function indexAnswers(): Promise<boolean> {
		try {
			await fetch(INDEX_URL, { signal: AbortSignal.timeout(PROBE_TIMEOUT_MS) });
			return true;
		} catch {
			return false;
		}
	}

	// phpstorm-background (dotfiles bin) wraps the JetBrains launcher and hands keyboard focus back
	// while the IDE starts, so it wins over a plain phpstorm on PATH.
	function launcher(): string | undefined {
		for (const name of ["phpstorm-background", "phpstorm"]) {
			for (const dir of (process.env.PATH ?? "").split(":")) {
				if (dir && existsSync(join(dir, name))) return join(dir, name);
			}
		}
		return existsSync(TOOLBOX_LAUNCHER) ? TOOLBOX_LAUNCHER : undefined;
	}

	async function askAndStart(reason: string, ctx: any, onUpdate: any): Promise<string> {
		const root = process.env.CRAWL_PROJECT ?? process.cwd();
		const running = await indexAnswers();

		if (!process.env.DISPLAY && !process.env.WAYLAND_DISPLAY) {
			return `No graphical session (DISPLAY and WAYLAND_DISPLAY are both unset), so PhpStorm cannot be started from here. ${noGuessing}`;
		}
		const bin = launcher();
		if (!bin) {
			return `No PhpStorm launcher found on PATH or at ${TOOLBOX_LAUNCHER}. ${noGuessing}`;
		}

		const title = running ? "Open this project in PhpStorm?" : "Start PhpStorm?";
		const shown = `${bin} ${root}`;

		// A launcher that set PI_DECISION_FILE has said it will handle the question, so hand it up even
		// when this run could ask: the human is watching the parent, not this pane.
		const file = process.env.PI_DECISION_FILE;
		if (!ctx.hasUI || file) {
			const request = [
				`NEEDS-DECISION: start_ide ${root}`,
				`reason: ${reason}`,
				`state: ${running ? "PhpStorm is running but does not have this project open" : "PhpStorm is not running"}`,
				`fix: run \`${shown}\`, wait until ${INDEX_URL} answers and ide_index_status reports isIndexing false, then ask again`,
			].join("\n");
			if (file) {
				try {
					writeFileSync(file, `${request}\n`);
				} catch {
					// The marker below still carries the request; a caller that set the variable and finds
					// no file falls back to reading the answer.
				}
			}
			if (!handedUp) {
				handedUp = true;
				pi.events.emit("herdr:blocked", { active: true, label: "start PhpStorm?" });
			}
			return [
				request,
				"",
				"The question cannot be answered here: it belongs to whoever started this run. Stop now.",
				"The four lines above are your entire final answer: no findings, no partial answer, no",
				"other text. The parent decides whether to start the IDE and runs the agent again.",
			].join("\n");
		}

		pi.events.emit("herdr:blocked", { active: true, label: "start PhpStorm?" });
		let ok: boolean;
		try {
			ok = await ctx.ui.confirm(title, `${reason}\n\nRuns \`${shown}\``, { timeout: ANSWER_TIMEOUT_MS });
		} finally {
			pi.events.emit("herdr:blocked", { active: false });
		}
		if (!ok) {
			return `The user declined or did not answer. Do not call start_ide again. ${noGuessing}`;
		}

		onUpdate?.(text(`Running ${shown} ...`));
		// The launcher execs the IDE in the foreground and only returns when it quits, so it is
		// detached: this tool waits for the index to answer, not for the editor to close.
		spawn(bin, [root], { detached: true, stdio: "ignore" }).unref();

		onUpdate?.(text("Waiting for the index to answer ..."));
		const deadline = Date.now() + READY_TIMEOUT_MS;
		for (;;) {
			if (await indexAnswers()) {
				return (
					`PhpStorm answers on ${INDEX_URL}. Call ide_project_status with project_path ${root} and ` +
					"confirm it lists that root as open. Opening a monorepo takes a while, so if ide_index_status " +
					"reports isIndexing true or dumb mode, wait and check again before you trust any result."
				);
			}
			if (Date.now() > deadline) {
				return (
					`Started \`${shown}\` but ${INDEX_URL} did not answer within ${READY_TIMEOUT_MS / 1000}s. ` +
					`The IDE may still be loading. ${noGuessing}`
				);
			}
			await sleep(3000);
		}
	}

	pi.registerTool({
		name: "start_ide",
		label: "Start PhpStorm",
		description:
			"Ask the user whether to start PhpStorm and open this project, and do it on yes. Only for when an " +
			"ide_* tool failed because the index was unreachable, or ide_project_status does not list this " +
			"project root as open.",
		promptSnippet: "Ask the user to start PhpStorm when the index is unreachable or does not have this project open",
		promptGuidelines: [
			"Call start_ide at most once per question, only after an ide_* call failed because the index was unreachable or ide_project_status did not list this project root as open, then retry that call.",
			"Without the index, never present a line number read from a file as a looked-up fact.",
		],
		parameters: Type.Object({
			reason: Type.String({ description: "The tool that failed and its error, shown to the user in the dialog" }),
		}),
		async execute(_toolCallId, params, _signal, onUpdate, ctx) {
			pending ??= askAndStart(params.reason, ctx, onUpdate).finally(() => {
				pending = undefined;
			});
			return text(await pending);
		},
	});
}
