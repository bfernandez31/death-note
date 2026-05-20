# Implementation Plan: Modes Survie, Arcade et Simulation avec système de vies

**Branch**: `DEATHN-29-modes-survie-arcade` | **Date**: 2026-05-19 | **Spec**: `specs/DEATHN-29-modes-survie-arcade/spec.md`
**Input**: Feature specification from `specs/DEATHN-29-modes-survie-arcade/spec.md`

## Summary

Add four distinct game modes (Survie, Arcade, Simulation, Zen) behind a redesigned main menu. Survie is the current survival mode stripped of power-ups (hardcore). Arcade adds a 3-heart lives system with power-ups and boss-triggered heart restoration. Simulation is a rename of Bot mode. Each playable mode stores high scores independently. The primary technical changes touch `zombie_types.zig` (enum extension), `highscore.zig` (per-mode persistence), and `main.zig` (menu, hearts system, mode-conditional branches).

## Technical Context

**Language/Version**: Zig (toolchain-pinned, ~0.16+)
**Primary Dependencies**: raylib (pinned commit `52f2a10d`)
**Storage**: Binary files (`highscore.dat`, `highscore-arcade.dat`, `highscore-zen.dat`) on native; `localStorage` on web/Emscripten
**Testing**: `zig build test` (built-in test runner)
**Target Platform**: Native (Linux/macOS/Windows 800×1000 window) + WASM/Emscripten
**Project Type**: Single-module game (3745-line `src/main.zig` + sibling modules)
**Performance Goals**: 60 FPS, no frame drops during heart flash or menu transitions
**Constraints**: No new external dependencies; no new asset files (reuse existing sounds); no `@cImport` outside `raylib.zig`
**Scale/Scope**: ~200-300 lines of new code, ~50-80 lines of modified code across 3 files

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Rule | Status | Notes |
|---|------|--------|-------|
| CP-1 | Single-module game loop | PASS | All gameplay changes stay in `main.zig`. No new modules introduced — hearts state and mode-conditional logic extend the existing update/draw structure. |
| CP-2 | C interop walled in `raylib.zig` | PASS | No new C interop needed. |
| CP-3 | Named constants for tunables | PASS | `MAX_HEARTS`, `HEART_LOSS_FLASH_DURATION`, etc. declared at file scope. |
| CP-4 | Paired Init/defer Close | PASS | No new resources loaded. Existing texture/sound assets reused. |
| CP-5 | Optional pointers via `if (x) \|val\|` | PASS | No new optional pointer types introduced. |
| CP-6 | Allocator passed by parameter | PASS | No new allocation sites. Hearts are stack variables (u8 counter). |
| CP-7 | Fixed-size pools, init to known state | PASS | No new pools. `hearts` is a scalar initialized to 0/MAX_HEARTS in `startGame()`. |
| TS-1 | Zig built-in test runner | PASS | All new tests in `test "..."` blocks within existing files. |
| TS-2 | Tests in module under test | PASS | Hearts tests in `main.zig`, GameMode tests in `zombie_types.zig`, highscore tests in `highscore.zig`. |
| TS-3 | Pure logic coverage | PASS | Heart decrement, cap logic, mode-conditional branching, high score routing — all pure logic, all testable. |
| TS-6 | Tests exercise production code | PASS | All planned tests call production functions/check production state. |
| SP-1 | No secrets, no network | PASS | No new I/O beyond the new `highscore-arcade.dat` file (follows existing persistence pattern). |
| SP-4 | Asset paths are literals | PASS | No new asset loads. |
| CQ-3 | Naming discipline | PASS | `hearts` (snake_case), `MAX_HEARTS` (SCREAMING), `resetHeartState` (camelCase), `GameMode` (PascalCase). |
| GA-5 | Agent authority | PASS | No dependency changes, no network, no `defer` removal. |

**Post-Phase-1 re-check**: All gates still pass. The data model introduces no new complexity patterns — hearts are a simple counter, mode gating uses existing `if/switch` idioms, high score extension follows the established file-per-mode pattern.

## Project Structure

### Documentation (this feature)

