#!/usr/bin/env bash
#
# lint-scripts.sh - Lint and spellcheck the scripts in this repo.
#
# Usage:
#   lint-scripts.sh            Check every tracked script
#   lint-scripts.sh FILE...    Check the given files instead
#   lint-scripts.sh -h         This help
#
# Shell scripts go through `bash -n` and ShellCheck, Python through ruff, and both through
# codespell. (This line avoids starting with the linter's name: a comment that opens with it is
# read as a malformed directive.)
# Only errors fail the run: the repo carries a known tail of warnings and notes (mostly SC2155 and
# unused colour variables) that is reported on every run but not worth churning through.
#
set -uo pipefail

# Sources that cannot be followed statically: ~/.bashrc loads its fragments through a variable.
SHELLCHECK_EXCLUDE="SC1090,SC1091"
# "Offen" is a German Jira status in bash/.bash/exports/jira.bash, not a misspelling of "often".
SPELL_IGNORE="offen"
# Upstream Symfony completion, shipped as-is. Its findings are not ours to fix.
VENDORED=("bash/.bash/completions/composer.bash")

case "${1:-}" in
	-h | --help)
		sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'
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
collect_tracked() {
	local f first
	while IFS= read -r f; do
		[[ -f "$f" ]] || continue
		case "$f" in *.sh | *.bash | *.py) echo "$f"; continue ;; esac
		read -r first <"$f" 2>/dev/null || continue
		# *sh covers sh, bash and zsh shebangs; a separate *bash branch would never be reached.
		case "$first" in '#!'*sh | '#!'*python*) echo "$f" ;; esac
	done < <(git ls-files)
}

FILES=()
if [[ $# -gt 0 ]]; then
	FILES=("$@")
else
	while IFS= read -r f; do
		is_vendored "$f" || FILES+=("$f")
	done < <(collect_tracked | sort -u)
fi

SHELL_FILES=() PY_FILES=()
for f in "${FILES[@]}"; do
	if is_python "$f"; then PY_FILES+=("$f"); else SHELL_FILES+=("$f"); fi
done

printf 'Linting %d script(s): %d shell, %d python\n\n' "${#FILES[@]}" "${#SHELL_FILES[@]}" "${#PY_FILES[@]}"

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
	errors=$(grep -c ': error:' "$log/sc")
	warnings=$(grep -c ': warning:' "$log/sc")
	notes=$(grep -c ': note:' "$log/sc")
	printf 'shellcheck: %s error(s), %s warning(s), %s note(s)\n' "$errors" "$warnings" "$notes"
	if [[ "$errors" -gt 0 ]]; then
		grep ': error:' "$log/sc"
		failed=1
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

if command -v uvx >/dev/null; then
	if uvx codespell --ignore-words-list="$SPELL_IGNORE" "${FILES[@]}" >"$log/spell" 2>&1; then
		echo "codespell: clean"
	else
		echo "codespell: FAILED"
		cat "$log/spell"
		failed=1
	fi
else
	echo "codespell: skipped (uv not installed)"
fi

echo ""
if [[ "$failed" -eq 0 ]]; then
	echo "LINT PASS"
else
	echo "LINT FAIL"
fi
exit "$failed"
