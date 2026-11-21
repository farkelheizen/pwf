# pwf

`pwf` is a small Zsh CLI for managing named
[planning-with-files](https://github.com/OthmanAdi/planning-with-files) plans
from anywhere inside a project tree.

Version 0.1.0 delegates plan creation, selection, validation, and archiving to
the planning-with-files scripts installed in the project. It does not replace
the planning skill or modify the caller's shell environment.

## Requirements

- macOS with Zsh
- A complete planning-with-files script installation in the project

Project-specific agent guidance is tracked in [AGENTS.md](AGENTS.md).

The CLI searches upward from the current directory for the nearest installation
under one of these layouts:

```text
.agents/skills/planning-with-files/scripts/
.github/skills/planning-with-files/scripts/
.claude/skills/planning-with-files/scripts/
.opencode/skills/planning-with-files/scripts/
```

The installation must provide executable `init-session.sh`,
`set-active-plan.sh`, `check-complete.sh`, and `plan-doctor.sh` scripts with
usable shebangs. `pwf` invokes these scripts directly so their declared
interpreters are honored.

## Installation

Run the installer from this repository:

```zsh
./install.sh
```

By default this creates `~/.local/bin/pwf`. To use another prefix:

```zsh
PREFIX="$HOME/bin" ./install.sh
```

Ensure the selected `bin` directory is on `PATH`, then run `pwf` from inside a
project containing planning-with-files.

The installer creates a symlink to this checkout; it does not copy source files
or install dependencies.

## Restoring agent skills

The generated `.agents/` directory is intentionally ignored. The tracked
[skills-lock.json](skills-lock.json) records the planning-with-files source,
exact commit, skill path, and content hash used by this checkout.

The lockfile is a reproducibility record, not an installer by itself. After a
fresh checkout, restore the locked skill with the repository's current
bootstrap command:

```zsh
npx skills add OthmanAdi/planning-with-files
```

The restored skill must match the source, commit, skill path, and content hash
recorded in `skills-lock.json`. Verify that the files appear under
`.agents/skills/planning-with-files/` before running project-local planning
commands. `pwf` does not install or verify skills automatically.

## Commands

```text
pwf new <slug>
```

Creates and activates a named plan. The exact `PLAN_ID=` reported by
`init-session.sh` is used; the wrapper does not infer the directory with
filesystem globbing.

```text
pwf list
pwf list --archived
pwf list --all
```

Lists active plans, archived plans, or both. `--all` runs both upstream list
operations.

```text
pwf use <plan-id-or-unique-slug>
pwf use
```

Selects an exact plan ID or a unique suffix such as `auth`. Without a query,
`pwf use` displays a numbered picker only when attached to a TTY. It fails
clearly in noninteractive use rather than guessing.

This command updates `.planning/.active_plan`. It cannot change an already
exported `PLAN_ID` in the calling shell. The upstream resolver gives an
explicit `PLAN_ID` precedence over the shared pointer.

```text
pwf done [plan-id] [--yes]
```

Previews archiving by default. Pass `--yes` to perform the reversible archive
operation. With no plan ID, the current `.planning/.active_plan` is used.

```text
pwf status
pwf doctor
```

`status` forwards the upstream completion report. It is report-only; an exit
code of zero does not necessarily mean every phase is complete.

`doctor` runs the upstream diagnostic and also verifies that the shared active
pointer names an existing, non-archived plan.

```text
pwf path
pwf path task_plan.md
pwf path findings.md
pwf path progress.md
```

Prints the active plan directory or one of its three managed files. Other file
names are rejected.

Use `pwf help` for the detected project and planning-script paths.

## Safety behavior

- No plan is archived without `--yes`.
- Ambiguous plan matches fail without changing the active pointer.
- Missing or stale active pointers are reported explicitly.
- Planning roots, plan directories, managed files, and the active pointer must
  be regular non-symlink paths physically contained in the project.
- Input is validated before delegated commands perform side effects.
- `pwf` never installs planning-with-files automatically.

## Development

Run the same checks as CI:

```zsh
zsh -n pwf
zsh -n tests/test-cli.zsh
git diff --check
zsh tests/test-cli.zsh
```

The command is intentionally self-contained and has no package-manager or
third-party parser dependency.
