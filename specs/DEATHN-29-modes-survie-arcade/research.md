# Research: Modes Survie, Arcade et Simulation avec système de vies

**Branch**: `DEATHN-29-modes-survie-arcade` | **Date**: 2026-05-19

## Existing Files

### Source Files to Modify

| File | Lines | What it covers | Action |
|------|-------|----------------|--------|
| `src/main.zig` | 3745 | Game loop, menus, spawning, drawing, all gameplay logic | Extend — add GameMode variants, hearts system, menu refactor, per-mode high score routing |
| `src/zombie_types.zig` | 92 | `GameMode` enum (`.survival`, `.zen`), `PowerUpType`, spawn/name weight tables | Extend — add `.arcade` and `.simulation` to `GameMode` |
| `src/highscore.zig` | 143 | Per-mode high score persistence (native file + web localStorage) | Extend — add `.arcade` filename/webKey branch, skip `.simulation` |

### Source Files Unchanged

| File | Lines | Reason |
|------|-------|--------|
| `src/name_lists.zig` | ~400 | Name selection unaffected by mode changes |
| `src/boss_phrases.zig` | ~50 | Boss phrases shared across all modes |
| `src/sound_config.zig` | ~80 | Sound config is mode-agnostic |
| `src/raylib.zig` | ~15 | C interop wrapper, no gameplay |
| `src/zombie_names.zig` | ~60 | Legacy name array, not actively used |
| `build.zig` / `build.zig.zon` | — | No build changes needed |

### Test Files to Extend

| File | Test blocks | Action |
|------|-------------|--------|
| `src/main.zig` | 85 existing tests | Extend — add tests for hearts system, per-mode high scores, menu items, power-up gating per mode |
| `src/zombie_types.zig` | 3 existing tests | Extend — update GameMode enum count test (2 → 4) |
| `src/highscore.zig` | 6 existing tests | Extend — add tests for arcade filename/webKey, simulation skipping |

## Patterns to Follow

### Error Handling Pattern
- **File**: `src/main.zig:1662+` (spawnZombieInZone)
- Allocation via `page_allocator.create(Zombie)` uses `catch return false` for non-critical spawn failures.
- `errdefer allocator.destroy(new_zombie)` guards partial allocation (though not actively used since creation is a single step).
- **Apply to**: Heart restoration after boss kill is purely state mutation (no allocation), so no error handling needed. The hearts system has no fallible operations.

### State Reset Pattern
- **File**: `src/main.zig:2032-2041` (resetSessionState)
- All gameplay state grouped into reset functions (`resetSessionState`, `resetScoreState`, `resetMetricsState`, `resetBotState`).
- `startGame()` at line 1293 calls all reset functions in sequence.
- **Apply to**: New heart state variables (`hearts`, related flags) must be reset in `resetSessionState` or a dedicated reset. `startGame()` must initialize hearts based on mode.

### Mode-Conditional Behavior Pattern
- **File**: `src/main.zig:1484-1487` (zen zombie despawn), `src/main.zig:1319` (survival-only starter pack), `src/main.zig:1733` (survival-only power-up drops)
- Mode checks use `if (game_mode == .survival)` / `if (game_mode == .zen)` guards at the branch point.
- **Apply to**: Arcade mode heart-loss logic at line 1502 (where `is_dying = true` currently fires), power-up drop gating at line 1733, starter pack at line 1319.

### High Score Per-Mode Pattern
- **File**: `src/highscore.zig:15-27` (filename/webKey switches)
- Each `GameMode` variant maps to a unique filename and web localStorage key via exhaustive `switch`.
- `src/main.zig:220-221` declares one `highscore.Record` variable per tracked mode.
- `src/main.zig:649-657` saves survival scores; `src/main.zig:1278-1291` saves zen scores.
- **Apply to**: Add `best_score_arcade: highscore.Record` variable. Add `.arcade` and `.simulation` arms to `filename()`/`webKey()` switches. Simulation returns a sentinel or is guarded upstream (bot_tainted already prevents saves).

### Menu Item Pattern
- **File**: `src/main.zig:808-853` (MENU_ITEMS array + updateMenu switch)
- Menu items are a compile-time `[_][]const u8` array. Selection index maps to a switch case.
- **Apply to**: Expand to 6 items: `{ "SURVIE", "ARCADE", "SIMULATION", "ZEN", "SOUND", "QUIT" }`. Update `MENU_ITEM_COUNT` and all switch cases.

### Drawing / HUD Pattern
- **File**: `src/main.zig:800-806` (drawPlayingHud)
- HUD elements draw after the CRT overlay in the playing state. Position constants declared at file scope.
- All text through `drawText()` / `drawCenteredText()` wrappers.
- Colors from `CRT_*` constants only.
- **Apply to**: Hearts display in Arcade mode. Use `CRT_ERR` for filled hearts (matches the red/danger theme), `CRT_DIM` for empty heart slots.

### Bot Mode Activation Pattern
- **File**: `src/main.zig:829-840` (menu Bot entry)
- Bot starts as survival game, then overlays `bot_active = true` + `bot_tainted = true` + reaction timer setup.
- **Apply to**: Simulation menu entry should follow the same pattern (it IS the same code, just renamed).

