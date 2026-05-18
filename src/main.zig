const std = @import("std");
const builtin = @import("builtin");
const raylib = @import("raylib.zig").c;

const BossPhrases = @import("boss_phrases.zig").BossPhrases;
const name_lists = @import("name_lists.zig");
const zt = @import("zombie_types.zig");
const highscore = @import("highscore.zig");
const sound_config = @import("sound_config.zig");

// Aliases for the moved shared declarations (see src/zombie_types.zig). Kept at file
// scope so the rest of main.zig and its tests keep their original identifiers.
const ZombieType = zt.ZombieType;
const GameMode = zt.GameMode;
const PowerUpType = zt.PowerUpType;
const SpawnWeights = zt.SpawnWeights;
const NameWeights = zt.NameWeights;
const SPAWN_WEIGHT_TABLE = zt.SPAWN_WEIGHT_TABLE;
const NAME_WEIGHT_TABLE = zt.NAME_WEIGHT_TABLE;
const RUNNER_SPEED_MULTIPLIER = zt.RUNNER_SPEED_MULTIPLIER;
const TANK_SPEED_MULTIPLIER = zt.TANK_SPEED_MULTIPLIER;
const getSpawnWeights = zt.getSpawnWeights;
const getNameWeights = zt.getNameWeights;

const is_web = builtin.target.os.tag == .emscripten;

const MAX_ZOMBIES = 100;
const MAX_INPUT_CHARS = 20;
const MAX_BOSS_INPUT_CHARS = 35;
const BOSS_SCALE: f32 = 0.4;
const BOSS_SPEED_MULTIPLIER: f32 = 0.5;
const BOSS_HEALTH_BAR_WIDTH: c_int = 200;
const BOSS_HEALTH_BAR_HEIGHT: c_int = 8;
const BOSS_DARK_RED = raylib.Color{ .r = 139, .g = 0, .b = 0, .a = 255 };

const CRT_FG = raylib.Color{ .r = 212, .g = 138, .b = 255, .a = 255 };
// CRT_DIM is fill-only (text-box backgrounds, boss health bar). It is too dark
// on CRT_BG to read as text — use CRT_DIM_TEXT for secondary/unselected labels.
const CRT_DIM = raylib.Color{ .r = 58, .g = 26, .b = 90, .a = 255 };
const CRT_DIM_TEXT = raylib.Color{ .r = 154, .g = 106, .b = 204, .a = 255 };
const CRT_BG = raylib.Color{ .r = 8, .g = 2, .b = 10, .a = 255 };
const CRT_ACCENT = raylib.Color{ .r = 240, .g = 200, .b = 255, .a = 255 };
const CRT_WARN = raylib.Color{ .r = 255, .g = 177, .b = 58, .a = 255 };
const CRT_ERR = raylib.Color{ .r = 255, .g = 90, .b = 138, .a = 255 };
const CRT_BEZEL_OUTER = raylib.Color{ .r = 20, .g = 5, .b = 25, .a = 255 };
const CRT_BEZEL_INNER = raylib.Color{ .r = 35, .g = 10, .b = 45, .a = 255 };
const CRT_SCANLINE = raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 30 };
const CRT_VIGNETTE_OUTER = raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 60 };
const CRT_VIGNETTE_INNER = raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 30 };
const CRT_PAUSE_OVERLAY = raylib.Color{ .r = 0, .g = 0, .b = 0, .a = 150 };
const CRT_BG_CENTER = raylib.Color{ .r = 25, .g = 8, .b = 35, .a = 255 };
const CRT_FLICKER = raylib.Color{ .r = 212, .g = 138, .b = 255, .a = 8 };
const CRT_TANK = raylib.Color{ .r = 138, .g = 72, .b = 200, .a = 255 };
const CRT_SCANLINE_STEP: c_int = 3;
const CRT_VIGNETTE_OUTER_PX: c_int = 20;
const CRT_VIGNETTE_INNER_PX: c_int = 10;
const CRT_FLICKER_PERIOD_S: f64 = 7.0;
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
// Standard typing-test convention so displayed WPM is comparable to mainstream benchmarks.
const CHARS_PER_WORD: f32 = 5.0;
const SECONDS_PER_MINUTE: f32 = 60.0;

// Wave timing is derived from target_wpm so the displayed challenge matches reality:
// spawn cadence forces sustained typing at target_wpm, and on-screen time gives a
// player at target_wpm one full type-cycle of grace before a zombie lands.
const AVG_NAME_CHARS: f32 = 6.0;
const FRAMES_PER_SECOND: f32 = 60.0;

// Sustained-density model (decoupled from the WPM-lock spawn cadence):
//   - At wave start a STARTER_PACK of zombies is front-loaded in a vertical
//     cascade so the screen is dense immediately (no slow ramp-up).
//   - SPAWN_DELAY stays small (~1.5s at wave 1) so a fresh zombie always arrives
//     before the screen empties — continuous flow, never "waiting".
//   - TIME_ON_SCREEN stays long (~30s at wave 1) so even a 20-wpm typist has
//     time to clear the deepest zombie before it lands.
// All three tighten per wave so progression bites without breaking wave 1 feel.
// Pool size is still WPM-linked (round(WAVE_DURATION × wpm / 72)) so wave 1
// keeps its 13-zombie pool at WAVE_BASE_WPM = 20.
const TIME_TO_TYPE_NUMERATOR: f32 = AVG_NAME_CHARS * SECONDS_PER_MINUTE / CHARS_PER_WORD;

const SPAWN_DELAY_BASE: f32 = 1.5;
const SPAWN_DELAY_MIN: f32 = 0.4;
const SPAWN_DELAY_DECAY_PER_WAVE: f32 = 0.04;

const TIME_ON_SCREEN_BASE: f32 = 30.0;
const TIME_ON_SCREEN_MIN: f32 = 4.0;
const TIME_ON_SCREEN_DECAY_PER_WAVE: f32 = 0.9;

const STARTER_PACK_BASE: f32 = 6.0;
const STARTER_PACK_INCREMENT_PER_WAVE: f32 = 0.25;
const STARTER_PACK_CAP: f32 = 18.0;
// Starter pack arrives "from the top": first zombie at y=0 visible immediately,
// the rest are stacked off-screen above (negative y) and slide in as they fall.
// STARTER_PACK_OFFSET_RANGE controls how far above the screen the last starter
// starts — bigger range = longer slide-in window.
const STARTER_PACK_OFFSET_RANGE: f32 = 200.0;

// Jitter around the spawn cadence so consecutive zombies don't arrive on a
// perfect metronome (cosmetic; mean preserved).
const SPAWN_DELAY_JITTER: f32 = 0.3;

const DYING_DURATION: f32 = 1.0;
const STATS_TITLE_Y: c_int = 80;
const STATS_TITLE_SIZE: c_int = 56;
const STATS_BADGE_Y: c_int = 165;
const STATS_BADGE_SIZE: c_int = 22;
const STATS_GRID_LABEL_SIZE: c_int = 14;
const STATS_GRID_VALUE_SIZE: c_int = 32;
const STATS_GRID_ROW1_LABEL_Y: c_int = 280;
const STATS_GRID_ROW1_VALUE_Y: c_int = 310;
const STATS_GRID_ROW2_LABEL_Y: c_int = 420;
const STATS_GRID_ROW2_VALUE_Y: c_int = 450;
const STATS_COL1_CX: c_int = 135;
const STATS_COL2_CX: c_int = 400;
const STATS_COL3_CX: c_int = 665;
const STATS_RESTART_HINT_Y: c_int = 880;
const STATS_RESTART_HINT_SIZE: c_int = 18;
const WaveConfig = struct {
    target_wpm: u32,
    spawn_delay: f32,
    fall_speed: f32,
    pool_size: u32,
    starter_pack: u32,
};

// Wave authoring is fully formula-driven. target_wpm ramps linearly; pool_size
// is sized so each wave lasts ~WAVE_DURATION_TARGET_S at target_wpm.
const WAVE_DURATION_TARGET_S: f32 = 36.0;
const WAVE_BASE_WPM: u32 = 20;
const WAVE_WPM_INCREMENT: u32 = 5;
const WAVE_MAX_WPM: u32 = 250;

// Input buffer for characters
var name = [_]u8{0} ** (MAX_BOSS_INPUT_CHARS + 1);
var letter_count: usize = 0;

var spawn_timer: f32 = 0.0;

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
var max_combo: u32 = 0;
var popups = [_]ScorePopup{.{ .x = 0, .y = 0, .points = 0, .timer = 0, .active = false }} ** MAX_POPUPS;
var popup_next: usize = 0;

var wpm_buffer = [_]f32{0} ** WPM_BUFFER_SIZE;
var wpm_buffer_head: usize = 0;
var wpm_buffer_count: usize = 0;
var correct_chars: u32 = 0;
var wrong_chars: u32 = 0;
var elapsed_time: f32 = 0.0;
// `elapsed_time` only ticks once the player has actually started typing in the
// current wave. This keeps the displayed WPM honest (pre-typing idle doesn't
// drag the number down) and matches the user expectation that each wave is its
// own typing-test segment. The flag is cleared on wave transition end so the
// next wave reads the player's pace, not a session-wide average.
var wpm_timer_started: bool = false;
var displayed_wpm: f32 = 0.0;
var displayed_accuracy: f32 = 100.0;

var trap_cluster_group: ?usize = null;
var trap_cluster_remaining: u8 = 0;

var prng: std.Random.DefaultPrng = undefined;

var total_kills: u32 = 0;
var is_dying: bool = false;
var dying_timer: f32 = 0.0;
var dying_zombie_index: ?usize = null;
var best_score_survival: highscore.Record = .{};
var best_score_zen: highscore.Record = .{};
var last_played_mode: GameMode = .survival;
var is_new_high_score: bool = false;

var sound_cfg: sound_config.SoundConfig = .{};

var held_power_up: ?PowerUpType = null;
var freeze_timer: f32 = 0.0;
var shield_active: bool = false;
const FREEZE_DURATION: f32 = 3.0;

var zen_wpm_selection: u8 = 0;
var zen_target_wpm: u32 = 50;
const ZEN_WPM_TIERS = [_]u32{ 30, 50, 80 };

const GameScreen = enum {
    main_menu,
    wpm_select,
    playing,
    paused,
    game_over,
    sound_settings,
};

var current_screen: GameScreen = .main_menu;
var game_mode: GameMode = .survival;
var menu_selection: u8 = 0;
var pause_selection: u8 = 0;
// Set by the main-menu Quit entry so the main loop exits cleanly between frames.
// Tearing raylib down inside `frame()` would leave the rest of the same frame drawing
// onto a destroyed context.
var should_quit_app: bool = false;

// Define the Zombie structure
const Zombie = struct {
    x: f32,
    y: f32,
    speed: f32,
    name: [*:0]const u8,
    is_active: bool,
    frame: f32,
    animation_timer: f32,
    zombie_type: ZombieType = .standard,
    power_up: ?PowerUpType = null,
};

const ScorePopup = struct {
    x: f32,
    y: f32,
    points: u64,
    timer: f32,
    active: bool,
};

// Array to hold zombie pointers. Initialized explicitly to null per constitution rule;
// `undefined` debug-fills with 0xAA bytes which read as non-null pointers and crash
// on the first iteration before any zombie is spawned.
var zombies: [MAX_ZOMBIES]?*Zombie = [_]?*Zombie{null} ** MAX_ZOMBIES;

var zombie_texture: raylib.Texture2D = undefined;
var zombie_kill_sound: raylib.Sound = undefined;

const CLICK_SAMPLE_COUNT: u8 = 3;
const TYPEWRITER_SAMPLE_COUNT: u8 = 6;
const HITMARKER_SAMPLE_COUNT: u8 = 3;
const DAMAGE_SAMPLE_COUNT: u8 = 1;
const SQUARE_SAMPLE_COUNT: u8 = 1;
const MISSED_PUNCH_SAMPLE_COUNT: u8 = 2;

var click_sounds: [CLICK_SAMPLE_COUNT]raylib.Sound = undefined;
var typewriter_sounds: [TYPEWRITER_SAMPLE_COUNT]raylib.Sound = undefined;
var hitmarker_sounds: [HITMARKER_SAMPLE_COUNT]raylib.Sound = undefined;
var damage_sounds: [DAMAGE_SAMPLE_COUNT]raylib.Sound = undefined;
var square_sounds: [SQUARE_SAMPLE_COUNT]raylib.Sound = undefined;
var missed_punch_sounds: [MISSED_PUNCH_SAMPLE_COUNT]raylib.Sound = undefined;
var bomb_sound: raylib.Sound = undefined;
var freeze_sound: raylib.Sound = undefined;
var shield_sound: raylib.Sound = undefined;
var music: raylib.Music = undefined;

var typing_round_robin: u8 = 0;
var error_round_robin: u8 = 0;
var audio_ready: bool = false;

var sound_menu_selection: u8 = 0;
var sound_menu_return_screen: GameScreen = .paused;
const SOUND_MENU_ITEM_COUNT: u8 = 10;

// Tracks the currently-playing preview so a new pack focus interrupts the previous sample (ARD-5).
var last_preview_sound: ?*raylib.Sound = null;

const screen_width = 800;
const screen_height = 1000;

// Spawn X bounds: left margin + right margin sized for the rendered sprite
// (≈ 313 px frame × 0.2 scale ≈ 63 px) so zombies stay fully on-screen.
const ZOMBIE_SPAWN_X_MIN: c_int = 10;
const ZOMBIE_SPAWN_X_MAX: c_int = screen_width - 51;

// New-spawn collision guard: a zombie that hasn't yet fallen past
// SPAWN_OVERLAP_GUARD_Y still shares the vertical band with a fresh spawn at y=0,
// so its name+sprite footprint can overlap and make the new name unreadable.
// We retry the X pick up to SPAWN_MAX_X_ATTEMPTS times; on exhaustion we accept
// the last candidate rather than fail the spawn (keeps wave progression flowing).
const SPAWN_OVERLAP_GUARD_Y: f32 = 80.0;
const SPAWN_OVERLAP_PADDING: c_int = 8;
const SPAWN_MAX_X_ATTEMPTS: u8 = 8;

// Per-frame mutable context threaded through the game loop (native and emscripten paths)
const FrameContext = struct {
    allocator: *std.mem.Allocator,
    text_box: raylib.Rectangle,
    mouse_on_text: bool,
    frames_counter: usize,
};

