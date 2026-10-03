// node --test symfony-lookup-core.test.ts — the read-only gate for PhpStorm's built-in MCP server.
import { test } from "node:test";
import assert from "node:assert/strict";
import { SUBTOOLS, buildCommand, createRepeatGuard } from "./symfony-lookup-core.ts";

test("allowlist is exactly the read-only Symfony lookups", () => {
	assert.deepEqual(Object.keys(SUBTOOLS).sort(), [
		"get_composer_dependencies",
		"list_doctrine_entity_fields",
		"list_symfony_form_options",
		"list_twig_template_usages",
		"list_twig_template_variables",
		"locate_symfony_service",
		"search_symbol",
	]);
});

test("allowed sub-tool with its one argument: quoted command", () => {
	assert.equal(
		buildCommand("locate_symfony_service", "App\\Service\\Foo"),
		'locate_symfony_service --identifier "App\\Service\\Foo"',
	);
	assert.equal(buildCommand("search_symbol", "Kernel"), 'search_symbol --q "Kernel"');
});

test("argument-less sub-tool: bare name, a value is refused", () => {
	assert.equal(buildCommand("get_composer_dependencies", ""), "get_composer_dependencies");
	assert.throws(() => buildCommand("get_composer_dependencies", "x"), /takes no value/);
});

test("anything off the list is refused", () => {
	for (const t of ["execute_terminal_command", "search_regex", "read_file", "list_symfony_forms", "analyze_calls", ""]) {
		assert.throws(() => buildCommand(t, "x"), /not on the read-only list/, t);
	}
});

test("a value that could break out of its quotes is refused", () => {
	for (const v of ['a"b', "a\nb", "a\rb", "a\\"]) {
		assert.throws(() => buildCommand("search_symbol", v), /not allowed/, JSON.stringify(v));
	}
});

test("a sub-tool that needs a value refuses an empty one", () => {
	assert.throws(() => buildCommand("locate_symfony_service", ""), /needs a value/);
});

test("repeat guard: the third identical command is blocked, others pass", () => {
	const guard = createRepeatGuard(2);
	assert.equal(guard("search_symbol --q \"A\""), true);
	assert.equal(guard("search_symbol --q \"A\""), true);
	assert.equal(guard("search_symbol --q \"B\""), true);
	assert.equal(guard("search_symbol --q \"A\""), false);
});
