# death-note — Project Constitution

Governance principles for contributors and AI agents working on this Zig + raylib typing game. Derived from the patterns in `build.zig`, `build.zig.zon`, `src/main.zig`, `src/raylib.zig`, and `src/zombie_names.zig`.

## Code Patterns

1. **Single-module game loop.** Gameplay lives in `src/main.zig` as a classic init → update → draw → teardown loop. New features should extend that structure in place, or split out a new `src/*.zig` sibling module that is `@import`-ed from `main.zig` (mirroring how `zombie_names.zig` is consumed). Do not introduce indirection layers (interfaces, registries, event buses) until there is concrete duplication to consolidate.

   **When to split a new module.** Split only when there's (a) concrete duplication to consolidate, (b) a genuinely distinct concern with its own surface (e.g. dual-backend persistence: native file I/O vs Emscripten `localStorage`), or (c) pure data isolated from logic (as in `zombie_names.zig`). File size alone is not a trigger — large cohesive files are idiomatic in Zig.

   **Dependency direction.** Sibling modules MUST NOT `@import("main.zig")`. `main.zig` is the entry point — shared symbols (types, constants, helpers) needed by multiple modules move to their own `snake_case.zig` (or into the sibling itself if `main.zig` is the only other caller). Circular imports between game modules are forbidden.
2. **C interop stays walled off in `src/raylib.zig`.** That file is the only place that calls `@cImport`. Game code imports `raylib.zig` and uses the re-exported symbols (`raylib.InitWindow`, `raylib.Rectangle`, etc.). Do not sprinkle `@cImport` or raw `@cInclude` elsewhere.
3. **Explicit, named constants for tunables.** `MAX_ZOMBIES`, `MAX_INPUT_CHARS`, `ZOMBIE_FRAME_COUNT`, `spawn_delay`, `screen_width`, `screen_height`, and similar values live at the top of the module that uses them. New magic numbers must be promoted to `const` with an explanatory name before they ship.
4. **Paired `Init…` / `defer Close…` for every resource.** Window, audio device, textures, and sounds are each cleaned up via `defer` on the very next line after acquisition. New resource loads MUST follow this idiom — we never rely on process exit alone to release raylib handles.
5. **Optional pointers are unwrapped with `if (x) |val|`.** Zombie slots are `?*Zombie` and always unwrapped defensively. Do not use `.?` in gameplay code; we want the null path to be a first-class branch.
6. **Allocator is passed by pointer parameter.** Functions that allocate (e.g. `spawnZombie`, `resetZombies`) take `allocator: *std.mem.Allocator`. Do not reach into `std.heap.page_allocator` from helpers — thread the allocator through so it can be swapped (e.g. an arena for tests) later without plumbing changes.
7. **Fixed-size pools, not dynamic lists.** Zombies live in a `[MAX_ZOMBIES]?*Zombie` slot array with `is_active` gating. When adding new entity kinds, prefer the same pattern: fixed capacity, nullable slot, active flag. Resize by changing the constant, not the data structure. **Pools and any array/struct that will be iterated or pointer-dereferenced before being fully written MUST be initialized to a known-empty state** (e.g. `[_]?*T{null} ** N`), never `= undefined` — debug builds fill `undefined` with `0xAA` which reads as non-null pointers and crashes on the first iteration. Local scalar variables that are unconditionally assigned in a subsequent block (the Zig idiom for deferred initialization in an `if/else if/else` chain) MAY use `= undefined`; the compiler proves the read-before-write impossible.

## Testing Standards

1. **Framework**: Zig's built-in test runner via `zig build test`. The step is wired up in `build.zig` against `src/main.zig`; do not add a separate test framework.
2. **Test location**: place `test "…" { … }` blocks in the module under test. For them to be discovered by `zig build test`, the module must be reachable (directly or transitively) from `src/main.zig`.
3. **Coverage expectations**: pure logic (input matching, spawn eligibility, name lookups) should have at least one `test` block. Raylib calls are not unit-tested — verify them manually with `zig build run`.
4. **No end-to-end harness**: there is no automated GUI test. When a feature changes rendering, input, or audio, the implementation `summary.md` MUST include a **Manual Requirements** section telling the reviewer what to verify with `zig build run`.
5. **Determinism in tests**: when testing code that uses `std.Random`, seed the PRNG explicitly rather than relying on the `std.time.milliTimestamp()` seed used in `main()`.
6. **Tests must exercise the subject under test.** Assertions like `try expect(true)`, or tests that only manipulate test-local state without ever calling a production function, are not acceptable coverage. Every `test "..." { ... }` block must invoke at least one production symbol (function, comptime evaluation) whose behavior changes the asserted outcome — otherwise the test passes for the wrong reason and a regression in the named feature will not fail it.

