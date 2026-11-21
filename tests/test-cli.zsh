#!/bin/zsh

emulate -L zsh

ROOT=${${(%):-%N}:A:h:h}
failures=0
FIXTURE=$(mktemp -d "${TMPDIR:-/tmp}/pwf-cli.XXXXXX")
FIXTURE_ROOT=${FIXTURE:A}
NO_INSTALL=$(mktemp -d "${TMPDIR:-/tmp}/pwf-no-install.XXXXXX")
OUTSIDE=$(mktemp -d "${TMPDIR:-/tmp}/pwf-outside.XXXXXX")
INSTALL_PREFIX="$FIXTURE/install"
trap 'rm -rf "$FIXTURE" "$NO_INSTALL" "$OUTSIDE"' EXIT

ok() {
  print -r -- "ok - $1"
}

not_ok() {
  print -u2 -r -- "not ok - $1"
  (( failures++ ))
}

expect_status() {
  local expected=$1 label=$2
  if [[ "$LAST_STATUS" == "$expected" ]]; then
    ok "$label"
  else
    not_ok "$label (expected $expected, got $LAST_STATUS: $LAST_OUTPUT)"
  fi
}

expect_contains() {
  local expected=$1 label=$2
  if [[ "$LAST_OUTPUT" == *"$expected"* ]]; then
    ok "$label"
  else
    not_ok "$label (missing '$expected': $LAST_OUTPUT)"
  fi
}

expect_file_contains() {
  local file=$1 expected=$2 label=$3
  if [[ -f "$file" && "$(< "$file")" == *"$expected"* ]]; then
    ok "$label"
  else
    not_ok "$label"
  fi
}

run_capture() {
  LAST_OUTPUT="$("$@" 2>&1)"
  LAST_STATUS=$?
}

run_pwf() {
  local cwd=$1
  shift
  LAST_OUTPUT="$(cd "$cwd" && "$ROOT/pwf" "$@" 2>&1)"
  LAST_STATUS=$?
}

run_pwf_no_tty() {
  local cwd=$1
  shift
  LAST_OUTPUT="$(cd "$cwd" && "$ROOT/pwf" "$@" </dev/null 2>&1)"
  LAST_STATUS=$?
}

make_plan() {
  local id=$1
  mkdir -p "$FIXTURE/.planning/$id"
  cat > "$FIXTURE/.planning/$id/task_plan.md" <<'EOF'
# Test plan

### Phase 1: Test
- **Status:** complete
EOF
  : > "$FIXTURE/.planning/$id/findings.md"
  : > "$FIXTURE/.planning/$id/progress.md"
}

for arg in help --help -h; do
  run_capture "$ROOT/pwf" "$arg"
  expect_status 0 "$arg succeeds"
  expect_contains 'Usage: pwf <command>' "$arg shows help"
done

run_capture "$ROOT/pwf" help install
expect_status 0 'help install succeeds'
expect_contains 'npx skills install --frozen-lockfile' 'help install shows the restore command'
expect_contains 'pwf never invokes npx' 'help install explains read-only behavior'

run_capture "$ROOT/pwf" help unknown
expect_status 2 'unknown help topic fails'

for arg in --version -V; do
  run_capture "$ROOT/pwf" "$arg"
  expect_status 0 "$arg succeeds"
  expect_contains 'pwf 0.1.1' "$arg shows version"
done

run_capture "$ROOT/pwf" invalid
expect_status 2 'unknown command fails'

run_capture "$ROOT/pwf" --version extra
expect_status 2 'unexpected arguments fail'

run_capture env PREFIX="$INSTALL_PREFIX" "$ROOT/install.sh"
expect_status 0 'installer succeeds'
if [[ -L "$INSTALL_PREFIX/bin/pwf" && "$(readlink "$INSTALL_PREFIX/bin/pwf")" == "$ROOT/pwf" ]]; then
  ok 'installer creates a symlink'
else
  not_ok 'installer creates a symlink'
fi

SCRIPT_DIR="$FIXTURE/.agents/skills/planning-with-files/scripts"
mkdir -p "$SCRIPT_DIR" "$FIXTURE/src/deep" \
  "$FIXTURE/src/.agents/skills/planning-with-files/scripts"

