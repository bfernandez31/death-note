// High-score persistence with two backends: native binary file (`highscore.dat` via
// std.c.fopen/fwrite/fread) and Emscripten localStorage (JSON via emscripten_run_script).
//
// Split from main.zig per constitution Code Patterns #1: dual-backend persistence is a
// genuinely distinct concern with its own surface. main.zig stays focused on gameplay.

const std = @import("std");
const builtin = @import("builtin");
const raylib = @import("raylib.zig").c;
const zt = @import("zombie_types.zig");
const GameMode = zt.GameMode;

const is_web = builtin.target.os.tag == .emscripten;

pub const FILENAME = "highscore.dat";

pub fn filename(mode: GameMode) [*:0]const u8 {
    return switch (mode) {
        .survival => "highscore.dat",
        .zen => "highscore-zen.dat",
    };
}

pub fn webKey(mode: GameMode) []const u8 {
    return switch (mode) {
        .survival => "death-note.highscore",
        .zen => "death-note.highscore.zen",
    };
}

// Native on-disk format: field-by-field little-endian serialization. Stable 17 bytes
// regardless of in-memory padding. (See data-model.md §3.8 / FR-011 / ARD-2.)
pub const DISK_SIZE: usize = @sizeOf(u64) + @sizeOf(u32) + @sizeOf(u32) + @sizeOf(u8);

pub const Record = struct {
    score: u64 = 0,
    wave: u32 = 0,
    wpm: u32 = 0,
    accuracy: u8 = 0,
};

pub fn load(mode: GameMode) Record {
    if (comptime is_web) {
        return loadWeb(mode);
    }
    return loadNative(mode) catch Record{};
}

pub fn save(mode: GameMode, record: Record) void {
    if (comptime is_web) {
        saveWeb(mode, record);
        return;
    }
    saveNative(mode, record) catch {};
}

fn loadNative(mode: GameMode) !Record {
    const fp = std.c.fopen(filename(mode), "rb") orelse return error.FileNotFound;
    defer _ = std.c.fclose(fp);
    var buf: [DISK_SIZE]u8 = undefined;
    const n = std.c.fread(&buf, 1, DISK_SIZE, fp);
    if (n != DISK_SIZE) return error.InvalidSize;
    return Record{
        .score = std.mem.readInt(u64, buf[0..8], .little),
        .wave = std.mem.readInt(u32, buf[8..12], .little),
        .wpm = std.mem.readInt(u32, buf[12..16], .little),
        .accuracy = buf[16],
    };
}

fn saveNative(mode: GameMode, record: Record) !void {
    const fp = std.c.fopen(filename(mode), "wb") orelse return error.AccessDenied;
    defer _ = std.c.fclose(fp);
    var buf: [DISK_SIZE]u8 = undefined;
    std.mem.writeInt(u64, buf[0..8], record.score, .little);
    std.mem.writeInt(u32, buf[8..12], record.wave, .little);
    std.mem.writeInt(u32, buf[12..16], record.wpm, .little);
    buf[16] = record.accuracy;
    const n = std.c.fwrite(&buf, 1, DISK_SIZE, fp);
    if (n != DISK_SIZE) return error.InputOutput;
}

// Goes through emscripten_run_script_string and parses the result as u64 so scores above
// 2^31-1 survive the round-trip; a raw c_int return would truncate to a negative value
// and clamp to 0.
fn readWebField(mode: GameMode, field: []const u8) u64 {
    const key = webKey(mode);
    var buf: [384]u8 = undefined;
    const js = std.fmt.bufPrintZ(
        &buf,
        "(function(){{try{{var d=JSON.parse(localStorage.getItem('{s}'));return d&&typeof d.{s}==='number'&&isFinite(d.{s})?String(Math.max(0,Math.floor(d.{s}))):'0'}}catch(e){{return '0'}}}})()",
        .{ key, field, field, field },
    ) catch return 0;
    const cstr = raylib.emscripten_run_script_string(js.ptr) orelse return 0;
    var len: usize = 0;
    while (cstr[len] != 0) : (len += 1) {}
    return std.fmt.parseInt(u64, cstr[0..len], 10) catch 0;
}

fn loadWeb(mode: GameMode) Record {
    const wave_v = readWebField(mode, "wave");
    const wpm_v = readWebField(mode, "wpm");
    const acc_v = readWebField(mode, "accuracy");
    return Record{
        .score = readWebField(mode, "score"),
        .wave = if (wave_v > std.math.maxInt(u32)) 0 else @intCast(wave_v),
        .wpm = if (wpm_v > std.math.maxInt(u32)) 0 else @intCast(wpm_v),
        .accuracy = if (acc_v > 100) 0 else @intCast(acc_v),
    };
}

fn saveWeb(mode: GameMode, record: Record) void {
    const key = webKey(mode);
    var js_buf: [384]u8 = undefined;
    const js = std.fmt.bufPrintZ(
        &js_buf,
        "localStorage.setItem('{s}',JSON.stringify({{score:{d},wave:{d},wpm:{d},accuracy:{d}}}));",
        .{ key, record.score, record.wave, record.wpm, record.accuracy },
    ) catch return;
    raylib.emscripten_run_script(js.ptr);
}

test "disk size is stable at 17 bytes" {
    try std.testing.expectEqual(@as(usize, 17), DISK_SIZE);
}

test "web load/save signatures stay wired" {
    try std.testing.expect(@typeInfo(@TypeOf(loadWeb)).@"fn".return_type == Record);
    try std.testing.expect(@typeInfo(@TypeOf(saveWeb)).@"fn".params.len == 2);
}

test "filename survival returns highscore.dat" {
    const f = filename(.survival);
    try std.testing.expectEqual(@as(u8, 'h'), f[0]);
    const expected: [*:0]const u8 = "highscore.dat";
    var len: usize = 0;
    while (f[len] != 0) len += 1;
    var elen: usize = 0;
    while (expected[elen] != 0) elen += 1;
    try std.testing.expectEqual(elen, len);
    try std.testing.expect(std.mem.eql(u8, f[0..len], expected[0..elen]));
}

test "filename zen returns highscore-zen.dat" {
    const f = filename(.zen);
    var len: usize = 0;
    while (f[len] != 0) len += 1;
    const expected: [*:0]const u8 = "highscore-zen.dat";
    var elen: usize = 0;
    while (expected[elen] != 0) elen += 1;
    try std.testing.expect(std.mem.eql(u8, f[0..len], expected[0..elen]));
}

test "webKey survival returns death-note.highscore" {
    const key = webKey(.survival);
    try std.testing.expect(std.mem.eql(u8, key, "death-note.highscore"));
}

test "webKey zen returns death-note.highscore.zen" {
    const key = webKey(.zen);
    try std.testing.expect(std.mem.eql(u8, key, "death-note.highscore.zen"));
}

test "DISK_SIZE unchanged at 17 bytes" {
    try std.testing.expectEqual(@as(usize, 17), DISK_SIZE);
}