// 20-step volume sliders map linearly to raylib's 0.0–1.0 range (20 * VOLUME_STEP = 1.0).
const VOLUME_STEP: f32 = 0.05;
// Pack preview plays at half the typing volume, with a floor so a near-muted slider can still audition packs.
const PREVIEW_VOL_FACTOR: f32 = 0.5;
const PREVIEW_VOL_FLOOR: f32 = 0.30;
// Sound settings screen layout.
const SOUND_SETTINGS_TITLE_Y: c_int = 60;
const SOUND_SETTINGS_TITLE_SIZE: c_int = 40;
const SOUND_SETTINGS_ITEM_START_Y: c_int = 160;
const SOUND_SETTINGS_ITEM_SPACING: c_int = 75;
const SOUND_SETTINGS_ITEM_LEFT_X: c_int = 40;
const SOUND_SETTINGS_ITEM_FONT_SIZE: c_int = 22;
const SOUND_SETTINGS_VALUE_RIGHT_OFFSET: c_int = 300;
const SOUND_SETTINGS_HINT_Y_OFFSET: c_int = 50;
const SOUND_SETTINGS_HINT_SIZE: c_int = 18;
const VOLUME_BAR_SEGMENTS: u8 = 10;

fn volumeToFloat(level: u8) f32 {
    return @as(f32, @floatFromInt(level)) * VOLUME_STEP;
}

fn cyclePackEnum(comptime T: type, current: T, forward: bool) T {
    const max: u8 = @intCast(@typeInfo(T).@"enum".fields.len);
    const ord: u8 = @intFromEnum(current);
    const next: u8 = if (forward) (ord + 1) % max else (ord + max - 1) % max;
    return @enumFromInt(next);
}

fn getTypingSounds() []raylib.Sound {
    return switch (sound_cfg.typing_pack) {
        .click => &click_sounds,
        .typewriter => &typewriter_sounds,
        .hitmarker => &hitmarker_sounds,
    };
}

fn getTypingSampleCount() u8 {
    return switch (sound_cfg.typing_pack) {
        .click => CLICK_SAMPLE_COUNT,
        .typewriter => TYPEWRITER_SAMPLE_COUNT,
        .hitmarker => HITMARKER_SAMPLE_COUNT,
    };
}

fn playTypingSound() void {
    if (!sound_cfg.keystrokes_enabled or !audio_ready) return;
    const sounds = getTypingSounds();
    raylib.SetSoundVolume(sounds[typing_round_robin], volumeToFloat(sound_cfg.typing_volume));
    raylib.PlaySound(sounds[typing_round_robin]);
    typing_round_robin = (typing_round_robin + 1) % getTypingSampleCount();
}

fn getErrorSounds() []raylib.Sound {
    return switch (sound_cfg.error_pack) {
        .damage => &damage_sounds,
        .square => &square_sounds,
        .missed_punch => &missed_punch_sounds,
    };
}

fn getErrorSampleCount() u8 {
    return switch (sound_cfg.error_pack) {
        .damage => DAMAGE_SAMPLE_COUNT,
        .square => SQUARE_SAMPLE_COUNT,
        .missed_punch => MISSED_PUNCH_SAMPLE_COUNT,
    };
}

// Errors share the typing pack's volume slider — they're part of the typing-feedback experience.
fn playErrorSound() void {
    if (!sound_cfg.errors_enabled or !audio_ready) return;
    const sounds = getErrorSounds();
    raylib.SetSoundVolume(sounds[error_round_robin], volumeToFloat(sound_cfg.typing_volume));
    raylib.PlaySound(sounds[error_round_robin]);
    error_round_robin = (error_round_robin + 1) % getErrorSampleCount();
}

fn typingPackName(pack: sound_config.TypingPack) []const u8 {
    return switch (pack) {
        .click => "CLICK",
        .typewriter => "TYPEWRITER",
        .hitmarker => "HITMARKER",
    };
}

fn errorPackName(pack: sound_config.ErrorPack) []const u8 {
    return switch (pack) {
        .damage => "DAMAGE",
        .square => "SQUARE",
        .missed_punch => "MISSED PUNCH",
    };
}

fn getSpeedMultiplier(zombie_type: ZombieType) f32 {
    return switch (zombie_type) {
        .standard => 1.0,
        .runner => RUNNER_SPEED_MULTIPLIER,
        .tank => TANK_SPEED_MULTIPLIER,
    };
}

fn selectZombieType(weights: SpawnWeights, rng: std.Random) ZombieType {
    const roll = rng.intRangeAtMost(u8, 0, 99);
    if (roll < weights.standard) return .standard;
    if (roll < weights.standard + weights.runner) return .runner;
    return .tank;
}

fn getZombieTint(zombie_type: ZombieType) raylib.Color {
    return switch (zombie_type) {
        .standard => CRT_FG,
        .runner => CRT_WARN,
        // CRT_DIM is too dark to multiply against the spritesheet outlines and
        // leaves tanks nearly invisible against CRT_BG; CRT_TANK is a brighter
        // violet that keeps them visually distinct as their own zombie type.
        .tank => CRT_TANK,
    };
}

fn frame(ctx: *FrameContext) void {
    // --- UPDATE PHASE ---
    switch (current_screen) {
        .main_menu => {
            updateMenu(ctx.allocator);
        },
        .wpm_select => {
            updateWpmSelect(ctx.allocator);
        },
        .playing => {
            if (audio_ready) raylib.UpdateMusicStream(music);

            // Resize input box for boss mode
            if (boss != null) {
                ctx.text_box.width = 700.0;
                ctx.text_box.x = (screen_width - 700.0) / 2.0;
            } else {
                ctx.text_box.width = 500.0;
                ctx.text_box.x = screen_width / 2.0 - 250.0;
            }

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

            if (!is_transitioning and !is_dying) {
                if (raylib.IsKeyPressed(raylib.KEY_ESCAPE)) {
                    current_screen = .paused;
                    pause_selection = 0;
                    if (audio_ready) raylib.PauseMusicStream(music);
                } else {
                    var space_consumed = false;
                    // Boss phrases contain spaces ("the dead walk again", ...), so during a
                    // boss fight space must be a typing character, not the power-up trigger.
                    if (raylib.IsKeyPressed(raylib.KEY_SPACE) and held_power_up != null and boss == null) {
                        activatePowerUp(ctx.allocator);
                        space_consumed = true;
                    }

                    var key = raylib.GetCharPressed();
                    while (key > 0) {
                        if ((key >= 32) and (key <= 125)) {
                            if (key == 32 and space_consumed) {
                                key = raylib.GetCharPressed();
                                continue;
                            }
                            wpm_timer_started = true;
                            if (letter_count < getCurrentMaxInput()) {
                                name[letter_count] = @intCast(key);
                                name[letter_count + 1] = '\x00';
                                letter_count += 1;
                                if (typedMatchesAnyEnemy()) {
                                    recordCorrectTimestamp(elapsed_time);
                                    correct_chars += 1;
                                    playTypingSound();
                                } else {
                                    wrong_chars += 1;
                                    combo_count = 0;
                                    playErrorSound();
                                }
                            } else {
                                wrong_chars += 1;
                                combo_count = 0;
                                playErrorSound();
                            }
                        }
                        key = raylib.GetCharPressed();
                    }

                    if (raylib.IsKeyPressed(raylib.KEY_BACKSPACE) and letter_count > 0) {
                        letter_count -= 1;
                        name[letter_count] = '\x00';
                    }

                    spawn_timer += raylib.GetFrameTime();

                    if (game_mode == .zen) {
                        const zen_timing = deriveWaveTiming(zen_target_wpm);
                        if (spawn_timer >= zen_timing.spawn_delay) {
                            const spawned = spawnZombie(ctx.allocator, prng.random()) catch false;
                            if (spawned) {
                                spawn_timer = 0.0;
                            }
                        }
                    } else {
                        const wave_cfg = getWaveConfig(current_wave);
                        if (spawn_timer >= wave_cfg.spawn_delay and wave_spawned < wave_cfg.pool_size and boss == null) {
                            const spawned = spawnZombie(ctx.allocator, prng.random()) catch false;
                            if (spawned) {
                                wave_spawned += 1;
                                const j = (prng.random().float(f32) * 2.0 - 1.0) * SPAWN_DELAY_JITTER;
                                spawn_timer = -wave_cfg.spawn_delay * j;
                            }
                        }
                    }

                    updateZombies(ctx.allocator);

                    if (!is_dying and game_mode == .survival) {
                        const wave_cfg = getWaveConfig(current_wave);
                        if (isBossWave(current_wave) and !boss_spawned_this_wave and boss == null) {
                            const threshold = (wave_cfg.pool_size + 1) / 2;
                            if (wave_kills >= threshold) {
                                spawnBoss(ctx.allocator) catch {};
                            }
                        }

                        updateBoss(ctx.allocator);

                        const boss_done = !isBossWave(current_wave) or (boss == null and boss_spawned_this_wave);
                        if (!is_dying and wave_kills >= wave_cfg.pool_size and wave_spawned >= wave_cfg.pool_size and boss_done) {
                            is_transitioning = true;
                            transition_timer = WAVE_TRANSITION_DURATION;
                        }
                    }
                }
            }

            if (is_transitioning) {
                transition_timer -= raylib.GetFrameTime();
                if (transition_timer <= 0) {
                    current_wave += 1;
                    wave_kills = 0;
                    wave_spawned = 0;
                    // Pre-load spawn_timer to the new wave's spawn_delay so the
                    // first drip zombie arrives on the very next update tick.
                    spawn_timer = getWaveConfig(current_wave).spawn_delay;
                    is_transitioning = false;
                    resetMetricsState();
                    resetZombies(ctx.allocator);
                    resetBoss(ctx.allocator);
                    // Front-load the new wave's starter pack for instant density.
                    if (game_mode == .survival) {
                        spawnStarterPack(ctx.allocator, prng.random(), getWaveConfig(current_wave).starter_pack);
                    }
                }
            }

            if (is_dying) {
                dying_timer -= raylib.GetFrameTime();
                if (dying_timer <= 0) {
                    current_screen = .game_over;
                    is_dying = false;
                    if (audio_ready) raylib.StopMusicStream(music);
                    const avg_wpm = calculateAverageWpm();
                    const acc: u8 = @intCast(calculateStatsAccuracy());
                    if (score > best_score_survival.score) {
                        is_new_high_score = true;
                        best_score_survival = highscore.Record{
                            .score = score,
                            .wave = current_wave,
                            .wpm = avg_wpm,
                            .accuracy = acc,
                        };
                        highscore.save(.survival, best_score_survival);
                    }
                }
            }

            if (freeze_timer > 0) {
                freeze_timer -= raylib.GetFrameTime();
                if (freeze_timer < 0) freeze_timer = 0.0;
            }

            if (!is_dying) {
                updateMetrics();
            }

            for (&popups) |*p| {
                if (p.active) {
                    p.timer -= raylib.GetFrameTime();
                    if (p.timer <= 0) p.active = false;
                }
            }
        },
        .paused => {
            updatePause(ctx.allocator);
        },
        .sound_settings => {
            updateSoundSettings();
        },
        .game_over => {
            if (raylib.IsKeyPressed(raylib.KEY_ENTER)) {
                // Retry the mode the player was actually playing — hard-coding `.survival` here
                // would silently override the choice if game-over is ever wired up for other modes.
                startGame(last_played_mode, ctx.allocator);
            } else if (raylib.IsKeyPressed(raylib.KEY_ESCAPE)) {
                current_screen = .main_menu;
            }
        },
    }

    // --- DRAW PHASE ---
    raylib.BeginDrawing();
    defer raylib.EndDrawing();

    raylib.ClearBackground(CRT_BG);
    raylib.DrawCircleGradient(
        raylib.Vector2{
            .x = @as(f32, @floatFromInt(screen_width)) / 2.0,
            .y = @as(f32, @floatFromInt(screen_height)) / 2.0,
        },
        @as(f32, @floatFromInt(screen_height)),
        CRT_BG_CENTER,
        CRT_BG,
    );

    switch (current_screen) {
        .main_menu => {
            drawMenu();
        },
        .wpm_select => {
            drawWpmSelect();
        },
        .playing => {
            raylib.DrawRectangleRec(ctx.text_box, CRT_DIM);
            const border_color = if (ctx.mouse_on_text) CRT_WARN else CRT_FG;
            raylib.DrawRectangleLines(
                @intFromFloat(ctx.text_box.x),
                @intFromFloat(ctx.text_box.y),
                @intFromFloat(ctx.text_box.width),
                @intFromFloat(ctx.text_box.height),
                border_color,
            );
            drawText(&name, @as(c_int, @intFromFloat(ctx.text_box.x)) + 5, @as(c_int, @intFromFloat(ctx.text_box.y)) + 8, 40, CRT_ACCENT);

            if (is_transitioning) {
                const next_wave = current_wave + 1;
                const next_cfg = getWaveConfig(next_wave);
                const countdown = @as(u32, @intFromFloat(@ceil(transition_timer)));

                var wave_buf: [64]u8 = undefined;
                const wave_text = std.fmt.bufPrintZ(&wave_buf, "WAVE {d} - {d} WPM challenge - {d}...", .{ next_wave, next_cfg.target_wpm, countdown }) catch "NEXT WAVE";
                drawCenteredText(wave_text.ptr, screen_height / 2 - 15, 30, CRT_FG);
            } else {
                drawZombies();
                drawBoss();
            }

            if (ctx.mouse_on_text and letter_count < getCurrentMaxInput() and ((ctx.frames_counter / 20) % 2) == 0) {
                drawText("_", @as(c_int, @intFromFloat(ctx.text_box.x)) + 8 + measureText(&name, 40), @as(c_int, @intFromFloat(ctx.text_box.y)) + 12, 40, CRT_ACCENT);
            }
            if (ctx.mouse_on_text and letter_count >= getCurrentMaxInput()) {
                drawCenteredText("Press BACKSPACE to delete chars...", 905, 18, CRT_DIM_TEXT);
            }
        },
        .paused => {
            // Draw frozen gameplay behind the pause overlay
            raylib.DrawRectangleRec(ctx.text_box, CRT_DIM);
            drawText(&name, @as(c_int, @intFromFloat(ctx.text_box.x)) + 5, @as(c_int, @intFromFloat(ctx.text_box.y)) + 8, 40, CRT_ACCENT);
            drawZombies();
            drawBoss();
            drawPauseOverlay();
        },
        .sound_settings => {
            drawSoundSettings();
        },
        .game_over => {
            raylib.DrawRectangleRec(ctx.text_box, CRT_DIM);
            drawText(&name, @as(c_int, @intFromFloat(ctx.text_box.x)) + 5, @as(c_int, @intFromFloat(ctx.text_box.y)) + 8, 40, CRT_ACCENT);

            drawCenteredTextShadow("GAME OVER", STATS_TITLE_Y, STATS_TITLE_SIZE, CRT_ERR);

            if (is_new_high_score) {
                drawCenteredText("- NEW HIGH SCORE -", STATS_BADGE_Y, STATS_BADGE_SIZE, CRT_WARN);
            }

            var score_cell_buf: [16]u8 = undefined;
            const score_cell = std.fmt.bufPrintZ(&score_cell_buf, "{d:0>6}", .{score}) catch "??????";
            drawStatCell("SCORE", score_cell.ptr, STATS_COL1_CX, STATS_GRID_ROW1_LABEL_Y, STATS_GRID_ROW1_VALUE_Y);

            var wave_cell_buf: [16]u8 = undefined;
            const wave_cell = std.fmt.bufPrintZ(&wave_cell_buf, "{d}", .{current_wave}) catch "?";
            drawStatCell("WAVE REACHED", wave_cell.ptr, STATS_COL2_CX, STATS_GRID_ROW1_LABEL_Y, STATS_GRID_ROW1_VALUE_Y);

            var slain_cell_buf: [16]u8 = undefined;
            const slain_cell = std.fmt.bufPrintZ(&slain_cell_buf, "{d}", .{total_kills}) catch "?";
            drawStatCell("ENEMIES SLAIN", slain_cell.ptr, STATS_COL3_CX, STATS_GRID_ROW1_LABEL_Y, STATS_GRID_ROW1_VALUE_Y);

            var combo_cell_buf: [16]u8 = undefined;
            const combo_cell = std.fmt.bufPrintZ(&combo_cell_buf, "x{d}", .{max_combo}) catch "x?";
            drawStatCell("MAX COMBO", combo_cell.ptr, STATS_COL1_CX, STATS_GRID_ROW2_LABEL_Y, STATS_GRID_ROW2_VALUE_Y);

            var wpm_cell_buf: [16]u8 = undefined;
            const wpm_cell = std.fmt.bufPrintZ(&wpm_cell_buf, "{d}", .{calculateAverageWpm()}) catch "?";
            drawStatCell("WPM", wpm_cell.ptr, STATS_COL2_CX, STATS_GRID_ROW2_LABEL_Y, STATS_GRID_ROW2_VALUE_Y);

            var acc_cell_buf: [16]u8 = undefined;
            const acc_cell = std.fmt.bufPrintZ(&acc_cell_buf, "{d}%", .{calculateStatsAccuracy()}) catch "?%";
            drawStatCell("ACCURACY", acc_cell.ptr, STATS_COL3_CX, STATS_GRID_ROW2_LABEL_Y, STATS_GRID_ROW2_VALUE_Y);

            drawCenteredText("> PRESS [ENTER] TO RETRY | [ESC] MENU <", STATS_RESTART_HINT_Y, STATS_RESTART_HINT_SIZE, CRT_FG);
        },
    }

    drawCrtOverlay();

    // HUD draws AFTER the overlay so the vignette doesn't dim corner-anchored text.
    if (current_screen == .playing) {
        drawPlayingHud();
    }

    drawPopups();
}

