# Changelog

All notable changes to TOFF Games Production OS are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) ideas; versioning is [SemVer](https://semver.org/).

## [0.2.0] — 2026-10-27

### Added

- Initial extraction of the studio Production OS into a standalone repository.
- Studio `AGENTS.md` (maintain the OS) vs `templates/AGENTS.template.md` (game repos).
- Cursor rule templates: task delivery, Unity MCP safety, architecture recommendations, coding/tests, assets/scenes.
- Documentation: philosophy, pipeline, agent architecture, tooling, validation strategy, studio-vs-project, roadmap.
- Portable `templates/scripts/validate.sh` (no hardcoded Unity version or test assembly; pin from `ProjectSettings/ProjectVersion.txt`).
- `bootstrap/bootstrap.sh` with `--dry-run`, non-destructive default, post-bootstrap report.
- `examples/nehokej/` pilot findings from onboarding, code workflow (GAME-E2E-001), and Unity MCP (GAME-E2E-002).

### Verified in pilot (Nehokej reference — not portfolio-wide proof)

- Agent onboarding via repo docs + Cursor rules (**proven** for Nehokej).
- Spec → pure C# → Edit Mode tests → evidence report (**proven** for GAME-E2E-001 on Nehokej).
- MCP exact project-root identity, approved single-property scene mutation, property readback, console check, Play Mode observation, serialized-diff hygiene including incidental YAML fields (**proven** for GAME-E2E-002 on Nehokej with noted limits).

### Known limitations

- Bootstrap not yet rolled out to WheelDraw / SOWA / other titles.
- Validate script does not provide CI runners, licensing, or device farms.
- MCP remains optional and server-implementation-dependent.
- No automatic upgrade path from older game installs beyond re-running bootstrap carefully.
- Framework static self-checks ≠ production readiness.

### Deferred

- Shared CI templates and release automation.
- Portfolio dashboard / issue-tracker integration.
- Multi-agent orchestration and event-driven handoffs.
- Art pipeline and store-publish automation.
- Cross-game package sharing policy.

## [0.1.0] — 2026-10-27

Draft Production OS lived inside the Nehokej docs tree (`docs/studio/TOFF_Games_Production_OS_v0.1.md`) before extraction. Not a shipped standalone repo.
