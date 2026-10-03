// The read-only gate for PhpStorm's built-in MCP server. That server exposes one tool, execute_tool,
// whose `command` string can name any IDE sub-tool, the terminal and file patches included. So the
// child never gets execute_tool: symfony_lookup builds the command itself, from this allowlist only.

/** Read-only sub-tools and the one flag each takes (null: takes no value). */
export const SUBTOOLS: Record<string, string | null> = {
	locate_symfony_service: "identifier",
	list_doctrine_entity_fields: "className",
	list_symfony_form_options: "formType",
	list_twig_template_usages: "template",
	list_twig_template_variables: "template",
	get_composer_dependencies: null,
	search_symbol: "q",
};

export function buildCommand(subtool: string, value: string): string {
	if (!Object.hasOwn(SUBTOOLS, subtool)) {
		throw new Error(`'${subtool}' is not on the read-only list: ${Object.keys(SUBTOOLS).join(", ")}`);
	}
	const flag = SUBTOOLS[subtool];
	if (flag === null) {
		if (value !== "") throw new Error(`${subtool} takes no value`);
		return subtool;
	}
	if (value === "") throw new Error(`${subtool} needs a value for --${flag}`);
	// The value goes between double quotes; a quote, a line break or a trailing backslash could end them.
	if (/["\r\n]/.test(value) || value.endsWith("\\")) {
		throw new Error(`characters not allowed in the value: quotes, line breaks, a trailing backslash`);
	}
	return `${subtool} --${flag} "${value}"`;
}

/** Allows each identical command `max` times per child; the next one is refused. */
export function createRepeatGuard(max: number): (command: string) => boolean {
	const seen = new Map<string, number>();
	return (command) => {
		const n = (seen.get(command) ?? 0) + 1;
		seen.set(command, n);
		return n <= max;
	};
}
