# Feature Specification: Sound System and Audio Settings Menu

**Feature Branch**: `DEATHN-26-sound-system-and`  
**Created**: 2026-05-17  
**Status**: Draft  
**Input**: Ticket DEATHN-26 — Sound system and audio settings menu

## Auto-Resolved Decisions

### ARD-1: Kill sound differentiation (single vs. variants)

- **Decision**: Keep the existing single kill sound for all kill events (standard, combo, boss). No additional kill sound variants for v1.
- **Policy Applied**: AUTO → CONSERVATIVE
- **Confidence**: Low (score 1) — ticket explicitly marks this "to be decided in SPECIFY" with no strong preference signal
- **Fallback Triggered?**: Yes — low confidence promoted AUTO to CONSERVATIVE; simplest scope chosen
- **Trade-offs**: Limits audio variety on kills, but avoids scope creep and unvetted asset sourcing. Variants can be added in a follow-up ticket.
- **Reviewer Notes**: If richer kill audio is desired, create a follow-up ticket for kill sound variants (combo/boss differentiation).

### ARD-2: GPL-3.0 license handling for Monkeytype-sourced sound packs

- **Decision**: Document GPL-3.0 attribution for the Monkeytype-sourced WAV files in a dedicated `THIRD_PARTY_LICENSES` file at the repo root. The spec does not prescribe which license to adopt for the death-note project itself — that is a business decision — but requires that the Monkeytype attribution and GPL-3.0 notice be present before merge.
- **Policy Applied**: AUTO → CONSERVATIVE
- **Confidence**: Low (score 1) — license strategy is a legal/business decision, not a technical one; conservative fallback ensures no compliance gap
- **Fallback Triggered?**: Yes — legal implications require conservative handling
- **Trade-offs**: Documenting GPL origin creates a compliance obligation the project owner must evaluate. Replacing the wavs with non-viral alternatives is deferred but remains an option.
- **Reviewer Notes**: Project owner must decide whether to adopt GPL-3.0 project-wide, isolate the wavs under a GPL notice, or replace them with non-viral equivalents before public distribution.

### ARD-3: Volume slider granularity

- **Decision**: Use 5% increments (21 discrete steps: 0%, 5%, 10%, ..., 100%) for all three volume sliders.
- **Policy Applied**: AUTO → CONSERVATIVE
- **Confidence**: Low (score 1) — ticket says "5 or 10%, reasonable granularity"
- **Fallback Triggered?**: Yes — finer granularity is the more user-friendly conservative default
- **Trade-offs**: 21 steps is slightly more to navigate with arrow keys, but gives meaningfully finer control. Players who want coarse adjustment can hold the key.
- **Reviewer Notes**: If 21 steps feels excessive during playtesting, switching to 10% increments is trivial.

### ARD-4: Music behavior during pause and game-over

- **Decision**: Music pauses when the game is paused (Escape key) and resumes on unpause. Music stops on game-over and when returning to the main menu. Music does not play on the main menu or during wave transitions.
- **Policy Applied**: AUTO → CONSERVATIVE
- **Confidence**: Low (score 1) — ticket says "plays during active game phases, not in menu" but doesn't specify pause/game-over behavior
- **Fallback Triggered?**: Yes — pausing music on pause is the conventional, least-surprising behavior
- **Trade-offs**: Some players may prefer music to continue during pause for ambiance. A future enhancement could add a "music continues during pause" toggle.
- **Reviewer Notes**: Validate during playtesting that pause/resume of music stream has no audible glitch at the resume point.

### ARD-5: Sound preview trigger in menu

- **Decision**: Sound preview plays when the player moves focus to a pack option (on focus change via arrow key), not on a separate "preview" action. Only the first sample of the pack is played for preview, at 50% of the typing volume slider value (minimum 30% if slider is at 0%).
- **Policy Applied**: AUTO → CONSERVATIVE
- **Confidence**: Low (score 1) — ticket says "preview on hover/selection" but the game is keyboard-only, so "hover" maps to focus
- **Fallback Triggered?**: Yes — playing on focus change is the closest keyboard equivalent of "hover"
- **Trade-offs**: May feel noisy if the player scrolls quickly through options; short samples mitigate this. Playing only the first sample keeps preview predictable.
- **Reviewer Notes**: Ensure preview does not stack (if player scrolls rapidly, only the last-focused sample should play, interrupting any prior preview).

