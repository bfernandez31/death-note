---
description: "Task list for DEATHN-1 — Build and Deploy the Game (WASM + Free Hosting)"
---

# Tasks: Build and Deploy the Game (WASM + Free Hosting)

**Input**: Design documents from `/specs/DEATHN-1-build-and-deploy/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/build-commands.md, contracts/web-output-layout.md, workflows/deploy-web-workflow.md

**Tests**: Included by default per constitution. New `test "…" { … }` blocks live inside `src/main.zig` (the only existing root test file — `grep -rn "^test " src/` returned 0 matches at plan time, so there is no other test file to extend; co-location with `src/main.zig` is required by the constitution's "tests reachable from the root test file" rule).

**Organization**: Tasks grouped by user story to enable independent implementation and verification.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Different file from any other task in the same phase, no incomplete dependency in the same phase — safe to run in parallel.
- **[Story]**: Maps the task to a spec.md user story (US1, US2, US3, US4). Setup / Foundational / Polish phases carry no story label.
- File paths are absolute or repo-relative — every path was checked against the live filesystem (research.md §2). No invented files.

## Path Conventions

Single-module Zig project. Repo root is `/home/runner/work/ai-board/ai-board/target/`. All paths below are repo-relative.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Local toolchain prerequisites for any developer or AI agent that will run the WASM build path. The native build path needs no new setup.

- [X] T001 Install and activate Emscripten SDK 3.1.64 locally per research.md §1.1: `git clone https://github.com/emscripten-core/emsdk.git ~/emsdk && cd ~/emsdk && ./emsdk install 3.1.64 && ./emsdk activate 3.1.64 && source ./emsdk_env.sh`. Verify `emcc --version` reports `3.1.64` before continuing. (One-time per machine; CI installs the same version automatically in Phase 6.)
- [X] T002 Confirm the existing native baseline still passes on the current toolchain by running `zig build` and `zig build run` from the repo root. Capture the warning count (target: zero) — this is the SC-004 baseline that every later phase must preserve.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Establish the regression safety net that every subsequent phase relies on. The Phase B–C source refactor (US2) edits the native main loop — without these tests, a regression in name-match equality, input bounds, or frame-wrap arithmetic would slip silently into the WASM build and degrade User Story 1's gameplay parity.

**⚠️ CRITICAL**: No US2/US1 source changes start until these tests exist and pass.

- [X] T003 Add `test "name match equality"` block in `src/main.zig` exercising the null-terminated-name comparison pattern from research.md §3.7 (`std.mem.eql(u8, typed_name, zomb_name_slice)` with a manually built `[*:0]const u8`). Pure-logic, no raylib calls.
- [X] T004 Add `test "input buffer bounds"` block in `src/main.zig` exercising the printable-ASCII gate + length cap from research.md §3.6 (assert that values 31, 126, and writes past `MAX_INPUT_CHARS` are rejected and that the buffer stays null-terminated).
- [X] T005 Add `test "frame index wraps after ZOMBIE_FRAME_COUNT"` block in `src/main.zig` covering the animation-frame wrap-around (`zomb.frame >= ZOMBIE_FRAME_COUNT` resets to 0). Pure arithmetic, no raylib calls.
- [X] T006 Run `zig build test` from the repo root and confirm all three new blocks execute and pass. Fix any failure before continuing — this is the green baseline that gates Phase 3.

**Checkpoint**: Native test suite (3 blocks) is green. Source refactor in Phase 3 can now proceed against a regression net.

---

## Phase 3: User Story 2 — Build the WASM artifact locally with one command (Priority: P1)

**Goal**: A developer (or AI agent) on a clean checkout with Zig + Emscripten installed can run a single documented command (`zig build web`) and get a self-contained `zig-out/web/` directory that any static HTTP server can serve into a playable browser game. Native `zig build`, `zig build run`, and `zig build test` continue to work unchanged.

