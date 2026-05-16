const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_optimize = b.option(
        std.builtin.OptimizeMode,
        "raylib-optimize",
        "Prioritize performance, safety, or binary size (-O flag), defaults to value of optimize option",
    ) orelse optimize;

    const strip = b.option(
        bool,
        "strip",
        "Strip debug info to reduce binary size, defaults to false",
    ) orelse false;

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = raylib_optimize,
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .strip = strip,
    });
    exe_mod.linkLibrary(raylib_dep.artifact("raylib"));

    const exe = b.addExecutable(.{
        .name = "death-note",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);

    // Web step: build for wasm32-emscripten and emit zig-out/web/
    // Requires Emscripten SDK 3.1.64 on PATH (emsdk install + activate).
    // -sASYNCIFY=1 is a viable fallback if needed (inflates .wasm ~30-50%).
    {
        const web_step = b.step("web", "Build WebAssembly bundle for browser deployment");

        const web_target = b.resolveTargetQuery(.{
            .cpu_arch = .wasm32,
            .os_tag = .emscripten,
        });

        // Compile the game module as a static library for wasm32-emscripten.
        // We link raylib separately (via its own Makefile) so we don't pull in
        // native raylib artifacts; the build.zig.zon pin stays untouched (FR-014).
        const web_mod = b.createModule(.{
            .root_source_file = b.path("src/web_root.zig"),
            .target = web_target,
            .optimize = optimize,
            .strip = strip,
            // single_threaded avoids pulling in std.Io.Threaded, which evaluates
            // posix.system.getrandom / IOV_MAX at comptime and those decls don't
            // exist in Zig 0.16's emscripten posix bindings. The game is single-
            // threaded anyway — emscripten_set_main_loop drives one frame at a time.
            .single_threaded = true,
            // link_libc lets the game use std.heap.c_allocator (malloc/free); on
            // wasm32-emscripten std.heap.page_allocator's mmap path is a no-op
            // and silently fails every Zombie allocation. emcc provides libc at
            // link time, but Zig needs the dependency declared at compile time.
            .link_libc = true,
        });
        // Raylib headers are needed for @cImport in src/raylib.zig
        web_mod.addIncludePath(raylib_dep.path("src"));

        // Emscripten libc headers (math.h, stdint.h, …) for the @cImport chain.
        // EMSDK is exported by `source $EMSDK/emsdk_env.sh`; CI sets it via
        // mymindstorm/setup-emsdk. If missing here, skip the include and let the
        // emcc_check step below surface the actionable error at run time —
        // panicking now would also break native `zig build` / `zig build test`,
        // which traverse this build graph even though they don't compile the lib.
        if (b.graph.environ_map.get("EMSDK")) |emsdk_path| {
            const emsdk_sysroot_include = b.pathJoin(&.{ emsdk_path, "upstream", "emscripten", "cache", "sysroot", "include" });
            web_mod.addSystemIncludePath(.{ .cwd_relative = emsdk_sysroot_include });
        }

        const web_lib = b.addLibrary(.{
            .name = "game",
            .linkage = .static,
            .root_module = web_mod,
        });

        // Build raylib for PLATFORM_WEB via its own Makefile.
        // Produces libraylib.a in the raylib dependency's src/ directory.
        const raylib_make = b.addSystemCommand(&.{"make"});
        raylib_make.addArg("-C");
        raylib_make.addDirectoryArg(raylib_dep.path("src"));
        raylib_make.addArgs(&.{ "PLATFORM=PLATFORM_WEB", "GRAPHICS=GRAPHICS_API_OPENGL_ES2", "-j4" });

        // Ensure the output directory exists before emcc runs
        const mkdir_out = b.addSystemCommand(&.{ "mkdir", "-p", "zig-out/web" });

        // Pre-flight: surface the contracted error message before invoking emcc so a
        // missing Emscripten SDK fails with actionable wording instead of a raw OS-level
        // "command not found" (specs/DEATHN-1-build-and-deploy/contracts/build-commands.md).
        // Runs at step-execution time (not graph-construction) so native builds aren't gated on emsdk.
        const emcc_check = b.addSystemCommand(&.{
            "sh",
            "-c",
            "command -v emcc >/dev/null 2>&1 || { echo 'Emscripten SDK not found — install and activate `emsdk` ≥ 3.1.64' >&2; exit 1; }",
        });

        // Link game + libraylib.a with emcc to produce the browser bundle
        const emcc_link = b.addSystemCommand(&.{"emcc"});
        emcc_link.addArtifactArg(web_lib);
        emcc_link.addFileArg(raylib_dep.path("src/libraylib.web.a"));
        emcc_link.addArgs(&.{ "--shell-file", "src/web/shell.html" });
        emcc_link.addArgs(&.{ "--preload-file", "assets/" });
        emcc_link.addArgs(&.{ "-sUSE_GLFW=3", "-sFULL_ES2=1", "-sASYNCIFY=0" });
        // Default emscripten stack is 64 KB. Raylib's DrawTexturePro / DrawText
        // path consumes deep stack frames in the per-frame callback. 1 MB
        // matches the value used by raylib's official PLATFORM_WEB samples.
        emcc_link.addArgs(&.{"-sSTACK_SIZE=1048576"});
        emcc_link.addArgs(&.{ "-o", "zig-out/web/index.html" });
        emcc_link.step.dependOn(&emcc_check.step);
        emcc_link.step.dependOn(&raylib_make.step);
        emcc_link.step.dependOn(&mkdir_out.step);

        // Copy assets alongside the bundle (belt-and-suspenders, contracts/web-output-layout.md §L4)
        const cp_assets = b.addSystemCommand(&.{ "cp", "-r", "assets/", "zig-out/web/assets" });
        cp_assets.step.dependOn(&emcc_link.step);

        web_step.dependOn(&cp_assets.step);
    }
}
