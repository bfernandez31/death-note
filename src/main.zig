const std = @import("std");
const raylib = @import("raylib.zig").c;

// Importing the list of zombie names
const ZombieNames = @import("zombie_names.zig").ZombieNames;

const MAX_ZOMBIES = 100;
const MAX_INPUT_CHARS = 9;

const ZOMBIE_FRAME_COUNT = 17;

const BUFFER_SIZE = 16;
const WEB_CANVAS_ID = "canvas";
const WEB_PRELOAD_ROOT = "assets/";
// Input buffer for characters
var name = [_]u8{0} ** (MAX_INPUT_CHARS + 1);
var letter_count: usize = 0;

var input_text: [MAX_INPUT_CHARS]u8 = undefined;
var input_length: usize = 0;

// Delay settings
const spawn_delay: f32 = 3.0; // Delay in seconds between spawns
var spawn_timer: f32 = 0.0; // Timer to track time since last spawn

var is_game_over: bool = false;

// Define the Zombie structure
const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,
    name: [*:0]const u8,
    is_active: bool,
    frame: f32, // Current animation frame
    animationTimer: f32,
};

// Array to hold zombie pointers
var zombies: [MAX_ZOMBIES]?*Zombie = undefined;

var zombie_texture: raylib.Texture2D = undefined;
var zombie_kill_sound: raylib.Sound = undefined;

const screen_width = 800;
const screen_height = 450;

// Per-frame mutable context threaded through the game loop (native and emscripten paths)
const FrameContext = struct {
    allocator: *std.mem.Allocator,
    text_box: raylib.Rectangle,
    mouse_on_text: bool,
    frames_counter: usize,
};

