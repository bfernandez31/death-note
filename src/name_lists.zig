const std = @import("std");
const zt = @import("zombie_types.zig");

pub const NameCategory = enum {
    primary,
    compound,
    trap,
};

pub const TrapGroup = struct {
    names: []const [*:0]const u8,
};

pub const NameSelection = struct {
    name: [*:0]const u8,
    category: NameCategory,
    trap_group_index: ?usize,
};

pub fn cstrLen(s: [*:0]const u8) usize {
    var len: usize = 0;
    while (s[len] != '\x00') len += 1;
    return len;
}

pub const PrimaryNames = [_][*:0]const u8{
    // Original 49 names from zombie_names.zig
    "aaron",    "abby",     "adrian",   "aisha",    "akira",
    "alex",     "ali",      "amara",    "amir",     "ana",
    "anil",     "arjun",    "ava",      "bao",      "bella",
    "carlos",   "carmen",   "chin",     "dalia",    "daniel",
    "eli",      "emma",     "eric",     "fatima",   "felix",
    "gabriel",  "hana",     "igor",     "ivan",     "jack",
    "jane",     "juan",     "kai",      "lara",     "liam",
    "lina",     "maria",    "mila",     "nina",     "omar",
    "oscar",    "pablo",    "ravi",     "sara",     "seth",
    "tina",     "vera",     "yara",     "zane",
    // 300+ new names — short names (<=5 chars) for Runners
    "ada",      "amy",      "ann",      "ben",      "bob",
    "cal",      "cam",      "dan",      "dee",      "don",
    "ed",       "eva",      "fay",      "gus",      "hal",
    "ian",      "ida",      "jay",      "jim",      "jo",
    "joy",      "kay",      "ken",      "kim",      "kit",
    "lee",      "leo",      "les",      "liz",      "lou",
    "mae",      "max",      "meg",      "mo",       "nan",
    "ned",      "nia",      "noa",      "ora",      "pat",
    "ray",      "rex",      "rob",      "rod",      "ron",
    "roy",      "rue",      "sal",      "sam",      "sol",
    "sue",      "tad",      "ted",      "tom",      "uma",
    "val",      "van",      "vic",      "wen",      "wes",
    "yuri",     "zara",     "zoe",      "abel",     "alma",
    "amos",     "andy",     "axel",     "beth",     "boyd",
    "bree",     "burt",     "carl",     "cleo",     "cole",
    "cora",     "dale",     "dana",     "dara",     "dawn",
    "dean",     "dina",     "drew",     "duke",     "earl",
    "eden",     "edna",     "elsa",     "emil",     "enya",
    "esme",     "etta",     "evan",     "ezra",     "finn",
    "gabe",     "gail",     "gene",     "glen",     "greg",
    "gwen",     "hans",     "hope",     "hugo",     "ines",
    "iris",     "jade",     "jake",     "joel",     "jude",
    "june",     "kara",     "kate",     "kent",     "kira",
    "kurt",     "kyle",     "lars",     "leon",     "lily",
    "lisa",     "lois",     "lola",     "lucy",     "luke",
    "luna",     "lyle",     "lynn",     "macy",     "mara",
    "marc",     "mark",     "maud",     "maya",     "mona",
    "myra",     "neal",     "neil",     "nell",     "noel",
    "nora",     "olga",     "opal",     "otto",     "owen",
    "page",     "paul",     "peri",     "phil",     "reba",
    "reed",     "remy",     "rena",     "rhea",     "rica",
    "rick",     "rita",     "rosa",     "rose",     "ruby",
    "rudy",     "ruth",     "ryan",     "sage",     "sean",
    "shay",     "skye",     "thea",     "toby",     "todd",
    "tony",     "tori",     "troy",     "ty",       "vern",
    "wade",     "walt",     "will",     "xena",     "yael",
    // Trap-only names also mirrored here so they remain reachable via primary selection
    // (contract: TrapGroup names also appear in the searchable pool, not separate).
    "sera",     "sana",     "eris",
    // Medium-length names (6-7 chars)
    "albert",   "alexis",   "alfred",   "alicia",   "amelia",
    "andrea",   "angela",   "archie",   "arthur",   "austin",
    "bianca",   "bonnie",   "brenda",   "calvin",   "carla",
    "carter",   "cassie",   "claire",   "claude",   "connor",
    "cooper",   "curtis",   "dahlia",   "dakota",   "damien",
    "denise",   "dennis",   "derek",   "dexter",   "diana",
    "donald",   "donna",    "dorian",   "dustin",   "edward",
    "elaine",   "elena",    "elijah",   "ernest",   "esther",
    "eunice",   "evelyn",   "fabian",   "farrah",   "felice",
    "fiona",    "gaston",   "george",   "gerald",   "gideon",
    "gloria",   "gordon",   "gracie",   "gunnar",   "hannah",
    "harold",   "harvey",   "hayden",   "hector",   "helena",
    "herman",   "hilary",   "holden",   "ingrid",   "irene",
    "irving",   "isabel",   "jasper",   "jordan",   "josiah",
    "julian",   "kendra",   "kermit",   "landon",   "lauren",
    "leona",    "leslie",   "lester",   "lionel",   "louisa",
    "luther",   "maddox",   "marcus",   "marina",   "martin",
    "melvin",   "mercer",   "milton",   "monica",   "morgan",
    "morris",   "murray",   "nadine",   "nathan",   "nelson",
    "newton",   "nicole",   "noelle",   "norman",   "olivia",
    "palmer",   "parker",   "pascal",   "phoebe",   "pierce",
    "rachel",   "ramona",   "reeves",   "regina",   "renata",
    "robert",   "roland",   "rupert",   "sandra",   "selena",
    "sharon",   "sheila",   "shelly",   "simone",   "sophie",
    "stefan",   "stella",   "steven",   "stuart",   "sybil",
    "sylvia",   "tamara",   "teresa",   "thomas",   "travis",
    "trevor",   "trisha",   "ulrich",   "ursula",   "vaughn",
    "victor",   "violet",   "vivian",   "walter",   "wanda",
    "warren",   "wesley",   "willow",   "xavier",   "yvette",
    "yvonne",   "zelda",
    // Long names (>=8 chars) for Tanks
    "adelaide",  "adrienne",  "alejandro", "alphonse",  "angelica",
    "annabelle", "antonella", "augustus",  "beatrice",  "benedict",
    "benjamin",  "bernardo",  "brigitte",  "callista",  "cameron",
    "carolina",  "cassandra", "catalina",  "catharine", "celeste",
    "charlene",  "charlotte", "clarence",  "claudette", "clifford",
    "columbia",  "cordelia",  "courtney",  "demetrius", "dominic",
    "dorothea",  "ebenezer",  "eleonora",  "elizabeth", "emanuele",
    "esperanza", "estefania", "eustace",   "everette",  "fabrizio",
    "ferdinand", "florence",  "francesca", "franklin",  "frederic",
    "gabriella", "genevieve", "giovanni",  "giuseppe",  "graciela",
    "griffith",  "gulliver",  "harrison",  "hendrick",  "hezekiah",
    "humphrey",  "isabella",  "jacobson",  "jeanette",  "jennifer",
    "jonathan",  "josephine", "katharine", "kendrick",  "kimberly",
    "kingsley",  "lancelot",  "lavender",  "lawrence",  "leonardo",
    "lorraine",  "lucienne",  "madeline",  "magdalena", "marcello",
    "margaret",  "marianna",  "matthias",  "melchior",  "mercedes",
    "meredith",  "mitchell",  "mohammed",  "montague",  "murielle",
    "napoleon",  "nathaniel", "nicholas",  "octavius",  "patience",
    "patricia",  "penelope",  "percival",  "philippe",  "prudence",
    "raffaele",  "randolph",  "reginald",  "reinhold",  "robinson",
    "roderick",  "rosalind",  "rosamund",  "salvatore", "santiago",
    "scarlett",  "seraphina", "shepherd",  "siegfried", "sinclair",
    "stafford",  "stanford",  "sterling",  "sullivan",  "theodora",
    "theodore",  "thompson",  "valencia",  "valentin",  "vanessa",
    "victoria",  "vincenzo",  "virginia",  "vivienne",  "winthrop",
    "wolfgang",  "woodward",  "yoshiaki",  "zachariah",
};

