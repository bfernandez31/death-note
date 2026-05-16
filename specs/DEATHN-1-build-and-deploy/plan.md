# Implementation Plan: Build and Deploy the Game (WASM + Free Hosting)

**Branch**: `DEATHN-1-build-and-deploy` | **Date**: 2026-04-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/DEATHN-1-build-and-deploy/spec.md`

## Summary

Extend the existing Zig + raylib desktop game (`death-note`) with a **WebAssembly build target and automated deployment to GitHub Pages**, while preserving the native build path byte-for-byte. The WASM path compiles the game against `wasm32-emscripten` using Emscripten SDK 3.1.64, links against raylib's Web-platform build (`PLATFORM=PLATFORM_WEB`, `GRAPHICS=GRAPHICS_API_OPENGL_ES2`), bundles all `assets/` into the Emscripten VFS via `--preload-file`, and wraps the output in a custom HTML shell that renders a loading indicator and WebGL-availability guard. A GitHub Actions workflow builds the bundle on every push to `main` (and on manual dispatch) and publishes it to GitHub Pages. Two alternative deployment guides (Cloudflare Pages, GCP Firebase Hosting) are authored in this ticket's spec folder so the owner can switch hosts without rework.

## Technical Context

**Language/Version**: Zig (toolchain pinned by the repo — the same version that currently builds `main`; recorded in the CI workflow env var at implement time). No `.zig-version` file is committed today; the version is whatever the developer's `zig` invocation resolves to. The CI workflow will pin this explicitly.
**Primary Dependencies**:
- raylib (commit `52f2a10db610d0e9f619fd7c521db08a876547d0`, content hash per `build.zig.zon` — **pinned, not bumped**, per FR-014 and constitution §Security Practices/5).
- Emscripten SDK `3.1.64` (new dependency; required only for the `web` build step and the CI workflow).
**Storage**: N/A (no database, no persistence — constitution §Security Practices/1).
**Testing**: Zig's built-in test runner via `zig build test`. Pure-logic tests added in `src/main.zig` (input-matching equality, input-buffer bounds, frame-wrap arithmetic). Raylib-dependent paths exercised manually per constitution §Testing Standards/4.
**Target Platform**:
- **Native** (preserved): Linux/macOS/Windows desktop — whatever `zig build` on the host already produces.
- **Web** (added): `wasm32-emscripten` running in current-stable desktop Chrome, Firefox, Safari. Mobile browsers out of scope.
**Project Type**: Single project — one Zig module tree, build + deploy tooling co-located. No frontend/backend split. Matches the constitution's "single-module game loop" pattern.
**Performance Goals**: 60 FPS on desktop (preserved from native); first-load-to-playable ≤ 30 s over typical home broadband (spec SC-001).
**Constraints**:
- Native build path produces **zero new warnings or errors** (SC-004).
- WASM bundle makes **zero outbound network requests** beyond the host CDN (FR-011, SC-008).
- Hosting cost **$0.00/month** at hobby traffic levels (SC-006).
- Deploy workflow completes in **≤ 10 minutes** on a stock GitHub-hosted runner (SC-005).
- Entire feature must **not modify `build.zig.zon`** — raylib commit + hash stay as-is (FR-014).
**Scale/Scope**: One published site, one primary host + two alternatives documented. Build output expected under ~8 MB uncompressed `.wasm` (data-model V3).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Gates derived from `.ai-board/memory/constitution.md`:

| Gate | Constitution clause | Plan compliance | Status |
|---|---|---|---|
| G1 — Single-module game loop preserved | §Code Patterns/1 | Web changes live inline in `src/main.zig` (`main()` only) plus a new `src/web/shell.html` (HTML, not Zig). No new abstraction layers or indirection. | PASS |
| G2 — C interop walled off in `src/raylib.zig` | §Code Patterns/2 | `@cInclude("emscripten/emscripten.h")` is added **inside the existing `@cImport` block** in `src/raylib.zig`, gated by `target.os.tag == .emscripten`. No other file calls `@cImport`. | PASS |
| G3 — Named constants for new tunables | §Code Patterns/3 | New tunables (`WEB_CANVAS_ID`, `WEB_PRELOAD_ROOT`) promoted to module-level `const` at the top of `src/main.zig` (or a new `src/web_config.zig` if more than two emerge). No magic numbers introduced. | PASS |
| G4 — Paired `Init…` / `defer Close…` | §Code Patterns/4, §Agent Authority/c | Web build reuses the existing `defer` cleanup stack in `main()`. No new `Init…` / `Load…` calls are added; the Emscripten main-loop callback does **not** load/unload resources per frame (research §3.1, §3.10). | PASS |
| G5 — Optional pointers unwrapped safely | §Code Patterns/5 | Any new optional (e.g. `?*FrameContext` passed through `emscripten_set_main_loop_arg`) uses `if (x) |val|` (research §3.3). | PASS |
| G6 — Allocator threaded through parameters | §Code Patterns/6 | Web callback receives the allocator via its `arg` pointer; no reach-into `std.heap.page_allocator` (research §3.4). | PASS |
| G7 — Fixed-size pools | §Code Patterns/7 | Zombie pool unchanged. No new dynamic entity kinds. | PASS |
| G8 — Testing via `zig build test` | §Testing Standards/1, /2 | New `test "…" { … }` blocks added in `src/main.zig` (reachable from the root test file). No separate framework. | PASS |
| G9 — No network, no secrets in game code | §Security Practices/1, FR-011, SC-008 | Emscripten bundle makes no network requests. CI-only secrets (alt hosts) never ship inside the WASM. Grep assertion in the workflow enforces this. | PASS |
| G10 — Bounded input buffers | §Security Practices/2 | Input path unchanged (research §3.6); the web build routes the same `GetCharPressed` events through the same write site. | PASS |
| G11 — Null-terminated C-string comparison | §Security Practices/3 | Unchanged; new unit test in `src/main.zig` exercises the equality path. | PASS |
| G12 — Asset paths are literals | §Security Practices/4 | `--preload-file assets/` preserves literal `"assets/…"` paths verbatim (research §1.4, §3.8). | PASS |
| G13 — Pinned dependency hash | §Security Practices/5, FR-014 | `build.zig.zon` not modified. raylib Web build is driven by `PLATFORM=PLATFORM_WEB` at the Makefile level of the same pinned source (research §1.2). | PASS |
| G14 — `zig build` is the gate | §Code Quality/1 | Native `zig build` still succeeds with zero new warnings (SC-004). CI verifies this. | PASS |
| G15 — Idiomatic error handling | §Code Quality/2 | Fallible web init returns `!T`; allocation sites use `errdefer` (research §3.5). No `catch unreachable` in gameplay code. | PASS |
| G16 — Naming discipline | §Code Quality/3 | New identifiers follow the existing casing: `snake_case` for runtime vars, `SCREAMING_SNAKE_CASE` for compile-time consts, `camelCase` for functions, `PascalCase` for types. Raylib / Emscripten C identifiers keep upstream casing. | PASS |
| G17 — No unused imports or dead code | §Code Quality/5 | Web-only imports (`@cInclude("emscripten/emscripten.h")`) are gated so native builds neither pull them in nor warn on them. | PASS |
| G18 — Commit / PR expectations | §Governance/2, /3 | PRs will describe gameplay-visible changes (none expected), call out the `build.zig` delta (new `web` step), and include manual-test notes for browser verification. | PASS |

**Result**: All gates pass at plan time. No Complexity Tracking entries required. Re-evaluated after Phase 1 design below — still passing.

### Post-Phase-1 re-evaluation

After generating `research.md`, `data-model.md`, `contracts/*`, and `workflows/deploy-web-workflow.md`, re-checking every gate above:

- No gate's compliance rationale changed.
- No new abstraction, allocator, input surface, or network capability was introduced by the design artifacts.
- The single design choice that touches existing source — swapping the `while (!WindowShouldClose())` loop for `emscripten_set_main_loop_arg` behind a `target.os.tag == .emscripten` check — is explicitly permitted by §Agent Authority (agents may edit source), preserves the `defer` stack (§Code Patterns/4), and keeps C interop walled off (§Code Patterns/2).

**Result**: All gates still pass. Proceed to `/ai-board.tasks`.

## Project Structure

### Documentation (this feature)

```
specs/DEATHN-1-build-and-deploy/
├── plan.md                              # This file
├── research.md                          # Phase 0 output
├── data-model.md                        # Phase 1 output
├── contracts/
│   ├── build-commands.md                # CLI contract for zig build {native, web, test}
│   └── web-output-layout.md             # Filesystem contract for zig-out/web/
├── workflows/
│   └── deploy-web-workflow.md           # .github/workflows/deploy-web.yml spec
├── deployment-guide.md                  # PRIMARY: GitHub Pages (authored during /ai-board.implement)
├── deployment-cloudflare-pages.md       # ALTERNATIVE: Cloudflare Pages (authored during /ai-board.implement)
├── deployment-gcp-firebase.md           # ALTERNATIVE: GCP Firebase Hosting (authored during /ai-board.implement)
├── checklists/                          # (pre-existing)
├── spec.md                              # (pre-existing)
└── tasks.md                             # Phase 2 output (/ai-board.tasks — not created by this command)
```

### Source Code (repository root)

The project is a **single Zig module tree**. The web addition layers on top without a second tree:

```
repo root
├── build.zig                            # [MODIFIED] Add `web` step + wasm32-emscripten branch
├── build.zig.zon                        # [READ-ONLY] raylib pin preserved (FR-014)
├── src/
│   ├── main.zig                         # [MODIFIED] main() branches on target; new test blocks
│   ├── raylib.zig                       # [MODIFIED] Add emscripten.h inside existing @cImport
│   ├── zombie_names.zig                 # [UNCHANGED]
│   └── web/
│       └── shell.html                   # [NEW] Custom --shell-file for emcc
├── assets/                              # [UNCHANGED] Bundled via --preload-file
│   ├── z_spritesheet.png
│   ├── zombie-hit.wav
│   └── …
├── .github/
│   └── workflows/
│       └── deploy-web.yml               # [NEW] Build + publish to GitHub Pages
├── AGENTS.md                            # [APPEND] Short "Web / WASM build" note
├── CLAUDE.md                            # [APPEND] Same note (updated by update-agent-context.sh)
└── README.md                            # [APPEND] Link to deployment-guide.md
```

**Structure Decision**: Preserve the single-module layout mandated by constitution §Code Patterns/1. The only new subdirectory is `src/web/` for the HTML shell (not Zig code), which keeps all gameplay source at the root of `src/`. A full `src/web/` module tree is **not** introduced — one HTML file does not justify it, and the constitution forbids premature indirection. `.github/workflows/` is created because the repo has no existing `.github/` directory, but it holds CI config, not source.

## Implementation Phases (narrative summary for `/ai-board.tasks`)

These phases are **narrative only** — `/ai-board.tasks` will decompose them into an ordered, dependency-aware task list. They reference the file paths and patterns established in `research.md`.

### Phase A — Native build safety net

1. Add pure-logic `test "…" { … }` blocks to `src/main.zig`:
   - name-match equality (pattern §3.7),
   - input-buffer bounds (pattern §3.6),
   - frame-index wrap-around.
2. Confirm `zig build test` passes on the host. This phase establishes the regression signal for Phase B.

### Phase B — Emscripten-aware source changes (native still works)

1. Extend `src/raylib.zig` to conditionally `@cInclude("emscripten/emscripten.h")` when `target.os.tag == .emscripten` (pattern §3.2).
2. Extract the body of `main()`'s `while (!WindowShouldClose())` loop into a `frame(ctx: *FrameContext) void` helper. The `FrameContext` struct carries the allocator and RNG (pattern §3.4).
3. In `main()`, branch on `@import("builtin").target.os.tag == .emscripten`:
   - Native: existing `while` loop calls `frame(&ctx)`.
   - Emscripten: `raylib.emscripten_set_main_loop_arg(frame_c_callback, &ctx, 0, 1)` where `frame_c_callback` is a `callconv(.C)` trampoline wrapping `frame`.
4. Confirm `zig build` (native) still produces a working game with zero new warnings.

### Phase C — Web build plumbing in `build.zig`

1. Add `-Dtarget=wasm32-emscripten` detection and a `web` step (contracts/build-commands.md §Command 4).
2. Under the web branch: compile the game as a static library (or object), invoke raylib's Makefile with `PLATFORM=PLATFORM_WEB GRAPHICS=GRAPHICS_API_OPENGL_ES2` from within the raylib dependency's source directory, then link with `emcc` using:
   - `--shell-file src/web/shell.html`
   - `--preload-file assets/`
   - `-sUSE_GLFW=3 -sFULL_ES2=1 -sASYNCIFY=0` (with `ASYNCIFY=1` as a documented fallback — research §1.6)
   - `-o zig-out/web/index.html`
3. Add a post-link step that copies `assets/` into `zig-out/web/assets/` (contract L1 belt-and-suspenders).
4. Verify the output layout matches `contracts/web-output-layout.md`.

### Phase D — HTML shell

1. Create `src/web/shell.html`:
   - Inline CSS, inline JS, no remote `<script>` or `<link>`.
   - Loading indicator visible until Emscripten's `Module.onRuntimeInitialized` fires.
   - WebGL detection (`canvas.getContext("webgl2") || canvas.getContext("webgl")`) with a text fallback message on failure.
   - `<meta http-equiv="Cache-Control" content="no-cache">` on the shell itself (contracts/web-output-layout.md §Caching).
   - `<canvas id="canvas" tabindex="0">` with focus-on-click so typing is routed to the game (edge case "Keyboard input swallowed by the page").

### Phase E — Local verification

1. Run `zig build web`. Confirm the layout matches the contract.
2. Serve `zig-out/web/` via `python3 -m http.server 8000` and manually verify User Story 1 acceptance scenarios in Chrome and Firefox (SC-003).
3. Capture the Network panel — confirm zero non-same-origin requests (SC-008 manual check).

### Phase F — GitHub Actions workflow

1. Author `.github/workflows/deploy-web.yml` per `workflows/deploy-web-workflow.md`.
2. Ensure the workflow's no-remote-fetch grep runs on `index.html` only (the Emscripten-generated `index.js` legitimately contains URL-shaped strings like error messages; grepping it would false-positive).
3. Commit, push, and verify the workflow runs and publishes successfully.

### Phase G — Deployment guides

Author three guides in `specs/DEATHN-1-build-and-deploy/` (data-model §Entity 3 fields):

1. `deployment-guide.md` (GitHub Pages, primary).
2. `deployment-cloudflare-pages.md` (alternative).
3. `deployment-gcp-firebase.md` (alternative — GCP path the user mentioned).

Each must be independently completable (SC-007) and include a dated "Free-tier limits" section (FR-010, FR-015).

### Phase H — Documentation touch-ups

1. Append a "Web / WASM build" note to `README.md`, `CLAUDE.md`, and `AGENTS.md` linking to `deployment-guide.md`.
2. Run `update-agent-context.sh claude` once the plan's Technical Context is finalized to refresh the Claude-specific context file.

## Testing Strategy

Following constitution §Testing Standards and the existing-files inventory in research.md §2.4:

- **Unit tests** live in `src/main.zig` (the root test file) — new `test "…" { … }` blocks for pure logic only (name equality, bounded input, frame wrap). **No new test file is created**; the constitution's "tests reachable from `src/main.zig`" discovery rule requires co-location.
- **No integration or E2E harness** is added. The game has no automated GUI test (constitution §Testing Standards/4); browser behavior is verified manually per the spec's User Story 1 acceptance scenarios.
- **Manual-test note requirement** (§Testing Standards/4, §Governance/3): the PR description must include a manual-test note — what was played, on which browser(s), and whether all acceptance scenarios passed.
- **Determinism**: the added tests do **not** use `std.time.milliTimestamp()`; any PRNG-dependent test seeds the `DefaultPrng` explicitly (§Testing Standards/5).
- **CI test step**: the `deploy-web.yml` workflow runs `zig build test` (native) before `zig build web` to catch regressions before a deploy.

## Complexity Tracking

*(None — Constitution Check passed with no violations.)*

No deviations from constitution, no complexity budget used. Every addition sits inside an existing pattern (research.md §3) or is a self-contained new artifact (HTML shell, YAML workflow, markdown guides).

---

## Artifacts produced by Phases 0 and 1

| Path | Phase | Purpose |
|---|---|---|
| `specs/DEATHN-1-build-and-deploy/research.md` | 0 | Decisions, existing-file inventory, patterns to follow |
| `specs/DEATHN-1-build-and-deploy/data-model.md` | 1 | Build-artifact / workflow-run / guide entity shapes |
| `specs/DEATHN-1-build-and-deploy/contracts/build-commands.md` | 1 | CLI contract (`zig build` / `run` / `test` / `web`) |
| `specs/DEATHN-1-build-and-deploy/contracts/web-output-layout.md` | 1 | Filesystem contract for `zig-out/web/` |
| `specs/DEATHN-1-build-and-deploy/workflows/deploy-web-workflow.md` | 1 | `.github/workflows/deploy-web.yml` spec |
| `CLAUDE.md` | 1 | Agent context refreshed via `update-agent-context.sh claude` |

## Next step

Run `/ai-board.tasks` to decompose Phases A–H into an ordered `tasks.md`.
