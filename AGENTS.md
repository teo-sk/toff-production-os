# AGENTS.md — TOFF Games Production OS (studio repo)

Portable instructions for agents maintaining **this** framework repository (`toff-production-os`), not an individual game.

## Identity

- **Repo:** TOFF Games Production OS  
- **Purpose:** Game-agnostic process, templates, bootstrap, and validation patterns for Unity games  
- **Version:** see [VERSION](VERSION)  
- **Consumers:** Nehokej, WheelDraw, SOWA Game, Zuma Roguelike, Fishpond Hockey, future titles  

This repository contains **no Unity project**. Do not invent game mechanics, scenes, or package pins here.

## Document ownership

| Doc | Authority |
|---|---|
| [docs/philosophy.md](docs/philosophy.md) | Studio process principles |
| [docs/production-pipeline.md](docs/production-pipeline.md) | Lifecycle / stage gates |
| [docs/studio-vs-project.md](docs/studio-vs-project.md) | Boundary between OS and games |
| [docs/unity-tooling.md](docs/unity-tooling.md) | Unity tooling contract, backends, safety, evidence |
| [templates/](templates/) | Installable defaults for game repos |
| [examples/](examples/) | Pilot evidence (reference only) |
| [CHANGELOG.md](CHANGELOG.md) | Released framework changes |

Agents **may** update factual docs after verified framework changes.  
Agents **must not** rewrite philosophy or safety rules to match a single game’s shortcuts without human approval.

## Hard constraints

1. Keep the framework **game-agnostic** — no hardcoded game namespaces, absolute machine paths, or mandatory folder layouts like a single title’s `Assets/Domains`.  
2. Separate **mandatory process** from **optional architecture recommendations**.  
3. Do not create Git remotes, commits, pushes, or GitHub repos unless a human explicitly asks.  
4. Do not bootstrap or mutate consumer game repositories unless the task explicitly names a target path.  
5. Do not claim capabilities as “proven” unless examples document verification level (proven / partial / proposed).  
6. Prefer small shell scripts and Markdown over complex orchestration.

## Task lifecycle (framework work)

1. **Understand** — which consumers are affected; version impact.  
2. **Plan** — list template/docs/script files; note breaking changes for bootstrap.  
3. **Implement** — focused diff; keep templates placeholder-driven.  
4. **Validate** — link checks, MDC frontmatter, `bash -n`, bootstrap `--help` / `--dry-run` on a disposable fixture (never a silent write to a live game), capability-detect + bootstrap test suites when those scripts change.  
5. **Review** — update CHANGELOG + VERSION when releasing; human approval for safety-rule changes.  
6. **Do not** mutate consumer games (Nehokej, WheelDraw, SOWA, …) unless the task explicitly names a target path.

## Git safety

- Never update git config.  
- Never force-push `main`.  
- Never commit unless the human asks.  
- Never amend pushed history.  
- Do not use interactive git flags (`-i`).

## Definition of Done (framework)

- [ ] Acceptance criteria met or exceptions listed  
- [ ] Templates remain free of accidental game-specific absolute paths  
- [ ] Shell scripts pass `bash -n`; bootstrap `--help` works  
- [ ] Docs links checked for new/changed files  
- [ ] CHANGELOG / VERSION updated when releasing  
- [ ] Completion report includes verification actually performed  

## Task completion report

- Summary of changes (paths)  
- Acceptance: met / not met / deferred  
- Validation: commands + results (do not invent)  
- Consumer impact / migration notes  
- Human approvals still needed  
