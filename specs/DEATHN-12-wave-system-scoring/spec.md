# Feature Specification: Wave System, Scoring and Difficulty Progression

**Feature Branch**: `DEATHN-12-wave-system-scoring`  
**Created**: 2026-05-16  
**Status**: Draft  
**Input**: User description: "Wave system, scoring and difficulty progression — structured wave gameplay with boss fights, combo scoring, live stats, and persistent high scores"

## Auto-Resolved Decisions

### ARD-1: Wave Completion Mode

- **Decision**: Waves end when the kill target is reached OR when the wave timer expires, whichever comes first. If the timer expires before the target is met, the wave is considered "survived" (game continues to the next wave) but the player receives no wave-completion bonus. If a boss is alive when the timer expires, the timer pauses — the boss must be defeated to end the wave.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 1 — neutral game-feature context offset by internal-project signal; absScore < 3 triggers fallback)
- **Fallback Triggered?**: Yes — AUTO recommended PRAGMATIC but confidence was below 0.5 threshold, promoted to CONSERVATIVE
- **Trade-offs**: Pausing the timer for bosses prevents frustration from unbeatable waves but may create stall situations at high difficulty; timer expiration without penalty keeps the game accessible but reduces stakes.
- **Reviewer Notes**: Validate that "timer pauses for boss" feels fair in playtesting; consider adding a partial-score penalty for timer expiration if the game feels too forgiving.

### ARD-2: Inter-Wave Transition Duration

- **Decision**: 5-second recap screen (showing wave stats: kills, accuracy, WPM) followed by a 3-second countdown before the next wave begins, totaling 8 seconds between waves. The recap screen appears immediately; the countdown begins after the recap.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (no explicit timing given; "a few seconds" is vague)
- **Fallback Triggered?**: Yes
- **Trade-offs**: 8 seconds is generous — enough to read stats but may feel slow at high waves; could be shortened in future iterations.
- **Reviewer Notes**: Consider whether advanced players should be able to skip the recap by pressing Enter/Space.

### ARD-3: WPM Sliding Window Size

- **Decision**: WPM is calculated over a 30-second rolling window of completed words (zombie names successfully typed). If fewer than 30 seconds have elapsed, the entire session is used.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (no window size specified in ticket)
- **Fallback Triggered?**: Yes
- **Trade-offs**: 30 seconds smooths out burst/pause patterns but reacts slowly to changes in typing speed; a shorter window (10s) would be more responsive but noisier.
- **Reviewer Notes**: 30 seconds is standard for typing-test applications; validate that the displayed value feels responsive during play.

### ARD-4: Boss Phrase Source and Input Buffer

- **Decision**: Boss zombies display multi-word phrases (10–30 characters) drawn from a predefined phrase list (similar to how zombie names come from `zombie_names.zig`). The input buffer limit is increased from 9 to 40 characters to accommodate boss phrases. The existing MAX_INPUT_CHARS constant governs normal zombie name length; a separate maximum applies to boss input.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (ticket says "phrase entière" but no specifics on length or source)
- **Fallback Triggered?**: Yes
- **Trade-offs**: Predefined phrases are predictable after repeated play but ensure quality and appropriate difficulty; 40-char limit is generous for short phrases.
- **Reviewer Notes**: The phrase list should be curated for typing difficulty and humor/thematic fit; ensure phrases contain only characters within the existing accepted input range (ASCII 32–125).

### ARD-5: Combo Multiplier Cap and Scoring Formula

- **Decision**: The combo multiplier caps at 5x. The multiplier progression is: 1x (0–4 combo), 2x (5–9 combo), 3x (10–14 combo), 4x (15–19 combo), 5x (20+ combo). Base kill score is 100 points per normal zombie. Boss kills award 500 base points. A wave-completion bonus of 200 × wave number is awarded when the kill target is met before timer expiration.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (no scoring values specified in ticket)
- **Fallback Triggered?**: Yes
- **Trade-offs**: Capping at 5x prevents runaway scores but may frustrate expert players; the 5-kill combo steps are forgiving enough for intermediate players to reach 2x–3x regularly.
- **Reviewer Notes**: All scoring values should be declared as named constants (tunables) for easy balancing iteration. Playtest to verify the 5-kill step size feels rewarding.

