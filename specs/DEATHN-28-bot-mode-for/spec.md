# Feature Specification: Bot Mode for Difficulty Validation and Auto-Pilot Watching

**Feature Branch**: `DEATHN-28-bot-mode-for`
**Created**: 2026-05-18
**Status**: Draft
**Input**: DEATHN-28 — Bot mode for difficulty validation and auto-pilot watching

## Auto-Resolved Decisions

### ARD-1: Bot Typing Cadence Formula

- **Decision**: Bot types at `chars_per_second = target_wpm / 12` using the standard 5-characters-per-word convention, applying the active wave's `target_wpm`. During boss phases the same cadence applies to boss phrase characters.
- **Policy Applied**: CONSERVATIVE (AUTO fallback — low confidence, score -1)
- **Confidence**: Low (0.3) — internal tooling feature with mixed signals; ticket description is explicit about the formula, so no ambiguity remains.
- **Fallback Triggered?**: Yes — AUTO scored net -1, absScore 1, confidence 0.3 < 0.5; promoted to CONSERVATIVE.
- **Trade-offs**: Locking cadence to `target_wpm / 12` means the bot cannot demonstrate "headroom" above the survival floor without changing the constant; acceptable because the primary goal is floor validation.
- **Reviewer Notes**: Confirm that the 5-chars/word convention matches the WPM display the player sees on the HUD. If the game ever changes its WPM definition, the bot formula must update in lockstep.

### ARD-2: Reaction Delay Scope

- **Decision**: The reaction delay (default 200 ms) applies to three events: (a) selecting an initial target when no target is active, (b) switching to a new target after the current target dies, and (c) switching to a new target when a more-pressing zombie appears below the current target. The bot does not re-evaluate targets while actively typing a name — it finishes the current name first, then applies the delay before choosing the next target.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (0.3) — ticket says "configurable reaction delay" but does not specify whether mid-name re-targeting is allowed.
- **Fallback Triggered?**: Yes — ambiguous axis resolved conservatively: finishing the current name before switching is the safer default because partial-name abandonment would inflate error stats and complicate input-buffer management.
- **Trade-offs**: A human player might abandon a partially typed name to save a closer zombie; the bot will not, making it slightly less optimal than a perfect human in panic scenarios. This is acceptable for floor validation.
- **Reviewer Notes**: If future iterations add typo simulation, mid-name target switching should be revisited.

### ARD-3: Menu Entry Placement and Keyboard Shortcut

- **Decision**: "BOT" is added as a new main-menu item between "ZEN" and "SOUND" (position index 2 in the menu array). The in-game toggle shortcut is F2. Pressing F2 during gameplay toggles bot mode on or off immediately.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (0.3) — ticket suggests "e.g. F2" and "e.g. BOT entry alongside SURVIVAL/ZEN/SOUND" without mandating exact placement.
- **Fallback Triggered?**: Yes — resolved conservatively: placing BOT after the two game modes but before settings keeps the menu logically grouped (play modes → bot → settings → quit).
- **Trade-offs**: Adding a fifth menu item increases visual density slightly; acceptable given the menu's simple vertical layout.
- **Reviewer Notes**: Verify F2 does not conflict with any existing raylib or OS shortcut on target platforms (Windows, macOS, Linux, Web).

### ARD-4: Bot Behavior During Dying and Transition States

- **Decision**: The bot stops typing during the dying animation (1-second pause) and during wave transition countdowns (3-second countdown). It resumes typing automatically when the next wave's update phase begins. The bot does not attempt to "pre-type" during transitions.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (0.3) — ticket says "dying state, wave transitions, boss waves all apply" but does not detail bot behavior during non-gameplay states.
- **Fallback Triggered?**: Yes — conservative: the bot respects the same gating (`!is_game_over`, `!is_transitioning`, `!is_dying`) that the player's input already respects.
- **Trade-offs**: None significant — aligning bot behavior with existing input gating is the simplest and most accurate simulation.
- **Reviewer Notes**: Ensure the bot clears its internal target state on wave transition so it doesn't try to type a zombie name from the previous wave.

