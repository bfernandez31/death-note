const std = @import("std");
const raylib = @import("raylib.zig").c;

// Importing the list of zombie names
const ZombieNames = @import("zombie_names.zig").ZombieNames;
const BossPhrases = @import("boss_phrases.zig").BossPhrases;

const MAX_ZOMBIES = 100;
const MAX_INPUT_CHARS = 9;
const MAX_BOSS_INPUT_CHARS = 35;
const BOSS_SCALE: f32 = 0.4;
const BOSS_SPEED_MULTIPLIER: f32 = 0.5;
const BOSS_HEALTH_BAR_WIDTH: c_int = 200;
const BOSS_HEALTH_BAR_HEIGHT: c_int = 8;
const BOSS_DARK_RED = raylib.Color{ .r = 139, .g = 0, .b = 0, .a = 255 };
const BOSS_WAVE_INTERVAL: u32 = 5;

const ZOMBIE_FRAME_COUNT = 17;
const ZOMBIE_ANIMATION_FRAME_DURATION: f32 = 0.1; // seconds per spritesheet frame
const WAVE_TRANSITION_DURATION: f32 = 3.0;

const MAX_POPUPS = 32;
const POPUP_DURATION: f32 = 0.5;
const POPUP_RISE_PX: f32 = 30.0;
const SCORE_HUD_X: c_int = 10;
const SCORE_HUD_Y: c_int = 5;
const SCORE_HUD_SIZE: c_int = 24;
const COMBO_HUD_X: c_int = 10;
const COMBO_HUD_Y: c_int = 35;
const COMBO_HUD_SIZE: c_int = 18;
const POPUP_FONT_SIZE: c_int = 20;
const BOSS_TYPE_MULTIPLIER: f32 = 3.0;
const STANDARD_TYPE_MULTIPLIER: f32 = 1.0;

const WPM_BUFFER_SIZE: usize = 512;
const WPM_WINDOW_SECONDS: f32 = 10.0;
const WPM_HUD_X: c_int = screen_width - 100;
const WPM_HUD_Y: c_int = 5;
const ACC_HUD_X: c_int = screen_width - 100;
const ACC_HUD_Y: c_int = 30;
const METRICS_HUD_SIZE: c_int = 18;
const SMOOTHING_FACTOR: f32 = 0.2;
// WPM convention: 1 word = 5 chars, so wpm = (chars / time_seconds) * 60 / 5.
const CHARS_PER_WORD: f32 = 5.0;
const SECONDS_PER_MINUTE: f32 = 60.0;

const WaveConfig = struct {
    target_wpm: u32,
    spawn_delay: f32,
    fall_speed: f32,
    pool_size: u32,
};

const WAVE_TABLE = [_]WaveConfig{
    .{ .target_wpm = 15, .spawn_delay = 4.80, .fall_speed = 0.5, .pool_size = 5 },
    .{ .target_wpm = 18, .spawn_delay = 4.00, .fall_speed = 0.6, .pool_size = 7 },
    .{ .target_wpm = 22, .spawn_delay = 3.27, .fall_speed = 0.7, .pool_size = 9 },
    .{ .target_wpm = 26, .spawn_delay = 2.77, .fall_speed = 0.8, .pool_size = 11 },
    .{ .target_wpm = 30, .spawn_delay = 2.40, .fall_speed = 0.9, .pool_size = 13 },
    .{ .target_wpm = 35, .spawn_delay = 2.06, .fall_speed = 1.0, .pool_size = 15 },
    .{ .target_wpm = 40, .spawn_delay = 1.80, .fall_speed = 1.1, .pool_size = 17 },
    .{ .target_wpm = 45, .spawn_delay = 1.60, .fall_speed = 1.2, .pool_size = 19 },
    .{ .target_wpm = 50, .spawn_delay = 1.44, .fall_speed = 1.3, .pool_size = 21 },
    .{ .target_wpm = 55, .spawn_delay = 1.31, .fall_speed = 1.4, .pool_size = 23 },
    .{ .target_wpm = 60, .spawn_delay = 1.20, .fall_speed = 1.5, .pool_size = 25 },
    .{ .target_wpm = 70, .spawn_delay = 1.03, .fall_speed = 1.6, .pool_size = 27 },
    .{ .target_wpm = 80, .spawn_delay = 0.90, .fall_speed = 1.7, .pool_size = 29 },
    .{ .target_wpm = 90, .spawn_delay = 0.80, .fall_speed = 1.8, .pool_size = 31 },
    .{ .target_wpm = 100, .spawn_delay = 0.72, .fall_speed = 1.9, .pool_size = 33 },
};

// Input buffer for characters
var name = [_]u8{0} ** (MAX_BOSS_INPUT_CHARS + 1);
var letter_count: usize = 0;

var spawn_timer: f32 = 0.0;

var is_game_over: bool = false;
var current_wave: u32 = 1;
var wave_kills: u32 = 0;
var wave_spawned: u32 = 0;
var is_transitioning: bool = false;
var transition_timer: f32 = 0.0;

var boss: ?*Zombie = null;
var boss_spawned_this_wave: bool = false;
var boss_phrase_len: usize = 0;

var score: u64 = 0;
var combo_count: u32 = 0;
var popups = [_]ScorePopup{.{ .x = 0, .y = 0, .points = 0, .timer = 0, .active = false }} ** MAX_POPUPS;
var popup_next: usize = 0;

