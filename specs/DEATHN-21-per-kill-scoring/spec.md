# Feature Specification: Per-kill scoring formula with combo and HUD

**Feature Branch**: `DEATHN-21-per-kill-scoring`  
**Created**: 2026-05-16  
**Status**: Draft  
**Input**: Ticket DEATHN-21 — Per-kill scoring formula with combo and HUD

## Auto-Resolved Decisions

- **Decision**: Score resets to zero on game restart
- **Policy Applied**: CONSERVATIVE (via AUTO fallback)
- **Confidence**: Low (score 0.3 — game feature, no compliance/security signals, absScore 1)
- **Fallback Triggered?**: Yes — AUTO confidence < 0.5, promoted to CONSERVATIVE
- **Trade-offs**: Safe default avoids unintended score carry-over between sessions; persistent high-score tracking is explicitly out of scope.
- **Reviewer Notes**: If score carry-over across restarts is desired in a future ticket, this decision must be revisited.

---

- **Decision**: Score is displayed on the game-over screen alongside existing wave/WPM info
- **Policy Applied**: CONSERVATIVE (via AUTO fallback)
- **Confidence**: Low (score 0.3)
- **Fallback Triggered?**: Yes — ticket does not specify game-over screen score display; conservative default provides it for completeness.
- **Trade-offs**: Adds one line of information on an existing screen; no visual clutter risk at this scope. Ticket marks "game-over screen enrichi" as out of scope — this is the minimal addition (score value only).
- **Reviewer Notes**: Verify this minimal display doesn't conflict with the out-of-scope "enriched game-over screen" planned for a future ticket.

---

- **Decision**: Combo HUD line is always visible, even when combo count is zero
- **Policy Applied**: CONSERVATIVE (via AUTO fallback)
- **Confidence**: Low (score 0.3)
- **Fallback Triggered?**: Yes — ticket specifies HUD format but not visibility at combo 0.
- **Trade-offs**: Consistent HUD layout prevents visual shifting; "Combo: 0 x1" is technically accurate. Slight visual noise when combo is 0.
- **Reviewer Notes**: Confirm the always-visible approach is acceptable or if hiding at combo 0 is preferred.

---

- **Decision**: Boss prefix matching is included when determining whether a typed letter matches any active enemy (combo reset check)
- **Policy Applied**: CONSERVATIVE (via AUTO fallback)
- **Confidence**: Low (score 0.3)
- **Fallback Triggered?**: Yes — ticket says "aucun zombie actif" which could exclude the boss; conservative includes all active enemies.
- **Trade-offs**: Prevents unfair combo resets while typing a boss phrase (player-friendly). Without this, long boss phrases would almost certainly trigger false combo resets.
- **Reviewer Notes**: Validate that boss phrase prefix checking participates in the "does any enemy match?" logic.

## User Scenarios & Testing

### User Story 1 — Scoring on zombie kill (Priority: P1)

A player types a zombie's name correctly and kills it. The system calculates a score based on the zombie's name length, vertical position, enemy type, and current combo multiplier, then adds it to the running total displayed on screen.

**Why this priority**: Core scoring is the foundational mechanic; all other stories depend on accurate per-kill score calculation.

**Independent Test**: Kill a single standard zombie at a known position with combo at 0 and verify the displayed score matches the formula. Repeat with different positions and combo values.

**Acceptance Scenarios**:

1. **Given** a standard zombie named "Alex" (4 characters) at vertical position 0 with combo count 0, **When** the player types "Alex" and the zombie is killed, **Then** the score increases by exactly 40.
2. **Given** a standard zombie named "Alex" at vertical position 0 with combo count 20, **When** the player types "Alex" and the zombie is killed, **Then** the score increases by exactly 200.
3. **Given** a standard zombie named "Alex" at vertical position 440 (near the bottom of the 450-high screen) with combo count 0, **When** the player types "Alex" and the zombie is killed, **Then** the score increases by exactly 138.
4. **Given** a boss zombie with the phrase "the dead walk again" (19 characters) at vertical position 300 with combo count 10, **When** the player completes the phrase, **Then** the score increases by exactly 2313.

---

### User Story 2 — Combo counter progression and reset (Priority: P1)

The combo counter increments by 1 each time the player kills any enemy (standard or boss). The combo resets to 0 when the player types a character that does not match the beginning of any active enemy's name, or when a wave transition begins.

