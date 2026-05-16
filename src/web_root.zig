// Root source file for the wasm32-emscripten build.
//
// std/start.zig has a comptime block gated by `@hasDecl(root, "main")` that
// dispatches on cpu_arch and hits `@compileError("unsupported arch")` for
// wasm32-emscripten. Keeping `main` only inside src/main.zig (imported here,
// not at the root) makes that check return false and the offending branch is
// skipped entirely. emcc still finds the C `main` symbol via @export below.

const std = @import("std");
const main_module = @import("main.zig");

// Override Zig 0.16's default panic handler. The default chain
// (defaultPanic → debug_io → Io.Threaded) evaluates posix decls (IOV_MAX,
// getrandom) that don't exist in 0.16's wasm32-emscripten posix bindings, so
// the build fails before linking. `no_panic` just @trap()s on each panic path,
// which is fine in a browser — a panic surfaces as a wasm RuntimeError visible
// in the dev console; we don't need formatted output.
pub const panic = std.debug.no_panic;

// Signature matches `int main(int argc, char **argv)` — emcc's JS runtime calls
// main with both args and asserts the arity. A 0-arg main triggers the runtime
// error: "native function `main` called with 2 args but expects 0".
fn entryPoint(argc: c_int, argv: [*c][*c]u8) callconv(.c) c_int {
    _ = argc;
    _ = argv;
    main_module.main() catch return 1;
    return 0;
}

comptime {
    @export(&entryPoint, .{ .name = "main" });
}
