const std = @import("std");
const raylib = @import("raylib.zig");

const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,
    name: []const u8,
};

const MAX_ZOMBIES = 100;
var zombies: [MAX_ZOMBIES]?*Zombie = undefined;

var input_text: [32]u8 = undefined;
var input_length: usize = 0;

pub fn main() !void {
    raylib.InitWindow(800, 600, "Death Note Game");
    defer raylib.CloseWindow();

    raylib.SetTargetFPS(60);

    const font = raylib.LoadFont("assets/alagard.png");
    defer raylib.UnloadFont(font);

    while (!raylib.WindowShouldClose()) {
        handleInput();
        updateZombies();
        render(font);
    }
}

fn handleInput() void {
    var key = raylib.GetCharPressed();
    while (key != 0) {
        if (key >= 32 and key <= 125) {
            if (input_length < input_text.len) {
                input_text[input_length] = @intCast(key);
                input_length += 1;
            }
        }
        key = raylib.GetCharPressed();
    }

    if (raylib.IsKeyPressed(raylib.KEY_BACKSPACE) and input_length > 0) {
        input_length -= 1;
    }
}

fn updateZombies() void {
    for (zombies) |zombie| {
        if (zombie == null) continue;

        if (zombie) |zomb| {
            if (zomb.y < 0) continue;
            zomb.y += zomb.speed;

            const typed_name = input_text[0..input_length];
            if (std.mem.eql(u8, typed_name, zomb.name)) {
                zomb.y = -1.0;
                input_length = 0;
            }

            if (zomb.y > 600) {
                raylib.CloseWindow();
                std.debug.print("Game Over!\n", .{});
            }
        }
    }
}

fn render(font: raylib.Font) void {
    raylib.BeginDrawing();
    defer raylib.EndDrawing();

    raylib.ClearBackground(raylib.RAYWHITE);

    for (zombies) |zombie| {
        if (zombie == null) continue;

        if (zombie) |zomb| {
            const pos = raylib.Vector2{ .x = zomb.x, .y = zomb.y };
            raylib.DrawTextEx(font, zomb.name, pos, 20.0, 2.0, raylib.BLACK);
        }
    }

    const page_texture = raylib.LoadTexture("assets/page.png");
    const page_pos = raylib.Vector2{ .x = 0, .y = 500 };
    raylib.DrawTexture(page_texture, page_pos.x, page_pos.y, raylib.RAYWHITE);

    const input_str = input_text[0..input_length];
    const text_pos = raylib.Vector2{ .x = 50, .y = 550 };
    raylib.DrawTextEx(font, input_str, text_pos, 20.0, 2.0, raylib.DARKGRAY);

    const plume_texture = raylib.LoadTexture("assets/plume.png");
    const plume_pos = raylib.Vector2{ .x = text_pos.x + raylib.MeasureTextEx(font, input_str, 20.0, 2.0).x, .y = 540 };
    raylib.DrawTexture(plume_texture, plume_pos.x, plume_pos.y, raylib.RAYWHITE);
}

fn spawnZombie() void {
    for (zombies) |zombie| {
        if (zombie == null) {
            zombie.* = Zombie{
                .x = std.rand.defaultRandom.next() % 750,
                .y = 0.0,
                .speed = 1.0 + std.rand.defaultRandom.next() % 2,
                .name = "Alex",
            };
            break;
        }
    }
}