### ARD-5: Bot Mode Interaction with Zen Mode

- **Decision**: Bot mode is available only in Survival mode. Selecting "BOT" from the menu starts a Survival-mode session with the bot active. The bot cannot be used in Zen mode.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (0.3) — ticket references only survival-mode concepts (wave numbers, `target_wpm` per wave, pool sizes) and frames the bot as a "survival-floor validator." Zen mode has player-selected WPM tiers, making bot validation less meaningful there.
- **Fallback Triggered?**: Yes — restricting scope to Survival is the conservative choice; Zen support can be added later if needed.
- **Trade-offs**: Users who want to watch a bot play Zen mode (demo/screensaver purpose) cannot do so in this iteration. The validation use case is unaffected.
- **Reviewer Notes**: If Zen-mode bot support is desired, a follow-up ticket should specify which WPM tier the bot targets and whether the high-score gate applies there too.

### ARD-6: Bot Target Selection When Multiple Zombies Are Equidistant

- **Decision**: When multiple zombies are at the same Y position (equidistant from the bottom), the bot selects the one with the shortest name to maximize kill throughput. If names are also equal length, the leftmost zombie is chosen (lowest X position) for deterministic behavior.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (0.3) — ticket says "most-pressing zombie (e.g. closest to the bottom)" without specifying tie-breaking.
- **Fallback Triggered?**: Yes — tie-breaking by shortest name then leftmost position is conservative (deterministic, repeatable, favors clearing threats quickly).
- **Trade-offs**: A human might pick a different zombie in a tie; the bot's deterministic tie-breaking makes its behavior fully reproducible, which is better for validation.
- **Reviewer Notes**: If the bot consistently fails certain waves due to this heuristic, consider adding a "longest name first" option as a tunable.

### ARD-7: Session-Level Bot-Tainted Flag Persistence

- **Decision**: A boolean "bot-tainted" flag is set to true the moment bot mode is activated during a session (either from the menu or via F2 toggle). This flag persists for the entire session — it is never cleared, even if the player disables the bot and plays manually for the remainder. The flag is reset only on full game restart (returning to the main menu and starting a new session). While bot-tainted is true, no high-score writes occur.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (0.3) — ticket says "the high-score gate stays disabled for the remainder of that session" but does not define "session" precisely.
- **Fallback Triggered?**: Yes — "session" is conservatively interpreted as "from game start to game over or quit to menu." Returning to the main menu resets the flag because it starts a fresh session.
- **Trade-offs**: A player who accidentally taps F2 during a legitimate run loses high-score eligibility for that run. This is the intended anti-cheese behavior.
- **Reviewer Notes**: Consider a brief confirmation prompt before activating bot mode during an active game to prevent accidental activation. (Not required for this iteration — flagged for UX polish.)

## User Scenarios & Testing

### User Story 1 — Watch the Bot Validate Wave 1 Survival Floor (Priority: P1)

A developer or designer wants to visually confirm that the announced `target_wpm = 20` for wave 1 is genuinely survivable. They select "BOT" from the main menu, watch the bot type zombie names at the wave-1 cadence, and verify that all zombies are killed before reaching the bottom.

**Why this priority**: This is the core validation use case that motivated the entire feature. Without it, wave balance can only be verified through math, not observation.

**Independent Test**: Start the game, select BOT from the menu, observe wave 1 — all zombies should be killed before landing. No high-score file should be written.

**Acceptance Scenarios**:

1. **Given** the game is at the main menu, **When** the user selects "BOT", **Then** a Survival-mode session starts with the bot active, a "BOT" badge is visible on the HUD, and the bot begins typing zombie names at the wave-1 cadence.
2. **Given** the bot is playing wave 1 with default settings (`target_wpm = 20`, reaction delay 200 ms), **When** all 10 zombies have spawned and the bot types at the announced cadence, **Then** all zombies are killed before reaching the bottom of the screen.
3. **Given** the bot completes wave 1, **When** the wave transition occurs, **Then** the bot resumes typing at the wave-2 cadence after the 3-second countdown.

---

### User Story 2 — Toggle Bot On/Off Mid-Game with F2 (Priority: P2)

