const builtin = @import("builtin");

pub const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
    if (builtin.target.os.tag == .emscripten) {
        @cInclude("emscripten/emscripten.h");
    }
});
