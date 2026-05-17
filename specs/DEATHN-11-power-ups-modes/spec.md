# Feature Specification: Power-ups, Game Modes & Main Menu

**Feature Branch**: `DEATHN-11-power-ups-modes`
**Created**: 2026-05-17
**Status**: Draft
**Input**: Ticket DEATHN-11 — Power-ups, modes de jeu alternatifs et menu principal

## Auto-Resolved Decisions

### ARD-1: Freeze duration

- **Decision**: Freeze power-up freezes all zombies for 3 seconds
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket says "quelques secondes" without a precise value
- **Fallback Triggered?**: Yes — AUTO confidence too low; CONSERVATIVE chosen to avoid an overpowered freeze
- **Trade-offs**: 3 seconds is short enough to prevent trivializing waves, but long enough to provide meaningful relief during surges
- **Reviewer Notes**: Playtest whether 3s feels too short on high waves (10+); adjust if needed

### ARD-2: Power-up drop probability

- **Decision**: Power-ups drop on kill with a 10% base probability; only one power-up type is offered per drop (randomly selected among Freeze, Bomb, Shield with equal weight)
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket says "faible probabilité" without a number
- **Fallback Triggered?**: Yes — CONSERVATIVE fallback applied to keep power-ups feeling rare but not frustrating
- **Trade-offs**: 10% means roughly one drop every 10 kills; too high devalues power-ups, too low frustrates new players
- **Reviewer Notes**: Validate that average time between drops feels rewarding in waves 1-5 and 10+

### ARD-3: Power-up activation key

- **Decision**: Power-ups are activated by pressing the Space bar (dedicated key, separate from the typing input)
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket says "touche dédiée" without specifying which key
- **Fallback Triggered?**: Yes — Space bar is the most discoverable key that doesn't conflict with typing input or Escape (pause)
- **Trade-offs**: Space bar is intuitive but may cause accidental activation; Tab was considered but is less discoverable
- **Reviewer Notes**: Verify Space doesn't conflict with any existing typing mechanic or boss input

### ARD-4: Shield behavior scope

- **Decision**: Shield absorbs exactly one zombie reaching the bottom, then is consumed. The zombie that triggers the shield is destroyed (not just ignored). Shield does not stack.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket says "encaisse un zombie" but doesn't clarify if zombie is destroyed or passes through
- **Fallback Triggered?**: Yes — destroying the zombie provides clearer visual feedback and prevents confusion
- **Trade-offs**: Single-use is conservative but fair; multi-use would trivialize survival on later waves
- **Reviewer Notes**: Confirm the shield-consumed animation/feedback is distinct from a normal kill

### ARD-5: Zen mode WPM target selection

- **Decision**: Zen mode offers 3 preset WPM targets (30, 50, 80 WPM) selectable from a sub-menu before starting. The spawn rate and fall speed are derived from the selected WPM using the same formula as wave configs.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket mentions "possibilité de choisir un WPM cible" without specifying UI for selection
- **Fallback Triggered?**: Yes — preset tiers are safer than free-form numeric input in a keyboard-driven game
- **Trade-offs**: Presets limit flexibility but avoid the need for a numeric input widget; 3 tiers cover beginner/intermediate/advanced
- **Reviewer Notes**: Consider adding a 4th tier or allowing custom WPM if playtesting reveals gaps

### ARD-6: Bomb interaction with boss

- **Decision**: Bomb kills all standard zombies on screen but does NOT affect an active boss. Boss damage remains typing-only.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket doesn't mention boss interaction with power-ups
- **Fallback Triggered?**: Yes — allowing Bomb to one-shot a boss would trivialize boss encounters
- **Trade-offs**: Protects boss fight integrity but may frustrate players who expect Bomb to clear everything
- **Reviewer Notes**: Ensure HUD or visual feedback communicates that the boss was unaffected by the bomb

### ARD-7: Power-ups availability in Zen mode

