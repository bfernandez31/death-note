const std = @import("std");
const main = @import("main.zig");

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
    "Aaron",    "Abby",     "Adrian",   "Aisha",    "Akira",
    "Alex",     "Ali",      "Amara",    "Amir",     "Ana",
    "Anil",     "Arjun",    "Ava",      "Bao",      "Bella",
    "Carlos",   "Carmen",   "Chin",     "Dalia",    "Daniel",
    "Eli",      "Emma",     "Eric",     "Fatima",   "Felix",
    "Gabriel",  "Hana",     "Igor",     "Ivan",     "Jack",
    "Jane",     "Juan",     "Kai",      "Lara",     "Liam",
    "Lina",     "Maria",    "Mila",     "Nina",     "Omar",
    "Oscar",    "Pablo",    "Ravi",     "Sara",     "Seth",
    "Tina",     "Vera",     "Yara",     "Zane",
    // 300+ new names — short names (<=5 chars) for Runners
    "Ada",      "Amy",      "Ann",      "Ben",      "Bob",
    "Cal",      "Cam",      "Dan",      "Dee",      "Don",
    "Ed",       "Eva",      "Fay",      "Gus",      "Hal",
    "Ian",      "Ida",      "Jay",      "Jim",      "Jo",
    "Joy",      "Kay",      "Ken",      "Kim",      "Kit",
    "Lee",      "Leo",      "Les",      "Liz",      "Lou",
    "Mae",      "Max",      "Meg",      "Mo",       "Nan",
    "Ned",      "Nia",      "Noa",      "Ora",      "Pat",
    "Ray",      "Rex",      "Rob",      "Rod",      "Ron",
    "Roy",      "Rue",      "Sal",      "Sam",      "Sol",
    "Sue",      "Tad",      "Ted",      "Tom",      "Uma",
    "Val",      "Van",      "Vic",      "Wen",      "Wes",
    "Yuri",     "Zara",     "Zoe",      "Abel",     "Alma",
    "Amos",     "Andy",     "Axel",     "Beth",     "Boyd",
    "Bree",     "Burt",     "Carl",     "Cleo",     "Cole",
    "Cora",     "Dale",     "Dana",     "Dara",     "Dawn",
    "Dean",     "Dina",     "Drew",     "Duke",     "Earl",
    "Eden",     "Edna",     "Elsa",     "Emil",     "Enya",
    "Esme",     "Etta",     "Evan",     "Ezra",     "Finn",
    "Gabe",     "Gail",     "Gene",     "Glen",     "Greg",
    "Gwen",     "Hans",     "Hope",     "Hugo",     "Ines",
    "Iris",     "Jade",     "Jake",     "Joel",     "Jude",
    "June",     "Kara",     "Kate",     "Kent",     "Kira",
    "Kurt",     "Kyle",     "Lars",     "Leon",     "Lily",
    "Lisa",     "Lois",     "Lola",     "Lucy",     "Luke",
    "Luna",     "Lyle",     "Lynn",     "Macy",     "Mara",
    "Marc",     "Mark",     "Maud",     "Maya",     "Mona",
    "Myra",     "Neal",     "Neil",     "Nell",     "Noel",
    "Nora",     "Olga",     "Opal",     "Otto",     "Owen",
    "Page",     "Paul",     "Peri",     "Phil",     "Reba",
    "Reed",     "Remy",     "Rena",     "Rhea",     "Rica",
    "Rick",     "Rita",     "Rosa",     "Rose",     "Ruby",
    "Rudy",     "Ruth",     "Ryan",     "Sage",     "Sean",
    "Shay",     "Skye",     "Thea",     "Toby",     "Todd",
    "Tony",     "Tori",     "Troy",     "Ty",       "Vern",
    "Wade",     "Walt",     "Will",     "Xena",     "Yael",
    // Trap-only names also mirrored here so they remain reachable via primary selection
    // (contract: TrapGroup names also appear in the searchable pool, not separate).
    "Sera",     "Sana",     "Eris",
    // Medium-length names (6-7 chars)
    "Albert",   "Alexis",   "Alfred",   "Alicia",   "Amelia",
    "Andrea",   "Angela",   "Archie",   "Arthur",   "Austin",
    "Bianca",   "Bonnie",   "Brenda",   "Calvin",   "Carla",
    "Carter",   "Cassie",   "Claire",   "Claude",   "Connor",
    "Cooper",   "Curtis",   "Dahlia",   "Dakota",   "Damien",
    "Denise",   "Dennis",   "Derek",   "Dexter",   "Diana",
    "Donald",   "Donna",    "Dorian",   "Dustin",   "Edward",
    "Elaine",   "Elena",    "Elijah",   "Ernest",   "Esther",
    "Eunice",   "Evelyn",   "Fabian",   "Farrah",   "Felice",
    "Fiona",    "Gaston",   "George",   "Gerald",   "Gideon",
    "Gloria",   "Gordon",   "Gracie",   "Gunnar",   "Hannah",
    "Harold",   "Harvey",   "Hayden",   "Hector",   "Helena",
    "Herman",   "Hilary",   "Holden",   "Ingrid",   "Irene",
    "Irving",   "Isabel",   "Jasper",   "Jordan",   "Josiah",
    "Julian",   "Kendra",   "Kermit",   "Landon",   "Lauren",
    "Leona",    "Leslie",   "Lester",   "Lionel",   "Louisa",
    "Luther",   "Maddox",   "Marcus",   "Marina",   "Martin",
    "Melvin",   "Mercer",   "Milton",   "Monica",   "Morgan",
    "Morris",   "Murray",   "Nadine",   "Nathan",   "Nelson",
    "Newton",   "Nicole",   "Noelle",   "Norman",   "Olivia",
    "Palmer",   "Parker",   "Pascal",   "Phoebe",   "Pierce",
    "Rachel",   "Ramona",   "Reeves",   "Regina",   "Renata",
    "Robert",   "Roland",   "Rupert",   "Sandra",   "Selena",
    "Sharon",   "Sheila",   "Shelly",   "Simone",   "Sophie",
    "Stefan",   "Stella",   "Steven",   "Stuart",   "Sybil",
    "Sylvia",   "Tamara",   "Teresa",   "Thomas",   "Travis",
    "Trevor",   "Trisha",   "Ulrich",   "Ursula",   "Vaughn",
    "Victor",   "Violet",   "Vivian",   "Walter",   "Wanda",
    "Warren",   "Wesley",   "Willow",   "Xavier",   "Yvette",
    "Yvonne",   "Zelda",
    // Long names (>=8 chars) for Tanks
    "Adelaide",  "Adrienne",  "Alejandro", "Alphonse",  "Angelica",
    "Annabelle", "Antonella", "Augustus",  "Beatrice",  "Benedict",
    "Benjamin",  "Bernardo",  "Brigitte",  "Callista",  "Cameron",
    "Carolina",  "Cassandra", "Catalina",  "Catharine", "Celeste",
    "Charlene",  "Charlotte", "Clarence",  "Claudette", "Clifford",
    "Columbia",  "Cordelia",  "Courtney",  "Demetrius", "Dominic",
    "Dorothea",  "Ebenezer",  "Eleonora",  "Elizabeth", "Emanuele",
    "Esperanza", "Estefania", "Eustace",   "Everette",  "Fabrizio",
    "Ferdinand", "Florence",  "Francesca", "Franklin",  "Frederic",
    "Gabriella", "Genevieve", "Giovanni",  "Giuseppe",  "Graciela",
    "Griffith",  "Gulliver",  "Harrison",  "Hendrick",  "Hezekiah",
    "Humphrey",  "Isabella",  "Jacobson",  "Jeanette",  "Jennifer",
    "Jonathan",  "Josephine", "Katharine", "Kendrick",  "Kimberly",
    "Kingsley",  "Lancelot",  "Lavender",  "Lawrence",  "Leonardo",
    "Lorraine",  "Lucienne",  "Madeline",  "Magdalena", "Marcello",
    "Margaret",  "Marianna",  "Matthias",  "Melchior",  "Mercedes",
    "Meredith",  "Mitchell",  "Mohammed",  "Montague",  "Murielle",
    "Napoleon",  "Nathaniel", "Nicholas",  "Octavius",  "Patience",
    "Patricia",  "Penelope",  "Percival",  "Philippe",  "Prudence",
    "Raffaele",  "Randolph",  "Reginald",  "Reinhold",  "Robinson",
    "Roderick",  "Rosalind",  "Rosamund",  "Salvatore", "Santiago",
    "Scarlett",  "Seraphina", "Shepherd",  "Siegfried", "Sinclair",
    "Stafford",  "Stanford",  "Sterling",  "Sullivan",  "Theodora",
    "Theodore",  "Thompson",  "Valencia",  "Valentin",  "Vanessa",
    "Victoria",  "Vincenzo",  "Virginia",  "Vivienne",  "Winthrop",
    "Wolfgang",  "Woodward",  "Yoshiaki",  "Zachariah",
};

