# Workflow Spec: `deploy-web.yml`

**Feature**: DEATHN-1 — Build and Deploy (WASM)
**Artifact location**: `.github/workflows/deploy-web.yml`
**Type**: GitHub Actions workflow (internal process per spec §Internal Processes)

This document defines the contract of the deploy workflow. The YAML file implements it; if they disagree, the spec wins and the YAML is corrected.

---

## Triggers

| Trigger | Purpose |
|---|---|
| `push` on `main` | Automatic publish on merge (spec User Story 3) |
| `workflow_dispatch` | Manual publish: hotfix, retry, or deploying a non-main branch (spec User Story 3, acceptance scenario 3) |

**Not triggered by**:

- Pull requests (avoids publishing half-reviewed work).
- Tags (custom tag-based deploys are out of scope; reviewer can adopt later).
- Scheduled runs.

---

## Permissions (job-level, minimum viable)

```yaml
permissions:
  contents: read        # checkout
  pages: write          # deploy-pages publishes
  id-token: write       # OIDC for deploy-pages (no PAT stored)
```

No secrets are defined for the GitHub Pages path. Alternative guides (Cloudflare, Firebase) document the additional secrets those hosts need — those live in **encrypted Actions secrets**, never in the repo.

---

## Concurrency

```yaml
concurrency:
  group: "pages"
  cancel-in-progress: false
```

- `group: pages` is the canonical group name for Pages deploys (recommended by GitHub docs) — prevents two deploys from racing on the same site.
- `cancel-in-progress: false` lets the currently-deploying run finish; a new push queues behind it. This preserves FR-013: if the newer build fails, the previously deployed version (from the prior run) stays live.

---

## Jobs

### Job 1: `build`

**Runs on**: `ubuntu-latest`

**Inputs**: None (uses the triggering ref).

**Steps** (functional — YAML is the implementation):

1. `actions/checkout@v4` — checks out the repository at the triggering ref.
2. `mymindstorm/setup-emsdk@v14` with `version: 3.1.64`, `actions-cache-folder: emsdk-cache` — installs and activates the pinned Emscripten SDK; cache key is the version so warm runs restore in seconds (research §1.8).
3. `goto-bus-stop/setup-zig@v2` with the pinned Zig version (read from a workflow env var — same version used locally, TBD at implement time based on what `zig build` on `main` expects).
4. Run `zig build web -Doptimize=ReleaseSmall` — builds the WASM bundle into `zig-out/web/` (contracts/build-commands.md §Command 4).
5. **Verification step**: shell script asserts `zig-out/web/index.html`, `index.js`, `index.wasm`, `index.data` all exist (data-model V1). Fails the job with a clear message if any are missing.
6. **No-remote-fetch assertion**: `grep -E "https?://" zig-out/web/index.html` must return empty (data-model V2, FR-011, SC-008). Note: this is `index.html` only; `index.js` is Emscripten's generated runtime and is allowed to contain URL strings it does not actually fetch.
7. **Size log**: prints `du -h zig-out/web/*` to the job summary so bundle-size regressions are visible (data-model V3).
8. `actions/upload-pages-artifact@v3` with `path: zig-out/web` — uploads the bundle as the Pages artifact.

**Failure behavior**: Any failed step aborts the job; the `deploy` job does not run (`needs: build`); the previously deployed version stays live (FR-013).

### Job 2: `deploy`

**Needs**: `build`
**Runs on**: `ubuntu-latest`
**Environment**: `github-pages` with `url: ${{ steps.deployment.outputs.page_url }}`

**Steps**:

1. `actions/deploy-pages@v4` (id: `deployment`) — publishes the artifact uploaded by `build`. The action's output `page_url` is surfaced in the workflow summary and job log so the owner can click through.

**Failure behavior**: If publish fails (rare — usually Pages API transient), the previously deployed version stays live. Re-run via `workflow_dispatch`.

---

## Reporting / callback contract

- **Where the run appears**: GitHub Actions tab, workflow name "Deploy Web".
- **What the run reports**:
  - Per-step success/failure with timestamps.
  - Bundle file sizes (step 7).
  - The live URL (`page_url` output) surfaced in the `deploy` job's environment link and in the run summary.
  - On failure: the failing step's full stderr is in the log; the job summary calls out which phase (toolchain install, build, verification, upload, publish) failed.
- **No external callback**: The workflow does not POST to any external system. Spec §Internal Processes: "the failing step is visible in the Actions UI" — that is the entire reporting surface.

---

## Idempotence

- Re-running the workflow on the same commit produces functionally identical output and re-publishes safely (spec §Internal Processes).
- Emscripten embeds a build timestamp into `index.js`, so bytes differ; gameplay does not.

---

## Secrets & security

- **GitHub Pages path** (default): **zero repository secrets**. OIDC handles auth via `id-token: write`.
- **Cloudflare Pages path** (alternative): requires `CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` as encrypted Actions secrets. Documented in `deployment-cloudflare-pages.md`.
- **Firebase Hosting path** (alternative): requires `FIREBASE_SERVICE_ACCOUNT` (JSON, base64-optional) as an encrypted Actions secret. Documented in `deployment-gcp-firebase.md`.

Constitution §Security Practices/1 + spec FR-011: no game-runtime network capability is added. Secrets listed here are **build/deploy-time only** — they never ship inside the WASM bundle.

---

## What this workflow does NOT do

- No caching of `zig-cache/` (Zig builds are fast enough; caching introduces staleness risk).
- No release tagging or changelog generation.
- No PR preview deploys (viable future extension; out of scope for this ticket).
- No automatic rollback on HTTP smoke-test failure (rollback is human-driven via `workflow_dispatch` on an older ref — documented in each guide's "Rollback" section).
