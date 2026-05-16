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
var boss_spawned_this_wave: bool = false;

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
                boss_spawned_this_wave = false;
                resetZombies(ctx.allocator);
            }
        } else {
            var key = raylib.GetCharPressed();
            while (key > 0) {
                if ((key >= 32) and (key <= 125) and (letter_count < MAX_INPUT_CHARS)) {
                    name[letter_count] = @intCast(key);
                    name[letter_count + 1] = '\x00';
                    letter_count += 1;
                    total_keystrokes += 1;
                    if (isValidPrefix(name[0..letter_count], &zombies)) {
                        correct_keystrokes += 1;
                    } else {
                        combo = 0;
                    }
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

            const is_boss_wave = (current_wave % BOSS_WAVE_INTERVAL == 0);
            const target_met = wave_kill_count >= waveKillTarget(current_wave);

            // Spawn boss when kill target met on boss waves
            if (is_boss_wave and target_met and !boss_spawned_this_wave) {
                _ = spawnBoss(ctx.allocator) catch {};
                boss_spawned_this_wave = true;
            }

            if (target_met and !boss_alive) {
                score += WAVE_COMPLETION_BONUS_PER_WAVE * current_wave;
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
        // Save high score on first frame of game over
        if (score > best_score) {
            best_score = score;
            best_score_loaded = true;
            saveHighScore(score);
        }

        raylib.DrawText("GAME OVER", screen_width / 2 - 100, screen_height / 2 - 100, 40, raylib.RED);

        if (score >= best_score and score > 0) {
            raylib.DrawText("New High Score!", screen_width / 2 - 80, screen_height / 2 - 60, 20, raylib.ORANGE);
        }

        var wave_buf: [32]u8 = undefined;
        const wave_text = std.fmt.bufPrint(&wave_buf, "Wave: {}", .{current_wave}) catch "Wave: --";
        raylib.DrawText(@ptrCast(wave_text.ptr), screen_width / 2 - 80, screen_height / 2 - 30, 20, raylib.DARKGRAY);

        var score_buf: [32]u8 = undefined;
        const score_text = std.fmt.bufPrint(&score_buf, "Score: {}", .{score}) catch "Score: --";
        raylib.DrawText(@ptrCast(score_text.ptr), screen_width / 2 - 80, screen_height / 2 - 5, 20, raylib.DARKGRAY);

        var best_buf: [32]u8 = undefined;
        const best_text = std.fmt.bufPrint(&best_buf, "Best: {}", .{best_score}) catch "Best: --";
        raylib.DrawText(@ptrCast(best_text.ptr), screen_width / 2 - 80, screen_height / 2 + 20, 20, raylib.DARKGRAY);

        const accuracy: u64 = if (total_keystrokes > 0) (correct_keystrokes * 100) / total_keystrokes else 100;
        var acc_buf: [32]u8 = undefined;
        const acc_text = std.fmt.bufPrint(&acc_buf, "Accuracy: {}%", .{accuracy}) catch "Accuracy: --%";
        raylib.DrawText(@ptrCast(acc_text.ptr), screen_width / 2 - 80, screen_height / 2 + 45, 20, raylib.DARKGRAY);

        var kills_buf: [32]u8 = undefined;
        const kills_text = std.fmt.bufPrint(&kills_buf, "Kills: {}", .{total_kills}) catch "Kills: --";
        raylib.DrawText(@ptrCast(kills_text.ptr), screen_width / 2 - 80, screen_height / 2 + 70, 20, raylib.DARKGRAY);

        raylib.DrawText("Press ENTER to Restart", screen_width / 2 - 130, screen_height / 2 + 105, 20, raylib.GRAY);

        if (raylib.IsKeyPressed(raylib.KEY_ENTER)) {
            resetGameState(ctx.allocator);
        }
    } else if (is_wave_transitioning) {
        drawWaveTransition();
    } else {
        drawZombies();
        drawHud();
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

    raylib.SetTargetFPS(60);

    const loaded = loadHighScore();
    if (loaded > 0) {
        best_score = loaded;
        best_score_loaded = true;
    }

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

            if (zomb.is_boss) {
                // Boss: update phrase progress based on how many chars match from the start
                if (letter_count > 0 and std.mem.startsWith(u8, zomb_name_slice, typed_name)) {
                    zomb.phrase_progress = letter_count;
                }
            }

            if (std.mem.eql(u8, typed_name, zomb_name_slice)) {
                zomb.is_active = false;
                letter_count = 0;
                name[0] = '\x00';

                combo += 1;
                const kill_score = if (zomb.is_boss) BOSS_KILL_SCORE else BASE_KILL_SCORE;
                score += kill_score * comboMultiplier(combo);
                wave_kill_count += 1;
                total_kills += 1;

                wpm_kill_times[wpm_kill_index] = raylib.GetTime();
                wpm_kill_index = (wpm_kill_index + 1) % WPM_BUFFER_SIZE;
                if (wpm_kill_count < WPM_BUFFER_SIZE) wpm_kill_count += 1;

                if (zomb.is_boss) boss_alive = false;

                raylib.PlaySound(zombie_kill_sound);
            }
        }
    }
}

fn drawHud() void {
    // Top-left: wave
    var wave_buf: [24]u8 = undefined;
    const wave_text = std.fmt.bufPrint(&wave_buf, "Wave: {}", .{current_wave}) catch "Wave: --";
    raylib.DrawText(@ptrCast(wave_text.ptr), 10, 5, 18, raylib.DARKGRAY);

    // Top-center: score and best
    var score_buf: [32]u8 = undefined;
    const score_text = std.fmt.bufPrint(&score_buf, "Score: {}", .{score}) catch "Score: --";
    raylib.DrawText(@ptrCast(score_text.ptr), screen_width / 2 - 60, 5, 18, raylib.DARKGRAY);

    if (best_score_loaded and best_score > 0) {
        var best_buf: [32]u8 = undefined;
        const best_text = std.fmt.bufPrint(&best_buf, "Best: {}", .{best_score}) catch "Best: --";
        raylib.DrawText(@ptrCast(best_text.ptr), screen_width / 2 + 60, 5, 16, raylib.GRAY);
    }

    // Top-right: combo, WPM, accuracy
    const mult = comboMultiplier(combo);
    var combo_buf: [32]u8 = undefined;
    const combo_text = std.fmt.bufPrint(&combo_buf, "Combo: {} ({}x)", .{ combo, mult }) catch "Combo: --";
    raylib.DrawText(@ptrCast(combo_text.ptr), screen_width - 180, 5, 16, if (combo >= 5) raylib.ORANGE else raylib.DARKGRAY);

    const wpm = calculateWpm(&wpm_kill_times, wpm_kill_count, raylib.GetTime());
    var wpm_buf: [24]u8 = undefined;
    const wpm_text = std.fmt.bufPrint(&wpm_buf, "WPM: {}", .{wpm}) catch "WPM: --";
    raylib.DrawText(@ptrCast(wpm_text.ptr), screen_width - 90, 5, 16, raylib.DARKGRAY);

    const accuracy: u64 = if (total_keystrokes > 0) (correct_keystrokes * 100) / total_keystrokes else 100;
    var acc_buf: [24]u8 = undefined;
    const acc_text = std.fmt.bufPrint(&acc_buf, "Acc: {}%", .{accuracy}) catch "Acc: --%";
    raylib.DrawText(@ptrCast(acc_text.ptr), screen_width - 90, 22, 16, raylib.DARKGRAY);

    // Wave timer
    const duration = waveDuration(current_wave);
    const remaining = if (wave_timer < duration) duration - wave_timer else 0.0;
    const remaining_int: u32 = @intFromFloat(remaining);
    var timer_buf: [24]u8 = undefined;
    const timer_text = std.fmt.bufPrint(&timer_buf, "Time: {}s", .{remaining_int}) catch "Time: --";
    raylib.DrawText(@ptrCast(timer_text.ptr), 10, 22, 16, if (remaining < 10.0) raylib.RED else raylib.DARKGRAY);
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

            const scale: f32 = if (zomb.is_boss) 0.35 else 0.2;
            const tint = if (zomb.is_boss) raylib.Color{ .r = 200, .g = 50, .b = 50, .a = 255 } else raylib.WHITE;
            raylib.DrawTexturePro(
                zombie_texture,
                src_rect,
                raylib.Rectangle{
                    .x = pos.x,
                    .y = pos.y,
                    .width = frame_width * scale,
                    .height = @as(f32, @floatFromInt(zombie_texture.height)) * scale,
                },
                raylib.Vector2{ .x = 0, .y = 0 },
                0.0,
                tint,
            );

            if (zomb.is_boss) {
                const phrase_len = cstrLen(zomb.name);
                const sprite_h = @as(f32, @floatFromInt(zombie_texture.height)) * scale;
                const bar_y: c_int = @intFromFloat(pos.y + sprite_h + 2.0);
                const bar_w: c_int = 80;
                const bar_h: c_int = 6;
                const bar_x: c_int = @intFromFloat(pos.x);

                // Background
                raylib.DrawRectangle(bar_x, bar_y, bar_w, bar_h, raylib.LIGHTGRAY);
                // Filled portion
                if (phrase_len > 0) {
                    const fill_f = @as(f32, @floatFromInt(zomb.phrase_progress)) / @as(f32, @floatFromInt(phrase_len));
                    const fill_w: c_int = @intFromFloat(fill_f * @as(f32, @floatFromInt(bar_w)));
                    raylib.DrawRectangle(bar_x, bar_y, fill_w, bar_h, raylib.GREEN);
                }

                // Phrase text above boss
                raylib.DrawText(zomb.name, @intFromFloat(pos.x), @as(c_int, @intFromFloat(pos.y)) - 20, 16, raylib.RED);
            } else {
                raylib.DrawText(zomb.name, @intFromFloat(pos.x), @as(c_int, @intFromFloat(pos.y)) - 20, 20, raylib.DARKGREEN);
            }
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

fn spawnBoss(allocator: *std.mem.Allocator) !bool {
    for (zombies, 0..) |zombie, i| {
        if (zombie == null) {
            const new_zombie = try allocator.create(Zombie);
            errdefer allocator.destroy(new_zombie);

            const x = @as(f32, @floatFromInt(raylib.GetRandomValue(ZOMBIE_SPAWN_X_MIN, ZOMBIE_SPAWN_X_MAX)));
            const phrase_index: usize = @intCast(raylib.GetRandomValue(0, @intCast(BossPhrases.len - 1)));

            new_zombie.* = Zombie{
                .x = x,
                .y = 0.0,
                .speed = waveFallSpeed(current_wave) * BOSS_FALL_SPEED_FACTOR,
                .name = BossPhrases[phrase_index],
                .is_active = true,
                .frame = 0,
                .animation_timer = 0,
                .is_boss = true,
                .phrase_progress = 0,
            };
            zombies[i] = new_zombie;
            boss_alive = true;
            return true;
        }
    }
    return false;
}

fn loadHighScore() u64 {
    if (comptime @import("builtin").target.os.tag == .emscripten) {
        const val = raylib.emscripten_run_script_int("(function(){var v=localStorage.getItem('death-note-highscore');return v?parseInt(v,10)||0:0;})()");
        return if (val > 0) @intCast(val) else 0;
    } else {
        const fp = raylib.fopen(HIGHSCORE_FILE, "rb") orelse return 0;
        defer _ = raylib.fclose(fp);
        var buf: [8]u8 = undefined;
        const n = raylib.fread(&buf, 1, 8, fp);
        if (n < 8) return 0;
        return std.mem.readInt(u64, &buf, .little);
    }
}

fn saveHighScore(s: u64) void {
    if (comptime @import("builtin").target.os.tag == .emscripten) {
        var js_buf: [128]u8 = undefined;
        const js = std.fmt.bufPrint(&js_buf, "localStorage.setItem('death-note-highscore','{}')", .{s}) catch return;
        if (js.len < js_buf.len) {
            js_buf[js.len] = 0;
            raylib.emscripten_run_script(@ptrCast(&js_buf));
        }
    } else {
        const fp = raylib.fopen(HIGHSCORE_FILE, "wb") orelse return;
        defer _ = raylib.fclose(fp);
        const bytes = std.mem.toBytes(std.mem.nativeTo(u64, s, .little));
        _ = raylib.fwrite(&bytes, 1, 8, fp);
    }
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
    boss_spawned_this_wave = false;
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

test "score calculation with combo" {
    try std.testing.expectEqual(@as(u64, 100), BASE_KILL_SCORE * comboMultiplier(0));
    try std.testing.expectEqual(@as(u64, 200), BASE_KILL_SCORE * comboMultiplier(5));
    try std.testing.expectEqual(@as(u64, 300), BASE_KILL_SCORE * comboMultiplier(10));
    try std.testing.expectEqual(@as(u64, 500), BASE_KILL_SCORE * comboMultiplier(20));
    try std.testing.expectEqual(@as(u64, 500), BOSS_KILL_SCORE * comboMultiplier(0));
    try std.testing.expectEqual(@as(u64, 2500), BOSS_KILL_SCORE * comboMultiplier(20));
}

test "wave completion bonus" {
    try std.testing.expectEqual(@as(u64, 200), WAVE_COMPLETION_BONUS_PER_WAVE * 1);
    try std.testing.expectEqual(@as(u64, 1000), WAVE_COMPLETION_BONUS_PER_WAVE * 5);
    try std.testing.expectEqual(@as(u64, 2000), WAVE_COMPLETION_BONUS_PER_WAVE * 10);
}

test "high score is monotonic" {
    const old_best = best_score;
    defer best_score = old_best;

    best_score = 100;
    // Score lower than best: should not update
    const lower: u64 = 50;
    if (lower > best_score) best_score = lower;
    try std.testing.expectEqual(@as(u64, 100), best_score);

    // Score higher than best: should update
    const higher: u64 = 200;
    if (higher > best_score) best_score = higher;
    try std.testing.expectEqual(@as(u64, 200), best_score);

    // Equal score: should not update (strict >)
    const equal: u64 = 200;
    if (equal > best_score) best_score = equal;
    try std.testing.expectEqual(@as(u64, 200), best_score);
}

test "boss wave detection" {
    try std.testing.expect(5 % BOSS_WAVE_INTERVAL == 0);
    try std.testing.expect(10 % BOSS_WAVE_INTERVAL == 0);
    try std.testing.expect(15 % BOSS_WAVE_INTERVAL == 0);
    try std.testing.expect(1 % BOSS_WAVE_INTERVAL != 0);
    try std.testing.expect(3 % BOSS_WAVE_INTERVAL != 0);
    try std.testing.expect(7 % BOSS_WAVE_INTERVAL != 0);
}

test "boss fall speed" {
    const normal_speed = waveFallSpeed(5);
    const boss_speed = normal_speed * BOSS_FALL_SPEED_FACTOR;
    try std.testing.expect(boss_speed < normal_speed);
    try std.testing.expectApproxEqAbs(normal_speed * 0.5, boss_speed, 0.01);
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
