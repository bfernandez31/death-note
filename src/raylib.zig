const builtin = @import("builtin");

pub const c = @cImport({
    @cInclude("raylib.h");
    @cInclude("raymath.h");
    @cInclude("rlgl.h");
    @cInclude("stdlib.h"); // for atexit() — used by the emscripten cleanup hook in src/main.zig
    @cInclude("stdio.h"); // for fopen/fread/fwrite/fclose — used by high score persistence
    if (builtin.target.os.tag == .emscripten) {
        // emscripten.h declares deprecated functions with 2-arg
        // __attribute__((deprecated("msg","replacement"))) — Zig 0.16's
        // translate-c only accepts 1 arg. Strip __attribute__ for this header
        // only; raylib headers above keep their annotations intact.
        @cDefine("__attribute__(X)", "");
        @cInclude("emscripten/emscripten.h");
    }
});
