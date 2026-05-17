# Feature Specification: Zombie Variety and Name List Depth

**Feature Branch**: `DEATHN-13-zombie-variety-and`
**Created**: 2026-05-17
**Status**: Draft
**Input**: Ticket DEATHN-13: "Zombie variety and name list depth"

## Auto-Resolved Decisions

### ARD-1: Exact number of zombie types

- **Decision**: Three zombie types will be introduced: Standard (existing), Runner (fast, short names), and Tank (slow, long names). No additional types beyond these three.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket says "at minimum" Runner and Tank; CONSERVATIVE caps scope at exactly three types to limit initial complexity.
- **Fallback Triggered?**: Yes — AUTO confidence below 0.5, promoted to CONSERVATIVE
- **Trade-offs**: Limits scope to a manageable set; additional types can be added in future tickets. Three types already provide meaningful variety.
- **Reviewer Notes**: If playtesting shows three types feel insufficient in late waves, a follow-up ticket can introduce more.

### ARD-2: Visual differentiation method for zombie types

- **Decision**: Each zombie type is visually distinguished by a color tint applied to the existing spritesheet. Runner zombies are tinted green, Tank zombies are tinted blue. No new sprite assets are required.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket says "colour, sprite, or clear visual variation" without specifying which approach
- **Fallback Triggered?**: Yes — AUTO confidence below 0.5, promoted to CONSERVATIVE
- **Trade-offs**: Color tinting reuses the existing spritesheet, avoiding new asset creation. Distinct types are recognizable at a glance. Some players may find tint-only differentiation subtle.
- **Reviewer Notes**: If tinting alone is insufficient for clarity during playtesting, consider adding size variation or sprite swaps in a follow-up.

### ARD-3: Runner and Tank speed values relative to wave config

- **Decision**: Runner speed is 1.8x the wave's base fall_speed. Tank speed is 0.5x the wave's base fall_speed. These multipliers are fixed across all waves.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket gives qualitative guidance ("fast" / "slow") without specific multipliers
- **Fallback Triggered?**: Yes — AUTO confidence below 0.5, promoted to CONSERVATIVE
- **Trade-offs**: Fixed multipliers keep behavior predictable and testable. The wave's own speed progression already increases difficulty.
- **Reviewer Notes**: Multipliers should be play-tested across waves 1-15+; adjust if Runners become impossible or Tanks trivial in late waves.

### ARD-4: Name length boundaries for Runner vs Tank selection

- **Decision**: Runners draw names with 5 or fewer characters. Tanks draw names with 8 or more characters. Standard zombies draw from names of any length. These thresholds apply after name list filtering.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket says "short names" and "long names" without numeric thresholds
- **Fallback Triggered?**: Yes — AUTO confidence below 0.5, promoted to CONSERVATIVE
- **Trade-offs**: Clear numeric boundaries make the system deterministic and testable. Some names near the boundary (6-7 chars) are reserved for Standard only, which may reduce perceived variety for Standard zombies.
- **Reviewer Notes**: Verify that each name list contains enough entries within each length range to avoid repetition.

### ARD-5: Wave weighting progression model

- **Decision**: Waves 1-3: 100% Standard. Waves 4-6: 70% Standard, 20% Runner, 10% Tank. Waves 7-10: 50% Standard, 30% Runner, 20% Tank. Waves 11+: 40% Standard, 30% Runner, 30% Tank. Weights are probability-based; actual spawns may vary.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket describes a progression pattern qualitatively without exact percentages
- **Fallback Triggered?**: Yes — AUTO confidence below 0.5, promoted to CONSERVATIVE
- **Trade-offs**: Gradual introduction lets players learn each type before facing mixed groups. Late-wave 40/30/30 split ensures all types remain relevant.
- **Reviewer Notes**: Play-test the wave 4 transition — players should encounter their first Runner before their first Tank.

### ARD-6: Name list weights by wave for secondary and trap lists

- **Decision**: Waves 1-3: 100% primary list. Waves 4-7: 85% primary, 10% trap, 5% compound. Waves 8-12: 65% primary, 20% trap, 15% compound. Waves 13+: 50% primary, 25% trap, 25% compound. These weights apply after type-based length filtering.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket gives a progression pattern without exact numbers
- **Fallback Triggered?**: Yes — AUTO confidence below 0.5, promoted to CONSERVATIVE
- **Trade-offs**: Early waves stay simple; trap names appear before compound names to introduce challenge gradually. Late-wave 50/25/25 keeps all lists active.
- **Reviewer Notes**: Verify that trap-name clusters (2-3 similar names on screen simultaneously) create the intended confusion effect.