## User Scenarios & Testing

### User Story 1 - Keystroke audio feedback during gameplay (Priority: P1)

A player types letters to kill zombies and hears audio feedback on every correct keystroke and on errors. Correct keystrokes play a sound from the selected typing pack (round-robin across samples), while mistyped letters play the selected error pack sound. This transforms the silent typing experience into a tactile, satisfying interaction loop.

**Why this priority**: Keystroke feedback is the most frequent audio event in the game (hundreds per session) and the core value proposition of this ticket — making typing feel alive.

**Independent Test**: Start a game with default settings (typewriter pack, damage error pack). Type correct letters and hear typewriter clicks alternating between samples. Type a wrong letter and hear the damage sound. Confirm sounds are distinct and responsive.

**Acceptance Scenarios**:

1. **Given** the game is running with keystroke sounds enabled and the "typewriter" pack selected, **When** the player types a letter that extends a valid prefix on any active zombie, **Then** a typewriter sound sample plays immediately, cycling through the 6 available samples in round-robin order.
2. **Given** the game is running with error sounds enabled and the "damage" pack selected, **When** the player types a letter that does not match any active zombie prefix, **Then** the damage error sound plays immediately.
3. **Given** keystroke sounds are toggled off in settings, **When** the player types any letter, **Then** no keystroke or error sound plays regardless of pack selection.
4. **Given** the player is typing rapidly (multiple keys per frame), **When** several correct keystrokes register in quick succession, **Then** each keystroke triggers its own sound without audio glitches or dropped frames.

---

### User Story 2 - Background music loop (Priority: P1)

A player starts a game session and hears dark synthwave music playing in a seamless loop, creating atmosphere consistent with the CRT horror aesthetic. The music starts when gameplay begins and stops when the player exits to the main menu or the game ends.

**Why this priority**: Music is the most impactful single addition for game atmosphere and is a standalone, always-on audio layer that sets the mood for the entire session.

**Independent Test**: Start a Survival or Zen game. Confirm music begins playing. Let the music loop past the 88-second mark and verify the loop point is seamless (no gap, pop, or volume dip). Press Escape to pause — music pauses. Resume — music resumes. Get a game over — music stops.

**Acceptance Scenarios**:

1. **Given** the player starts a new game (Survival or Zen), **When** the gameplay state becomes active, **Then** the nightmare-pulse music track begins playing from the start.
2. **Given** music is playing during gameplay, **When** the track reaches the end of its 88-second duration, **Then** it loops back seamlessly with no audible gap or click.
3. **Given** music is playing, **When** the player presses Escape to pause, **Then** music pauses immediately. **When** the player resumes, **Then** music resumes from where it paused.
4. **Given** music is playing, **When** the game ends (game over or quit to menu), **Then** music stops.
5. **Given** the music toggle is set to off, **When** the player starts a game, **Then** no music plays.

---

### User Story 3 - Power-up activation sounds (Priority: P2)

When a player activates a held power-up (Freeze, Bomb, or Shield) by pressing the activation key, a distinct sound plays for each type, giving immediate tangible feedback that the power-up fired. Each power-up has its own characteristic sound (explosion for Bomb, ice/frost for Freeze, deflection/barrier for Shield).

**Why this priority**: Power-up activation is a high-impact, infrequent event that currently has no dedicated feedback. Distinct sounds reinforce the identity of each power-up and help the player confirm their action.

**Independent Test**: Collect each power-up type during gameplay and activate it. Confirm each plays a unique, recognizable sound. Confirm no sound plays if no power-up is held.

**Acceptance Scenarios**:

1. **Given** the player holds a Bomb power-up, **When** they press the activation key (Space), **Then** the bomb explosion sound plays immediately, regardless of whether any zombies are killed.
2. **Given** the player holds a Freeze power-up, **When** they press the activation key, **Then** the freeze/ice sound plays immediately.
3. **Given** the player holds a Shield power-up, **When** they press the activation key, **Then** the shield/barrier sound plays immediately.
4. **Given** the power-up sounds toggle is off, **When** the player activates any power-up, **Then** no activation sound plays.