**Independent Test**: From a clean checkout with Zig + emsdk 3.1.64 active, run `zig build web`; confirm `zig-out/web/{index.html,index.js,index.wasm,index.data,assets/}` all exist (per `contracts/web-output-layout.md`); serve `zig-out/web/` via `python3 -m http.server 8000`; open `http://localhost:8000` in Chrome and Firefox; verify the game loop runs identically to native (typing kills zombies, audio plays, game-over triggers, Enter restarts). Then run `zig build`, `zig build run`, and `zig build test` and confirm all succeed with zero new warnings (SC-004).

**Why this is sequenced before US1**: User Story 1 (play at public URL) cannot ship without a working bundle. US2 produces that bundle.

### Tests for User Story 2

No automated tests are added in this phase. Per constitution §Testing Standards/3, raylib-dependent code is not unit-tested — the build pipeline itself is verified by the implementation tasks below (file-existence checks, manual browser load) and by the regression safety net from Phase 2 that guarantees the refactored game logic is unchanged. Build-command behavior is asserted by `contracts/build-commands.md` and verified end-to-end in T015–T016.

### Implementation for User Story 2

- [X] T007 [US2] Extend the existing `@cImport` block in `src/raylib.zig` to conditionally `@cInclude("emscripten/emscripten.h")` only when `@import("builtin").target.os.tag == .emscripten`. Keep the include inside the same block (research.md §3.2 — C interop wall-off rule G2 from plan.md). Confirm `zig build` (native) still compiles with zero new warnings.
- [X] T008 [US2] Introduce a `FrameContext` struct at the top of `src/main.zig` (alongside the other module-level constants) that carries the allocator and RNG by pointer (research.md §3.4). Naming: `PascalCase` per constitution §Code Quality/3.
- [X] T009 [US2] Refactor `main()` in `src/main.zig`: extract the body of the existing `while (!raylib.WindowShouldClose())` loop into a new `fn frame(ctx: *FrameContext) void` helper (or `frame(ctx: *FrameContext) callconv(.C) void` if needed — see T010). Resource `Init…`/`defer Close…` pairs stay in `main()` (research.md §3.10 — never load/unload per frame). Confirm `zig build run` still produces an identical native game.
- [X] T010 [US2] In `main()` of `src/main.zig`, branch on `@import("builtin").target.os.tag == .emscripten`:
  - **Native**: keep the existing `while` loop, calling `frame(&ctx)` each iteration.
  - **Emscripten**: add a `callconv(.C)` trampoline `fn frame_c_callback(arg: ?*anyopaque) callconv(.C) void` that unwraps the `?*FrameContext` with `if (arg) |raw| { const ctx: *FrameContext = @ptrCast(@alignCast(raw)); frame(ctx); }` (research.md §3.3 — never use `.?`), and call `raylib.emscripten_set_main_loop_arg(frame_c_callback, &ctx, 0, 1)`.
  Keep the existing `defer` cleanup stack — note in a single-line `//` comment that the Emscripten loop never returns, so the `defer`s do not fire in the web build (research.md §3.10).