**Why this priority**: Combo directly multiplies scoring; incorrect combo tracking invalidates all score calculations.

**Independent Test**: Kill several zombies in sequence and verify the combo counter increments. Type an incorrect character and verify the combo resets to 0. Start a new wave and verify the combo resets to 0.

**Acceptance Scenarios**:

1. **Given** combo is at 0, **When** the player kills a zombie, **Then** combo becomes 1.
2. **Given** combo is at 4, **When** the player kills another zombie, **Then** combo becomes 5 and the multiplier changes from x1 to x2.
3. **Given** combo is at 12, **When** the player types a character that does not match the prefix of any active enemy (including boss), **Then** combo resets to 0 and multiplier returns to x1.
4. **Given** combo is at 8, **When** a wave transition begins, **Then** combo resets to 0.
5. **Given** the player uses backspace, **When** the input buffer shrinks, **Then** combo does NOT reset (backspace is not a mismatch).

---

### User Story 3 — HUD display (Priority: P2)

The player sees a persistent heads-up display showing their current score and combo information. The score line appears at the top-left of the screen. The combo line appears below the score line and changes color based on the current combo tier.

**Why this priority**: Without the HUD, scoring and combo are invisible to the player. This is the primary feedback mechanism.

**Independent Test**: Start a game and verify both HUD lines are visible. Kill enemies to raise the combo through each tier and verify the combo line color changes at the defined thresholds.

**Acceptance Scenarios**:

1. **Given** the game is running and not in game-over state, **When** the player looks at the screen, **Then** the score is displayed at position (10, 5) in font size 24, in dark green, formatted as "Score: {value}".
2. **Given** the game is running, **When** the player looks below the score, **Then** the combo is displayed at position (10, 35) in font size 18, formatted as "Combo: {count} x{multiplier}".
3. **Given** combo count is below 5, **When** the combo line renders, **Then** it uses a dark gray color.
4. **Given** combo count is between 5 and 14 (inclusive), **When** the combo line renders, **Then** it uses an orange color.
5. **Given** combo count is 15 or above, **When** the combo line renders, **Then** it uses a red color.

---

### User Story 4 — Floating score popup (Priority: P2)

When a zombie or boss is killed, a floating text popup appears at the enemy's position showing the points earned. The popup rises upward and fades out over half a second.

**Why this priority**: Provides immediate, contextual feedback on each kill's value, reinforcing the combo/height incentives.

**Independent Test**: Kill a zombie and verify the popup shows "+{score}" at the zombie's position, moves upward by 30 pixels, and fades to invisible over 0.5 seconds.

**Acceptance Scenarios**:

1. **Given** the player kills a zombie worth 138 points, **When** the kill registers, **Then** a popup reading "+138" appears at the zombie's screen position in gold color, font size 20.
2. **Given** a popup has just appeared, **When** 0.25 seconds have elapsed, **Then** the popup has moved up approximately 15 pixels and its opacity is approximately 50%.
3. **Given** a popup has just appeared, **When** 0.5 seconds have elapsed, **Then** the popup is fully transparent and no longer visible.
4. **Given** 32 popups are active, **When** a 33rd kill occurs, **Then** the oldest popup is recycled (overwritten) by the new one.

---

### User Story 5 — Score shown on game-over screen (Priority: P3)

When the game ends, the final score is displayed on the game-over screen alongside the existing wave-reached and required-WPM information.

**Why this priority**: Players need closure on their performance; without this, the score disappears when they die.

**Independent Test**: Play until a zombie reaches the bottom and verify the game-over screen shows the final score value.

**Acceptance Scenarios**:

1. **Given** the player has accumulated 5000 points, **When** a zombie reaches the bottom of the screen, **Then** the game-over screen displays "Score: 5000" alongside the wave and WPM info.
2. **Given** the player presses Enter to restart after game over, **When** the new game begins, **Then** the score resets to 0.

---

### Edge Cases

- What happens when a zombie is killed at the very bottom of the screen (y near screen_height)? The height_score component reaches its maximum (~100), yielding the highest possible per-kill base score for that name length.
- What happens when multiple zombies are killed in rapid succession? Each kill increments the combo independently; popups from earlier kills continue their fade animation while new ones appear.
- What happens when the popup pool is full and kills happen faster than the 0.5s fade? Circular recycling overwrites the oldest popup, which may still be partially visible — this is acceptable.
- What happens when the combo multiplier changes mid-wave? The new multiplier applies to the very next kill; there is no buffering or delay.
- What happens to the score when it approaches the maximum u64 value? The score is stored as a 64-bit unsigned integer, supporting values up to 18.4 quintillion — overflow is practically unreachable in normal gameplay.