---

### User Story 4 - Sound settings menu (Priority: P2)

The player opens the pause menu (Escape during gameplay) or the main menu and navigates to a "Sound" section where they can toggle each of the five sound categories on/off, select typing and error sound packs, and adjust three independent volume sliders. All settings take effect immediately and persist across sessions.

**Why this priority**: Without a settings UI, players have no control over the audio system. This story enables personal preference configuration and accessibility (e.g., muting typing sounds in a quiet environment).

**Independent Test**: Open the pause menu, navigate to Sound. Toggle keystroke sounds off, resume game, confirm no typing sounds. Return to Sound, switch pack to "hitmarker," resume, confirm hitmarker sounds play. Adjust the typing volume slider down, resume, confirm sounds are quieter. Quit and restart the game — confirm all settings are preserved.

**Acceptance Scenarios**:

1. **Given** the player is on the main menu, **When** they select "Sound", **Then** the Sound settings screen displays with five category toggles, two pack selectors, and three volume sliders.
2. **Given** the player is in the pause menu during gameplay, **When** they select "Sound", **Then** the same Sound settings screen appears.
3. **Given** the player is in the Sound settings, **When** they navigate to a pack selector and move focus to a different pack, **Then** a preview sample from that pack plays immediately.
4. **Given** the player changes a volume slider, **When** they release the slider (stop pressing the arrow key), **Then** a representative sound plays at the new volume level for auditory feedback.
5. **Given** the player changes any sound setting, **When** they exit the Sound screen and return to gameplay, **Then** the new settings are applied immediately.
6. **Given** the player has customized sound settings, **When** they close and relaunch the game, **Then** all settings are restored to their saved values.

---

### User Story 5 - Kill sound feedback (Priority: P3)

When a zombie is killed (by completing its name, by bomb, or by boss phrase completion), the existing kill sound plays, providing audio confirmation of the kill. The kill sound respects the kill category toggle and the effects volume slider.

**Why this priority**: The kill sound already exists in the game; this story ensures it is integrated into the new volume/toggle system rather than playing at a hardcoded volume.

**Independent Test**: Kill a zombie and hear the kill sound. Toggle kill sounds off in settings, kill another zombie, confirm silence. Adjust effects volume slider down, toggle kill sounds back on, kill a zombie, confirm reduced volume.

**Acceptance Scenarios**:

1. **Given** kill sounds are enabled and effects volume is at 80%, **When** a zombie is killed by typing, **Then** the kill sound plays at 80% volume.
2. **Given** kill sounds are toggled off, **When** a zombie is killed, **Then** no kill sound plays.
3. **Given** a bomb power-up kills multiple zombies, **When** the bomb activates, **Then** the kill sound plays once (not per zombie) in addition to the bomb activation sound.

---

### Edge Cases

- What happens when the player rapidly toggles a category on/off while sound is playing? Settings apply on the next sound trigger; currently-playing sounds finish naturally.
- What happens if the persisted config file is corrupted or missing? The system falls back to default settings (typewriter pack at 70%, damage pack at 70%, effects at 80%, music at 50%, all toggles on) without error.
- What happens when multiple sounds trigger in the same frame (e.g., correct keystroke + zombie kill)? Both sounds play concurrently; raylib handles mixing internally.
- What happens if the player changes the typing pack mid-game? The new pack takes effect on the next keystroke; the round-robin index resets to 0.
- What happens to music if the player starts a new game immediately after game-over without returning to menu? Music restarts from the beginning of the track.

## Requirements

### Functional Requirements

