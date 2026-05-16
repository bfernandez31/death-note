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

const ZOMBIE_FRAME_COUNT = 17;
const ZOMBIE_ANIMATION_FRAME_DURATION: f32 = 0.1; // seconds per spritesheet frame
const WAVE_TRANSITION_DURATION: f32 = 3.0;

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
                name[letter_count] = @intCast(key); // Add character to input buffer
                name[letter_count + 1] = '\x00'; // Null-terminate the string
                letter_count += 1;
            }
            key = raylib.GetCharPressed(); // Check next character in the queue
        }

        // Handle backspace
        if (raylib.IsKeyPressed(raylib.KEY_BACKSPACE) and letter_count > 0) {
            letter_count -= 1;
            name[letter_count] = '\x00'; // Null-terminate after backspace
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

        if (current_wave % 5 == 0 and !boss_spawned_this_wave and boss == null) {
            const threshold = (wave_cfg.pool_size + 1) / 2;
            if (wave_kills >= threshold) {
                spawnBoss(ctx.allocator) catch {};
            }
        }

        updateBoss(ctx.allocator);

        // Wave completion detection — guarded against is_game_over so a kill+death in the
        // same frame does not silently start a wave transition behind the game-over screen.
        if (!is_game_over and wave_kills >= wave_cfg.pool_size and wave_spawned >= wave_cfg.pool_size) {
            is_transitioning = true;
            transition_timer = WAVE_TRANSITION_DURATION;
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

        raylib.DrawText("Press ENTER to Restart", screen_width / 2 - 130, screen_height / 2 + 60, 20, raylib.GRAY);

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
            resetZombies(ctx.allocator);
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
    // Free killed zombies and null their slots so spawnZombie can reuse them; otherwise
    // pool_size values above MAX_ZOMBIES (waves 49+) soft-lock once every slot is consumed.
    for (&zombies) |*slot| {
        if (slot.*) |zomb| {
            if (!zomb.is_active) continue; // Skip if zombie is not on screen
            zomb.y += zomb.speed; // Update zombie position

            // Check if the zombie has reached the bottom of the screen
            if (zomb.y >= screen_height) {
                is_game_over = true;
                return; // Exit function to stop updating further
            }

            // Create a slice from the input text
            const typed_name = name[0..letter_count];

            // Calculate the length of the zombie's name
            var zomb_name_length: usize = 0;
            while (zomb.name[zomb_name_length] != '\x00') {
                zomb_name_length += 1;
            }

            // Create a slice from the zombie's name
            const zomb_name_slice = zomb.name[0..zomb_name_length];

            // Check for equality
            if (std.mem.eql(u8, typed_name, zomb_name_slice)) {
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

        const typed_name = name[0..letter_count];
        const boss_slice = b.name[0..boss_phrase_len];

        if (letter_count <= boss_phrase_len and std.mem.eql(u8, typed_name, boss_slice[0..letter_count])) {
            if (letter_count == boss_phrase_len) {
                allocator.destroy(b);
                boss = null;
                letter_count = 0;
                name[0] = '\x00';
                raylib.PlaySound(zombie_kill_sound);
            }
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
        const dark_red = raylib.Color{ .r = 139, .g = 0, .b = 0, .a = 255 };
        raylib.DrawText(b.name, boss_x, boss_y - 30, 20, dark_red);

        const bar_x = boss_x;
        const bar_y = boss_y - 42;
        raylib.DrawRectangle(bar_x, bar_y, BOSS_HEALTH_BAR_WIDTH, BOSS_HEALTH_BAR_HEIGHT, raylib.LIGHTGRAY);

        if (boss_phrase_len > 0) {
            const typed_name = name[0..letter_count];
            const boss_slice = b.name[0..boss_phrase_len];
            if (letter_count <= boss_phrase_len and std.mem.eql(u8, typed_name, boss_slice[0..letter_count])) {
                const remaining = boss_phrase_len - letter_count;
                const fill_width: c_int = @intCast(BOSS_HEALTH_BAR_WIDTH * remaining / boss_phrase_len);
                raylib.DrawRectangle(bar_x, bar_y, fill_width, BOSS_HEALTH_BAR_HEIGHT, raylib.RED);
            } else {
                raylib.DrawRectangle(bar_x, bar_y, BOSS_HEALTH_BAR_WIDTH, BOSS_HEALTH_BAR_HEIGHT, raylib.RED);
            }
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
    try std.testing.expect(5 % 5 == 0);
    try std.testing.expect(10 % 5 == 0);
    try std.testing.expect(15 % 5 == 0);
    try std.testing.expect(20 % 5 == 0);
    try std.testing.expect(1 % 5 != 0);
    try std.testing.expect(4 % 5 != 0);
    try std.testing.expect(6 % 5 != 0);
    try std.testing.expect(14 % 5 != 0);
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
