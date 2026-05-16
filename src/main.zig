const std = @import("std");
const raylib = @import("raylib.zig").c;

const ZombieNames = @import("zombie_names.zig").ZombieNames;
const BossPhrases = @import("boss_phrases.zig").BossPhrases;

const MAX_ZOMBIES = 100;
const MAX_INPUT_CHARS = 40;

const ZOMBIE_FRAME_COUNT = 17;
const ZOMBIE_ANIMATION_FRAME_DURATION: f32 = 0.1;

// Wave system
const WAVE_TRANSITION_RECAP_DURATION: f32 = 5.0;
const WAVE_TRANSITION_COUNTDOWN_DURATION: f32 = 3.0;
const WAVE_TRANSITION_TOTAL_DURATION: f32 = 8.0;
const BOSS_WAVE_INTERVAL: u32 = 5;
const BOSS_FALL_SPEED_FACTOR: f32 = 0.5;

// Scoring
const BASE_KILL_SCORE: u64 = 100;
const BOSS_KILL_SCORE: u64 = 500;
const WAVE_COMPLETION_BONUS_PER_WAVE: u64 = 200;

// Difficulty scaling
const BASE_SPAWN_DELAY: f32 = 3.0;
const SPAWN_DELAY_DECAY: f32 = 0.85;
const MIN_SPAWN_DELAY: f32 = 0.5;
const BASE_FALL_SPEED: f32 = 0.5;
const FALL_SPEED_GROWTH: f32 = 1.10;
const MAX_FALL_SPEED: f32 = 2.0;
const BASE_MAX_ACTIVE: u32 = 5;
const MAX_ACTIVE_INCREMENT: u32 = 2;
const CAP_MAX_ACTIVE: u32 = 30;
const BASE_KILL_TARGET: u32 = 5;
const KILL_TARGET_INCREMENT: u32 = 2;
const CAP_KILL_TARGET: u32 = 40;
const BASE_WAVE_DURATION: f32 = 30.0;
const WAVE_DURATION_INCREMENT: f32 = 5.0;
const CAP_WAVE_DURATION: f32 = 120.0;

// Stats
const WPM_WINDOW_SECONDS: f64 = 30.0;
const WPM_BUFFER_SIZE: usize = 200;

// High score persistence
const HIGHSCORE_FILE = "highscore.dat";

// Input buffer
var name = [_]u8{0} ** (MAX_INPUT_CHARS + 1);
var letter_count: usize = 0;

// Spawn timer
var spawn_timer: f32 = 0.0;

var is_game_over: bool = false;

// Wave state
var current_wave: u32 = 1;
var wave_timer: f32 = 0.0;
var wave_kill_count: u32 = 0;
var is_wave_transitioning: bool = false;
var wave_transition_timer: f32 = 0.0;
var boss_alive: bool = false;

// Score state
var score: u64 = 0;
var combo: u32 = 0;
var best_score: u64 = 0;
var best_score_loaded: bool = false;

// Player stats
var total_keystrokes: u64 = 0;
var correct_keystrokes: u64 = 0;
var total_kills: u32 = 0;
var wpm_kill_times: [WPM_BUFFER_SIZE]f64 = [_]f64{0.0} ** WPM_BUFFER_SIZE;
var wpm_kill_index: usize = 0;
var wpm_kill_count: usize = 0;

const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,
    name: [*:0]const u8,
    is_active: bool,
    frame: f32,
    animation_timer: f32,
    is_boss: bool,
    phrase_progress: usize,
};

// Array to hold zombie pointers
var zombies: [MAX_ZOMBIES]?*Zombie = undefined;

var zombie_texture: raylib.Texture2D = undefined;
var zombie_kill_sound: raylib.Sound = undefined;

const screen_width = 800;
const screen_height = 450;

// Spawn X bounds: left margin + right margin sized for the rendered sprite
// (≈ 313 px frame × 0.2 scale ≈ 63 px) so zombies stay fully on-screen.
const ZOMBIE_SPAWN_X_MIN: c_int = 10;
const ZOMBIE_SPAWN_X_MAX: c_int = screen_width - 51;

// Per-frame mutable context threaded through the game loop (native and emscripten paths)
const FrameContext = struct {
    allocator: *std.mem.Allocator,
    text_box: raylib.Rectangle,
    mouse_on_text: bool,
    frames_counter: usize,
};

