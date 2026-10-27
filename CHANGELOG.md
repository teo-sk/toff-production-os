# Changelog

All notable changes to TOFF Games Production OS are documented here.  
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) ideas; versioning is [SemVer](https://semver.org/).

## [0.3.0] — 2026-10-27

### Added

- **Unity Tooling Contract** in [docs/unity-tooling.md](docs/unity-tooling.md): conceptual capabilities, permission levels (`READ` / `CONTROLLED_WRITE` / `ARBITRARY_EXECUTION`), backend selection rules, evidence strength, and safety policy.
- Read-only [scripts/unity-capability-detect.sh](scripts/unity-capability-detect.sh) with machine-readable JSON and automated fixture tests under `scripts/tests/`.
- Tooling completion-report template: `templates/docs/tooling-completion-report.template.md` (installed by bootstrap for new projects).
- SOWA CLI/Pipeline pilot evidence under [examples/sowa-game/](examples/sowa-game/) (Tests A/B/C, lifecycle and capture lessons).

### Changed

- Cursor rule `unity-mcp-safety.mdc` generalized to **Unity tooling safety** (CLI Direct / CLI MCP / legacy MCP) while keeping the filename for v0.2 compatibility.
- `templates/AGENTS.template.md`, coding/tests and assets/scenes rules updated for capability-based backends and dual UTF routes.
- [docs/validation-strategy.md](docs/validation-strategy.md), [docs/tooling.md](docs/tooling.md), philosophy/roadmap/studio-vs-project/agent docs aligned with the contract.
- README documents optional Unity CLI integration, legacy MCP compatibility, readiness checks, and explicit non-automation boundaries.

### Compatibility

- **Backward compatible with v0.2 projects.** Bootstrap still works without Unity CLI or Pipeline.
- Existing managed files are never silently overwritten (default skip; `--force` remains explicit).
- Bootstrap does **not** install Unity packages or rewrite Cursor MCP configuration.
- Nehokej and WheelDraw require **no** mandatory migration.
- No automatic three-way merge upgrade system in this release; manual adopt via dry-run / selective `--force`.

### Fixed (carried from post-0.2.0 main)

- Bootstrap path safety, exact Git-root identity, and unconfirmed metadata reporting (see prior `fix(bootstrap)` commit on main). Included here so 0.3.0 consumers inherit the hardened bootstrap.

### SOWA pilot learnings encoded

- CLI Direct preferred when capability verified; package-installed ≠ service-reachable.
- `unity test` (CLI `1.0.0-beta.8`) required exclusive project lock — do not auto-close Editors.
- Legacy MCP may not auto-reconnect after Editor close/reopen.
- Scene View captures do not prove Main Camera FOV; CLI capture paths may remap under `Assets/`.
- Tooling smoke tests ≠ gameplay proof; experimental CLI/Pipeline pins are version-sensitive.

### Known limitations

- Capability detector does not probe legacy MCP session reachability (avoids false confidence / config mutation).
- Detector does not execute tests or mutations; `AVAILABLE` for controlled write means backend readiness only.
- CLI command surface may change across versions — re-verify with `unity --help` / detector.
- Framework static self-checks ≠ production readiness; orchestrator not included.

### Deferred

- Headless Game Development Orchestrator (consumes this contract later).
- Shared CI templates and release automation.
- Automatic template three-way merge (`bootstrap --upgrade`).
- Portfolio dashboard / issue-tracker integration.

## [Unreleased]

_(empty after 0.3.0 cut)_

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

- Bootstrap destination checks are TOCTOU-sensitive if another process races path components during install (see bootstrap README).
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
