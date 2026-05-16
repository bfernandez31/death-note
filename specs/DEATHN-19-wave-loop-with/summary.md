# Implementation Summary: Wave Loop with Per-Wave Difficulty Table

**Branch**: `DEATHN-19-wave-loop-with` | **Date**: 2026-05-16
**Spec**: [spec.md](spec.md)

## Changes Summary

Added wave-based progression system to the zombie typing game. Waves 1-15 follow an explicit difficulty table controlling spawn delay, fall speed, and pool size. Waves 16+ scale endlessly with capped parameters and increasing pool size. 3-second transition countdown between waves freezes gameplay. HUD displays wave number, target WPM, and kill progress. Game-over screen shows wave reached and required WPM. Restart resets to wave 1.

## Key Decisions

All wave logic implemented as module-level globals in `src/main.zig` (consistent with existing state management). Used `std.fmt.bufPrintZ` for null-terminated formatted strings passed to raylib DrawText. Wave completion requires both all spawns AND all kills to prevent premature advancement. Transition countdown uses `@ceil` for display (3, 2, 1).

## Files Modified

- `src/main.zig` — Added WaveConfig struct, WAVE_TABLE (15 entries), WAVE_TRANSITION_DURATION, getWaveConfig() function, wave state variables, spawn gating, kill tracking, wave completion detection, transition countdown, HUD rendering, game-over wave info, restart wave reset, and 4 new unit tests.

## Manual Requirements

T026: Manual integration test — start game, complete wave 1, verify transition, verify wave 2 parameters, let zombie reach bottom, verify game-over info, restart, verify wave 1. Run with `zig build run`.
