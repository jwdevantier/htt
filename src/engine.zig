//! Implements the scripting engine component.
//!
//!

// TODO: package.path needs to be set up, but which paths to include ?
// ? <cwd> for lua modules
// ? <project root>/htt  for lua modules (?)
// ? <global/inlined lua code>
const std = @import("std");
const ziglua = @import("ziglua");

const env = @import("engine/env.zig");
const tpl = @import("engine/tpl.zig");
const json = @import("engine/json.zig");
const proc = @import("engine/proc.zig");
const tcp = @import("engine/tcp/main.zig");
const fs = @import("engine/fs.zig");
const time = @import("engine/time.zig");

const Allocator = std.mem.Allocator;
const Lua = ziglua.Lua;
const builtin = @import("builtin");

const ResolvePathError = error{
    FileNotFound,
    FileNotAccessible,
};

// resolves config file path and checks that it is accessible by process
// NOTE: caller must free memory
pub fn resolvePath(a: Allocator, relpath: []const u8) ResolvePathError![]const u8 {
    const path = std.fs.cwd().realpathAlloc(a, relpath) catch {
        return ResolvePathError.FileNotFound;
    };
    errdefer a.free(path);

    if (builtin.os.tag == .windows) {
        // This fails on Windows if applied to a directory.
    } else {
        _ = std.fs.cwd().statFile(path) catch {
            return ResolvePathError.FileNotAccessible;
        };
    }

    return path;
}

pub fn registerZigFuncs(lua: *Lua) !void {
    const top = lua.getTop();
    defer lua.setTop(top);
    _ = try lua.getGlobal("htt");
    const htt_ndx = lua.getTop();

    try env.registerFuncs(lua, htt_ndx);

    try tcp.registerFuncs(lua, htt_ndx);

    try time.registerFuncs(lua, htt_ndx);

    try fs.registerFuncs(lua, htt_ndx);

    _ = lua.getField(htt_ndx, "tpl");
    lua.pushFunction(ziglua.wrap(tpl.compile));
    lua.setField(-2, "compile");

    _ = lua.getField(htt_ndx, "json");
    lua.pushFunction(ziglua.wrap(json.loads));
    lua.setField(-2, "loads");
    lua.pushFunction(ziglua.wrap(json.dumps));
    lua.setField(-2, "dumps");
}
