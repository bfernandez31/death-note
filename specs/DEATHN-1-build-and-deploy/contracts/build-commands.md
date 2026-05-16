# Contract: Build Commands (CLI)

**Feature**: DEATHN-1 — Build and Deploy (WASM)
**Interface kind**: CLI (Zig build steps invoked from the repo root)

This contract fixes the command surface the feature exposes. Anything under `zig build …` that is not listed here is untouched by this feature.

---

## Command 1: `zig build` (native — unchanged)

**Invocation**: `zig build`

**Behavior** (pre-existing, preserved by this feature per FR-003, SC-004):

- Targets the host (`native` triple).
- Compiles `src/main.zig` + dependencies into `zig-out/bin/death-note` (or `death-note.exe` on Windows).
- Links `libraylib` built with the same `-Doptimize` mode.

**Guarantee this feature adds**: Exit code, output filename, and emitted warnings are byte-for-byte unchanged versus before the feature. **Zero new warnings or errors** (SC-004). Verified by building both with and without `-Dtarget=wasm32-emscripten` in CI or locally.

---

## Command 2: `zig build run` (native — unchanged)

**Invocation**: `zig build run -- [args…]`

**Behavior**: Same as before — builds (if needed), installs, then runs the native executable from the install directory so assets resolve relative to it.

**Guarantee**: Unchanged.

---

## Command 3: `zig build test` (native — unchanged command, extended test coverage)

**Invocation**: `zig build test`

**Behavior**: Runs all `test "…" { … }` blocks reachable from `src/main.zig` using Zig's built-in test runner.

**What this feature adds**: New pure-logic tests in `src/main.zig` (see research.md §2.4). Raylib-dependent code is **not** tested here (constitution §Testing Standards/3 — "Raylib calls are not unit-tested — verify them manually with `zig build run`").

**Guarantee**: `zig build test` still exits 0 on green, non-zero on any failing test, and takes < 30 seconds on a developer laptop.

---

## Command 4: `zig build web` (new)

**Invocation**: `zig build web`

**Required environment**:

- **Zig toolchain**: same version that builds the native target.
- **Emscripten SDK**: version `3.1.64`, activated (`emsdk activate 3.1.64 && source ./emsdk_env.sh` or equivalent). `emcc`, `em++`, and `EMSDK` env var must be on `PATH` / exported before `zig build web` runs.

**Inputs**: Everything in `src/`, `assets/`, and the raylib dependency pulled by `build.zig.zon`.

**Outputs**: `zig-out/web/` containing the files described in `data-model.md §Entity 1`:

- `index.html`
- `index.js`
- `index.wasm`
- `index.data` (+ `index.data.js` when Emscripten emits split loaders)
- `assets/` (copy of the source `assets/` for debugging)

**Build options this step honors** (passed through from the existing `build.zig`):

| Option | Default | Effect |
|---|---|---|
| `-Doptimize={Debug,ReleaseSafe,ReleaseFast,ReleaseSmall}` | same as native default | Applied to Zig-compiled game code. `ReleaseSmall` recommended for smaller `.wasm`. |
| `-Draylib-optimize=<mode>` | falls through from `-Doptimize` | Applied to raylib's compile (matches existing option). Under the web path, the raylib Makefile is invoked with the equivalent `-Os`/`-O2`/`-O3` flag. |
| `-Dstrip={true,false}` | `false` | Passed to Zig; `emcc` also strips debug names when `true`. |

**Exit codes**:

- `0`: success. Every required output file (V1 in data-model.md) exists.
- non-zero: any sub-step failed (Zig compile, raylib Makefile, `emcc` link, or post-build file-existence check). The stderr pinpoints which sub-step failed.

**Idempotence**: Running `zig build web` twice back-to-back on the same source tree must produce functionally identical output. Emscripten embeds a build timestamp into `index.js`, so byte-equality is **not** guaranteed; functional equality (same game, same asset hashes) **is** (per spec §Internal Processes).

**Preconditions / failure modes**:

- If `emcc` is not on `PATH`, `zig build web` fails fast with a clear message ("Emscripten SDK not found — install and activate `emsdk` ≥ 3.1.64") rather than a cryptic linker error.
- If the target is not `wasm32-emscripten`, the `web` step errors with "The `web` step requires `-Dtarget=wasm32-emscripten` (this is set automatically by `zig build web`; override only if you know what you are doing)."

---

## Command 5: Local serve (documented, not a build step)

**Invocation** (documented in `deployment-guide.md`):

```bash
zig build web
cd zig-out/web
python3 -m http.server 8000
# Open http://localhost:8000 in a browser
```

**Contract**: Any static HTTP server that serves `.wasm` with `Content-Type: application/wasm` works. `python3 -m http.server` ≥ 3.9 does this correctly. For servers that do not, the deployment guide lists workarounds.

**Not owned by this feature**: We do not ship a custom dev server. The guides simply document the one-liner.