- **Decision**: Power-ups are disabled in Zen mode. Zen mode is a pure typing practice environment with no tactical resource management.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket doesn't specify whether power-ups apply to Zen mode
- **Fallback Triggered?**: Yes — Zen is described as a training mode; power-ups add tactical complexity that conflicts with the "just practice" goal
- **Trade-offs**: Keeps Zen mode simple and focused; some players may want power-ups for fun even in non-competitive mode
- **Reviewer Notes**: If users request power-ups in Zen, it can be added later without breaking the core design

### ARD-8: Menu navigation model

- **Decision**: Main menu uses vertical keyboard navigation (Up/Down arrows to highlight, Enter to select). No mouse support. Escape during gameplay pauses and shows a pause overlay with "Resume" and "Quit to Menu" options (same keyboard navigation).
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket says "navigable au clavier" without specifying navigation keys
- **Fallback Triggered?**: Yes — arrow keys + Enter is the most conventional keyboard menu navigation
- **Trade-offs**: No mouse support is consistent with the keyboard-only game design; arrow navigation is universally understood
- **Reviewer Notes**: Verify arrow key input doesn't leak into the typing buffer when transitioning from menu to gameplay

### ARD-9: High score file format for multiple modes

- **Decision**: Each game mode stores its own high score record in a separate persistent storage location. Survival and Zen high scores are stored independently to avoid collisions, on both native and web platforms.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket says "chaque mode conserve son propre meilleur score" without specifying storage strategy
- **Fallback Triggered?**: Yes — separate files avoid corrupting existing high score data and keep the format simple
- **Trade-offs**: Multiple files are slightly more complex but avoid breaking backward compatibility with existing saves
- **Reviewer Notes**: Ensure existing `highscore.dat` is not overwritten or invalidated by the new multi-mode system

### ARD-10: Power-up carrier visual indicator

- **Decision**: A zombie carrying a power-up displays a small colored icon (matching the power-up type) floating above its name label. The icon pulses gently to draw attention. On kill, the power-up pickup is confirmed by a brief flash effect on the HUD inventory slot.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket says "effet visuel" without specifying what kind
- **Fallback Triggered?**: Yes — an icon above the name is the least intrusive approach that doesn't obscure the zombie's name (critical for gameplay)
- **Trade-offs**: Icon-based approach requires rendering small glyphs (can use text symbols); more elaborate particle effects would require new assets
- **Reviewer Notes**: Verify the power-up icon doesn't overlap with the zombie name text or obscure readability

## User Scenarios & Testing

### User Story 1 - Survival Mode with Power-ups (Priority: P1)

A player launches the game, selects "Survival" from the main menu, and plays the existing wave-based mode. During gameplay, some killed zombies drop power-ups. The player sees a glowing icon above carrier zombies, and upon killing one, the power-up appears in their HUD inventory slot. The player presses Space to activate it at a strategic moment — freezing all zombies, bombing the screen, or absorbing a fatal zombie with a shield.

**Why this priority**: This is the core new mechanic layered onto the existing (and most important) game mode. Power-ups add tactical depth without changing the fundamental typing gameplay.

**Independent Test**: Can be tested by playing Survival mode; verify power-ups drop, display in HUD, and activate correctly with Space bar.

**Acceptance Scenarios**:

1. **Given** the player is in Survival mode and kills a zombie carrying a power-up, **When** the zombie dies, **Then** the power-up is added to the player's inventory slot and its icon appears in the HUD.
2. **Given** the player has a Freeze power-up in inventory, **When** they press Space, **Then** all active zombies stop moving for 3 seconds, the freeze timer is visible, and zombies resume normal speed afterward.
3. **Given** the player has a Bomb power-up in inventory, **When** they press Space, **Then** all active standard zombies are destroyed instantly, score is awarded for each, and the boss (if present) is unaffected.
4. **Given** the player has a Shield power-up active, **When** a zombie reaches the bottom of the screen, **Then** the shield absorbs the hit, the zombie is destroyed, the shield is consumed, and the game continues without triggering game over.
5. **Given** the player already has a power-up in inventory, **When** they kill another carrier zombie, **Then** the new power-up is NOT picked up (the existing one is kept) and the drop is lost.
6. **Given** the player has no power-up in inventory, **When** they press Space, **Then** nothing happens (no error, no feedback disruption).