cat > "$SCRIPT_DIR/init-session.sh" <<'EOF'
#!/bin/sh
set -eu
slug=$1
plan_id="2026-11-20-$slug"
mkdir -p ".planning/$plan_id"
cat > ".planning/$plan_id/task_plan.md" <<'PLAN'
# Test plan

### Phase 1: Test
- **Status:** complete
PLAN
: > ".planning/$plan_id/findings.md"
: > ".planning/$plan_id/progress.md"
printf '%s\n' "$plan_id" > .planning/.active_plan
printf 'PLAN_ID=%s\n' "$plan_id"
EOF

cat > "$SCRIPT_DIR/set-active-plan.sh" <<'EOF'
#!/bin/sh
set -eu
mkdir -p .planning
case "${1-}" in
  --list)
    if [ "${2-}" = '--archived' ]; then
      printf '%s\n' 'fake archived list'
    else
      printf '%s\n' 'fake active list'
    fi
    ;;
  --archive)
    id=$2
    if [ "${3-}" = '--yes' ]; then
      mkdir -p .planning/.archive
      mv ".planning/$id" ".planning/.archive/$id"
      printf 'Archived %s\n' "$id"
    else
      printf 'Preview: would archive %s\n' "$id"
    fi
    ;;
  *)
    id=$1
    [ -d ".planning/$id" ]
    printf '%s\n' "$id" > .planning/.active_plan
    printf 'Active plan set to: %s\n' "$id"
    ;;
esac
EOF

cat > "$SCRIPT_DIR/check-complete.sh" <<'EOF'
#!/usr/bin/env bash
if [[ -z "${BASH_VERSION:-}" ]]; then
  exit 99
fi
printf '%s\n' 'fake status'
exit 7
EOF

cat > "$SCRIPT_DIR/plan-doctor.sh" <<'EOF'
#!/bin/sh
printf '%s\n' 'fake doctor'
EOF