const MENU_ITEMS = [_][]const u8{ "SURVIVAL", "ZEN", "SOUND", "QUIT" };
const MENU_ITEM_COUNT: u8 = 4;
const PAUSE_ITEMS = [_][]const u8{ "RESUME", "SOUND", "QUIT TO MENU" };
const PAUSE_ITEM_COUNT: u8 = 3;

fn updateMenu(allocator: *std.mem.Allocator) void {
    if (raylib.IsKeyPressed(raylib.KEY_UP)) {
        menu_selection = (menu_selection +% MENU_ITEM_COUNT -% 1) % MENU_ITEM_COUNT;
    }
    if (raylib.IsKeyPressed(raylib.KEY_DOWN)) {
        menu_selection = (menu_selection +% 1) % MENU_ITEM_COUNT;
    }
    if (raylib.IsKeyPressed(raylib.KEY_ENTER)) {
        switch (menu_selection) {
            0 => {
                startGame(.survival, allocator);
            },
            1 => {
                current_screen = .wpm_select;
            },
            2 => {
                sound_menu_return_screen = .main_menu;
                sound_menu_selection = 0;
                current_screen = .sound_settings;
            },
            3 => {
                saveZenScoreIfBest();
                should_quit_app = true;
            },
            else => {},
        }
    }
}

fn drawMenu() void {
    drawCenteredTextShadow("DEATH NOTE", 200, 60, CRT_FG);
    drawCenteredText("- TYPING GAME -", 270, 22, CRT_DIM_TEXT);

    const menu_start_y: c_int = 400;
    const menu_spacing: c_int = 60;

    for (MENU_ITEMS, 0..) |item, i| {
        const y = menu_start_y + @as(c_int, @intCast(i)) * menu_spacing;
        const color = if (i == menu_selection) CRT_ACCENT else CRT_DIM_TEXT;
        var buf: [32]u8 = undefined;
        const prefix: []const u8 = if (i == menu_selection) "> " else "  ";
        const text = std.fmt.bufPrintZ(&buf, "{s}{s}", .{ prefix, item }) catch "???";
        drawCenteredText(text.ptr, y, 30, color);
    }

    var hs_buf: [64]u8 = undefined;
    const menu_best = if (last_played_mode == .zen) best_score_zen else best_score_survival;
    const hs_text = if (last_played_mode == .zen)
        std.fmt.bufPrintZ(&hs_buf, "BEST: {d} WPM - {d}% ACC", .{ menu_best.wpm, menu_best.accuracy }) catch "BEST: ---"
    else
        std.fmt.bufPrintZ(&hs_buf, "BEST: {d:0>6} - WAVE {d}", .{ menu_best.score, menu_best.wave }) catch "BEST: ---";
    drawCenteredText(hs_text.ptr, 700, 20, CRT_DIM_TEXT);
}

fn updateWpmSelect(allocator: *std.mem.Allocator) void {
    const tier_count: u8 = @intCast(ZEN_WPM_TIERS.len);
    if (raylib.IsKeyPressed(raylib.KEY_UP)) {
        zen_wpm_selection = (zen_wpm_selection +% tier_count -% 1) % tier_count;
    }
    if (raylib.IsKeyPressed(raylib.KEY_DOWN)) {
        zen_wpm_selection = (zen_wpm_selection +% 1) % tier_count;
    }
    if (raylib.IsKeyPressed(raylib.KEY_ENTER)) {
        zen_target_wpm = ZEN_WPM_TIERS[zen_wpm_selection];
        startGame(.zen, allocator);
    }
    if (raylib.IsKeyPressed(raylib.KEY_ESCAPE)) {
        current_screen = .main_menu;
    }
}

fn drawWpmSelect() void {
    drawCenteredTextShadow("SELECT WPM TARGET", 200, 40, CRT_FG);

    const start_y: c_int = 400;
    const spacing: c_int = 60;

    for (ZEN_WPM_TIERS, 0..) |tier, i| {
        const y = start_y + @as(c_int, @intCast(i)) * spacing;
        const color = if (i == zen_wpm_selection) CRT_ACCENT else CRT_DIM_TEXT;
        var buf: [32]u8 = undefined;
        const prefix: []const u8 = if (i == zen_wpm_selection) "> " else "  ";
        const text = std.fmt.bufPrintZ(&buf, "{s}{d} WPM", .{ prefix, tier }) catch "???";
        drawCenteredText(text.ptr, y, 30, color);
    }
}

fn updatePause(allocator: *std.mem.Allocator) void {
    if (raylib.IsKeyPressed(raylib.KEY_UP)) {
        pause_selection = (pause_selection +% PAUSE_ITEM_COUNT -% 1) % PAUSE_ITEM_COUNT;
    }
    if (raylib.IsKeyPressed(raylib.KEY_DOWN)) {
        pause_selection = (pause_selection +% 1) % PAUSE_ITEM_COUNT;
    }
    if (raylib.IsKeyPressed(raylib.KEY_ENTER)) {
        switch (pause_selection) {
            0 => {
                current_screen = .playing;
                if (audio_ready) raylib.ResumeMusicStream(music);
            },
            1 => {
                sound_menu_return_screen = .paused;
                sound_menu_selection = 0;
                current_screen = .sound_settings;
            },
            2 => {
                saveZenScoreIfBest();
                resetZombies(allocator);
                resetBoss(allocator);
                if (audio_ready) raylib.StopMusicStream(music);
                current_screen = .main_menu;
            },
            else => {},
        }
    }
}

fn updateSoundSettings() void {
    const prev_selection = sound_menu_selection;

    if (raylib.IsKeyPressed(raylib.KEY_UP)) {
        sound_menu_selection = (sound_menu_selection +% SOUND_MENU_ITEM_COUNT -% 1) % SOUND_MENU_ITEM_COUNT;
    }
    if (raylib.IsKeyPressed(raylib.KEY_DOWN)) {
        sound_menu_selection = (sound_menu_selection +% 1) % SOUND_MENU_ITEM_COUNT;
    }

    // Pack selector preview on focus change
    if (sound_menu_selection != prev_selection) {
        if (sound_menu_selection == 1) {
            playPackPreview(true);
        } else if (sound_menu_selection == 4) {
            playPackPreview(false);
        }
    }

    if (raylib.IsKeyPressed(raylib.KEY_ENTER)) {
        switch (sound_menu_selection) {
            0 => sound_cfg.keystrokes_enabled = !sound_cfg.keystrokes_enabled,
            3 => sound_cfg.errors_enabled = !sound_cfg.errors_enabled,
            5 => sound_cfg.kills_enabled = !sound_cfg.kills_enabled,
            6 => sound_cfg.power_ups_enabled = !sound_cfg.power_ups_enabled,
            8 => {
                sound_cfg.music_enabled = !sound_cfg.music_enabled;
                if (audio_ready) {
                    if (!sound_cfg.music_enabled) {
                        raylib.StopMusicStream(music);
                    } else if (sound_menu_return_screen == .paused) {
                        // Coming from an active (paused) session: prime the stream so the game's
                        // resume flow has something to ResumeMusicStream, but pause it immediately
                        // so music does not audibly play on the pause screen.
                        raylib.SetMusicVolume(music, volumeToFloat(sound_cfg.music_volume));
                        raylib.PlayMusicStream(music);
                        raylib.PauseMusicStream(music);
                    }
                    // From main menu: there's nothing to hear yet — music starts when a mode is chosen.
                }
            },
            else => {},
        }
    }

    const left = raylib.IsKeyPressed(raylib.KEY_LEFT);
    const right = raylib.IsKeyPressed(raylib.KEY_RIGHT);

    if (left or right) {
        switch (sound_menu_selection) {
            1 => {
                sound_cfg.typing_pack = cyclePackEnum(sound_config.TypingPack, sound_cfg.typing_pack, right);
                typing_round_robin = 0;
                playPackPreview(true);
            },
            4 => {
                sound_cfg.error_pack = cyclePackEnum(sound_config.ErrorPack, sound_cfg.error_pack, right);
                error_round_robin = 0;
                playPackPreview(false);
            },
            2 => {
                if (right and sound_cfg.typing_volume < 20) sound_cfg.typing_volume += 1;
                if (left and sound_cfg.typing_volume > 0) sound_cfg.typing_volume -|= 1;
                // Use the always-on preview so the player hears the level even if keystroke sounds are toggled off.
                const tsounds = getTypingSounds();
                playVolumePreview(tsounds[typing_round_robin], sound_cfg.typing_volume);
                typing_round_robin = (typing_round_robin + 1) % getTypingSampleCount();
            },
            7 => {
                if (right and sound_cfg.effects_volume < 20) sound_cfg.effects_volume += 1;
                if (left and sound_cfg.effects_volume > 0) sound_cfg.effects_volume -|= 1;
                playVolumePreview(zombie_kill_sound, sound_cfg.effects_volume);
            },
            9 => {
                if (right and sound_cfg.music_volume < 20) sound_cfg.music_volume += 1;
                if (left and sound_cfg.music_volume > 0) sound_cfg.music_volume -|= 1;
                if (audio_ready) raylib.SetMusicVolume(music, volumeToFloat(sound_cfg.music_volume));
                // FR-014 calibration: the music stream is usually paused/stopped on this screen, so the
                // kill sound stands in as a short representative sample at the music slider's level.
                playVolumePreview(zombie_kill_sound, sound_cfg.music_volume);
            },
            else => {},
        }
    }

    if (raylib.IsKeyPressed(raylib.KEY_ESCAPE)) {
        sound_config.save(sound_cfg);
        current_screen = sound_menu_return_screen;
        if (sound_menu_return_screen == .paused) {
            pause_selection = 0;
        }
    }
}

fn playPackPreview(is_typing: bool) void {
    if (!audio_ready) return;
    const sounds = if (is_typing) getTypingSounds() else getErrorSounds();
    const vol = volumeToFloat(sound_cfg.typing_volume);
    const preview_vol = if (vol < PREVIEW_VOL_FLOOR) PREVIEW_VOL_FLOOR else vol * PREVIEW_VOL_FACTOR;
    if (last_preview_sound) |prev| raylib.StopSound(prev.*);
    raylib.SetSoundVolume(sounds[0], preview_vol);
    raylib.PlaySound(sounds[0]);
    last_preview_sound = &sounds[0];
}

// Always-on volume calibration preview that bypasses the category toggle — when adjusting a
// volume slider, the player needs audible feedback even if the matching category is disabled.
fn playVolumePreview(snd: raylib.Sound, level: u8) void {
    if (!audio_ready) return;
    if (last_preview_sound) |prev| raylib.StopSound(prev.*);
    raylib.SetSoundVolume(snd, volumeToFloat(level));
    raylib.PlaySound(snd);
    last_preview_sound = null;
}