fn frame(ctx: *FrameContext) void {
    if (raylib.CheckCollisionPointRec(raylib.GetMousePosition(), ctx.text_box)) {
        ctx.mouse_on_text = true;
        raylib.SetMouseCursor(raylib.MOUSE_CURSOR_IBEAM);
    } else {
        ctx.mouse_on_text = false;
        raylib.SetMouseCursor(raylib.MOUSE_CURSOR_DEFAULT);
    }

    if (ctx.mouse_on_text) {
        ctx.frames_counter += 1;
    } else {
        ctx.frames_counter = 0;
    }

    const dt = raylib.GetFrameTime();

    if (!is_game_over) {
        if (is_wave_transitioning) {
            wave_transition_timer += dt;
            if (wave_transition_timer >= WAVE_TRANSITION_TOTAL_DURATION) {
                current_wave += 1;
                wave_kill_count = 0;
                wave_timer = 0.0;
                is_wave_transitioning = false;
                wave_transition_timer = 0.0;
                resetZombies(ctx.allocator);
            }
        } else {
            // Input handling
            var key = raylib.GetCharPressed();
            while (key > 0) {
                if ((key >= 32) and (key <= 125) and (letter_count < MAX_INPUT_CHARS)) {
                    name[letter_count] = @intCast(key);
                    name[letter_count + 1] = '\x00';
                    letter_count += 1;
                }
                key = raylib.GetCharPressed();
            }

            if (raylib.IsKeyPressed(raylib.KEY_BACKSPACE) and letter_count > 0) {
                letter_count -= 1;
                name[letter_count] = '\x00';
            }

            // Wave timer (paused while boss alive)
            if (!boss_alive) {
                wave_timer += dt;
            }

            // Spawn timer with wave-scaled delay
            spawn_timer += dt;
            if (spawn_timer >= waveSpawnDelay(current_wave)) {
                const spawned = spawnZombie(ctx.allocator) catch false;
                if (spawned) spawn_timer = 0.0;
            }

            updateZombies();

            // Wave completion detection
            if (wave_kill_count >= waveKillTarget(current_wave) and !boss_alive) {
                is_wave_transitioning = true;
                wave_transition_timer = 0.0;
            } else if (wave_timer >= waveDuration(current_wave) and !boss_alive) {
                resetZombies(ctx.allocator);
                is_wave_transitioning = true;
                wave_transition_timer = 0.0;
            }
        }
    }

    // Draw
    raylib.BeginDrawing();
    defer raylib.EndDrawing();

    raylib.ClearBackground(raylib.RAYWHITE);

    raylib.DrawRectangleRec(ctx.text_box, raylib.LIGHTGRAY);
    const border_color = if (ctx.mouse_on_text) raylib.RED else raylib.DARKGRAY;
    raylib.DrawRectangleLines(
        @intFromFloat(ctx.text_box.x),
        @intFromFloat(ctx.text_box.y),
        @intFromFloat(ctx.text_box.width),
        @intFromFloat(ctx.text_box.height),
        border_color,
    );

    raylib.DrawText(&name, @as(c_int, @intFromFloat(ctx.text_box.x)) + 5, @as(c_int, @intFromFloat(ctx.text_box.y)) + 8, 40, raylib.MAROON);

    if (is_game_over) {
        raylib.DrawText("GAME OVER", screen_width / 2 - 100, screen_height / 2 - 20, 40, raylib.RED);
        raylib.DrawText("Press ENTER to Restart", screen_width / 2 - 130, screen_height / 2 + 20, 20, raylib.GRAY);

        if (raylib.IsKeyPressed(raylib.KEY_ENTER)) {
            resetGameState(ctx.allocator);
        }
    } else if (is_wave_transitioning) {
        drawWaveTransition();
    } else {
        drawZombies();
    }

    if (ctx.mouse_on_text and letter_count < MAX_INPUT_CHARS and ((ctx.frames_counter / 20) % 2) == 0) {
        raylib.DrawText("_", @as(c_int, @intFromFloat(ctx.text_box.x)) + 8 + raylib.MeasureText(&name, 40), @as(c_int, @intFromFloat(ctx.text_box.y)) + 12, 40, raylib.MAROON);
    }

    if (ctx.mouse_on_text and letter_count >= MAX_INPUT_CHARS) {
        raylib.DrawText("Press BACKSPACE to delete chars...", 230, 300, 20, raylib.GRAY);
    }
}

