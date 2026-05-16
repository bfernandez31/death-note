# Feature Specification: Build and Deploy the Game (WASM + Free Hosting)

**Feature Branch**: `DEATHN-1-build-and-deploy`
**Ticket**: DEATHN-1 — "build and deploy the game"
**Created**: 2026-04-22
**Status**: Draft
**Clarification Policy (input)**: AUTO
**Effective Policy**: CONSERVATIVE (AUTO fell back — see Auto-Resolved Decisions)
**Input**: User description: "je veu que t'ajoute un build en wasm pour pouvoir deployer le jeu sur une serveur gratuit. faut que tu trouver une solution gratuite de deploeiment du jeu. j'ai deja un compte vercel avec le free tier use, il faut donc une autre solution. je peu potentiellement faire sur gcp. il me faudra des instruction detaille dans le repertoire de spec de ce ticket sur comment faire. setup tout ce qu'il faut pour build en tout cas l'app en wasm et preparer le deploiement."

## Auto-Resolved Decisions *(mandatory when clarification policies apply)*

- **Decision**: Primary free hosting target is **GitHub Pages**, with **Cloudflare Pages** documented as a fully equivalent secondary option and **Firebase Hosting (GCP free tier)** documented as the GCP path the user mentioned. The published artifact is static (HTML + WASM + assets), so any static host works; the spec picks GitHub Pages as the default because the repository is already on GitHub, the free tier is unmetered for public repos, and deployment automates cleanly from GitHub Actions without a separate account.
  - **Policy Applied**: AUTO → CONSERVATIVE (fallback)
  - **Confidence**: Low (0.3). AUTO signals: neutral feature context (+1) and a cost constraint ("gratuit", not a speed directive) (≈0). `netScore ≈ +1`, `absScore = 1`, which is below the 0.5 high-confidence threshold, so the rules fall back to CONSERVATIVE.
  - **Fallback Triggered?**: Yes — low AUTO confidence promoted the decision to CONSERVATIVE (favor the most reliable, lowest-risk free option with zero billing surface).
  - **Trade-offs**:
    1. Scope: ties the default deploy path to GitHub. Mitigated by keeping the WASM build fully portable and documenting two alternate hosts (Cloudflare Pages, Firebase Hosting) with equivalent step-by-step instructions so the user can switch without rework.
    2. Cost/Risk: GitHub Pages has no paid upgrade surprise (public repos are free and unmetered in the normal sense); GCP free tier can incur charges if quotas are exceeded, so it is documented as a secondary path.
  - **Reviewer Notes**: Confirm (a) the repository is (or will be made) public on GitHub so Pages free tier applies, and (b) the user is comfortable with the deployed URL pattern `https://<owner>.github.io/<repo>/`. If the repo must remain private or a custom domain is required, the reviewer should redirect to Cloudflare Pages (private source allowed, custom domain on free tier) before `/ai-board.plan`.

- **Decision**: The WASM toolchain is **Zig's built-in Emscripten target** (`-Dtarget=wasm32-emscripten`) using the Emscripten SDK (`emsdk`). Raylib's upstream build supports Emscripten, so the existing `raylib_dep.artifact("raylib")` will be compiled for `wasm32-emscripten` alongside the game.
  - **Policy Applied**: CONSERVATIVE
  - **Confidence**: High. Emscripten is the only production-grade path for compiling raylib to WebAssembly with a WebGL backend, audio, input, and filesystem emulation. There is no credible alternative today (wasi-libc alone does not provide the browser glue for GLFW/WebGL/OpenAL that raylib needs).
  - **Fallback Triggered?**: No.
  - **Trade-offs**:
    1. Adds a build-time dependency on the Emscripten SDK (must be installed locally and in CI). Mitigated by pinning `emsdk` to a known-good version in the deployment guide and CI workflow.
    2. Output is larger than a raw `wasm32-freestanding` binary because it includes Emscripten's JS runtime glue, but this is the cost of getting raylib's graphics/audio/input working in the browser.
  - **Reviewer Notes**: The plan phase must pin a specific `emsdk` version and confirm raylib's Emscripten build flags (`PLATFORM=Web`, `GRAPHICS=GRAPHICS_API_OPENGL_ES2`).