pub const CompoundNames = [_][*:0]const u8{
    "jean-pierre",
    "anne-sophie",
    "marie-claire",
    "jean-claude",
    "jean-marc",
    "marie-jose",
    "anne-marie",
    "jean-paul",
    "jean-luc",
    "marie-anne",
    "jean-louis",
    "marie-eve",
    "anne-laure",
    "jean-michel",
    "marie-line",
    "jean-yves",
    "anne-lise",
    "marie-paule",
    "jean-rene",
    "jean-guy",
    "ana-maria",
    "karl-heinz",
    "hans-peter",
    "eva-marie",
    "jan-erik",
    "sven-erik",
    "per-olof",
    "lars-erik",
    "tor-arne",
    "nils-erik",
    "bo-anders",
};

pub const TrapGroups = [_]TrapGroup{
    .{ .names = &[_][*:0]const u8{ "liam", "lila", "lina" } },
    .{ .names = &[_][*:0]const u8{ "sara", "sera", "sana" } },
    .{ .names = &[_][*:0]const u8{ "eric", "erik", "eris" } },
    .{ .names = &[_][*:0]const u8{ "ana", "ava", "ada" } },
    .{ .names = &[_][*:0]const u8{ "carl", "cora", "cole" } },
    .{ .names = &[_][*:0]const u8{ "dean", "dana", "dawn" } },
    .{ .names = &[_][*:0]const u8{ "nora", "noel", "noa" } },
    .{ .names = &[_][*:0]const u8{ "leon", "leona", "leo" } },
    .{ .names = &[_][*:0]const u8{ "mara", "maya", "macy" } },
    .{ .names = &[_][*:0]const u8{ "jake", "jane", "jack" } },
    .{ .names = &[_][*:0]const u8{ "ryan", "remy", "rena" } },
    .{ .names = &[_][*:0]const u8{ "evan", "ezra", "eden" } },
    .{ .names = &[_][*:0]const u8{ "lily", "lisa", "lois" } },
    .{ .names = &[_][*:0]const u8{ "hugo", "hans", "hope" } },
    .{ .names = &[_][*:0]const u8{ "kate", "kara", "kent" } },
    // Long trap group — without at least one ≥TANK_MIN_NAME_LEN trap group, tank zombies
    // can never trigger a trap cluster because all short groups fail the length filter.
    .{ .names = &[_][*:0]const u8{ "catharine", "catalina", "carolina" } },
};

