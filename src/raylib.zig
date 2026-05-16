const builtin = @import("builtin");

pub const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
    @cInclude("stdlib.h"); // for atexit() — used by the emscripten cleanup hook in src/main.zig
    if (builtin.target.os.tag == .emscripten) {
        @cInclude("emscripten/emscripten.h");
    }
});
