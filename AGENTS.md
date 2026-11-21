# Project instructions

## Project shape

- Keep `pwf` a self-contained Zsh CLI. Do not add a package manager or
  third-party parser without a project requirement.
- Keep changes focused. Update inline help, `README.md`, and tests when
  command behavior changes.
- Use Semantic Versioning and keep the authoritative version in `pwf`.
  Do not bump versions or create tags for ordinary unreleased changes.

## Documentation and safety

- Keep user-facing behavior in `README.md`, `SECURITY.md`, and
  `CONTRIBUTING.md`. Document any future interface contract in `spec/`.
- Validate inputs before side effects and surface errors explicitly.
- Run `zsh -n pwf`, `zsh -n tests/test-cli.zsh`, and
  `zsh tests/test-cli.zsh` for CLI changes.
