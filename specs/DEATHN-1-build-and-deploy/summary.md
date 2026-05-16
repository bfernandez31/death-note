# Implementation Summary: Build and Deploy the Game (WASM + Free Hosting)

**Branch**: `DEATHN-1-build-and-deploy` | **Date**: 2026-05-16
**Spec**: [spec.md](spec.md)

## Changes Summary

Added a `zig build web` step that compiles the death-note game for `wasm32-emscripten`, builds raylib for PLATFORM_WEB via its Makefile, and links with emcc into `zig-out/web/`. Includes a GitHub Actions workflow that publishes to GitHub Pages on push to `main`. Native build is unchanged. Three deployment guides added for GitHub Pages, Cloudflare Pages, and GCP Firebase Hosting.

## Key Decisions

Used Zig 0.16.0 `b.addLibrary` (not `addStaticLibrary`). `frame()` extracted from `main()` and invoked via `emscripten_set_main_loop_arg` behind `comptime if` to avoid analyzing the dead branch on native. `zig build test` gates the CI deploy so the regression net (3 pure-logic tests) must pass before publish.

## Files Modified

- `src/main.zig` — FrameContext, frame(), frame_c_callback, emscripten branch, 3 tests
- `src/raylib.zig` — conditional emscripten.h include
- `build.zig` — web step (addLibrary, make, emcc, cp assets)
- `src/web/shell.html` [NEW], `.github/workflows/deploy-web.yml` [NEW]
- `specs/.../deployment-guide.md` [NEW], `deployment-cloudflare-pages.md` [NEW], `deployment-gcp-firebase.md` [NEW]
- `README.md`, `CLAUDE.md` — web build note appended

## ⚠️ Manual Requirements

1. Enable GitHub Pages: Settings → Pages → Source: GitHub Actions. 2. T015/T016 (zig build web + browser play): requires Emscripten SDK 3.1.64 — verified by first CI run. 3. T018–T022 (live URL checks): after first deploy. 4. T026/T027: CI failure-mode and dispatch verification.
