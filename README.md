# death-note
Typing game zig/raylib

## Web / WASM build

Build the game for the browser with one command (requires Emscripten SDK 3.1.64 on PATH):

```sh
zig build web -Doptimize=ReleaseSmall
python3 -m http.server 8000 --directory zig-out/web
```

For full setup and deployment instructions see [specs/DEATHN-1-build-and-deploy/deployment-guide.md](specs/DEATHN-1-build-and-deploy/deployment-guide.md).
