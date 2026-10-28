# Onboarding findings (legacy MCP pilot)

**Verification:** Proven on a Unity game pilot (2026-10). Narrative anonymized for public docs.

## What worked

- A short root `AGENTS.md` oriented agents faster than long chat memory.
- Document ownership table (GDD vs status vs features vs ADRs) reduced silent design rewrites.
- Always-applied Cursor rules for task delivery + Editor tooling safety; scoped rules for architecture/coding/assets.
- Pinning Unity via `ProjectSettings/ProjectVersion.txt` and forbidding silent upgrades.

## Lessons extracted into Production OS

- Framework repo vs game repo `AGENTS.md` are different documents.
- Placeholders for game identity, Unity pin, primary scene, layout.
- Minimal alwaysApply surface; architecture as optional/scoped recommendation.

## Gaps observed

- Agents still need explicit “do not invent project facts” reminders.
- Game-specific hard constraints (e.g. domain purity) must live in the game repo, not the framework.
