# Feature Specification: Live WPM and Accuracy with Character-Based Metrics

**Feature Branch**: `DEATHN-22-live-wpm-and`  
**Created**: 2026-05-16  
**Status**: Draft  
**Input**: Ticket DEATHN-22: "Live WPM and accuracy with character-based metrics"

## Auto-Resolved Decisions

- **Decision**: Sliding window behavior during wave transitions — WPM window continues ticking during transition countdown; no new correct characters are added, so WPM naturally declines toward zero
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (score 1) — AUTO fallback triggered
- **Fallback Triggered?**: Yes — AUTO confidence < 0.5, promoted to CONSERVATIVE
- **Trade-offs**: WPM may visually dip during transitions, but this accurately reflects typing inactivity
- **Reviewer Notes**: Confirm that a declining WPM during the 3-second wave transition feels right; an alternative is to freeze the WPM display during transitions

---

- **Decision**: WPM display freezes at last computed value when game-over triggers — no further updates to the sliding window or smoothed display value
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Low (score 1) — AUTO fallback triggered
- **Fallback Triggered?**: Yes — AUTO promoted to CONSERVATIVE
- **Trade-offs**: Player sees their final WPM; no risk of confusing post-death decay
- **Reviewer Notes**: Verify this matches expected game-over screen behavior (WPM on game-over screen is out of scope per ticket)

---

- **Decision**: Smoothing formula uses per-frame interpolation (`displayed += 0.2 × (target - displayed)`) without delta-time normalization, acceptable given the fixed 60 FPS target
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Medium (score 3) — game already targets fixed frame rate
- **Fallback Triggered?**: No
- **Trade-offs**: If frame rate drops, smoothing speed changes proportionally; acceptable for a fixed-FPS game
- **Reviewer Notes**: If variable frame rate support is ever added, this formula should be updated to use delta-time

---

- **Decision**: Circular buffer overflow — when more than 512 correct-character timestamps exist in the buffer, oldest entries are silently overwritten per standard circular buffer semantics
- **Policy Applied**: CONSERVATIVE
- **Confidence**: High (score 5) — 512 entries for a 10-second window means >51 correct chars/second to overflow, which exceeds human typing speed
- **Fallback Triggered?**: No
- **Trade-offs**: None practical; the buffer size far exceeds realistic input rates
- **Reviewer Notes**: No action needed; 512 is well above any achievable typing rate

---

- **Decision**: Metrics reset scope on game restart — all WPM state (circular buffer, elapsed time), accuracy counters (correct_chars, wrong_chars), and smoothed display values reset to initial state when the player restarts
- **Policy Applied**: CONSERVATIVE
- **Confidence**: High (score 5) — ticket explicitly states "session-wide, reset au restart"
- **Fallback Triggered?**: No
- **Trade-offs**: None; fresh session means fresh metrics
- **Reviewer Notes**: Ensure reset covers all new state variables added by this feature

## User Scenarios & Testing

### User Story 1 - Live WPM Feedback (Priority: P1)

As a player, I see my current typing speed (WPM) updating in real time on the HUD so I can gauge my performance against the wave's target WPM.

**Why this priority**: WPM is the core metric for a typing game; it directly informs the player whether they are keeping up with the current wave difficulty.

**Independent Test**: Can be fully tested by typing zombie names during gameplay and verifying the WPM number in the top-right corner updates smoothly and matches expected values.

**Acceptance Scenarios**:

1. **Given** a fresh game start with no keypresses, **When** the first frame renders, **Then** the HUD displays "WPM 0" in the top-right area.
2. **Given** a game in progress for over 10 seconds, **When** the player has typed 60 correct characters in the last 10-second window, **Then** the HUD displays a WPM value converging toward 72.
3. **Given** a game in progress for only 5 seconds, **When** the player has typed 12 correct characters, **Then** the HUD displays a WPM value converging toward 29.
4. **Given** the player stops typing for 10+ seconds, **When** the sliding window empties, **Then** the WPM value smoothly declines toward 0.
5. **Given** a wave transition is in progress, **When** the 3-second countdown is active, **Then** the WPM continues to update (declining naturally since no new characters are typed).

---

### User Story 2 - Live Accuracy Feedback (Priority: P1)

As a player, I see my session accuracy percentage on the HUD so I know how precisely I am typing.

**Why this priority**: Accuracy is a fundamental typing metric and a key indicator of player skill; it directly affects combo maintenance.

**Independent Test**: Can be fully tested by typing a mix of correct and incorrect characters and verifying the accuracy percentage on the HUD matches the expected formula.

**Acceptance Scenarios**:

1. **Given** a fresh game start with no keypresses, **When** the first frame renders, **Then** the HUD displays "Acc 100%".
2. **Given** 100 correct and 4 incorrect characters typed during the session, **When** the HUD updates, **Then** the accuracy displays a value converging toward 96%.
3. **Given** the player types an incorrect character (no active zombie name matches), **When** the accuracy recalculates, **Then** accuracy decreases AND the combo counter resets to 0.
4. **Given** a wave transition occurs, **When** the next wave begins, **Then** accuracy retains its session-wide value (does not reset between waves).
5. **Given** the player restarts after game-over, **When** the new game begins, **Then** accuracy resets to 100%.

---

### User Story 3 - Smooth HUD Display (Priority: P2)

As a player, I experience WPM and accuracy changes as smooth visual transitions rather than jarring frame-to-frame jumps, making the HUD pleasant and readable.