### ARD-6: Difficulty Curve Parameters

- **Decision**: Difficulty scales per wave with diminishing returns (fast early ramp, plateau at high waves). Spawn delay: starts at 3.0s (wave 1), decreases by ~15% per wave, floor at 0.5s (~wave 12). Zombie fall speed: starts at 0.5 px/frame (wave 1), increases by ~10% per wave, cap at 2.0 px/frame (~wave 15). Max simultaneous zombies: starts at 5 (wave 1), increases by 2 per wave, cap at 30 (wave 13+). These are approximate targets; exact formulas use exponential decay / linear clamp.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (ticket gives qualitative targets — "wave 10 high density, wave 20 real stress" — but no numbers)
- **Fallback Triggered?**: Yes
- **Trade-offs**: Conservative floor/cap values prevent impossible waves but may limit late-game challenge; the exponential curve front-loads difficulty increases so early waves feel dynamic.
- **Reviewer Notes**: These numbers are the starting point for playtesting. Validate that waves 1–5 feel accessible and wave 10+ feels demanding. All values must be named constants.

### ARD-7: High Score Persistence Mechanism

- **Decision**: On native builds, persist the high score to a local file in the user's data directory (or working directory as fallback). On web builds, persist using the browser's localStorage API (accessed via Emscripten's persistence helpers). Only the single highest score is stored (not a leaderboard). If persistence fails (e.g., localStorage disabled), the game continues without persistence and does not display a "best score" value.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (ticket says "persisted locally" but no mechanism specified)
- **Fallback Triggered?**: Yes
- **Trade-offs**: Single high score is minimal but sufficient; localStorage may be cleared by the user; graceful degradation avoids crashes but loses the "beat your best" motivation.
- **Reviewer Notes**: Validate that the web build correctly reads/writes localStorage. Consider whether additional stats (best wave, best WPM) should also be persisted — currently scoped to score only for conservatism.

### ARD-8: Accuracy Calculation and Error Detection

- **Decision**: Accuracy = (total correct keystrokes / total keystrokes) × 100%. A keystroke is "correct" if the typed character extends a prefix match against any active zombie's name (or the boss phrase). A keystroke is "incorrect" (and breaks the combo) if it does not match any active zombie's name prefix from the current input buffer state. Backspace does not count as a keystroke for accuracy purposes.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (ticket says "lettre tapée qui ne correspond à aucun préfixe de zombie actif" but exact matching semantics need specification)
- **Fallback Triggered?**: Yes
- **Trade-offs**: Prefix-matching against all active zombies is generous (any zombie is a valid target) but aligns with the current single-input-buffer design; this means the player doesn't explicitly "target" a zombie.
- **Reviewer Notes**: Verify that the prefix-match logic handles edge cases: two zombies sharing a prefix (e.g., "Ana" and "Anil"), empty input buffer after a kill, and boss phrases containing spaces.

## User Scenarios & Testing

### User Story 1 - Wave-Based Gameplay Loop (Priority: P1)

A player launches the game and is presented with Wave 1. Zombies spawn at a relaxed pace. The player types zombie names to eliminate them. After reaching the wave's kill target, a transition screen shows their wave stats (kills, accuracy, WPM) and a countdown to the next wave. Each subsequent wave spawns zombies faster and at higher speed. The game continues until a zombie reaches the bottom of the screen.

**Why this priority**: This is the core gameplay restructuring. Without waves, no other feature (scoring, bosses, stats) has a framework to attach to.

**Independent Test**: Can be fully tested by playing through waves 1–3 and verifying that wave numbers increment, transitions appear, and difficulty increases visibly.

**Acceptance Scenarios**:

1. **Given** the game has just started, **When** the player types and eliminates the required number of zombies for wave 1, **Then** a transition screen appears showing "Wave 1 Complete" with kills, accuracy, and WPM stats, followed by a countdown to wave 2.
2. **Given** wave 2 has started, **When** the player observes zombie behavior, **Then** zombies spawn more frequently and fall faster than in wave 1.
3. **Given** any wave is active, **When** the wave timer expires before the kill target is met, **Then** the wave ends without a completion bonus, remaining non-boss zombies are cleared, and the next wave begins after the transition screen.
4. **Given** any wave is active, **When** a zombie reaches the bottom of the screen, **Then** the game ends (game over) regardless of wave progress.

---

### User Story 2 - Score, Combo, and HUD Display (Priority: P2)

During gameplay, the player sees a heads-up display showing their current score, combo count, multiplier, current wave number, WPM, and accuracy. Killing zombies consecutively without errors builds a combo that increases the score multiplier. Typing a character that doesn't match any active zombie's name prefix resets the combo to zero.

**Why this priority**: Scoring and combo give the player feedback and motivation. The HUD is the primary information channel during play.

**Independent Test**: Can be tested by playing a single wave and verifying that the score increments on kills, combo builds on consecutive kills, and combo resets on a mistyped character.

**Acceptance Scenarios**:

1. **Given** the game is running, **When** the player looks at the screen, **Then** the HUD displays: wave number, score, combo count, multiplier, WPM, and accuracy — all without overlapping the zombie play area or input box.
2. **Given** the player has killed 5 zombies without any mistyped characters or lost zombies, **When** they kill a 6th zombie, **Then** the combo counter shows 6 and the multiplier displays 2x.
3. **Given** the player has an active combo of 8, **When** they type a character that does not match any active zombie's name prefix from the current input state, **Then** the combo resets to 0 and the multiplier returns to 1x.
4. **Given** the player kills a zombie, **When** the score updates, **Then** the score increases by (base points × current multiplier).

---

### User Story 3 - Boss Zombie Every 5 Waves (Priority: P3)

At the end of every 5th wave (wave 5, 10, 15, etc.), a boss zombie appears. The boss displays a longer phrase instead of a single name. It falls slowly and has a visual indicator (character progress bar) showing how much of the phrase remains to be typed. The wave cannot end until the boss is defeated. Normal zombies may continue spawning alongside the boss.

**Why this priority**: Bosses add variety and climactic moments to the wave structure, but the core wave loop must work first.

**Independent Test**: Can be tested by reaching wave 5 and verifying the boss spawns, displays a phrase, falls slowly, shows typing progress, and blocks wave completion until defeated.

**Acceptance Scenarios**:

1. **Given** the player completes the kill target for wave 5, **When** the wave's normal zombies are cleared, **Then** a boss zombie spawns with a multi-word phrase displayed above it.
2. **Given** a boss is active, **When** the player types characters matching the boss phrase prefix, **Then** a progress indicator updates to show remaining characters.
3. **Given** a boss is active and the wave timer is running, **When** the timer would normally expire, **Then** the timer pauses until the boss is defeated.
4. **Given** a boss is active alongside normal zombies, **When** a normal zombie reaches the bottom, **Then** the game ends (game over) — the boss does not grant immunity from normal zombie threats.

---

### User Story 4 - Game-Over Screen with Stats and Persistent High Score (Priority: P4)

When the game ends, the player sees a detailed game-over screen showing: wave reached, final score, best score (local high score), average WPM, overall accuracy, and total kills. If the final score exceeds the stored best score, it is saved. On the next session, the best score is loaded and displayed.

**Why this priority**: End-of-game stats and persistence give long-term replayability and a goal to beat, but require the scoring system (P2) to be in place.

**Independent Test**: Can be tested by playing until game over, verifying all stats display, then restarting and confirming the best score persists across sessions.

**Acceptance Scenarios**:

1. **Given** the game has ended, **When** the game-over screen appears, **Then** it displays: wave reached, final score, best score, average WPM, accuracy percentage, and total kill count.
2. **Given** the player's final score is higher than the stored best score, **When** the game-over screen is shown, **Then** the new high score is saved and a "New High Score!" indicator is visible.
3. **Given** the player closes and reopens the game (native or web), **When** they reach the game-over screen again, **Then** the previously saved best score is displayed.
4. **Given** high score persistence is unavailable (e.g., localStorage disabled on web), **When** the game-over screen appears, **Then** the game displays stats normally but omits the best score field instead of crashing.

---

### User Story 5 - Live WPM and Accuracy Stats (Priority: P5)

During active gameplay, the HUD shows the player's words-per-minute (calculated over a 30-second rolling window) and accuracy (correct keystrokes / total keystrokes as a percentage). These values update in near-real-time as the player types.

**Why this priority**: Live stats enhance the typing-game feel and provide continuous feedback, but depend on the HUD infrastructure from P2.

**Independent Test**: Can be tested by typing several zombie names and verifying WPM and accuracy values update, and that deliberately mistyping changes the accuracy downward.

**Acceptance Scenarios**:

1. **Given** the player has been playing for at least 10 seconds, **When** they look at the HUD, **Then** WPM shows a non-zero value reflecting their recent typing speed.
2. **Given** the player has typed 20 correct characters and 5 incorrect characters, **When** they check the accuracy display, **Then** it shows 80% (20/25).
3. **Given** the player has not typed anything for 30 seconds, **When** they look at the WPM display, **Then** WPM shows 0 (the rolling window contains no completed words).

---

### Edge Cases

- What happens when the input buffer is full and the player tries to type a boss phrase character? The input buffer must accommodate boss phrase lengths (up to 40 characters); if a phrase exceeds the buffer, the boss phrase list must be curated to prevent this.
- How does the game handle two zombies with identical names on screen simultaneously? The first zombie matching the typed name is killed (topmost / earliest spawned); the input buffer clears after the kill.
- What happens if all zombie pool slots are full during a wave? Spawning pauses until a slot frees up; the spawn timer remains hot and retries each frame (existing behavior preserved).
- What happens when the player reaches extremely high waves (50+)? Difficulty parameters are clamped at their floor/cap values; the game does not become literally impossible, just very challenging.
- How does the combo interact with backspace? Backspace does not break the combo and does not count toward accuracy. It simply removes the last character from the input buffer.
- What happens if the player types a valid prefix for zombie A but then completes it to match zombie B? The match is checked on full name completion only (existing behavior); partial prefix typing does not lock onto a target.

## Requirements

### Functional Requirements

- **FR-001**: The game MUST organize zombie spawns into sequential, numbered waves starting from wave 1.
- **FR-002**: Each wave MUST have a defined kill target (number of zombies the player must eliminate) and a maximum duration timer.
- **FR-003**: A wave MUST end when either the kill target is reached or the wave timer expires, whichever occurs first.
- **FR-004**: Between waves, the game MUST display a transition screen showing: the completed wave number, kills achieved, accuracy percentage, and WPM for that wave, followed by a countdown before the next wave starts.
- **FR-005**: The spawn delay between zombies MUST decrease with each successive wave, with a minimum floor to prevent overlapping spawns.
- **FR-006**: The zombie fall speed MUST increase with each successive wave, with a maximum cap to keep the game playable.
- **FR-007**: The maximum number of simultaneously active zombies MUST increase with each successive wave, with a cap at or below the existing MAX_ZOMBIES pool size.
- **FR-008**: Every 5th wave (5, 10, 15, ...) MUST spawn a boss zombie that displays a multi-word phrase instead of a single name.
- **FR-009**: The boss zombie MUST fall at a slower speed than normal zombies in the same wave.
- **FR-010**: The boss zombie MUST display a visual progress indicator showing how much of the phrase has been typed and how much remains.
- **FR-011**: A wave containing a boss MUST NOT end until the boss is defeated, regardless of the wave timer (timer pauses while boss is alive).
- **FR-012**: The game MUST maintain and display a score that increases when zombies are killed, with points proportional to a combo multiplier.
- **FR-013**: The game MUST maintain a combo counter that increments on each consecutive kill without a mistyped character or a lost zombie (one reaching the bottom).
- **FR-014**: A mistyped character (one that does not extend a valid prefix match against any active zombie's name or boss phrase) MUST reset the combo counter to zero.
- **FR-015**: The combo multiplier MUST increase in defined steps (1x at combo 0–4, 2x at 5–9, 3x at 10–14, 4x at 15–19, 5x at 20+) and cap at 5x.
- **FR-016**: The HUD MUST display during active gameplay: current wave number, score, combo count, multiplier, WPM, and accuracy.
- **FR-017**: HUD elements MUST NOT overlap the zombie play area or the text input box.
- **FR-018**: WPM MUST be calculated over a 30-second rolling window of completed words (killed zombies).
- **FR-019**: Accuracy MUST be calculated as (correct keystrokes / total keystrokes) × 100%, where backspace does not count as a keystroke.
- **FR-020**: The game-over screen MUST display: wave reached, final score, best score, average WPM, overall accuracy, and total kills.
- **FR-021**: The game MUST persist the best score locally between sessions — using file storage on native and browser localStorage on web.
- **FR-022**: If score persistence is unavailable, the game MUST continue to function normally, omitting the best score display rather than failing.
- **FR-023**: The input buffer MUST accommodate up to 40 characters to support boss phrases, while normal zombie names remain bounded by existing name lengths.
- **FR-024**: Boss phrases MUST be drawn from a predefined, curated list of short phrases containing only ASCII printable characters (32–125).
- **FR-025**: A zombie reaching the bottom of the screen MUST trigger game over, even during a boss fight.
- **FR-026**: On game restart, all wave state, score, combo, and stats MUST reset to initial values (wave 1, score 0, combo 0).

### Key Entities

- **Wave**: Represents a numbered phase of gameplay with a kill target, timer, and difficulty parameters (spawn delay, fall speed, max active zombies). Transitions to the next wave on completion.
- **Boss Zombie**: A special zombie variant that appears every 5 waves, carrying a multi-word phrase instead of a short name. Falls slower than normal zombies and blocks wave completion until defeated.
- **Score**: A cumulative point total built from kills, modified by the combo multiplier and wave-completion bonuses. Persisted as a high score across sessions.
- **Combo**: A streak counter tracking consecutive kills without errors. Maps to a multiplier tier (1x–5x) applied to kill points.
- **Player Stats**: Real-time metrics (WPM, accuracy, total keystrokes, correct keystrokes) calculated during gameplay and summarized at game over.
- **High Score Record**: A single persisted value representing the player's best-ever score, stored locally (file on native, localStorage on web).

## Success Criteria

### Measurable Outcomes

- **SC-001**: Players can complete waves 1 through 5 on their first session with a success rate above 80% (fewer than 1 in 5 players hit game over before wave 5), indicating accessible early difficulty.
- **SC-002**: Fewer than 20% of players reach wave 15 on a given session, indicating effective difficulty scaling.
- **SC-003**: The score, combo, wave number, WPM, and accuracy are visible at all times during gameplay without requiring the player to look away from the zombie play area for more than a glance.
- **SC-004**: The game maintains 60 FPS with up to 30 simultaneously active zombies on screen (the defined cap), on both native and web builds.
- **SC-005**: The best score persists correctly across at least 3 consecutive game sessions (close and reopen) on both native and web platforms.
- **SC-006**: Boss encounters occur exactly every 5 waves and take between 10 and 30 seconds to defeat at their intended difficulty level, providing a distinct climactic moment.
- **SC-007**: Players report (via playtest feedback) that difficulty feels progressive and not monotonous — early waves feel relaxed, mid-waves feel engaging, and late waves feel intense.

## Assumptions

- The existing `zombie_names.zig` name list is sufficient for normal zombie variety; no new short names are needed for this feature.
- Boss phrases will be added in a new source file (e.g., `boss_phrases.zig`) following the same pattern as `zombie_names.zig`.
- The 800×450 window resolution provides sufficient space for HUD elements without obscuring gameplay. HUD placement will use screen margins (top bar or side panels).
- The existing `page_allocator` / `c_allocator` allocation strategy is sufficient for the increased zombie count and new state tracking.
- Font rendering via raylib's built-in `DrawText` is sufficient for HUD display; no custom font assets are required for this feature.
- The scoring and difficulty constants defined in this spec are starting points for playtesting and will be tuned iteratively via named constants.
