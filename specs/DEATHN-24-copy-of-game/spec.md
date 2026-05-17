# Feature Specification: Game-Over Stats Screen and High Score Persistence

**Feature Branch**: `DEATHN-24-copy-of-game`
**Created**: 2026-05-17
**Status**: Draft
**Input**: User description: "Game-over stats screen with detailed session statistics and persistent high score tracking across native and web builds"

## Auto-Resolved Decisions

### ARD-1: File persistence vs. constitution constraint

- **Decision**: Allow file writes for `highscore.dat` despite constitution stating "no persistence" and agents must not add filesystem-write capabilities without human approval. The ticket explicitly requests this feature, which constitutes authorized human direction.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: High (score 5) — ticket description is explicit and unambiguous about persistence requirements
- **Fallback Triggered?**: No
- **Trade-offs**: Adds a new I/O surface to a previously read-only game; constitution security practices section will need updating post-merge.
- **Reviewer Notes**: Confirm that introducing file writes to the game is intentional and update the constitution's "no persistence" statement accordingly.

### ARD-2: Binary file endianness and corruption handling

- **Decision**: Use native (little-endian on all current targets) byte order for `highscore.dat`. On read, validate that the file size matches the expected structure size exactly; if it does not match, treat the file as corrupt and fall back to all-zero defaults. Do not attempt partial recovery.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: High (score 5) — the game targets x86/wasm (both little-endian); strict validation prevents undefined behavior from corrupt data
- **Fallback Triggered?**: No
- **Trade-offs**: A player who manually edits the file with a different byte order will lose their score silently. Strict size check means any future format change requires migration logic or a clean reset.
- **Reviewer Notes**: Verify that no big-endian deployment target is planned. Consider whether a version byte should be prepended to the file format for forward compatibility.

### ARD-3: Division by zero in average WPM calculation

- **Decision**: If `session_duration_minutes` is zero or negative (game ends in under one frame), display average WPM as 0 rather than producing an undefined value.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: High (score 5) — edge case is mathematically certain (very fast game-over on wave 1)
- **Fallback Triggered?**: No
- **Trade-offs**: A player who dies instantly sees "Average WPM: 0" which is technically inaccurate but safe. No performance or UX cost.
- **Reviewer Notes**: No action needed — standard defensive arithmetic.

### ARD-4: Which zombie is highlighted during game-over transition

- **Decision**: Highlight the first zombie that crossed the bottom boundary in the current update frame. If multiple zombies cross simultaneously, only one receives the red tint highlight; the others remain in their normal state.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Medium (score 3) — the ticket says "the responsible zombie" (singular), implying one; simultaneous crossings are rare but possible
- **Fallback Triggered?**: No
- **Trade-offs**: In rare multi-cross scenarios, the player may not see all culprits highlighted. Highlighting only one keeps the visual clean and the logic simple.
- **Reviewer Notes**: Acceptable simplification. If playtesters find it confusing, a follow-up could highlight all crossing zombies.

### ARD-5: Exact position of "Press ENTER to restart" text

- **Decision**: The restart prompt is rendered at a fixed position near the bottom of the screen (approximately 90% of screen height), centered horizontally, independent of the stats block's vertical layout.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Medium (score 3) — the ticket says "en bas" (at bottom) without a pixel value; anchoring to screen bottom is the safest interpretation
- **Fallback Triggered?**: No
- **Trade-offs**: On non-standard window sizes (if ever supported), the gap between stats and prompt may look uneven. Fixed anchor is visually predictable.
- **Reviewer Notes**: Fine-tune exact y-offset during implementation if visual spacing feels off.

## User Scenarios & Testing

### User Story 1 - Game-Over Stats Display (Priority: P1)

A player whose zombie reaches the bottom of the screen sees a brief transition animation followed by a full-screen statistics summary showing their performance for that session, including wave reached, final score, average WPM, accuracy percentage, and total kills.

**Why this priority**: The stats screen is the core deliverable — it replaces the current minimal game-over display and gives players meaningful feedback on their performance. All other stories depend on this screen existing.

**Independent Test**: Can be fully tested by playing a game until game-over and verifying all seven stat lines appear with correct values at the specified positions and styles.

**Acceptance Scenarios**:

1. **Given** a game is in progress, **When** a zombie reaches the bottom of the screen, **Then** the game pauses for 1 second with the responsible zombie tinted red, no spawns or updates occur during this pause, and after 1 second the full-screen stats overlay appears.
2. **Given** the stats screen is displayed, **When** the player reads the screen, **Then** they see eight lines in order: "GAME OVER" (large, red), "Wave reached: N", "Score: N", "Best: N" (or "NEW HIGH SCORE!" in gold), "Average WPM: N", "Accuracy: N%", "Kills: N", and "Press ENTER to restart" (small, gray, at the bottom).
3. **Given** the stats screen is displayed, **When** the player has typed 600 correct characters in 60 seconds of play, **Then** the average WPM shows 120.
4. **Given** the stats screen is displayed, **When** the session lasted less than 1 second, **Then** the average WPM shows 0.

---

### User Story 2 - High Score Persistence on Native Build (Priority: P2)

A player who beats their previous best score sees "NEW HIGH SCORE!" on the game-over screen, and when they relaunch the game later, their best score is remembered and displayed as the "Best:" line on subsequent game-over screens.

**Why this priority**: Persistence gives the game replayability and a sense of progression. Without it, the stats screen has no long-term value. Native build is the primary development target.

**Independent Test**: Can be tested by playing two sessions — first session sets a score, second session verifies "Best:" displays the previously saved value. Deleting `highscore.dat` and relaunching confirms reset to zero.

**Acceptance Scenarios**:

1. **Given** no `highscore.dat` file exists, **When** the game launches, **Then** the best score defaults to zero.
2. **Given** the player finishes a game with a score higher than the current best, **When** the game-over screen appears, **Then** "NEW HIGH SCORE!" is displayed in gold instead of "Best: N", and the score is saved to `highscore.dat`.
3. **Given** a valid `highscore.dat` exists from a previous session, **When** the game launches and the player reaches game-over with a lower score, **Then** "Best: N" displays the previously saved high score.
4. **Given** the player deletes `highscore.dat` and relaunches, **When** they reach game-over, **Then** "Best:" shows 0 (or "NEW HIGH SCORE!" if their score is > 0).
5. **Given** `highscore.dat` exists but is corrupt or has an unexpected size, **When** the game launches, **Then** the best score defaults to zero and the game does not crash.

---

### User Story 3 - High Score Persistence on Web Build (Priority: P3)

A player using the web (Emscripten/WASM) build has their high score persisted in the browser's localStorage under the key `death-note.highscore` in JSON format, with the same user-facing behavior as the native build.

**Why this priority**: The web build is a secondary deployment target. The persistence behavior mirrors native but uses a different storage mechanism appropriate for the browser environment.

**Independent Test**: Can be tested by playing the web build, achieving a high score, refreshing the page and verifying "Best:" persists. Clearing localStorage and refreshing confirms reset to zero.

**Acceptance Scenarios**:

1. **Given** `death-note.highscore` does not exist in localStorage, **When** the web game loads, **Then** the best score defaults to zero.
2. **Given** the player beats the current best on the web build, **When** game-over occurs, **Then** the high score is saved to localStorage as JSON under `death-note.highscore`.
3. **Given** a valid high score exists in localStorage, **When** the page is refreshed and the player reaches game-over, **Then** "Best:" displays the persisted value.
4. **Given** the player clears localStorage and reloads, **When** they reach game-over, **Then** the best score is zero.

---

### User Story 4 - Restart Resets Session but Preserves Best (Priority: P1)

A player who presses ENTER on the game-over screen starts a fresh game at wave 1 with all session counters reset to zero, but the persisted best score remains intact and is shown on the next game-over.

**Why this priority**: Restart is essential for the core gameplay loop. Incorrectly resetting (or failing to reset) counters would break the game experience. Tied with P1 because it is part of the fundamental game-over flow.

**Independent Test**: Can be tested by completing a game, pressing ENTER, playing again to game-over, and verifying all session stats are fresh while "Best:" retains the previous high.

**Acceptance Scenarios**:

1. **Given** the game-over screen is showing, **When** the player presses ENTER, **Then** the game restarts at wave 1 with score=0, combo=0, kills=0, WPM stats reset, accuracy reset, and the input buffer cleared.
2. **Given** the player achieved a new high score in their previous run, **When** they restart and reach game-over with a lower score, **Then** "Best:" shows the value from the previous run.

---

### Edge Cases

- What happens when `highscore.dat` is present but contains fewer bytes than expected? The file is treated as corrupt; best score defaults to zero.
- What happens when the game-over trigger occurs on the very first frame (zero elapsed time)? Average WPM displays as 0; no division by zero occurs.
- What happens when multiple zombies cross the bottom on the same frame? Only the first detected zombie is highlighted red; game-over triggers once.
- What happens when the player has 0 correct characters and 0 wrong characters? Accuracy displays as 0%.
- What happens on web if localStorage is disabled or full? Best score defaults to zero; the game continues without persistence. No error is shown to the player.

