# Implementation Summary: Bot Mode for Difficulty Validation and Auto-Pilot Watching

**Branch**: `DEATHN-28-bot-mode-for` | **Date**: 2026-05-18
**Spec**: [spec.md](spec.md)

## Changes Summary

Added AI bot mode to Survival gameplay. Bot types zombie names at wave-cadence WPM (target_wpm / 12 chars/sec), targeting the closest-to-bottom zombie with tie-breaking by shortest name then leftmost X. "BOT" menu entry starts bot-controlled Survival session. F2 toggles bot on/off mid-game (Survival only). Bot handles boss phrases including spaces. Session-level bot_tainted flag permanently disables high-score persistence. BOT badge displayed on HUD in CRT_WARN amber. Power-up activation suppressed while bot active. 15 new tests added.

## Key Decisions

All bot logic in src/main.zig per constitution §1 — bot state is deeply coupled to game loop (input buffer, zombie array, wave config, boss state). Bot uses same input buffer injection pattern as human input. selectBotTarget() does a full O(100) zombie array scan per frame (negligible at 60 FPS). startGame() calls resetBotState() then menu re-sets bot_active/bot_tainted after (order matters).

## Files Modified

- `src/main.zig` — Added BOT_REACTION_DELAY constant, 7 bot state variables, resetBotState(), selectBotTarget(), updateBot() functions, menu entry at index 2, F2 toggle handler, HUD badge, high-score gating, input suppression, wave-transition bot state clearing, 15 new test blocks, updated menu wrap-around test
- `specs/DEATHN-28-bot-mode-for/tasks.md` — All 40 tasks marked complete

## Manual Requirements

Verify with `zig build run`: select BOT from menu, watch wave 1 cleared autonomously. Press F2 mid-game to toggle. Confirm BOT badge visible in amber. Confirm no highscore.dat written after bot session. Confirm power-ups not consumed by bot.
