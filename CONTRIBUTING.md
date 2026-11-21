# Contributing

Keep the reference implementation as a self-contained Zsh executable.

## Local checks

Run the same checks as CI:

```zsh
zsh -n pwf
zsh -n tests/test-cli.zsh
git diff --check
zsh tests/test-cli.zsh
```

## Change guidelines

- Update inline help, `README.md`, and tests when behavior changes.
- Validate inputs before side effects and report failures explicitly.
- Use synthetic test values; never commit secrets.