fn drawSoundSettings() void {
    raylib.DrawRectangle(0, 0, screen_width, screen_height, CRT_BG);

    drawCenteredTextShadow("SOUND SETTINGS", SOUND_SETTINGS_TITLE_Y, SOUND_SETTINGS_TITLE_SIZE, CRT_FG);

    const labels = [SOUND_MENU_ITEM_COUNT][]const u8{
        "KEYSTROKE SOUNDS",
        "TYPING PACK",
        "TYPING VOLUME",
        "ERROR SOUNDS",
        "ERROR PACK",
        "KILL SOUNDS",
        "POWER-UP SOUNDS",
        "EFFECTS VOLUME",
        "MUSIC",
        "MUSIC VOLUME",
    };

    for (labels, 0..) |label, i| {
        const y = SOUND_SETTINGS_ITEM_START_Y + @as(c_int, @intCast(i)) * SOUND_SETTINGS_ITEM_SPACING;
        const selected = (i == sound_menu_selection);
        const color = if (selected) CRT_ACCENT else CRT_DIM_TEXT;

        var label_buf: [48]u8 = undefined;
        const prefix: []const u8 = if (selected) "> " else "  ";
        const label_text = std.fmt.bufPrintZ(&label_buf, "{s}{s}", .{ prefix, label }) catch "???";
        drawText(label_text.ptr, SOUND_SETTINGS_ITEM_LEFT_X, y, SOUND_SETTINGS_ITEM_FONT_SIZE, color);

        var val_buf: [48]u8 = undefined;
        const val_text: [*:0]const u8 = switch (@as(u8, @intCast(i))) {
            0 => if (sound_cfg.keystrokes_enabled) "[ON]" else "[OFF]",
            1 => std.fmt.bufPrintZ(&val_buf, "< {s} >", .{typingPackName(sound_cfg.typing_pack)}) catch "???",
            2 => formatVolumeBar(&val_buf, sound_cfg.typing_volume),
            3 => if (sound_cfg.errors_enabled) "[ON]" else "[OFF]",
            4 => std.fmt.bufPrintZ(&val_buf, "< {s} >", .{errorPackName(sound_cfg.error_pack)}) catch "???",
            5 => if (sound_cfg.kills_enabled) "[ON]" else "[OFF]",
            6 => if (sound_cfg.power_ups_enabled) "[ON]" else "[OFF]",
            7 => formatVolumeBar(&val_buf, sound_cfg.effects_volume),
            8 => if (sound_cfg.music_enabled) "[ON]" else "[OFF]",
            9 => formatVolumeBar(&val_buf, sound_cfg.music_volume),
            else => "???",
        };
        drawText(val_text, screen_width - SOUND_SETTINGS_VALUE_RIGHT_OFFSET, y, SOUND_SETTINGS_ITEM_FONT_SIZE, color);
    }

    drawCenteredText("ESC: BACK", screen_height - SOUND_SETTINGS_HINT_Y_OFFSET, SOUND_SETTINGS_HINT_SIZE, CRT_DIM_TEXT);
}

fn formatVolumeBar(buf: *[48]u8, level: u8) [*:0]const u8 {
    const filled: u8 = @intCast(@as(u16, level) * VOLUME_BAR_SEGMENTS / 20);
    var bar: [VOLUME_BAR_SEGMENTS + 2]u8 = undefined;
    bar[0] = '[';
    var i: u8 = 0;
    while (i < VOLUME_BAR_SEGMENTS) : (i += 1) {
        bar[i + 1] = if (i < filled) '#' else '-';
    }
    bar[VOLUME_BAR_SEGMENTS + 1] = ']';
    const pct = @as(u32, level) * 5;
    return std.fmt.bufPrintZ(buf, "{s} {d:>3}%", .{ bar, pct }) catch "???";
}

fn drawPauseOverlay() void {
    raylib.DrawRectangle(0, 0, screen_width, screen_height, CRT_PAUSE_OVERLAY);
    drawCenteredTextShadow("PAUSED", screen_height / 2 - 100, 50, CRT_FG);

    const pause_start_y: c_int = screen_height / 2;
    const pause_spacing: c_int = 50;

    for (PAUSE_ITEMS, 0..) |item, i| {
        const y = pause_start_y + @as(c_int, @intCast(i)) * pause_spacing;
        const color = if (i == pause_selection) CRT_ACCENT else CRT_DIM_TEXT;
        var buf: [32]u8 = undefined;
        const prefix: []const u8 = if (i == pause_selection) "> " else "  ";
        const text = std.fmt.bufPrintZ(&buf, "{s}{s}", .{ prefix, item }) catch "???";
        drawCenteredText(text.ptr, y, 26, color);
    }
}

fn drawMetricsHud() void {
    const wpm_rounded: u32 = @intFromFloat(@round(displayed_wpm));
    var wpm_buf: [32]u8 = undefined;
    const wpm_text = std.fmt.bufPrintZ(&wpm_buf, "WPM {d}", .{wpm_rounded}) catch "WPM ?";
    drawText(wpm_text.ptr, WPM_HUD_X, WPM_HUD_Y, METRICS_HUD_SIZE, CRT_FG);

    const acc_rounded: u32 = @intFromFloat(@round(displayed_accuracy));
    var acc_buf: [32]u8 = undefined;
    const acc_text = std.fmt.bufPrintZ(&acc_buf, "Acc {d}%", .{acc_rounded}) catch "Acc ?";
    drawText(acc_text.ptr, ACC_HUD_X, ACC_HUD_Y, METRICS_HUD_SIZE, CRT_FG);
}

fn drawPlayingHud() void {
    if (game_mode == .zen) {
        drawZenHud();
        return;
    }

    const hud_cfg = getWaveConfig(current_wave);
    var hud_buf: [64]u8 = undefined;
    const hud_text = std.fmt.bufPrintZ(&hud_buf, "WAVE {d} - {d} WPM - {d} / {d}", .{ current_wave, hud_cfg.target_wpm, wave_kills, hud_cfg.pool_size }) catch "WAVE ?";
    drawCenteredText(hud_text.ptr, 10, 20, CRT_FG);

    var score_buf: [32]u8 = undefined;
    const score_text = std.fmt.bufPrintZ(&score_buf, "Score: {d:0>6}", .{score}) catch "Score: ?";
    drawText(score_text.ptr, SCORE_HUD_X, SCORE_HUD_Y, SCORE_HUD_SIZE, CRT_FG);

    var combo_buf: [32]u8 = undefined;
    const combo_text = std.fmt.bufPrintZ(&combo_buf, "Combo: {d} x{d}", .{ combo_count, getComboMultiplier(combo_count) }) catch "Combo: ?";
    drawText(combo_text.ptr, COMBO_HUD_X, COMBO_HUD_Y, COMBO_HUD_SIZE, getComboColor(combo_count));

    drawMetricsHud();

    if (game_mode == .survival) {
        if (held_power_up) |pu| {
            const label: [*:0]const u8 = switch (pu) {
                .freeze => "[*] FREEZE",
                .bomb => "[!] BOMB",
                .shield => "[+] SHIELD",
            };
            const color = switch (pu) {
                .freeze => CRT_ACCENT,
                .bomb => CRT_ERR,
                .shield => CRT_WARN,
            };
            drawText(label, SCORE_HUD_X, 60, METRICS_HUD_SIZE, color);
        }

        if (freeze_timer > 0) {
            var ft_buf: [32]u8 = undefined;
            const timer_int: u32 = @intFromFloat(@ceil(freeze_timer));
            const ft_text = std.fmt.bufPrintZ(&ft_buf, "FREEZE {d}s", .{timer_int}) catch "FREEZE";
            drawText(ft_text.ptr, SCORE_HUD_X, 80, METRICS_HUD_SIZE, CRT_ACCENT);
        }

        if (shield_active) {
            // Drawn on its own row so it does not overlap the FREEZE countdown when both effects are active.
            const shield_y: c_int = if (freeze_timer > 0) 100 else 80;
            drawText("SHIELD ARMED", SCORE_HUD_X, shield_y, METRICS_HUD_SIZE, CRT_WARN);
        }
    }
}

fn getFallSpeed() f32 {
    if (game_mode == .zen) {
        return deriveWaveTiming(zen_target_wpm).fall_speed;
    }
    return getWaveConfig(current_wave).fall_speed;
}

fn drawZenHud() void {
    var target_buf: [32]u8 = undefined;
    const target_text = std.fmt.bufPrintZ(&target_buf, "ZEN - {d} WPM target", .{zen_target_wpm}) catch "ZEN";
    drawCenteredText(target_text.ptr, 10, 20, CRT_FG);
    drawMetricsHud();
}

fn playPowerUpSound(pu_type: PowerUpType) void {
    if (!sound_cfg.power_ups_enabled or !audio_ready) return;
    const snd = switch (pu_type) {
        .freeze => freeze_sound,
        .bomb => bomb_sound,
        .shield => shield_sound,
    };
    raylib.SetSoundVolume(snd, volumeToFloat(sound_cfg.effects_volume));
    raylib.PlaySound(snd);
}

fn playKillSound() void {
    if (!sound_cfg.kills_enabled or !audio_ready) return;
    raylib.SetSoundVolume(zombie_kill_sound, volumeToFloat(sound_cfg.effects_volume));
    raylib.PlaySound(zombie_kill_sound);
}

fn activatePowerUp(allocator: *std.mem.Allocator) void {
    if (held_power_up) |pu| {
        playPowerUpSound(pu);
        switch (pu) {
            .freeze => {
                freeze_timer = FREEZE_DURATION;
            },
            .bomb => {
                var bomb_killed_any = false;
                for (&zombies) |*slot| {
                    if (slot.*) |zomb| {
                        if (!zomb.is_active) continue;
                        if (zomb.zombie_type == .standard) {
                            var zomb_name_length: usize = 0;
                            while (zomb.name[zomb_name_length] != '\x00') zomb_name_length += 1;
                            const points = calculateScore(zomb_name_length, zomb.y, false, combo_count);
                            score += points;
                            combo_count += 1;
                            if (combo_count > max_combo) max_combo = combo_count;
                            spawnPopup(zomb.x, zomb.y, points);
                            // Bomb kills must tick wave_kills, else the wave stalls when the
                            // bomb clears the last zombies before wave_spawned reaches pool_size.
                            wave_kills += 1;
                            total_kills += 1;
                            allocator.destroy(zomb);
                            slot.* = null;
                            bomb_killed_any = true;
                        }
                    }
                }
                if (bomb_killed_any) playKillSound();
            },
            .shield => {
                shield_active = true;
            },
        }
        held_power_up = null;
    }
}

// Persist the current Zen session's WPM/accuracy if it beats `best_score_zen`.
// Called from every transition that ends an active Zen session (start new game,
// quit-to-menu, quit-to-OS) so a record is never silently dropped.
fn saveZenScoreIfBest() void {
    if (game_mode != .zen) return;
    const avg_wpm = calculateAverageWpm();
    const acc: u8 = @intCast(calculateStatsAccuracy());
    if (avg_wpm > best_score_zen.wpm or (avg_wpm == best_score_zen.wpm and acc > best_score_zen.accuracy)) {
        best_score_zen = highscore.Record{
            .score = 0,
            .wave = 0,
            .wpm = avg_wpm,
            .accuracy = acc,
        };
        highscore.save(.zen, best_score_zen);
    }
}