var wpm_buffer = [_]f32{0} ** WPM_BUFFER_SIZE;
var wpm_buffer_head: usize = 0;
var wpm_buffer_count: usize = 0;
var correct_chars: u32 = 0;
var wrong_chars: u32 = 0;
var elapsed_time: f32 = 0.0;
var displayed_wpm: f32 = 0.0;
var displayed_accuracy: f32 = 100.0;

// Define the Zombie structure
const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,
    name: [*:0]const u8,
    is_active: bool,
    frame: f32, // Current animation frame
    animation_timer: f32,
};

const ScorePopup = struct {
    x: f32,
    y: f32,
    points: u64,
    timer: f32,
    active: bool,
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
    // Resize input box for boss mode: the 9-char box is too narrow for the 35-char
    // boss buffer at font size 40, so typing overflows visually. Widen and recenter
    // while a boss is active; restore the standard layout otherwise.
    if (boss != null) {
        ctx.text_box.width = 700.0;
        ctx.text_box.x = (screen_width - 700.0) / 2.0;
    } else {
        ctx.text_box.width = 225.0;
        ctx.text_box.x = screen_width / 2.0 - 100.0;
    }

    // Mouse-over and cursor state are updated every frame (not gated by is_game_over),
    // so the blinking cursor on the game-over screen stays animated and matches the
    // current mouse position instead of freezing at its last in-game value.
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

    if (!is_game_over and !is_transitioning) {
        // Accept keystrokes regardless of mouse position so players can start typing
        // immediately on load (especially on web, where focus is on the canvas, not the
        // text box hit-test rectangle).
        var key = raylib.GetCharPressed();
        while (key > 0) {
            if ((key >= 32) and (key <= 125) and (letter_count < getCurrentMaxInput())) {
                name[letter_count] = @intCast(key);
                name[letter_count + 1] = '\x00';
                letter_count += 1;
                if (typedMatchesAnyEnemy()) {
                    recordCorrectTimestamp(elapsed_time);
                    correct_chars += 1;
                } else {
                    wrong_chars += 1;
                    combo_count = 0;
                }
            }
            key = raylib.GetCharPressed();
        }

        if (raylib.IsKeyPressed(raylib.KEY_BACKSPACE) and letter_count > 0) {
            letter_count -= 1;
            name[letter_count] = '\x00';
        }

        const wave_cfg = getWaveConfig(current_wave);

        // Update spawn timer
        spawn_timer += raylib.GetFrameTime(); // Increment timer by the time elapsed since last frame

        // Spawn gate: pool_size cap stops new spawns for the rest of the wave once the
        // quota is hit (timer then accumulates harmlessly until the wave transitions and
        // resets it). When the gate is open but spawnZombie returns false (pool full),
        // spawn_timer is left untouched so the engine retries every frame.
        if (spawn_timer >= wave_cfg.spawn_delay and wave_spawned < wave_cfg.pool_size) {
            const spawned = spawnZombie(ctx.allocator) catch false;
            if (spawned) {
                spawn_timer = 0.0;
                wave_spawned += 1;
            }
        }

        // Update zombies (may set is_game_over if a zombie reaches the bottom)
        updateZombies(ctx.allocator);

        if (isBossWave(current_wave) and !boss_spawned_this_wave and boss == null) {
            const threshold = (wave_cfg.pool_size + 1) / 2;
            if (wave_kills >= threshold) {
                spawnBoss(ctx.allocator) catch {};
            }
        }

        updateBoss(ctx.allocator);

        // Wave completion detection — guarded against is_game_over so a kill+death in the
        // same frame does not silently start a wave transition behind the game-over screen.
        const boss_done = !isBossWave(current_wave) or (boss == null and boss_spawned_this_wave);
        if (!is_game_over and wave_kills >= wave_cfg.pool_size and wave_spawned >= wave_cfg.pool_size and boss_done) {
            is_transitioning = true;
            transition_timer = WAVE_TRANSITION_DURATION;
            combo_count = 0;
        }
    }

    // Wave transition countdown — also gated by !is_game_over for the same reason.
    if (is_transitioning and !is_game_over) {
        transition_timer -= raylib.GetFrameTime();
        if (transition_timer <= 0) {
            current_wave += 1;
            wave_kills = 0;
            wave_spawned = 0;
            spawn_timer = 0.0;
            is_transitioning = false;
            resetZombies(ctx.allocator);
            resetBoss(ctx.allocator);
        }
    }

    if (!is_game_over) {
        updateMetrics();
    }

    for (&popups) |*p| {
        if (p.active) {
            p.timer -= raylib.GetFrameTime();
            if (p.timer <= 0) p.active = false;
        }
    }

    // Draw
    raylib.BeginDrawing();
    defer raylib.EndDrawing();

    raylib.ClearBackground(raylib.RAYWHITE);

    // HUD: wave number, target WPM, kill progress (not shown during game-over)
    if (!is_game_over) {
        const hud_cfg = getWaveConfig(current_wave);
        var hud_buf: [64]u8 = undefined;
        const hud_text = std.fmt.bufPrintZ(&hud_buf, "WAVE {d} - {d} WPM - {d} / {d}", .{ current_wave, hud_cfg.target_wpm, wave_kills, hud_cfg.pool_size }) catch "WAVE ?";
        drawCenteredText(hud_text.ptr, 10, 20, raylib.DARKGRAY);

        var score_buf: [32]u8 = undefined;
        const score_text = std.fmt.bufPrintZ(&score_buf, "Score: {d}", .{score}) catch "Score: ?";
        raylib.DrawText(score_text.ptr, SCORE_HUD_X, SCORE_HUD_Y, SCORE_HUD_SIZE, raylib.DARKGREEN);

        var combo_buf: [32]u8 = undefined;
        const combo_text = std.fmt.bufPrintZ(&combo_buf, "Combo: {d} x{d}", .{ combo_count, getComboMultiplier(combo_count) }) catch "Combo: ?";
        raylib.DrawText(combo_text.ptr, COMBO_HUD_X, COMBO_HUD_Y, COMBO_HUD_SIZE, getComboColor(combo_count));

        const wpm_rounded: u32 = @intFromFloat(@round(displayed_wpm));
        var wpm_buf: [32]u8 = undefined;
        const wpm_text = std.fmt.bufPrintZ(&wpm_buf, "WPM {d}", .{wpm_rounded}) catch "WPM ?";
        raylib.DrawText(wpm_text.ptr, WPM_HUD_X, WPM_HUD_Y, METRICS_HUD_SIZE, raylib.DARKGRAY);

        const acc_rounded: u32 = @intFromFloat(@round(displayed_accuracy));
        var acc_buf: [32]u8 = undefined;
        const acc_text = std.fmt.bufPrintZ(&acc_buf, "Acc {d}%", .{acc_rounded}) catch "Acc ?";
        raylib.DrawText(acc_text.ptr, ACC_HUD_X, ACC_HUD_Y, METRICS_HUD_SIZE, raylib.DARKGRAY);
    }

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
        raylib.DrawText("GAME OVER", screen_width / 2 - 100, screen_height / 2 - 40, 40, raylib.RED);

        var go_wave_buf: [32]u8 = undefined;
        const go_wave_text = std.fmt.bufPrintZ(&go_wave_buf, "Wave reached: {d}", .{current_wave}) catch "Wave reached: ?";
        drawCenteredText(go_wave_text.ptr, screen_height / 2 + 5, 20, raylib.GRAY);

        var go_wpm_buf: [32]u8 = undefined;
        const go_wpm_text = std.fmt.bufPrintZ(&go_wpm_buf, "Required WPM: {d}", .{getWaveConfig(current_wave).target_wpm}) catch "Required WPM: ?";
        drawCenteredText(go_wpm_text.ptr, screen_height / 2 + 30, 20, raylib.GRAY);

        var go_score_buf: [32]u8 = undefined;
        const go_score_text = std.fmt.bufPrintZ(&go_score_buf, "Score: {d}", .{score}) catch "Score: ?";
        drawCenteredText(go_score_text.ptr, screen_height / 2 + 55, 20, raylib.GRAY);

        raylib.DrawText("Press ENTER to Restart", screen_width / 2 - 130, screen_height / 2 + 85, 20, raylib.GRAY);

        // Restart game if Enter is pressed
        if (raylib.IsKeyPressed(raylib.KEY_ENTER)) {
            is_game_over = false;
            letter_count = 0;
            name[letter_count] = '\x00';
            spawn_timer = 0.0;
            current_wave = 1;
            wave_kills = 0;
            wave_spawned = 0;
            is_transitioning = false;
            transition_timer = 0.0;
            resetScoreState();
            resetMetricsState();
            resetZombies(ctx.allocator);
            resetBoss(ctx.allocator);
        }
    } else if (is_transitioning) {
        const next_wave = current_wave + 1;
        const next_cfg = getWaveConfig(next_wave);
        const countdown = @as(u32, @intFromFloat(@ceil(transition_timer)));

        var wave_buf: [64]u8 = undefined;
        const wave_text = std.fmt.bufPrintZ(&wave_buf, "WAVE {d} - {d} WPM challenge - {d}...", .{ next_wave, next_cfg.target_wpm, countdown }) catch "NEXT WAVE";
        drawCenteredText(wave_text.ptr, screen_height / 2 - 15, 30, raylib.DARKGRAY);
    } else {
        drawZombies();
        drawBoss();
    }
    // Popups layer on top of every state so the visual feedback for the kill that
    // ended the wave (transition branch) or that coincided with the floor-cross
    // game-over (game_over branch) is never silently dropped.
    drawPopups();
    // Draw blinking underscore char
    if (ctx.mouse_on_text and letter_count < getCurrentMaxInput() and ((ctx.frames_counter / 20) % 2) == 0) {
        raylib.DrawText("_", @as(c_int, @intFromFloat(ctx.text_box.x)) + 8 + raylib.MeasureText(&name, 40), @as(c_int, @intFromFloat(ctx.text_box.y)) + 12, 40, raylib.MAROON);
    }

    if (ctx.mouse_on_text and letter_count >= getCurrentMaxInput()) {
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
fn updateZombies(allocator: *std.mem.Allocator) void {
    // Boss has priority: while the player is typing a prefix of the boss phrase,
    // skip regular-zombie kill matches so the input isn't consumed by a coincidental name match.
    const boss_protected = typedIsBossPrefix();

    // Free killed zombies and null their slots so spawnZombie can reuse them; otherwise
    // pool_size values above MAX_ZOMBIES (waves 49+) soft-lock once every slot is consumed.
    for (&zombies) |*slot| {
        if (slot.*) |zomb| {
            if (!zomb.is_active) continue;
            zomb.y += zomb.speed;

            if (zomb.y >= screen_height) {
                is_game_over = true;
                return;
            }

            if (boss_protected) continue;

            const typed_name = name[0..letter_count];

            var zomb_name_length: usize = 0;
            while (zomb.name[zomb_name_length] != '\x00') {
                zomb_name_length += 1;
            }
            const zomb_name_slice = zomb.name[0..zomb_name_length];

            if (std.mem.eql(u8, typed_name, zomb_name_slice)) {
                const points = calculateScore(zomb_name_length, zomb.y, false, combo_count);
                score += points;
                combo_count += 1;
                spawnPopup(zomb.x, zomb.y, points);
                allocator.destroy(zomb);
                slot.* = null;
                letter_count = 0;
                name[letter_count] = '\x00';
                wave_kills += 1;
                raylib.PlaySound(zombie_kill_sound);
            }
        }
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

// Function to spawn new zombies. Returns true when a slot was claimed, false when
// the pool is full so the caller can keep the spawn timer hot for next frame.
fn spawnZombie(allocator: *std.mem.Allocator) !bool {
    for (zombies, 0..) |zombie, i| {
        if (zombie == null) {
            // Allocate memory for a new zombie and assign it to zombies[i]
            const new_zombie = try allocator.create(Zombie);
            errdefer allocator.destroy(new_zombie);

            const x = @as(f32, @floatFromInt(raylib.GetRandomValue(ZOMBIE_SPAWN_X_MIN, ZOMBIE_SPAWN_X_MAX)));
            const name_index: usize = @intCast(raylib.GetRandomValue(0, @intCast(ZombieNames.len - 1)));

            new_zombie.* = Zombie{
                .x = x,
                .y = 0.0,
                .speed = getWaveConfig(current_wave).fall_speed,
                .name = ZombieNames[name_index],
                .is_active = true,
                .frame = 0,
                .animation_timer = 0,
            };
            zombies[i] = new_zombie;
            return true;
        }
    }
    return false;
}

fn drawCenteredText(text: [*:0]const u8, y: c_int, size: c_int, color: raylib.Color) void {
    const width = raylib.MeasureText(text, size);
    raylib.DrawText(text, @divTrunc(screen_width - width, 2), y, size, color);
}

fn getWaveConfig(wave: u32) WaveConfig {
    if (wave >= 1 and wave <= WAVE_TABLE.len) {
        return WAVE_TABLE[wave - 1];
    }
    return WaveConfig{
        .target_wpm = 110,
        .spawn_delay = 0.66,
        .fall_speed = 2.0,
        .pool_size = 33 + 2 * (wave - 15),
    };
}

fn updateBoss(allocator: *std.mem.Allocator) void {
    if (boss) |b| {
        b.y += b.speed;

        if (b.y >= screen_height) {
            is_game_over = true;
            return;
        }

        if (letter_count == boss_phrase_len and typedIsBossPrefix()) {
            const points = calculateScore(boss_phrase_len, b.y, true, combo_count);
            score += points;
            combo_count += 1;
            spawnPopup(b.x, b.y, points);
            allocator.destroy(b);
            boss = null;
            letter_count = 0;
            name[0] = '\x00';
            raylib.PlaySound(zombie_kill_sound);
        }
    }
}

fn drawBoss() void {
    if (boss) |b| {
        const delta_time = 1.0 / 60.0;

        b.animation_timer += delta_time;
        if (b.animation_timer >= ZOMBIE_ANIMATION_FRAME_DURATION) {
            b.frame += 1;
            if (b.frame >= ZOMBIE_FRAME_COUNT) {
                b.frame = 0;
            }
            b.animation_timer = 0;
        }

        const frame_width = @as(f32, @floatFromInt(@divTrunc(zombie_texture.width, ZOMBIE_FRAME_COUNT)));

        const src_rect = raylib.Rectangle{
            .x = b.frame * frame_width,
            .y = 0,
            .width = frame_width,
            .height = @as(f32, @floatFromInt(zombie_texture.height)),
        };

        raylib.DrawTexturePro(
            zombie_texture,
            src_rect,
            raylib.Rectangle{
                .x = b.x,
                .y = b.y,
                .width = frame_width * BOSS_SCALE,
                .height = @as(f32, @floatFromInt(zombie_texture.height)) * BOSS_SCALE,
            },
            raylib.Vector2{ .x = 0, .y = 0 },
            0.0,
            raylib.RED,
        );

        const boss_x: c_int = @intFromFloat(b.x);
        const boss_y: c_int = @intFromFloat(b.y);
        // FR-007: phrase text sits above the sprite; health bar sits below the phrase
        // (between phrase and sprite). Stacked top→bottom: phrase, bar, sprite.
        raylib.DrawText(b.name, boss_x, boss_y - 50, 20, BOSS_DARK_RED);

        const bar_x = boss_x;
        const bar_y = boss_y - 25;
        raylib.DrawRectangle(bar_x, bar_y, BOSS_HEALTH_BAR_WIDTH, BOSS_HEALTH_BAR_HEIGHT, raylib.LIGHTGRAY);

        if (boss_phrase_len > 0) {
            // c_int * usize is not implicitly coercible — promote lengths to c_int for arithmetic.
            const phrase_len_i: c_int = @intCast(boss_phrase_len);
            const letter_count_i: c_int = @intCast(letter_count);
            const fill_width: c_int = if (typedIsBossPrefix())
                @divTrunc(BOSS_HEALTH_BAR_WIDTH * (phrase_len_i - letter_count_i), phrase_len_i)
            else
                BOSS_HEALTH_BAR_WIDTH;
            raylib.DrawRectangle(bar_x, bar_y, fill_width, BOSS_HEALTH_BAR_HEIGHT, raylib.RED);
        }

        raylib.DrawRectangleLines(bar_x, bar_y, BOSS_HEALTH_BAR_WIDTH, BOSS_HEALTH_BAR_HEIGHT, raylib.DARKGRAY);
    }
}

fn spawnBoss(allocator: *std.mem.Allocator) !void {
    const new_boss = try allocator.create(Zombie);
    errdefer allocator.destroy(new_boss);

    const frame_width = @as(f32, @floatFromInt(@divTrunc(zombie_texture.width, ZOMBIE_FRAME_COUNT)));
    const phrase_index: usize = @intCast(raylib.GetRandomValue(0, @intCast(BossPhrases.len - 1)));
    const phrase = BossPhrases[phrase_index];

    new_boss.* = Zombie{
        .x = screen_width / 2.0 - (frame_width * BOSS_SCALE / 2.0),
        .y = 0.0,
        .speed = getWaveConfig(current_wave).fall_speed * BOSS_SPEED_MULTIPLIER,
        .name = phrase,
        .is_active = true,
        .frame = 0,
        .animation_timer = 0,
    };
    boss = new_boss;
    boss_spawned_this_wave = true;

    var len: usize = 0;
    while (phrase[len] != '\x00') len += 1;
    boss_phrase_len = len;
}

fn getCurrentMaxInput() usize {
    return if (boss != null) MAX_BOSS_INPUT_CHARS else MAX_INPUT_CHARS;
}

fn isBossWave(wave: u32) bool {
    return wave % BOSS_WAVE_INTERVAL == 0;
}

// True when the currently-typed input is a (possibly partial) prefix of the live boss phrase.
// Used to (a) protect the player's keystrokes from being consumed by a coincidental zombie-name
// match, (b) detect a completed boss kill, and (c) drive the health-bar fill.
fn typedIsBossPrefix() bool {
    const b = boss orelse return false;
    if (letter_count > boss_phrase_len) return false;
    const boss_slice = b.name[0..boss_phrase_len];
    return std.mem.eql(u8, name[0..letter_count], boss_slice[0..letter_count]);
}

fn resetBoss(allocator: *std.mem.Allocator) void {
    if (boss) |b| {
        allocator.destroy(b);
        boss = null;
    }
    boss_spawned_this_wave = false;
    boss_phrase_len = 0;
}

fn resetZombies(allocator: *std.mem.Allocator) void {
    for (&zombies) |*zombie| {
        if (zombie.*) |z| {
            allocator.destroy(z);
            zombie.* = null;
        }
    }
}

fn getComboMultiplier(combo: u32) u64 {
    if (combo >= 20) return 5;
    if (combo >= 15) return 4;
    if (combo >= 10) return 3;
    if (combo >= 5) return 2;
    return 1;
}

fn getComboColor(combo: u32) raylib.Color {
    if (combo >= 15) return raylib.RED;
    if (combo >= 5) return raylib.ORANGE;
    return raylib.DARKGRAY;
}

fn resetScoreState() void {
    score = 0;
    combo_count = 0;
    popup_next = 0;
    for (&popups) |*p| p.active = false;
}

fn calculateScore(name_len: usize, y_pos: f32, is_boss: bool, combo: u32) u64 {
    const type_mult: f32 = if (is_boss) BOSS_TYPE_MULTIPLIER else STANDARD_TYPE_MULTIPLIER;
    const height_score = @round(100.0 * (y_pos / @as(f32, @floatFromInt(screen_height))));
    const base = @as(f32, @floatFromInt(name_len)) * 10.0 + height_score;
    return @as(u64, @intFromFloat(@round(base * type_mult))) * getComboMultiplier(combo);
}

fn spawnPopup(x: f32, y: f32, points: u64) void {
    popups[popup_next] = ScorePopup{ .x = x, .y = y, .points = points, .timer = POPUP_DURATION, .active = true };
    popup_next = (popup_next + 1) % MAX_POPUPS;
}

fn typedMatchesAnyEnemy() bool {
    if (letter_count == 0) return true;
    const typed = name[0..letter_count];
    for (zombies) |slot| {
        if (slot) |zomb| {
            if (!zomb.is_active) continue;
            var zomb_name_length: usize = 0;
            while (zomb.name[zomb_name_length] != '\x00') zomb_name_length += 1;
            if (letter_count <= zomb_name_length and std.mem.eql(u8, typed, zomb.name[0..letter_count])) return true;
        }
    }
    if (boss) |b| {
        if (letter_count <= boss_phrase_len and std.mem.eql(u8, typed, b.name[0..letter_count])) return true;
    }
    return false;
}

fn recordCorrectTimestamp(time: f32) void {
    wpm_buffer[wpm_buffer_head] = time;
    wpm_buffer_head = (wpm_buffer_head + 1) % WPM_BUFFER_SIZE;
    wpm_buffer_count = @min(wpm_buffer_count + 1, WPM_BUFFER_SIZE);
}

fn countCharsInWindow(current_time: f32) u32 {
    var count: u32 = 0;
    const window_start = current_time - WPM_WINDOW_SECONDS;
    for (wpm_buffer[0..wpm_buffer_count]) |timestamp| {
        if (timestamp >= window_start) count += 1;
    }
    return count;
}

fn resetMetricsState() void {
    wpm_buffer = [_]f32{0} ** WPM_BUFFER_SIZE;
    wpm_buffer_head = 0;
    wpm_buffer_count = 0;
    correct_chars = 0;
    wrong_chars = 0;
    elapsed_time = 0.0;
    displayed_wpm = 0.0;
    displayed_accuracy = 100.0;
}

fn charsToWpm(chars: u32, time_seconds: f32) f32 {
    return @as(f32, @floatFromInt(chars)) * SECONDS_PER_MINUTE / CHARS_PER_WORD / time_seconds;
}

fn calculateTargetWpm() f32 {
    if (elapsed_time == 0) return 0.0;
    // Before the window fills, scale by elapsed time so early bursts aren't under-reported.
    if (elapsed_time < WPM_WINDOW_SECONDS) return charsToWpm(correct_chars, elapsed_time);
    return charsToWpm(countCharsInWindow(elapsed_time), WPM_WINDOW_SECONDS);
}

fn calculateTargetAccuracy() f32 {
    const total = correct_chars + wrong_chars;
    if (total == 0) return 100.0;
    return (@as(f32, @floatFromInt(correct_chars)) / @as(f32, @floatFromInt(total))) * 100.0;
}

fn updateMetrics() void {
    elapsed_time += raylib.GetFrameTime();
    const target_wpm = calculateTargetWpm();
    displayed_wpm += SMOOTHING_FACTOR * (target_wpm - displayed_wpm);
    const target_accuracy = calculateTargetAccuracy();
    displayed_accuracy += SMOOTHING_FACTOR * (target_accuracy - displayed_accuracy);
}

fn drawPopups() void {
    for (&popups) |*p| {
        if (!p.active) continue;
        const progress = 1.0 - (p.timer / POPUP_DURATION);
        const draw_y = p.y - (POPUP_RISE_PX * progress);
        const alpha: u8 = @intFromFloat((p.timer / POPUP_DURATION) * 255.0);
        const color = raylib.Color{ .r = 255, .g = 203, .b = 0, .a = alpha };
        var buf: [32]u8 = undefined;
        const text = std.fmt.bufPrintZ(&buf, "+{d}", .{p.points}) catch "+?";
        raylib.DrawText(text.ptr, @intFromFloat(p.x), @intFromFloat(draw_y), POPUP_FONT_SIZE, color);
    }
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

test "getWaveConfig returns correct values for wave 1" {
    const cfg = getWaveConfig(1);
    try std.testing.expectEqual(@as(u32, 15), cfg.target_wpm);
    try std.testing.expectApproxEqAbs(@as(f32, 4.80), cfg.spawn_delay, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), cfg.fall_speed, 0.01);
    try std.testing.expectEqual(@as(u32, 5), cfg.pool_size);
}

test "getWaveConfig returns correct values for wave 15" {
    const cfg = getWaveConfig(15);
    try std.testing.expectEqual(@as(u32, 100), cfg.target_wpm);
    try std.testing.expectApproxEqAbs(@as(f32, 0.72), cfg.spawn_delay, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.9), cfg.fall_speed, 0.01);
    try std.testing.expectEqual(@as(u32, 33), cfg.pool_size);
}

test "wave completes when kills equals pool size" {
    const cfg = getWaveConfig(1);
    const kills: u32 = cfg.pool_size;
    const spawned: u32 = cfg.pool_size;
    try std.testing.expect(kills >= cfg.pool_size and spawned >= cfg.pool_size);

    const partial_kills: u32 = cfg.pool_size - 1;
    try std.testing.expect(!(partial_kills >= cfg.pool_size and spawned >= cfg.pool_size));
}

test "getWaveConfig scales correctly for wave 16+" {
    const cfg16 = getWaveConfig(16);
    try std.testing.expectEqual(@as(u32, 110), cfg16.target_wpm);
    try std.testing.expectApproxEqAbs(@as(f32, 0.66), cfg16.spawn_delay, 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), cfg16.fall_speed, 0.01);
    try std.testing.expectEqual(@as(u32, 35), cfg16.pool_size);

    const cfg20 = getWaveConfig(20);
    try std.testing.expectEqual(@as(u32, 43), cfg20.pool_size);

    const cfg100 = getWaveConfig(100);
    try std.testing.expectEqual(@as(u32, 203), cfg100.pool_size);
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

test "boss wave detection" {
    try std.testing.expect(isBossWave(5));
    try std.testing.expect(isBossWave(10));
    try std.testing.expect(isBossWave(15));
    try std.testing.expect(isBossWave(20));
    try std.testing.expect(!isBossWave(1));
    try std.testing.expect(!isBossWave(4));
    try std.testing.expect(!isBossWave(6));
    try std.testing.expect(!isBossWave(14));
}

test "boss spawn threshold calculation" {
    const cfg5 = getWaveConfig(5);
    try std.testing.expectEqual(@as(u32, 13), cfg5.pool_size);
    try std.testing.expectEqual(@as(u32, 7), (cfg5.pool_size + 1) / 2);

    const cfg10 = getWaveConfig(10);
    try std.testing.expectEqual(@as(u32, 23), cfg10.pool_size);
    try std.testing.expectEqual(@as(u32, 12), (cfg10.pool_size + 1) / 2);

    const cfg20 = getWaveConfig(20);
    try std.testing.expectEqual(@as(u32, 43), cfg20.pool_size);
    try std.testing.expectEqual(@as(u32, 22), (cfg20.pool_size + 1) / 2);
}

test "getCurrentMaxInput returns correct limits" {
    const saved_boss = boss;
    defer boss = saved_boss;

    boss = null;
    try std.testing.expectEqual(@as(usize, MAX_INPUT_CHARS), getCurrentMaxInput());

    var dummy = Zombie{ .x = 0, .y = 0, .speed = 0, .name = "test", .is_active = true, .frame = 0, .animation_timer = 0 };
    boss = &dummy;
    try std.testing.expectEqual(@as(usize, MAX_BOSS_INPUT_CHARS), getCurrentMaxInput());
}

test "boss phrase validity" {
    for (BossPhrases) |phrase| {
        var len: usize = 0;
        while (phrase[len] != '\x00') len += 1;
        try std.testing.expect(len > 0);
        try std.testing.expect(len <= 35);
        for (0..len) |i| {
            const c = phrase[i];
            try std.testing.expect((c >= 97 and c <= 122) or c == 32);
        }
    }
}

test "input buffer capacity for boss phrases" {
    try std.testing.expect(name.len >= MAX_BOSS_INPUT_CHARS + 1);
}

test "wave completion requires boss kill on boss waves" {
    const saved_boss = boss;
    const saved_spawned = boss_spawned_this_wave;
    defer {
        boss = saved_boss;
        boss_spawned_this_wave = saved_spawned;
    }

    const boss_wave: u32 = 5;
    const non_boss_wave: u32 = 6;
    const cfg = getWaveConfig(boss_wave);
    const kills = cfg.pool_size;
    const spawned = cfg.pool_size;
    const pool_done = kills >= cfg.pool_size and spawned >= cfg.pool_size;

    const computeBossDone = struct {
        fn f(wave: u32) bool {
            return !isBossWave(wave) or (boss == null and boss_spawned_this_wave);
        }
    }.f;

    // Boss wave: pool done but boss still alive → must NOT complete
    var dummy = Zombie{ .x = 0, .y = 0, .speed = 0, .name = "test", .is_active = true, .frame = 0, .animation_timer = 0 };
    boss = &dummy;
    boss_spawned_this_wave = true;
    try std.testing.expect(!(pool_done and computeBossDone(boss_wave)));

    // Boss wave: pool done and boss killed → must complete
    boss = null;
    boss_spawned_this_wave = true;
    try std.testing.expect(pool_done and computeBossDone(boss_wave));

    // Non-boss wave: pool done → must complete regardless of boss state
    try std.testing.expect(pool_done and computeBossDone(non_boss_wave));
}

test "calculateScore reference cases" {
    try std.testing.expectEqual(@as(u64, 40), calculateScore(4, 0, false, 0));
    try std.testing.expectEqual(@as(u64, 200), calculateScore(4, 0, false, 20));
    try std.testing.expectEqual(@as(u64, 138), calculateScore(4, 440, false, 0));
    try std.testing.expectEqual(@as(u64, 2313), calculateScore(19, 300, true, 10));
}

test "getComboMultiplier tier boundaries" {
    try std.testing.expectEqual(@as(u64, 1), getComboMultiplier(0));
    try std.testing.expectEqual(@as(u64, 1), getComboMultiplier(4));
    try std.testing.expectEqual(@as(u64, 2), getComboMultiplier(5));
    try std.testing.expectEqual(@as(u64, 2), getComboMultiplier(9));
    try std.testing.expectEqual(@as(u64, 3), getComboMultiplier(10));
    try std.testing.expectEqual(@as(u64, 3), getComboMultiplier(14));
    try std.testing.expectEqual(@as(u64, 4), getComboMultiplier(15));
    try std.testing.expectEqual(@as(u64, 4), getComboMultiplier(19));
    try std.testing.expectEqual(@as(u64, 5), getComboMultiplier(20));
    try std.testing.expectEqual(@as(u64, 5), getComboMultiplier(100));
}

test "typedMatchesAnyEnemy mismatch detection" {
    const saved_letter_count = letter_count;
    const saved_name = name;
    const saved_boss = boss;
    const saved_boss_phrase_len = boss_phrase_len;
    const saved_zombies = zombies;
    defer {
        letter_count = saved_letter_count;
        name = saved_name;
        boss = saved_boss;
        boss_phrase_len = saved_boss_phrase_len;
        zombies = saved_zombies;
    }

    for (&zombies) |*slot| slot.* = null;
    boss = null;
    boss_phrase_len = 0;

    letter_count = 0;
    try std.testing.expect(typedMatchesAnyEnemy());

    name[0] = 'Z';
    name[1] = 'Z';
    name[2] = 'Z';
    name[3] = '\x00';
    letter_count = 3;
    try std.testing.expect(!typedMatchesAnyEnemy());
}

test "popup pool circular recycling" {
    const saved_popups = popups;
    const saved_next = popup_next;
    defer {
        popups = saved_popups;
        popup_next = saved_next;
    }

    popup_next = 0;
    for (&popups) |*p| p.active = false;

    var i: usize = 0;
    while (i < 33) : (i += 1) {
        spawnPopup(@floatFromInt(i), @floatFromInt(i), @intCast(i + 1));
    }

    try std.testing.expectEqual(@as(usize, 1), popup_next);
    try std.testing.expect(popups[0].active);
    try std.testing.expectEqual(@as(u64, 33), popups[0].points);
}

test "resetScoreState clears score, combo, and popups" {
    const saved_score = score;
    const saved_combo = combo_count;
    const saved_next = popup_next;
    const saved_popups = popups;
    defer {
        score = saved_score;
        combo_count = saved_combo;
        popup_next = saved_next;
        popups = saved_popups;
    }

    score = 999;
    combo_count = 10;
    popup_next = 5;
    popups[0].active = true;

    resetScoreState();

    try std.testing.expectEqual(@as(u64, 0), score);
    try std.testing.expectEqual(@as(u32, 0), combo_count);
    try std.testing.expectEqual(@as(usize, 0), popup_next);
    try std.testing.expect(!popups[0].active);
}

test "circular buffer wraps correctly" {
    const saved_buffer = wpm_buffer;
    const saved_head = wpm_buffer_head;
    const saved_count = wpm_buffer_count;
    defer {
        wpm_buffer = saved_buffer;
        wpm_buffer_head = saved_head;
        wpm_buffer_count = saved_count;
    }

    wpm_buffer = [_]f32{0} ** WPM_BUFFER_SIZE;
    wpm_buffer_head = 0;
    wpm_buffer_count = 0;

    var i: usize = 0;
    while (i < WPM_BUFFER_SIZE + 10) : (i += 1) {
        recordCorrectTimestamp(@floatFromInt(i));
    }

    try std.testing.expectEqual(@as(usize, 10), wpm_buffer_head);
    try std.testing.expectEqual(WPM_BUFFER_SIZE, wpm_buffer_count);
}

test "resetMetricsState clears all metrics" {
    const saved_buffer = wpm_buffer;
    const saved_head = wpm_buffer_head;
    const saved_count = wpm_buffer_count;
    const saved_correct = correct_chars;
    const saved_wrong = wrong_chars;
    const saved_elapsed = elapsed_time;
    const saved_wpm = displayed_wpm;
    const saved_acc = displayed_accuracy;
    defer {
        wpm_buffer = saved_buffer;
        wpm_buffer_head = saved_head;
        wpm_buffer_count = saved_count;
        correct_chars = saved_correct;
        wrong_chars = saved_wrong;
        elapsed_time = saved_elapsed;
        displayed_wpm = saved_wpm;
        displayed_accuracy = saved_acc;
    }

    wpm_buffer_head = 42;
    wpm_buffer_count = 100;
    correct_chars = 50;
    wrong_chars = 10;
    elapsed_time = 30.0;
    displayed_wpm = 72.0;
    displayed_accuracy = 85.0;

    resetMetricsState();

    try std.testing.expectEqual(@as(usize, 0), wpm_buffer_head);
    try std.testing.expectEqual(@as(usize, 0), wpm_buffer_count);
    try std.testing.expectEqual(@as(u32, 0), correct_chars);
    try std.testing.expectEqual(@as(u32, 0), wrong_chars);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), elapsed_time, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), displayed_wpm, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), displayed_accuracy, 0.001);
}

