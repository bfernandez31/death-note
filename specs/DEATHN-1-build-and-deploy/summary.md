# Implementation Summary: Build and Deploy the Game (WASM + Free Hosting)

**Branch**: `DEATHN-1-build-and-deploy` | **Date**: 2026-05-16
**Spec**: [spec.md](spec.md)

## Changes Summary

Added a `zig build web` step that compiles the death-note game for `wasm32-emscripten`, builds raylib for PLATFORM_WEB via its Makefile, and links with emcc into `zig-out/web/`. Includes a GitHub Actions workflow that publishes to GitHub Pages on push to `main`. Three pure-logic unit tests added (T003–T005). Native build is unchanged. Three deployment guides added (GitHub Pages, Cloudflare Pages, GCP Firebase).

## Key Decisions

Used Zig 0.16.0 `b.addLibrary` (not deprecated `addStaticLibrary`). `frame()` extracted from `main()` and invoked via `emscripten_set_main_loop_arg` behind `comptime if` to avoid analyzing the dead branch on native. `zig build test` gates the CI deploy so the regression net must pass before publish. `ASYNCIFY=0` default with `ASYNCIFY=1` documented as fallback.

## Files Modified

- `src/main.zig` — FrameContext, frame(), frame_c_callback, emscripten branch, 3 unit tests
- `src/raylib.zig` — conditional emscripten.h include
- `build.zig` — web step (addLibrary, make, emcc, cp assets)
- `src/web/shell.html` [NEW], `.github/workflows/deploy-web.yml` [NEW]
- `specs/.../deployment-guide.md` [NEW], `deployment-cloudflare-pages.md` [NEW], `deployment-gcp-firebase.md` [NEW]
- `README.md`, `CLAUDE.md` — web build note appended

## ⚠️ Manual Requirements

1. Enable GitHub Pages: Settings → Pages → Source: GitHub Actions (T018). 2. T015/T016 (zig build web + browser play): verified by first CI run on merge to main. 3. T020–T022 (live URL checks): after first deploy. 4. T026/T027: CI failure-mode and dispatch verification after merge.
