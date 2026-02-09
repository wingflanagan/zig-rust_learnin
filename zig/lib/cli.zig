const std = @import("std");

pub const ParseError = error{
    UnknownOption,
    MissingValue,
};

pub const OptionKind = enum {
    flag, // no value
    value, // requires value
};

pub const OptionSpec = struct {
    short: ?u8 = null, // e.g. 'a' for -a
    long: ?[]const u8 = null, // e.g. "all" for --all
    kind: OptionKind = .flag,
};

pub const Parsed = struct {
    // Store what you need. Keep it generic but usable.
    // For flags: set of seen short/long names
    // For values: map long->value, short->value
    // For positionals: list

    allocator: std.mem.Allocator,

    // For simplicity: store options encountered as strings and optional values.
    // You can later specialize per util.
    items: std.ArrayList(Item),
    positionals: std.ArrayList([]const u8),

    pub const Item = struct {
        name: []const u8, // "-a" or "--all" normalized however you want
        value: ?[]const u8 = null, // points into argv strings
    };

    pub fn deinit(self: *Parsed) void {
        self.items.deinit();
        self.positionals.deinit();
    }

    pub fn has(self: *const Parsed, name: []const u8) bool {
        for (self.items.items) |it| {
            if (std.mem.eql(u8, it.name, name) and it.value == null) return true;
        }
        return false;
    }

    pub fn get(self: *const Parsed, name: []const u8) ?[]const u8 {
        for (self.items.items) |it| {
            if (std.mem.eql(u8, it.name, name)) return it.value;
        }
        return null;
    }
};

fn matchSpec(specs: []const OptionSpec, token: []const u8) ?OptionSpec {
    // token is like "-a" or "--all"
    if (std.mem.startsWith(u8, token, "--")) {
        const key = token[2..];
        for (specs) |s| {
            if (s.long) |lname| {
                if (std.mem.eql(u8, key, lname)) return s;
            }
        }
    } else if (std.mem.startsWith(u8, token, "-") and token.len == 2) {
        const ch = token[1];
        for (specs) |s| {
            if (s.short) |sh| {
                if (ch == sh) return s;
            }
        }
    }
    return null;
}

pub fn parse(
    allocator: std.mem.Allocator,
    specs: []const OptionSpec,
    argv: []const []const u8,
) ParseError!Parsed {
    var out = Parsed{
        .allocator = allocator,
        .items = std.ArrayList(Parsed.Item).init(allocator),
        .positionals = std.ArrayList([]const u8).init(allocator),
    };

    var i: usize = 1; // skip argv[0]
    var stop_options = false;

    while (i < argv.len) : (i += 1) {
        const arg = argv[i];

        if (!stop_options and std.mem.eql(u8, arg, "--")) {
            stop_options = true;
            continue;
        }

        if (!stop_options and std.mem.startsWith(u8, arg, "--")) {
            // long option, maybe --key=value
            const eq = std.mem.indexOfScalar(u8, arg, '=');
            if (eq) |pos| {
                const name = arg[0..pos];
                const value = arg[pos + 1 ..];
                const spec = matchSpec(specs, name) orelse return error.UnknownOption;
                if (spec.kind != .value) return error.UnknownOption;

                try out.items.append(.{ .name = name, .value = value });
            } else {
                const spec = matchSpec(specs, arg) orelse return error.UnknownOption;
                if (spec.kind == .flag) {
                    try out.items.append(.{ .name = arg, .value = null });
                } else {
                    // needs value: next argv
                    if (i + 1 >= argv.len) return error.MissingValue;
                    i += 1;
                    try out.items.append(.{ .name = arg, .value = argv[i] });
                }
            }
            continue;
        }

        if (!stop_options and std.mem.startsWith(u8, arg, "-") and arg.len > 1) {
            // short options, potentially bundled: -alh or -oFILE?
            if (arg.len == 2) {
                // single -x
                const spec = matchSpec(specs, arg) orelse return error.UnknownOption;
                if (spec.kind == .flag) {
                    try out.items.append(.{ .name = arg, .value = null });
                } else {
                    if (i + 1 >= argv.len) return error.MissingValue;
                    i += 1;
                    try out.items.append(.{ .name = arg, .value = argv[i] });
                }
            } else {
                // bundle: -abc or -oFILE
                // Walk each letter; if one needs a value, consume rest or next argv.
                var j: usize = 1;
                while (j < arg.len) : (j += 1) {
                    const token = [_]u8{ '-', arg[j] };
                    const opt = token[0..2];
                    const spec = matchSpec(specs, opt) orelse return error.UnknownOption;

                    if (spec.kind == .flag) {
                        try out.items.append(.{ .name = opt, .value = null });
                        continue;
                    }

                    // value option: remainder is the value if present, else next argv
                    if (j + 1 < arg.len) {
                        const value = arg[j + 1 ..];
                        try out.items.append(.{ .name = opt, .value = value });
                    } else {
                        if (i + 1 >= argv.len) return error.MissingValue;
                        i += 1;
                        try out.items.append(.{ .name = opt, .value = argv[i] });
                    }
                    break; // value option ends the bundle
                }
            }
            continue;
        }

        // positional
        try out.positionals.append(arg);
    }

    return out;
}
