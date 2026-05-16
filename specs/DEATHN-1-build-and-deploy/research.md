# Phase 0 Research: Build and Deploy the Game (WASM + Free Hosting)

**Feature Branch**: `DEATHN-1-build-and-deploy`
**Date**: 2026-04-22
**Scope**: Resolve every NEEDS CLARIFICATION flagged in the plan's Technical Context and inventory the files that will change (or are referenced) during implementation.

---

## 1. Open Questions (NEEDS CLARIFICATION) and Resolutions

### 1.1 What Emscripten SDK version is pinned?

- **Decision**: Pin `emsdk` to **`3.1.64`** (latest 3.1.x stable at plan time; `emcc` 3.1.64 supports `-sUSE_GLFW=3`, `-sFULL_ES2=1`, `-sASYNCIFY`, `--preload-file`, and `--shell-file` — every feature raylib's Web build and this plan rely on).
- **Rationale**: 3.1.x is the raylib-tested line for PLATFORM=Web; 3.1.64 keeps a single version across local dev instructions and CI. A single pinned version removes "works on my machine" drift.
- **Alternatives considered**:
  - **Emscripten 4.x**: rejected for now. raylib's upstream Web build documentation targets 3.1.x; moving to 4.x introduces an un-vetted variable on top of an already non-trivial integration.
  - **System-package `emscripten`** (apt/brew): rejected. Distro versions lag and vary per OS, so we cannot pin. `emsdk` is the official, reproducible installer.

### 1.2 How does Zig build raylib for `wasm32-emscripten` given the pinned raylib commit `52f2a10db610d0e9f619fd7c521db08a876547d0`?

- **Decision**: Build raylib for the Web platform **through raylib's own build.zig**, by setting the dependency target to `wasm32-emscripten` and passing `.platform = .web` as a raylib dependency option when that option exists, otherwise fall back to invoking raylib's Makefile (`make PLATFORM=PLATFORM_WEB GRAPHICS=GRAPHICS_API_OPENGL_ES2`) from `build.zig` and linking the produced `libraylib.a` manually with `emcc`.
- **Rationale**: Preserving the pinned commit hash is a constitutional requirement (FR-014, constitution §Security Practices/5). We must not bump raylib to get better Zig-Emscripten ergonomics. The pinned commit exposes a Makefile-driven Web build (`raylib/src/Makefile`, target `PLATFORM=PLATFORM_WEB`) that produces `libraylib.a` usable by `emcc`. Zig's `build.zig` integration for that commit may or may not expose a "web" option; the fallback ensures the plan works either way.
- **Alternatives considered**:
  - **Bump raylib to a newer commit**: rejected. Violates FR-014 and the constitution's pinned-dependency rule.
  - **Build raylib with Zig's own C compiler targeting `wasm32-emscripten`**: rejected. raylib's Web build needs Emscripten-specific glue (`emscripten.h`, GLFW web-emulation, OpenAL web-emulation) that only `emcc` links correctly.
  - **Switch to `wasm32-freestanding`**: rejected. No GLFW, no WebGL bridge, no audio; raylib does not function.

### 1.3 How is `zig build` wired to produce the Web bundle?

- **Decision**: Add a new build step **`web`** to `build.zig` (`zig build web`). When Zig's target option is `wasm32-emscripten`, the step:
  1. Builds the game as a **static library** (or object file) for `wasm32-emscripten` using Zig.
  2. Builds `libraylib.a` for `PLATFORM=PLATFORM_WEB` via raylib's Makefile (invoked from `build.zig` via `b.addSystemCommand`), re-using raylib's source tree from Zig's package cache.
  3. Invokes `emcc` via `b.addSystemCommand` to link the game + `libraylib.a` into `zig-out/web/index.html`, `index.js`, `index.wasm`, and the preloaded asset bundle.
  4. Copies `assets/` into `zig-out/web/assets/` as a safety net for hosts that prefer file-system assets over the Emscripten virtual FS.
- **Rationale**: A dedicated `web` step keeps the native `zig build` / `zig build run` / `zig build test` paths untouched (FR-003, SC-004). All web-only complexity lives behind one conditional branch gated on `target.result.os.tag == .emscripten`.
- **Alternatives considered**:
  - **Conditional inside the existing `install` step**: rejected. Native users would see web-only errors if Emscripten is not installed. A separate step is opt-in.
  - **A separate `build-web.zig` file**: rejected. Two build scripts double the surface area; the delta is small enough to fit in `build.zig`.

### 1.4 How are runtime assets bundled into the WASM artifact?

- **Decision**: Use **Emscripten's `--preload-file assets/`** so every file under `assets/` is packaged into the Emscripten virtual filesystem (`index.data`) and becomes available to `raylib.LoadTexture("assets/…")` / `raylib.LoadSound("assets/…")` at the same relative paths the native build uses.
- **Rationale**: The current code loads assets with string literals like `"assets/z_spritesheet.png"` (constitution §Security Practices/4). `--preload-file` preserves those paths verbatim, so **no source changes to `src/main.zig` are required** for asset resolution. It also sidesteps FR-004's subpath concern (GitHub Pages serves from `/<repo>/`), since `emcc` loads `index.data` relative to `index.js` at runtime rather than from an absolute root.
- **Alternatives considered**:
  - **`--embed-file`**: rejected. Embeds assets into the `.wasm` (larger binary, re-download on every version bump); `--preload-file` keeps them in a separate `.data` file that some hosts can cache independently.
  - **Host assets as loose files and fetch them at runtime**: rejected. Would require changing raylib's asset-path logic, and hits FR-004 subpath failure modes head-on.

### 1.5 What HTML shell is used?

- **Decision**: Use a **custom `src/web/shell.html`** passed to `emcc --shell-file` that:
  - Renders a loading indicator (spinner + "Loading…" text) until Emscripten's `Module.onRuntimeInitialized` fires (FR-012).
  - Detects WebGL availability via `canvas.getContext("webgl2") || canvas.getContext("webgl")` and, on failure, replaces the canvas with a text message explaining the requirement (FR-012, edge case "No GPU / WebGL disabled").
  - Contains **no analytics, no remote fonts, no remote scripts** (FR-011, SC-008). The shell is self-contained HTML + inline CSS + inline JS.
  - Forwards keyboard focus to the canvas (edge case "Keyboard input swallowed by the page") via `canvas.setAttribute("tabindex", "0")` and a click-to-focus handler.
- **Rationale**: Emscripten's default `shell_minimal.html` is too bare (no loading indicator, no WebGL guard) and its default `shell.html` pulls extra UI we do not need. A custom shell is ~50 lines and fully under our control.
- **Alternatives considered**:
  - **Emscripten default `shell.html`**: rejected. Fails FR-012's loading-indicator-and-WebGL-error-surface requirements out of the box.
  - **A JS framework (React/Svelte) for the shell**: rejected. Adds a toolchain and violates FR-011 (only the host CDN should serve files).

### 1.6 Will raylib's main-loop integration work under Emscripten?

- **Decision**: The current `while (!raylib.WindowShouldClose()) { … }` loop **must be replaced with `emscripten_set_main_loop_arg`** when built for `wasm32-emscripten`. Browsers cannot block on a `while` loop — the main thread must return to the event loop each frame. Compile-time branching using `@import("builtin").target.os.tag == .emscripten` selects between the two loop shapes inside `main()`.
- **Rationale**: This is a documented Emscripten requirement. raylib's own Web examples ([raylib-5.0/examples/web](https://github.com/raysan5/raylib/tree/master/examples)) all use `emscripten_set_main_loop`. Without it, the canvas never paints and the browser tab freezes on load.
- **Alternatives considered**:
  - **`-sASYNCIFY`**: viable workaround (`emcc -sASYNCIFY` can make synchronous `while` loops yield to the browser), but it inflates the `.wasm` 30–50% and slows execution. Use only if the main-loop refactor proves disruptive. **Documented as a fallback**, not the default.
  - **Ship only native**: rejected — defeats the entire ticket.

### 1.7 Which GitHub Actions deploy pattern?

- **Decision**: Use the **official `actions/deploy-pages@v4`** + **`actions/upload-pages-artifact@v3`** pattern. One `build` job produces the artifact, one `deploy` job consumes it. Triggers: `push` on `main` *and* `workflow_dispatch`. The `deploy` job requires the `pages: write` + `id-token: write` permissions and the `github-pages` environment.
- **Rationale**: This is GitHub's maintained, first-party deployment pattern for Pages. It inherits every security improvement GitHub ships (no manual `gh-pages` branch, no PAT management). Free on public repos.
- **Alternatives considered**:
  - **`peaceiris/actions-gh-pages`**: still popular but pushes to a `gh-pages` branch, which leaves a rewriteable artifact trail in Git history and requires a token. Rejected in favor of the official artifact-based approach.
  - **Manual `gh-pages` branch push**: rejected. Highest maintenance burden, easiest to get wrong.

### 1.8 Emscripten SDK caching in CI

- **Decision**: Use the **`mymindstorm/setup-emsdk@v14`** action with its built-in cache keyed on the pinned emsdk version (`3.1.64`). On a cold cache, a full install is ~1 min; warm cache restores in a few seconds.
- **Rationale**: This action is the community-standard `emsdk` installer for GitHub Actions. It handles `emsdk install`, `emsdk activate`, and environment export. Its cache key is already version-scoped.
- **Alternatives considered**:
  - **Manual `actions/cache` + `git clone emsdk`**: viable but 3× the YAML. No reason to reinvent.
  - **Container pre-built with emsdk**: rejected. Dockerfile-plus-image-hosting is overkill for a single workflow.

### 1.9 Which browsers are "current stable" for acceptance?

- **Decision**: Test against **Chrome (latest stable), Firefox (latest stable), and Safari (latest stable on macOS 14+)**. Mobile browsers are out of scope (see spec §Out of Scope).
- **Rationale**: Matches the spec's User Story 1 / SC-003 wording and covers >95% of desktop web traffic.

### 1.10 How is free-tier usage monitored?

- **Decision**: Each deployment guide includes a **"Free-tier limits"** section that states the quota numbers verbatim from the provider's docs at the time of writing, links to the provider's billing/usage dashboard, and lists the triggers (bandwidth, site count, build minutes) that could move the account into paid territory.
- **Rationale**: FR-010 and FR-015 require explicit, upfront disclosure. Numbers drift, so each section is timestamped ("as of 2026-04") and pairs the number with the dashboard URL for verification.

---

## 2. Existing Files

This inventory covers every file that will be **modified**, **created**, or **referenced** by this feature. New files are only proposed where the search below found no existing file covering that responsibility.

### 2.1 Source / build (existing — will be modified)

| Path | Current role | This feature's change |
|---|---|---|
| `build.zig` | Declares executable, raylib linkage, `run` + `test` steps. | **Extend in place.** Add a `web` step that builds for `wasm32-emscripten`, builds raylib's Web platform, and invokes `emcc`. Native path untouched. |
| `build.zig.zon` | Pins raylib by URL + content hash. | **Read-only.** Must not change (FR-014). |
| `src/main.zig` | Entry point + game loop. | **Modify `main()` only.** Split the loop body into a `frame()` function and, under `@import("builtin").target.os.tag == .emscripten`, call `emscripten_set_main_loop_arg(frame, …)` instead of the native `while` loop. All gameplay code (update/draw helpers) stays byte-identical. |
| `src/raylib.zig` | `@cImport` wall for raylib headers. | **Extend.** Add `@cInclude("emscripten/emscripten.h")` inside the same `@cImport` block, gated by `@import("builtin").target.os.tag == .emscripten` so native builds do not pick it up. This preserves the constitution's "all C interop in one file" rule. |
| `src/zombie_names.zig` | Flat `[*:0]const u8` name array. | **No change.** Works verbatim under Emscripten (static data). |
| `assets/z_spritesheet.png`, `assets/zombie-hit.wav`, other assets | Runtime-loaded by `src/main.zig`. | **No change.** Bundled via `--preload-file assets/`. |
| `CLAUDE.md`, `AGENTS.md`, `README.md` | Project documentation. | **Append-only**: add "Web / WASM build" section pointing to the deployment guide (touched by `update-agent-context.sh` in Phase 1). |

### 2.2 Source / build (new — created by this feature)

| Path | Responsibility | Why a new file (confirmed no existing cover) |
|---|---|---|
| `src/web/shell.html` | HTML shell passed to `emcc --shell-file`: loading indicator, WebGL-availability check, canvas focus. | No existing HTML exists in the repo (`ls` confirms `src/` only contains the three `.zig` files). |
| `.github/workflows/deploy-web.yml` | GitHub Actions workflow: build WASM and publish to Pages. | No `.github/` directory exists yet (`ls` confirmed). |

### 2.3 Documentation / specs (new — under the ticket spec folder, per user request)

| Path | Responsibility |
|---|---|
| `specs/DEATHN-1-build-and-deploy/deployment-guide.md` | Primary guide: GitHub Pages. |
| `specs/DEATHN-1-build-and-deploy/deployment-cloudflare-pages.md` | Alternative guide: Cloudflare Pages. |
| `specs/DEATHN-1-build-and-deploy/deployment-gcp-firebase.md` | Alternative guide: GCP Firebase Hosting. |
| `specs/DEATHN-1-build-and-deploy/research.md` | This file. |
| `specs/DEATHN-1-build-and-deploy/data-model.md` | Data shapes introduced by the feature. |
| `specs/DEATHN-1-build-and-deploy/contracts/build-commands.md` | CLI contract: what `zig build web` promises. |
| `specs/DEATHN-1-build-and-deploy/contracts/web-output-layout.md` | File-layout contract of `zig-out/web/`. |
| `specs/DEATHN-1-build-and-deploy/workflows/deploy-web-workflow.md` | GitHub Actions workflow spec. |

### 2.4 Test files (existing inventory per constitution)

**Search result**: `grep -rn "^test " src/` → **0 matches**. No `test "…" { … }` blocks exist anywhere under `src/` at plan time. The constitution §Testing Standards/2 requires tests to live in the module under test and be reachable from `src/main.zig`.

| Path | Status | This feature's change |
|---|---|---|
| `src/main.zig` | No tests today. | **Add** `test "…" { … }` blocks for: (a) name-match equality (pure `std.mem.eql` logic), (b) input-buffer bounds (`letter_count < MAX_INPUT_CHARS`, printable-ASCII gate), (c) frame-index wrap-around (`zomb.frame >= ZOMBIE_FRAME_COUNT`). All three target pure logic that does **not** call raylib, so they run under `zig build test` without a windowed environment. |

**No new test file is created.** Per the constitution, pure-logic tests co-locate with the module under test (`src/main.zig`). A separate `tests/` tree would violate the "tests reachable from `src/main.zig`" discovery rule.

---

## 3. Patterns to Follow

This section extracts concrete patterns from reference files that new code must mirror. The implementation phases reference these patterns by line number, not by vague "follow the existing style".

### 3.1 Paired `Init…` / `defer Close…` for every raylib resource

- **Reference**: `src/main.zig:49-61`
  ```zig
  raylib.InitWindow(screen_width, screen_height, "Zombie Game");
  defer raylib.CloseWindow();

  raylib.InitAudioDevice();
  defer raylib.CloseAudioDevice();

  zombie_kill_sound = raylib.LoadSound("assets/zombie-hit.wav");
  defer raylib.UnloadSound(zombie_kill_sound);

  zombie_texture = raylib.LoadTexture("assets/z_spritesheet.png");
  defer raylib.UnloadTexture(zombie_texture);
  ```
- **Rule for new code**: Any new `Init…` / `Load…` call introduced under the Emscripten path **MUST** be followed immediately by a matching `defer`. In the Emscripten-main-loop refactor, the cleanup `defer`s are in `main()`; the `frame()` callback must **NOT** load/unload resources per frame.
- **Why it matters**: Constitution §Code Patterns/4 + §Agent Authority/c explicitly forbid removing the `defer` cleanup pattern without human approval.

### 3.2 C interop is walled off in `src/raylib.zig`

- **Reference**: `src/raylib.zig:1-5`
  ```zig
  pub usingnamespace @cImport({
      @cInclude("raylib.h");
      @cInclude("raymath.h");
      @cInclude("rlgl.h");
  });
  ```
- **Rule for new code**: `emscripten.h` must be added **inside this same `@cImport` block**, not via a second `@cImport` call elsewhere. Gameplay code calls the symbol as `raylib.emscripten_set_main_loop_arg(…)`, matching how it already calls `raylib.InitWindow`.
- **Why it matters**: Constitution §Code Patterns/2 — sprinkling `@cImport` across files breaks the wall-off invariant.

### 3.3 Optional pointers unwrapped with `if (x) |val|`

- **Reference**: `src/main.zig:167-202` (`updateZombies`), `src/main.zig:285-292` (`resetZombies`)
  ```zig
  if (zombie) |zomb| {
      if (!zomb.is_active) continue;
      // …
  }
  ```
- **Rule for new code**: Any new optional pointer (e.g. a `?*FrameContext` passed to `emscripten_set_main_loop_arg`) must unwrap with `if (x) |val|`, never `.?`.
- **Why it matters**: Constitution §Code Patterns/5.

### 3.4 Allocator threaded by pointer parameter

- **Reference**: `src/main.zig:260` (`spawnZombie`), `src/main.zig:285` (`resetZombies`)
  ```zig
  fn spawnZombie(allocator: *std.mem.Allocator, rng: *std.Random.Xoshiro256) !void { … }
  fn resetZombies(allocator: *std.mem.Allocator) void { … }
  ```
- **Rule for new code**: If the Emscripten main-loop callback needs an allocator, pass it through the `arg` pointer of `emscripten_set_main_loop_arg` (as a field on a `FrameContext` struct). Do **NOT** reach into `std.heap.page_allocator` from inside the callback.
- **Why it matters**: Constitution §Code Patterns/6. Lets tests swap in an arena allocator later.

### 3.5 Error handling with `errdefer` on partial allocation failure

- **Reference**: `src/main.zig:264-265`
  ```zig
  const new_zombie = try allocator.create(Zombie);
  errdefer allocator.destroy(new_zombie);
  ```
- **Rule for new code**: Any new allocation in the web path (e.g. a boxed `FrameContext`) must pair `try allocator.create(T)` with `errdefer allocator.destroy(ptr)` on the next line. Native and Emscripten builds must both honor this.
- **Why it matters**: Constitution §Code Quality/2; prevents leaks on mid-init failure.

### 3.6 Bounded input buffer + printable-ASCII gate

- **Reference**: `src/main.zig:83-90`
  ```zig
  while (key > 0) {
      if ((key >= 32) and (key <= 125) and (letter_count < MAX_INPUT_CHARS)) {
          name[letter_count] = @intCast(key);
          name[letter_count + 1] = '\x00';
          letter_count += 1;
      }
      key = raylib.GetCharPressed();
  }
  ```
- **Rule for new code**: The Emscripten-routed `GetCharPressed` events go through the identical write site. **No new input surface is introduced**, so this pattern is inherited unchanged — but if the HTML shell ever injects characters directly (it must not), the same length + ASCII-range guard applies at that write site, not downstream.
- **Why it matters**: Constitution §Security Practices/2.

### 3.7 Null-terminated C-string comparison by slice

- **Reference**: `src/main.zig:181-193`
  ```zig
  const typed_name = name[0..letter_count];
  var zomb_name_length: usize = 0;
  while (zomb.name[zomb_name_length] != '\x00') { zomb_name_length += 1; }
  const zomb_name_slice = zomb.name[0..zomb_name_length];
  if (std.mem.eql(u8, typed_name, zomb_name_slice)) { … }
  ```
- **Rule for new code**: Unchanged — this logic runs identically under Emscripten. New tests (see §2.4) exercise exactly this path to satisfy constitution §Testing Standards/3.

### 3.8 Asset paths are string literals rooted at `assets/`

- **Reference**: `src/main.zig:57, 60`
- **Rule for new code**: `--preload-file assets/` keeps literals like `"assets/zombie-hit.wav"` working verbatim inside the Emscripten VFS. **Do not rewrite any asset path.** Any new asset must be dropped into `assets/` and preloaded via the same `--preload-file` glob.
- **Why it matters**: Constitution §Security Practices/4.

### 3.9 Deploy pipeline — no secrets, no network beyond host CDN

- **Reference**: Constitution §Security Practices/1, FR-011, SC-008.
- **Rule for new code**: The GitHub Actions workflow **MUST NOT** add any step that makes a network call to a host outside `github.com`, `raw.githubusercontent.com`, or the GitHub Pages deploy action. The Cloudflare/Firebase guides will involve provider auth (by necessity for those hosts), but those runs are opt-in; the default GitHub Pages path has zero third-party secrets.
- **Pattern for alternative-host guides**: Secrets (Cloudflare API token, Firebase service account) go into **GitHub Actions encrypted secrets**, never committed. Guides must explicitly call out this separation.

### 3.10 Resource lifetime extends across the main loop

- **Reference**: `src/main.zig:50, 54, 58, 61` — all `defer Close…` / `Unload…` sit in `main()` and only fire when `main()` returns.
- **Rule for new code**: Because Emscripten's main loop does not return until `emscripten_cancel_main_loop()` is called, the `defer`s in `main()` never fire in the web build. That is acceptable (the browser tab unload handles process-level cleanup), **but we MUST NOT** move resource loads into the per-frame callback to "work around" this. Loads stay in `main()` before `emscripten_set_main_loop_arg`; closes are present but effectively unreachable in the web build — matching raylib's own Web examples.

---

## 4. Consolidated Decisions

| # | Decision | Rationale | Alternatives Rejected |
|---|---|---|---|
| D1 | Pin emsdk to `3.1.64` | Reproducible across local + CI; raylib-tested line | Emscripten 4.x (unvetted); distro packages (drift) |
| D2 | Build raylib via its Makefile (`PLATFORM=PLATFORM_WEB`) from `build.zig` | Preserves pinned raylib commit; Makefile path exists in that commit | Bump raylib (violates FR-014); Zig-native compile (lacks Emscripten glue) |
| D3 | Add a `web` step to `build.zig`; native steps untouched | Opt-in; preserves `zig build`/`run`/`test` (FR-003, SC-004) | Conditional inside `install` (breaks native UX); separate `build-web.zig` (double surface) |
| D4 | Bundle assets via `--preload-file assets/` | Zero source changes; subpath-safe | `--embed-file` (binary bloat); loose fetches (FR-004 risk) |
| D5 | Custom `src/web/shell.html` | FR-012 (loading + WebGL guard); FR-011 (no third-party fetches) | Emscripten default (fails FR-012); JS framework (violates FR-011) |
| D6 | `emscripten_set_main_loop_arg` behind `target.os.tag == .emscripten` | Browsers cannot block on `while` loops | `-sASYNCIFY` (binary bloat, slower) — documented as fallback only |
| D7 | `actions/deploy-pages@v4` + `upload-pages-artifact@v3` | Official GitHub pattern; no token management | `peaceiris/actions-gh-pages` (branch pollution); manual push (high maintenance) |
| D8 | `mymindstorm/setup-emsdk@v14` for emsdk in CI | Built-in caching; community-standard | Manual cache + clone (3× YAML); Docker image (overkill) |
| D9 | Target browsers: Chrome, Firefox, Safari (current stable) | Matches spec SC-003 and User Story 1 | Mobile browsers (out of scope per spec) |
| D10 | Deploy trigger: push-to-`main` + `workflow_dispatch` | Matches spec auto-resolved decision; supports hotfix re-runs | Tag-only (slows shipping); manual only (defeats automation) |