```
specs/DEATHN-29-modes-survie-arcade/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── checklists/
│   └── requirements.md  # Pre-existing
└── tasks.md             # Phase 2 output (not created by /plan)
```

### Source Code (repository root)

```
src/
├── main.zig           # Hearts system, menu refactor, mode-conditional branches, HUD, tests
├── zombie_types.zig   # GameMode enum extension (.arcade, .simulation), updated tests
├── highscore.zig      # .arcade/.simulation filename/webKey routing, updated tests
├── name_lists.zig     # Unchanged
├── boss_phrases.zig   # Unchanged
├── sound_config.zig   # Unchanged
├── raylib.zig         # Unchanged
└── zombie_names.zig   # Unchanged
```

**Structure Decision**: No new files. All changes extend existing modules. This follows constitution CP-1 (single-module game loop) — the hearts system is gameplay state that belongs in `main.zig`, and the enum/persistence changes are minimal extensions to their respective sibling modules.

## Complexity Tracking

*No constitution violations. No complexity justification needed.*

## Implementation Phases

### Phase 1: GameMode Enum Extension (`zombie_types.zig`)

**Goal**: Extend `GameMode` with `.arcade` and `.simulation` variants. This intentionally breaks all exhaustive switches in `main.zig` and `highscore.zig`, creating a compiler-enforced checklist of every callsite that must handle the new modes.

**Changes**:
1. Add `.arcade` and `.simulation` to `pub const GameMode = enum { ... }` at `zombie_types.zig:15-18`
2. Update test `"GameMode enum has 2 variants"` at `zombie_types.zig:84` to expect 4 variants

**Verification**: `zig build test` will fail with exhaustive-switch errors in `main.zig` and `highscore.zig` — that is expected and intentional. The errors enumerate every callsite to update.

### Phase 2: High Score Persistence (`highscore.zig`)

**Goal**: Route Arcade high scores to their own file. Handle `.simulation` (never saves).

**Changes**:
1. `filename()` at `highscore.zig:15-19`: add `.arcade => "highscore-arcade.dat"`, `.simulation => "highscore.dat"` (sentinel — never actually called due to upstream guard)
2. `webKey()` at `highscore.zig:22-27`: add `.arcade => "death-note.highscore.arcade"`, `.simulation => "death-note.highscore"` (sentinel)
3. Add `best_score_arcade: highscore.Record = .{}` in `main.zig` alongside existing vars (line ~221)
4. Add `best_score_arcade = highscore.load(.arcade)` in `main.zig` initialization (line ~1436)

**New tests** (`highscore.zig`):
- `"filename arcade returns highscore-arcade.dat"`
- `"webKey arcade returns death-note.highscore.arcade"`

### Phase 3: Menu Refactor (`main.zig`)

**Goal**: Redesign menu from 5 items (SURVIVAL, ZEN, BOT, SOUND, QUIT) to 6 items (SURVIE, ARCADE, SIMULATION, ZEN, SOUND, QUIT).

**Changes**:
1. `MENU_ITEMS` at line 808: `{ "SURVIE", "ARCADE", "SIMULATION", "ZEN", "SOUND", "QUIT" }`
2. `MENU_ITEM_COUNT` at line 809: `6`
3. `updateMenu()` switch at lines 820-852:
   - Index 0 (SURVIE): `startGame(.survival, allocator)` — identical to current index 0
   - Index 1 (ARCADE): `startGame(.arcade, allocator)` — new
   - Index 2 (SIMULATION): current bot activation code (lines 829-840) with `startGame(.simulation, allocator)` instead of `.survival`
   - Index 3 (ZEN): current zen flow (unchanged, shifted from index 1)
   - Index 4 (SOUND): current sound flow (shifted from index 3)
   - Index 5 (QUIT): current quit flow (shifted from index 4)
4. `drawMenu()` high score line (lines 872-878): add mode label prefix and handle arcade mode display

**New tests**:
- `"menu has 6 items"` — verify MENU_ITEMS.len and MENU_ITEM_COUNT
- `"menu item labels are SURVIE ARCADE SIMULATION ZEN SOUND QUIT"` — verify exact labels
- Update existing test `"menu has 5 items with BOT at index 2"` → `"menu has 6 items with SIMULATION at index 2"`