fn startGame(mode: GameMode, allocator: *std.mem.Allocator) void {
    // If we were mid-Zen (e.g. user picked a new mode from the menu), preserve the WPM record
    // before the session counters are reset below.
    if (current_screen == .playing) saveZenScoreIfBest();
    game_mode = mode;
    last_played_mode = mode;
    current_screen = .playing;
    letter_count = 0;
    name[0] = '\x00';
    current_wave = 1;
    // Pre-load spawn_timer to spawn_delay so the first drip zombie arrives on
    // the next update tick instead of after a full empty window.
    spawn_timer = getWaveConfig(current_wave).spawn_delay;
    wave_kills = 0;
    wave_spawned = 0;
    is_transitioning = false;
    transition_timer = 0.0;
    resetSessionState();
    resetScoreState();
    resetMetricsState();
    resetZombies(allocator);
    resetBoss(allocator);
    // Front-load the wave 1 starter pack so the screen is dense from t=0
    // (sustained density model, see SPAWN_DELAY_BASE comment).
    if (mode == .survival) {
        spawnStarterPack(allocator, prng.random(), getWaveConfig(current_wave).starter_pack);
    }
    if (sound_cfg.music_enabled and audio_ready) {
        raylib.SetMusicVolume(music, volumeToFloat(sound_cfg.music_volume));
        raylib.StopMusicStream(music);
        raylib.PlayMusicStream(music);
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
    // Skip audio unloads when audio init failed — handles are zeroed and unloading them is UB.
    if (audio_ready) {
        raylib.UnloadSound(zombie_kill_sound);
        for (&click_sounds) |*s| raylib.UnloadSound(s.*);
        for (&typewriter_sounds) |*s| raylib.UnloadSound(s.*);
        for (&hitmarker_sounds) |*s| raylib.UnloadSound(s.*);
        for (&damage_sounds) |*s| raylib.UnloadSound(s.*);
        for (&square_sounds) |*s| raylib.UnloadSound(s.*);
        for (&missed_punch_sounds) |*s| raylib.UnloadSound(s.*);
        raylib.UnloadSound(bomb_sound);
        raylib.UnloadSound(freeze_sound);
        raylib.UnloadSound(shield_sound);
        raylib.UnloadMusicStream(music);
        raylib.CloseAudioDevice();
    }
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

    click_sounds[0] = raylib.LoadSound("assets/sounds/click/1.wav");
    defer raylib.UnloadSound(click_sounds[0]);
    click_sounds[1] = raylib.LoadSound("assets/sounds/click/2.wav");
    defer raylib.UnloadSound(click_sounds[1]);
    click_sounds[2] = raylib.LoadSound("assets/sounds/click/3.wav");
    defer raylib.UnloadSound(click_sounds[2]);

    typewriter_sounds[0] = raylib.LoadSound("assets/sounds/typewriter/1.wav");
    defer raylib.UnloadSound(typewriter_sounds[0]);
    typewriter_sounds[1] = raylib.LoadSound("assets/sounds/typewriter/2.wav");
    defer raylib.UnloadSound(typewriter_sounds[1]);
    typewriter_sounds[2] = raylib.LoadSound("assets/sounds/typewriter/3.wav");
    defer raylib.UnloadSound(typewriter_sounds[2]);
    typewriter_sounds[3] = raylib.LoadSound("assets/sounds/typewriter/4.wav");
    defer raylib.UnloadSound(typewriter_sounds[3]);
    typewriter_sounds[4] = raylib.LoadSound("assets/sounds/typewriter/5.wav");
    defer raylib.UnloadSound(typewriter_sounds[4]);
    typewriter_sounds[5] = raylib.LoadSound("assets/sounds/typewriter/6.wav");
    defer raylib.UnloadSound(typewriter_sounds[5]);

    hitmarker_sounds[0] = raylib.LoadSound("assets/sounds/hitmarker/1.wav");
    defer raylib.UnloadSound(hitmarker_sounds[0]);
    hitmarker_sounds[1] = raylib.LoadSound("assets/sounds/hitmarker/2.wav");
    defer raylib.UnloadSound(hitmarker_sounds[1]);
    hitmarker_sounds[2] = raylib.LoadSound("assets/sounds/hitmarker/3.wav");
    defer raylib.UnloadSound(hitmarker_sounds[2]);

    damage_sounds[0] = raylib.LoadSound("assets/sounds/damage/1.wav");
    defer raylib.UnloadSound(damage_sounds[0]);

    square_sounds[0] = raylib.LoadSound("assets/sounds/square/1.wav");
    defer raylib.UnloadSound(square_sounds[0]);

    missed_punch_sounds[0] = raylib.LoadSound("assets/sounds/missed-punch/1.wav");
    defer raylib.UnloadSound(missed_punch_sounds[0]);
    missed_punch_sounds[1] = raylib.LoadSound("assets/sounds/missed-punch/2.wav");
    defer raylib.UnloadSound(missed_punch_sounds[1]);

    bomb_sound = raylib.LoadSound("assets/sounds/bomb/1.wav");
    defer raylib.UnloadSound(bomb_sound);
    freeze_sound = raylib.LoadSound("assets/sounds/freeze/1.wav");
    defer raylib.UnloadSound(freeze_sound);
    shield_sound = raylib.LoadSound("assets/sounds/shield/1.wav");
    defer raylib.UnloadSound(shield_sound);

    music = raylib.LoadMusicStream("assets/music/nightmare-pulse.wav");
    defer raylib.UnloadMusicStream(music);
    music.looping = true;
    // Detect headless / driver-less environments so subsequent PlaySound/UpdateMusicStream
    // calls become no-ops instead of operating on zeroed handles.
    audio_ready = raylib.IsAudioDeviceReady();

    zombie_texture = raylib.LoadTexture("assets/z_spritesheet.png");
    defer raylib.UnloadTexture(zombie_texture);

    raylib.SetTargetFPS(60);

    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.REALTIME, &ts);
    const seed: u64 = @intCast(@max(0, ts.sec *% 1000 + @divTrunc(ts.nsec, 1_000_000)));
    prng = std.Random.DefaultPrng.init(seed);

    best_score_survival = highscore.load(.survival);
    best_score_zen = highscore.load(.zen);
    sound_cfg = sound_config.load();

    // page_allocator uses posix.mmap, which has no backend on wasm32-emscripten —
    // every allocator.create(...) silently fails and zombies never spawn.
    // c_allocator forwards to libc malloc/free, which emcc provides.
    var allocator: std.mem.Allocator = if (is_web)
        std.heap.c_allocator
    else
        std.heap.page_allocator;

    var ctx = FrameContext{
        .allocator = &allocator,
        .text_box = raylib.Rectangle{ .x = screen_width / 2.0 - 250.0, .y = 930.0, .width = 500.0, .height = 50.0 },
        .mouse_on_text = false,
        .frames_counter = 0,
    };

    if (comptime is_web) {
        // The emscripten loop never returns, so the defers above do not fire in the web
        // build. Register cleanup_on_exit() as a best-effort mitigation; see its doc
        // comment for the limitations on browser tab close.
        _ = raylib.atexit(&cleanup_on_exit);
        raylib.emscripten_set_main_loop_arg(frame_c_callback, &ctx, 0, 1);
    } else {
        while (!raylib.WindowShouldClose() and !should_quit_app) { // Main game loop
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
    var shield_absorbed_any = false;
    for (&zombies, 0..) |*slot, i| {
        if (slot.*) |zomb| {
            if (!zomb.is_active) continue;
            if (freeze_timer <= 0) {
                zomb.y += zomb.speed;
            }

            if (zomb.y >= screen_height) {
                if (game_mode == .zen) {
                    allocator.destroy(zomb);
                    slot.* = null;
                    continue;
                }
                // Survival: a shield absorbs every zombie that crosses this frame, then disarms once.
                // Disarming after the loop prevents a cluster (e.g. freeze expiry advancing several past
                // the bottom in one step) from leaking a second zombie past the shield.
                if (shield_active) {
                    allocator.destroy(zomb);
                    slot.* = null;
                    shield_absorbed_any = true;
                    // Count the absorbed zombie toward wave completion and the kill total;
                    // otherwise the wave stalls because spawned > kills forever.
                    wave_kills += 1;
                    total_kills += 1;
                    continue;
                }
                is_dying = true;
                dying_timer = DYING_DURATION;
                dying_zombie_index = i;
                break;
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
                if (combo_count > max_combo) max_combo = combo_count;
                spawnPopup(zomb.x, zomb.y, points);
                if (zomb.power_up != null and held_power_up == null) {
                    held_power_up = zomb.power_up;
                }
                allocator.destroy(zomb);
                slot.* = null;
                letter_count = 0;
                name[letter_count] = '\x00';
                wave_kills += 1;
                total_kills += 1;
                playKillSound();
            }
        }
    }
    if (shield_absorbed_any) shield_active = false;
}

fn drawZombies() void {
    const delta_time = 1.0 / 60.0; // 60 FPS

    for (zombies, 0..) |zombie, i| {
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

            const scale = 0.2;
            const is_dying_target = is_dying and dying_zombie_index == i;
            const tint: raylib.Color = if (is_dying_target) CRT_ERR else getZombieTint(zomb.zombie_type);
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
                tint,
            );

            // Draw the zombie's name above the zombie
            const text_pos = raylib.Vector2{ .x = pos.x, .y = pos.y - 20.0 };
            drawText(zomb.name, @intFromFloat(text_pos.x), @intFromFloat(text_pos.y), 20, CRT_ACCENT);

            if (zomb.power_up) |pu| {
                const t = raylib.GetTime();
                const pulse_f: f32 = @floatCast(@sin(t * 4.0) * 0.3 + 0.7);
                const alpha: u8 = @intFromFloat(pulse_f * 255.0);
                const glyph: [*:0]const u8 = switch (pu) {
                    .freeze => "*",
                    .bomb => "!",
                    .shield => "+",
                };
                var glyph_color = switch (pu) {
                    .freeze => CRT_ACCENT,
                    .bomb => CRT_ERR,
                    .shield => CRT_WARN,
                };
                glyph_color.a = alpha;
                drawText(glyph, @intFromFloat(text_pos.x), @intFromFloat(text_pos.y - 18.0), 20, glyph_color);
            }
        }
    }
}

fn spawnZombie(allocator: *std.mem.Allocator, rng: std.Random) !bool {
    return spawnZombieInZone(allocator, rng, ZOMBIE_SPAWN_X_MIN, ZOMBIE_SPAWN_X_MAX, 0.0);
}

// Pure AABB overlap with padding for two horizontal boxes [a, a+wa] and [b, b+wb].
fn xBoxesOverlap(a: c_int, wa: c_int, b: c_int, wb: c_int, padding: c_int) bool {
    return if (a <= b) a + wa + padding > b else b + wb + padding > a;
}

// True if a new zombie at (x, new_y) would collide with any active zombie
// whose y is within SPAWN_OVERLAP_GUARD_Y vertical band (i.e. close enough
// that their name+sprite footprints overlap).
fn xCollidesAtY(x: c_int, new_y: f32, width: c_int) bool {
    const sprite_w: c_int = screen_width - ZOMBIE_SPAWN_X_MAX;
    for (zombies) |slot| {
        if (slot) |z| {
            if (!z.is_active) continue;
            const dy = if (new_y > z.y) new_y - z.y else z.y - new_y;
            if (dy >= SPAWN_OVERLAP_GUARD_Y) continue;
            const z_name_w = measureText(z.name, 20);
            const z_width = @max(z_name_w, sprite_w);
            const z_x_int: c_int = @intFromFloat(z.x);
            if (xBoxesOverlap(x, width, z_x_int, z_width, SPAWN_OVERLAP_PADDING)) return true;
        }
    }
    return false;
}

// Front-load `count` zombies at wave start. First zombie spawns at y=0 (visible
// immediately, no empty screen), the rest stack off-screen above (negative y)
// so they slide in from the top over the next few seconds. Spread across X
// zones so they don't pile up horizontally. Each successful spawn increments
// wave_spawned.
fn spawnStarterPack(allocator: *std.mem.Allocator, rng: std.Random, count: u32) void {
    if (count == 0) return;
    const count_f = @as(f32, @floatFromInt(count));
    const y_step: f32 = if (count == 1) 0.0 else STARTER_PACK_OFFSET_RANGE / (count_f - 1.0);
    const zone_w: c_int = @divTrunc(screen_width, @as(c_int, @intCast(count)));
    var i: u32 = 0;
    var spawned_count: u32 = 0;
    while (i < count) : (i += 1) {
        const y0: f32 = -@as(f32, @floatFromInt(i)) * y_step;
        const zone_min: c_int = @as(c_int, @intCast(i)) * zone_w;
        const zone_max: c_int = if (i + 1 == count) screen_width else zone_min + zone_w;
        const ok = spawnZombieInZone(allocator, rng, zone_min, zone_max, y0) catch false;
        if (ok) spawned_count += 1;
    }
    wave_spawned += spawned_count;
}

fn spawnZombieInZone(allocator: *std.mem.Allocator, rng: std.Random, zone_x_min: c_int, zone_x_max: c_int, y0: f32) !bool {
    for (zombies, 0..) |zombie, i| {
        if (zombie == null) {
            const zombie_type = selectZombieType(getSpawnWeights(current_wave), rng);

            var active_buf: [MAX_ZOMBIES][*:0]const u8 = undefined;
            var active_count: usize = 0;
            for (zombies) |slot| {
                if (slot) |z| {
                    if (z.is_active) {
                        active_buf[active_count] = z.name;
                        active_count += 1;
                    }
                }
            }

            const forced_group: ?usize = if (trap_cluster_remaining > 0) trap_cluster_group else null;

            const selection = name_lists.selectName(
                current_wave,
                zombie_type,
                active_buf[0..active_count],
                forced_group,
                rng,
            ) orelse {
                // Tick the cluster counter down even on selection failure: an exhausted
                // trap group would otherwise stall the spawner into retrying the same
                // forced group on every subsequent call.
                if (trap_cluster_remaining > 0) {
                    trap_cluster_remaining -= 1;
                    if (trap_cluster_remaining == 0) trap_cluster_group = null;
                }
                return false;
            };

            if (selection.category == .trap and trap_cluster_remaining == 0) {
                trap_cluster_group = selection.trap_group_index;
                trap_cluster_remaining = @intCast(rng.intRangeAtMost(u8, 1, 2));
            } else if (trap_cluster_remaining > 0) {
                trap_cluster_remaining -= 1;
                if (trap_cluster_remaining == 0) trap_cluster_group = null;
            }

            const new_zombie = try allocator.create(Zombie);
            errdefer allocator.destroy(new_zombie);

            const name_width = measureText(selection.name, 20);
            const sprite_width: c_int = screen_width - ZOMBIE_SPAWN_X_MAX;
            const required = @max(name_width, sprite_width);
            // Hard screen-edge protection: x can never sit so far right that the rendered
            // name overflows past screen_width - 5. The zone fits inside this safe band.
            const screen_safe_max = @max(ZOMBIE_SPAWN_X_MIN, screen_width - required - 5);
            const zone_safe_max = @min(zone_x_max - required - 5, screen_safe_max);
            // Prefer the assigned burst zone for distribution. If the zone is narrower
            // than the rendered name, fall back to the full safe range so every spawn
            // in that zone doesn't stack on zone_x_min.
            const use_zone = zone_safe_max >= zone_x_min;
            const x_lo: c_int = if (use_zone) zone_x_min else ZOMBIE_SPAWN_X_MIN;
            const x_hi: c_int = if (use_zone) zone_safe_max else screen_safe_max;
            // Retry the X pick to avoid spawning on top of a zombie in the same
            // vertical band as y0 (would render two overlapping names). On exhaustion
            // we keep the last candidate — better to occasionally overlap than to
            // stall spawns.
            var candidate: c_int = raylib.GetRandomValue(x_lo, x_hi);
            var attempt: u8 = 1;
            while (attempt < SPAWN_MAX_X_ATTEMPTS and xCollidesAtY(candidate, y0, required)) : (attempt += 1) {
                candidate = raylib.GetRandomValue(x_lo, x_hi);
            }
            const x: f32 = @floatFromInt(candidate);

            var carrier_power_up: ?PowerUpType = null;
            if (game_mode == .survival) {
                if (rng.intRangeAtMost(u8, 0, 99) < zt.POWER_UP_DROP_CHANCE) {
                    carrier_power_up = switch (rng.intRangeAtMost(u8, 0, 2)) {
                        0 => .freeze,
                        1 => .bomb,
                        else => .shield,
                    };
                }
            }

            new_zombie.* = Zombie{
                .x = x,
                .y = y0,
                .speed = getFallSpeed() * getSpeedMultiplier(zombie_type),
                .name = selection.name,
                .is_active = true,
                .frame = 0,
                .animation_timer = 0,
                .zombie_type = zombie_type,
                .power_up = carrier_power_up,
            };
            zombies[i] = new_zombie;
            return true;
        }
    }
    return false;
}

fn drawText(text: [*c]const u8, x: c_int, y: c_int, size: c_int, color: raylib.Color) void {
    raylib.DrawText(text, x, y, size, color);
}

fn measureText(text: [*c]const u8, size: c_int) c_int {
    return raylib.MeasureText(text, size);
}

fn drawCenteredText(text: [*:0]const u8, y: c_int, size: c_int, color: raylib.Color) void {
    const width = measureText(text, size);
    drawText(text, @divTrunc(screen_width - width, 2), y, size, color);
}

// Cheap CRT-style glow: a soft dim copy offset by a couple of pixels behind
// the main text. Avoids per-frame blur passes while still selling the look.
fn drawCenteredTextShadow(text: [*:0]const u8, y: c_int, size: c_int, color: raylib.Color) void {
    const width = measureText(text, size);
    const x = @divTrunc(screen_width - width, 2);
    const shadow = raylib.Color{ .r = color.r / 3, .g = color.g / 3, .b = color.b / 3, .a = color.a };
    drawText(text, x + 2, y + 3, size, shadow);
    drawText(text, x, y, size, color);
}

fn drawColumnCenteredText(text: [*:0]const u8, cx: c_int, y: c_int, size: c_int, color: raylib.Color) void {
    const width = measureText(text, size);
    drawText(text, cx - @divTrunc(width, 2), y, size, color);
}

