#!/usr/bin/env bash
#
# lint.sh - Lint and spellcheck the scripts and documentation in this repo.
#
# Usage:
#   lint.sh            Check every tracked script and doc
#   lint.sh FILE...    Check the given files instead
#   lint.sh -h         This help
#
# Shell scripts go through `bash -n` and ShellCheck, Python through ruff, Markdown through
# markdownlint, and all of them through codespell. (This line avoids starting with the
# linter's name: a comment that opens with it is read as a malformed directive.)
# ShellCheck errors fail the run; its known tail of warnings and notes (mostly SC2155 and
# unused colour variables) is reported every run but not worth churning through. Every
# other tool fails the run on any finding.
#
set -uo pipefail

# Sources that cannot be followed statically: ~/.bashrc loads its fragments through a variable.
SHELLCHECK_EXCLUDE="SC1090,SC1091"
# offen      - German Jira status in bash/.bash/exports/jira.bash, not a misspelling of "often"
# classe,thi - Mermaid identifiers in the mermaid skill's reference diagrams
# wirth      - Niklaus Wirth, named in the railroad diagram reference
# lightening - used correctly (making lighter) in the mermaid theming reference
SPELL_IGNORE="offen,classe,wirth,thi,lightening"
# Upstream Symfony completion, shipped as-is. Its findings are not ours to fix.
VENDORED=("bash/.bash/completions/composer.bash")
# Vendored upstream markdown: the yazi flavors and plugins ship their own READMEs.
SPELL_DOC_EXCLUDE='^yazi/'
# markdownlint covers this repo's own documentation. The trees under claude/, agents/ and pi/
# are instruction prose for models, written to read well in an agent's context rather than to
# a line-length rule; they carry 600+ findings that say nothing about their quality.
DOC_LINT_EXCLUDE='^(yazi|claude|agents|pi)/'

case "${1:-}" in
	-h | --help)
		sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//'
		exit 0
		;;
esac

cd "$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 1

is_vendored() {
	local v
	for v in "${VENDORED[@]}"; do [[ "$1" == "$v" ]] && return 0; done
	return 1
}

is_python() {
	local first
	[[ "$1" == *.py ]] && return 0
	read -r first <"$1" 2>/dev/null || return 1
	[[ "$first" == *python* ]]
}

# Every tracked script: by extension, or by shebang for the extensionless ones in bin/.
collect_tracked_scripts() {
	local f first
	while IFS= read -r f; do
		[[ -f "$f" ]] || continue
		case "$f" in *.sh | *.bash | *.py) echo "$f"; continue ;; esac
		read -r first <"$f" 2>/dev/null || continue
		# *sh covers sh, bash and zsh shebangs; a separate *bash branch would never be reached.
		case "$first" in '#!'*sh | '#!'*python*) echo "$f" ;; esac
	done < <(git ls-files)
}