## Requirements

### Functional Requirements

- **FR-001**: System MUST pause all gameplay (spawning, movement, input processing) for exactly 1 second when a zombie reaches the bottom of the screen, before displaying the stats overlay.
- **FR-002**: System MUST visually highlight the zombie that triggered game-over with a red tint during the 1-second pause.
- **FR-003**: System MUST display a full-screen stats overlay with a white background containing exactly eight lines: "GAME OVER" (font size 48, red), "Wave reached: N", "Score: N", "Best: N" or "NEW HIGH SCORE!", "Average WPM: N", "Accuracy: N%", "Kills: N", and "Press ENTER to restart" (font size 18, gray).
- **FR-004**: System MUST display stat lines in font size 24, dark gray color, centered horizontally, starting at y=80 with 35px vertical spacing between lines.
- **FR-005**: System MUST calculate average WPM as `(total_correct_chars / 5) / (session_duration_in_seconds / 60)`, returning 0 when session duration is less than 1 second.
- **FR-006**: System MUST track a cumulative kill counter (normal zombies and bosses) that increments each time a zombie is eliminated by correct typing, and display it on the stats screen.
- **FR-007**: System MUST display "NEW HIGH SCORE!" in gold color when the current session score exceeds the persisted best score, replacing the "Best: N" line.
- **FR-008**: System MUST persist the high score on the native build as a binary file `highscore.dat` in the working directory, containing score (unsigned 64-bit), wave (unsigned 32-bit), WPM (unsigned 32-bit), and accuracy (unsigned 8-bit).
- **FR-009**: System MUST persist the high score on the web build using localStorage under the key `death-note.highscore` in JSON format containing the same fields as the native format.
- **FR-010**: System MUST save the high score only when the current session score strictly exceeds the previously persisted best score.
- **FR-011**: System MUST load the persisted high score at game startup and default all values to zero if the persistence store is absent, corrupt, or unreadable.
- **FR-012**: System MUST reset all session counters (score, combo, kills, WPM statistics, accuracy counters, elapsed time) when the player presses ENTER to restart, while preserving the loaded best score in memory.
- **FR-013**: System MUST display the "Best:" value reflecting the state after any save that occurred during the current game-over (i.e., if a new high score was just set, "Best:" equals the new score, not the old one).

### Key Entities

- **Session Statistics**: The set of metrics accumulated during a single play session — score, wave reached, average WPM, accuracy percentage, and kill count. Reset on each restart.
- **High Score Record**: The persisted best performance containing score, wave reached, average WPM, and accuracy. Survives across sessions and is only overwritten when surpassed.
- **Game-Over Transition State**: A timed intermediate state (1 second) between active gameplay and the stats screen, during which the triggering zombie is highlighted and all gameplay is frozen.

## Success Criteria

### Measurable Outcomes

- **SC-001**: All seven stat lines plus the restart prompt are visible and correctly positioned on the game-over screen within 2 seconds of the triggering event (1s transition + render).
- **SC-002**: A player who types 600 correct characters in 60 seconds of gameplay sees "Average WPM: 120" on the stats screen.
- **SC-003**: The kill counter on the stats screen matches the exact number of zombies (normal and boss) the player eliminated during the session.
- **SC-004**: After achieving a new high score and relaunching the game (native) or refreshing the page (web), the persisted best score is correctly displayed on the next game-over screen.
- **SC-005**: Deleting `highscore.dat` (native) or clearing localStorage (web) and restarting results in a best score of zero.
- **SC-006**: The game does not crash or display incorrect data when the persistence file is missing, empty, or corrupt.
- **SC-007**: Pressing ENTER on the stats screen restarts the game at wave 1 with all session counters at zero while the best score remains intact.

## Assumptions

- The existing score, WPM, and accuracy tracking capabilities are functioning correctly and will be reused.
- The game window remains at the fixed 800x450 resolution; layout positions are designed for this size.
- The native build always runs on a little-endian architecture.
- The web build has access to the browser's localStorage capability.
- Boss kills are tracked by the same mechanism as regular zombie kills; the kill counter does not need to distinguish between zombie types.
- No migration path is needed for the binary file format in this version; if the format changes in the future, a version header can be added at that time.