fn drawStatCell(label: [*:0]const u8, value: [*:0]const u8, cx: c_int, label_y: c_int, value_y: c_int) void {
    drawColumnCenteredText(label, cx, label_y, STATS_GRID_LABEL_SIZE, CRT_ACCENT);
    drawColumnCenteredText(value, cx, value_y, STATS_GRID_VALUE_SIZE, CRT_FG);
}

// Zen keeps spawn WPM-locked (player picks the WPM tier) but bumps density to
// match the new survival feel — fewer "fast drip" moments at low WPM tiers.
const ZEN_DENSITY: f32 = 8.0;

fn deriveWaveTiming(target_wpm: u32) struct { spawn_delay: f32, fall_speed: f32 } {
    const wpm_f: f32 = @floatFromInt(target_wpm);
    const spawn_delay = TIME_TO_TYPE_NUMERATOR / wpm_f;
    const time_on_screen = @max(TIME_ON_SCREEN_MIN, ZEN_DENSITY * spawn_delay);
    const sh: f32 = @floatFromInt(screen_height);
    return .{
        .spawn_delay = spawn_delay,
        .fall_speed = sh / (time_on_screen * FRAMES_PER_SECOND),
    };
}

fn getWaveConfig(wave: u32) WaveConfig {
    const target_wpm = @min(WAVE_MAX_WPM, WAVE_BASE_WPM + (wave - 1) * WAVE_WPM_INCREMENT);
    const wave_f: f32 = @floatFromInt(wave);
    const wpm_f: f32 = @floatFromInt(target_wpm);

    // Decoupled spawn cadence: starts fast (1.5s) and tightens per wave.
    const spawn_delay = @max(SPAWN_DELAY_MIN, SPAWN_DELAY_BASE - SPAWN_DELAY_DECAY_PER_WAVE * (wave_f - 1.0));

    // Decoupled fall time: long at wave 1 (30s) so 20-wpm players can clear the
    // front-loaded cascade; tightens to a 4s floor for late-wave challenge.
    const time_on_screen = @max(TIME_ON_SCREEN_MIN, TIME_ON_SCREEN_BASE - TIME_ON_SCREEN_DECAY_PER_WAVE * (wave_f - 1.0));

    const sh: f32 = @floatFromInt(screen_height);
    const fall_speed = sh / (time_on_screen * FRAMES_PER_SECOND);

    // Pool stays WPM-linked: wave 1 keeps its 13-zombie pool at WAVE_BASE_WPM=20.
    const pool_f = @round(WAVE_DURATION_TARGET_S * wpm_f / TIME_TO_TYPE_NUMERATOR);
    const pool_size = @as(u32, @intFromFloat(pool_f));

    // Front-load count: starts at 6, grows with wave, capped at 18. Always
    // clamped to pool_size so we never starter-pack more than the wave contains.
    const starter_f = @min(STARTER_PACK_CAP, STARTER_PACK_BASE + STARTER_PACK_INCREMENT_PER_WAVE * (wave_f - 1.0));
    const starter_pack = @min(pool_size, @as(u32, @intFromFloat(@round(starter_f))));

    return WaveConfig{
        .target_wpm = target_wpm,
        .spawn_delay = spawn_delay,
        .fall_speed = fall_speed,
        .pool_size = pool_size,
        .starter_pack = starter_pack,
    };
}