**Why this priority**: Smoothing is a quality-of-life improvement that prevents visual noise; the metrics are still functional without it but harder to read.

**Independent Test**: Can be verified by watching WPM changes during gameplay — the displayed number should interpolate toward the target value rather than snapping instantly.

**Acceptance Scenarios**:

1. **Given** the target WPM changes from 0 to 72 in one frame, **When** subsequent frames render, **Then** the displayed WPM value increases incrementally per frame (20% of the gap per frame), not instantly.
2. **Given** the target accuracy drops from 100% to 96%, **When** subsequent frames render, **Then** the displayed accuracy decreases incrementally, not in a single jump.

---

### Edge Cases

- What happens when the player types only backspace keys? Backspace is ignored for stats; WPM and accuracy remain unchanged.
- What happens when a single keypress matches the next character for multiple active zombies simultaneously? Only one correct character is counted, not one per matching zombie.
- What happens at extremely high typing speed (> 200 WPM)? The circular buffer of 512 entries provides ample capacity for the 10-second window; no overflow risk at human typing speeds.
- What happens during game-over state? WPM and accuracy display values freeze at their last computed state; no further updates occur.
- What happens if the player types zero characters for an entire wave? WPM stays at 0, accuracy stays at 100% (the formula handles the zero-denominator case by defaulting to 100%).

## Requirements

### Functional Requirements

- **FR-001**: System MUST track each keypress as either "correct" (matches the next expected character of at least one active enemy, including bosses) or "incorrect" (matches no active enemy prefix).
- **FR-002**: System MUST ignore backspace keypresses for all WPM and accuracy calculations.
- **FR-003**: When multiple active enemies accept the same typed character, system MUST count exactly one correct character, not one per matching enemy.
- **FR-004**: System MUST maintain a circular buffer of 512 timestamps recording when each correct character was typed.
- **FR-005**: System MUST purge timestamps older than 10 seconds from the active window count each frame.
- **FR-006**: System MUST calculate WPM using a 10-second sliding window: `WPM = chars_in_window × 1.2` (where 1 word = 5 characters).
- **FR-007**: During the first 10 seconds of a game session, system MUST calculate WPM using elapsed time: `WPM = (total_correct_chars / 5) / (elapsed_seconds / 60)`.
- **FR-008**: System MUST maintain session-wide counters for correct characters and incorrect characters (u32).
- **FR-009**: System MUST calculate accuracy as `(correct_chars / (correct_chars + wrong_chars)) × 100`, rounded to the nearest integer.
- **FR-010**: When no characters have been typed (zero denominator), accuracy MUST display as 100%.
- **FR-011**: System MUST display WPM on the HUD at position top-right (x = screen_width − 100, y = 5), font size 18, color DARKGRAY, format "WPM {value}".
- **FR-012**: System MUST display accuracy on the HUD at position top-right (x = screen_width − 100, y = 30), font size 18, color DARKGRAY, format "Acc {value}%".
- **FR-013**: System MUST apply display smoothing: `displayed_value += 0.2 × (target_value − displayed_value)` each frame, for both WPM and accuracy.
- **FR-014**: When the player types an incorrect character, system MUST increment the wrong_chars counter AND reset the combo counter to 0.
- **FR-015**: All WPM and accuracy state (buffer, counters, smoothed display values, elapsed timer) MUST reset to initial values when the player restarts the game.
- **FR-016**: Accuracy MUST persist across wave transitions without resetting.
- **FR-017**: The four reference cases MUST pass as unit tests:
  - 60 correct characters in 10 seconds → WPM = 72
  - 12 correct characters in 5 seconds (early game) → WPM = 29
  - 100 correct + 4 incorrect → accuracy = 96%
  - 0 keypresses → WPM = 0, accuracy = 100%

### Key Entities

- **Correct Character Timestamp**: A record of when a correct character was typed, stored in a fixed-size circular buffer; used to compute the 10-second sliding window for WPM.
- **Session Metrics**: A pair of cumulative counters (correct characters, incorrect characters) spanning the entire game session from start to restart; used to compute accuracy.
- **Smoothed Display Value**: An interpolated representation of a metric (WPM or accuracy) that converges toward the true computed value at a fixed rate per frame; used to prevent visual jitter on the HUD.

## Success Criteria

### Measurable Outcomes

- **SC-001**: All four reference WPM and accuracy test cases pass in the automated test suite.
- **SC-002**: The WPM display value changes by no more than 20% of the remaining gap per frame, confirming smoothing is active and preventing frame-to-frame jumps.
- **SC-003**: After an incorrect keypress, the accuracy percentage decreases and the combo counter resets to 0 within the same frame.
- **SC-004**: Accuracy retains its session value through at least one complete wave transition without resetting.
- **SC-005**: After a game restart, WPM displays 0 and accuracy displays 100% on the first frame of the new session.

## Assumptions

- The game continues to target a fixed 60 FPS frame rate; the smoothing formula does not use delta-time normalization.
- The existing combo reset on mismatch (`typedMatchesAnyEnemy` returning false) will be extended to also increment the wrong_chars counter; no separate mismatch detection is needed.
- The existing input handling (ASCII 32–125 filtering, backspace handling) remains unchanged; WPM/accuracy tracking hooks into the same code path.
- The 10-second sliding window uses wall-clock game time (raylib frame time accumulation), not real-time clock.

## Out of Scope

- Displaying WPM or accuracy on the game-over screen.
- Calculating or displaying average WPM for the full session at end of game.
- Persisting metrics across multiple game sessions (history).