A player is in the middle of a Survival session and wants to hand control to the bot (or take it back). They press F2 to toggle bot mode. The "BOT" badge appears or disappears accordingly. Once the bot has been active at any point, high-score persistence is disabled for the rest of that session.

**Why this priority**: Mid-session toggling is the second most important interaction — it enables quick A/B observation (human vs. bot) on the same wave and supports the "take over when I'm tired" demo use case.

**Independent Test**: Start a Survival game normally, press F2 mid-wave, confirm the BOT badge appears and the bot starts typing. Press F2 again, confirm the badge disappears and manual control resumes. Verify no high-score is written at game over.

**Acceptance Scenarios**:

1. **Given** a Survival session is in progress with the bot off, **When** the player presses F2, **Then** the bot activates immediately, the "BOT" badge appears, and the bot begins targeting the most-pressing zombie after the reaction delay.
2. **Given** the bot is active mid-wave, **When** the player presses F2 again, **Then** the bot deactivates, the "BOT" badge disappears, and the player resumes manual typing from the current input buffer state.
3. **Given** bot mode was activated at any point during the session, **When** the game ends (game over or quit), **Then** no high-score data is written to persistent storage (file or localStorage).

---

### User Story 3 — Bot Handles Boss Waves (Priority: P2)

The bot encounters a boss wave (every 5th wave). It must type the full boss phrase using the same input buffer and cadence rules. The boss phrase can be up to 35 characters including spaces.

**Why this priority**: Boss waves are a critical part of the difficulty curve. If the bot cannot handle them, it cannot validate the full survival experience.

**Independent Test**: Let the bot play through waves 1–5 and observe wave 5 (boss wave). The bot should type the boss phrase correctly and kill the boss before it reaches the bottom.

**Acceptance Scenarios**:

1. **Given** the bot is active and a boss wave begins, **When** the boss zombie spawns with a phrase, **Then** the bot targets the boss and types the phrase character by character at the wave's cadence, including space characters.
2. **Given** the bot is typing a boss phrase, **When** regular zombies also spawn during the boss wave, **Then** the bot finishes the boss phrase before switching to regular zombies (boss takes priority, consistent with existing boss-prefix protection).

---

### User Story 4 — Bot Ignores Power-Ups (Priority: P3)

While the bot is active, carrier zombies still spawn and drop power-ups. The bot picks up power-ups by killing carriers (existing mechanic), but never activates them. Power-ups sit in the inventory until the wave ends or the player takes manual control.

**Why this priority**: Power-up abstinence ensures the bot validates raw typing survival without shortcuts. Important for balance accuracy but lower priority than core typing simulation.

**Independent Test**: Enable bot mode, play through several waves, observe that power-ups are picked up (HUD shows held power-up) but never consumed — the bot never presses the activation key.

**Acceptance Scenarios**:

1. **Given** the bot is active and kills a carrier zombie with a power-up, **When** the power-up is picked up, **Then** the HUD shows the held power-up but the bot does not activate it.
2. **Given** the bot is holding a power-up, **When** subsequent frames are processed, **Then** the bot never issues the power-up activation input (Space key), regardless of game state.

---

### User Story 5 — "BOT" Visual Badge (Priority: P3)

Whenever bot mode is active, a prominent "BOT" badge is displayed on the HUD so spectators can immediately tell that automated typing is in progress.

**Why this priority**: Essential for clarity but mechanically simple — it's a static text overlay gated on a boolean.

**Independent Test**: Activate bot mode, confirm the badge is visible. Deactivate, confirm it disappears.

**Acceptance Scenarios**:

1. **Given** bot mode is active, **When** any frame is drawn, **Then** a "BOT" badge is displayed prominently on the HUD using the game's CRT color palette.
2. **Given** bot mode is deactivated, **When** any frame is drawn, **Then** no "BOT" badge is visible.

---

### Edge Cases