pub const CompoundNames = [_][*:0]const u8{
    "Jean-Pierre",
    "Anne-Sophie",
    "Marie-Claire",
    "Jean-Claude",
    "Jean-Marc",
    "Marie-Jose",
    "Anne-Marie",
    "Jean-Paul",
    "Jean-Luc",
    "Marie-Anne",
    "Jean-Louis",
    "Marie-Eve",
    "Anne-Laure",
    "Jean-Michel",
    "Marie-Line",
    "Jean-Yves",
    "Anne-Lise",
    "Marie-Paule",
    "Jean-Rene",
    "Jean-Guy",
    "Ana-Maria",
    "Karl-Heinz",
    "Hans-Peter",
    "Eva-Marie",
    "Jan-Erik",
    "Sven-Erik",
    "Per-Olof",
    "Lars-Erik",
    "Tor-Arne",
    "Nils-Erik",
    "Bo-Anders",
};

pub const TrapGroups = [_]TrapGroup{
    .{ .names = &[_][*:0]const u8{ "Liam", "Lila", "Lina" } },
    .{ .names = &[_][*:0]const u8{ "Sara", "Sera", "Sana" } },
    .{ .names = &[_][*:0]const u8{ "Eric", "Erik", "Eris" } },
    .{ .names = &[_][*:0]const u8{ "Ana", "Ava", "Ada" } },
    .{ .names = &[_][*:0]const u8{ "Carl", "Cora", "Cole" } },
    .{ .names = &[_][*:0]const u8{ "Dean", "Dana", "Dawn" } },
    .{ .names = &[_][*:0]const u8{ "Nora", "Noel", "Noa" } },
    .{ .names = &[_][*:0]const u8{ "Leon", "Leona", "Leo" } },
    .{ .names = &[_][*:0]const u8{ "Mara", "Maya", "Macy" } },
    .{ .names = &[_][*:0]const u8{ "Jake", "Jane", "Jack" } },
    .{ .names = &[_][*:0]const u8{ "Ryan", "Remy", "Rena" } },
    .{ .names = &[_][*:0]const u8{ "Evan", "Ezra", "Eden" } },
    .{ .names = &[_][*:0]const u8{ "Lily", "Lisa", "Lois" } },
    .{ .names = &[_][*:0]const u8{ "Hugo", "Hans", "Hope" } },
    .{ .names = &[_][*:0]const u8{ "Kate", "Kara", "Kent" } },
    // Long trap group — without at least one ≥TANK_MIN_NAME_LEN trap group, tank zombies
    // can never trigger a trap cluster because all short groups fail the length filter.
    .{ .names = &[_][*:0]const u8{ "Catharine", "Catalina", "Carolina" } },
};