pub fn selectName(
    wave: u32,
    zombie_type: zt.ZombieType,
    active_names: []const [*:0]const u8,
    forced_trap_group: ?usize,
    rng: std.Random,
) ?NameSelection {
    var retries: u32 = 0;
    while (retries < zt.MAX_SPAWN_RETRIES) : (retries += 1) {
        const selection = pickCandidate(wave, zombie_type, forced_trap_group, rng) orelse continue;
        if (!isDuplicate(selection.name, active_names)) return selection;
    }
    return null;
}

fn pickCandidate(
    wave: u32,
    zombie_type: zt.ZombieType,
    forced_trap_group: ?usize,
    rng: std.Random,
) ?NameSelection {
    if (forced_trap_group) |group_idx| {
        if (group_idx < TrapGroups.len) {
            const group = TrapGroups[group_idx];
            const candidate = group.names[rng.intRangeAtMost(usize, 0, group.names.len - 1)];
            if (meetsLengthConstraint(candidate, zombie_type)) {
                return NameSelection{
                    .name = candidate,
                    .category = .trap,
                    .trap_group_index = group_idx,
                };
            }
        }
    }

    const weights = zt.getNameWeights(wave);
    const roll = rng.intRangeAtMost(u8, 0, 99);

    if (roll < weights.primary) {
        return pickFromPrimary(zombie_type, rng);
    } else if (roll < weights.primary + weights.trap) {
        return pickFromTrap(zombie_type, rng);
    } else {
        return pickFromCompound(zombie_type, rng);
    }
}

fn pickFromPrimary(zombie_type: zt.ZombieType, rng: std.Random) ?NameSelection {
    var attempts: u32 = 0;
    while (attempts < 50) : (attempts += 1) {
        const idx = rng.intRangeAtMost(usize, 0, PrimaryNames.len - 1);
        const candidate = PrimaryNames[idx];
        if (meetsLengthConstraint(candidate, zombie_type)) {
            return NameSelection{
                .name = candidate,
                .category = .primary,
                .trap_group_index = null,
            };
        }
    }
    return null;
}

