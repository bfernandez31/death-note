# Implementation Summary: Modes Survie, Arcade et Simulation avec systeme de vies

**Branch**: `DEATHN-29-modes-survie-arcade` | **Date**: 2026-05-19
**Spec**: [spec.md](spec.md)

## Changes Summary

Implemented 4 distinct game modes behind a redesigned 6-item main menu: Survie (hardcore, no power-ups, instant death), Arcade (3-heart lives with power-ups and boss heart restoration), Simulation (renamed Bot with auto-play), and Zen (unchanged). Each mode persists high scores independently. Hearts HUD displays centered at top in Arcade mode with flash feedback on loss/gain.

## Key Decisions

- Hearts are a simple u8 counter, not entities — no allocation needed
- Power-up drop gating changed from .survival to .arcade (single if-condition)
- Shield absorption runs before arcade heart-loss check (preserves shield priority)
- Boss reaching bottom in Arcade costs 1 heart instead of instant death
- Simulation high score save prevented by both switch guard and bot_tainted

## Files Modified

- `src/zombie_types.zig` — Extended GameMode enum with .arcade and .simulation variants
- `src/highscore.zig` — Added per-mode filename/webKey routing for arcade and simulation
- `src/main.zig` — Menu refactor (6 items), hearts system (constants, state, HUD, loss/restore logic), mode-conditional power-ups, per-mode high score save, Bot→Simulation rename, 15+ new tests

## ⚠️ Manual Requirements

Verify with `zig build run`: menu shows 6 items, Survie has no power-ups, Arcade shows 3 hearts with loss/restore, Simulation auto-plays with no "Bot" text, Zen unchanged, cross-mode scores independent.