chmod +x "$SCRIPT_DIR"/*.sh

run_pwf "$FIXTURE/src/deep" new auth
expect_status 0 'new works from a nested directory'
expect_contains 'PLAN_ID=2026-11-20-auth' 'new reports the exact plan ID'
expect_file_contains "$FIXTURE/.planning/.active_plan" '2026-11-20-auth' 'new activates the reported plan'

run_pwf "$FIXTURE/src/deep" path
expect_status 0 'path resolves the active plan'
expect_contains "$FIXTURE_ROOT/.planning/2026-11-20-auth" 'path prints an absolute plan directory'

run_pwf "$FIXTURE/src/deep" path task_plan.md
expect_status 0 'path resolves a managed file'
expect_contains "$FIXTURE_ROOT/.planning/2026-11-20-auth/task_plan.md" 'path prints the managed file'

printf '%s\n' 'outside' > "$OUTSIDE/findings.md"
rm "$FIXTURE/.planning/2026-11-20-auth/findings.md"
ln -s "$OUTSIDE/findings.md" "$FIXTURE/.planning/2026-11-20-auth/findings.md"
run_pwf "$FIXTURE/src/deep" path findings.md
expect_status 1 'path rejects a managed file outside the project'
expect_contains 'active plan does not exist' 'path reports an escaping managed file'
run_pwf "$FIXTURE/src/deep" doctor
expect_status 1 'doctor rejects an escaping managed file'
expect_contains 'active plan does not exist' 'doctor reports an escaping managed file'
rm "$FIXTURE/.planning/2026-11-20-auth/findings.md"
: > "$FIXTURE/.planning/2026-11-20-auth/findings.md"

printf '\357\273\2772026-11-20-auth\n' > "$FIXTURE/.planning/.active_plan"
run_pwf "$FIXTURE/src/deep" path
expect_status 0 'path accepts a BOM-prefixed active pointer'
expect_contains "$FIXTURE_ROOT/.planning/2026-11-20-auth" 'path strips the active pointer BOM'
run_pwf "$FIXTURE/src/deep" doctor
expect_status 0 'doctor accepts a BOM-prefixed active pointer'
run_pwf "$FIXTURE/src/deep" done
expect_status 0 'done accepts a BOM-prefixed active pointer'
expect_contains 'Preview: would archive 2026-11-20-auth' 'done resolves the BOM-prefixed pointer'
printf '%s\n' '2026-11-20-auth' > "$FIXTURE/.planning/.active_plan"

printf '%s\n' '2026-11-20-auth' > "$OUTSIDE/active_plan"
rm "$FIXTURE/.planning/.active_plan"
ln -s "$OUTSIDE/active_plan" "$FIXTURE/.planning/.active_plan"
run_pwf "$FIXTURE/src/deep" path
expect_status 1 'path rejects a symlinked active pointer'
expect_contains 'no valid active plan is set' 'path reports a symlinked active pointer'
rm "$FIXTURE/.planning/.active_plan"
printf '%s\n' '2026-11-20-auth' > "$FIXTURE/.planning/.active_plan"

mv "$FIXTURE/.planning" "$FIXTURE/planning-real"
ln -s "$FIXTURE/planning-real" "$FIXTURE/.planning"
run_pwf "$FIXTURE/src/deep" path
expect_status 1 'path rejects a symlinked planning root'
expect_contains 'active plan does not exist' 'path reports a symlinked planning root'
rm "$FIXTURE/.planning"
mv "$FIXTURE/planning-real" "$FIXTURE/.planning"

run_pwf "$FIXTURE/src/deep" path unknown.md
expect_status 2 'path rejects unknown files'

run_pwf "$FIXTURE/src/deep" list
expect_status 0 'list delegates to the upstream listing'
expect_contains 'fake active list' 'list shows active plans'

run_pwf "$FIXTURE/src/deep" new billing
expect_status 0 'new creates a second plan'

run_pwf "$FIXTURE/src/deep" use auth
expect_status 0 'use accepts a unique slug'
expect_file_contains "$FIXTURE/.planning/.active_plan" '2026-11-20-auth' 'use updates the shared pointer'

make_plan 2026-11-19-auth
printf '%s\n' '2026-11-20-billing' > "$FIXTURE/.planning/.active_plan"
run_pwf "$FIXTURE/src/deep" use auth
expect_status 1 'ambiguous use fails'
expect_contains "multiple plans match 'auth'" 'ambiguous use explains the candidates'
expect_file_contains "$FIXTURE/.planning/.active_plan" '2026-11-20-billing' 'ambiguous use preserves the active pointer'

run_pwf_no_tty "$FIXTURE/src/deep" use
expect_status 1 'noninteractive use without a query fails'
expect_contains 'requires an interactive terminal' 'noninteractive use explains the requirement'

run_pwf "$FIXTURE/src/deep" status
expect_status 7 'status forwards the upstream exit status'
expect_contains 'fake status' 'status forwards the upstream report'

printf '%s\n' '2026-11-20-auth' > "$FIXTURE/.planning/.active_plan"
run_pwf "$FIXTURE/src/deep" doctor
expect_status 0 'doctor verifies a valid active plan'
expect_contains 'Active plan verified: 2026-11-20-auth' 'doctor reports the verified plan'

run_pwf "$FIXTURE/src/deep" done 2026-11-20-auth
expect_status 0 'done previews archive by default'
expect_contains 'Preview: would archive 2026-11-20-auth' 'done shows the archive preview'
if [[ -d "$FIXTURE/.planning/2026-11-20-auth" ]]; then
  ok 'archive preview does not move the plan'
else
  not_ok 'archive preview does not move the plan'
fi

run_pwf "$FIXTURE/src/deep" done 2026-11-20-auth --yes
expect_status 0 'done archives with --yes'
if [[ -d "$FIXTURE/.planning/.archive/2026-11-20-auth" ]]; then
  ok 'archive moves the plan reversibly'
else
  not_ok 'archive moves the plan reversibly'
fi

run_pwf "$FIXTURE/src/deep" doctor
expect_status 1 'doctor rejects a stale active pointer'
expect_contains 'active plan does not exist' 'doctor reports stale active state'

run_pwf "$FIXTURE/src/deep" list --all
expect_status 0 'list --all succeeds'
expect_contains 'fake archived list' 'list --all includes archived plans'

run_pwf "$NO_INSTALL" list
expect_status 1 'missing installation fails'
expect_contains 'no complete planning-with-files installation' 'missing installation is explicit'

print
if (( failures == 0 )); then
  print -r -- "All tests passed."
else
  print -u2 -r -- "$failures test(s) failed."
fi
exit "$failures"
