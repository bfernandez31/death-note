# Feature Specification: Boss Zombie Every Five Waves with Phrase Typing

**Feature Branch**: `DEATHN-20-boss-zombie-every`
**Created**: 2026-05-16
**Status**: Draft
**Input**: Ticket DEATHN-20: "Boss zombie every five waves with phrase typing"

## Auto-Resolved Decisions

### ARD-1: Input buffer state on boss spawn

- **Decision**: When the boss spawns mid-wave, the player's current input buffer is NOT cleared. Any previously typed characters are preserved.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket is silent on this edge case
- **Fallback Triggered?**: Yes — AUTO confidence below 0.5, promoted to CONSERVATIVE
- **Trade-offs**: Preserving input avoids frustrating the player mid-word; may cause brief confusion if partially typed text no longer matches any target.
- **Reviewer Notes**: If playtesting reveals the leftover text is confusing, consider clearing the buffer on boss spawn instead.

### ARD-2: Typed-portion visual feedback on boss phrase

- **Decision**: The boss phrase is displayed in full above the sprite at all times. No per-character highlighting of typed progress; the health bar alone communicates typing progress.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket specifies font/color for the phrase but not per-character feedback
- **Fallback Triggered?**: Yes — AUTO confidence below 0.5, promoted to CONSERVATIVE
- **Trade-offs**: Simpler display reduces implementation risk; players rely on the health bar for progress feedback rather than inline character highlighting.
- **Reviewer Notes**: Per-character highlighting (e.g., dimming typed letters) could improve UX in a future iteration.

### ARD-3: Game restart resets all boss state

- **Decision**: When the player presses Enter to restart after game over, all boss-related state (boss alive flag, boss spawned flag, extended input limit) resets to defaults alongside the existing game state reset.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket does not explicitly mention restart behavior for boss state
- **Fallback Triggered?**: Yes — AUTO confidence below 0.5, promoted to CONSERVATIVE
- **Trade-offs**: Full reset ensures a clean slate; no risk of stale boss state leaking into a new game.
- **Reviewer Notes**: Straightforward extension of the existing restart logic; low risk.

## User Scenarios & Testing

### User Story 1 - Boss Encounter on Wave 5 (Priority: P1)

A player progresses through the first four waves of standard zombies. Upon reaching wave 5 and killing the 7th zombie (out of 13 in the pool), a visually distinct boss zombie appears at the center of the screen. The boss is larger (double the normal scale) and tinted red, making it immediately recognizable. A multi-word phrase is displayed above the boss, and a health bar appears beneath the phrase. The player must type the entire phrase (including spaces) to defeat the boss.

**Why this priority**: Core boss mechanic — without this, the feature does not exist.

**Independent Test**: Start a game, survive to wave 5, kill 7 zombies, and verify the boss spawns with correct visual treatment and phrase display.

**Acceptance Scenarios**:

1. **Given** the player is on wave 5 (pool_size = 13) and has killed 6 zombies, **When** the player kills the 7th zombie, **Then** a boss zombie spawns at the horizontal center of the screen with a random phrase from the boss phrase list displayed above it in dark red, font size 20.
2. **Given** the player is on wave 5 and has killed fewer than 7 zombies, **When** the player kills a zombie, **Then** no boss spawns.
3. **Given** the player is on wave 10 (pool_size = 23), **When** the player kills the 12th zombie (ceil(23/2)), **Then** a boss zombie spawns following the same rules.

---

### User Story 2 - Typing a Boss Phrase to Kill the Boss (Priority: P1)

While the boss is active, the input buffer extends to 35 characters so the player can type the full phrase. The player types the boss phrase character by character (including spaces). As each correct character is typed, the health bar above the boss shrinks proportionally. When the full phrase is typed, the boss is destroyed, the input buffer clears, and the character limit returns to 9.

**Why this priority**: Inseparable from the boss encounter — the boss must be killable.

**Independent Test**: With the boss on screen, type the displayed phrase and verify the health bar depletes and the boss is destroyed.

**Acceptance Scenarios**:

1. **Given** a boss is active with phrase "the dead walk again" (19 characters), **When** the player types the first character "t", **Then** the health bar fill decreases to 18/19 of its full width.
2. **Given** a boss is active, **When** the player types the complete phrase correctly, **Then** the boss is destroyed, a kill sound plays, the input buffer clears, and the input character limit returns to 9.
3. **Given** a boss is active, **When** the player presses backspace, **Then** the last typed character is removed and the health bar fill increases accordingly.

---

### User Story 3 - Boss Priority Over Regular Zombies (Priority: P2)

While the boss is active, regular zombies continue to fall. If the player's typed input simultaneously matches the prefix of the boss phrase AND the name of an active regular zombie, the boss takes priority — the regular zombie is not killed until the boss is dealt with or the input changes.

**Why this priority**: Prevents confusing behavior where typing the boss phrase accidentally kills regular zombies.

**Independent Test**: With both a boss and a regular zombie whose name matches the start of the boss phrase on screen, type that matching prefix and verify the regular zombie is not killed.

**Acceptance Scenarios**:

1. **Given** a boss with phrase "bones remember every step" is active AND a regular zombie is on screen, **When** the player types the full boss phrase, **Then** only the boss is killed (the regular zombie remains).
2. **Given** a boss is active AND the player's input exactly matches a regular zombie's name, **When** that input is also a valid prefix of the boss phrase, **Then** the regular zombie is NOT killed; the boss match takes priority.
3. **Given** no boss is active, **When** the player types a regular zombie's name, **Then** the regular zombie is killed as normal (no boss priority logic applies).

---

### User Story 4 - Wave Completion Requires Boss Kill (Priority: P2)

