# Feature Specification: Wave Loop with Per-Wave Difficulty Table

**Feature Branch**: `DEATHN-19-wave-loop-with`
**Created**: 2026-05-16
**Status**: Draft
**Input**: User description: "Wave loop with explicit per-wave difficulty table"

## Auto-Resolved Decisions

- **Decision**: Truncated acceptance criteria completed from difficulty table data
- **Policy Applied**: CONSERVATIVE
- **Confidence**: High (0.9) — values are directly derivable from the provided table
- **Fallback Triggered?**: No
- **Trade-offs**: None; the table is unambiguous and the truncated text is clearly mid-word
- **Reviewer Notes**: Verify wave 5 pool_size=13, wave 20 pool_size=43 match design intent

---

- **Decision**: Input disabled during wave transition pause
- **Policy Applied**: CONSERVATIVE (AUTO fallback due to low confidence)
- **Confidence**: Low (0.3) — ticket does not specify whether typing is accepted during countdown
- **Fallback Triggered?**: Yes — AUTO promoted to CONSERVATIVE; safest default is to ignore keystrokes when no zombies are active
- **Trade-offs**: Players cannot pre-type during countdown; simpler state management during transition
- **Reviewer Notes**: Confirm that disabling input during the 3-second countdown is acceptable UX

---

- **Decision**: Existing game-over screen text replaced with wave-specific information
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Medium (0.6) — ticket explicitly defines new game-over text; implies replacement of current generic text
- **Fallback Triggered?**: No
- **Trade-offs**: Previous "GAME OVER / Press ENTER to Restart" text is superseded; wave and WPM info added
- **Reviewer Notes**: Verify the "Press ENTER to Restart" prompt is still desired alongside the new wave/WPM lines

---

- **Decision**: No persistent cross-wave score tracking beyond the HUD kill counter
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Medium (0.6) — ticket defines only wave-local kill count (killed/pool_size); no mention of cumulative score
- **Fallback Triggered?**: No
- **Trade-offs**: No overall score or leaderboard; keeps scope minimal and aligned with ticket
- **Reviewer Notes**: If cumulative scoring is desired, it should be specified in a follow-up ticket

## User Scenarios & Testing

### User Story 1 - Progressive Wave Gameplay (Priority: P1)

A player starts the game and faces wave 1 with 5 slow zombies. After typing all 5 names correctly, a 3-second countdown announces wave 2. Each subsequent wave increases zombie count, spawn rate, and fall speed according to the difficulty table. The player progresses through waves until a zombie reaches the bottom.

**Why this priority**: Core gameplay loop — without waves, the game has no progression or challenge curve.

**Independent Test**: Start the game, type all 5 zombie names in wave 1, verify the transition countdown appears, then verify wave 2 spawns 7 zombies at faster settings.

**Acceptance Scenarios**:

1. **Given** the game starts, **When** the first frame renders, **Then** the game is in wave 1 with spawn_delay=4.80s, fall_speed=0.5, and pool_size=5
2. **Given** wave 1 is active, **When** the player types and matches all 5 zombie names, **Then** a 3-second countdown screen appears showing "WAVE 2 — 18 WPM challenge — 3... 2... 1..."
3. **Given** the countdown finishes, **When** wave 2 begins, **Then** zombies spawn with spawn_delay=4.00s, fall_speed=0.6, and pool_size=7

---

### User Story 2 - HUD Displays Wave Progress (Priority: P1)

While playing, the player sees a centered HUD at the top of the screen showing the current wave number, target WPM, and kill progress (e.g., "WAVE 5 — 30 WPM — 7 / 13"). The kill counter updates in real time as the player eliminates zombies.

**Why this priority**: Essential feedback — the player needs to know their progress within a wave to stay engaged.

**Independent Test**: During any wave, kill a zombie and verify the HUD counter increments by 1. Verify the HUD text is centered at y=10 with font size 20.

**Acceptance Scenarios**:

1. **Given** wave 5 is active and the player has killed 7 of 13 zombies, **When** the frame renders, **Then** the HUD displays "WAVE 5 — 30 WPM — 7 / 13" centered at y=10 in font size 20 with DARKGRAY color
2. **Given** wave 5 is active and the player kills zombie 8, **When** the kill registers, **Then** the HUD updates to "WAVE 5 — 30 WPM — 8 / 13"

---

### User Story 3 - Game Over with Wave Info (Priority: P2)

