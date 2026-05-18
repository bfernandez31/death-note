# Workflows & Automation

## Table of Contents

- [Automation Overview](#automation-overview)
- [Workflow Catalog](#workflow-catalog)
  - [install (default)](#install-default)
  - [run](#run)
  - [test](#test)
- [Workflow Diagrams](#workflow-diagrams)
  - [Build Pipeline](#build-pipeline)
  - [Run Pipeline](#run-pipeline)
  - [Test Pipeline](#test-pipeline)
- [Scripts & Commands](#scripts--commands)
- [Infrastructure](#infrastructure)
- [Deployment Pipeline](#deployment-pipeline)
- [Environment Configuration](#environment-configuration)

---

## Automation Overview

**GitHub Actions is configured as the CI/CD platform for this repository.**

| Location | Expected artifact | Present? |
|---|---|---|
| `.github/workflows/` | GitHub Actions workflow YAML files | Yes — `deploy-web.yml` builds the WASM bundle and publishes it to GitHub Pages |
| `.gitlab-ci.yml` | GitLab CI pipeline definition | No |
| `Jenkinsfile` | Jenkins declarative or scripted pipeline | No |
| `.circleci/` | CircleCI pipeline configuration | No |
| `Makefile` | GNU Make-based build automation | No |
| `Dockerfile` / `docker-compose.yml` | Container build and orchestration | No |
| `bin/` or `scripts/` | Shell script automation directories | No |

The primary build automation layer is the **Zig build graph** declared in `build.zig`. This file defines four named steps (`install` as default, `run`, `test`, and `web`), wires up the raylib dependency fetch and compilation, and exposes build option flags. A GitHub Actions workflow (`.github/workflows/deploy-web.yml`) provides CI build gating and automated deployment to GitHub Pages on every push to `main` and on manual dispatch.

Additionally, the `.ai-board/config.yml` harness file defines four command aliases used by the ai-board tooling:

| Alias | Command |
|---|---|
| `install` | `zig build` |
| `test` | `zig build test` |
| `type_check` | `zig build --summary all` |
| `lint` | `zig fmt --check .` |

These aliases are conventions for the ai-board agent harness and do not represent separate automation steps or scripts — they map directly to `zig` CLI invocations.

---

## Workflow Catalog

### install (default)

- **Trigger**: `zig build` (no step name specified; `install` is the default step)
- **Purpose**: Compile the `death-note` game executable and install it to `zig-out/bin/death-note`. Raylib is fetched from the pinned URL in `build.zig.zon` (if not already cached), compiled as a static library, then linked into the final binary.
- **Key inputs**:
  - `src/main.zig` (root source file, declared as `b.path("src/main.zig")`)
  - `src/raylib.zig`, `src/zombie_names.zig` (imported transitively)
  - raylib dependency fetched from `https://github.com/raysan5/raylib/archive/52f2a10db610d0e9f619fd7c521db08a876547d0.tar.gz`, hash-verified against `122078ad3e79fb83b45b04bd30fb63aaf936c6774db60095bc6987d325cbe5743373`
- **Key outputs**: `zig-out/bin/death-note` (native executable for the host platform)
- **Build options honored**:
  - `-Doptimize=Debug|ReleaseSafe|ReleaseFast|ReleaseSmall` (defaults to `Debug`)
  - `-Draylib-optimize=…` (overrides optimization mode for raylib only; defaults to value of `-Doptimize`)
  - `-Dstrip=true|false` (strip debug symbols from executable; defaults to `false`)
- **Source**: `build.zig` lines 18–47 (`b.addExecutable`, `b.installArtifact`)

### run

- **Trigger**: `zig build run` or `zig build run -- <arg1> <arg2> …`
- **Purpose**: Build the `death-note` executable (same as the install step) and then immediately execute it. The run command depends on the install step (`run_cmd.step.dependOn(b.getInstallStep())`), so the binary is always rebuilt and installed to `zig-out/bin/` before execution. The game launches a native window via raylib.
- **CLI argument forwarding**: Arguments after `--` are captured via `b.args` and appended to the run command (`run_cmd.addArgs(args)`). The current `src/main.zig` does not parse or consume any CLI arguments, so forwarded args are silently ignored by the game at runtime.
- **Working directory**: The run command executes from the install directory (`zig-out/`). Assets are loaded by relative path (`"assets/zombie-hit.wav"`, `"assets/z_spritesheet.png"`, etc.) and are **not** copied to the install directory during the build. This means asset loads will fail unless the game is launched from the repo root. See [Infrastructure](#infrastructure) for details.
- **Source**: `build.zig` lines 52–70 (`b.addRunArtifact`, `b.step("run", …)`)

### test

- **Trigger**: `zig build test`
- **Purpose**: Compile a test binary rooted at `src/main.zig` (using `b.addTest`) and execute it via `b.addRunArtifact`. The test runner discovers all `test "…" { … }` blocks reachable from `src/main.zig` (including transitively imported modules). Around 98 unit tests are currently defined across `src/main.zig` (67), `src/name_lists.zig` (12), `src/sound_config.zig` (10), `src/highscore.zig` (6), and `src/zombie_types.zig` (3), covering name-match equality, input-buffer bounds, wave config, boss mechanics, scoring, popup pool, WPM/accuracy metrics, sound config persistence, volume clamping, pack enum cycling, and more.
- **Key inputs**: `src/main.zig` (root source file for test artifact)
- **Key outputs**: Pass/fail report printed to stdout; non-zero exit code on failure
- **Source**: `build.zig` lines 72–84 (`b.addTest`, `b.addRunArtifact`, `b.step("test", …)`)

### web

- **Trigger**: `zig build web` (requires Emscripten SDK 3.1.64 active on `PATH` via `source ~/emsdk/emsdk_env.sh`)
- **Purpose**: Compile the game as a WebAssembly binary for browser deployment. The step compiles `src/main.zig` for `wasm32-emscripten`, builds raylib for `PLATFORM_WEB` (OpenGL ES 2.0), and links everything with `emcc` into a static web bundle at `zig-out/web/`. All assets in `assets/` are bundled into the Emscripten virtual filesystem via `--preload-file`. The HTML shell at `src/web/shell.html` wraps the output, providing a loading indicator and WebGL availability guard. The `emcc` link line passes `-sINITIAL_MEMORY=33554432` (32 MB) and `-sALLOW_MEMORY_GROWTH=1` so the runtime can host the ~10 MB audio payload added by DEATHN-26 without aborting on heap-grow during startup, plus `-sSTACK_SIZE=1048576` (1 MB) to match raylib's PLATFORM_WEB samples and absorb the deep stack frames `DrawTexturePro` / `DrawText` push from the per-frame callback.
- **Key inputs**:
  - `src/main.zig` (compiled for `wasm32-emscripten`; branches at `comptime` on `builtin.target.os.tag == .emscripten`)
  - `src/raylib.zig` (conditionally includes `emscripten/emscripten.h` when target is Emscripten)
  - `src/web/shell.html` (Emscripten `--shell-file`)
  - `assets/` directory (bundled via `--preload-file`)
  - raylib dependency (built from the same pinned source via `PLATFORM=PLATFORM_WEB`)
  - Emscripten SDK (`emcc` must be on `PATH`)
- **Key outputs**: `zig-out/web/{index.html, index.js, index.wasm, index.data}` — a self-contained static bundle serveable by any HTTP server
- **Build options honored**:
  - `-Doptimize=ReleaseSmall` (recommended for deployment; reduces WASM bundle size)
  - `-Dstrip=true` (strips debug symbols)
- **Precondition failure**: If `emcc` is not found on `PATH`, the step fails immediately with a clear error message before any compilation begins.
- **Source**: `build.zig` web step

---

## Workflow Diagrams

### Build Pipeline

```mermaid
graph LR
    A[zig build] --> B[resolve build.zig.zon]
    B --> C{raylib in cache?}
    C -- no --> D[fetch raylib tarball]
    D --> E[compile raylib static lib]
    C -- yes --> E
    E --> F[compile src/main.zig]
    F --> G[link death-note executable]
    G --> H[install to zig-out/bin/death-note]
```

### Run Pipeline

```mermaid
graph LR
    A[zig build run] --> B[install pipeline]
    B --> C[zig-out/bin/death-note installed]
    C --> D[addRunArtifact run_cmd]
    D --> E{b.args provided?}
    E -- yes --> F[addArgs to run_cmd]
    E -- no --> G[execute from install dir]
    F --> G
    G --> H[game window opens]
```

### Test Pipeline

```mermaid
graph LR
    A[zig build test] --> B[addTest root=src/main.zig]
    B --> C[compile test binary]
    C --> D[addRunArtifact run_exe_unit_tests]
    D --> E[execute test binary]
    E --> F[run ~98 test blocks]
    F --> G[pass/fail output]
```

### Deploy Pipeline

```mermaid
graph LR
    A[push to main / workflow_dispatch] --> B[checkout repo]
    B --> C[setup Zig toolchain]
    C --> D[setup Emscripten SDK 3.1.64]
    D --> E[zig build test]
    E --> F[zig build web -Doptimize=ReleaseSmall]
    F --> G{build succeeded?}
    G -- yes --> H[upload zig-out/web as Pages artifact]
    H --> I[deploy to GitHub Pages]
    G -- no --> J[fail job / preserve live version]
```

---

## Scripts & Commands

No shell scripts exist in this repository. All developer commands are `zig` CLI invocations.

| Command | Purpose | Notes |
|---|---|---|
| `zig build` | Build (install) the `death-note` executable | Output: `zig-out/bin/death-note`; default Debug mode |
| `zig build run` | Build then execute the game | Runs from install dir; asset path caveat applies |
| `zig build run -- <args>` | Build then execute with CLI args forwarded | Args passed to process but not consumed by `main.zig` |
| `zig build test` | Run unit tests declared in `src/main.zig` | ~98 test blocks across main.zig, name_lists.zig, sound_config.zig, highscore.zig, zombie_types.zig — name match, input bounds, wave config, boss mechanics, scoring, popup pool, WPM/accuracy metrics, sound config persistence/clamping, pack enum cycling |
| `zig build web` | Build the WASM + HTML bundle | Requires Emscripten SDK 3.1.64 on `PATH`; output: `zig-out/web/` |
| `zig build web -Doptimize=ReleaseSmall` | Web release build (recommended for deploy) | Smaller WASM binary; suitable for GitHub Pages |
| `python3 -m http.server 8000 --directory zig-out/web` | Serve the web bundle locally | Open `http://localhost:8000` to test the WASM build |
| `zig build --summary all` | Build with full summary output (type-check) | Useful for verifying compilation without running |
| `zig fmt --check .` | Check formatting of all `.zig` files | Non-zero exit if any file would be reformatted |
| `zig build -Doptimize=ReleaseFast` | Release build optimized for speed | Applies to both `death-note` and raylib |
| `zig build -Draylib-optimize=ReleaseFast` | Optimize raylib only, keep default for game code | Useful for faster iteration with optimized lib |
| `zig build -Dstrip=true` | Strip debug symbols from the executable | Reduces binary size; combine with `ReleaseFast` for distribution |
| `zig build --help` | List all available build steps and options | Includes `install`, `run`, `test`, `web`, all `-D` flags |

---

## Infrastructure

**No infrastructure automation, containers, or cloud configuration exists.**

Specifically:

- **No Docker**: no `Dockerfile`, no `docker-compose.yml`, no `.dockerignore`. The game is not containerized and cannot be meaningfully containerized (it requires a native windowing system via raylib).
- **No container orchestration**: no Kubernetes manifests, no Helm charts, no Compose files.
- **No cloud configuration**: no Terraform, no Pulumi, no AWS/GCP/Azure config files.
- **No remote build services**: no Nix flakes, no Bazel remote cache config, no CI runners.

The game runs as a **single native binary** on the developer's local machine. It requires:

1. The compiled `death-note` executable (`zig-out/bin/death-note` after `zig build`)
2. The `assets/` directory accessible at the relative path `assets/` from the **current working directory at launch time**

The assets loaded at runtime are:
- `assets/zombie-hit.wav` (sound effect)
- `assets/z_spritesheet.png` (zombie sprite sheet)
- `assets/JetBrainsMonoNerdFont-Thin.ttf` (font, based on assets directory contents)
- Additional PNG assets present in `assets/` (`alagard.png`, `page.png`, `plume.png`, `spritesheet.png`)

**Known limitation**: `zig build run` executes the binary from the install directory (`zig-out/`), not the repo root. The `assets/` directory is not copied to `zig-out/` during the build step. Therefore, asset loads via `raylib.LoadSound("assets/…")` and `raylib.LoadTexture("assets/…")` will fail to find the files when the game is launched via `zig build run` unless the working directory is correctly set. The safe approach is to run the binary directly from the repo root: `./zig-out/bin/death-note`. This limitation is noted in `CLAUDE.md`.

---

## Deployment Pipeline

**GitHub Actions automates web deployment to GitHub Pages.** The workflow file is `.github/workflows/deploy-web.yml`.

- **Triggers**: push to `main`; manual `workflow_dispatch` from the Actions UI.
- **Jobs**: `build` (compiles the WASM bundle and uploads it as a Pages artifact) then `deploy` (publishes the artifact to the live `https://<owner>.github.io/<repo>/` URL).
- **Toolchain pinning**: the workflow pins both the Zig toolchain version (env var `ZIG_VERSION`) and the Emscripten SDK version (`3.1.64`). The emsdk install step is cached by SDK version to keep subsequent runs fast.
- **Failure isolation**: if the `build` job fails, the `deploy` job is skipped and the previously deployed version remains live. The failing step is visible in the Actions UI with full logs.
- **CI gate**: `zig build test` runs in the `build` job before `zig build web`, so a test regression blocks deployment.

```mermaid
sequenceDiagram
    participant GitHub as GitHub (push / dispatch)
    participant Build as build job
    participant Pages as GitHub Pages
    participant Player as Player browser

    GitHub->>Build: trigger on push to main
    Build->>Build: checkout + setup Zig + setup emsdk 3.1.64
    Build->>Build: zig build test (gate)
    Build->>Build: zig build web -Doptimize=ReleaseSmall
    Build->>Pages: upload zig-out/web as artifact
    Pages-->>Build: artifact accepted
    Build->>Pages: deploy-pages action publishes
    Pages-->>Player: https://<owner>.github.io/<repo>/ updated
```

**Native distribution** (no change from before): the native binary continues to be distributable manually — build with `zig build -Doptimize=ReleaseFast`, package `zig-out/bin/death-note` together with the `assets/` directory, and the recipient runs the binary from the same directory as `assets/`.

---

## Environment Configuration

**No environment variables are read or required by this project's code.**

- `src/main.zig` does not call `std.process.getEnvMap`, `std.os.getenv`, or any equivalent. No environment variable is read at runtime.
- `build.zig` does not read any environment variables directly. It uses only the standard `std.Build` API (target options, optimize options, custom `-D` flags).
- There are no secrets, API keys, tokens, or credentials involved anywhere in the build or runtime.
- There is no `.env` file, no `dotenv` loading, and no secret management integration.

The Zig toolchain itself respects certain conventional environment variables that are not declared by this project but may be present on the developer's machine:

| Variable | Toolchain use | Declared by this project? |
|---|---|---|
| `ZIG_GLOBAL_CACHE_DIR` | Override Zig's global package cache location | No |
| `ZIG_LOCAL_CACHE_DIR` | Override the per-project cache directory | No |
| `HOME` | Used by Zig to locate default cache under `~/.cache/zig` | No |
| `PATH` | Must include the `zig` binary for all commands to work | No |

These are Zig toolchain conventions, not declarations or requirements of this project. No configuration is needed beyond having a working `zig` installation on `PATH`.
