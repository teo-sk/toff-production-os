# Code workflow findings — GAME-E2E-001

**Verification:** Proven on Nehokej (challenge JSON stub load + Edit Mode tests).

## Intent

Prove: feature spec → plan → pure C# → Edit Mode tests → evidence report → human review.

## What worked

- YAML feature contract with allowed/forbidden paths and measurable acceptance.
- Keeping domain code free of UnityEngine enabled Edit Mode UTF without scenes.
- `validate.sh` distinguishing `--self-test` (script only) from real UTF runs.
- BLOCKED exit when Editor lock present — without force-quitting the Editor.
- Structural NUnit XML parse rejecting stale/malformed/empty suites.

## Partial / caveats

- In-Editor Test Runner remains the documented fallback when batchmode is blocked; agents must not claim PASS without recording that path’s results.
- Assembly names and filters are game-specific adapters.

## Extracted into Production OS

- Feature template, QA plan template, portable validate.sh contract, evidence honesty language.