- What happens when the bot is mid-name and the target zombie is killed by a bomb power-up activated by the player (after toggling off bot mode)? The bot clears its input buffer, waits the reaction delay, then selects a new target.
- What happens when no zombies are on screen? The bot idles with an empty input buffer until a new zombie spawns, then applies the reaction delay before targeting it.
- What happens if the player types while bot mode is active? Player keypresses are ignored while the bot is active — the bot exclusively controls the input buffer. The player must press F2 to deactivate the bot before typing manually.
- What happens when the bot is activated during the pause menu? F2 has no effect while the pause menu is open. The toggle only applies during active gameplay.
- What happens at game over while bot mode is active? The game-over screen displays normally with stats. The bot stops typing. No high-score is persisted. The player can restart or return to the menu.
- What happens when the bot encounters a compound/hyphenated name (e.g., "Jean-Pierre")? The bot types all characters including hyphens at the same cadence — no special handling needed since hyphens are already accepted by the input system.

## Requirements

### Functional Requirements

- **FR-001**: The main menu MUST include a "BOT" entry that starts a Survival-mode session with the bot active.
- **FR-002**: Pressing F2 during active gameplay MUST toggle bot mode on or off immediately.
- **FR-003**: While bot mode is active, the system MUST generate synthetic character inputs into the shared input buffer at a rate of `target_wpm / 12` characters per second, matching the current wave's announced WPM.
- **FR-004**: The bot MUST apply a configurable reaction delay (default 200 ms) before selecting a new target zombie after: initial activation, current target death, or wave start.
- **FR-005**: The bot MUST target the active zombie closest to the bottom of the screen. Ties are broken by shortest name, then leftmost position.
- **FR-006**: The bot MUST complete typing the current target's full name before switching to a new target.
- **FR-007**: The bot MUST type boss phrases correctly during boss waves, including spaces, at the same cadence.
- **FR-008**: The bot MUST NOT activate any held power-up under any circumstances.
- **FR-009**: Player keyboard input MUST be ignored while bot mode is active; the player must deactivate the bot (F2) to resume manual control.
- **FR-010**: A "bot-tainted" flag MUST be set the first time bot mode is activated in a session and MUST NOT be cleared until a new session starts from the main menu.
- **FR-011**: When the bot-tainted flag is set, the system MUST NOT write high-score data to persistent storage (native file or web localStorage) for the remainder of that session.
- **FR-012**: In-memory high-score tracking MAY continue during bot-tainted sessions for display purposes, but MUST NOT persist across restarts.
- **FR-013**: A visible "BOT" badge MUST be displayed on the HUD whenever bot mode is active, using the game's existing CRT color palette.
- **FR-014**: The bot MUST stop typing during dying animation, wave transition countdowns, pause states, and game-over states.
- **FR-015**: The reaction delay MUST be exposed as a tunable constant so developers can adjust it for balance research (e.g., 0 ms, 100 ms, 200 ms, 500 ms).
- **FR-016**: Bot mode MUST only be available in Survival mode, not Zen mode.

### Key Entities

- **BotState**: Represents the bot's internal state — whether it is active, its current target zombie, accumulated typing timer, reaction delay timer, and the index into the target's name it has typed so far.
- **Bot-Tainted Flag**: A session-level boolean that permanently disables high-score persistence once bot mode has been activated at any point during the session.

## Success Criteria

### Measurable Outcomes

- **SC-001**: With bot mode active at wave 1 (target_wpm = 20, reaction delay = 200 ms), 100% of zombies are killed before reaching the screen bottom — validating the survival-floor contract.
- **SC-002**: Bot mode can be toggled on/off mid-wave in under 1 frame (no perceptible delay to the spectator).
- **SC-003**: No high-score data is persisted to disk or localStorage for any session where bot mode was activated, verified by checking storage after game-over.
- **SC-004**: The bot successfully types boss phrases (up to 35 characters including spaces) without errors during boss waves.
- **SC-005**: The "BOT" badge is visible within 1 frame of bot activation and disappears within 1 frame of deactivation.
- **SC-006**: Zero power-ups are consumed by the bot across an entire multi-wave session, regardless of how many are picked up.
- **SC-007**: The reaction delay constant can be changed to any value between 0 and 2000 ms and the bot behavior adjusts accordingly without code changes beyond the constant.
