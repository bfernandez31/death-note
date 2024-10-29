const std = @import("std");
const raylib = @import("raylib.zig");

const MAX_ZOMBIES = 100;
const MAX_INPUT_CHARS = 9;

const ZOMBIE_FRAME_COUNT = 17;

const BUFFER_SIZE = 16;
// Input buffer for characters
var name = [_]u8{0} ** (MAX_INPUT_CHARS + 1);
var letter_count: usize = 0;

var input_text: [MAX_INPUT_CHARS]u8 = undefined;
var input_length: usize = 0;

// Delay settings
const spawn_delay: f32 = 3.0; // Delay in seconds between spawns
var spawn_timer: f32 = 0.0; // Timer to track time since last spawn

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

const names = [_][*:0]const u8{
    "toto",
    "fo",
    "titi",
    "lolo",
    "riri",
};

const screen_width = 800;
const screen_height = 450;

pub fn main() !void {
    raylib.InitWindow(screen_width, screen_height, "Zombie Game");
    defer raylib.CloseWindow();

    zombie_texture = raylib.LoadTexture("assets/z_spritesheet.png");
    defer raylib.UnloadTexture(zombie_texture);

    const text_box = raylib.Rectangle{ .x = screen_width / 2.0 - 100.0, .y = 400.0, .width = 225.0, .height = 50.0 };
    var mouse_on_text = false;
    var frames_counter: usize = 0;

    raylib.SetTargetFPS(60); // Set target frames per second

    var allocator = std.heap.page_allocator;

    while (!raylib.WindowShouldClose()) { // Main game loop
        // Update
        if (raylib.CheckCollisionPointRec(raylib.GetMousePosition(), text_box)) {
            mouse_on_text = true;
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
            mouse_on_text = false;
            raylib.SetMouseCursor(raylib.MOUSE_CURSOR_DEFAULT);
        }

        if (mouse_on_text) {
            frames_counter += 1;
        } else {
            frames_counter = 0;
        }

        // Update spawn timer
        spawn_timer += raylib.GetFrameTime(); // Increment timer by the time elapsed since last frame

        // Check if enough time has passed to spawn a new zombie
        if (spawn_timer >= spawn_delay) {
            try spawnZombie(&allocator); // Call the function to spawn a zombie
            spawn_timer = 0.0; // Reset the spawn timer
        }

        // Update zombies
        updateZombies();

        // Draw
        raylib.BeginDrawing();
        defer raylib.EndDrawing();

        raylib.ClearBackground(raylib.RAYWHITE);

        raylib.DrawRectangleRec(text_box, raylib.LIGHTGRAY);
        if (mouse_on_text) {
            raylib.DrawRectangleLines(@intFromFloat(text_box.x), @intFromFloat(text_box.y), @intFromFloat(text_box.width), @intFromFloat(text_box.height), raylib.RED);
        } else {
            raylib.DrawRectangleLines(@intFromFloat(text_box.x), @intFromFloat(text_box.y), @intFromFloat(text_box.width), @intFromFloat(text_box.height), raylib.DARKGRAY);
        }

        raylib.DrawText(&name, @as(c_int, @intFromFloat(text_box.x)) + 5, @as(c_int, @intFromFloat(text_box.y)) + 8, 40, raylib.MAROON);

        // Draw zombies
        drawZombies();

        // Draw blinking underscore char
        if (mouse_on_text and letter_count < MAX_INPUT_CHARS and ((frames_counter / 20) % 2) == 0) {
            raylib.DrawText("_", @as(c_int, @intFromFloat(text_box.x)) + 8 + raylib.MeasureText(&name, 40), @as(c_int, @intFromFloat(text_box.y)) + 12, 40, raylib.MAROON);
        }

        if (mouse_on_text and letter_count >= MAX_INPUT_CHARS) {
            raylib.DrawText("Press BACKSPACE to delete chars...", 230, 300, 20, raylib.GRAY);
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
            errdefer allocator.destroy(Zombie);

            new_zombie.* = Zombie{
                .x = 200,
                .y = 0.0,
                .speed = 0.5,
                .name = names[1], // Selecting a name as an example
                .is_active = true,
                .frame = 0,
                .animationTimer = 0,
            };
            zombies[i] = new_zombie;
            break;
        }
    }
}