When a zombie reaches the bottom of the screen, the game ends. The game-over screen shows which wave the player reached and the target WPM of that wave. Pressing ENTER restarts from wave 1.

**Why this priority**: Provides meaningful feedback on how far the player got and resets cleanly to wave 1.

**Independent Test**: Let a zombie reach the bottom during wave 3, verify the game-over screen shows "Wave reached: 3" and "Required WPM: 22". Press ENTER and verify the game restarts at wave 1.

**Acceptance Scenarios**:

1. **Given** the player is on wave 7, **When** a zombie reaches the bottom, **Then** the game-over screen displays "Wave reached: 7" and "Required WPM: 40"
2. **Given** the game-over screen is displayed, **When** the player presses ENTER, **Then** the game restarts at wave 1 with all wave state reset

---

### User Story 4 - Wave Transition Freeze (Priority: P2)

Between waves, a 3-second automatic countdown plays. During this countdown, no zombies spawn, no existing zombies move, and input is ignored. The countdown displays the next wave number and its target WPM.

**Why this priority**: Gives the player a brief rest between waves and builds anticipation for the next challenge level.

**Independent Test**: Complete wave 1, verify no zombies spawn or move during the countdown, and verify the countdown decrements visually from 3 to 1 before wave 2 starts.

**Acceptance Scenarios**:

1. **Given** the player just killed the last zombie of wave 1, **When** the transition begins, **Then** the screen shows "WAVE 2 — 18 WPM challenge — 3... 2... 1..." with the countdown decrementing each second
2. **Given** the transition countdown is active, **When** the 3 seconds elapse, **Then** wave 2 begins automatically with no player input required

---

### User Story 5 - Zombie Accumulation Under Pressure (Priority: P2)

If the player cannot type fast enough, zombies accumulate on screen without any cap on simultaneous active zombies. The game only ends when a zombie touches the ground — not when a spawn limit is reached.

**Why this priority**: Creates natural difficulty pressure and ensures the game-over condition is always a zombie reaching the bottom.

**Independent Test**: Start a wave and do not type anything. Verify that zombies keep spawning and falling until one reaches the bottom and triggers game over.

**Acceptance Scenarios**:

1. **Given** wave 3 is active with pool_size=9, **When** the player does not type any names, **Then** all 9 zombies spawn and fall simultaneously until one reaches the bottom
2. **Given** multiple zombies are on screen, **When** one zombie's y-position reaches the screen height, **Then** game over triggers immediately regardless of how many zombies remain

---

### User Story 6 - Endless Scaling Beyond Wave 15 (Priority: P3)

After wave 15, all subsequent waves use the same WPM, spawn delay, and fall speed as wave 15+ (target_wpm=110, spawn_delay=0.66s, fall_speed=2.0) but increase pool_size by 2 per wave beyond 15.

**Why this priority**: Ensures the game has no hard end and becomes an endurance test for advanced players.

**Independent Test**: Reach wave 16 and verify pool_size=35, then wave 17 with pool_size=37. Verify spawn_delay and fall_speed remain at 0.66s and 2.0 respectively.

**Acceptance Scenarios**:

1. **Given** the player reaches wave 16, **When** the wave begins, **Then** target_wpm=110, spawn_delay=0.66s, fall_speed=2.0, and pool_size=35
2. **Given** the player reaches wave 20, **When** the wave begins, **Then** pool_size=43 (33 + 2*(20-15))

---

### Edge Cases