On boss waves (multiples of 5), the wave does not end when all pool zombies are killed. The wave only completes when both the entire pool AND the boss are defeated. This prevents the player from skipping the boss challenge.

**Why this priority**: Enforces the boss as a mandatory challenge within boss waves.

**Independent Test**: Kill all 13 pool zombies on wave 5 without killing the boss, and verify the wave does not transition.

**Acceptance Scenarios**:

1. **Given** wave 5 with all 13 pool zombies killed but the boss still alive, **When** no further action is taken, **Then** the wave does NOT transition to wave 6.
2. **Given** wave 5 with all 13 pool zombies killed, **When** the player kills the boss, **Then** the wave transition countdown begins.
3. **Given** wave 5 with the boss killed but 2 pool zombies remaining, **When** the player kills the last 2 pool zombies, **Then** the wave transition countdown begins.

---

### User Story 5 - Boss Reaches Bottom Causes Game Over (Priority: P2)

If the boss zombie falls to the bottom of the screen, the game ends immediately, just like a regular zombie reaching the bottom. The boss falls at half the wave's normal fall speed, giving the player more time.

**Why this priority**: Maintains game-over consistency and establishes the boss as a slower but mandatory threat.

**Independent Test**: Allow the boss to fall without typing, and verify game over triggers when it reaches the bottom.

**Acceptance Scenarios**:

1. **Given** a boss is falling at 0.5x the wave's fall speed, **When** the boss reaches the bottom of the screen, **Then** game over is triggered immediately.
2. **Given** a boss is falling, **When** a regular zombie reaches the bottom before the boss, **Then** game over is triggered by the regular zombie (standard behavior unchanged).

---

### Edge Cases

- What happens when the boss spawns while the player has characters in the input buffer? The input is preserved (ARD-1); the buffer limit extends to 35 characters.
- What happens if the player restarts the game during a boss wave? All boss state resets completely (ARD-3).
- What happens on wave 5 if the 7th kill and a zombie reaching the bottom occur in the same frame? Game over takes precedence (consistent with existing behavior).
- Can a boss spawn on dynamically scaled waves (wave 20, 25, etc.)? Yes — any wave where `wave_number % 5 == 0` triggers a boss, including waves beyond the static wave table.
- What if the boss phrase contains characters outside the printable ASCII range (32-125)? All 10 phrases use only lowercase letters and spaces, which are within the accepted input range.

## Requirements

### Functional Requirements

- **FR-001**: The system MUST spawn exactly one boss zombie on every wave that is a multiple of 5 (waves 5, 10, 15, 20, ...).
- **FR-002**: The boss MUST spawn when the number of pool kills reaches ceil(pool_size / 2) for the current wave.
- **FR-003**: The boss MUST appear at the horizontal center of the screen, starting at the top (y = 0).
- **FR-004**: The boss MUST fall at exactly 0.5x the current wave's fall speed.
- **FR-005**: The boss MUST be rendered using the standard zombie sprite at 0.4 scale (double the normal 0.2 scale) with a red tint.
- **FR-006**: The boss MUST display a randomly selected phrase from the predefined list of 10 phrases, rendered in font size 20, color dark red, positioned above the sprite.
- **FR-007**: A health bar (200x8 pixels) MUST be displayed below the boss phrase text, with light gray background, red fill, and 1-pixel dark gray border.
- **FR-008**: The health bar fill MUST represent the ratio of remaining untyped characters to total phrase length, decreasing as the player types correctly.
- **FR-009**: While a boss is active, the input buffer character limit MUST extend to 35 characters.
- **FR-010**: When the player's typed input matches both a boss phrase prefix and a regular zombie name, the boss MUST take priority (regular zombie is not killed).
- **FR-011**: When the boss is killed (full phrase typed), the input buffer MUST clear and the character limit MUST revert to 9.
- **FR-012**: A boss wave MUST NOT complete until both the entire zombie pool AND the boss are defeated.
- **FR-013**: If the boss reaches the bottom of the screen, the game MUST end immediately (game over).
- **FR-014**: On game restart, all boss-related state MUST reset to defaults.
- **FR-015**: The boss phrase list MUST contain exactly 10 phrases, all lowercase with spaces, with the longest phrase fitting within the 35-character input limit.
- **FR-016**: No more than one boss may be active at any time.
- **FR-017**: All boss memory allocations MUST be properly freed on boss kill, wave reset, and game restart, with no memory leaks.

### Key Entities

- **Boss Zombie**: A special zombie that appears on every 5th wave. Distinguished by larger scale (0.4), red tint, a multi-word phrase instead of a single name, and a visible health bar. Falls at half the normal wave speed. One boss per boss wave, spawned at the 50% kill threshold.
- **Boss Phrase**: A lowercase multi-word string (up to 35 characters, including spaces) randomly selected from a fixed pool of 10 phrases. Serves as the "name" the player must type to kill the boss.
- **Boss Health Bar**: A visual indicator (200x8 pixels) showing remaining typing progress. Fill ratio = remaining characters / total characters.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Players can visually identify a boss zombie within 1 second of it appearing, due to distinct size and color treatment.
- **SC-002**: Players can defeat the boss by typing the displayed phrase with 100% character accuracy, with the health bar reflecting progress in real time.
- **SC-003**: Boss waves (every 5th wave) take measurably longer than adjacent non-boss waves, confirming the boss adds meaningful challenge.
- **SC-004**: Zero game state corruption after completing 3 consecutive boss waves (waves 5, 10, 15) — wave transitions, kill counts, and input state all function correctly.
- **SC-005**: Zero memory leaks across a full play session that includes boss spawns, boss kills, boss game-overs, and game restarts.
- **SC-006**: The input buffer correctly accepts up to 35 characters during boss encounters and reverts to 9 characters after boss defeat, with no truncation or overflow.
