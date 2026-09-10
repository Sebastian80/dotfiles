/**
 * Protected Paths
 *
 * The sandbox extension overrides `bash` only. The `read`, `write` and `edit`
 * tools bypass it entirely, so the sandbox's denyRead/denyWrite lists do not
 * apply to them. This guards those three tools directly.
 *
 * Verified: without this, `read` on a path inside the sandbox denyRead list
 * returns the file contents while the same path via bash is refused.
 *
 * Template env files stay readable and writable; only real env files are blocked.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

const TEMPLATE_ENV = /(\.env)([.-](dist|example|sample|template)|-app.*)$/i;

/** Credential material: refused for read, write and edit alike. */
const SECRET_PATHS = [
	"/.ssh/",
	"/.gnupg/",
	"/.aws/",
	"/.codex/",
	"/.pi/agent/auth.json",
	"/.claude/.credentials",
	"id_rsa",
	"id_ed25519",
	".env",
];

/** Additionally refused for write and edit, but readable. */
const WRITE_ONLY_PROTECTED = [".git/", "node_modules/", "/.pi/", "/.claude/"];

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => {
		const tool = event.toolName;
		if (tool !== "read" && tool !== "write" && tool !== "edit") return undefined;

		const path = String(event.input.path ?? "");
		if (!path) return undefined;
		if (TEMPLATE_ENV.test(path)) return undefined;

		const list = tool === "read" ? SECRET_PATHS : [...SECRET_PATHS, ...WRITE_ONLY_PROTECTED];
		const hit = list.find((p) => path.includes(p));
		if (!hit) return undefined;

		if (ctx.hasUI) {
			ctx.ui.notify(`Blocked ${tool} on protected path: ${path}`, "warning");
		}
		return { block: true, reason: `Path "${path}" is protected (matched "${hit}")` };
	});
}