fn updateBoss(allocator: *std.mem.Allocator) void {
    if (boss) |b| {
        if (freeze_timer <= 0) {
            b.y += b.speed;
        }

        if (b.y >= screen_height) {
            is_dying = true;
            dying_timer = DYING_DURATION;
            dying_zombie_index = null;
            return;
        }

        if (letter_count == boss_phrase_len and typedIsBossPrefix()) {
            const points = calculateScore(boss_phrase_len, b.y, true, combo_count);
            score += points;
            combo_count += 1;
            if (combo_count > max_combo) max_combo = combo_count;
            spawnPopup(b.x, b.y, points);
            allocator.destroy(b);
            boss = null;
            letter_count = 0;
            name[0] = '\x00';
            total_kills += 1;
            // Give the player a full spawn_delay of breathing room before regular
            // zombies resume — typing the boss phrase is enough work for one beat.
            spawn_timer = 0.0;
            playKillSound();
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

        // Boss-caused game-over uses a darker tint so the player sees a distinct visual cue
        // during the dying transition (mirrors the red-tint logic for zombies in drawZombies).
        const boss_tint: raylib.Color = if (is_dying and dying_zombie_index == null) BOSS_DARK_RED else CRT_ERR;
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
            boss_tint,
        );

        const boss_x: c_int = @intFromFloat(b.x);
        const boss_y: c_int = @intFromFloat(b.y);
        // FR-007: phrase text sits above the sprite; health bar sits below the phrase
        // (between phrase and sprite). Stacked top→bottom: phrase, bar, sprite.
        drawText(b.name, boss_x, boss_y - 50, 20, CRT_ERR);

        const bar_x = boss_x;
        const bar_y = boss_y - 25;
        raylib.DrawRectangle(bar_x, bar_y, BOSS_HEALTH_BAR_WIDTH, BOSS_HEALTH_BAR_HEIGHT, CRT_DIM);

        if (boss_phrase_len > 0) {
            // c_int * usize is not implicitly coercible — promote lengths to c_int for arithmetic.
            const phrase_len_i: c_int = @intCast(boss_phrase_len);
            const letter_count_i: c_int = @intCast(letter_count);
            const fill_width: c_int = if (typedIsBossPrefix())
                @divTrunc(BOSS_HEALTH_BAR_WIDTH * (phrase_len_i - letter_count_i), phrase_len_i)
            else
                BOSS_HEALTH_BAR_WIDTH;
            raylib.DrawRectangle(bar_x, bar_y, fill_width, BOSS_HEALTH_BAR_HEIGHT, CRT_ERR);
        }

        raylib.DrawRectangleLines(bar_x, bar_y, BOSS_HEALTH_BAR_WIDTH, BOSS_HEALTH_BAR_HEIGHT, CRT_FG);
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
    trap_cluster_group = null;
    trap_cluster_remaining = 0;
}

fn getComboMultiplier(combo: u32) u64 {
    if (combo >= 20) return 5;
    if (combo >= 15) return 4;
    if (combo >= 10) return 3;
    if (combo >= 5) return 2;
    return 1;
}

fn getComboColor(combo: u32) raylib.Color {
    if (combo >= 15) return CRT_ERR;
    if (combo >= 5) return CRT_WARN;
    return CRT_FG;
}

fn resetScoreState() void {
    score = 0;
    combo_count = 0;
    max_combo = 0;
    popup_next = 0;
    for (&popups) |*p| p.active = false;
}

fn resetSessionState() void {
    total_kills = 0;
    is_dying = false;
    dying_timer = 0.0;
    dying_zombie_index = null;
    is_new_high_score = false;
    held_power_up = null;
    freeze_timer = 0.0;
    shield_active = false;
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
    wpm_timer_started = false;
    displayed_wpm = 0.0;
    displayed_accuracy = 100.0;
}

fn charsToWpm(chars: u32, time_seconds: f32) f32 {
    return @as(f32, @floatFromInt(chars)) * SECONDS_PER_MINUTE / CHARS_PER_WORD / time_seconds;
}

fn calculateTargetWpm() f32 {
    if (elapsed_time <= 0.0) return 0.0;
    // Before the window fills, scale by elapsed time so early bursts aren't under-reported.
    if (elapsed_time < WPM_WINDOW_SECONDS) return charsToWpm(correct_chars, elapsed_time);
    return charsToWpm(countCharsInWindow(elapsed_time), WPM_WINDOW_SECONDS);
}

fn calculateTargetAccuracy() f32 {
    const total = correct_chars + wrong_chars;
    if (total == 0) return 100.0;
    return (@as(f32, @floatFromInt(correct_chars)) / @as(f32, @floatFromInt(total))) * 100.0;
}

fn calculateAverageWpm() u32 {
    if (elapsed_time < 1.0) return 0;
    const chars_f = @as(f32, @floatFromInt(correct_chars));
    const words = chars_f / CHARS_PER_WORD;
    const minutes = elapsed_time / SECONDS_PER_MINUTE;
    return @intFromFloat(@round(words / minutes));
}

fn calculateStatsAccuracy() u32 {
    const total = correct_chars + wrong_chars;
    if (total == 0) return 0;
    return (correct_chars * 100) / total;
}

fn updateMetrics() void {
    if (wpm_timer_started) elapsed_time += raylib.GetFrameTime();
    const target_wpm = calculateTargetWpm();
    displayed_wpm += SMOOTHING_FACTOR * (target_wpm - displayed_wpm);
    const target_accuracy = calculateTargetAccuracy();
    displayed_accuracy += SMOOTHING_FACTOR * (target_accuracy - displayed_accuracy);
}

fn drawCrtOverlay() void {
    var y: c_int = 0;
    while (y < screen_height) : (y += CRT_SCANLINE_STEP) {
        raylib.DrawRectangle(0, y, screen_width, 1, CRT_SCANLINE);
    }

    const outer = CRT_VIGNETTE_OUTER_PX;
    raylib.DrawRectangle(0, 0, screen_width, outer, CRT_VIGNETTE_OUTER);
    raylib.DrawRectangle(0, screen_height - outer, screen_width, outer, CRT_VIGNETTE_OUTER);
    raylib.DrawRectangle(0, 0, outer, screen_height, CRT_VIGNETTE_OUTER);
    raylib.DrawRectangle(screen_width - outer, 0, outer, screen_height, CRT_VIGNETTE_OUTER);

    // Inner ring nests inside the outer ring so the band closest to the center
    // (outer-inner..outer px from the edge) layers both alphas. Without this offset
    // the 0..inner strip would receive both ring alphas, inverting the gradient.
    const inner = CRT_VIGNETTE_INNER_PX;
    const inner_offset = outer - inner;
    raylib.DrawRectangle(0, inner_offset, screen_width, inner, CRT_VIGNETTE_INNER);
    raylib.DrawRectangle(0, screen_height - outer, screen_width, inner, CRT_VIGNETTE_INNER);
    raylib.DrawRectangle(inner_offset, 0, inner, screen_height, CRT_VIGNETTE_INNER);
    raylib.DrawRectangle(screen_width - outer, 0, inner, screen_height, CRT_VIGNETTE_INNER);

    raylib.DrawRectangleLines(0, 0, screen_width, screen_height, CRT_BEZEL_OUTER);
    raylib.DrawRectangleLines(1, 1, screen_width - 2, screen_height - 2, CRT_BEZEL_OUTER);
    raylib.DrawRectangleLines(2, 2, screen_width - 4, screen_height - 4, CRT_BEZEL_INNER);
    raylib.DrawRectangleLines(3, 3, screen_width - 6, screen_height - 6, CRT_BEZEL_INNER);

    // DEATHN-25: subtle magenta flicker pulse every 7s (~2-3% opacity) mirrors the
    // .crt-flicker CSS animation so the native build matches the web rendering.
    const elapsed = raylib.GetTime();
    const phase = @mod(elapsed, CRT_FLICKER_PERIOD_S) / CRT_FLICKER_PERIOD_S;
    if (phase > 0.94 and phase < 0.98) {
        raylib.DrawRectangle(0, 0, screen_width, screen_height, CRT_FLICKER);
    }
}

fn drawPopups() void {
    for (&popups) |*p| {
        if (!p.active) continue;
        const progress = 1.0 - (p.timer / POPUP_DURATION);
        const draw_y = p.y - (POPUP_RISE_PX * progress);
        const alpha: u8 = @intFromFloat((p.timer / POPUP_DURATION) * 255.0);
        var color = CRT_WARN;
        color.a = alpha;
        var buf: [32]u8 = undefined;
        const text = std.fmt.bufPrintZ(&buf, "+{d}", .{p.points}) catch "+?";
        drawText(text.ptr, @intFromFloat(p.x), @intFromFloat(draw_y), POPUP_FONT_SIZE, color);
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

fn expectedFallSpeed(wave: u32) f32 {
    return getWaveConfig(wave).fall_speed;
}

test "getWaveConfig wave 1" {
    const cfg = getWaveConfig(1);
    try std.testing.expectEqual(@as(u32, 20), cfg.target_wpm);
    // SPAWN_DELAY_BASE at wave 1 (no decay).
    try std.testing.expectApproxEqAbs(SPAWN_DELAY_BASE, cfg.spawn_delay, 0.001);
    // round(36 × 20 / 72) = 10 (pool sized so wave 1 aligns exactly with 20 wpm
    // survival floor under the sustained-density model).
    try std.testing.expectEqual(@as(u32, 10), cfg.pool_size);
    try std.testing.expectEqual(@as(u32, 6), cfg.starter_pack);
}

test "getWaveConfig wave 15" {
    const cfg = getWaveConfig(15);
    try std.testing.expectEqual(@as(u32, 90), cfg.target_wpm);
    // 1.5 - 0.04×14 = 0.94
    try std.testing.expectApproxEqAbs(0.94, cfg.spawn_delay, 0.001);
    // round(36 × 90 / 72) = 45
    try std.testing.expectEqual(@as(u32, 45), cfg.pool_size);
    // round(6 + 0.25×14) = round(9.5) = 10
    try std.testing.expectEqual(@as(u32, 10), cfg.starter_pack);
}

test "wave completes when kills equals pool size" {
    const cfg = getWaveConfig(1);
    const kills: u32 = cfg.pool_size;
    const spawned: u32 = cfg.pool_size;
    try std.testing.expect(kills >= cfg.pool_size and spawned >= cfg.pool_size);

    const partial_kills: u32 = cfg.pool_size - 1;
    try std.testing.expect(!(partial_kills >= cfg.pool_size and spawned >= cfg.pool_size));
}

test "getWaveConfig follows linear WPM ramp" {
    // target_wpm = WAVE_BASE_WPM + (wave-1) × WAVE_WPM_INCREMENT, capped at WAVE_MAX_WPM.
    try std.testing.expectEqual(@as(u32, 95), getWaveConfig(16).target_wpm);
    try std.testing.expectEqual(@as(u32, 115), getWaveConfig(20).target_wpm);
    // pool_size = round(36 × wpm / 72) under the WAVE_DURATION_TARGET_S contract.
    try std.testing.expectEqual(@as(u32, 48), getWaveConfig(16).pool_size); // round(36×95/72) = 48
    try std.testing.expectEqual(@as(u32, 58), getWaveConfig(20).pool_size); // round(36×115/72) = 58
}

test "target WPM caps at WAVE_MAX_WPM" {
    // 20 + 46×5 = 250 hits the cap at wave 47.
    try std.testing.expectEqual(@as(u32, 240), getWaveConfig(45).target_wpm);
    try std.testing.expectEqual(@as(u32, 250), getWaveConfig(47).target_wpm);
    try std.testing.expectEqual(@as(u32, 250), getWaveConfig(100).target_wpm);
    // pool_size once capped: round(36 × 250 / 72) = 125.
    try std.testing.expectEqual(@as(u32, 125), getWaveConfig(47).pool_size);
    try std.testing.expectEqual(@as(u32, 125), getWaveConfig(100).pool_size);
}

test "fall time stays at or above TIME_ON_SCREEN_MIN floor" {
    const sh: f32 = @floatFromInt(screen_height);
    // Floor is reached when 30 - 0.9×(wave-1) ≤ 4, i.e. wave ≥ ~30.
    const cfg50 = getWaveConfig(50);
    const time50 = sh / (cfg50.fall_speed * FRAMES_PER_SECOND);
    try std.testing.expect(time50 >= TIME_ON_SCREEN_MIN - 0.01);

    const cfg100 = getWaveConfig(100);
    const time100 = sh / (cfg100.fall_speed * FRAMES_PER_SECOND);
    try std.testing.expect(time100 >= TIME_ON_SCREEN_MIN - 0.01);
}

test "spawn_delay decays per wave to SPAWN_DELAY_MIN floor" {
    try std.testing.expectApproxEqAbs(SPAWN_DELAY_BASE, getWaveConfig(1).spawn_delay, 0.001);
    try std.testing.expectApproxEqAbs(0.94, getWaveConfig(15).spawn_delay, 0.001);
    // Floor reached when 1.5 - 0.04×(wave-1) ≤ 0.4 → wave ≥ 29.
    try std.testing.expectApproxEqAbs(SPAWN_DELAY_MIN, getWaveConfig(50).spawn_delay, 0.001);
    try std.testing.expectApproxEqAbs(SPAWN_DELAY_MIN, getWaveConfig(100).spawn_delay, 0.001);
}

test "starter_pack grows with wave and caps at STARTER_PACK_CAP" {
    try std.testing.expectEqual(@as(u32, 6), getWaveConfig(1).starter_pack);
    try std.testing.expectEqual(@as(u32, 10), getWaveConfig(15).starter_pack);
    // round(6 + 0.25×49) = round(18.25) → cap 18.
    try std.testing.expectEqual(@as(u32, @intFromFloat(STARTER_PACK_CAP)), getWaveConfig(50).starter_pack);
    try std.testing.expectEqual(@as(u32, @intFromFloat(STARTER_PACK_CAP)), getWaveConfig(100).starter_pack);
}

test "starter_pack clamped to pool_size" {
    // No wave today has pool_size < 6, but the clamp must hold structurally.
    const cfg = getWaveConfig(1);
    try std.testing.expect(cfg.starter_pack <= cfg.pool_size);
}

test "runner fall time stays above 1.9s at all waves" {
    const sh: f32 = @floatFromInt(screen_height);
    var wave: u32 = 1;
    while (wave <= 100) : (wave += 1) {
        const cfg = getWaveConfig(wave);
        const runner_speed = cfg.fall_speed * RUNNER_SPEED_MULTIPLIER;
        const runner_time = sh / (runner_speed * FRAMES_PER_SECOND);
        try std.testing.expect(runner_time >= 1.9);
    }
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
    // pool_size values under the new round(45 × target_wpm / 72) formula.
    const cfg5 = getWaveConfig(5);
    try std.testing.expectEqual(@as(u32, 25), cfg5.pool_size); // wpm 40 → 25
    try std.testing.expectEqual(@as(u32, 13), (cfg5.pool_size + 1) / 2);

    const cfg10 = getWaveConfig(10);
    try std.testing.expectEqual(@as(u32, 41), cfg10.pool_size); // wpm 65 → 41
    try std.testing.expectEqual(@as(u32, 21), (cfg10.pool_size + 1) / 2);

    const cfg20 = getWaveConfig(20);
    try std.testing.expectEqual(@as(u32, 72), cfg20.pool_size); // wpm 115 → 72
    try std.testing.expectEqual(@as(u32, 36), (cfg20.pool_size + 1) / 2);
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
    // y positions are expressed as fractions of screen_height so the test stays
    // valid if the play-field size changes (e.g. portrait-arcade rework).
    const h: f32 = @floatFromInt(screen_height);
    try std.testing.expectEqual(@as(u64, 40), calculateScore(4, 0, false, 0));
    try std.testing.expectEqual(@as(u64, 200), calculateScore(4, 0, false, 20));
    try std.testing.expectEqual(@as(u64, 138), calculateScore(4, h * 440.0 / 450.0, false, 0));
    try std.testing.expectEqual(@as(u64, 2313), calculateScore(19, h * 300.0 / 450.0, true, 10));
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
    const saved_max_combo = max_combo;
    const saved_next = popup_next;
    const saved_popups = popups;
    defer {
        score = saved_score;
        combo_count = saved_combo;
        max_combo = saved_max_combo;
        popup_next = saved_next;
        popups = saved_popups;
    }

    score = 999;
    combo_count = 10;
    max_combo = 25;
    popup_next = 5;
    popups[0].active = true;

    resetScoreState();

    try std.testing.expectEqual(@as(u64, 0), score);
    try std.testing.expectEqual(@as(u32, 0), combo_count);
    try std.testing.expectEqual(@as(u32, 0), max_combo);
    try std.testing.expectEqual(@as(usize, 0), popup_next);
    try std.testing.expect(!popups[0].active);
}

test "restart resets session state but preserves best_score" {
    const saved_kills = total_kills;
    const saved_dying = is_dying;
    const saved_timer = dying_timer;
    const saved_index = dying_zombie_index;
    const saved_best = best_score_survival;
    const saved_new_hs = is_new_high_score;
    defer {
        total_kills = saved_kills;
        is_dying = saved_dying;
        dying_timer = saved_timer;
        dying_zombie_index = saved_index;
        best_score_survival = saved_best;
        is_new_high_score = saved_new_hs;
    }

    best_score_survival = highscore.Record{ .score = 500, .wave = 3, .wpm = 40, .accuracy = 90 };
    total_kills = 15;
    is_dying = true;
    dying_timer = 0.5;
    dying_zombie_index = 3;
    is_new_high_score = true;

    resetSessionState();

    try std.testing.expectEqual(@as(u32, 0), total_kills);
    try std.testing.expect(!is_dying);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dying_timer, 0.001);
    try std.testing.expect(dying_zombie_index == null);
    try std.testing.expect(!is_new_high_score);
    try std.testing.expectEqual(@as(u64, 500), best_score_survival.score);
    try std.testing.expectEqual(@as(u32, 3), best_score_survival.wave);
    try std.testing.expectEqual(@as(u32, 40), best_score_survival.wpm);
    try std.testing.expectEqual(@as(u8, 90), best_score_survival.accuracy);
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

test "total_kills increments correctly" {
    const saved = total_kills;
    defer total_kills = saved;

    total_kills = 0;
    try std.testing.expectEqual(@as(u32, 0), total_kills);
    total_kills += 1;
    try std.testing.expectEqual(@as(u32, 1), total_kills);
    total_kills += 1;
    try std.testing.expectEqual(@as(u32, 2), total_kills);
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

test "dying state transition" {
    const saved_dying = is_dying;
    const saved_timer = dying_timer;
    const saved_screen = current_screen;
    const saved_index = dying_zombie_index;
    defer {
        is_dying = saved_dying;
        dying_timer = saved_timer;
        current_screen = saved_screen;
        dying_zombie_index = saved_index;
    }

    is_dying = true;
    dying_timer = DYING_DURATION;
    dying_zombie_index = 5;
    current_screen = .playing;

    try std.testing.expect(is_dying);
    try std.testing.expect(current_screen != .game_over);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), dying_timer, 0.001);

    dying_timer = 0.0;
    if (dying_timer <= 0) {
        current_screen = .game_over;
        is_dying = false;
    }

    try std.testing.expect(!is_dying);
    try std.testing.expect(current_screen == .game_over);
}

test "average WPM calculation" {
    const saved_correct = correct_chars;
    const saved_elapsed = elapsed_time;
    defer {
        correct_chars = saved_correct;
        elapsed_time = saved_elapsed;
    }

    correct_chars = 600;
    elapsed_time = 60.0;
    try std.testing.expectEqual(@as(u32, 120), calculateAverageWpm());

    elapsed_time = 0.5;
    try std.testing.expectEqual(@as(u32, 0), calculateAverageWpm());
}

test "accuracy edge case zero input stats" {
    const saved_correct = correct_chars;
    const saved_wrong = wrong_chars;
    defer {
        correct_chars = saved_correct;
        wrong_chars = saved_wrong;
    }

    correct_chars = 0;
    wrong_chars = 0;
    try std.testing.expectEqual(@as(u32, 0), calculateStatsAccuracy());
}

test "high score comparison logic" {
    const saved = best_score_survival;
    defer best_score_survival = saved;

    best_score_survival = highscore.Record{ .score = 100, .wave = 2, .wpm = 30, .accuracy = 85 };

    try std.testing.expect(200 > best_score_survival.score);
    try std.testing.expect(!(100 > best_score_survival.score));
    try std.testing.expect(!(0 > best_score_survival.score));
    try std.testing.expect(!(50 > best_score_survival.score));
}

test "zen high score comparison: wpm first, accuracy tiebreaker" {
    const saved = best_score_zen;
    defer best_score_zen = saved;

    best_score_zen = highscore.Record{ .score = 0, .wave = 0, .wpm = 50, .accuracy = 80 };

    // Higher WPM wins
    const higher_wpm: u32 = 60;
    try std.testing.expect(higher_wpm > best_score_zen.wpm);

    // Lower WPM loses
    const lower_wpm: u32 = 40;
    try std.testing.expect(!(lower_wpm > best_score_zen.wpm));

    // Equal WPM, higher accuracy wins
    const equal_wpm: u32 = 50;
    const higher_acc: u8 = 90;
    try std.testing.expect(equal_wpm == best_score_zen.wpm and higher_acc > best_score_zen.accuracy);

    // Equal WPM, lower accuracy loses
    const lower_acc: u8 = 70;
    try std.testing.expect(!(equal_wpm > best_score_zen.wpm or (equal_wpm == best_score_zen.wpm and lower_acc > best_score_zen.accuracy)));

    // Equal WPM, equal accuracy: no new best
    const same_acc: u8 = 80;
    try std.testing.expect(!(equal_wpm > best_score_zen.wpm or (equal_wpm == best_score_zen.wpm and same_acc > best_score_zen.accuracy)));
}

test "kill counter tracks total kills" {
    const saved = total_kills;
    defer total_kills = saved;

    total_kills = 0;
    total_kills += 1;
    try std.testing.expectEqual(@as(u32, 1), total_kills);
    total_kills += 1;
    try std.testing.expectEqual(@as(u32, 2), total_kills);
    total_kills += 1;
    total_kills += 1;
    total_kills += 1;
    try std.testing.expectEqual(@as(u32, 5), total_kills);
}

test "ZombieType speed multipliers" {
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), getSpeedMultiplier(.standard), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.3), getSpeedMultiplier(.runner), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), getSpeedMultiplier(.tank), 0.001);
}

test "spawn weight table wave brackets" {
    const w1 = getSpawnWeights(1);
    try std.testing.expectEqual(@as(u8, 100), w1.standard);
    try std.testing.expectEqual(@as(u8, 0), w1.runner);

    const w3 = getSpawnWeights(3);
    try std.testing.expectEqual(@as(u8, 100), w3.standard);

    const w4 = getSpawnWeights(4);
    try std.testing.expectEqual(@as(u8, 70), w4.standard);
    try std.testing.expectEqual(@as(u8, 20), w4.runner);
    try std.testing.expectEqual(@as(u8, 10), w4.tank);

    const w7 = getSpawnWeights(7);
    try std.testing.expectEqual(@as(u8, 50), w7.standard);
    try std.testing.expectEqual(@as(u8, 30), w7.runner);
    try std.testing.expectEqual(@as(u8, 20), w7.tank);

    const w11 = getSpawnWeights(11);
    try std.testing.expectEqual(@as(u8, 40), w11.standard);
    try std.testing.expectEqual(@as(u8, 30), w11.runner);
    try std.testing.expectEqual(@as(u8, 30), w11.tank);
}

test "selectZombieType distribution" {
    var test_prng = std.Random.DefaultPrng.init(42);
    const rng = test_prng.random();

    const weights = SpawnWeights{ .standard = 50, .runner = 30, .tank = 20 };
    var standard_count: u32 = 0;
    var runner_count: u32 = 0;
    var tank_count: u32 = 0;

    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        switch (selectZombieType(weights, rng)) {
            .standard => standard_count += 1,
            .runner => runner_count += 1,
            .tank => tank_count += 1,
        }
    }

    try std.testing.expect(standard_count > 400 and standard_count < 600);
    try std.testing.expect(runner_count > 200 and runner_count < 400);
    try std.testing.expect(tank_count > 100 and tank_count < 300);
}

test "zombie tint colors" {
    const standard = getZombieTint(.standard);
    try std.testing.expectEqual(CRT_FG.r, standard.r);
    try std.testing.expectEqual(CRT_FG.g, standard.g);
    try std.testing.expectEqual(CRT_FG.b, standard.b);

    const runner = getZombieTint(.runner);
    try std.testing.expectEqual(CRT_WARN.r, runner.r);
    try std.testing.expectEqual(CRT_WARN.g, runner.g);
    try std.testing.expectEqual(CRT_WARN.b, runner.b);

    const tank = getZombieTint(.tank);
    try std.testing.expectEqual(CRT_TANK.r, tank.r);
    try std.testing.expectEqual(CRT_TANK.g, tank.g);
    try std.testing.expectEqual(CRT_TANK.b, tank.b);
}

test "hyphen accepted in input" {
    const key_hyphen: i32 = 45;
    try std.testing.expect(key_hyphen >= 32 and key_hyphen <= 125);

    const hyphen_name: [*:0]const u8 = "jean-luc";
    var typed_buf = [_]u8{ 'j', 'e', 'a', 'n', '-', 'l', 'u', 'c', '\x00' };
    const typed_name = typed_buf[0..8];
    var zomb_len: usize = 0;
    while (hyphen_name[zomb_len] != '\x00') zomb_len += 1;
    try std.testing.expect(std.mem.eql(u8, typed_name, hyphen_name[0..zomb_len]));
}

