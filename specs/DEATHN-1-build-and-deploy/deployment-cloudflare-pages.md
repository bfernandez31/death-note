# Deployment Guide: Cloudflare Pages (Alternative)

**Feature**: DEATHN-1 — Build and Deploy (WASM)
**Host**: Cloudflare Pages (free tier)
**Date**: 2026-04-22

---

## Prerequisites

- Git and Zig 0.16.0 installed on your developer machine
- Emscripten SDK 3.1.64 installed and activated:
  ```sh
  git clone https://github.com/emscripten-core/emsdk.git ~/emsdk
  cd ~/emsdk
  ./emsdk install 3.1.64
  ./emsdk activate 3.1.64
  source ./emsdk_env.sh   # re-run in each shell session
  ```
  Verify with `emcc --version` — should report `3.1.64`.
- A free Cloudflare account at https://dash.cloudflare.com
- Wrangler CLI (optional, for manual deploys):
  ```sh
  npm install -g wrangler
  wrangler login
  ```

---

## Local Build

Run from the repository root with the Emscripten environment active:

```sh
zig build web -Doptimize=ReleaseSmall
```

Expected output: `zig-out/web/` containing `index.html`, `index.js`, `index.wasm`, `index.data`, and `assets/`.

---

## Local Verification

Serve the bundle with any static HTTP server from the repository root:

```sh
python3 -m http.server 8000 --directory zig-out/web
```

Open `http://localhost:8000` in Chrome or Firefox. The canvas loads within a few seconds, zombies spawn, typing their names kills them, audio plays, game-over triggers when one reaches the bottom, and pressing Enter restarts.

---

## One-Time Provider Setup

### Option A: Connect via Cloudflare Dashboard (recommended)

1. Log in to https://dash.cloudflare.com.
2. Go to **Workers & Pages → Create → Pages → Connect to Git**.
3. Select your GitHub repository and authorize Cloudflare.
4. Configure the build:
   - **Framework preset**: None
   - **Build command**: _(leave blank — CI handles the build)_
   - **Build output directory**: `zig-out/web`
5. Click **Save and Deploy**. The first deploy will fail (no build yet) — that is expected.

### Option B: Deploy manually with Wrangler

Skip the dashboard setup and push the bundle directly:

```sh
zig build web -Doptimize=ReleaseSmall
wrangler pages deploy zig-out/web --project-name death-note
```

Wrangler will create the project if it doesn't exist and return a `*.pages.dev` URL.

---

## CI Configuration

For automated deploys on every push to `main`, add the following workflow file. Do NOT create a second `deploy-web.yml` — add a separate file (e.g., `.github/workflows/deploy-cloudflare.yml`) alongside the existing GitHub Pages workflow, or replace it:

```yaml
name: Deploy to Cloudflare Pages

on:
  push:
    branches: [main]
  workflow_dispatch:

env:
  ZIG_VERSION: "0.16.0"

jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: mymindstorm/setup-emsdk@v14
        with:
          version: 3.1.64
          actions-cache-folder: emsdk-cache
      - uses: goto-bus-stop/setup-zig@v2
        with:
          version: ${{ env.ZIG_VERSION }}
      - run: zig build test
      - run: zig build web -Doptimize=ReleaseSmall
      - uses: cloudflare/wrangler-action@v3
        with:
          apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          accountId: ${{ secrets.CLOUDFLARE_ACCOUNT_ID }}
          command: pages deploy zig-out/web --project-name death-note
```

### Required GitHub Actions secrets

Go to **Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret name | Value |
|---|---|
| `CLOUDFLARE_API_TOKEN` | API token from Cloudflare (Workers:Edit scope, or Pages-specific token) |
| `CLOUDFLARE_ACCOUNT_ID` | Found in the Cloudflare dashboard right sidebar |

Secrets are never committed to the repository and never ship inside the WASM bundle.

---

## First-Time Publish

1. Ensure the one-time provider setup above is complete.
2. Add the two GitHub Actions secrets.
3. Push any commit to `main` or trigger the workflow manually.
4. The live URL is `https://death-note.pages.dev` (or a subdomain Cloudflare assigned).
5. Open the URL in Chrome and Firefox to confirm the game loads.

---

## Rollback

To republish a previous version, go to **Workers & Pages → death-note → Deployments** in the Cloudflare dashboard, find the target deployment, click the three-dot menu, and select **Rollback to this deployment**.

Alternatively, trigger the workflow on an older commit via `workflow_dispatch` with the desired ref.

---

## Free-Tier Limits (as of 2026-04)

| Limit | Value |
|---|---|
| Requests per month | Unlimited |
| Bandwidth per month | Unlimited |
| Builds per month | 500 (CI builds) |
| Custom domains | 100 |
| Sites | 1 on the free plan |
| Price | $0.00 |

Cloudflare Pages' free tier has no bandwidth cap, which makes it attractive for games with unpredictable traffic spikes. The 500 builds/month limit is generous for a hobby project.

Check current quotas at: https://developers.cloudflare.com/pages/platform/limits/

---

## Troubleshooting

**MIME type error (`application/wasm`)**: Cloudflare Pages serves `.wasm` with the correct MIME type automatically.

**404 for assets under subpath**: All assets are bundled in `index.data` via Emscripten's virtual filesystem. Asset 404s indicate the `index.data` file failed to load — check the Network panel.

**Audio autoplay blocked**: Click the canvas before typing to satisfy the browser's autoplay policy.

**Wrangler authentication failed**: Run `wrangler login` again or regenerate the API token in the Cloudflare dashboard.