### Phase 4: Hearts System (`main.zig`)

**Goal**: Implement the 3-heart lives system for Arcade mode.

**New state variables** (file scope, near line 227):
```zig
const MAX_HEARTS: u8 = 3;
const HEART_LOSS_FLASH_DURATION: f32 = 0.2;
const HEART_RESTORE_FLASH_DURATION: f32 = 0.3;
var hearts: u8 = 0;
var heart_flash_timer: f32 = 0.0;
var heart_flash_is_loss: bool = false;
```

**Initialization** in `startGame()` (line ~1293):
```zig
hearts = if (mode == .arcade) MAX_HEARTS else 0;
heart_flash_timer = 0.0;
```

**Reset** in `resetSessionState()` (line ~2032):
```zig
hearts = 0;
heart_flash_timer = 0.0;
heart_flash_is_loss = false;
```

**Heart loss** — modify `updateZombies()` at line 1502 (where `is_dying` is currently set):
```zig
// Before the is_dying block, add arcade heart loss:
if (game_mode == .arcade) {
    hearts -= 1;
    heart_flash_timer = HEART_LOSS_FLASH_DURATION;
    heart_flash_is_loss = true;
    playDamageSound();  // reuse existing damage sound
    allocator.destroy(zomb);
    slot.* = null;
    wave_kills += 1;
    total_kills += 1;
    if (hearts == 0) {
        is_dying = true;
        dying_timer = DYING_DURATION;
        dying_zombie_index = null;  // no specific zombie to tint
        break;
    }
    continue;
}
// Existing survival death code follows unchanged
```

**Heart restore** — modify boss kill logic (line ~1864-1879 in `updateBoss`):
```zig
// After boss defeat scoring, before spawn_timer reset:
if (game_mode == .arcade and hearts < MAX_HEARTS) {
    hearts += 1;
    heart_flash_timer = HEART_RESTORE_FLASH_DURATION;
    heart_flash_is_loss = false;
    playShieldSound();  // reuse existing shield sound
}
```

**Heart flash timer** — in the playing update phase (near line 662):
```zig
if (heart_flash_timer > 0) {
    heart_flash_timer -= raylib.GetFrameTime();
    if (heart_flash_timer < 0) heart_flash_timer = 0.0;
}
```

**New tests**:
- `"hearts start at MAX_HEARTS in arcade mode"` — verify `startGame(.arcade, ...)` sets hearts = 3
- `"hearts start at 0 in survival mode"` — verify non-arcade modes have 0 hearts
- `"heart loss decrements hearts"` — unit test the decrement + game-over at 0 logic
- `"heart restore caps at MAX_HEARTS"` — verify increment never exceeds 3
- `"MAX_HEARTS is 3"` — constant verification

### Phase 5: Mode-Conditional Behavior (`main.zig`)

**Goal**: Wire mode-specific behavior for Survie, Arcade, and Simulation.

**Power-up drops** — `spawnZombieInZone()` at line 1733:
- Change `if (game_mode == .survival)` to `if (game_mode == .arcade)`
- This makes Survie (`.survival`) power-free and gives Arcade the drops

**Starter pack** — `startGame()` at line 1319 and wave transition at line ~636:
- Change `if (mode == .survival)` to `if (mode == .survival or mode == .arcade or mode == .simulation)`
- All wave-based modes get the starter pack

**Zombie reaches bottom** — already handled in Phase 4 (arcade branch added before survival death)

**Zen despawn** — line 1484: unchanged, `.zen` check remains

**Simulation bot activation** — already handled in Phase 3 (menu index 2)

**F2 bot toggle** — the existing F2 toggle path (line ~499-520) works in all modes. `bot_tainted` prevents score saves. No changes needed.

**Game-over high score save** — dying timer expiry at line 649:
- Currently saves only for survival. Extend to route by mode:
  - `.survival`: existing `best_score_survival` logic
  - `.arcade`: new `best_score_arcade` logic (compare score, save if better)
  - `.simulation`: skip (bot_tainted already guards, but add explicit mode check)
  - `.zen`: already handled by `saveZenScoreIfBest()` elsewhere