test "WPM sliding window — 60 chars in 10 seconds" {
    const saved_buffer = wpm_buffer;
    const saved_head = wpm_buffer_head;
    const saved_count = wpm_buffer_count;
    const saved_correct = correct_chars;
    const saved_elapsed = elapsed_time;
    defer {
        wpm_buffer = saved_buffer;
        wpm_buffer_head = saved_head;
        wpm_buffer_count = saved_count;
        correct_chars = saved_correct;
        elapsed_time = saved_elapsed;
    }

    wpm_buffer = [_]f32{0} ** WPM_BUFFER_SIZE;
    wpm_buffer_head = 0;
    wpm_buffer_count = 0;
    correct_chars = 60;
    elapsed_time = 15.0;

    var i: usize = 0;
    while (i < 60) : (i += 1) {
        recordCorrectTimestamp(5.0 + @as(f32, @floatFromInt(i)) * (10.0 / 60.0));
    }

    const result = calculateTargetWpm();
    try std.testing.expectApproxEqAbs(@as(f32, 72.0), result, 0.1);
}

test "WPM early game — 12 chars in 5 seconds" {
    const saved_correct = correct_chars;
    const saved_elapsed = elapsed_time;
    defer {
        correct_chars = saved_correct;
        elapsed_time = saved_elapsed;
    }

    correct_chars = 12;
    elapsed_time = 5.0;

    const result = calculateTargetWpm();
    try std.testing.expectApproxEqAbs(@as(f32, 28.8), result, 0.1);
}

