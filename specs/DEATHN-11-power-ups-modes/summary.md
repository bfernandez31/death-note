# Implementation Summary: Power-ups, Game Modes & Main Menu

**Branch**: `DEATHN-11-power-ups-modes` | **Date**: 2026-05-17
**Spec**: [spec.md](spec.md)

## Changes Summary

Implemented full feature set across 7 phases (44 tasks): GameScreen enum refactor replacing boolean state flags with switch-based dispatch; main menu with arrow-key navigation and mode selection; pause overlay with resume/quit; power-up system (freeze/bomb/shield) with 10% drop chance, single-slot inventory, Space activation, and carrier zombie pulsing glyph; zen practice mode with WPM-tier selection and no game-over; per-mode high score persistence with independent files/localStorage keys.

## Key Decisions

- Kept single-module architecture per constitution; added helpers (startGame, activatePowerUp, getFallSpeed, updateMenu, drawMenu, etc.) rather than splitting files.
- Power-up carrier designation at spawn time via Zombie.power_up optional field.
- Zen mode derives spawn_delay/fall_speed from target WPM using deriveWaveTiming().
- Per-mode high scores: highscore.zig parameterized with GameMode; survival uses original filenames for backward compatibility.
- Menu displays stats for last_played_mode (survival: score+wave, zen: WPM+accuracy).

## Files Modified

- `src/zombie_types.zig` — Added GameMode, PowerUpType enums, POWER_UP_DROP_CHANCE constant
- `src/highscore.zig` — Parameterized load/save with GameMode, added filename()/webKey() helpers
- `src/main.zig` — GameScreen enum, menu/pause/zen/power-up systems, per-mode scores, 20+ new test blocks
- `specs/DEATHN-11-power-ups-modes/tasks.md` — All 44 tasks marked complete

## Manual Requirements

None