- **FR-001**: System MUST play a sound from the selected typing pack on every correctly typed letter that extends a valid prefix on at least one active zombie.
- **FR-002**: System MUST cycle through samples within a pack using round-robin selection to avoid repetitive playback.
- **FR-003**: System MUST play a sound from the selected error pack when a typed letter does not match any active zombie prefix.
- **FR-004**: System MUST play the kill sound when a zombie is destroyed (by typing, bomb, or boss phrase completion).
- **FR-005**: System MUST play a distinct activation sound for each power-up type (Freeze, Bomb, Shield) at the moment of activation.
- **FR-006**: System MUST play the background music track in a seamless loop during active gameplay phases (not during menus, pause, transitions, or game-over).
- **FR-007**: System MUST pause music when the game is paused and resume it from the pause point when unpaused.
- **FR-008**: System MUST provide independent on/off toggles for five sound categories: keystrokes, errors, kill effects, power-up effects, and music.
- **FR-009**: System MUST provide three independent volume sliders: music volume (affects background music), effects volume (affects kill and power-up sounds), and typing volume (affects keystroke and error sounds).
- **FR-010**: Each volume slider MUST range from 0% to 100% in 5% increments (21 discrete steps).
- **FR-011**: System MUST offer three selectable typing sound packs (click, typewriter, hitmarker) plus an "off" option.
- **FR-012**: System MUST offer three selectable error sound packs (damage, square, missed-punch) plus an "off" option.
- **FR-013**: When the player moves focus to a pack option in the Sound settings, the system MUST play a preview sample from that pack.
- **FR-014**: When the player finishes adjusting a volume slider, the system MUST play a representative sound at the new volume for auditory calibration.
- **FR-015**: The Sound settings screen MUST be accessible from both the main menu and the pause menu.
- **FR-016**: Sound settings navigation MUST be keyboard-only (arrow keys for navigation, Enter for selection/toggle, Escape to exit), consistent with the existing menu system.
- **FR-017**: System MUST persist all sound settings (five toggles, two pack selections, three volume levels) between sessions on both native and web platforms.
- **FR-018**: On first launch or when no saved config exists, system MUST apply default settings: keystroke pack "typewriter" at 70%, error pack "damage" at 70%, effects volume 80%, music volume 50%, all five toggles on.
- **FR-019**: When a category toggle is off, no sounds from that category MUST play regardless of pack selection or volume level.
- **FR-020**: System MUST handle rapid keystroke input (sustained bursts) without audio glitches, dropped frames, or performance degradation.
- **FR-021**: A `THIRD_PARTY_LICENSES` file MUST be present at the repo root documenting the GPL-3.0 origin and attribution for Monkeytype-sourced sound packs and the Pixabay Content License for the music track, before the feature PR is merged.

### Key Entities

- **SoundConfig**: The player's full audio preference state — five boolean toggles (keystrokes, errors, kills, power-ups, music), two pack identifiers (typing pack, error pack), and three volume levels (music, effects, typing). Persisted as a single record on native (binary file) and web (localStorage JSON).
- **SoundPack**: A named collection of WAV samples (e.g., "typewriter" = 6 samples, "click" = 3 samples). Each pack has an identifier, a sample count, and loaded sound handles. The active typing and error packs are loaded at startup and swapped when the player changes selection.
- **RoundRobinIndex**: Per-pack playback counter that cycles through available samples (0, 1, 2, ..., N-1, 0, ...) to avoid playing the same sample consecutively.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Players hear audio feedback on 100% of correct keystrokes and 100% of error keystrokes when the respective category is enabled, with no perceptible delay (under 1 frame / 16ms).
- **SC-002**: Background music loops seamlessly with no audible gap, pop, or volume dip at the loop point, verified by listening through at least 3 consecutive loops.
- **SC-003**: All five category toggles independently silence their respective sound category within the same game session, verified by toggling each on and off during gameplay.
- **SC-004**: All three volume sliders independently control their respective sound group's loudness, verified by moving each slider from 100% to 0% and confirming volume changes proportionally.
- **SC-005**: Sound settings persist across application restarts on both native and web platforms, verified by saving settings, quitting, relaunching, and confirming all values are restored.
- **SC-006**: The game maintains a stable 60 FPS during sustained rapid typing (10+ characters per second) with all sound categories enabled, verified by monitoring frame time during fast input.
- **SC-007**: Each of the three power-up types plays a distinct, recognizable sound on activation, verified by activating each power-up and confirming auditory differentiation.
- **SC-008**: Pack selection changes take effect immediately on the next keystroke or error event, with no need to restart the game.