fn pickFromTrap(zombie_type: zt.ZombieType, rng: std.Random) ?NameSelection {
    const group_idx = rng.intRangeAtMost(usize, 0, TrapGroups.len - 1);
    const group = TrapGroups[group_idx];
    const candidate = group.names[rng.intRangeAtMost(usize, 0, group.names.len - 1)];
    if (meetsLengthConstraint(candidate, zombie_type)) {
        return NameSelection{
            .name = candidate,
            .category = .trap,
            .trap_group_index = group_idx,
        };
    }
    return pickFromPrimary(zombie_type, rng);
}

fn pickFromCompound(zombie_type: zt.ZombieType, rng: std.Random) ?NameSelection {
    if (zombie_type == .runner) return pickFromPrimary(zombie_type, rng);
    const idx = rng.intRangeAtMost(usize, 0, CompoundNames.len - 1);
    const candidate = CompoundNames[idx];
    if (meetsLengthConstraint(candidate, zombie_type)) {
        return NameSelection{
            .name = candidate,
            .category = .compound,
            .trap_group_index = null,
        };
    }
    return pickFromPrimary(zombie_type, rng);
}

fn meetsLengthConstraint(n: [*:0]const u8, zombie_type: zt.ZombieType) bool {
    const len = cstrLen(n);
    return switch (zombie_type) {
        .runner => len <= zt.RUNNER_MAX_NAME_LEN,
        .tank => len >= zt.TANK_MIN_NAME_LEN,
        // Standards own the middle band (4–8 chars). Without this filter a long
        // compound like "Jean-Pierre" could spawn at normal speed and be unfair;
        // the new partition routes any ≥9-char name to tank automatically.
        .standard => len > zt.RUNNER_MAX_NAME_LEN and len <= zt.STANDARD_MAX_NAME_LEN,
    };
}

fn isDuplicate(candidate: [*:0]const u8, active_names: []const [*:0]const u8) bool {
    const candidate_len = cstrLen(candidate);
    const candidate_slice = candidate[0..candidate_len];
    for (active_names) |active| {
        const active_len = cstrLen(active);
        if (candidate_len == active_len and std.mem.eql(u8, candidate_slice, active[0..active_len])) return true;
    }
    return false;
}

test "primary list size" {
    try std.testing.expect(PrimaryNames.len >= 349);
}

test "all names ascii" {
    const all_lists = [_][]const [*:0]const u8{
        &PrimaryNames,
        &CompoundNames,
    };
    for (all_lists) |list| {
        for (list) |n| {
            const len = cstrLen(n);
            for (0..len) |i| {
                try std.testing.expect(n[i] >= 32 and n[i] <= 125);
            }
        }
    }
    for (TrapGroups) |group| {
        for (group.names) |n| {
            const len = cstrLen(n);
            for (0..len) |i| {
                try std.testing.expect(n[i] >= 32 and n[i] <= 125);
            }
        }
    }
}

