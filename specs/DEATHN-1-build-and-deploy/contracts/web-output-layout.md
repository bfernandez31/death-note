# Contract: Web Output Layout

**Feature**: DEATHN-1 — Build and Deploy (WASM)
**Interface kind**: Filesystem contract (what `zig-out/web/` must look like)

Static hosts (GitHub Pages, Cloudflare Pages, Firebase Hosting) all publish a directory root verbatim. This contract fixes the directory shape so the deployment guides can treat the three hosts symmetrically.

---

## Directory layout (exactly)

```
zig-out/web/
├── index.html          # Emscripten shell (from src/web/shell.html)
├── index.js            # Emscripten runtime glue
├── index.wasm          # Compiled game + raylib (wasm32-emscripten)
├── index.data          # Preloaded Emscripten VFS (assets/*)
├── index.data.js       # Preload loader shim (present on Emscripten ≥ 3.1)
└── assets/             # Source assets copied verbatim (for debugging, not used by the running game)
    ├── z_spritesheet.png
    ├── zombie-hit.wav
    └── …               # (every file currently in the repo's top-level assets/ folder)
```

**Rules**:

- **L1**: The root of `zig-out/web/` is the directory that ships to the host. The host serves that directory as `/` (or as `/<repo>/` on GitHub Pages).
- **L2**: Every `<script>` and `<link>` tag in `index.html` uses **relative** paths (`./index.js`, `./index.data.js`, etc.), never absolute (`/index.js`). This is what makes the bundle subpath-safe.
- **L3**: No file in `zig-out/web/` references a remote URL. Verified by CI grep (data-model V2).
- **L4**: The `assets/` copy is **not** the runtime asset source — Emscripten's VFS (packed into `index.data`) is. The copy exists so that, if a deploy misbehaves, `https://<host>/<repo>/assets/zombie-hit.wav` returns the file for diagnosis instead of 404.

---

## MIME-type contract

Static hosts must serve:

| Extension | Content-Type |
|---|---|
| `.html` | `text/html; charset=utf-8` |
| `.js` | `application/javascript` (or `text/javascript`) |
| `.wasm` | `application/wasm` (critical — Chrome/Firefox refuse to instantiate otherwise) |
| `.data` | `application/octet-stream` (any binary type works; the loader uses `fetch` + `ArrayBuffer`) |
| `.png`, `.wav`, `.ttf` | standard image/audio/font types |

- GitHub Pages, Cloudflare Pages, and Firebase Hosting **all** serve `.wasm` correctly out of the box. The deployment guides note this as a troubleshooting item only for custom / misconfigured servers.

---

## Caching and cache-busting

- Static hosts set `Cache-Control` headers by default; GitHub Pages uses `max-age=600`, Cloudflare Pages uses its edge cache with short TTLs for HTML and longer for static assets.
- Emscripten's default output embeds a hash of the compiled code into the JS runtime's data-package loader, so `index.data` cache misses are naturally invalidated when the content changes — no manual cache-busting query strings needed.
- The shell `index.html` must include `<meta http-equiv="Cache-Control" content="no-cache">` so the **shell** refetches on navigation; otherwise a stale shell can keep loading a stale `.wasm` reference. (Applied in `src/web/shell.html`.)

---

## What MUST NOT appear in `zig-out/web/`

- Any source file (`.zig`, `.c`, `.h`).
- Any debug mapping file (`.wasm.map`) in release builds. In Debug builds a map file is acceptable but the deployment workflow builds in `ReleaseSmall`, so no map is emitted.
- Any `.DS_Store`, `Thumbs.db`, editor temp file.
- Any file larger than **25 MB** (GitHub's per-file artifact ceiling under the free tier). Empirically, the game bundle is well under this, but the workflow prints per-file sizes to make regressions visible.
