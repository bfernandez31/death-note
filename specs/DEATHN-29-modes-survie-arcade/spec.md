# Feature Specification: Modes Survie, Arcade et Simulation avec systeme de vies

**Feature Branch**: `DEATHN-29-modes-survie-arcade`
**Created**: 2026-05-19
**Status**: Draft
**Input**: User description: "Modes Survie, Arcade et Simulation avec systeme de vies"

## Auto-Resolved Decisions

### ARD-1: Maximum heart cap in Arcade mode

- **Decision**: Hearts are capped at 3 maximum. Player starts with 3 hearts, can never exceed 3 even after boss restoration.
- **Policy Applied**: CONSERVATIVE (AUTO resolved)
- **Confidence**: High (0.9) — description explicitly suggests "a priori 3 max"
- **Fallback Triggered?**: Yes — AUTO confidence was low (0.3), promoted to CONSERVATIVE
- **Trade-offs**: Limits comeback potential but preserves meaningful difficulty; aligns with ticket intent
- **Reviewer Notes**: Confirm 3 is the right cap. A higher cap (e.g., 5) would significantly change Arcade difficulty curve.

### ARD-2: Heart loss feedback in Arcade mode

- **Decision**: When a zombie reaches the bottom and a heart is lost, the player receives clear visual and audio feedback. The game is briefly interrupted to acknowledge the loss before continuing.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Medium (0.6) — standard game design practice for life-loss events
- **Fallback Triggered?**: Yes — description does not specify feedback behavior
- **Trade-offs**: Brief interruption ensures player awareness of life loss; too long an interruption could feel punishing on repeated hits
- **Reviewer Notes**: Validate the interruption duration feels right during playtesting. Consider whether losing a heart should also clear the current input buffer.

### ARD-3: Simulation mode retains current bot behavior including power-ups

- **Decision**: Simulation mode is a pure rename of Bot mode. All current bot behaviors are preserved exactly, including any interaction with the power-up system. No gameplay changes.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: High (0.9) — ticket explicitly states "Aucun changement de comportement, juste le nom"
- **Fallback Triggered?**: No
- **Trade-offs**: Simulation mode may behave differently from Survie (which disables powers), but this matches the "no behavior change" directive
- **Reviewer Notes**: Verify that power-up interactions in Simulation match current bot behavior exactly.

### ARD-4: Arcade mode gets its own separate high score storage

- **Decision**: Arcade mode stores its high score independently from Survie and Zen modes. The Arcade high score starts at zero on first play.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: High (0.9) — acceptance criteria explicitly require "high score reste separe par mode"
- **Fallback Triggered?**: No
- **Trade-offs**: Players cannot compare Survie and Arcade scores directly from in-game display, but separation is fair given different rulesets
- **Reviewer Notes**: Confirm storage format and naming convention for the new Arcade high score file.

### ARD-5: Existing survival high scores carry over to Survie mode

- **Decision**: Current survival high scores are preserved and become the Survie high scores. No migration or reset occurs for existing players.
- **Policy Applied**: CONSERVATIVE
- **Confidence**: Medium (0.6) — Survie is the direct successor of the current survival mode with the same rules (minus powers)
- **Fallback Triggered?**: Yes — powers are removed from Survie which makes old scores not perfectly comparable
- **Trade-offs**: Players keep their history which respects their effort; scores achieved with powers may be higher than what's possible in the new powerless Survie, creating an unreachable high score in edge cases
- **Reviewer Notes**: Decide whether to reset survival high scores given the power-up removal. If powers significantly inflated scores, a reset may be fairer.

### ARD-6: Power-up behavior change scope

- **Decision**: Power-ups are fully disabled in Survie mode (no drops, no pickups, no activation). Power-ups remain fully enabled in Arcade mode with existing behavior (freeze, bomb, shield). Zen mode continues without power-ups (current behavior).
- **Policy Applied**: CONSERVATIVE
- **Confidence**: High (0.9) — ticket is explicit: Survie has "aucun pouvoir" and Arcade has "les pouvoirs actuels"
- **Fallback Triggered?**: No
- **Trade-offs**: Survie becomes a harder, purer experience; Arcade becomes the accessible mode with more tools
- **Reviewer Notes**: Verify that disabling power-ups in Survie doesn't break wave balance (waves were designed with powers available).

## User Scenarios & Testing

### User Story 1 - Main Menu Mode Selection (Priority: P1)

A player launches the game and sees the main menu with four clearly labeled game modes: Survie, Arcade, Simulation, and Zen. Each mode has a distinct identity and the player understands what each offers before selecting.

**Why this priority**: The menu is the gateway to all modes. Without a clear, functional 4-mode menu, no other feature in this ticket is accessible.

**Independent Test**: Can be fully tested by launching the game and navigating the menu. Delivers value by giving players clear access to all game experiences.

**Acceptance Scenarios**:

1. **Given** the game is launched, **When** the main menu appears, **Then** four mode options are displayed in order: Survie, Arcade, Simulation, Zen (plus Sound and Quit options)
2. **Given** the player is on the main menu, **When** they navigate with up/down keys, **Then** the selection highlight moves between all available options
3. **Given** the player highlights a mode, **When** they press Enter, **Then** the corresponding game mode starts (or WPM selection screen for Zen)

