# Unity MCP findings — GAME-E2E-002

**Verification:** Proven on Nehokej with partial limits (2026-10-27).

## Intent

Prove safe MCP loop: identity → approval → single property mutation → readback → console → Play Mode observe → serialized diff → rollback docs (not auto-run).

## Proven

- Exact canonical Git root == MCP `GetProjectRoot` before mutation.
- Abort/refuse when identity unverifiable (rule exercised as gate; mismatch not forced in pilot).
- Active scene confirmation (`Assets/Scenes/Pitch.unity` in that game).
- Human approval of exact property + before/after values (`Camera.orthographicSize` `8` → `7.5`).
- Property readback after set; console error check; Play Mode camera capture showed pitch content.
- Full Git diff review after Save.
- Incidental YAML serialization detected (`PitchDebugView` fields matching C# defaults written on Save).
- Safe minimization: removed incidental YAML keys only after confirming defaults apply when keys are absent; reload kept scene clean and values correct; did not `git checkout` the whole scene.

## Partial / not claimed

- Edit Mode camera capture showed clear color only (runtime meshes) — zoom before/after not comparable in Edit Mode.
- Drag-aim / input-position interaction **not** exercised via MCP.
- Device play **not** verified.
- MCP tool success ≠ gameplay correctness (explicitly reported).
- Next intentional Save may re-emit default fields — expected Unity behavior.

## Extracted mandatory rules

- Exact path identity; exclusive writers; approval for design-altering edits.
- Full serialized diff inspection; incidental YAML handling; no blind one-line forcing.
- Verification taxonomy: console ≠ visual ≠ interaction.
- MCP optional for Production OS consumers.