---

### User Story 2 - Main Menu & Pause (Priority: P1)

A player launches the game and sees a main menu with options: "Survival", "Zen", and "Quit". They navigate with Up/Down arrows and select with Enter. During gameplay, pressing Escape pauses the game and shows a pause overlay with "Resume" and "Quit to Menu". The main menu displays the best score for the last mode played.

**Why this priority**: The menu is the entry point for all other features (game modes, options). Without it, players cannot access Zen mode or return to the menu mid-game.

**Independent Test**: Can be tested by launching the game, navigating the menu, starting a mode, pausing, resuming, and quitting to menu.

**Acceptance Scenarios**:

1. **Given** the game is launched, **When** the window opens, **Then** the main menu is displayed with "Survival", "Zen", and "Quit" options, with the first option highlighted.
2. **Given** the main menu is displayed, **When** the player presses Down arrow, **Then** the highlight moves to the next menu item; Up arrow moves it back.
3. **Given** the player highlights "Survival" and presses Enter, **When** the game loads, **Then** Survival mode begins (wave 1, empty input buffer, score 0).
4. **Given** the player is in any game mode, **When** they press Escape, **Then** the game pauses (no zombie movement, no input processing, no timers advancing) and a pause overlay appears with "Resume" and "Quit to Menu".
5. **Given** the pause overlay is shown, **When** the player selects "Resume", **Then** gameplay resumes exactly where it was paused.
6. **Given** the pause overlay is shown, **When** the player selects "Quit to Menu", **Then** the current session ends (no high score save unless beaten) and the main menu is displayed.
7. **Given** a previous Survival session achieved a high score, **When** the main menu is displayed, **Then** the best score for Survival mode is shown on the menu screen.

---

### User Story 3 - Zen Mode (Priority: P2)

A player who wants to practice typing without competitive pressure selects "Zen" from the main menu. They choose a target WPM tier (30, 50, or 80 WPM). Zombies spawn at a constant rate matching their chosen WPM. There is no game over — zombies that reach the bottom simply disappear. Live stats (WPM, accuracy) are shown but no competitive score is tracked. The player can pause and return to the menu at any time.

**Why this priority**: Zen mode expands the audience to include typing learners and casual players, but depends on the menu system (P1) being in place first.

**Independent Test**: Can be tested by selecting Zen mode, choosing a WPM target, typing, observing that no game over occurs, and verifying live stats.

**Acceptance Scenarios**:

1. **Given** the player selects "Zen" from the main menu, **When** the Zen sub-menu loads, **Then** three WPM target options are displayed: 30 WPM, 50 WPM, and 80 WPM.
2. **Given** the player selects 50 WPM, **When** gameplay starts, **Then** zombies spawn at a rate and speed calibrated to require approximately 50 words per minute to keep up.
3. **Given** a zombie reaches the bottom of the screen in Zen mode, **When** it crosses the threshold, **Then** the zombie disappears without triggering game over or dying state.
4. **Given** the player is typing in Zen mode, **When** they look at the HUD, **Then** live WPM and accuracy percentages are displayed and update in real time.
5. **Given** the player is in Zen mode, **When** they press Escape, **Then** the game pauses with the same pause overlay as Survival mode.
6. **Given** the player finishes a Zen session, **When** they quit to menu, **Then** no competitive score is saved, but accuracy and WPM stats are preserved as Zen high score if they are the best recorded.

---

### User Story 4 - Per-Mode High Scores (Priority: P2)

The game maintains separate high scores for Survival and Zen modes. When a Survival session ends with a new best score, it is persisted. Zen mode tracks best WPM and accuracy per session. The main menu shows the high score for the most recently played mode.

**Why this priority**: High score persistence per mode builds on the existing high score system and is a natural complement to multi-mode support.