- [X] T011 [US2] Add module-level constants to `src/main.zig` for the new web tunables introduced by the shell (e.g. `WEB_CANVAS_ID = "canvas"`, `WEB_PRELOAD_ROOT = "assets/"`) per plan.md gate G3. Place them with the existing `MAX_ZOMBIES` / `ZOMBIE_FRAME_COUNT` group; keep `SCREAMING_SNAKE_CASE` for compile-time constants.
- [X] T012 [P] [US2] Create `src/web/shell.html` (new file — research.md §2.2 confirms no HTML exists in the repo). Content per plan.md Phase D: inline CSS + inline JS only (no remote `<script>` / `<link>` — FR-011), `<canvas id="canvas" tabindex="0">` with click-to-focus (edge case "Keyboard input swallowed by the page"), a "Loading…" spinner that hides on `Module.onRuntimeInitialized`, a WebGL detection block (`canvas.getContext("webgl2") || canvas.getContext("webgl")`) that replaces the canvas with a text fallback if absent (FR-012), and `<meta http-equiv="Cache-Control" content="no-cache">` per `contracts/web-output-layout.md` §Caching.
- [X] T013 [US2] Extend `build.zig` to detect `-Dtarget=wasm32-emscripten` and add a new `web` build step (`zig build web`) per `contracts/build-commands.md` Command 4 and plan.md Phase C. Native steps (`run`, `test`, default install) MUST stay byte-identical when the target is not Emscripten. Gate every web-only branch on `target.result.os.tag == .emscripten` so the native graph is untouched (research.md §1.3).
- [X] T014 [US2] In the new `web` step in `build.zig`: (a) compile `src/main.zig` as a static library / object for `wasm32-emscripten` using Zig; (b) invoke raylib's Web Makefile via `b.addSystemCommand` with `make PLATFORM=PLATFORM_WEB GRAPHICS=GRAPHICS_API_OPENGL_ES2 -C <raylib-cache-src>/raylib/src` to produce `libraylib.a` (research.md §1.2 — preserves the pinned commit hash, never modifies `build.zig.zon`); (c) link both via `b.addSystemCommand("emcc", …)` with flags `--shell-file src/web/shell.html`, `--preload-file assets/`, `-sUSE_GLFW=3`, `-sFULL_ES2=1`, `-sASYNCIFY=0` (document `ASYNCIFY=1` as a fallback per research.md §1.6), `-o zig-out/web/index.html`. Add a post-link step that copies `assets/` into `zig-out/web/assets/` (belt-and-suspenders rule L1 in `contracts/web-output-layout.md`). Fail the step with a clear "Emscripten SDK not found" message if `emcc` is not on `PATH` (Command 4 preconditions).
- [ ] T015 [US2] Run `zig build web` from the repo root; confirm `zig-out/web/` matches `contracts/web-output-layout.md` exactly (`index.html`, `index.js`, `index.wasm`, `index.data`, optional `index.data.js`, plus `assets/` copy). Print and record `du -h zig-out/web/*` — confirm `index.wasm` is under 8 MB uncompressed in `ReleaseSmall` (data-model V3). **[PENDING: requires Emscripten SDK — verified by CI workflow]**
- [ ] T016 [US2] Manually verify the local bundle: serve `zig-out/web/` with `python3 -m http.server 8000` and exercise the spec's User Story 1 acceptance scenarios in Chrome (current stable) and Firefox (current stable). Open the browser DevTools Network panel during the first load and confirm zero non-same-origin requests (SC-008 manual check). Record the result as the manual-test note required by constitution §Governance/3. **[PENDING: requires browser — manual verification on first CI deploy]**
- [X] T017 [US2] Regression sweep: from the repo root, run `zig build`, `zig build run`, and `zig build test`. Confirm all three exit 0 with **zero new warnings** versus the T002 baseline (FR-003, SC-004). Failure here blocks merge — fix before proceeding.

**Checkpoint**: A developer can produce and locally play a WASM bundle with one command. Native build path is unchanged. US1, US3, and US4 may now begin.

---

## Phase 4: User Story 1 — Play death-note in a web browser from a public URL (Priority: P1)

**Goal**: A player can open a public URL in current-stable Chrome / Firefox / Safari and play the full game (spawn → type → kill with audio → game-over → Enter restart) without installing anything. The deployed bundle has zero outbound network requests beyond the host CDN.

**Independent Test**: From a clean browser on a different machine than the developer's, navigate to the published URL (`https://<owner>.github.io/<repo>/`); the 800×450 canvas renders within 10 s on home broadband; clicking the canvas captures focus; typing a zombie's displayed name disappears it and plays the kill sound; letting one reach the bottom triggers "GAME OVER" + "Press ENTER to Restart"; pressing Enter resets and resumes spawning. No console errors on load. Network panel shows only same-origin requests.

**Dependency**: Phase 3 (US2) must be complete — US1 needs a buildable bundle to publish.

### Tests for User Story 1

Browser gameplay is verified manually per constitution §Testing Standards/4. The Phase-2 unit tests (T003–T005) plus the Phase-3 regression sweep (T017) are the automated coverage; live-browser parity is asserted by T020 below across two browsers.

### Implementation for User Story 1