### ARD-7: Input buffer maximum size

- **Decision**: The input buffer maximum is raised to 20 characters (from 9) for all zombie types. The existing boss input buffer of 35 characters remains unchanged for boss encounters.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket says "adapt to the longest potentially spawnable name" without a specific number; longest compound names (e.g., "Jean-Christophe") are ~16 characters
- **Fallback Triggered?**: Yes — AUTO confidence below 0.5, promoted to CONSERVATIVE
- **Trade-offs**: 20 characters accommodates all compound names with margin. Does not affect boss phrase input which already has its own 35-char limit.
- **Reviewer Notes**: Ensure the on-screen input display area can render 20 characters without clipping.

### ARD-8: Anti-doublon retry limit

- **Decision**: When spawning a zombie, if the randomly selected name is already active on screen, the system retries up to 10 times with a new random pick. If all 10 attempts collide, the spawn is skipped for that cycle and retried on the next spawn timer tick.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket requires no duplicates but does not specify retry behavior
- **Fallback Triggered?**: Yes — AUTO confidence below 0.5, promoted to CONSERVATIVE
- **Trade-offs**: A retry cap prevents infinite loops in edge cases where many zombies are active. Skipping one spawn cycle is imperceptible to the player.
- **Reviewer Notes**: With 300+ names in the primary list alone, 10 retries should virtually never be exhausted.

### ARD-9: Boss zombie relationship to Tank type

- **Decision**: Boss zombies remain a distinct entity separate from the Tank type. The ticket mentions "Tank as XXL boss" as aspirational, but altering the existing boss system (DEATHN-20) is out of scope for this ticket. Tank is a regular zombie type with its own behavior.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket says the boss "ideally reuses Tank as XXL version" without making it mandatory
- **Fallback Triggered?**: Yes — AUTO confidence below 0.5, promoted to CONSERVATIVE
- **Trade-offs**: Keeping boss and Tank separate avoids regression risk on the existing boss feature (DEATHN-20). A future ticket can unify them if desired.
- **Reviewer Notes**: If unifying boss and Tank is desired, it should be a separate ticket to avoid scope creep.

### ARD-10: Trap name cluster spawning behavior

- **Decision**: When a trap-list name is selected, the system attempts to spawn 1-2 additional zombies with visually similar names (from the same trap group) within the next 2 spawn cycles, subject to available zombie slots and anti-doublon rules.
- **Policy Applied**: CONSERVATIVE (AUTO fallback)
- **Confidence**: Low (score 0.3) — ticket says trap names appear "in clusters" without defining cluster mechanics
- **Fallback Triggered?**: Yes — AUTO confidence below 0.5, promoted to CONSERVATIVE
- **Trade-offs**: Cluster spawning creates the intended confusion without overwhelming the player. Limited to 1-2 extras keeps difficulty manageable.
- **Reviewer Notes**: Test that clusters don't cause spawn bursts that exceed the wave's intended pacing.

## User Scenarios & Testing

### User Story 1 - Encountering Different Zombie Types (Priority: P1)

A player starts a new game and progresses through waves. In waves 1-3, only Standard white zombies appear with familiar short names. Upon reaching wave 4, the player notices a green-tinted zombie falling faster than the others with a very short name — a Runner. The player must type quickly to kill it before it reaches the bottom. By wave 7, blue-tinted Tank zombies begin appearing, moving slowly but bearing longer names that require more precise typing.

**Why this priority**: The three zombie types are the core feature — without visual and mechanical variety, the ticket's primary goal is unmet.

**Independent Test**: Start a game, play through waves 1-7, and verify that Standard, Runner, and Tank zombies appear with correct visual tinting, speed differences, and name length patterns.

**Acceptance Scenarios**:

1. **Given** the player is on wave 2, **When** zombies spawn, **Then** all zombies are Standard type with no color tint and normal speed.
2. **Given** the player is on wave 5, **When** a Runner spawns, **Then** it has a green tint, moves at 1.8x the wave's base fall speed, and displays a name of 5 characters or fewer.
3. **Given** the player is on wave 8, **When** a Tank spawns, **Then** it has a blue tint, moves at 0.5x the wave's base fall speed, and displays a name of 8 characters or more.
4. **Given** the player is on wave 11, **When** zombies spawn, **Then** approximately 40% are Standard, 30% Runner, and 30% Tank (verified over multiple spawn cycles).