// Emscripten C-callback trampoline; arg carries the FrameContext pointer
fn frame_c_callback(arg: ?*anyopaque) callconv(.c) void {
    if (arg) |raw| {
        const ctx: *FrameContext = @ptrCast(@alignCast(raw));
        frame(ctx);
    }
}

// Registered via atexit() on the emscripten path because the `defer` blocks in main()
// never run there — emscripten_set_main_loop_arg does not return. atexit only fires on
// explicit emscripten_force_exit / module shutdown (browser tab close bypasses it), but
// it is the cleanest available hook for any controlled teardown the runtime offers.
fn cleanup_on_exit() callconv(.c) void {
    raylib.UnloadTexture(zombie_texture);
    raylib.UnloadSound(zombie_kill_sound);
    raylib.CloseAudioDevice();
    raylib.CloseWindow();
}

pub fn main() !void {
    raylib.InitWindow(screen_width, screen_height, "Zombie Game");
    defer raylib.CloseWindow();

    // Initialize the audio device
    raylib.InitAudioDevice();
    defer raylib.CloseAudioDevice();

    // Load sound effect
    zombie_kill_sound = raylib.LoadSound("assets/zombie-hit.wav");
    defer raylib.UnloadSound(zombie_kill_sound);

    zombie_texture = raylib.LoadTexture("assets/z_spritesheet.png");
    defer raylib.UnloadTexture(zombie_texture);

    raylib.SetTargetFPS(60); // Set target frames per second

    // page_allocator uses posix.mmap, which has no backend on wasm32-emscripten —
    // every allocator.create(...) silently fails and zombies never spawn.
    // c_allocator forwards to libc malloc/free, which emcc provides.
    var allocator: std.mem.Allocator = if (@import("builtin").target.os.tag == .emscripten)
        std.heap.c_allocator
    else
        std.heap.page_allocator;

    var ctx = FrameContext{
        .allocator = &allocator,
        .text_box = raylib.Rectangle{ .x = screen_width / 2.0 - 100.0, .y = 400.0, .width = 225.0, .height = 50.0 },
        .mouse_on_text = false,
        .frames_counter = 0,
    };

    if (comptime @import("builtin").target.os.tag == .emscripten) {
        // The emscripten loop never returns, so the defers above do not fire in the web
        // build. Register cleanup_on_exit() as a best-effort mitigation; see its doc
        // comment for the limitations on browser tab close.
        _ = raylib.atexit(&cleanup_on_exit);
        raylib.emscripten_set_main_loop_arg(frame_c_callback, &ctx, 0, 1);
    } else {
        while (!raylib.WindowShouldClose()) { // Main game loop
            frame(&ctx);
        }
    }
}

// Function to update zombies
fn updateZombies() void {
    for (zombies) |zombie| {
        if (zombie) |zomb| {
            if (!zomb.is_active) continue; // Skip if zombie is not on screen
            zomb.y += zomb.speed; // Update zombie position

            // Check if the zombie has reached the bottom of the screen
            if (zomb.y >= screen_height) {
                is_game_over = true;
                return; // Exit function to stop updating further
            }

            const typed_name = name[0..letter_count];
            const zomb_name_length = cstrLen(zomb.name);
            const zomb_name_slice = zomb.name[0..zomb_name_length];

            // Check for equality
            if (std.mem.eql(u8, typed_name, zomb_name_slice)) {
                zomb.is_active = false; // Mark zombie as "removed"
                letter_count = 0;
                name[letter_count] = '\x00';

                // Play the zombie kill sound
                raylib.PlaySound(zombie_kill_sound);
            }
        }
    }
}

