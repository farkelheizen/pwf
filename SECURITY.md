# Security

`pwf` is a local command-line tool for managing
`planning-with-files` state. Version 0.1.x is the currently supported release
line.

## Security model

`pwf` is designed for use inside a trusted project checkout:

- It searches ancestor directories for the nearest complete installation of
  planning-with-files and executes that installation's helper scripts directly.
  Do not run `pwf` in a directory tree containing untrusted helper scripts.
- It validates plan identifiers before using them as path components.
- It requires helper scripts to be executable and honors their shebangs.
- It requires `.planning`, plan directories, managed files, and
  `.planning/.active_plan` to be regular, non-symlink paths physically inside
  the discovered project root.
- It rejects ambiguous selections and stale pointers rather than guessing.
- Archive operations preview by default and require `--yes` to perform the
  delegated move.
- It does not install skills, dependencies, or packages automatically.
- The generated `.agents/` skill directory is ignored by Git. Restore it from
  the tracked `skills-lock.json` with
  `npx skills install --frozen-lockfile`, and verify that the restored source,
  commit, path, and content hash match the lock entry.

The planning files can contain sensitive project information. Keep private
planning state out of commits and do not place credentials, access tokens, or
other secrets in plans, fixtures, tests, or documentation.

`pwf` does not interpret Markdown as shell commands. The separate
planning-with-files skill and any agent host that consumes plan files have
their own trust and prompt-injection boundaries; review those files before
using them in an automated workflow.

## Reporting

No private vulnerability reporting channel is configured yet. Do not put
sensitive vulnerability details in a public issue or pull request. Contact the
repository maintainer privately to arrange a secure reporting channel, and
include only the minimum reproducible detail needed to investigate.

For non-sensitive bugs and documentation issues, use the repository's normal
public issue process.