---

### User Story 2 - Survie Mode: Hardcore Experience (Priority: P1)

A player selects Survie mode to test their pure typing skill. The game plays with progressive waves of increasing WPM, but no power-ups are available. A single zombie reaching the bottom ends the game immediately. This is the leaderboard mode for competitive players.

**Why this priority**: Survie is the direct evolution of the current default game mode and serves as the competitive/hardcore experience. It must work correctly before adding Arcade's layers on top.

**Independent Test**: Can be fully tested by selecting Survie, playing through several waves, confirming no power-ups drop, and verifying that one zombie reaching the bottom triggers game over.

**Acceptance Scenarios**:

1. **Given** the player selects Survie, **When** a wave starts, **Then** zombies spawn with the same wave progression, WPM targets, and spawn timing as the current survival mode
2. **Given** the player is in Survie mode, **When** zombies are killed, **Then** no power-up drops occur (no freeze, bomb, or shield icons appear)
3. **Given** the player is in Survie mode, **When** a single zombie reaches the bottom of the screen, **Then** the dying sequence plays and the game ends (game over)
4. **Given** the player achieves a new high score in Survie, **When** the game-over screen appears, **Then** the Survie high score is updated and stored separately from other modes
5. **Given** the player completes a boss wave in Survie, **When** the boss is defeated, **Then** the wave advances normally (no heart restoration since there are no hearts)

---

### User Story 3 - Arcade Mode: Lives and Powers (Priority: P1)

A player selects Arcade mode for a more forgiving experience. The game uses the same wave progression as Survie but adds 3 hearts (lives) and power-ups. Losing a zombie costs one heart instead of ending the game. Defeating a boss restores one heart (up to the 3-heart cap). Game over occurs only when all hearts are depleted.

**Why this priority**: Arcade is the major new feature of this ticket. It introduces the lives system and combines it with power-ups to create a distinct gameplay loop.

**Independent Test**: Can be fully tested by selecting Arcade, playing through waves, losing hearts, defeating a boss to regain a heart, and verifying game over only at zero hearts.

**Acceptance Scenarios**:

1. **Given** the player selects Arcade, **When** the game starts, **Then** 3 heart indicators are displayed on screen and the power-up system is active
2. **Given** the player is in Arcade with 3 hearts, **When** a zombie reaches the bottom, **Then** one heart is removed, the player receives clear visual/audio feedback, and gameplay continues
3. **Given** the player is in Arcade with 1 heart remaining, **When** a zombie reaches the bottom, **Then** the last heart is removed and the game-over sequence triggers
4. **Given** the player is in Arcade with 2 hearts, **When** they defeat a boss, **Then** one heart is restored (now 3 hearts) and a restoration indicator is shown
5. **Given** the player is in Arcade with 3 hearts (maximum), **When** they defeat a boss, **Then** no heart is added (cap remains at 3) and the player is informed the cap is reached
6. **Given** the player is in Arcade mode, **When** zombies are killed, **Then** power-ups can drop with the same probability and behavior as the current system (freeze, bomb, shield)
7. **Given** the player achieves a new high score in Arcade, **When** the game ends, **Then** the Arcade high score is updated separately from Survie and Zen scores

---

### User Story 4 - Simulation Mode: Renamed Bot (Priority: P2)

A player selects Simulation mode to observe the game playing itself. This is the current Bot mode with a new name. All behavior, including auto-typing, F2 toggle, and power-up interactions, remains identical.

**Why this priority**: This is a low-risk rename with no gameplay changes. Important for menu consistency but not a functional blocker.

**Independent Test**: Can be fully tested by selecting Simulation, observing auto-play behavior, and confirming it matches current Bot mode exactly.

**Acceptance Scenarios**:

1. **Given** the player selects Simulation from the main menu, **When** the game starts, **Then** the bot auto-types zombie names and the game plays itself (identical to current Bot behavior)
2. **Given** the player is in any mode, **When** they look at all menu labels and in-game text, **Then** "Bot" does not appear anywhere; it is replaced by "Simulation"
3. **Given** the player is in Simulation mode, **When** they press F2, **Then** the simulation toggle behaves identically to the current bot toggle

---

### User Story 5 - Separate High Scores per Mode (Priority: P2)

Each game mode (Survie, Arcade, Zen) maintains its own independent high score. Simulation mode does not record high scores (current bot behavior). The game-over screen displays the relevant mode's high score.

**Why this priority**: Separate scores ensure fair competition within each mode and prevent Arcade's forgiveness from diluting Survie leaderboard integrity.

**Independent Test**: Can be fully tested by playing each mode, achieving scores, and verifying each mode stores and displays its own best independently.

**Acceptance Scenarios**:

1. **Given** the player achieves a high score in Survie, **When** they check Arcade high score, **Then** the Arcade score is unaffected and vice versa
2. **Given** the player plays Simulation mode, **When** the session ends, **Then** no high score is saved (bot-tainted behavior preserved)
3. **Given** the player has existing survival high scores, **When** they update to the new version, **Then** the existing scores are preserved as Survie high scores
4. **Given** the game-over screen is displayed, **When** the player views stats, **Then** the high score shown corresponds to the current mode only

