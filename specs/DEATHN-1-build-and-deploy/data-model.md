# Phase 1 Data Model: Build and Deploy the Game (WASM + Free Hosting)

**Feature Branch**: `DEATHN-1-build-and-deploy`
**Date**: 2026-04-22

This feature adds **build artifacts and deployment plumbing**, not persistent user data. The "entities" below describe the shapes that flow through the build/deploy pipeline. No database or ORM is introduced. No state is persisted across sessions.

---

## Entity 1: WASM Build Artifact

The output directory produced by `zig build web`. Consumed by static hosts (GitHub Pages, Cloudflare Pages, Firebase Hosting).

**Location**: `zig-out/web/`

**Fields**:

| File | Type | Required | Produced by | Purpose |
|---|---|:---:|---|---|
| `index.html` | HTML | Yes | `emcc --shell-file src/web/shell.html` | Entry document; loads `index.js`, hosts the canvas, shows loading indicator and WebGL-availability error (FR-012) |
| `index.js` | JavaScript | Yes | `emcc` (Emscripten JS glue) | Emscripten runtime: loads the `.wasm`, mounts the VFS, bridges GLFW/OpenAL/OpenGL to the browser |
| `index.wasm` | WebAssembly | Yes | `emcc` linking Zig-compiled game object + `libraylib.a` | The game binary |
| `index.data` | Binary | Yes | `--preload-file assets/` | Preloaded VFS containing `assets/z_spritesheet.png`, `assets/zombie-hit.wav`, and any other asset the game loads |
| `index.data.js` | JavaScript | Conditional | `--preload-file` (Emscripten ≥ 3.1) | Loader shim for `index.data`; present when Emscripten emits split loaders |
| `assets/` | Directory (copy) | Yes (belt-and-suspenders) | `build.zig` copy step | Raw asset files alongside the bundle. Not used by Emscripten at runtime (VFS wins), but useful for debugging 404s |

**Validation rules**:

- **V1**: `index.html`, `index.js`, `index.wasm`, `index.data` **MUST** all exist after `zig build web`. The workflow verifies this with a shell check (`test -f …`) and fails the build otherwise — enforces the spec's "Phase 2 internal-process step 5: Verify the expected files exist".
- **V2**: `index.html` **MUST NOT** reference any URL outside the same directory (no CDN scripts, fonts, or analytics). Enforced by a grep in CI (`grep -E "src=\"https?://" zig-out/web/index.html` must return empty) — covers FR-011 / SC-008.
- **V3**: `index.wasm` size **SHOULD** be under 8 MB uncompressed in release builds. Not a hard fail, but the workflow prints the size so regressions are visible (supports SC-001's 30-second first-load target over typical broadband).
- **V4**: All paths inside the bundle **MUST** be relative (no leading `/`) so the bundle works under any subpath (GitHub Pages `/<repo>/`, Cloudflare Pages root, Firebase root).

**Lifecycle**:

1. **Built** by `zig build web` on a developer machine or CI runner.
2. **Uploaded** by `actions/upload-pages-artifact@v3` (GitHub Pages path) or the provider's CLI (alternative paths).
3. **Published** to the public URL by `actions/deploy-pages@v4` (or the provider's CLI).
4. **Replaced** on the next successful deploy. The prior version remains live until the new deploy's publish step succeeds (FR-013).

**Not persisted**: Artifacts in `zig-out/` are ignored by Git (standard Zig `.gitignore`). Only the **deployed** copy on the host is authoritative.

---

## Entity 2: Deploy Workflow Run

A single execution of `.github/workflows/deploy-web.yml`. Ephemeral — lives in GitHub Actions logs.

**Fields**:

| Field | Type | Source | Purpose |
|---|---|---|---|
| `trigger` | enum {`push`, `workflow_dispatch`} | GitHub event | Determines whether this run was automatic (push-to-main) or manual (owner hit "Run workflow") |
| `ref` | string (git SHA) | GitHub event | Which commit is being built + deployed |
| `emsdk_version` | string | Repo-pinned (`3.1.64`) | Passed into `mymindstorm/setup-emsdk@v14` |
| `zig_version` | string | Repo-pinned (read from workflow env var) | Which Zig toolchain `goto-bus-stop/setup-zig` installs |
| `artifact_digest` | string (sha256) | `upload-pages-artifact` output | Uniquely identifies the built bundle; recorded in the workflow summary |
| `deploy_url` | string (URL) | `deploy-pages` output | The `https://<owner>.github.io/<repo>/` URL the bundle is live at |
| `duration_s` | number | GitHub Actions | Measured against SC-005 (`≤ 600 seconds`) |
| `outcome` | enum {`success`, `failure`, `cancelled`} | GitHub Actions | If `failure`, previously deployed version stays live (FR-013) |

**State transitions** (workflow-level):

```
queued → in_progress → { success | failure | cancelled }
                              │
                              └── on success: public URL now serves this artifact
                              └── on failure: public URL unchanged, error surfaced in Actions tab
```

**Validation rules**:

- **V5**: The `build` job **MUST** fail if any of the Entity-1 validations (V1, V2) fail.
- **V6**: The `deploy` job **MUST NOT** run if the `build` job fails (expressed as `needs: build` in YAML).
- **V7**: The workflow **MUST** be idempotent — re-running on the same `ref` produces a functionally identical artifact (modulo Emscripten build timestamps). Spec §Internal Processes: "re-running on the same ref produces byte-identical output (modulo Emscripten's embedded build metadata) and republishing it is safe."

---

## Entity 3: Deployment Guide

A markdown document under `specs/DEATHN-1-build-and-deploy/` describing how to reach a live URL for a specific host. Static content (written once, edited when a provider's free tier changes).

**Instances** (one per host):

- `deployment-guide.md` — GitHub Pages (primary)
- `deployment-cloudflare-pages.md` — Cloudflare Pages (alternative)
- `deployment-gcp-firebase.md` — GCP Firebase Hosting (alternative)

**Fields** (consistent structure across all three):

| Section | Required | Purpose |
|---|:---:|---|
| Prerequisites | Yes | Accounts, CLI tools, quotas to request |
| Local build | Yes | One-liner `zig build web` reminder + expected output |
| Local verification | Yes | How to serve `zig-out/web/` on `http://localhost:<port>/` (e.g., `python3 -m http.server`) |
| One-time provider setup | Yes | Account creation, project creation, token/key generation (with exact dashboard paths) |
| CI configuration | Yes | Which GitHub Actions secrets to set and exactly where (Settings → Secrets → Actions) |
| First-time publish | Yes | Step-by-step from "push this commit" to "open the URL" |
| Rollback | Yes | How to republish a prior commit (FR-013 follow-up) |
| Free-tier limits | Yes | Verbatim quota numbers + dashboard URL + break-points (FR-010, FR-015) |
| Troubleshooting | Yes | Known failure modes: MIME type (`application/wasm`), CORS, cache-busting, preload-file 404 |

**Validation rules**:

- **V8**: Each guide **MUST** be independently completable — a reader who starts at a guide's top and executes every step through "First-time publish" reaches a live URL without consulting the others (SC-007).
- **V9**: The "Free-tier limits" section **MUST** include a date stamp ("as of 2026-04-…") because quotas drift; any future reviewer should double-check against the provider's current docs.
- **V10**: The "Local build" and "Local verification" sections **MUST** be identical across the three guides (the WASM artifact is host-agnostic). Only the publish section diverges.

---

## Relationships

```
                 produced from         uploaded by
┌──────────┐   ┌─────────────┐   ┌────────────────────┐   ┌────────────┐
│ Source   │──▶│ zig build   │──▶│ WASM Build         │──▶│ Public URL │
│ tree     │   │ web         │   │ Artifact           │   │ (host CDN) │
│ (src/,   │   │ (Entity —   │   │ (Entity 1)         │   │            │
│ assets/) │   │ Entity 2    │   │                    │   │            │
│          │   │  step 4)    │   │                    │   │            │
└──────────┘   └─────────────┘   └────────────────────┘   └────────────┘
                     ▲                    ▲
                     │                    │
                     │                    │ described by
                     │                    │
                     │                    └───────┐
                     │                            │
               ┌────────────────────┐   ┌────────────────────┐
               │ Deploy Workflow    │   │ Deployment Guide   │
               │ Run (Entity 2)     │   │ (Entity 3,         │
               │                    │   │  one per host)     │
               └────────────────────┘   └────────────────────┘
```

- Entity 1 is produced once per workflow run (Entity 2) and uploaded to the host.
- Entity 3 is the *human* contract describing how to produce Entity 1 and operate Entity 2 for each host.

---

## No-Database Note

The game itself introduces **no new persistent data** (see constitution §Security Practices/1: "no credentials, API calls, or persistence"). All "entities" above are build- or workflow-time shapes, not runtime user data. There is no DB schema, no migration, no ORM, and none is needed.