**Independent Test**: Can be tested by playing each mode, achieving scores, restarting the game, and verifying persistence.

**Acceptance Scenarios**:

1. **Given** the player achieves a new high score in Survival mode, **When** the game-over screen displays, **Then** the new high score is shown with a "NEW HIGH SCORE!" indicator and persisted to storage.
2. **Given** the player plays Zen mode and achieves a better WPM than their previous best, **When** they quit the session, **Then** the new best WPM and accuracy are persisted as the Zen high score.
3. **Given** the player has high scores for both modes, **When** they launch the game, **Then** the main menu displays the high score for the last mode played.
4. **Given** the player has an existing Survival high score from a previous version, **When** they launch the updated game, **Then** the existing high score is preserved and accessible.

---

### Edge Cases

- What happens when the player pauses while a Freeze power-up timer is active? The freeze timer should pause along with the game; remaining freeze time resumes when unpaused.
- What happens if the player activates Bomb when no zombies are on screen? Nothing happens — no score awarded, power-up is still consumed.
- What happens when a carrier zombie reaches the bottom? The carried power-up is lost (not dropped or awarded).
- What happens if the player activates Shield and then pauses? The shield remains in "armed" state; it only activates when a zombie crosses the bottom.
- What happens if the last zombie in a wave pool is a carrier? The power-up drops normally; wave completion is not affected.
- What happens if the player presses Escape on the game-over screen? Returns to main menu (same as current restart flow, but now goes to menu instead).
- What happens if the player navigates past the last menu item with Down arrow? Selection wraps to the first item (circular navigation).
- What happens if Freeze is activated while a boss is active? The boss is also frozen (bosses are not immune to Freeze, unlike Bomb). This gives the player time to read and type the boss phrase.

## Requirements

### Functional Requirements

#### Power-up System

- **FR-001**: System MUST support three power-up types: Freeze (stops all zombie movement for 3 seconds), Bomb (instantly kills all active standard zombies), and Shield (absorbs one fatal zombie crossing the bottom).
- **FR-002**: Killed zombies MUST have a 10% chance to drop a random power-up, with equal probability among the three types.
- **FR-003**: A zombie designated as a power-up carrier MUST display a distinct visual indicator (colored icon above its name) visible throughout its lifetime.
- **FR-004**: The player MUST have exactly one power-up inventory slot. If the slot is occupied, new drops are ignored (not picked up).
- **FR-005**: The currently held power-up MUST be displayed in the HUD with a recognizable icon.
- **FR-006**: Power-ups MUST be activated by pressing the Space bar. Activation consumes the held power-up.
- **FR-007**: Pressing Space with an empty inventory MUST have no effect.
- **FR-008**: Bomb MUST NOT affect an active boss. The boss remains at its current health/position after Bomb activation.
- **FR-009**: Freeze MUST freeze all on-screen entities including the boss (if active). During freeze, zombie Y-positions and animation timers do not advance. The freeze duration timer MUST be visible on the HUD.
- **FR-010**: Shield MUST activate passively when a zombie crosses the bottom. It destroys the triggering zombie, consumes the shield, and prevents game-over for that single event.
- **FR-011**: Power-ups MUST be disabled in Zen mode. No carriers spawn and the inventory slot is hidden.

#### Main Menu

- **FR-012**: The game MUST display a main menu on launch with options: "Survival", "Zen", and "Quit".
- **FR-013**: Menu navigation MUST use Up/Down arrow keys to move selection and Enter to confirm.
- **FR-014**: Menu selection MUST wrap circularly (Down from last item goes to first; Up from first goes to last).
- **FR-015**: The main menu MUST display the best score for the most recently played game mode.
- **FR-016**: Selecting "Quit" MUST close the game window.

#### Pause System

