const std = @import("std");
const builtin = @import("builtin");
const raylib = @import("raylib.zig").c;

const is_web = builtin.target.os.tag == .emscripten;

pub const TypingPack = enum(u8) {
    click = 0,
    typewriter = 1,
    hitmarker = 2,
};

pub const ErrorPack = enum(u8) {
    damage = 0,
    square = 1,
    missed_punch = 2,
};

pub const SoundConfig = struct {
    keystrokes_enabled: bool = true,
    errors_enabled: bool = true,
    kills_enabled: bool = true,
    power_ups_enabled: bool = true,
    music_enabled: bool = true,

    typing_pack: TypingPack = .typewriter,
    error_pack: ErrorPack = .damage,

    typing_volume: u8 = 14,
    effects_volume: u8 = 16,
    music_volume: u8 = 10,
};

pub const DISK_SIZE: usize = 10;

fn clampVolume(v: u8) u8 {
    return if (v > 20) 20 else v;
}

fn toTypingPack(ord: u8) TypingPack {
    return switch (ord) {
        0 => .click,
        1 => .typewriter,
        2 => .hitmarker,
        else => .typewriter,
    };
}

fn toErrorPack(ord: u8) ErrorPack {
    return switch (ord) {
        0 => .damage,
        1 => .square,
        2 => .missed_punch,
        else => .damage,
    };
}

pub fn load() SoundConfig {
    if (comptime is_web) {
        return loadWeb();
    }
    return loadNative() catch SoundConfig{};
}

pub fn save(cfg: SoundConfig) void {
    if (comptime is_web) {
        saveWeb(cfg);
        return;
    }
    saveNative(cfg) catch {};
}

fn loadNative() !SoundConfig {
    const fp = std.c.fopen("soundconfig.dat", "rb") orelse return error.FileNotFound;
    defer _ = std.c.fclose(fp);
    var buf: [DISK_SIZE]u8 = undefined;
    const n = std.c.fread(&buf, 1, DISK_SIZE, fp);
    if (n != DISK_SIZE) return error.InvalidSize;

    const tp_ord = buf[5];
    const ep_ord = buf[6];

    return SoundConfig{
        .keystrokes_enabled = buf[0] != 0,
        .errors_enabled = buf[1] != 0,
        .kills_enabled = buf[2] != 0,
        .power_ups_enabled = buf[3] != 0,
        .music_enabled = buf[4] != 0,
        .typing_pack = toTypingPack(tp_ord),
        .error_pack = toErrorPack(ep_ord),
        .typing_volume = clampVolume(buf[7]),
        .effects_volume = clampVolume(buf[8]),
        .music_volume = clampVolume(buf[9]),
    };
}

fn saveNative(cfg: SoundConfig) !void {
    // Write to a temp file and rename into place so an interrupted write (crash, disk full)
    // cannot leave a truncated 0-byte soundconfig.dat that would reset all settings on next load.
    var buf: [DISK_SIZE]u8 = undefined;
    buf[0] = if (cfg.keystrokes_enabled) 1 else 0;
    buf[1] = if (cfg.errors_enabled) 1 else 0;
    buf[2] = if (cfg.kills_enabled) 1 else 0;
    buf[3] = if (cfg.power_ups_enabled) 1 else 0;
    buf[4] = if (cfg.music_enabled) 1 else 0;
    buf[5] = @intFromEnum(cfg.typing_pack);
    buf[6] = @intFromEnum(cfg.error_pack);
    buf[7] = cfg.typing_volume;
    buf[8] = cfg.effects_volume;
    buf[9] = cfg.music_volume;

    const tmp_path = "soundconfig.dat.tmp";
    const final_path = "soundconfig.dat";
    {
        const fp = std.c.fopen(tmp_path, "wb") orelse return error.AccessDenied;
        defer _ = std.c.fclose(fp);
        const written = std.c.fwrite(&buf, 1, DISK_SIZE, fp);
        if (written != DISK_SIZE) return error.InputOutput;
    }
    if (std.c.rename(tmp_path, final_path) != 0) return error.InputOutput;
}

fn webEntryExists() bool {
    const js: [*:0]const u8 = "(function(){try{var s=localStorage.getItem('death-note.soundconfig');if(!s)return '0';var d=JSON.parse(s);return (d&&typeof d==='object')?'1':'0';}catch(e){return '0'}})()";
    const cstr = raylib.emscripten_run_script_string(js) orelse return false;
    const span = std.mem.span(cstr);
    return span.len > 0 and span[0] == '1';
}

fn readWebField(field: []const u8) u64 {
    var buf: [384]u8 = undefined;
    const js = std.fmt.bufPrintZ(
        &buf,
        "(function(){{try{{var d=JSON.parse(localStorage.getItem('death-note.soundconfig'));return d&&typeof d.{s}==='number'&&isFinite(d.{s})?String(Math.max(0,Math.floor(d.{s}))):'0'}}catch(e){{return '0'}}}})()",
        .{ field, field, field },
    ) catch return 0;
    const cstr = raylib.emscripten_run_script_string(js.ptr) orelse return 0;
    return std.fmt.parseInt(u64, std.mem.span(cstr), 10) catch 0;
}

