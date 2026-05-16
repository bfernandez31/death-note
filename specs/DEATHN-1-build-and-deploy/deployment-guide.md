# Deployment Guide: GitHub Pages (Primary)

**Feature**: DEATHN-1 — Build and Deploy (WASM)
**Host**: GitHub Pages (free tier, public repos)
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
- The repository must be **public** on GitHub. Private repos do not receive free GitHub Pages hosting (see Free-tier limits).

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

1. Navigate to your repository on GitHub.
2. Go to **Settings → Pages**.
3. Under **Build and deployment**, set **Source** to **GitHub Actions**.
4. Click **Save**.
5. Confirm the repository is **public** (Settings → General → Danger Zone → visibility).

No extra environment configuration is needed — the `github-pages` environment is created automatically on the first successful deploy.

---

## CI Configuration

The workflow `.github/workflows/deploy-web.yml` (already committed) triggers automatically on every push to `main` and can be triggered manually via **Actions → Deploy Web → Run workflow**.

No repository secrets are required for the GitHub Pages path. Authentication uses OIDC (`id-token: write` permission), which GitHub manages transparently.

---

## First-Time Publish

1. Ensure the one-time provider setup above is complete.
2. Push any commit to `main` (or trigger the workflow manually from the Actions tab).
3. Watch the **Actions** tab — the `build` job compiles and verifies the bundle; the `deploy` job publishes it.
4. The live URL appears in the `deploy` job's environment link:
   `https://<owner>.github.io/<repo>/`
5. Open the URL in Chrome and Firefox to confirm the game loads.

---

## Rollback

To republish a previous version:

1. In the **Actions** tab, select **Deploy Web**.
2. Click **Run workflow**.
3. In the **Use workflow from** dropdown, select the branch/tag/commit you want to redeploy.
4. Click **Run workflow**.

Alternatively, revert the commit and push to `main` — the next workflow run will deploy the older code.

---

## Free-Tier Limits (as of 2026-04)

| Limit | Value |
|---|---|
| Bandwidth per month | 100 GB (soft limit; GitHub may throttle or contact you) |
| Storage per site | 1 GB |
| Repo size (affects build artifact) | 5 GB recommended max |
| Custom domain | Free (bring your own domain) |
| Price | $0.00 for public repos |

GitHub does not automatically charge you when you exceed the soft bandwidth limit — they may reach out first. Check current quotas at: https://docs.github.com/en/pages/getting-started-with-github-pages/about-github-pages#usage-limits

---

## Troubleshooting

**MIME type error (`application/wasm`)**: GitHub Pages serves `.wasm` files with the correct MIME type. If you see errors, you are likely not using GitHub Pages — check the host.

**404 for assets under subpath**: All assets are bundled in `index.data` via Emscripten's virtual filesystem. Asset 404s indicate the `index.data` file itself failed to load — check the Network panel for the root cause.

**Audio autoplay blocked**: The game canvas requires a user gesture before audio plays. Clicking the canvas (or typing the first character) satisfies the browser's autoplay policy.

**First load slow**: The `.wasm` file is fetched fresh on first load. GitHub Pages sets `Cache-Control: max-age=600`; subsequent loads within 10 minutes are cached. If first-load exceeds 30 s, check the `index.wasm` size — target is under 8 MB (`ReleaseSmall`).