- **FR-017**: Pressing Escape during active gameplay (any mode) MUST pause the game: all timers, zombie movement, input processing, and spawn logic stop.
- **FR-018**: The pause state MUST display an overlay with "Resume" and "Quit to Menu" options, navigable with Up/Down + Enter.
- **FR-019**: Resuming MUST restore exact game state (positions, timers, inventory, score, combo) without any discontinuity.
- **FR-020**: Quitting to menu from pause MUST discard the current session. If a new high score was achieved before pausing, it is NOT saved.
- **FR-021**: Pressing Escape on the game-over screen MUST return to the main menu.

#### Game Modes

- **FR-022**: Survival mode MUST behave identically to the current wave-based mode, with the addition of power-up drops and the pause system.
- **FR-023**: Zen mode MUST present a WPM target selection screen with three presets: 30, 50, and 80 WPM.
- **FR-024**: Zen mode MUST derive spawn rate and fall speed from the selected WPM target using the existing wave timing formula.
- **FR-025**: In Zen mode, zombies that reach the bottom MUST disappear without triggering game-over or the dying state sequence.
- **FR-026**: Zen mode MUST display live WPM and accuracy in the HUD but MUST NOT display a competitive score or combo counter.
- **FR-027**: Zen mode MUST NOT include boss encounters.

#### High Score Persistence

- **FR-028**: Survival mode MUST persist its high score independently from Zen mode, using a separate storage key/file.
- **FR-029**: Zen mode MUST persist best session WPM and accuracy as its high score record.
- **FR-030**: Existing Survival high scores from previous versions MUST remain accessible and not be overwritten by the multi-mode system.
- **FR-031**: On all platforms (native and web), each mode MUST use a separate persistent storage location for high score data.

### Key Entities

- **PowerUpType**: Represents the type of power-up (Freeze, Bomb, or Shield). Each type has distinct activation behavior and visual representation.
- **PowerUpInventory**: Single-slot container for the player's currently held power-up. Can be empty or hold exactly one PowerUpType.
- **GameMode**: Distinguishes between Survival (competitive, wave-based, game-over enabled) and Zen (practice, constant speed, no game-over). Determines which features are active (power-ups, bosses, scoring).
- **GameScreen**: Represents the current UI state: MainMenu, WpmSelect (Zen sub-menu), Playing, Paused, GameOver. Controls which update/draw logic runs.
- **HighScoreRecord (per mode)**: Extends the existing record structure to be keyed by game mode. Survival tracks score/wave/wpm/accuracy; Zen tracks wpm/accuracy only.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Players can activate any of the three power-ups within 0.5 seconds of pressing the activation key, with immediate visible effect on screen.
- **SC-002**: Power-up drops occur at a rate that averages one drop per 10 zombie kills across a typical Survival session.
- **SC-003**: Players can navigate from game launch to active gameplay in under 5 seconds (menu to first zombie spawn).
- **SC-004**: Pausing and resuming introduces zero observable state discontinuity (zombie positions, timers, and score are identical before and after).
- **SC-005**: Zen mode sustains zombie spawn rates matching the selected WPM target within a 10% tolerance.
- **SC-006**: Each game mode independently persists and retrieves its own high score across game restarts.
- **SC-007**: Existing Survival high scores are preserved after updating to the new multi-mode version (backward compatibility).
- **SC-008**: All three power-up types are used by players at comparable rates (no single power-up dominates usage by more than 2:1 ratio), indicating balanced design.
- **SC-009**: 90% of first-time players can identify the power-up activation key, inventory slot, and carrier zombies without external instructions.

## Assumptions

- The Space bar is not currently used for any gameplay function (confirmed: input captures ASCII 32-125 for typing, but Space only adds a space character to the input buffer — this will need to be excluded from the typing buffer when used as the power-up key).
- The existing `deriveWaveTiming` / `getWaveConfig` functions can accept arbitrary WPM targets to generate spawn rate and fall speed for Zen mode.
- No new graphical assets are required for power-up icons — text symbols or colored shapes drawn procedurally are sufficient for the CRT aesthetic.
- The game window resolution (800x450) provides sufficient space for the HUD inventory slot without obscuring gameplay.
- Boss encounters remain exclusive to Survival mode (no changes to boss logic are needed for Zen mode).