test "compound names valid" {
    for (CompoundNames) |n| {
        const len = cstrLen(n);
        try std.testing.expect(len <= 20);
        for (0..len) |i| {
            const c = n[i];
            const valid = (c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z') or c == '-';
            try std.testing.expect(valid);
        }
    }
}

test "trap group sizes" {
    try std.testing.expect(TrapGroups.len >= 15);
    for (TrapGroups) |group| {
        try std.testing.expect(group.names.len >= 3);
        try std.testing.expect(group.names.len <= 5);
    }
}

test "sufficient runner names" {
    var count: usize = 0;
    for (PrimaryNames) |n| {
        if (cstrLen(n) <= zt.RUNNER_MAX_NAME_LEN) count += 1;
    }
    try std.testing.expect(count >= 30);
}

test "sufficient tank names" {
    // Count across every source the tank-eligible filter can draw from
    // (PrimaryNames + CompoundNames + TrapGroup entries). The narrowed
    // TANK_MIN_NAME_LEN partition leaves fewer ≥9-char primaries, but the
    // compounds carry the rest and the total pool stays comfortably above
    // the anti-doublon retry budget.
    var count: usize = 0;
    for (PrimaryNames) |n| {
        if (cstrLen(n) >= zt.TANK_MIN_NAME_LEN) count += 1;
    }
    for (CompoundNames) |n| {
        if (cstrLen(n) >= zt.TANK_MIN_NAME_LEN) count += 1;
    }
    for (TrapGroups) |group| {
        for (group.names) |n| {
            if (cstrLen(n) >= zt.TANK_MIN_NAME_LEN) count += 1;
        }
    }
    try std.testing.expect(count >= 30);
}

test "weight tables sum to 100" {
    for (zt.SPAWN_WEIGHT_TABLE) |w| {
        const sum = @as(u16, w.standard) + @as(u16, w.runner) + @as(u16, w.tank);
        try std.testing.expectEqual(@as(u16, 100), sum);
    }
    for (zt.NAME_WEIGHT_TABLE) |w| {
        const sum = @as(u16, w.primary) + @as(u16, w.trap) + @as(u16, w.compound);
        try std.testing.expectEqual(@as(u16, 100), sum);
    }
}

test "selectname anti-doublon" {
    var test_prng = std.Random.DefaultPrng.init(42);
    const rng = test_prng.random();

    var all_names: [PrimaryNames.len + CompoundNames.len + 100][*:0]const u8 = undefined;
    var idx: usize = 0;
    for (PrimaryNames) |n| {
        all_names[idx] = n;
        idx += 1;
    }
    for (CompoundNames) |n| {
        all_names[idx] = n;
        idx += 1;
    }
    for (TrapGroups) |group| {
        for (group.names) |n| {
            var already = false;
            for (all_names[0..idx]) |existing| {
                if (cstrLen(n) == cstrLen(existing) and std.mem.eql(u8, n[0..cstrLen(n)], existing[0..cstrLen(existing)])) {
                    already = true;
                    break;
                }
            }
            if (!already) {
                all_names[idx] = n;
                idx += 1;
            }
        }
    }

    const result = selectName(10, .standard, all_names[0..idx], null, rng);
    try std.testing.expect(result == null);
}

test "selectname length filtering" {
    var test_prng = std.Random.DefaultPrng.init(42);
    const rng = test_prng.random();
    const empty: []const [*:0]const u8 = &.{};

    var i: u32 = 0;
    while (i < 20) : (i += 1) {
        if (selectName(5, .runner, empty, null, rng)) |sel| {
            try std.testing.expect(cstrLen(sel.name) <= zt.RUNNER_MAX_NAME_LEN);
        }
    }
    i = 0;
    while (i < 20) : (i += 1) {
        if (selectName(8, .tank, empty, null, rng)) |sel| {
            try std.testing.expect(cstrLen(sel.name) >= zt.TANK_MIN_NAME_LEN);
        }
    }
}

test "selectname trap group preference" {
    var test_prng = std.Random.DefaultPrng.init(42);
    const rng = test_prng.random();
    const empty: []const [*:0]const u8 = &.{};

    var i: u32 = 0;
    while (i < 10) : (i += 1) {
        if (selectName(10, .standard, empty, 0, rng)) |sel| {
            if (sel.category == .trap) {
                try std.testing.expect(sel.trap_group_index != null);
                try std.testing.expectEqual(@as(usize, 0), sel.trap_group_index.?);
            }
        }
    }
}

test "runner names are short" {
    var test_prng = std.Random.DefaultPrng.init(123);
    const rng = test_prng.random();
    const empty: []const [*:0]const u8 = &.{};
    var i: u32 = 0;
    while (i < 50) : (i += 1) {
        if (selectName(6, .runner, empty, null, rng)) |sel| {
            try std.testing.expect(cstrLen(sel.name) <= zt.RUNNER_MAX_NAME_LEN);
        }
    }
}

test "tank names are long" {
    var test_prng = std.Random.DefaultPrng.init(123);
    const rng = test_prng.random();
    const empty: []const [*:0]const u8 = &.{};
    var i: u32 = 0;
    while (i < 50) : (i += 1) {
        if (selectName(9, .tank, empty, null, rng)) |sel| {
            try std.testing.expect(cstrLen(sel.name) >= zt.TANK_MIN_NAME_LEN);
        }
    }
}