- What happens if the zombie pool array (MAX_ZOMBIES=100) is full when a new wave zombie needs to spawn? Spawning waits for a slot to free up; the spawn timer stays hot (existing behavior).
- What happens if the player kills zombies faster than they spawn? The wave completes when all pool_size zombies have been both spawned and killed; early kills do not skip remaining spawns.
- What happens if a wave's pool_size exceeds MAX_ZOMBIES? For wave 48+ (pool_size > 99), zombies queue behind the 100-slot limit; the wave completes only when all have been spawned and killed.
- What happens during the countdown if the window loses focus? The countdown timer pauses with the frame loop (raylib's default behavior when FPS target is set).

## Requirements

### Functional Requirements

- **FR-001**: The game MUST start at wave 1 with the difficulty parameters defined in the wave table (target_wpm=15, spawn_delay=4.80s, fall_speed=0.5, pool_size=5)
- **FR-002**: Each wave MUST have a finite pool of zombies to spawn, determined by the difficulty table's pool_size column
- **FR-003**: Zombies within a wave MUST spawn at regular intervals determined by the wave's spawn_delay value
- **FR-004**: All zombies within a wave MUST fall at the wave's defined fall_speed
- **FR-005**: A wave MUST be considered complete only when all zombies in the pool have been spawned AND killed by the player
- **FR-006**: Upon wave completion, the game MUST display a 3-second transition screen showing the next wave number, its target WPM, and a descending countdown (3, 2, 1)
- **FR-007**: During the wave transition, no zombies MUST spawn and no existing zombies MUST move
- **FR-008**: The wave transition MUST advance automatically after 3 seconds without requiring player input
- **FR-009**: The game MUST display a HUD at the top center of the screen showing: wave number, target WPM, and kill progress (killed / pool_size), using font size 20, DARKGRAY color, at y=10
- **FR-010**: The HUD kill counter MUST update in real time as the player eliminates zombies
- **FR-011**: When a zombie reaches the bottom of the screen, the game MUST immediately trigger game over
- **FR-012**: The game-over screen MUST display the wave number reached and the required WPM for that wave
- **FR-013**: Pressing ENTER on the game-over screen MUST restart the game from wave 1 with all state reset
- **FR-014**: There MUST be no cap on the number of simultaneously active zombies beyond the existing MAX_ZOMBIES slot array
- **FR-015**: For waves 16 and beyond, the game MUST use target_wpm=110, spawn_delay=0.66s, fall_speed=2.0, and pool_size=33+2*(wave-15)
- **FR-016**: The spawn_delay formula MUST be derived from: (avg_chars_per_zombie x 60) / (target_wpm x 5), with avg_chars_per_zombie=6
- **FR-017**: The existing fixed spawn_delay constant (3.0s) and fixed fall speed (0.5) MUST be replaced by wave-dependent values from the difficulty table

### Key Entities

- **Wave**: Represents a round of gameplay defined by a wave number, target WPM, spawn delay, fall speed, and pool size. Waves 1-15 have explicit parameters; waves 16+ follow a scaling formula.
- **Difficulty Table**: A fixed lookup of 15 explicit wave definitions plus a formula for wave 16+. Each entry contains target_wpm, spawn_delay, fall_speed, and pool_size.
- **Wave Transition**: A 3-second interstitial state between waves during which gameplay is frozen and a countdown is displayed.

### Difficulty Table Reference

| Wave | Target WPM | spawn_delay (s) | fall_speed | pool_size |
|------|------------|-----------------|------------|-----------|
| 1    | 15         | 4.80            | 0.5        | 5         |
| 2    | 18         | 4.00            | 0.6        | 7         |
| 3    | 22         | 3.27            | 0.7        | 9         |
| 4    | 26         | 2.77            | 0.8        | 11        |
| 5    | 30         | 2.40            | 0.9        | 13        |
| 6    | 35         | 2.06            | 1.0        | 15        |
| 7    | 40         | 1.80            | 1.1        | 17        |
| 8    | 45         | 1.60            | 1.2        | 19        |
| 9    | 50         | 1.44            | 1.3        | 21        |
| 10   | 55         | 1.31            | 1.4        | 23        |
| 11   | 60         | 1.20            | 1.5        | 25        |
| 12   | 70         | 1.03            | 1.6        | 27        |
| 13   | 80         | 0.90            | 1.7        | 29        |
| 14   | 90         | 0.80            | 1.8        | 31        |
| 15   | 100        | 0.72            | 1.9        | 33        |
| 16+  | 110        | 0.66            | 2.0        | 33 + 2*(wave-15) |

## Success Criteria

### Measurable Outcomes

- **SC-001**: Players experience a clear difficulty progression — wave 1 feels approachable (15 WPM) while wave 10+ demands skilled typing (55+ WPM)
- **SC-002**: Wave transitions display correctly with a visible 3-second countdown between every wave completion and the next wave start
- **SC-003**: The HUD kill counter accurately reflects kills in real time with zero lag relative to the kill event
- **SC-004**: Game-over screen correctly reports the wave reached and its target WPM for 100% of game-over events
- **SC-005**: A player who does not type at all during wave 1 sees all 5 zombies accumulate and fall until game over triggers — no zombies are silently discarded
- **SC-006**: Game restart from game-over screen returns to wave 1 with correct difficulty parameters within 1 frame of pressing ENTER
- **SC-007**: Waves 16+ correctly scale pool_size by +2 per wave while maintaining capped WPM, spawn delay, and fall speed values