**Menu high score display** — `drawMenu()` at line 873:
- Extend `last_played_mode` switch to include `.arcade` (shows arcade best score) and `.simulation` (shows nothing or survival score)

**New tests**:
- `"power-ups drop only in arcade mode"` — verify drop chance condition
- `"survie mode has no power-up drops"` — verify survival mode check
- `"simulation mode sets bot_tainted"` — verify bot activation path

### Phase 6: Hearts HUD Drawing (`main.zig`)

**Goal**: Display heart indicators in Arcade mode during gameplay.

**New constants** (file scope):
```zig
const HEART_HUD_Y: c_int = 5;
const HEART_HUD_SIZE: c_int = 22;
const HEART_SPACING: c_int = 30;
```

**New function** `drawHeartsHud()`:
- Only draws when `game_mode == .arcade`
- Centers hearts horizontally at top of screen
- Filled hearts: `CRT_ERR` colored text (e.g., `"<3"` or a filled symbol)
- Empty hearts: `CRT_DIM` colored text
- During `heart_flash_timer > 0`: pulse effect (alternate tint between flash color and normal)

**Integration**: Call `drawHeartsHud()` from `drawPlayingHud()` (line ~802).

**Game-over screen** — extend the stats display (lines 785-791) to show final hearts info for Arcade, and show mode-specific high score.

**Manual Requirements** (for reviewer verification):
- Launch game, select Arcade: 3 hearts visible at top
- Let zombie reach bottom: heart decreases, brief red flash
- Defeat boss: heart increases (if below 3), brief accent flash
- Lose all 3 hearts: game over triggers with full dying sequence
- Select Survie: no hearts displayed
- Verify hearts update within the same frame as the event (FR-015)

### Phase 7: Cleanup and Polish

**Goal**: Ensure all "Bot" references are replaced and edge cases are handled.

1. **Text rename**: Search all string literals for "BOT" / "Bot" / "bot" and replace with "SIMULATION" / "Simulation" / "simulation" per FR-002, SC-005
2. **Multiple zombies same frame** (Edge Case): In `updateZombies()`, the Arcade heart-loss path uses `continue` (not `break`), so multiple zombies reaching bottom on the same frame each cost 1 heart independently. If hearts reach 0 mid-loop, `break` fires immediately.
3. **Boss active + zombie reaches bottom** (Edge Case): The arcade heart-loss path destroys the zombie and continues — boss encounter is unaffected since boss lives in `boss` variable, not the zombie pool.
4. **Shield + Arcade** (Edge Case): Shield absorption at line 1492 runs before the arcade heart-loss check, so shield takes priority per FR-018.
5. **Input buffer on heart loss** (Edge Case): The arcade path does NOT clear `letter_count` or `name` — input is preserved per spec edge case.

**New tests**:
- `"no BOT string literals remain"` — compile-time or test that MENU_ITEMS doesn't contain "BOT"
- `"shield absorbs before heart loss in arcade"` — verify ordering

## Testing Strategy

### Unit Tests (extend existing test blocks)

| Module | New Tests | What They Cover |
|--------|-----------|-----------------|
| `zombie_types.zig` | 1 | GameMode enum count (4 variants) |
| `highscore.zig` | 2 | Arcade filename + webKey |
| `main.zig` | ~15 | Hearts init/decrement/cap, menu items, mode-conditional power-ups, bot_tainted, mode-specific high scores |

### Manual Testing (via `zig build run`)

1. **Menu navigation**: All 6 items selectable, correct modes launch
2. **Survie mode**: No power-ups drop, single death = game over, high score saves to survival file
3. **Arcade mode**: Hearts display, power-ups drop, heart loss on zombie reach, heart restore on boss defeat, game over at 0 hearts, arcade high score saves separately
4. **Simulation mode**: Bot auto-plays, "BOT" text absent everywhere, no high score saved
5. **Zen mode**: Unchanged behavior
6. **Cross-mode scores**: Achieve high scores in Survie and Arcade, verify they don't cross-contaminate
7. **Edge cases**: Multiple zombies hitting bottom same frame in Arcade, shield absorption in Arcade, boss + heart loss
