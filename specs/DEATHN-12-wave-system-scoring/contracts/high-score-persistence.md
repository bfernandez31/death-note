# Contract: High Score Persistence

**Feature**: DEATHN-12 | **Date**: 2026-05-16

## Overview

The game persists a single high score value across sessions. Two backends exist: file-based (native) and localStorage (web). Both are optional — the game functions without persistence.

## Native Backend

**File**: `highscore.dat` in the working directory (same directory as `assets/`)

**Format**: 8 bytes, little-endian unsigned 64-bit integer (`u64`). No header, no magic bytes, no versioning.

**Operations**:

| Operation | Behavior | Failure mode |
|---|---|---|
| Load (startup) | Open `highscore.dat`, read 8 bytes, interpret as LE u64 | File missing or < 8 bytes → `best_score = 0`, `best_score_loaded = false` |
| Save (game over, new high) | Create/overwrite `highscore.dat`, write 8 bytes LE u64 | Write fails → log nothing, continue silently (FR-022) |

**Security**:
- File path is a compile-time literal (`HIGHSCORE_FILE`), never derived from runtime input (constitution §Security Practices/4).
- File write is the ONLY file-system write in the game. Justified by FR-021. Constitution §Security Practices/1 requires explicit callout for file writes outside `zig-out/` — `highscore.dat` is written to the working directory, which is the game's own directory.

## Web Backend

**Storage**: `window.localStorage`

**Key**: `"death-note-highscore"`

**Value**: Decimal string representation of the score (e.g., `"12500"`)

**Operations**:

| Operation | Behavior | Failure mode |
|---|---|---|
| Load (startup) | `localStorage.getItem("death-note-highscore")` → parse as integer | Returns null or NaN → `best_score = 0`, `best_score_loaded = false` |
| Save (game over, new high) | `localStorage.setItem("death-note-highscore", score.toString())` | Throws (quota exceeded, disabled) → continue silently (FR-022) |

**Implementation**: Access via `emscripten_run_script_int` (load) and `emscripten_run_script` (save), gated by `comptime builtin.target.os.tag == .emscripten`.
