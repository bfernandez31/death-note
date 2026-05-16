# Deployment Guide: GCP Firebase Hosting (Alternative)

**Feature**: DEATHN-1 — Build and Deploy (WASM)
**Host**: Firebase Hosting (Google Cloud, Spark free plan)
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
- A Google account with a free GCP project created at https://console.firebase.google.com
- Firebase CLI:
  ```sh
  npm install -g firebase-tools
  firebase login
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

1. Create a Firebase project at https://console.firebase.google.com → **Add project**.
2. In the repository root, initialize Firebase Hosting:
   ```sh
   firebase init hosting
   ```
   Answer the prompts:
   - **Which Firebase project?** → select the project you just created
   - **What do you want to use as your public directory?** → `zig-out/web`
   - **Configure as a single-page app?** → No
   - **Set up automatic builds with GitHub?** → No (CI handles this manually)
3. Firebase creates `firebase.json` and `.firebaserc` — commit both to the repository.
4. Ensure `firebase.json` does **not** rewrite all routes (the game is a static bundle, not a SPA):
   ```json
   {
     "hosting": {
       "public": "zig-out/web",
       "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
     }
   }
   ```

---

## CI Configuration

For automated deploys on every push to `main`, add the following workflow file. Do NOT create a second `deploy-web.yml` — add a separate file (e.g., `.github/workflows/deploy-firebase.yml`) alongside the existing GitHub Pages workflow, or replace it:

```yaml
name: Deploy to Firebase Hosting

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
      - uses: FirebaseExtended/action-hosting-deploy@v0
        with:
          repoToken: ${{ secrets.GITHUB_TOKEN }}
          firebaseServiceAccount: ${{ secrets.FIREBASE_SERVICE_ACCOUNT }}
          channelId: live
          projectId: <your-firebase-project-id>
```

### Required GitHub Actions secrets

Go to **Settings → Secrets and variables → Actions → New repository secret** and add:

| Secret name | Value |
|---|---|
| `FIREBASE_SERVICE_ACCOUNT` | JSON service account key from Google Cloud Console (IAM → Service Accounts → Create key → JSON). The `FirebaseExtended/action-hosting-deploy` action also supports generating this automatically via `firebase init hosting` with the GitHub integration wizard. |

Secrets are never committed to the repository and never ship inside the WASM bundle.

---

## First-Time Publish

1. Ensure the one-time provider setup above is complete.
2. Add the `FIREBASE_SERVICE_ACCOUNT` GitHub Actions secret.
3. Push any commit to `main` or trigger the workflow manually.
4. The live URL is `https://<project-id>.web.app` (and also `https://<project-id>.firebaseapp.com`).
5. Open the URL in Chrome and Firefox to confirm the game loads.

---

## Rollback

Firebase Hosting keeps a history of previous deploys. To roll back:

```sh
firebase hosting:releases:list
firebase hosting:clone <release-version> live
```

Or in the Firebase console: **Hosting → Release history → select a version → Rollback**.

---

## Free-Tier Limits (Spark Plan — as of 2026-04)

> **Important**: The Spark (free) plan has hard monthly quotas. Exceeding them does **not** automatically upgrade you to Blaze (paid) — Firebase will instead return 429 errors until the next month. However, enabling the Blaze plan (pay-as-you-go) removes these limits and introduces per-GB pricing. For a hobby game, you are very unlikely to hit Spark limits unless the game goes viral.

| Limit | Spark Value | Blaze pricing (if exceeded) |
|---|---|---|
| Storage | 10 GB | $0.026/GB |
| **Egress (bandwidth) per month** | **10 GB** | **$0.15/GB** |
| Custom domains | 10 | Included |
| SSL certificates | Free | Free |
| Price | $0.00 | Pay-as-you-go |

**The most likely limit to hit is the 10 GB/month egress cap.** A single `.wasm` + `.data` bundle is roughly 4–8 MB. At 10 GB/month, that allows approximately 1,250–2,500 full game loads before the cap triggers.

If you expect more traffic, either:
- Switch to Cloudflare Pages (unlimited bandwidth on the free tier), or
- Upgrade to the Blaze plan and monitor usage at: https://console.firebase.google.com → Hosting → Usage

Check current quotas at: https://firebase.google.com/pricing

---

## Troubleshooting

**MIME type error (`application/wasm`)**: Firebase Hosting serves `.wasm` with the correct MIME type automatically.

**404 for assets under subpath**: All assets are bundled in `index.data` via Emscripten's virtual filesystem. Asset 404s indicate the `index.data` file failed to load — check the Network panel.

**Audio autoplay blocked**: Click the canvas before typing to satisfy the browser's autoplay policy.

**Service account permission denied**: Ensure the service account has the `Firebase Hosting Admin` role (Firebase console → Project settings → Service accounts, or Google Cloud IAM).

**Bandwidth quota exceeded (Spark plan)**: Firebase returns HTTP 429 until the end of the billing month. To recover immediately, upgrade to the Blaze plan in the Firebase console.