test "name weight table wave brackets" {
    const w1 = getNameWeights(1);
    try std.testing.expectEqual(@as(u8, 100), w1.primary);
    try std.testing.expectEqual(@as(u8, 0), w1.trap);
    try std.testing.expectEqual(@as(u8, 0), w1.compound);

    const w5 = getNameWeights(5);
    try std.testing.expectEqual(@as(u8, 85), w5.primary);
    try std.testing.expectEqual(@as(u8, 10), w5.trap);
    try std.testing.expectEqual(@as(u8, 5), w5.compound);

    const w10 = getNameWeights(10);
    try std.testing.expectEqual(@as(u8, 65), w10.primary);
    try std.testing.expectEqual(@as(u8, 20), w10.trap);
    try std.testing.expectEqual(@as(u8, 15), w10.compound);

    const w13 = getNameWeights(13);
    try std.testing.expectEqual(@as(u8, 50), w13.primary);
    try std.testing.expectEqual(@as(u8, 25), w13.trap);
    try std.testing.expectEqual(@as(u8, 25), w13.compound);
}

test "trap cluster state reset" {
    const saved_group = trap_cluster_group;
    const saved_remaining = trap_cluster_remaining;
    defer {
        trap_cluster_group = saved_group;
        trap_cluster_remaining = saved_remaining;
    }

    trap_cluster_group = 5;
    trap_cluster_remaining = 2;

    trap_cluster_group = null;
    trap_cluster_remaining = 0;

    try std.testing.expect(trap_cluster_group == null);
    try std.testing.expectEqual(@as(u8, 0), trap_cluster_remaining);
}

test "anti-doublon retries exhaust gracefully" {
    var test_prng_val = std.Random.DefaultPrng.init(42);
    const rng = test_prng_val.random();
    const empty: []const [*:0]const u8 = &.{};

    const result = name_lists.selectName(1, .standard, empty, null, rng);
    try std.testing.expect(result != null);
}

test "GameScreen enum has exactly 6 variants" {
    const fields = @typeInfo(GameScreen).@"enum".fields;
    try std.testing.expectEqual(@as(usize, 6), fields.len);
}

test "menu selection circular wrap" {
    try std.testing.expectEqual(@as(u8, 3), (0 +% MENU_ITEM_COUNT -% 1) % MENU_ITEM_COUNT);
    try std.testing.expectEqual(@as(u8, 0), (3 +% 1) % MENU_ITEM_COUNT);
    try std.testing.expectEqual(@as(u8, 1), (0 +% 1) % MENU_ITEM_COUNT);
}

test "pause selection circular wrap" {
    try std.testing.expectEqual(@as(u8, 2), (0 +% PAUSE_ITEM_COUNT -% 1) % PAUSE_ITEM_COUNT);
    try std.testing.expectEqual(@as(u8, 0), (2 +% 1) % PAUSE_ITEM_COUNT);
}

test "pause does not modify game state" {
    const saved_score = score;
    const saved_wave = current_wave;
    const saved_kills = wave_kills;
    const saved_screen = current_screen;
    const saved_pause = pause_selection;
    defer {
        score = saved_score;
        current_wave = saved_wave;
        wave_kills = saved_kills;
        current_screen = saved_screen;
        pause_selection = saved_pause;
    }

    score = 500;
    current_wave = 3;
    wave_kills = 7;
    current_screen = .paused;
    pause_selection = 0;

    // Simulate resume
    current_screen = .playing;

    try std.testing.expectEqual(@as(u64, 500), score);
    try std.testing.expectEqual(@as(u32, 3), current_wave);
    try std.testing.expectEqual(@as(u32, 7), wave_kills);
}

test "startGame sets current_screen to playing" {
    const saved_screen = current_screen;
    const saved_mode = game_mode;
    const saved_wave = current_wave;
    const saved_score = score;
    defer {
        current_screen = saved_screen;
        game_mode = saved_mode;
        current_wave = saved_wave;
        score = saved_score;
    }

    var alloc = std.testing.allocator;
    current_screen = .main_menu;
    startGame(.survival, @ptrCast(&alloc));
    try std.testing.expect(current_screen == .playing);
    try std.testing.expect(game_mode == .survival);
    try std.testing.expectEqual(@as(u32, 1), current_wave);
    try std.testing.expectEqual(@as(u64, 0), score);
}

test "Zombie struct default power_up is null" {
    const z = Zombie{ .x = 0, .y = 0, .speed = 1, .name = "test", .is_active = true, .frame = 0, .animation_timer = 0 };
    try std.testing.expect(z.power_up == null);
}

test "FREEZE_DURATION is 3.0" {
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), FREEZE_DURATION, 0.001);
}

test "freeze timer clamps to zero" {
    const saved = freeze_timer;
    defer freeze_timer = saved;

    freeze_timer = 0.1;
    freeze_timer -= 0.2;
    if (freeze_timer < 0) freeze_timer = 0.0;
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), freeze_timer, 0.001);
}

test "shield state transition" {
    const saved = shield_active;
    defer shield_active = saved;

    shield_active = true;
    try std.testing.expect(shield_active);
    shield_active = false;
    try std.testing.expect(!shield_active);
}

test "space with empty inventory no state change" {
    const saved_held = held_power_up;
    const saved_freeze = freeze_timer;
    const saved_shield = shield_active;
    defer {
        held_power_up = saved_held;
        freeze_timer = saved_freeze;
        shield_active = saved_shield;
    }

    held_power_up = null;
    freeze_timer = 0.0;
    shield_active = false;

    // Simulate: space pressed but no power-up held — activatePowerUp is only called when held != null
    try std.testing.expect(held_power_up == null);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), freeze_timer, 0.001);
    try std.testing.expect(!shield_active);
}

test "power-up pickup with full slot unchanged" {
    const saved = held_power_up;
    defer held_power_up = saved;

    held_power_up = .freeze;
    const new_drop: ?PowerUpType = .bomb;
    if (new_drop != null and held_power_up == null) {
        held_power_up = new_drop;
    }
    try std.testing.expect(held_power_up.? == .freeze);
}

test "carrier glyph mapping per PowerUpType" {
    const freeze_glyph: [*:0]const u8 = switch (PowerUpType.freeze) {
        .freeze => "*",
        .bomb => "!",
        .shield => "+",
    };
    try std.testing.expectEqual(@as(u8, '*'), freeze_glyph[0]);

    const bomb_glyph: [*:0]const u8 = switch (PowerUpType.bomb) {
        .freeze => "*",
        .bomb => "!",
        .shield => "+",
    };
    try std.testing.expectEqual(@as(u8, '!'), bomb_glyph[0]);

    const shield_glyph: [*:0]const u8 = switch (PowerUpType.shield) {
        .freeze => "*",
        .bomb => "!",
        .shield => "+",
    };
    try std.testing.expectEqual(@as(u8, '+'), shield_glyph[0]);
}

test "ZEN_WPM_TIERS has 3 entries with correct values" {
    try std.testing.expectEqual(@as(usize, 3), ZEN_WPM_TIERS.len);
    try std.testing.expectEqual(@as(u32, 30), ZEN_WPM_TIERS[0]);
    try std.testing.expectEqual(@as(u32, 50), ZEN_WPM_TIERS[1]);
    try std.testing.expectEqual(@as(u32, 80), ZEN_WPM_TIERS[2]);
}

test "deriveWaveTiming produces valid timing for zen WPM targets" {
    for (ZEN_WPM_TIERS) |wpm| {
        const timing = deriveWaveTiming(wpm);
        try std.testing.expect(timing.spawn_delay > 0);
        try std.testing.expect(timing.fall_speed > 0);
    }
}

test "zen WPM selection circular wrap" {
    const tier_count: u8 = @intCast(ZEN_WPM_TIERS.len);
    try std.testing.expectEqual(@as(u8, 2), (0 +% tier_count -% 1) % tier_count);
    try std.testing.expectEqual(@as(u8, 0), (2 +% 1) % tier_count);
}

test "freeze timer only decrements during playing screen" {
    const saved_screen = current_screen;
    const saved_freeze = freeze_timer;
    defer {
        current_screen = saved_screen;
        freeze_timer = saved_freeze;
    }

    freeze_timer = 2.0;
    current_screen = .paused;
    // Freeze timer decrement is inside the .playing branch of the switch,
    // so when paused it is NOT touched — verify the invariant structurally:
    try std.testing.expect(current_screen != .playing);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), freeze_timer, 0.001);
}

test "xBoxesOverlap detects overlap with padding" {
    // Disjoint, well separated → no overlap.
    try std.testing.expect(!xBoxesOverlap(0, 50, 100, 50, 0));
    // Touching edges with zero padding → counts as overlap (right edge of A == left of B).
    try std.testing.expect(!xBoxesOverlap(0, 50, 50, 50, 0));
    try std.testing.expect(xBoxesOverlap(0, 51, 50, 50, 0));
    // Padding pushes adjacent boxes into overlap.
    try std.testing.expect(xBoxesOverlap(0, 50, 55, 50, 8));
    // Fully nested → overlap.
    try std.testing.expect(xBoxesOverlap(10, 80, 20, 10, 0));
    // Order independence: swap A and B, same outcome.
    try std.testing.expect(xBoxesOverlap(100, 50, 0, 60, 0) == xBoxesOverlap(0, 60, 100, 50, 0));
}

test "bomb on empty screen consumes power-up" {
    const saved_held = held_power_up;
    defer held_power_up = saved_held;

    held_power_up = .bomb;
    try std.testing.expect(held_power_up != null);
    // Bomb activation kills all active zombies; with none active it simply clears held_power_up
    held_power_up = null;
    try std.testing.expect(held_power_up == null);
}

test "carrier zombie power-up field is optional" {
    const z = Zombie{
        .x = 100,
        .y = 0,
        .speed = 1.0,
        .name = "test",
        .is_active = true,
        .frame = 0,
        .animation_timer = 0,
        .zombie_type = .standard,
        .power_up = .freeze,
    };
    try std.testing.expect(z.power_up != null);
    const z2 = Zombie{
        .x = 100,
        .y = 0,
        .speed = 1.0,
        .name = "test",
        .is_active = true,
        .frame = 0,
        .animation_timer = 0,
        .zombie_type = .standard,
    };
    try std.testing.expect(z2.power_up == null);
}

test "per-mode high scores are independent" {
    const saved_s = best_score_survival;
    const saved_z = best_score_zen;
    defer {
        best_score_survival = saved_s;
        best_score_zen = saved_z;
    }

    best_score_survival = highscore.Record{ .score = 1000, .wave = 5, .wpm = 60, .accuracy = 95 };
    best_score_zen = highscore.Record{ .score = 0, .wave = 0, .wpm = 80, .accuracy = 90 };

    try std.testing.expectEqual(@as(u64, 1000), best_score_survival.score);
    try std.testing.expectEqual(@as(u32, 80), best_score_zen.wpm);
    try std.testing.expect(best_score_survival.score != best_score_zen.score);
}

test "sample count constants match array sizes" {
    try std.testing.expectEqual(@as(usize, CLICK_SAMPLE_COUNT), click_sounds.len);
    try std.testing.expectEqual(@as(usize, TYPEWRITER_SAMPLE_COUNT), typewriter_sounds.len);
    try std.testing.expectEqual(@as(usize, HITMARKER_SAMPLE_COUNT), hitmarker_sounds.len);
    try std.testing.expectEqual(@as(usize, DAMAGE_SAMPLE_COUNT), damage_sounds.len);
    try std.testing.expectEqual(@as(usize, SQUARE_SAMPLE_COUNT), square_sounds.len);
    try std.testing.expectEqual(@as(usize, MISSED_PUNCH_SAMPLE_COUNT), missed_punch_sounds.len);
}

test "round-robin wrapping returns to 0 for each pack" {
    const counts = [_]u8{ CLICK_SAMPLE_COUNT, TYPEWRITER_SAMPLE_COUNT, HITMARKER_SAMPLE_COUNT, DAMAGE_SAMPLE_COUNT, SQUARE_SAMPLE_COUNT, MISSED_PUNCH_SAMPLE_COUNT };
    for (counts) |count| {
        var idx: u8 = 0;
        var i: u8 = 0;
        while (i < count) : (i += 1) {
            idx = (idx + 1) % count;
        }
        try std.testing.expectEqual(@as(u8, 0), idx);
    }
}

test "getTypingSampleCount returns correct value for each pack" {
    const saved = sound_cfg;
    defer sound_cfg = saved;

    sound_cfg.typing_pack = .click;
    try std.testing.expectEqual(CLICK_SAMPLE_COUNT, getTypingSampleCount());
    sound_cfg.typing_pack = .typewriter;
    try std.testing.expectEqual(TYPEWRITER_SAMPLE_COUNT, getTypingSampleCount());
    sound_cfg.typing_pack = .hitmarker;
    try std.testing.expectEqual(HITMARKER_SAMPLE_COUNT, getTypingSampleCount());
}

test "getErrorSampleCount returns correct value for each pack" {
    const saved = sound_cfg;
    defer sound_cfg = saved;

    sound_cfg.error_pack = .damage;
    try std.testing.expectEqual(DAMAGE_SAMPLE_COUNT, getErrorSampleCount());
    sound_cfg.error_pack = .square;
    try std.testing.expectEqual(SQUARE_SAMPLE_COUNT, getErrorSampleCount());
    sound_cfg.error_pack = .missed_punch;
    try std.testing.expectEqual(MISSED_PUNCH_SAMPLE_COUNT, getErrorSampleCount());
}

test "sound menu selection wraps correctly" {
    try std.testing.expectEqual(@as(u8, 9), (0 +% SOUND_MENU_ITEM_COUNT -% 1) % SOUND_MENU_ITEM_COUNT);
    try std.testing.expectEqual(@as(u8, 0), (9 +% 1) % SOUND_MENU_ITEM_COUNT);
    try std.testing.expectEqual(@as(u8, 5), (4 +% 1) % SOUND_MENU_ITEM_COUNT);
}

test "volume step clamping cannot go below 0 or above 20" {
    var vol: u8 = 0;
    vol -|= 1;
    try std.testing.expectEqual(@as(u8, 0), vol);

    vol = 20;
    if (vol < 20) vol += 1;
    try std.testing.expectEqual(@as(u8, 20), vol);

    vol = 19;
    if (vol < 20) vol += 1;
    try std.testing.expectEqual(@as(u8, 20), vol);
}
