/**
 * symfony_lookup — read-only Symfony facts from PhpStorm's built-in MCP server, for index-scout.
 *
 * Loaded only in index-scout's child (`subagentOnlyExtensions`), never as an ambient extension. It fails
 * closed: if this file does not load, the tool is missing and pi-subagents refuses the launch, so the
 * child can never end up with the server's raw execute_tool.
 *
 * Env: PHPSTORM_MCP_URL (default http://127.0.0.1:64442/stream).
 */

import { Type } from "@earendil-works/pi-ai";
import { defineTool, type ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { SUBTOOLS, buildCommand, createRepeatGuard } from "./symfony-lookup-core.ts";

const URL = process.env.PHPSTORM_MCP_URL ?? "http://127.0.0.1:64442/stream";
const MAX_CHARS = 20_000;
const HEADERS = { "Content-Type": "application/json", Accept: "application/json, text/event-stream" };

// The server answers either as JSON or as an SSE stream of `data:` lines.
async function rpc(body: object, sessionId: string | undefined, signal: AbortSignal) {
	const res = await fetch(URL, {
		method: "POST",
		headers: sessionId ? { ...HEADERS, "Mcp-Session-Id": sessionId } : HEADERS,
		body: JSON.stringify(body),
		signal,
	});
	if (!res.ok) throw new Error(`PhpStorm MCP server answered HTTP ${res.status} at ${URL}`);
	const text = await res.text();
	const json = text.trimStart().startsWith("{")
		? text
		: text.split("\n").filter((l) => l.startsWith("data: ")).map((l) => l.slice(6)).pop();
	return { session: res.headers.get("mcp-session-id") ?? sessionId, message: json ? JSON.parse(json) : undefined };
}

async function executeTool(command: string, projectPath: string, signal: AbortSignal): Promise<string> {
	const init = await rpc(
		{ jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: "2025-03-26", capabilities: {}, clientInfo: { name: "index-scout", version: "1" } } },
		undefined,
		signal,
	);
	await rpc({ jsonrpc: "2.0", method: "notifications/initialized" }, init.session, signal);
	const call = await rpc(
		{ jsonrpc: "2.0", id: 2, method: "tools/call", params: { name: "execute_tool", arguments: { command, projectPath } } },
		init.session,
		signal,
	);
	if (call.message?.error) throw new Error(call.message.error.message);
	return (call.message?.result?.content ?? []).map((c: { text?: string }) => c.text ?? "").join("\n");
}

const allowRepeat = createRepeatGuard(2);

const symfonyLookup = defineTool({
	name: "symfony_lookup",
	label: "Symfony lookup",
	description:
		"Read-only Symfony facts from PhpStorm's Symfony plugin. locate_symfony_service: services of a class FQCN or one service id, with arguments, tags, aliases. list_doctrine_entity_fields: fields and relations of an entity FQCN. list_symfony_form_options: options of a form type FQCN. list_twig_template_usages / list_twig_template_variables: a template like @Bundle/path.html.twig. get_composer_dependencies: installed packages (no value). search_symbol: a symbol name.",
	parameters: Type.Object({
		subtool: Type.Union(Object.keys(SUBTOOLS).map((s) => Type.Literal(s))),
		value: Type.String({ description: "The one argument the sub-tool takes; empty for get_composer_dependencies" }),
		project_path: Type.String({ description: "Absolute project root" }),
	}),

	async execute(_id, params, signal) {
		const command = buildCommand(params.subtool, params.value);
		if (!allowRepeat(command)) throw new Error(`blocked: '${command}' already ran twice; narrow the query or switch sub-tool`);
		const timeout = AbortSignal.timeout(60_000);
		const text = await executeTool(command, params.project_path, signal ? AbortSignal.any([signal, timeout]) : timeout);
		const cut = text.length > MAX_CHARS;
		return {
			content: [{ type: "text", text: cut ? `${text.slice(0, MAX_CHARS)}\n[cut at ${MAX_CHARS} characters]` : text }],
			details: { command, truncated: cut },
		};
	},
});

export default function (pi: ExtensionAPI) {
	pi.registerTool(symfonyLookup);
}
