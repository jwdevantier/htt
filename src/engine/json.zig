const std = @import("std");
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const Allocator = std.mem.Allocator;

pub fn loads(l: *Lua) i32 {
    return loads_(l) catch {
        l.pushNil();
        _ = l.pushString("failed to parse string");
        return 2;
    };
}

fn loads_(l: *Lua) !i32 {
    const jsonstr = l.checkString(1);
    const a: Allocator = l.allocator();

    // var arena = std.heap.ArenaAllocator.init(a);
    // defer arena.deinit();
    // const aa = arena.allocator();
    const jsonval = try std.json.parseFromSlice(std.json.Value, a, jsonstr, .{});
    defer jsonval.deinit();

    const top = l.getTop();
    pushLuaValue(l, jsonval.value, a) catch |err| {
        l.setTop(top);
        return err;
    };

    l.pushNil();
    // _ = res;
    return 2;

    //return 0;
}

fn pushLuaValue(l: *Lua, val: std.json.Value, a: Allocator) !void {
    switch (val) {
        .object => |obj| {
            l.createTable(0, @intCast(obj.count()));
            var it = obj.iterator();
            while (it.next()) |kv| {
                _ = l.pushString(kv.key_ptr.*);
                try pushLuaValue(l, kv.value_ptr.*, a);
                l.setTable(-3);
            }
        },
        .array => |arr| {
            l.createTable(@intCast(arr.items.len), 0);
            var i: i32 = 1;
            for (arr.items) |item| {
                l.pushInteger(i);
                i += 1;
                try pushLuaValue(l, item, a);
                l.setTable(-3);
            }
        },
        .string => |s| {
            _ = l.pushString(s);
        },
        .float => |f| {
            l.pushNumber(f);
        },
        .integer => |i| {
            l.pushInteger(i);
        },
        .bool => |b| {
            l.pushBoolean(b);
        },
        .null => {
            l.pushNil();
        },
        .number_string => |s| {
            _ = l.pushString(s);
        },
    }
}

const BufWriter = struct {
    buffer: std.ArrayList(u8),
    allocator: Allocator,

    const Writer = std.io.Writer(*@This(), error{OutOfMemory}, write);

    pub fn init(allocator: Allocator) BufWriter {
        return .{
            .buffer = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn writer(self: *@This()) Writer {
        return Writer{ .context = self };
    }

    pub fn write(self: *@This(), data: []const u8) !usize {
        try self.buffer.appendSlice(data);
        return data.len;
    }

    pub fn getBytes(self: *@This()) []u8 {
        return self.buffer.items;
    }

    pub fn deinit(self: *@This()) void {
        self.buffer.deinit();
    }
};

pub fn dumps(l: *Lua) i32 {
    return dumps_(l) catch {
        l.pushNil();
        _ = l.pushString("failed to serialize json");
        return 2;
    };
}

fn dumps_(l: *Lua) !i32 {
    var arena = std.heap.ArenaAllocator.init(l.allocator());
    defer arena.deinit();
    const a = arena.allocator();
    //_ = a;
    // var bw = BufWriter{};
    var bw = BufWriter.init(a);
    defer bw.deinit();
    const val = JsonWritable{ .l = l, .ndx = 1 };
    try std.json.stringify(val, .{}, bw.writer());
    _ = l.pushString(bw.getBytes());
    l.pushNil();
    return 2;
}

const JsonSerializeError = error{
    UnsupportedValue,
};
const JsonWritable = struct {
    l: *Lua,
    ndx: i32,

    pub fn jsonStringify(self: @This(), jws: anytype) !void {
        const typ = self.l.typeOf(self.ndx);
        const top = self.l.getTop();
        defer self.l.setTop(top);

        switch (typ) {
            .nil => {
                try jws.write(null);
            },
            .string => {
                const s = self.l.toString(self.ndx) catch unreachable;
                try jws.write(s);
            },
            .number => {
                const n = self.l.toNumber(self.ndx) catch unreachable;
                try jws.write(n);
            },
            .boolean => {
                const b = self.l.toBoolean(self.ndx);
                try jws.write(b);
            },
            .table => {
                if (isList(self.l, self.ndx)) {
                    try jws.beginArray();
                    self.l.pushNil();
                    while (self.l.next(-2)) {
                        const val = JsonWritable{ .l = self.l, .ndx = -1 };
                        try jws.write(val);
                        self.l.pop(1);
                    }
                    try jws.endArray();
                } else {
                    try jws.beginObject();
                    self.l.pushNil();
                    while (self.l.next(-2)) {

                        // NOTE: this dance is necessary because
                        // https://www.lua.org/manual/5.4/manual.html#lua_tolstring
                        self.l.pushValue(-2);
                        const key = self.l.toString(-1) catch unreachable;
                        try jws.objectField(key);
                        self.l.pop(1);

                        const val = JsonWritable{ .l = self.l, .ndx = -1 };
                        try val.jsonStringify(jws);

                        self.l.pop(1);
                    }
                    try jws.endObject();
                }
            },
            else => {
                std.log.warn("json.dumps: unsupported value of type 'Luatype.{s}'\n", .{@tagName(typ)});
                // NOTE: have to write a value, otherwise serializing tables can crash
                try jws.write(null);
            },
        }
    }
};

fn isList(l: *Lua, ndx: i32) bool {
    const top = l.getTop();
    defer l.setTop(top);
    l.pushValue(ndx); // push table to top
    var expected: i64 = 1;
    l.pushNil(); // required, space in stack for key
    while (l.next(ndx)) {
        const val = l.toInteger(-2) catch 0;
        if (val != expected) {
            return false;
        }
        expected += 1;
    }
    return true;
}