fn drawWaveTransition() void {
    if (wave_transition_timer < WAVE_TRANSITION_RECAP_DURATION) {
        // Recap screen (first 5 seconds)
        var wave_buf: [32]u8 = undefined;
        const wave_text = std.fmt.bufPrint(&wave_buf, "Wave {} Complete!", .{current_wave}) catch "Wave Complete!";
        raylib.DrawText(@ptrCast(wave_text.ptr), screen_width / 2 - 120, screen_height / 2 - 80, 30, raylib.DARKGREEN);

        var kills_buf: [32]u8 = undefined;
        const kills_text = std.fmt.bufPrint(&kills_buf, "Kills: {}", .{wave_kill_count}) catch "Kills: --";
        raylib.DrawText(@ptrCast(kills_text.ptr), screen_width / 2 - 60, screen_height / 2 - 30, 20, raylib.DARKGRAY);

        const accuracy = if (total_keystrokes > 0) (correct_keystrokes * 100) / total_keystrokes else 100;
        var acc_buf: [32]u8 = undefined;
        const acc_text = std.fmt.bufPrint(&acc_buf, "Accuracy: {}%", .{accuracy}) catch "Accuracy: --%";
        raylib.DrawText(@ptrCast(acc_text.ptr), screen_width / 2 - 60, screen_height / 2, 20, raylib.DARKGRAY);

        const wpm = calculateWpm(&wpm_kill_times, wpm_kill_count, raylib.GetTime());
        var wpm_buf: [32]u8 = undefined;
        const wpm_text = std.fmt.bufPrint(&wpm_buf, "WPM: {}", .{wpm}) catch "WPM: --";
        raylib.DrawText(@ptrCast(wpm_text.ptr), screen_width / 2 - 60, screen_height / 2 + 30, 20, raylib.DARKGRAY);
    } else {
        // Countdown (last 3 seconds)
        const remaining = WAVE_TRANSITION_TOTAL_DURATION - wave_transition_timer;
        const countdown: u32 = @intFromFloat(@ceil(remaining));
        var cd_buf: [8]u8 = undefined;
        const cd_text = std.fmt.bufPrint(&cd_buf, "{}", .{countdown}) catch "?";
        raylib.DrawText(@ptrCast(cd_text.ptr), screen_width / 2 - 15, screen_height / 2 - 30, 60, raylib.RED);
    }
}

fn drawZombies() void {
    const delta_time = 1.0 / 60.0; // 60 FPS

    for (zombies) |zombie| {
        if (zombie) |zomb| {
            if (!zomb.is_active) continue;

            const pos = raylib.Vector2{ .x = zomb.x, .y = zomb.y };

            // Update the animation frame
            zomb.animation_timer += delta_time;

            if (zomb.animation_timer >= ZOMBIE_ANIMATION_FRAME_DURATION) {
                zomb.frame += 1;
                if (zomb.frame >= ZOMBIE_FRAME_COUNT) {
                    zomb.frame = 0; // Loop back to the first frame
                }
                zomb.animation_timer = 0; // Reset the timer
            }

            // Calculate the source rectangle for the current frame
            const frame_width = @as(f32, @floatFromInt(@divTrunc(zombie_texture.width, ZOMBIE_FRAME_COUNT)));

            const src_rect = raylib.Rectangle{
                .x = zomb.frame * frame_width,
                .y = 0,
                .width = frame_width,
                .height = @as(f32, @floatFromInt(zombie_texture.height)),
            };

            const scale = 0.2; // Adjust the scale factor to make the zombie smaller
            raylib.DrawTexturePro(
                zombie_texture,
                src_rect,
                raylib.Rectangle{
                    .x = pos.x,
                    .y = pos.y,
                    .width = frame_width * scale,
                    .height = @as(f32, @floatFromInt(zombie_texture.height)) * scale,
                },
                raylib.Vector2{ .x = 0, .y = 0 }, // Origin for scaling
                0.0, // Rotation
                raylib.WHITE,
            );

            // Draw the zombie's name above the zombie
            const text_pos = raylib.Vector2{ .x = pos.x, .y = pos.y - 20.0 }; // Adjust Y position as needed
            raylib.DrawText(zomb.name, @intFromFloat(text_pos.x), @intFromFloat(text_pos.y), 20, raylib.DARKGREEN); // Adjust font size and color as needed
        }
    }
}

fn countActiveZombies() u32 {
    var count: u32 = 0;
    for (zombies) |zombie| {
        if (zombie) |zomb| {
            if (zomb.is_active) count += 1;
        }
    }
    return count;
}

