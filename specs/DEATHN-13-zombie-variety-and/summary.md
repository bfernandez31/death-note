# Implementation Summary: Zombie Variety and Name List Depth

**Branch**: `DEATHN-13-zombie-variety-and` | **Date**: 2026-05-17
**Spec**: [spec.md](spec.md)

## Changes Summary

Implemented three zombie types (Standard, Runner, Tank) with wave-weighted spawn probabilities, type-based speed multipliers (1.0x/1.8x/0.5x), and color tinting (white/green/blue). Created name_lists.zig with 349+ primary names, 31 compound hyphenated names, and 15 trap groups. Added anti-doublon enforcement, trap cluster spawning, and widened input buffer to 20 chars. All 54 tasks completed across 8 phases.

## Key Decisions

Used std.Random by value (not pointer) since Zig's Random is already a fat pointer interface. Seeded PRNG via std.c.clock_gettime since std.time.milliTimestamp was removed in Zig 0.16. Made ZombieType, constants, and weight tables pub for cross-module access from name_lists.zig. Compound names fall back to primary list for Runner type (too long).

## Files Modified

- `src/main.zig` — Added ZombieType enum, SpawnWeights/NameWeights structs, weight tables, helper functions, rewrote spawnZombie with type selection and name_lists integration, updated drawZombies tinting, widened text box, added 10+ new tests
- `src/name_lists.zig` — New module with PrimaryNames (349+), CompoundNames (31), TrapGroups (15), selectName function, 10 tests
- `specs/DEATHN-13-zombie-variety-and/tasks.md` — All 54 tasks marked complete

## ⚠️ Manual Requirements

Manual play-test recommended: run `zig build run` and verify zombie types appear with correct colors/speeds across waves 1-15. Verify compound names render correctly and hyphens type properly.
