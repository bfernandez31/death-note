# Quick Implementation: [Compliance] Fix 1 violation - Code Patterns

**Feature Branch**: `DEATHN-40-compliance-fix-1`
**Created**: 2026-05-24
**Mode**: Quick Implementation (bypassing formal specification)

## Description

Health scan found 1 compliance violation for principle "Code Patterns":

src/name_lists.zig:242: Magic number `50` used as the retry budget in `pickFromPrimary` (`while (attempts < 50)`) instead of a named SCREAMING_SNAKE_CASE constant. The sibling retry loop in `selectName` correctly uses `zt.MAX_SPAWN_RETRIES`, demonstrating the established pattern.

---

[Compliance] Fix 1 violation - Code Quality
Health scan found 1 compliance violation for principle "Code Quality":

src/main.zig:1425: Functions `frame_c_callback` (line 1425) and `cleanup_on_exit` (line 1436) use snake_case identifiers. Constitution Code Quality #3 requires `camelCase` for functions (`spawnZombie`, `updateZombies`), with the only exemption being raylib identifiers (which keep upstream C casing). These two are project-authored callbacks, not raylib symbols.

---

 [Compliance] Fix 5 violations - Testing Standards
Health scan found 5 compliance violations for principle "Testing Standards":

src/main.zig:3461: Test "shield state transition" only assigns to and reads back the production global `shield_active` (`shield_active = true; expect(shield_active); shield_active = false; expect(!shield_active);`). It does not invoke any production function — the test passes for any implementation, including one where the shield logic is entirely broken. Violates Testing Standards #6 ("Tests must exercise the subject under test").
src/main.zig:3451: Test "freeze timer clamps to zero" re-implements the clamp expression `if (freeze_timer < 0) freeze_timer = 0.0;` inside the test body itself before asserting. The production clamping code path is never executed; a regression that removed the clamp from `updateZombies`/`activatePowerUp` would not fail this test. Violates Testing Standards #6.
src/main.zig:3471: Test "space with empty inventory no state change" is explicitly a simulation: the comment reads `// Simulate: space pressed but no power-up held — activatePowerUp is only called when held != null`. It sets the globals to their pre-condition values and asserts they are still at those values — `activatePowerUp` is never invoked. The test passes regardless of whether the gate actually exists in production. Violates Testing Standards #6.
src/main.zig:3491: Test "power-up pickup with full slot unchanged" inlines the pickup gate (`if (new_drop != null and held_power_up == null) held_power_up = new_drop;`) in the test body rather than calling the production pickup path. A regression that allowed overwriting a full slot in the real pickup code would not fail this test. Violates Testing Standards #6.
src/main.zig:3577: Test "bomb on empty screen consumes power-up" sets `held_power_up = .bomb` and then manually sets `held_power_up = null` itself before asserting. The comment claims to describe what bomb activation does, but `activatePowerUp` is never called. The test would pass even if bomb activation were a no-op. Violates Testing Standards #6.

## Implementation Notes

This feature is being implemented via quick-impl workflow, bypassing formal specification and planning phases.

**Quick-impl is suitable for**:
- Bug fixes (typos, minor logic corrections)
- UI tweaks (colors, spacing, text changes)
- Simple refactoring (renaming, file organization)
- Documentation updates

**For complex features**, use the full workflow: INBOX → SPECIFY → PLAN → BUILD

## Implementation

Implementation will be done directly by Claude Code based on the description above.