## Requirements

### Functional Requirements

- **FR-001**: System MUST calculate per-kill score using the formula: `round((name_length × 10 + round(100 × (y_position / screen_height))) × type_multiplier) × combo_multiplier`, where type_multiplier is 3.0 for boss enemies and 1.0 for standard zombies.
- **FR-002**: System MUST maintain a combo counter that increments by 1 on each kill (standard or boss).
- **FR-003**: System MUST reset the combo counter to 0 when a typed character does not match the prefix of any active enemy's name (including boss phrase), or when a wave transition begins.
- **FR-004**: System MUST apply combo multiplier tiers: x1 for combo 0–4, x2 for combo 5–9, x3 for combo 10–14, x4 for combo 15–19, x5 for combo 20+.
- **FR-005**: System MUST display the running score at screen position (10, 5), font size 24, in dark green, formatted as "Score: {value}".
- **FR-006**: System MUST display the combo counter and current multiplier at screen position (10, 35), font size 18, formatted as "Combo: {count} x{multiplier}".
- **FR-007**: System MUST color the combo HUD line dark gray when combo < 5, orange when 5 ≤ combo < 15, and red when combo ≥ 15.
- **FR-008**: System MUST show a floating popup at the killed enemy's position displaying "+{score}" in gold, font size 20, that rises 30 pixels and fades from full opacity to invisible over 0.5 seconds with linear interpolation.
- **FR-009**: System MUST maintain a fixed pool of 32 popup slots with circular recycling (oldest slot reused when pool is full).
- **FR-010**: System MUST store the score as a 64-bit unsigned integer.
- **FR-011**: System MUST reset the score to 0 when the player restarts the game after game over.
- **FR-012**: System MUST display the final score on the game-over screen.
- **FR-013**: System MUST produce the exact scores defined in the reference test cases: Case 1 = 40, Case 2 = 200, Case 3 = 138, Case 4 = 2313.
- **FR-014**: System MUST NOT reset the combo when the player uses backspace.

### Key Entities

- **Score**: A cumulative 64-bit unsigned integer representing the player's total points earned across all kills in the current game session. Resets to zero on game restart.
- **Combo Counter**: An integer tracking consecutive successful kills without a mismatch. Determines the active combo multiplier tier. Resets on mismatch or wave transition.
- **Score Popup**: A temporary visual element tied to a kill event. Has a screen position (inherited from the killed enemy), a text value ("+{points}"), a lifetime (0.5 seconds), and an opacity (decreasing linearly from full to zero). Managed in a fixed-size circular pool of 32 entries.

### Assumptions

- The screen height used in the scoring formula is the game window's fixed height (currently 450 pixels). If the window size changes in a future ticket, the formula must use the active screen height.
- "Name length" for standard zombies is the character count of the displayed name. For boss enemies, it is the character count of the full boss phrase.
- The combo counter is a single global value shared across all enemy types within a game session.
- Rounding uses standard mathematical rounding (round half away from zero) as provided by the runtime's standard round function.

## Success Criteria

### Measurable Outcomes

- **SC-001**: All four reference test cases produce the exact expected score values (40, 200, 138, 2313) in automated unit tests.
- **SC-002**: The combo counter increments by exactly 1 per kill and resets to 0 on mismatch or wave transition, verified by unit tests.
- **SC-003**: The HUD score and combo lines are visible at all times during active gameplay, positioned and formatted as specified.
- **SC-004**: The combo HUD color changes at the correct tier thresholds (0–4 dark gray, 5–14 orange, 15+ red), visually verified.
- **SC-005**: Score popups appear at the killed enemy's position, rise 30 pixels, and fade out completely within 0.5 seconds.
- **SC-006**: The popup pool handles more than 32 concurrent kills without crashes or visual artifacts, recycling the oldest entry.
- **SC-007**: The score is stored as a 64-bit unsigned integer, supporting values well beyond any realistic gameplay session.
- **SC-008**: The final score is displayed on the game-over screen and resets to 0 on restart.
