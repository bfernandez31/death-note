# Implementation Summary: Per-kill scoring formula with combo and HUD

**Branch**: `DEATHN-21-per-kill-scoring` | **Date**: 2026-05-16
**Spec**: [spec.md](spec.md)

## Changes Summary

Implemented per-kill scoring system with combo multipliers, HUD display, and floating score popups. Score formula uses name length, vertical position, enemy type (boss 3x multiplier), and combo tier (x1–x5). Combo increments on kills, resets on typing mismatch or wave transition. Score and combo HUD render at top-left with color tiers. "+score" popups animate at kill positions with rise and fade. Score displays on game-over screen and resets on restart. All 18 tests pass including 6 new scoring/combo/popup tests.

## Key Decisions

Used `@as(u64, @intFromFloat(...))` for explicit type annotation required by Zig 0.16 in the score formula. Popup timer update placed outside the `!is_game_over` gate so popups fade naturally during game-over. Combo mismatch detection runs after the full character-input loop per frame, not per-character, matching research decision. `typedMatchesAnyEnemy` test initializes `zombies` array to null to avoid undefined memory access in test context.

## Files Modified

- `src/main.zig` — All scoring logic, combo system, popup pool, HUD rendering, game-over score display, 6 new test blocks
- `specs/DEATHN-21-per-kill-scoring/tasks.md` — All 25 tasks marked complete
- `.gitignore` — Added universal OS patterns

## ⚠️ Manual Requirements

Run `zig build run` and verify: score HUD at top-left, combo color tiers at 5/15, floating popups at kill positions, score on game-over screen, combo resets on mismatch/wave transition, backspace preserves combo.