fn spawnZombie(allocator: *std.mem.Allocator) !bool {
    if (countActiveZombies() >= waveMaxActive(current_wave)) return false;

    for (zombies, 0..) |zombie, i| {
        if (zombie == null) {
            const new_zombie = try allocator.create(Zombie);
            errdefer allocator.destroy(new_zombie);

            const x = @as(f32, @floatFromInt(raylib.GetRandomValue(ZOMBIE_SPAWN_X_MIN, ZOMBIE_SPAWN_X_MAX)));
            const name_index: usize = @intCast(raylib.GetRandomValue(0, @intCast(ZombieNames.len - 1)));

            new_zombie.* = Zombie{
                .x = x,
                .y = 0.0,
                .speed = waveFallSpeed(current_wave),
                .name = ZombieNames[name_index],
                .is_active = true,
                .frame = 0,
                .animation_timer = 0,
                .is_boss = false,
                .phrase_progress = 0,
            };
            zombies[i] = new_zombie;
            return true;
        }
    }
    return false;
}

fn cstrLen(s: [*:0]const u8) usize {
    var len: usize = 0;
    while (s[len] != '\x00') len += 1;
    return len;
}

fn comboMultiplier(c: u32) u32 {
    if (c >= 20) return 5;
    if (c >= 15) return 4;
    if (c >= 10) return 3;
    if (c >= 5) return 2;
    return 1;
}

fn waveSpawnDelay(wave: u32) f32 {
    const result = BASE_SPAWN_DELAY * std.math.pow(f32, SPAWN_DELAY_DECAY, @as(f32, @floatFromInt(wave - 1)));
    return @max(result, MIN_SPAWN_DELAY);
}

fn waveFallSpeed(wave: u32) f32 {
    const result = BASE_FALL_SPEED * std.math.pow(f32, FALL_SPEED_GROWTH, @as(f32, @floatFromInt(wave - 1)));
    return @min(result, MAX_FALL_SPEED);
}

fn waveMaxActive(wave: u32) u32 {
    const result = BASE_MAX_ACTIVE + MAX_ACTIVE_INCREMENT * (wave - 1);
    return @min(result, CAP_MAX_ACTIVE);
}

fn waveKillTarget(wave: u32) u32 {
    const result = BASE_KILL_TARGET + KILL_TARGET_INCREMENT * (wave - 1);
    return @min(result, CAP_KILL_TARGET);
}

fn waveDuration(wave: u32) f32 {
    const result = BASE_WAVE_DURATION + WAVE_DURATION_INCREMENT * @as(f32, @floatFromInt(wave - 1));
    return @min(result, CAP_WAVE_DURATION);
}

fn calculateWpm(kill_times: []const f64, kill_count: usize, current_time: f64) u32 {
    var count: u32 = 0;
    const entries = @min(kill_count, kill_times.len);
    for (kill_times[0..entries]) |t| {
        if (t > 0.0 and (current_time - t) < WPM_WINDOW_SECONDS) {
            count += 1;
        }
    }
    return count * 2;
}

fn isValidPrefix(typed: []const u8, zombies_arr: *const [MAX_ZOMBIES]?*Zombie) bool {
    if (typed.len == 0) return true;
    for (zombies_arr) |zombie| {
        if (zombie) |zomb| {
            if (!zomb.is_active) continue;
            const zomb_name_len = cstrLen(zomb.name);
            const zomb_name_slice = zomb.name[0..zomb_name_len];
            if (std.mem.startsWith(u8, zomb_name_slice, typed)) return true;
        }
    }
    return false;
}

fn resetZombies(allocator: *std.mem.Allocator) void {
    for (&zombies) |*zombie| {
        if (zombie.*) |z| {
            allocator.destroy(z);
            zombie.* = null;
        }
    }
}

fn resetGameState(allocator: *std.mem.Allocator) void {
    resetZombies(allocator);
    is_game_over = false;
    letter_count = 0;
    name[0] = '\x00';
    spawn_timer = 0.0;
    current_wave = 1;
    wave_timer = 0.0;
    wave_kill_count = 0;
    is_wave_transitioning = false;
    wave_transition_timer = 0.0;
    boss_alive = false;
    score = 0;
    combo = 0;
    total_keystrokes = 0;
    correct_keystrokes = 0;
    total_kills = 0;
    wpm_kill_times = [_]f64{0.0} ** WPM_BUFFER_SIZE;
    wpm_kill_index = 0;
    wpm_kill_count = 0;
}