test "WPM zero input" {
    const saved_buffer = wpm_buffer;
    const saved_head = wpm_buffer_head;
    const saved_count = wpm_buffer_count;
    const saved_correct = correct_chars;
    const saved_elapsed = elapsed_time;
    defer {
        wpm_buffer = saved_buffer;
        wpm_buffer_head = saved_head;
        wpm_buffer_count = saved_count;
        correct_chars = saved_correct;
        elapsed_time = saved_elapsed;
    }

    wpm_buffer = [_]f32{0} ** WPM_BUFFER_SIZE;
    wpm_buffer_head = 0;
    wpm_buffer_count = 0;
    correct_chars = 0;
    elapsed_time = 0.0;

    const result = calculateTargetWpm();
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), result, 0.001);
}

test "accuracy — 100 correct 4 incorrect" {
    const saved_correct = correct_chars;
    const saved_wrong = wrong_chars;
    defer {
        correct_chars = saved_correct;
        wrong_chars = saved_wrong;
    }

    correct_chars = 100;
    wrong_chars = 4;

    const result = calculateTargetAccuracy();
    try std.testing.expectApproxEqAbs(@as(f32, 96.15), result, 0.1);
}

test "accuracy zero input returns 100" {
    const saved_correct = correct_chars;
    const saved_wrong = wrong_chars;
    defer {
        correct_chars = saved_correct;
        wrong_chars = saved_wrong;
    }

    correct_chars = 0;
    wrong_chars = 0;

    const result = calculateTargetAccuracy();
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), result, 0.001);
}

test "smoothing convergence toward target WPM" {
    const saved_wpm = displayed_wpm;
    defer displayed_wpm = saved_wpm;

    displayed_wpm = 0.0;
    const target: f32 = 72.0;

    displayed_wpm += SMOOTHING_FACTOR * (target - displayed_wpm);
    try std.testing.expectApproxEqAbs(@as(f32, 14.4), displayed_wpm, 0.01);

    displayed_wpm += SMOOTHING_FACTOR * (target - displayed_wpm);
    try std.testing.expectApproxEqAbs(@as(f32, 25.92), displayed_wpm, 0.01);
}