---

### Edge Cases

- What happens when multiple zombies reach the bottom on the same frame in Arcade mode? Each zombie removes one heart independently; if 3 zombies hit simultaneously, the player loses all 3 hearts and game over triggers.
- What happens when a boss is active and a zombie reaches the bottom in Arcade? The heart is removed and the zombie is cleared, but the boss encounter continues as long as hearts remain.
- What happens when the shield power-up absorbs a zombie in Arcade? The shield absorbs the zombie without removing a heart (shield takes priority over heart loss).
- What happens if the player loses a heart during a boss fight in Arcade? The boss fight continues; heart loss does not interrupt boss typing.
- What happens to the input buffer when a heart is lost in Arcade? The current typed input is preserved (not cleared) so the player can continue typing their target.

## Requirements

### Functional Requirements

- **FR-001**: The main menu MUST display four game modes in this order: Survie, Arcade, Simulation, Zen (followed by Sound and Quit)
- **FR-002**: All references to "Bot" MUST be replaced with "Simulation" across all screens, menus, and labels
- **FR-003**: Survie mode MUST use the same wave progression, WPM targets, spawn timing, and boss schedule as the current survival mode
- **FR-004**: Survie mode MUST NOT provide any power-ups (no drops, no pickups, no activation of freeze, bomb, or shield)
- **FR-005**: Survie mode MUST trigger game over when a single zombie reaches the bottom of the screen (current behavior)
- **FR-006**: Arcade mode MUST use the exact same wave configuration as Survie mode (same WaveConfig values, same boss schedule)
- **FR-007**: Arcade mode MUST start the player with 3 hearts displayed on screen
- **FR-008**: In Arcade mode, a zombie reaching the bottom MUST remove exactly 1 heart instead of triggering immediate game over
- **FR-009**: In Arcade mode, game over MUST trigger only when all hearts are depleted (0 remaining)
- **FR-010**: In Arcade mode, defeating a boss MUST restore 1 heart, up to a maximum of 3 hearts
- **FR-011**: Arcade mode MUST enable the existing power-up system (freeze, bomb, shield) with current drop rates and behavior
- **FR-012**: Simulation mode MUST behave identically to the current Bot mode in all respects except the displayed name
- **FR-013**: High scores MUST be stored separately for Survie, Arcade, and Zen modes
- **FR-014**: Simulation mode MUST NOT save high scores (preserving current bot-tainted behavior)
- **FR-015**: The heart display in Arcade mode MUST be visible at all times during gameplay and update immediately when hearts are gained or lost
- **FR-016**: The player MUST receive clear visual and audio feedback when losing a heart in Arcade mode
- **FR-017**: The player MUST receive clear feedback when a heart is restored after defeating a boss in Arcade mode
- **FR-018**: The shield power-up in Arcade mode MUST absorb zombies without consuming a heart (shield takes priority)

### Assumptions

- The wave difficulty curve designed with power-ups available remains appropriate for Survie mode without power-ups. If Survie proves too difficult without powers, wave tuning may be needed in a follow-up ticket.
- The 3-heart cap and boss restoration rate provide meaningful extended gameplay in Arcade without making it trivially easy. Playtesting will validate this.
- Existing survival high scores become Survie high scores without reset, despite the power-up removal changing achievable scores.
- The current power-up drop rate (10%) and behavior are appropriate for Arcade mode without rebalancing.

### Key Entities

- **Heart (Life)**: Represents one life in Arcade mode. Player starts with 3, loses 1 per zombie reaching the bottom, gains 1 per boss defeated (capped at 3 maximum). Not present in Survie, Zen, or Simulation modes.
- **Game Mode**: One of four selectable experiences — Survie (hardcore, no powers, 1 life), Arcade (lives + powers), Simulation (auto-play observation), Zen (relaxed, no game over). Determines gameplay rules, power-up availability, and high score storage.
- **High Score Record (per mode)**: Independent score record for each playable mode (Survie, Arcade, Zen). Each stores score, wave reached, WPM, and accuracy. Simulation does not persist scores.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Players can select any of the 4 modes (Survie, Arcade, Simulation, Zen) and begin gameplay within 2 menu interactions
- **SC-002**: In Survie mode, a single zombie reaching the bottom consistently ends the game with zero exceptions
- **SC-003**: In Arcade mode, players survive at least 1 additional wave beyond their typical Survie performance (validating that lives provide meaningful extension)
- **SC-004**: Heart display updates within the same frame as the triggering event (zombie reaching bottom or boss defeated)
- **SC-005**: Zero instances of "Bot" text remain visible anywhere in the game after the rename
- **SC-006**: High scores for each mode are fully independent — achieving a score in one mode never affects another mode's stored best
- **SC-007**: Arcade mode wave timing, spawn rates, and boss schedule are identical to Survie mode for any given wave number
- **SC-008**: Power-ups appear in Arcade mode and never appear in Survie mode across 10+ waves of gameplay