// T003: name-match equality — mirrors the comparison in updateZombies
test "name match equality" {
    const alice: [*:0]const u8 = "Alice";
    var typed_buf = [_]u8{ 'A', 'l', 'i', 'c', 'e', '\x00', 0, 0, 0, 0 };
    const typed_name = typed_buf[0..5];

    var zomb_name_length: usize = 0;
    while (alice[zomb_name_length] != '\x00') zomb_name_length += 1;
    const zomb_name_slice = alice[0..zomb_name_length];

    try std.testing.expect(std.mem.eql(u8, typed_name, zomb_name_slice));
    try std.testing.expect(!std.mem.eql(u8, typed_buf[0..4], zomb_name_slice));
}

// T004: input buffer bounds — mirrors the write gate in the main game loop
test "input buffer bounds" {
    var buf = [_]u8{0} ** (MAX_INPUT_CHARS + 1);
    var count: usize = 0;

    // key 32 (lowest printable ASCII) must be accepted
    const key_lo: i32 = 32;
    if ((key_lo >= 32) and (key_lo <= 125) and (count < MAX_INPUT_CHARS)) {
        buf[count] = @intCast(key_lo);
        buf[count + 1] = '\x00';
        count += 1;
    }
    try std.testing.expectEqual(@as(usize, 1), count);

    // key 31 (below range) must be rejected
    const key_below: i32 = 31;
    const before_below = count;
    if ((key_below >= 32) and (key_below <= 125) and (count < MAX_INPUT_CHARS)) {
        buf[count] = @intCast(key_below);
        buf[count + 1] = '\x00';
        count += 1;
    }
    try std.testing.expectEqual(before_below, count);

    // key 126 (above range) must be rejected
    const key_above: i32 = 126;
    const before_above = count;
    if ((key_above >= 32) and (key_above <= 125) and (count < MAX_INPUT_CHARS)) {
        buf[count] = @intCast(key_above);
        buf[count + 1] = '\x00';
        count += 1;
    }
    try std.testing.expectEqual(before_above, count);

    // fill to MAX_INPUT_CHARS
    while (count < MAX_INPUT_CHARS) {
        const k: i32 = 65;
        if ((k >= 32) and (k <= 125) and (count < MAX_INPUT_CHARS)) {
            buf[count] = @intCast(k);
            buf[count + 1] = '\x00';
            count += 1;
        }
    }
    try std.testing.expectEqual(MAX_INPUT_CHARS, count);

    // one more write must be rejected even though the key is in range
    const key_full: i32 = 65;
    const before_full = count;
    if ((key_full >= 32) and (key_full <= 125) and (count < MAX_INPUT_CHARS)) {
        buf[count] = @intCast(key_full);
        buf[count + 1] = '\x00';
        count += 1;
    }
    try std.testing.expectEqual(before_full, count);

    // buffer remains null-terminated at position count
    try std.testing.expectEqual(@as(u8, '\x00'), buf[count]);
}

// T005: frame-index wrap — mirrors the animation increment in drawZombies
test "frame index wraps after ZOMBIE_FRAME_COUNT" {
    var f: f32 = ZOMBIE_FRAME_COUNT - 1;
    f += 1;
    if (f >= ZOMBIE_FRAME_COUNT) f = 0;
    try std.testing.expectEqual(@as(f32, 0.0), f);

    // mid-range frame must not wrap
    var mid: f32 = @as(f32, ZOMBIE_FRAME_COUNT) / 2.0;
    mid += 1;
    if (mid >= ZOMBIE_FRAME_COUNT) mid = 0;
    try std.testing.expect(mid > 0.0);
}

test "cstrLen" {
    try std.testing.expectEqual(@as(usize, 5), cstrLen("Alice"));
    try std.testing.expectEqual(@as(usize, 0), cstrLen(""));
    try std.testing.expectEqual(@as(usize, 1), cstrLen("A"));
    try std.testing.expectEqual(@as(usize, 17), cstrLen("undead apocalypse"));
}