SCRIPT_FILES=() DOC_FILES=()
if [[ $# -gt 0 ]]; then
	for f in "$@"; do
		if [[ "$f" == *.md ]]; then DOC_FILES+=("$f"); else SCRIPT_FILES+=("$f"); fi
	done
else
	while IFS= read -r f; do
		is_vendored "$f" || SCRIPT_FILES+=("$f")
	done < <(collect_tracked_scripts | sort -u)
	while IFS= read -r f; do
		DOC_FILES+=("$f")
	done < <(git ls-files '*.md' | grep -vE "$SPELL_DOC_EXCLUDE")
fi

SHELL_FILES=() PY_FILES=() MD_FILES=()
for f in ${SCRIPT_FILES[@]+"${SCRIPT_FILES[@]}"}; do
	if is_python "$f"; then PY_FILES+=("$f"); else SHELL_FILES+=("$f"); fi
done
for f in ${DOC_FILES[@]+"${DOC_FILES[@]}"}; do
	grep -qE "$DOC_LINT_EXCLUDE" <<<"$f" || MD_FILES+=("$f")
done

printf 'Linting %d script(s) (%d shell, %d python) and %d doc(s) (%d in markdownlint scope)\n\n' \
	"${#SCRIPT_FILES[@]}" "${#SHELL_FILES[@]}" "${#PY_FILES[@]}" "${#DOC_FILES[@]}" "${#MD_FILES[@]}"

failed=0
log=$(mktemp -d)
trap 'rm -rf "$log"' EXIT

if [[ ${#SHELL_FILES[@]} -gt 0 ]]; then
	command -v shellcheck >/dev/null || { echo "shellcheck not installed (brew install shellcheck)"; exit 2; }

	for f in "${SHELL_FILES[@]}"; do
		bash -n "$f" 2>>"$log/syntax" || echo "syntax error: $f" >>"$log/syntax"
	done
	if [[ -s "$log/syntax" ]]; then
		echo "bash -n: FAILED"
		cat "$log/syntax"
		failed=1
	else
		echo "bash -n: ${#SHELL_FILES[@]} file(s) parse"
	fi

	shellcheck -s bash -e "$SHELLCHECK_EXCLUDE" -f gcc "${SHELL_FILES[@]}" >"$log/sc" 2>&1
	sc_status=$?
	# 0 is clean and 1 is "findings reported"; anything higher means ShellCheck itself never ran
	# (fatal error, bad usage). Counting the report without checking this let a crashed
	# ShellCheck report "0 error(s)" and the whole run pass.
	if [[ "$sc_status" -gt 1 ]]; then
		echo "shellcheck: FAILED to run (exit $sc_status)"
		cat "$log/sc"
		failed=1
	else
		errors=$(grep -c ': error:' "$log/sc")
		warnings=$(grep -c ': warning:' "$log/sc")
		notes=$(grep -c ': note:' "$log/sc")
		printf 'shellcheck: %s error(s), %s warning(s), %s note(s)\n' "$errors" "$warnings" "$notes"
		if [[ "$errors" -gt 0 ]]; then
			grep ': error:' "$log/sc"
			failed=1
		fi
	fi
fi

if [[ ${#PY_FILES[@]} -gt 0 ]]; then
	if command -v uvx >/dev/null; then
		if uvx ruff check "${PY_FILES[@]}" >"$log/ruff" 2>&1; then
			echo "ruff: clean"
		else
			echo "ruff: FAILED"
			cat "$log/ruff"
			failed=1
		fi
	else
		echo "ruff: skipped (uv not installed)"
	fi
fi

if [[ ${#MD_FILES[@]} -gt 0 ]]; then
	if command -v npx >/dev/null; then
		# Reads .markdownlint.jsonc from the repo root.
		if npx --yes markdownlint-cli2 "${MD_FILES[@]}" >"$log/md" 2>&1; then
			echo "markdownlint: clean"
		else
			echo "markdownlint: FAILED"
			cat "$log/md"
			failed=1
		fi
	else
		echo "markdownlint: skipped (node/npx not installed)"
	fi
fi

SPELL_FILES=(
	${SHELL_FILES[@]+"${SHELL_FILES[@]}"}
	${PY_FILES[@]+"${PY_FILES[@]}"}
	${DOC_FILES[@]+"${DOC_FILES[@]}"}
)
if [[ ${#SPELL_FILES[@]} -gt 0 ]]; then
	if command -v uvx >/dev/null; then
		if uvx codespell --ignore-words-list="$SPELL_IGNORE" "${SPELL_FILES[@]}" >"$log/spell" 2>&1; then
			echo "codespell: clean"
		else
			echo "codespell: FAILED"
			cat "$log/spell"
			failed=1
		fi
	else
		echo "codespell: skipped (uv not installed)"
	fi
fi

echo ""
if [[ "$failed" -eq 0 ]]; then
	echo "LINT PASS"
else
	echo "LINT FAIL"
fi
exit "$failed"