pub fn selectName(
    wave: u32,
    zombie_type: main.ZombieType,
    active_names: []const [*:0]const u8,
    forced_trap_group: ?usize,
    rng: std.Random,
) ?NameSelection {
    var retries: u32 = 0;
    while (retries < main.MAX_SPAWN_RETRIES) : (retries += 1) {
        const selection = pickCandidate(wave, zombie_type, forced_trap_group, rng) orelse continue;
        if (!isDuplicate(selection.name, active_names)) return selection;
    }
    return null;
}

fn pickCandidate(
    wave: u32,
    zombie_type: main.ZombieType,
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

    const weights = main.getNameWeights(wave);
    const roll = rng.intRangeAtMost(u8, 0, 99);

    if (roll < weights.primary) {
        return pickFromPrimary(zombie_type, rng);
    } else if (roll < weights.primary + weights.trap) {
        return pickFromTrap(zombie_type, rng);
    } else {
        return pickFromCompound(zombie_type, rng);
    }
}

fn pickFromPrimary(zombie_type: main.ZombieType, rng: std.Random) ?NameSelection {
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

fn pickFromTrap(zombie_type: main.ZombieType, rng: std.Random) ?NameSelection {
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

fn pickFromCompound(zombie_type: main.ZombieType, rng: std.Random) ?NameSelection {
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

fn meetsLengthConstraint(n: [*:0]const u8, zombie_type: main.ZombieType) bool {
    const len = cstrLen(n);
    return switch (zombie_type) {
        .runner => len <= main.RUNNER_MAX_NAME_LEN,
        .tank => len >= main.TANK_MIN_NAME_LEN,
        .standard => true,
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

test "all names ASCII" {
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
        if (cstrLen(n) <= main.RUNNER_MAX_NAME_LEN) count += 1;
    }
    try std.testing.expect(count >= 30);
}

test "sufficient tank names" {
    var count: usize = 0;
    for (PrimaryNames) |n| {
        if (cstrLen(n) >= main.TANK_MIN_NAME_LEN) count += 1;
    }
    try std.testing.expect(count >= 30);
}

test "weight tables sum to 100" {
    for (main.SPAWN_WEIGHT_TABLE) |w| {
        const sum = @as(u16, w.standard) + @as(u16, w.runner) + @as(u16, w.tank);
        try std.testing.expectEqual(@as(u16, 100), sum);
    }
    for (main.NAME_WEIGHT_TABLE) |w| {
        const sum = @as(u16, w.primary) + @as(u16, w.trap) + @as(u16, w.compound);
        try std.testing.expectEqual(@as(u16, 100), sum);
    }
}

test "selectName anti-doublon" {
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

test "selectName length filtering" {
    var test_prng = std.Random.DefaultPrng.init(42);
    const rng = test_prng.random();
    const empty: []const [*:0]const u8 = &.{};

    var i: u32 = 0;
    while (i < 20) : (i += 1) {
        if (selectName(5, .runner, empty, null, rng)) |sel| {
            try std.testing.expect(cstrLen(sel.name) <= main.RUNNER_MAX_NAME_LEN);
        }
    }
    i = 0;
    while (i < 20) : (i += 1) {
        if (selectName(8, .tank, empty, null, rng)) |sel| {
            try std.testing.expect(cstrLen(sel.name) >= main.TANK_MIN_NAME_LEN);
        }
    }
}

test "selectName trap group preference" {
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
            try std.testing.expect(cstrLen(sel.name) <= main.RUNNER_MAX_NAME_LEN);
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
            try std.testing.expect(cstrLen(sel.name) >= main.TANK_MIN_NAME_LEN);
        }
    }
}