---

### User Story 2 - Expanded Name Variety (Priority: P1)

A player who has played several sessions notices a much wider variety of names on zombies compared to the original 49-name list. Simple first names still dominate early waves, but as the player progresses, compound names like "Jean-Pierre" and "Anne-Sophie" begin appearing. The player can type hyphens as part of the name. The input field accommodates names up to 20 characters long.

**Why this priority**: Name variety is the second pillar of the feature — without it, the typing challenge remains stale regardless of zombie types.

**Independent Test**: Play through waves 1-10 and verify that names come from an expanded pool with no noticeable repetition, compound names appear in later waves, and hyphens are accepted as valid input characters.

**Acceptance Scenarios**:

1. **Given** the player is on wave 1, **When** zombies spawn, **Then** all names are simple first names from the primary list (no compound or trap names).
2. **Given** the player is on wave 6, **When** a zombie spawns with a compound name like "Jean-Pierre", **Then** the name displays correctly with the hyphen, and the player can type the hyphen character to complete the match.
3. **Given** the player types a name that is 15 characters long (e.g., "Jean-Christophe"), **When** the input reaches 15 characters, **Then** the input buffer accepts all characters without truncation.
4. **Given** the primary name list has at least 349 entries (49 original + 300 new), **When** playing multiple sessions, **Then** name repetition is noticeably reduced compared to the original 49-name pool.

---

### User Story 3 - No Duplicate Names on Screen (Priority: P2)

While playing, the player never sees two zombies with the same name active simultaneously. This prevents confusion about which zombie the player is targeting when typing.

**Why this priority**: Duplicate names would create an ambiguous targeting experience, undermining the core typing mechanic.

**Independent Test**: Play through waves with high zombie counts (wave 10+, 20+ active zombies) and verify no two on-screen zombies share the same name at any point.

**Acceptance Scenarios**:

1. **Given** 15 zombies are active on screen, **When** a new zombie spawns, **Then** its name is different from all 15 currently active zombie names.
2. **Given** a zombie named "Liam" was just killed, **When** the next zombie spawns, **Then** "Liam" is eligible to appear again (the anti-doublon only applies to currently active zombies).
3. **Given** 10 retries all collide with active names, **When** the spawn attempt exhausts retries, **Then** the spawn is deferred to the next spawn cycle rather than spawning a duplicate.

---

### User Story 4 - Trap Name Clusters Create Typing Challenge (Priority: P2)

In mid-to-late waves, the player sees groups of zombies with visually similar names (e.g., "Liam", "Lila", "Lina" appearing close together). The player must read carefully to avoid mistyping one name for another. This increases the cognitive challenge without changing mechanical difficulty.

**Why this priority**: Trap names add a layer of difficulty that scales with reading attention, distinct from raw typing speed — important for experienced players.

**Independent Test**: Play waves 8+ and verify that trap-group names occasionally appear in clusters of 2-3 similar names on screen simultaneously.

**Acceptance Scenarios**:

1. **Given** the player is on wave 8 and a trap-list name "Liam" is selected for spawning, **When** the next 1-2 spawn cycles occur, **Then** similar names from the same trap group (e.g., "Lila", "Lina") are preferentially spawned.
2. **Given** a trap cluster is active with "Ana" and "Anil" on screen, **When** the player types "Ana", **Then** only the zombie named "Ana" is killed (exact match required).
3. **Given** the player is on wave 3, **When** zombies spawn, **Then** no trap-list names appear (trap names are introduced from wave 4 onward).

---

### User Story 5 - Type-Appropriate Name Selection (Priority: P3)

Runners consistently display short, quickly-typeable names while Tanks display longer names requiring sustained accuracy. Standard zombies display names of any length. This coupling between zombie type and name length reinforces each type's identity.

**Why this priority**: Type-name coupling enhances the design coherence but the game is playable without it — random assignment would still work.

**Independent Test**: Spawn 50 Runners and 50 Tanks across multiple waves and verify that Runner names are <= 5 characters and Tank names are >= 8 characters.

**Acceptance Scenarios**:

1. **Given** a Runner zombie is spawning on wave 6, **When** a name is selected, **Then** the name has 5 or fewer characters.
2. **Given** a Tank zombie is spawning on wave 8, **When** a name is selected, **Then** the name has 8 or more characters.
3. **Given** a Standard zombie is spawning, **When** a name is selected, **Then** the name can be of any length from any eligible list.

---

### Edge Cases

- What happens when all names in the required length range are already active on screen? The system falls back to selecting a name from the full eligible list regardless of length, bypassing the type-length preference.
- What happens if a compound name contains characters the player's keyboard layout does not produce? Only ASCII alphanumeric characters and hyphens are used in name lists; no accented characters, spaces, or special symbols.
- What happens when the player types a hyphen while no compound-named zombie is active? The hyphen is accepted as input and simply will not match any active zombie, same as any non-matching character.
- What happens if the game transitions to a boss wave while a Tank is still active? The Tank remains active and must still be killed. The boss spawns independently per existing DEATHN-20 logic.
- What happens if name list filtering (by length + anti-doublon) leaves zero eligible names? The spawn is deferred to the next cycle. This is extremely unlikely with 300+ primary names.

## Requirements

### Functional Requirements

- **FR-001**: The game MUST support three distinct zombie types: Standard, Runner, and Tank.
- **FR-002**: Each zombie type MUST be visually distinguishable at a glance through color tinting — Standard (no tint/white), Runner (green tint), Tank (blue tint).
- **FR-003**: Runner zombies MUST move at 1.8x the wave's configured fall speed.
- **FR-004**: Tank zombies MUST move at 0.5x the wave's configured fall speed.
- **FR-005**: The probability of spawning each zombie type MUST change per wave according to a defined weight table (Standard-heavy early, mixed late).
- **FR-006**: The primary name list MUST contain at least 349 first names (49 existing + 300 new), all ASCII without accented characters.
- **FR-007**: A secondary compound-name list MUST exist with hyphenated names (e.g., "Jean-Pierre", "Marie-Claire"), each up to 20 characters.
- **FR-008**: A trap-name list MUST exist containing groups of visually similar names (names differing by one or two characters).
- **FR-009**: Name selection MUST be weighted by wave: primary-only in early waves, with increasing probability of trap and compound names in later waves.
- **FR-010**: Runner zombies MUST draw names from entries with 5 or fewer characters.
- **FR-011**: Tank zombies MUST draw names from entries with 8 or more characters.
- **FR-012**: No two active zombies on screen MUST share the same name at any given time.
- **FR-013**: The anti-doublon mechanism MUST retry up to 10 times on collision, then defer the spawn to the next cycle.
- **FR-014**: When a trap-list name is spawned, the system MUST attempt to spawn 1-2 similar names from the same trap group within the next 2 spawn cycles.
- **FR-015**: The input buffer for regular zombies MUST accept up to 20 characters to accommodate compound names.
- **FR-016**: The hyphen character MUST be accepted as valid input and MUST be matchable in zombie names.
- **FR-017**: The existing boss mechanic (DEATHN-20) MUST continue to function without regression — boss input buffer (35 chars), boss spawning, and boss phrase typing are unchanged.

### Key Entities

- **ZombieType**: Categorizes each zombie as Standard, Runner, or Tank. Determines visual tint, speed multiplier, and eligible name length range.
- **NameList**: A categorized collection of names — primary (simple first names), compound (hyphenated), or trap (similar-looking groups). Each list has a wave-dependent selection weight.
- **TrapGroup**: A cluster of 3-5 visually similar names (e.g., "Liam", "Lila", "Lina") that can be spawned together to increase typing difficulty.
- **SpawnWeightTable**: Per-wave probability distribution controlling zombie type selection and name list selection.

## Success Criteria

### Measurable Outcomes

- **SC-001**: Players encounter all three zombie types (Standard, Runner, Tank) within the first 7 waves of any session.
- **SC-002**: Over a 10-wave test session, no two active zombies share the same name at any point.
- **SC-003**: Name repetition across a 10-wave session is reduced by at least 80% compared to the original 49-name pool.
- **SC-004**: Players can type and match compound names (with hyphens) with the same reliability as simple names — no input-related failures.
- **SC-005**: The visual distinction between zombie types is identifiable within 1 second of a zombie appearing on screen.
- **SC-006**: Trap name clusters appear at least once per session in waves 8+, creating a noticeable increase in typing attention required.
- **SC-007**: All existing game mechanics (scoring, WPM tracking, boss encounters, wave progression, high scores) continue functioning without regression.
