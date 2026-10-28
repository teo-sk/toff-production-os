# Contributing

Thanks for improving TOFF Production OS. Keep changes focused, game-agnostic, and honest about verification.

## Report bugs

Open a GitHub issue with:

- Framework `VERSION` and OS / shell if relevant  
- What you expected vs what happened  
- Commands run and exit codes (do not invent results)  
- Whether a disposable fixture reproduces the problem  

For security-sensitive reports, see [SECURITY.md](SECURITY.md).

## Propose workflow or template changes

1. Check [docs/philosophy.md](docs/philosophy.md) and [docs/unity-tooling.md](docs/unity-tooling.md) so the proposal fits existing safety rules.  
2. Prefer small PRs: docs-only, templates-only, or scripts-only when practical.  
3. Do not hardcode game names, absolute machine paths, or mandatory folder layouts.  
4. Separate mandatory process from optional architecture recommendations.

## Run regression tests

From the repository root:

```bash
# Shell syntax
find bootstrap scripts templates -name '*.sh' -print0 | xargs -0 bash -n

# Bootstrap suite (expected baseline: 32)
./bootstrap/tests/run-tests.sh

# Capability detector suite (expected baseline: 35)
./scripts/tests/run-capability-detect-tests.sh

# Public hygiene (forbidden internal portfolio strings in active docs/templates)
./scripts/tests/run-public-hygiene-tests.sh
```

Also:

- `./bootstrap/bootstrap.sh --help`  
- Dry-run / install on a **disposable** Unity fixture only — never silently write to a live game  
- Check MDC frontmatter on changed `.mdc` files  
- Check Markdown links for new or changed docs  

## Pull requests

- Target `main` unless maintainers ask otherwise.  
- Describe **why**, consumer impact, and validation actually performed.  
- Update [CHANGELOG.md](CHANGELOG.md) and [VERSION](VERSION) when the change is a release.  
- Do not force-push `main`, rewrite published history, or commit secrets.

## Documentation expectations

- Prefer precise language over marketing claims.  
- Label verification as proven / partial / proposed when citing capabilities.  
- Keep examples anonymized; do not reintroduce private project portfolio names into operational docs.  
- Do not claim tooling success proves gameplay correctness.

## Safety requirements (bootstrap and Unity tooling)

Changes to `bootstrap/`, `scripts/unity-capability-detect.sh`, or Unity tooling safety rules **must**:

- Preserve canonical path validation, Git root checks, and symlink protections  
- Keep default install non-destructive (skip existing files unless explicit `--force`)  
- Remain optional regarding CLI / Pipeline / MCP  
- Never auto-install Unity packages or rewrite MCP configuration  
- Never force-quit the Editor or invent unattended mutation privileges  

Human approval is required for weakening safety rules.