## Security Practices

1. **No secrets, no network.** The game is a local raylib application with no credentials, API calls, or persistence. Any PR that adds network access, file writes outside `zig-out/`, or environment-variable reads must call this out explicitly and justify the change.
2. **Bounded input buffers.** The typing buffer is guarded by `letter_count < MAX_INPUT_CHARS` and `key >= 32 and key <= 125` before writing. Any new text-input surface must enforce the same length + character-class checks at the write site; do not rely on downstream truncation.
3. **Null-terminated C strings are treated as untrusted length-wise.** When interoperating with C-string data (e.g. zombie names), compute length by scanning to `'\x00'` and compare via `std.mem.eql` on slices — never `strcmp`-style raw pointer arithmetic.
4. **Asset paths are literals, not user input.** `LoadTexture` / `LoadSound` are only called with constant string literals from `assets/`. Never derive an asset path from runtime input.
5. **Pinned dependency hash.** `build.zig.zon` pins raylib by commit hash *and* content hash. Dependency bumps must update both fields together and be reviewed — do not relax the hash check.

## Code Quality

1. **`zig build` is the gate.** The Zig compiler's type checking is the project's lint and type-check combined. A change MUST compile cleanly with `zig build` (no warnings treated as OK) before merge. No separate linter or formatter is configured; use `zig fmt` on files you touch.
2. **Idiomatic Zig error handling.** Fallible functions return `!T`, call sites use `try`, and allocation success paths use `errdefer` for cleanup on later failure (as in `spawnZombie`). Do not swallow errors with `catch unreachable` in gameplay code; propagate them.
3. **Naming discipline.**
   - `snake_case` for variables and runtime constants (`spawn_timer`, `is_game_over`).
   - `SCREAMING_SNAKE_CASE` for compile-time tunables (`MAX_ZOMBIES`, `ZOMBIE_FRAME_COUNT`).
   - `camelCase` for functions (`spawnZombie`, `updateZombies`).
   - `PascalCase` for types (`Zombie`, `ZombieNames`).
   - Raylib identifiers keep upstream C casing.
   - **File names**: `snake_case.zig` for modules that expose utilities, data, or a collection of declarations (e.g. `zombie_names.zig`, `raylib.zig`). Use `PascalCase.zig` only when the module's primary export is a single type with the same name (e.g. a future `Zombie.zig` whose main declaration is `pub const Zombie = struct { … }`), matching the Zig standard library's `Thread.zig` convention.
4. **Comments explain intent, not mechanics.** The existing code uses short `//` notes at branch points (e.g. "// Check if more characters have been pressed on the same frame"). Follow suit: comment on *why* a check exists, not *what* the next line does.
5. **No unused imports, globals, or dead code paths.** Zig will error on unused local bindings; treat unused module-level declarations the same way and delete them rather than prefixing with `_`.

## Governance

1. **Version control**: `main` is the default and primary branch. Work happens on feature branches and lands via PRs.
2. **Commit style**: observed history uses short, imperative, lower-case subjects (e.g. `implement game over`, `add sound on zombie death`, `correct animation for the zombie`). Follow that style — subject ≤ 72 chars, no trailing period, body optional.
3. **PR expectations**:
   - Describe gameplay-visible changes.
   - If `build.zig` or `build.zig.zon` changes, call out the build impact explicitly (new dependency, new step, changed artifact name).
   - Keep PRs focused: one gameplay feature or one refactor per PR.
4. **Amendments**: this constitution is updated when the onboarding workflow re-runs or when a reviewer-approved PR changes the governance rules above. Drive-by changes without justification should be rejected.
5. **Agent authority**: AI agents may edit source, tests, and build files, but MUST NOT (a) change the pinned raylib dependency, (b) add network / filesystem-write capabilities, or (c) remove the `defer` cleanup pattern around raylib resources without explicit human approval.
