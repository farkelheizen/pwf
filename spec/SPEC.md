# pwf 0.1.0 specification

## Runtime and scope

- The reference implementation is a self-contained Zsh executable.
- The authoritative version is stored in the `pwf` executable.
- The command manages human-facing lifecycle state; planning-with-files remains
  responsible for templates, phase parsing, validation, and archive mechanics.
- The command must work from any descendant directory of the project root.

## Installation discovery

Starting at `$PWD`, walk toward `/`. At each directory, check these candidate
script directories in order:

1. `.agents/skills/planning-with-files/scripts`
2. `.github/skills/planning-with-files/scripts`
3. `.claude/skills/planning-with-files/scripts`
4. `.opencode/skills/planning-with-files/scripts`

A candidate is valid only when it contains readable:

- `init-session.sh`
- `set-active-plan.sh`
- `check-complete.sh`
- `plan-doctor.sh`

All four helper scripts must also be executable and provide a usable shebang.
`pwf` invokes them directly so their declared interpreter is honored; helpers
must not rely on the caller's `sh` implementation.

The nearest valid candidate wins. If none exists, commands that need a project
fail with a clear error and a nonzero exit code. Help and version output remain
available outside a project.

### Skill restoration

The generated `.agents/` directory is ignored by this repository. The tracked
`skills-lock.json` records the required source, commit, skill path, and content
hash. After a fresh checkout, restore the locked skill with the repository's
supported skills tooling, currently:

```zsh
npx skills add OthmanAdi/planning-with-files
```

The restore is complete only when the installed skill matches the lockfile
entry. `pwf` does not install or verify skills automatically; the environment
bootstrap is responsible for lockfile-aware installation and verification.

## Commands

### `pwf new <slug>`

Requires exactly one slug argument. Delegates to `init-session.sh`, captures
the exact `PLAN_ID=<id>` line from its output, and verifies that the resulting
plan exists. Named initialization already updates `.planning/.active_plan`; the
wrapper must not perform a second activation.

### `pwf list [--archived|--all]`

- No option delegates to `set-active-plan.sh --list`.
- `--archived` delegates to `set-active-plan.sh --list --archived`.
- `--all` runs both list operations.

### `pwf use [plan-id|unique-slug]`

- An exact existing plan ID wins.
- Otherwise, a suffix match of the form `<date>-<slug>` is accepted only when
  it is unique.
- Ambiguous or missing matches fail without changing `.active_plan`.
- With no argument, a numbered picker is available only on a TTY.
- In noninteractive use, no argument is an error.

The command updates the shared pointer only. It cannot modify an exported
`PLAN_ID` in the calling shell; upstream resolver precedence remains unchanged.

### `pwf done [plan-id] [--yes]`

- Defaults to the valid shared active plan when no ID is supplied.
- Without `--yes`, delegates to the upstream archive preview.
- With `--yes`, delegates to the upstream archive operation.
- Invalid or missing plans fail before delegation.

### `pwf status`

Delegates to `check-complete.sh` and forwards its output and exit status.
Status is advisory and does not invent semantic completion exit codes.

### `pwf doctor`

Runs `plan-doctor.sh`, then verifies that `.planning/.active_plan` is a valid
regular file physically contained in the project, and that the referenced plan
directory contains `task_plan.md`, `findings.md`, and `progress.md`.

### `pwf path [managed-file]`

Prints the absolute active plan directory or one of:

- `task_plan.md`
- `findings.md`
- `progress.md`

Other paths are rejected. The active pointer must be a regular, project-
contained file identifying an existing plan.

## Exit behavior

- `0`: successful command or successful delegated command
- `1`: operational failure, missing plan, stale state, or ambiguous selection
- `2`: usage error, unknown command, or unsupported option

Delegated command exit statuses are preserved unless the wrapper must report a
validation or usage error before delegation.

## Security and reliability

- Quote all paths and delegated arguments.
- Validate identifiers before using them in filesystem paths.
- Require the planning root, plan directory, and all managed files to be
  regular non-symlink paths physically inside the discovered project root.
- Require `.planning/.active_plan` to be a regular, project-contained
  non-symlink file.
- Do not infer newly created plans with `ls`, `head`, or timestamp ordering.
- Do not silently replace stale active state.
- Do not automatically install dependencies or skills.