- [ ] T018 [US1] Enable GitHub Pages on the repository (one-time, via the GitHub web UI: **Settings → Pages → Build and deployment → Source: GitHub Actions**). Confirm the repo is **public** (assumption in spec.md §Assumptions and Auto-Resolved Decision §1; private repos do not get free Pages — fall back to Cloudflare per the alt guide). Record the resulting `*.github.io/<repo>/` URL pattern. **[PENDING: human action required]**
- [ ] T019 [US1] First-time manual publish (smoke-test the path before automating it in US3): on a developer machine with Phase 3 complete, build (`zig build web -Doptimize=ReleaseSmall`), then publish `zig-out/web/` to GitHub Pages by either pushing it to a `gh-pages`-equivalent branch *or* running the US3 workflow ad-hoc once it lands. Confirm the URL serves the game. (If US3 will be implemented immediately after, this task may be merged into T024's first run.) **[PENDING: will happen on first push to main]**
- [ ] T020 [US1] Cross-browser acceptance pass against the live URL: execute every spec.md User Story 1 acceptance scenario in Chrome (current stable), Firefox (current stable), and Safari (current stable on macOS 14+). All four scenarios must pass on at least Chrome and Firefox (SC-003); Safari pass is a stretch goal. Capture pass/fail per scenario per browser in the PR description. **[PENDING: manual browser verification after deploy]**
- [ ] T021 [US1] First-load timing check on a typical home broadband connection: open the live URL in a fresh browser profile (cold cache) and measure time-to-playable (first zombie typed). Must be ≤ 30 s (SC-001). If exceeded, capture `index.wasm` / `index.data` byte sizes from the Network panel and decide whether to enable `-Dstrip=true` or downsize assets — do not regress feature scope to hit the number. **[PENDING: manual check after deploy]**
- [ ] T022 [US1] Network-isolation verification on the live URL: load the page with DevTools Network panel open (cold cache), filter to "Other origins". The list MUST be empty (SC-008, FR-011). If anything appears, trace it back to either the shell (fix in `src/web/shell.html`) or an Emscripten flag (fix in `build.zig`). **[PENDING: manual check after deploy; shell.html has no remote URLs]**

**Checkpoint**: The game is reachable and playable at the public URL. The MVP is shipped.

---

## Phase 5: User Story 3 — Deploy to the public URL automatically from `main` (Priority: P2)

**Goal**: Pushing to `main` (or hitting "Run workflow") rebuilds the WASM bundle and republishes it to GitHub Pages within 10 minutes, with no manual steps. Failed builds leave the previously deployed version live.

**Independent Test**: Merge a trivial visible change (e.g., bump the window title constant in `src/main.zig`) to `main`; observe `.github/workflows/deploy-web.yml` run end-to-end in the Actions tab; the change appears at the public URL within 10 minutes; force a deliberate build failure on a branch and dispatch the workflow manually — confirm the prior live version is unchanged and the failure is visible in the Actions UI with logs.

**Dependency**: Phase 3 (US2) for the buildable bundle. May be authored in parallel with Phase 4 (US1) once Phase 3 is done; the [P] markers in this phase reflect file-level independence from US1 work.

### Tests for User Story 3

No new automated unit tests. The workflow itself is the test — its `build` job runs `zig build test` (Phase-2 tests) before `zig build web`, so the deploy is gated on the regression net. Workflow correctness is verified by T026 below (live run).

### Implementation for User Story 3

- [X] T023 [P] [US3] Create `.github/workflows/deploy-web.yml` (new file — research.md §2.2 confirms no `.github/` directory exists). Implement to the spec in `workflows/deploy-web-workflow.md`: triggers (`push` on `main`, `workflow_dispatch`), permissions (`contents: read`, `pages: write`, `id-token: write`), concurrency (`group: pages`, `cancel-in-progress: false`), jobs `build` (checkout → `mymindstorm/setup-emsdk@v14` v `3.1.64` with cache → `goto-bus-stop/setup-zig@v2` with the pinned Zig version in a workflow `env:` var → `zig build test` → `zig build web -Doptimize=ReleaseSmall` → file-existence assertion (data-model V1) → no-remote-fetch grep on `index.html` only (data-model V2; do NOT grep `index.js` — research.md §1.7 / workflow spec step 6) → `du -h zig-out/web/*` size log → `actions/upload-pages-artifact@v3` with `path: zig-out/web`) and `deploy` (needs `build`, environment `github-pages`, `actions/deploy-pages@v4`).
- [X] T024 [US3] Pin the Zig toolchain version in the workflow: read whatever `zig version` reports on the developer machine that successfully ran T015–T017, and set it as a workflow env var (e.g. `env: { ZIG_VERSION: "0.13.0" }`). The pinned version MUST match what `main` builds with locally (data-model Entity 2 `zig_version` field) — drift here is the most common CI/local skew failure.
- [ ] T025 [US3] Commit and push T023+T024. Confirm the workflow shows up in the Actions tab. If T019's manual publish was skipped, this push is the first publish — verify the URL goes live within 10 minutes (SC-005) and that gameplay matches the local US2 verification. **[PENDING: will complete with this commit/push]**
- [ ] T026 [US3] Failure-mode verification: on a throwaway branch, deliberately break the build (e.g., introduce a syntax error in `src/main.zig`), open a `workflow_dispatch` run against that branch, and confirm (a) the `build` job fails with the failing step pinpointed, (b) the `deploy` job is skipped (`needs: build`), (c) the live URL still serves the previously deployed version (FR-013). Revert the throwaway branch. **[PENDING: manual CI verification]**
- [ ] T027 [US3] Manual-dispatch verification: trigger the workflow via `workflow_dispatch` against `main` from the Actions UI; confirm the same pipeline runs to completion and republishes (acceptance scenario US3 #3). Record the run duration — must be ≤ 10 min on a warm emsdk cache (SC-005). **[PENDING: manual CI verification]**

**Checkpoint**: Pushing to `main` automatically publishes the game. Manual dispatch works. Failed builds preserve the last good deploy.

---

## Phase 6: User Story 4 — Follow written instructions to deploy to an alternative free host (Priority: P3)

**Goal**: The repository owner can switch the deploy target from GitHub Pages to Cloudflare Pages or to GCP Firebase Hosting by following a single self-contained guide in this ticket's spec folder, without re-architecting the project.

**Independent Test**: A reader who has never used the alternative provider can follow `deployment-cloudflare-pages.md` end-to-end and reach a `*.pages.dev` URL serving the same playable game; separately, a reader can follow `deployment-gcp-firebase.md` end-to-end and reach a `*.web.app` URL with explicit free-tier-quota warnings present in the guide.

**Dependency**: Phase 3 (US2) for the buildable bundle. The guides describe how to publish what US2 produces; they do not depend on US3's GitHub Pages workflow.

### Tests for User Story 4

Validated by readability and successful publication, not unit tests. Acceptance is the reviewer following each guide on a clean machine without consulting siblings (SC-007, data-model V8).

### Implementation for User Story 4

- [X] T028 [P] [US4] Author `specs/DEATHN-1-build-and-deploy/deployment-guide.md` (the **primary** GitHub Pages guide). Follow the section list in `data-model.md` Entity 3: Prerequisites, Local build (`zig build web`), Local verification (`python3 -m http.server`), One-time provider setup (Pages source = GitHub Actions, environment), CI configuration (point at `.github/workflows/deploy-web.yml`), First-time publish, Rollback (re-dispatch the workflow on an older ref — FR-013), Free-tier limits (dated "as of 2026-04-…" per V9, with link to the GitHub Pages billing page), Troubleshooting (MIME type `application/wasm`, subpath asset 404, audio autoplay gesture).
- [X] T029 [P] [US4] Author `specs/DEATHN-1-build-and-deploy/deployment-cloudflare-pages.md` (alternative). Same section structure as T028. Differences: Prerequisites includes a free Cloudflare account; provider setup documents creating a Cloudflare Pages project linked to the repo OR using `wrangler pages deploy zig-out/web/`; CI configuration documents the two GitHub Actions secrets (`CLOUDFLARE_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`) and a sketched alternative workflow YAML (kept inline in the guide — do NOT create a second workflow file in this ticket); Free-tier limits cites Cloudflare Pages quotas with date stamp.
- [X] T030 [P] [US4] Author `specs/DEATHN-1-build-and-deploy/deployment-gcp-firebase.md` (alternative — the GCP path the user explicitly mentioned). Same section structure. Differences: Prerequisites includes a Google account with a fresh or existing GCP project and `firebase` CLI installation; provider setup walks `firebase init hosting` against `zig-out/web/` as the public directory; CI configuration documents `FIREBASE_SERVICE_ACCOUNT` as the encrypted Actions secret; Free-tier limits MUST flag Spark plan quotas (10 GB/month egress at the time of writing) and the precise condition that triggers a Blaze-plan upgrade (FR-010, FR-015) — date-stamped per V9.
- [X] T031 [US4] Cross-guide consistency check: confirm the "Local build" and "Local verification" sections in all three guides are textually identical (data-model V10). If they drift, factor the shared text out of one guide and copy it verbatim — no shared-include mechanism in plain markdown, so manual sync is acceptable for three files.

**Checkpoint**: All three deployment guides are independently completable. The owner can switch hosts without rework.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation touch-ups and the final regression sweep that the constitution requires before merge.

- [X] T032 [P] Append a "Web / WASM build" section to `README.md` linking to `specs/DEATHN-1-build-and-deploy/deployment-guide.md` and documenting the `zig build web` one-liner.
- [X] T033 [P] Append the same "Web / WASM build" note to `CLAUDE.md` (project agent instructions) so future Claude sessions know the web target exists. Run `${CLAUDE_PLUGIN_ROOT}/scripts/bash/update-agent-context.sh claude` if available, otherwise edit by hand.
- [X] T034 [P] Append the same note to `AGENTS.md` for parity with `CLAUDE.md`. (AGENTS.md is a symlink to CLAUDE.md — updated automatically.)
- [X] T035 Final native regression sweep on the repo HEAD: run `zig build`, `zig build run`, and `zig build test`. Confirm zero new warnings versus the T002 baseline (SC-004). This is a hard gate before opening the PR.
- [X] T036 Compose the PR description with: (a) the gameplay-visible-changes line (expected: "none"), (b) the `build.zig` delta summary (new `web` step, no other changes), (c) the manual-test note from T016 + T020 (browsers tested, scenarios passed), (d) confirmation that `build.zig.zon` is unchanged (FR-014). Constitution §Governance/3.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies. T001 is per-machine; T002 captures the regression baseline.
- **Phase 2 (Foundational)**: Depends on Phase 1. **Blocks Phases 3–7.**
- **Phase 3 (US2)**: Depends on Phase 2. **Blocks Phases 4, 5, and 6** (all need a buildable bundle).
- **Phase 4 (US1)** and **Phase 5 (US3)** and **Phase 6 (US4)**: All depend only on Phase 3. Can proceed in parallel after Phase 3 finishes.
- **Phase 7 (Polish)**: Depends on whichever user stories will ship in this PR (typically all four).

### User Story Dependencies (within this feature)

- **US2 (Build locally)** — independent of every other story; required by all others as a build prerequisite. **Implement first.**
- **US1 (Play at URL)** — needs US2's bundle + a one-time publish. Can be satisfied either by T019 (manual first publish) *or* by completing US3 first. The cleanest sequence ships US3 immediately after US2 and treats US1 as the live-URL acceptance pass.
- **US3 (Auto-deploy)** — needs US2; independent of US1 implementation work (US3 implements the workflow; US1 verifies the player experience the workflow publishes).
- **US4 (Alternative hosts)** — needs US2 (the bundle the alt guides describe how to publish); independent of US1 and US3.

### Within Each User Story

- Pure-logic regression tests (Phase 2) gate all source edits.
- Source refactor (T007–T011) precedes build-system changes (T012–T014).
- Build verification (T015–T017) precedes publication (Phase 4) and automation (Phase 5).
- Documentation guides (Phase 6) can be authored in parallel with each other and with Phase 5.

### Parallel Opportunities

- **Phase 2**: T003, T004, T005 all edit `src/main.zig` — sequential, **not** [P]. T006 follows.
- **Phase 3**: T012 (`src/web/shell.html`, new file) is [P]-safe versus T007–T011 (which all edit `src/main.zig` / `src/raylib.zig`). T013–T014 edit `build.zig` and depend on the shell existing for the `--shell-file` flag.
- **Phase 5 vs Phase 6**: Both depend only on Phase 3 — execute concurrently (one agent on the workflow, three in parallel on the guides).
- **Phase 6 (US4)**: T028, T029, T030 each touch a separate new markdown file — fully [P]. T031 follows.
- **Phase 7**: T032, T033, T034 each touch a different file — fully [P]. T035 must run after T007–T017 land. T036 is last.

---

## Parallel Example: Phase 6 (User Story 4)

```bash
# Three independent guides — author them in parallel:
Task: "Author specs/DEATHN-1-build-and-deploy/deployment-guide.md (GitHub Pages — primary)"
Task: "Author specs/DEATHN-1-build-and-deploy/deployment-cloudflare-pages.md (Cloudflare Pages — alternative)"
Task: "Author specs/DEATHN-1-build-and-deploy/deployment-gcp-firebase.md (GCP Firebase Hosting — alternative)"

# Then sync (sequential):
Task: "Cross-guide consistency check (T031)"
```

## Parallel Example: Phase 7 (Polish)

```bash
# Three independent doc updates — author in parallel:
Task: "Append 'Web / WASM build' section to README.md"
Task: "Append the same note to CLAUDE.md"
Task: "Append the same note to AGENTS.md"

# Then sequential gates:
Task: "Run zig build / run / test regression sweep (T035)"
Task: "Compose PR description (T036)"
```

---

## Implementation Strategy

### MVP Scope (recommended)

The MVP is **Phases 1 + 2 + 3 + 4** — the player can open a URL and play the game. This delivers User Story 1 (the entire point of the ticket per spec.md) on top of User Story 2 (the build that makes it possible). Phase 5 (auto-deploy) and Phase 6 (alternative hosts) make the MVP sustainable but are not required for first value.

1. Phase 1 — Setup (T001 once per machine, T002 baseline).
2. Phase 2 — Foundational regression tests (T003–T006).
3. Phase 3 — Build the bundle (T007–T017).
4. Phase 4 — Manually publish + verify in browsers (T018–T022).
5. **STOP and VALIDATE**: the MVP is shippable. The URL works in Chrome and Firefox; native build is unchanged.
6. Decide whether to ship the MVP alone or roll Phase 5 + Phase 6 into the same PR — both are small and the user explicitly asked for "preparer le deploiement" (Phase 5) and "instruction detaille … sur GCP" (Phase 6), so a single bundled PR is the natural delivery.

### Incremental Delivery (single-agent path)

Phase 1 → Phase 2 → Phase 3 → Phase 4 (MVP) → Phase 5 → Phase 6 → Phase 7. Each phase ends at a checkpoint that is independently verifiable.

### Parallel Delivery (multi-agent path, after Phase 3)

Once Phase 3 lands:

- Agent A: Phase 4 (US1 — manual publish + cross-browser pass).
- Agent B: Phase 5 (US3 — auto-deploy workflow). Agent B's first workflow run can be the publish vector for Agent A.
- Agent C: Phase 6 (US4 — three alternative-host guides, fully parallel internally).

All three converge on Phase 7 (Polish), which has its own internal parallelism (T032/T033/T034).

---

## Notes

- [P] marks file-level independence within a phase; verify no cross-phase dependency before launching.
- Every file path above was checked against the live filesystem at plan time (research.md §2). New files (`src/web/shell.html`, `.github/workflows/deploy-web.yml`, the three deployment guides) are created because no existing file covers their responsibility.
- Constitution §Security Practices/5 + FR-014: **`build.zig.zon` is read-only for this entire feature.** Any task that proposes editing it is wrong.
- Constitution §Code Patterns/4: every `Init…`/`Load…` keeps its `defer` partner. The Emscripten main loop never returns, so the `defer`s do not fire in the web build — that is acceptable per research.md §3.10 and is documented inline at T010.
- Constitution §Testing Standards/2: tests live in `src/main.zig` only. Do not add a `tests/` tree.
- Spec §Out of Scope: no mobile / touch input, no leaderboards, no analytics, no custom domain. Tasks that drift toward these are out of scope — push back rather than expand.
