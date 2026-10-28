# Code workflow findings

**Verification:** Proven on a Unity game pilot (feature stub load + Edit Mode tests). Narrative anonymized for public docs.

## Intent

Prove: feature spec → plan → focused C# → Edit Mode tests → evidence report → human review.

## What worked

- YAML feature contract with allowed/forbidden paths and measurable acceptance.
- Keeping domain logic free of `UnityEngine` enabled Edit Mode UTF without scenes.
- `validate.sh` distinguishing `--self-test` (script only) from real UTF runs.
- BLOCKED exit when Editor lock present — without force-quitting the Editor.
- Structural NUnit XML parse rejecting stale/malformed/empty suites.

## Partial / caveats

- In-Editor Test Runner remains the documented fallback when batchmode is blocked; agents must not claim PASS without recording that path’s results.
- Assembly names and filters are game-specific adapters.

## Extracted into Production OS

- Feature template, QA plan template, portable validate.sh contract, evidence honesty language.