fn frame(ctx: *FrameContext) void {
    if (!is_game_over) {
        // Update
        if (raylib.CheckCollisionPointRec(raylib.GetMousePosition(), ctx.text_box)) {
            ctx.mouse_on_text = true;
            raylib.SetMouseCursor(raylib.MOUSE_CURSOR_IBEAM);

            var key = raylib.GetCharPressed();

            // Check if more characters have been pressed on the same frame
            while (key > 0) {
                if ((key >= 32) and (key <= 125) and (letter_count < MAX_INPUT_CHARS)) {
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
        } else {
            ctx.mouse_on_text = false;
            raylib.SetMouseCursor(raylib.MOUSE_CURSOR_DEFAULT);
        }

        if (ctx.mouse_on_text) {
            ctx.frames_counter += 1;
        } else {
            ctx.frames_counter = 0;
        }

        // Update spawn timer
        spawn_timer += raylib.GetFrameTime(); // Increment timer by the time elapsed since last frame

        // Check if enough time has passed to spawn a new zombie
        if (spawn_timer >= spawn_delay) {
            spawnZombie(ctx.allocator) catch {}; // Ignore allocation failure — page_allocator is nearly infallible
            spawn_timer = 0.0; // Reset the spawn timer
        }

        // Update zombies
        updateZombies();
    }
    // Draw
    raylib.BeginDrawing();
    defer raylib.EndDrawing();

    raylib.ClearBackground(raylib.RAYWHITE);

    raylib.DrawRectangleRec(ctx.text_box, raylib.LIGHTGRAY);
    if (ctx.mouse_on_text) {
        raylib.DrawRectangleLines(@intFromFloat(ctx.text_box.x), @intFromFloat(ctx.text_box.y), @intFromFloat(ctx.text_box.width), @intFromFloat(ctx.text_box.height), raylib.RED);
    } else {
        raylib.DrawRectangleLines(@intFromFloat(ctx.text_box.x), @intFromFloat(ctx.text_box.y), @intFromFloat(ctx.text_box.width), @intFromFloat(ctx.text_box.height), raylib.DARKGRAY);
    }

    raylib.DrawText(&name, @as(c_int, @intFromFloat(ctx.text_box.x)) + 5, @as(c_int, @intFromFloat(ctx.text_box.y)) + 8, 40, raylib.MAROON);

    if (is_game_over) {
        // Display "Game Over" message
        raylib.DrawText("GAME OVER", screen_width / 2 - 100, screen_height / 2 - 20, 40, raylib.RED);
        raylib.DrawText("Press ENTER to Restart", screen_width / 2 - 130, screen_height / 2 + 20, 20, raylib.GRAY);

        // Restart game if Enter is pressed
        if (raylib.IsKeyPressed(raylib.KEY_ENTER)) {
            is_game_over = false;
            letter_count = 0;
            name[letter_count] = '\x00';
            spawn_timer = 0.0;

            // Reset all zombies
            resetZombies(ctx.allocator);
        }
    } else {
        // Draw zombies if the game is not over
        drawZombies();
    }
    // Draw blinking underscore char
    if (ctx.mouse_on_text and letter_count < MAX_INPUT_CHARS and ((ctx.frames_counter / 20) % 2) == 0) {
        raylib.DrawText("_", @as(c_int, @intFromFloat(ctx.text_box.x)) + 8 + raylib.MeasureText(&name, 40), @as(c_int, @intFromFloat(ctx.text_box.y)) + 12, 40, raylib.MAROON);
    }

    if (ctx.mouse_on_text and letter_count >= MAX_INPUT_CHARS) {
        raylib.DrawText("Press BACKSPACE to delete chars...", 230, 300, 20, raylib.GRAY);
    }
}

// Emscripten C-callback trampoline; arg carries the FrameContext pointer
fn frame_c_callback(arg: ?*anyopaque) callconv(.C) void {
    if (arg) |raw| {
        const ctx: *FrameContext = @ptrCast(@alignCast(raw));
        frame(ctx);
    }
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

    var allocator = std.heap.page_allocator;

    var ctx = FrameContext{
        .allocator = &allocator,
        .text_box = raylib.Rectangle{ .x = screen_width / 2.0 - 100.0, .y = 400.0, .width = 225.0, .height = 50.0 },
        .mouse_on_text = false,
        .frames_counter = 0,
    };

    if (comptime @import("builtin").target.os.tag == .emscripten) {
        // The emscripten loop never returns, so the defers above do not fire in the web build
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
        if (zombie == null) continue;

        if (zombie) |zomb| {
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
                zomb.is_active = false; // Mark zombie as "removed"
                letter_count = 0;
                name[letter_count] = '\x00';

                // Play the zombie kill sound
                raylib.PlaySound(zombie_kill_sound);
            }
        }
    }
}

fn drawZombies() void {
    const deltaTime = 1.0 / 60.0; // 60 FPS

    for (zombies) |zombie| {
        if (zombie == null) continue;

        if (zombie) |zomb| {
            if (!zomb.is_active) continue;

            const pos = raylib.Vector2{ .x = zomb.x, .y = zomb.y };

            // Update the animation frame
            zomb.animationTimer += deltaTime;

            if (zomb.animationTimer >= 0.1) { // Change frame every 0.1 seconds
                zomb.frame += 1;
                if (zomb.frame >= ZOMBIE_FRAME_COUNT) {
                    zomb.frame = 0; // Loop back to the first frame
                }
                zomb.animationTimer = 0; // Reset the timer
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

// Function to spawn new zombies
fn spawnZombie(allocator: *std.mem.Allocator) !void {
    for (zombies, 0..) |zombie, i| {
        if (zombie == null) {
            // Allocate memory for a new zombie and assign it to zombies[i]
            const new_zombie = try allocator.create(Zombie);
            errdefer allocator.destroy(new_zombie);

            const x = @as(f32, @floatFromInt(raylib.GetRandomValue(10, 749)));
            const nameIndex: usize = @intCast(raylib.GetRandomValue(0, @intCast(ZombieNames.len - 1)));

            new_zombie.* = Zombie{
                .x = x,
                .y = 0.0,
                .speed = 0.5,
                .name = ZombieNames[nameIndex],
                .is_active = true,
                .frame = 0,
                .animationTimer = 0,
            };
            zombies[i] = new_zombie;
            break;
        }
    }
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