## Decisions

### D-1: GameMode Enum Extension Strategy
- **Decision**: Add `.arcade` and `.simulation` to the existing `GameMode` enum in `zombie_types.zig`.
- **Rationale**: The enum is already used for mode-conditional branching throughout `main.zig` and `highscore.zig`. Adding variants forces the compiler to catch every unhandled switch via Zig's exhaustive-switch semantics, ensuring nothing is missed.
- **Alternatives considered**: Using a separate `is_arcade` boolean — rejected because it creates parallel state that can drift out of sync with `game_mode`.

### D-2: Hearts as Simple Counter (not entities)
- **Decision**: Hearts are an integer counter (`hearts: u8 = 0`), not a fixed-pool entity array.
- **Rationale**: Hearts have no individual state (position, animation, type). They are a quantity consumed/restored by 1. Drawing uses a loop over `0..MAX_HEARTS` comparing against the counter.
- **Alternatives considered**: Struct array with per-heart animation state — rejected as overengineering for 3 hearts with no individual behavior.

### D-3: Per-Mode High Score Routing
- **Decision**: Add `best_score_arcade: highscore.Record` alongside existing `best_score_survival`/`best_score_zen`. Route save/load via mode. Simulation mode never saves (guarded by `game_mode != .simulation` check, complementing existing `bot_tainted` guard).
- **Rationale**: Follows established pattern in `highscore.zig` and `main.zig:649-657`. The existing infrastructure already handles per-mode files cleanly.
- **Alternatives considered**: Single high-score record with mode tag — rejected because it requires a migration of the existing binary format and breaks the simple file-per-mode approach.

### D-4: Power-Up Gating by Mode
- **Decision**: Change the power-up drop check at `main.zig:1733` from `if (game_mode == .survival)` to `if (game_mode == .arcade)`. Survie (which replaces the old survival default) explicitly has no power-ups per FR-004. Arcade gets the full power-up system per FR-011.
- **Rationale**: The spec is explicit: Survie = no powers, Arcade = current powers. The existing drop chance (10%) and all three types (freeze/bomb/shield) transfer to Arcade unchanged.
- **Alternatives considered**: A `mode_has_power_ups()` function — acceptable but unnecessary for a single `if` check at one callsite.

### D-5: Heart Loss Replaces Death in Arcade
- **Decision**: At the zombie-reaches-bottom branch (`main.zig:1502`), Arcade mode decrements `hearts` and destroys the zombie instead of setting `is_dying`. When `hearts` reaches 0, the existing `is_dying` path fires. A brief visual flash (not a full pause) acknowledges the heart loss.
- **Rationale**: ARD-2 specifies "brief interruption." A full 1-second dying pause per heart loss would be punishing. A 0.3s screen flash + sound effect conveys the hit without breaking flow. The final death at 0 hearts still uses the full dying sequence.
- **Alternatives considered**: Full dying pause per heart — rejected per spec note "too long an interruption could feel punishing on repeated hits."

### D-6: Simulation = Renamed Bot (No Logic Changes)
- **Decision**: The menu item "BOT" becomes "SIMULATION". The `GameMode.simulation` variant internally uses the exact same code paths as the current bot activation (survival mode + `bot_active = true`). No gameplay logic changes.
- **Rationale**: ARD-3 is explicit: "pure rename of Bot mode. All current bot behaviors are preserved exactly."
- **Alternatives considered**: None needed — this is a rename.

### D-7: Starter Pack for Arcade
- **Decision**: Arcade mode uses the same `spawnStarterPack` call as Survival/Survie. The existing `if (mode == .survival)` guard expands to include `.arcade`.
- **Rationale**: FR-006 requires "exact same wave configuration as Survie" for Arcade. The starter pack is part of wave configuration.
- **Alternatives considered**: None — spec is clear.

### D-8: Heart Visual/Audio Feedback
- **Decision**: Heart loss plays the existing `sounds/damage/1.wav` sound effect (reuses damage sound pack). Heart gain on boss defeat plays `sounds/shield/1.wav` (reuses shield sound). A brief red screen flash (0.2s fade) accompanies heart loss. Hearts are drawn as ASCII `[♥]` / `[·]` using `drawText()` in the HUD area.
- **Rationale**: Reuse existing sound assets. ASCII heart glyphs match the CRT aesthetic. Positioning in the HUD area (top-center or below score) keeps them always visible per FR-015.
- **Alternatives considered**: Custom heart sprite asset — rejected to avoid asset creation scope creep; ASCII with CRT colors is on-brand.

### D-9: Menu High Score Display per Mode
- **Decision**: The menu bottom-line high score display (`main.zig:872-878`) shows the score for `last_played_mode`. With 4 modes, this naturally shows the last-played mode's score. Add mode label prefix (e.g., "SURVIE BEST:" / "ARCADE BEST:") for clarity.
- **Rationale**: Follows existing pattern. The user sees the score relevant to what they last played.
- **Alternatives considered**: Show all 3 scores — rejected, too cluttered for the menu.
