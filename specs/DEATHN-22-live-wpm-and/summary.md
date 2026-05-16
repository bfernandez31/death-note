# Implementation Summary: Live WPM and Accuracy with Character-Based Metrics

**Branch**: `DEATHN-22-live-wpm-and` | **Date**: 2026-05-16
**Spec**: [spec.md](spec.md)

## Changes Summary

Added real-time WPM and accuracy metrics to the game HUD. WPM uses a 512-entry circular buffer with a 10-second sliding window (early-game uses elapsed-time formula). Accuracy tracks cumulative correct/incorrect keypresses. Both values are smoothed per-frame (20% interpolation). Per-keypress classification replaces the old per-frame mismatch check. All metrics reset on game restart.

## Key Decisions

- Moved `typedMatchesAnyEnemy()` inside the key processing loop for per-keypress tracking (FR-001). Combo reset is now per-key instead of per-frame — functionally identical since `combo_count = 0` is idempotent.
- `updateMetrics()` runs every frame where `!is_game_over`, including during wave transitions, so WPM naturally declines during the 3-second countdown.
- Used `@round` + `@intFromFloat` for HUD display to show integer WPM/accuracy values.

## Files Modified

- `src/main.zig` — Added 8 constants, 8 state variables, 6 functions (recordCorrectTimestamp, countCharsInWindow, resetMetricsState, calculateTargetWpm, calculateTargetAccuracy, updateMetrics), WPM/accuracy HUD drawing, per-keypress input classification, reset integration, and 8 new unit tests.
- `specs/DEATHN-22-live-wpm-and/tasks.md` — All 24 automatable tasks marked complete.

## ⚠️ Manual Requirements

T025: Manual play-test required — verify WPM climbs during typing, declines when idle, accuracy drops on wrong keys, metrics freeze on game-over, reset on restart.