fn loadWeb() SoundConfig {
    // No saved entry → return SoundConfig{} defaults instead of letting every absent field
    // collapse to 0, which would silently disable all sound and zero every volume on first launch.
    if (!webEntryExists()) return SoundConfig{};

    const ks = readWebField("keystrokes");
    const er = readWebField("errors");
    const kl = readWebField("kills");
    const pu = readWebField("powerups");
    const mu = readWebField("music");
    const tp = readWebField("typingPack");
    const ep = readWebField("errorPack");
    const tv = readWebField("typingVol");
    const ev = readWebField("effectsVol");
    const mv = readWebField("musicVol");

    const tp_u8: u8 = if (tp > 255) 255 else @intCast(tp);
    const ep_u8: u8 = if (ep > 255) 255 else @intCast(ep);

    return SoundConfig{
        .keystrokes_enabled = ks != 0,
        .errors_enabled = er != 0,
        .kills_enabled = kl != 0,
        .power_ups_enabled = pu != 0,
        .music_enabled = mu != 0,
        .typing_pack = toTypingPack(tp_u8),
        .error_pack = toErrorPack(ep_u8),
        .typing_volume = clampVolume(if (tv > 255) 255 else @intCast(tv)),
        .effects_volume = clampVolume(if (ev > 255) 255 else @intCast(ev)),
        .music_volume = clampVolume(if (mv > 255) 255 else @intCast(mv)),
    };
}

fn saveWeb(cfg: SoundConfig) void {
    var js_buf: [384]u8 = undefined;
    const js = std.fmt.bufPrintZ(
        &js_buf,
        "localStorage.setItem('death-note.soundconfig',JSON.stringify({{keystrokes:{d},errors:{d},kills:{d},powerups:{d},music:{d},typingPack:{d},errorPack:{d},typingVol:{d},effectsVol:{d},musicVol:{d}}}));",
        .{
            @as(u8, if (cfg.keystrokes_enabled) 1 else 0),
            @as(u8, if (cfg.errors_enabled) 1 else 0),
            @as(u8, if (cfg.kills_enabled) 1 else 0),
            @as(u8, if (cfg.power_ups_enabled) 1 else 0),
            @as(u8, if (cfg.music_enabled) 1 else 0),
            @intFromEnum(cfg.typing_pack),
            @intFromEnum(cfg.error_pack),
            cfg.typing_volume,
            cfg.effects_volume,
            cfg.music_volume,
        },
    ) catch return;
    raylib.emscripten_run_script(js.ptr);
}

// --- Tests ---

test "DISK_SIZE equals 10" {
    try std.testing.expectEqual(@as(usize, 10), DISK_SIZE);
}

test "default SoundConfig values match FR-018" {
    const cfg = SoundConfig{};
    try std.testing.expect(cfg.keystrokes_enabled);
    try std.testing.expect(cfg.errors_enabled);
    try std.testing.expect(cfg.kills_enabled);
    try std.testing.expect(cfg.power_ups_enabled);
    try std.testing.expect(cfg.music_enabled);
    try std.testing.expect(cfg.typing_pack == .typewriter);
    try std.testing.expect(cfg.error_pack == .damage);
    try std.testing.expectEqual(@as(u8, 14), cfg.typing_volume);
    try std.testing.expectEqual(@as(u8, 16), cfg.effects_volume);
    try std.testing.expectEqual(@as(u8, 10), cfg.music_volume);
}

test "TypingPack has 3 variants" {
    const fields = @typeInfo(TypingPack).@"enum".fields;
    try std.testing.expectEqual(@as(usize, 3), fields.len);
}

test "ErrorPack has 3 variants" {
    const fields = @typeInfo(ErrorPack).@"enum".fields;
    try std.testing.expectEqual(@as(usize, 3), fields.len);
}

test "volume clamping: value 25 clamps to 20" {
    try std.testing.expectEqual(@as(u8, 20), clampVolume(25));
}

test "volume clamping: value 255 clamps to 20" {
    try std.testing.expectEqual(@as(u8, 20), clampVolume(255));
}

test "volume clamping: value 20 stays 20" {
    try std.testing.expectEqual(@as(u8, 20), clampVolume(20));
}

test "volume clamping: value 0 stays 0" {
    try std.testing.expectEqual(@as(u8, 0), clampVolume(0));
}

test "invalid enum ordinal falls back to default" {
    try std.testing.expect(toTypingPack(5) == .typewriter);
    try std.testing.expect(toTypingPack(255) == .typewriter);
    try std.testing.expect(toErrorPack(5) == .damage);
    try std.testing.expect(toErrorPack(255) == .damage);
}

test "load/save function signatures stay wired" {
    try std.testing.expect(@typeInfo(@TypeOf(loadWeb)).@"fn".return_type == SoundConfig);
    try std.testing.expect(@typeInfo(@TypeOf(saveWeb)).@"fn".params.len == 1);
    try std.testing.expect(@typeInfo(@TypeOf(load)).@"fn".return_type == SoundConfig);
    try std.testing.expect(@typeInfo(@TypeOf(save)).@"fn".params.len == 1);
}