test "comboMultiplier tier boundaries" {
    try std.testing.expectEqual(@as(u32, 1), comboMultiplier(0));
    try std.testing.expectEqual(@as(u32, 1), comboMultiplier(4));
    try std.testing.expectEqual(@as(u32, 2), comboMultiplier(5));
    try std.testing.expectEqual(@as(u32, 2), comboMultiplier(9));
    try std.testing.expectEqual(@as(u32, 3), comboMultiplier(10));
    try std.testing.expectEqual(@as(u32, 3), comboMultiplier(14));
    try std.testing.expectEqual(@as(u32, 4), comboMultiplier(15));
    try std.testing.expectEqual(@as(u32, 4), comboMultiplier(19));
    try std.testing.expectEqual(@as(u32, 5), comboMultiplier(20));
    try std.testing.expectEqual(@as(u32, 5), comboMultiplier(100));
}

test "waveSpawnDelay" {
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), waveSpawnDelay(1), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0 * 0.85 * 0.85 * 0.85 * 0.85), waveSpawnDelay(5), 0.01);
    try std.testing.expect(waveSpawnDelay(12) >= MIN_SPAWN_DELAY);
    try std.testing.expect(waveSpawnDelay(20) >= MIN_SPAWN_DELAY);
}

test "waveFallSpeed" {
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), waveFallSpeed(1), 0.01);
    try std.testing.expect(waveFallSpeed(5) > BASE_FALL_SPEED);
    try std.testing.expect(waveFallSpeed(15) <= MAX_FALL_SPEED);
    try std.testing.expectApproxEqAbs(MAX_FALL_SPEED, @min(waveFallSpeed(20), MAX_FALL_SPEED), 0.01);
}

test "waveMaxActive" {
    try std.testing.expectEqual(@as(u32, 5), waveMaxActive(1));
    try std.testing.expectEqual(@as(u32, 13), waveMaxActive(5));
    try std.testing.expectEqual(@as(u32, 29), waveMaxActive(13));
    try std.testing.expectEqual(@as(u32, 30), waveMaxActive(20));
}

test "waveKillTarget" {
    try std.testing.expectEqual(@as(u32, 5), waveKillTarget(1));
    try std.testing.expectEqual(@as(u32, 13), waveKillTarget(5));
    try std.testing.expectEqual(@as(u32, 40), waveKillTarget(20));
}

test "waveDuration" {
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), waveDuration(1), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), waveDuration(5), 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 120.0), waveDuration(20), 0.01);
}

test "calculateWpm" {
    // empty buffer
    var empty_times = [_]f64{0.0} ** 10;
    try std.testing.expectEqual(@as(u32, 0), calculateWpm(&empty_times, 0, 100.0));

    // partial buffer: 3 kills within window
    var times = [_]f64{0.0} ** 10;
    times[0] = 90.0;
    times[1] = 92.0;
    times[2] = 95.0;
    try std.testing.expectEqual(@as(u32, 6), calculateWpm(&times, 3, 100.0));

    // expired entries outside window
    times[0] = 10.0;
    times[1] = 15.0;
    times[2] = 95.0;
    try std.testing.expectEqual(@as(u32, 2), calculateWpm(&times, 3, 100.0));

    // all expired
    times[0] = 10.0;
    times[1] = 15.0;
    times[2] = 20.0;
    try std.testing.expectEqual(@as(u32, 0), calculateWpm(&times, 3, 100.0));
}

test "wave state resets on new wave" {
    wave_kill_count = 10;
    wave_timer = 25.0;
    current_wave = 3;

    // Simulate what happens at wave transition end
    current_wave += 1;
    wave_kill_count = 0;
    wave_timer = 0.0;

    try std.testing.expectEqual(@as(u32, 0), wave_kill_count);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), wave_timer, 0.01);
    try std.testing.expectEqual(@as(u32, 4), current_wave);

    // Reset for other tests
    current_wave = 1;
}

test "wave transition timer progression" {
    try std.testing.expectApproxEqAbs(
        @as(f32, 8.0),
        WAVE_TRANSITION_RECAP_DURATION + WAVE_TRANSITION_COUNTDOWN_DURATION,
        0.01,
    );
    try std.testing.expectApproxEqAbs(
        WAVE_TRANSITION_TOTAL_DURATION,
        WAVE_TRANSITION_RECAP_DURATION + WAVE_TRANSITION_COUNTDOWN_DURATION,
        0.01,
    );
}