- **Decision**: The **existing desktop build (`zig build`, `zig build run`, `zig build test`) MUST continue to work unchanged** on Linux/macOS/Windows. The WASM build is added as an additional target selected via a build option (e.g., `-Dtarget=wasm32-emscripten` plus a `web` step), not a replacement.
  - **Policy Applied**: CONSERVATIVE
  - **Confidence**: High. The ticket says "setup tout ce qu'il faut pour build … en wasm" ("at least build the app in wasm") without asking to drop native support, and the constitution requires preserving existing gameplay behavior.
  - **Fallback Triggered?**: No.
  - **Trade-offs**:
    1. Slightly more complex `build.zig` (conditional branches for web vs. native). Mitigated by isolating the web-specific glue (shell HTML, preload flags) behind a single target-tag check.
    2. Two build paths to regression-test. Mitigated by CI jobs that run both.
  - **Reviewer Notes**: None — this is a non-negotiable compatibility guarantee.

- **Decision**: Deployment is **automated via GitHub Actions** on push to `main` (and manually dispatchable). A build job compiles WASM, uploads the resulting directory as a Pages artifact, and a deploy job publishes it. Manual deployment instructions are also documented for the case where CI is unavailable.
  - **Policy Applied**: CONSERVATIVE
  - **Confidence**: High. The user asked for "setup tout ce qu'il faut … preparer le deploiement", which implies repeatable deployment; CI is the lowest-risk, lowest-human-error option.
  - **Fallback Triggered?**: No.
  - **Trade-offs**:
    1. Adds a workflow file under `.github/workflows/`. Well-understood, free on public repos under GitHub Actions free tier.
    2. Tying deploy-to-Pages to `main` means accidental main pushes publish immediately; mitigated by a manual `workflow_dispatch` gate and optionally requiring a tag/environment for production.
  - **Reviewer Notes**: Confirm the deploy trigger (every `main` push vs. tag-only vs. manual dispatch) during `/ai-board.plan`. Default proposed here is: push-to-main plus `workflow_dispatch`.

- **Decision**: Detailed, step-by-step deployment instructions will be authored during `/ai-board.plan` and `/ai-board.implement` under `specs/DEATHN-1-build-and-deploy/` as **`deployment-guide.md`** (primary GitHub Pages path) with two siblings: **`deployment-cloudflare-pages.md`** and **`deployment-gcp-firebase.md`** covering the alternatives. This matches the user's explicit ask: "il me faudra des instruction detaille dans le repertoire de spec de ce ticket".
  - **Policy Applied**: CONSERVATIVE
  - **Confidence**: High.
  - **Fallback Triggered?**: No.
  - **Trade-offs**: One primary guide plus two alternatives is slightly more writing up front, but it delivers the optionality the user explicitly requested ("peu potentiellement faire sur gcp").
  - **Reviewer Notes**: Docs belong in the ticket spec folder (per user request), not the project-wide `specs/specifications/` folder.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Play death-note in a web browser from a public URL (Priority: P1)

As a player (or anyone the author shares the link with), I can open a public URL in a modern desktop browser and play the full typing game — falling zombies, typed names, kill sound, game-over, restart — without installing anything.

**Why this priority**: This is the entire point of the ticket. If a player cannot load and play the game at a URL, nothing else in this feature has delivered value.

**Independent Test**: From a clean browser on a different machine than the developer's, navigate to the published URL; verify the game canvas loads, a zombie spawns, typing the correct name kills it (with audio), letting one reach the bottom triggers game over, and pressing Enter restarts. No console errors on load.

**Acceptance Scenarios**:

1. **Given** a desktop browser (Chrome/Firefox/Safari current stable) and the published URL, **When** the player opens the URL, **Then** the 800×450 game canvas renders within 10 seconds on a typical home broadband connection and input focus can be acquired by clicking the input box (matching the native build's behavior).
2. **Given** the game is running in the browser, **When** the player clicks the input box and types a zombie's displayed name character-by-character, **Then** the zombie disappears, the kill sound plays, and the input buffer clears — identical behavior to the native build.
3. **Given** a zombie reaches the bottom of the canvas, **When** it passes `screen_height`, **Then** "GAME OVER" and "Press ENTER to Restart" are displayed, and pressing Enter resets state and resumes spawning.
4. **Given** the page is refreshed, **When** the game reloads, **Then** all assets (spritesheet, hit sound) load from the same origin with no 404s.

---

### User Story 2 - Build the WASM artifact locally with one command (Priority: P1)

As a developer (or AI agent) working on the repo, I can produce the WASM + HTML + assets bundle with a single Zig build command and serve it from any static HTTP server for local verification before publishing.

**Why this priority**: Without a reproducible local build, the deploy workflow cannot be authored, debugged, or trusted. This is the foundation all deployment options share.

**Independent Test**: On a clean checkout with the documented prerequisites installed (Zig toolchain + Emscripten SDK), run the documented build command. Verify that an output directory (e.g., `zig-out/web/` or equivalent) contains at minimum an `index.html`, a `.wasm` file, a `.js` runtime glue, and the game assets, and that serving that directory over `python3 -m http.server` (or any static server) from `http://localhost:<port>/` renders a playable game.

**Acceptance Scenarios**:

1. **Given** Zig and the pinned Emscripten SDK version are installed and active, **When** the developer runs the single documented WASM build command from the repo root, **Then** the build succeeds with no warnings treated as errors and emits a self-contained web output directory.
2. **Given** the build output directory, **When** it is served by any static HTTP server on localhost, **Then** the game is playable in a local browser with identical gameplay to the native build.
3. **Given** the existing native workflow (`zig build`, `zig build run`, `zig build test`), **When** any of those commands are executed, **Then** they succeed exactly as before — the WASM target has not regressed the native build path.

---

### User Story 3 - Deploy to the public URL automatically from `main` (Priority: P2)

As the repository owner, when I push changes to `main` (or manually trigger the deploy workflow), the game is rebuilt for WASM and published to the free hosting target without manual steps, and the public URL reflects the latest commit within a few minutes.

**Why this priority**: Automates the "preparer le deploiement" ask. Downgraded to P2 because a manual-deploy fallback (documented) already makes the game publishable; CI just makes it sustainable.

**Independent Test**: Merge a trivial visible change (e.g., window title or a constant) to `main`; observe the deploy workflow run to completion and the change appear at the public URL without any manual intervention beyond the merge.

**Acceptance Scenarios**:

1. **Given** a successful merge to `main`, **When** the deploy workflow triggers, **Then** it builds the WASM bundle, publishes it to the chosen host, and the new version is live at the public URL within 10 minutes of the workflow starting.
2. **Given** the workflow fails (e.g., build error), **When** the job ends, **Then** the previously deployed version remains live and the failure is visible in the Actions tab with logs pinpointing the failing step.
3. **Given** the owner wants to deploy without merging (hotfix, retry), **When** they run the workflow via `workflow_dispatch`, **Then** the same pipeline runs and publishes the current branch's build.

---

### User Story 4 - Follow written instructions to deploy to an alternative free host (Priority: P3)

As the repository owner, I can follow the instructions in this ticket's spec folder to switch the deploy target from GitHub Pages to Cloudflare Pages, or to GCP Firebase Hosting, without re-architecting the project.

**Why this priority**: The user explicitly said "je peu potentiellement faire sur gcp" and asked for "instruction detaille … sur comment faire". Delivering alternative guides respects that optionality. Downgraded to P3 because GitHub Pages is the default happy path; this story protects against vendor lock-in.

**Independent Test**: Following only the alternative guide (no prior knowledge of the alt provider), the owner can create the required account, configure the project, and publish the same WASM bundle to Cloudflare Pages or Firebase Hosting. The resulting URL serves the same playable game.

**Acceptance Scenarios**:

1. **Given** the `deployment-cloudflare-pages.md` guide, **When** the owner follows it end-to-end with no prior Cloudflare account, **Then** the game is reachable at a `*.pages.dev` URL and gameplay matches the GitHub Pages version.
2. **Given** the `deployment-gcp-firebase.md` guide, **When** the owner follows it with a fresh or existing GCP project, **Then** the game is reachable at a `*.web.app` (or `*.firebaseapp.com`) URL, and the guide explicitly warns about free-tier quotas and how to monitor them.

---

### Edge Cases

- **No GPU / WebGL disabled**: Browsers where WebGL is unavailable (some locked-down environments) will not render the game. Expected behavior: an informative message in the page (or at minimum, the Emscripten default fallback) rather than a silent black canvas.
- **Audio autoplay policy**: Modern browsers require a user gesture before playing audio. The zombie-hit sound will only play after the player interacts with the page (click/keypress). The current gameplay requires clicks/typing to progress, so this is satisfied naturally; verify no silent-load warning.
- **Asset 404 after deploy**: If relative asset paths break when served under a subpath (e.g., `https://owner.github.io/death-note/`), the Emscripten preload-file mechanism must ensure assets are bundled into the virtual filesystem, not fetched by URL.
- **Large WASM bundle / slow first load**: On slow connections the initial download may exceed the 10-second acceptance target. Document the expected bundle size range and add a simple loading indicator in the HTML shell.
- **Keyboard input swallowed by the page**: The canvas must capture keyboard focus so typing is routed to the game, not scrolled to the page.
- **Hot-reload during local dev**: Serving WASM with the wrong MIME type (`application/wasm`) causes instant-fail in some browsers. Document the required static-server configuration.
- **Deploy rollback**: If a bad build lands on `main`, the owner needs a documented way to redeploy a previous commit (tag-based trigger or manual `workflow_dispatch` on an older ref).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The build system MUST produce a browser-runnable WebAssembly artifact (at minimum: an `index.html`, a `.wasm` file, Emscripten JavaScript glue, and the game assets) via a single documented build command.
- **FR-002**: The resulting WASM build MUST reproduce the current gameplay exactly in a modern desktop browser: window/canvas size, zombie spawn cadence, typing input (printable ASCII 32–125, 9-char buffer, backspace), name-match kill with audio, game-over at canvas bottom, and Enter-to-restart.
- **FR-003**: The build system MUST continue to support the existing native build (`zig build`, `zig build run`, `zig build test`) without regression on the platforms currently supported.
- **FR-004**: The WASM build MUST bundle all required runtime assets (`assets/z_spritesheet.png`, `assets/zombie-hit.wav`, any fonts/images the code actually loads) so that the deployed bundle has no missing-asset failures when served from a subpath.
- **FR-005**: The repository MUST include a CI workflow that builds the WASM bundle and publishes it to the chosen primary free host on pushes to `main` and on manual dispatch.
- **FR-006**: The repository MUST include the CI workflow prerequisites (Emscripten SDK installation or caching, Zig toolchain setup) so the workflow runs on a clean GitHub-hosted runner without manual setup.
- **FR-007**: The published URL MUST be HTTPS (the default for GitHub Pages, Cloudflare Pages, and Firebase Hosting — no mixed-content concerns).
- **FR-008**: The ticket spec folder (`specs/DEATHN-1-build-and-deploy/`) MUST contain a primary deployment guide (`deployment-guide.md`) targeting the chosen free host, with step-by-step instructions covering prerequisites, local build, local verification, CI configuration, first-time publish, and rollback.
- **FR-009**: The ticket spec folder MUST contain at least two alternative-host guides (`deployment-cloudflare-pages.md`, `deployment-gcp-firebase.md`) with equivalent step-by-step instructions, explicitly addressing the user's interest in a GCP option.
- **FR-010**: All deployment guides MUST call out the free-tier limits of the host in question (bandwidth, build minutes, site count, custom-domain rules) and the exact conditions under which the tier could start charging, so the owner cannot be surprised by a bill.
- **FR-011**: The WASM build MUST NOT add any network call, analytics beacon, telemetry, or remote asset fetch that is not already present in the native build. (Security boundary per the constitution: the game has no network surface; the browser port MUST preserve that property. Only the host's own CDN serves the files.)
- **FR-012**: The WASM output HTML shell MUST display a loading indicator while the `.wasm` binary downloads and initializes, and MUST surface a clear error message if WebGL is unavailable.
- **FR-013**: The deploy workflow MUST leave the previously deployed version live if a build or deploy step fails.
- **FR-014**: Dependency pinning MUST be preserved: the raylib commit + content hash in `build.zig.zon` stays as-is, and the Emscripten SDK version is pinned in both the local instructions and the CI workflow.
- **FR-015**: The feature MUST NOT require a paid tier of any provider. If any step would require payment (e.g., GCP egress beyond free quota), the guide MUST mark that step with an explicit warning and a free-tier alternative.

### Key Entities *(include if feature involves data)*

- **WASM Build Artifact**: The output directory produced by the WASM build step. Contains the compiled `.wasm`, the Emscripten JS glue, the HTML shell, and the preloaded asset bundle. Lifecycle: produced by the WASM build step, consumed by the static host.
- **Deploy Workflow**: The CI configuration (GitHub Actions) that chains "checkout → install toolchains → build WASM → upload artifact → publish". Triggered by pushes to `main` and manual dispatch.
- **Deployment Guide (per host)**: A markdown document in `specs/DEATHN-1-build-and-deploy/` describing prerequisites, one-time setup, recurring deploys, rollback, and free-tier caveats for a specific free host.

### Internal Processes *(feature involves a CI/CD workflow)*

- **Web Build & Publish Workflow**: The GitHub Actions pipeline that builds the WASM bundle and deploys it to the configured free host.
  - **Input**: The current git ref of the repo (on push-to-`main` or `workflow_dispatch`).
  - **Phases**:
    1. Checkout repository at the triggering ref.
    2. Install and activate the pinned Zig toolchain.
    3. Install and activate the pinned Emscripten SDK (with caching keyed on the SDK version to keep runs fast).
    4. Invoke the documented WASM build command; fail fast on any build error.
    5. Verify the expected files exist in the build output (`index.html`, `*.wasm`, `*.js`, asset bundle or preload file).
    6. Upload the build output as the Pages artifact (or, for alternative hosts, invoke the provider's deploy CLI with repository-stored credentials).
    7. Publish the artifact to the live URL.
  - **Output**: An updated public URL serving the newly built game; a workflow run log retained by GitHub Actions; the prior version remains live if any step fails before the publish step completes.
  - **Error behavior**: Any failure aborts the pipeline, preserves the previously deployed version, and surfaces the failing step in the Actions UI. The workflow is idempotent — re-running on the same ref produces byte-identical output (modulo Emscripten's embedded build metadata) and republishing it is safe.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A new visitor with a current-stable desktop browser can reach the public URL and be playing the game (typing a name, seeing a zombie disappear) within **30 seconds on a typical home broadband connection**, including all asset downloads.
- **SC-002**: A developer who follows the primary deployment guide end-to-end on a clean machine can produce and serve the WASM build locally **within 30 minutes** (including toolchain install) and publish to the public URL **within 60 minutes total**.
- **SC-003**: Gameplay parity: **100% of the acceptance scenarios listed for User Story 1** pass on both Chrome and Firefox (current stable) on desktop.
- **SC-004**: The existing native build path (`zig build`, `zig build run`, `zig build test`) continues to succeed with **zero new warnings or errors** on the platforms currently supported.
- **SC-005**: The deploy workflow completes a full push-to-live cycle in **≤ 10 minutes** on a standard GitHub-hosted runner after the first run (subsequent runs benefit from the Emscripten SDK cache).
- **SC-006**: Hosting cost is **$0.00 per month** at the targeted usage levels for the game (hobby traffic, single site, single custom domain or default `*.github.io` URL). Each deployment guide explicitly states the free-tier limits and the break-points where cost would be incurred.
- **SC-007**: The ticket spec folder contains **at least three deployment guides** (primary + two alternatives) covering GitHub Pages, Cloudflare Pages, and GCP Firebase Hosting, each independently completable by a reader without cross-referencing the others.
- **SC-008**: The WASM bundle makes **zero outbound network requests** beyond the host CDN serving the bundle itself, verifiable by inspecting the browser's network panel on a fresh page load.

## Assumptions

- The repository is (or will be made) public on GitHub so GitHub Pages + GitHub Actions minutes are free. If this is not the case, the Cloudflare Pages guide becomes the primary path at review time.
- The owner is willing to install the Emscripten SDK locally (or delegate the build to CI) — there is no raylib WASM path that avoids Emscripten today.
- The target audience is desktop browsers (Chrome/Firefox/Safari current stable). Mobile support is out of scope for this ticket because the current game uses mouse-based text-box focus and physical keyboard input; adapting input for touch would be a separate feature.
- "A free server" means no billing surface, not "unlimited forever" — each guide will state the provider's free-tier quotas honestly.
- The existing `build.zig` may be extended. The constitution permits agent edits to build files as long as the pinned raylib dependency hash, the `defer` cleanup pattern, and the no-network-in-gameplay rule are preserved.
- The game's frame pacing (`SetTargetFPS(60)`) translates acceptably under Emscripten's main-loop model; if not, the plan phase will document a concrete switch to the Emscripten main-loop idiom without changing gameplay behavior.

## Out of Scope

- Mobile / touch input adaptation.
- High-score persistence, leaderboards, any server-side component.
- A custom domain purchase or DNS configuration (the default provider-supplied URL is sufficient for this ticket; custom-domain steps are noted in the guides but flagged optional).
- Performance tuning beyond getting the game to run at 60 FPS on a typical desktop browser.
- Internationalization of the HTML shell.
- Analytics, error reporting, or telemetry (explicitly excluded — see FR-011).
