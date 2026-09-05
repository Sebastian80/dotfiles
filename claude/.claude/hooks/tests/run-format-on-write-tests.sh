#!/usr/bin/env bash
# Verdict matrix for format-on-write.sh.
#
# Run after ANY change to the hook:
#     bash claude/.claude/hooks/tests/run-format-on-write-tests.sh
#
# Builds throwaway projects with a STUB formatter (a vendor/bin/php-cs-fixer that
# appends a marker line), so the real decision path runs without PHP tooling.
# Each case asserts the expected verdict: "reformatted" (hook emitted
# additionalContext and the file changed) or "silent" (no output, file
# untouched). A hook that fails open prints nothing and looks healthy —
# asserting the file content is what catches that.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/../format-on-write.sh"
[ -f "$HOOK" ] || { echo "hook not found: $HOOK"; exit 1; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
export HOME="$T/home"; mkdir -p "$HOME/.claude"   # keep the log out of the real one

# Project A: php-cs-fixer configured, stub binary rewrites the file.
mkdir -p "$T/a/src" "$T/a/vendor/bin"
touch "$T/a/.php-cs-fixer.dist.php"
cat > "$T/a/vendor/bin/php-cs-fixer" <<'EOF'
#!/usr/bin/env bash
# stub: "fix --quiet <file>" appends a marker
echo "// formatted" >> "$3"
EOF
chmod +x "$T/a/vendor/bin/php-cs-fixer"
# Project B: config present, no binary.
mkdir -p "$T/b/src"; touch "$T/b/.php-cs-fixer.dist.php"
# Project C: no config at all.
mkdir -p "$T/c/src"
# Project D: stub formatter that changes nothing.
mkdir -p "$T/d/src" "$T/d/vendor/bin"; touch "$T/d/.php-cs-fixer.dist.php"
printf '#!/usr/bin/env bash\nexit 0\n' > "$T/d/vendor/bin/php-cs-fixer"; chmod +x "$T/d/vendor/bin/php-cs-fixer"
# Project E: .claude/format-file override (the "run it in the container" hook),
# plus a host php-cs-fixer stub that must NOT run when the override exists.
mkdir -p "$T/e/src" "$T/e/.claude" "$T/e/vendor/bin"; touch "$T/e/.php-cs-fixer.dist.php"
printf '#!/usr/bin/env bash\necho "// via format-file" >> "$1"\n' > "$T/e/.claude/format-file"; chmod +x "$T/e/.claude/format-file"
printf '#!/usr/bin/env bash\necho "// via host fixer" >> "$3"\n' > "$T/e/vendor/bin/php-cs-fixer"; chmod +x "$T/e/vendor/bin/php-cs-fixer"

run_case() {  # label file want(reformatted|silent)
  local lbl=$1 file=$2 want=$3 got out before after
  printf '<?php\n' > "$file"
  before=$(md5sum < "$file")
  out=$(jq -nc --arg f "$file" '{tool_name:"Edit",tool_input:{file_path:$f}}' | bash "$HOOK" 2>/dev/null)
  after=$(md5sum < "$file")
  if [ "$before" != "$after" ] && printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
    got=reformatted
  elif [ "$before" = "$after" ] && [ -z "$out" ]; then
    got=silent
  else
    got=INCONSISTENT
  fi
  if [ "$got" = "$want" ]; then mark=ok; pass=$((pass + 1)); else mark=FAIL; fail=$((fail + 1)); fi
  printf '%-48s -> %-12s want=%-12s %s\n' "$lbl" "$got" "$want" "$mark"
}

pass=0; fail=0
run_case "php file, config + stub binary"          "$T/a/src/Foo.php"  reformatted
run_case "php file in subdir (walk-up finds root)" "$T/a/src/Sub.php"  reformatted
run_case "php file, config but no binary"          "$T/b/src/Foo.php"  silent
run_case "php file, no config anywhere"            "$T/c/src/Foo.php"  silent
run_case "php file, formatter changes nothing"     "$T/d/src/Foo.php"  silent
run_case "non-code extension (.txt) ignored"       "$T/a/src/notes.txt" silent
run_case "override: .claude/format-file rewrites"  "$T/e/src/Foo.php"  reformatted
run_case "override: any extension goes to it"      "$T/e/src/x.twig"   reformatted
if grep -q 'via host fixer' "$T/e/src/Foo.php"; then
  echo "override must win over host fixer               -> BOTH RAN     want=override     FAIL"; fail=$((fail+1))
else
  echo "override must win over host fixer               -> override     want=override     ok"; pass=$((pass+1))
fi

# Bash events: the hook must find files the command wrote via redirect, heredoc,
# tee or sed -i (auto mode writes files this way and bypasses Edit|Write).
run_bash_case() {  # label command file want(reformatted|silent)
  local lbl=$1 cmd=$2 file=$3 want=$4 got out before after
  printf '<?php\n' > "$file"
  before=$(md5sum < "$file")
  out=$(jq -nc --arg c "$cmd" --arg d "$(dirname "$file")" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' | bash "$HOOK" 2>/dev/null)
  after=$(md5sum < "$file")
  if [ "$before" != "$after" ] && printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null 2>&1; then
    got=reformatted
  elif [ "$before" = "$after" ] && [ -z "$out" ]; then
    got=silent
  else
    got=INCONSISTENT
  fi
  if [ "$got" = "$want" ]; then mark=ok; pass=$((pass + 1)); else mark=FAIL; fail=$((fail + 1)); fi
  printf '%-48s -> %-12s want=%-12s %s\n' "$lbl" "$got" "$want" "$mark"
}
run_bash_case "bash heredoc > relative path"        "cat > Bar.php <<'EOF'
<?php
EOF"                                                        "$T/a/src/Bar.php" reformatted
run_bash_case "bash >> absolute path"               "printf 'x' >> $T/a/src/Baz.php"      "$T/a/src/Baz.php" reformatted
run_bash_case "bash tee"                            "echo x | tee $T/a/src/Tee.php"       "$T/a/src/Tee.php" reformatted
run_bash_case "bash sed -i"                         "sed -i 's/a/b/' $T/a/src/Sed.php"    "$T/a/src/Sed.php" reformatted
run_bash_case "bash sed -i with flag value (-e)"    "sed -i -e 's/a/b/' $T/a/src/SedE.php" "$T/a/src/SedE.php" reformatted
run_bash_case "bash read-only command"              "grep -n foo $T/a/src/Foo.php"        "$T/a/src/Foo.php" silent
run_bash_case "bash redirect to /dev/null"          "ls > /dev/null 2>&1"                 "$T/a/src/Foo.php" silent
run_bash_case "bash write in project without config" "cat > $T/c/src/New.php <<'EOF'
<?php
EOF"                                                        "$T/c/src/New.php" silent

# Missing file and empty input must be silent too.
out=$(jq -nc '{tool_name:"Edit",tool_input:{file_path:"/nonexistent/x.php"}}' | bash "$HOOK" 2>/dev/null)
if [ -z "$out" ]; then echo "missing file                                     -> silent       want=silent       ok"; pass=$((pass+1)); else echo "missing file -> FAIL"; fail=$((fail+1)); fi
out=$(printf '' | bash "$HOOK" 2>/dev/null)
if [ -z "$out" ]; then echo "empty stdin                                      -> silent       want=silent       ok"; pass=$((pass+1)); else echo "empty stdin -> FAIL"; fail=$((fail+1)); fi

echo
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
