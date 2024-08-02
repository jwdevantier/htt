const std = @import("std");
const engine = @import("engine.zig");
const ziglua = @import("ziglua");
const yazap = @import("yazap");

const Lua = ziglua.Lua;
const Allocator = std.mem.Allocator;
const Arg = yazap.Arg;

const PrgErrors = error{
    ErrorHandled,
};

fn setLuaPackagePath(a: Allocator, lua: *Lua, htt_root: []const u8) !void {
    var sb = std.ArrayList(u8).init(a);
    defer sb.deinit();

    const path1 = try std.fs.path.join(a, &.{ htt_root, "?.lua" });
    defer a.free(path1);
    try sb.appendSlice(path1);
    try sb.appendSlice(";");

    const path2 = try std.fs.path.join(a, &.{ htt_root, "?", "init.lua" });
    defer a.free(path2);
    try sb.appendSlice(path2);
    try sb.appendSlice(";");

    _ = try lua.getGlobal("package\x00");
    _ = lua.pushString("path");
    _ = lua.pushString(sb.items);
    _ = lua.setTable(-3);
}

fn doRun(script_fpath_: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var ainit = std.heap.ArenaAllocator.init(allocator);
    defer ainit.deinit();
    const aai = ainit.allocator();

    // Resolve file paths ahead of changing the current working directory
    const script_fpath = try engine.resolvePath(aai, script_fpath_);
    std.debug.print("resolved script_fpath: '{s}'\n", .{script_fpath});
    defer aai.free(script_fpath);

    const htt_root = try engine.resolvePath(aai, std.fs.path.dirname(script_fpath_) orelse ".");
    std.debug.print("resolved htt_root: '{s}'\n", .{htt_root});
    defer aai.free(htt_root);

    // change working directory
    var htt_root_hndl = try std.fs.cwd().openDir(htt_root, .{});
    defer htt_root_hndl.close();
    try htt_root_hndl.setAsCwd();

    // Initialize Lua VM
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    var lua = try Lua.init(&arena.allocator());
    defer lua.deinit();

    lua.openLibs();

    const prelude = @embedFile("./prelude.lua");
    lua.doString(prelude) catch |err| {
        const err_msg = lua.toString(-1) catch unreachable;
        std.log.err(
            \\ Error Evaluating prelude code:
            \\ ---
            \\ {s}
            \\ ---
            \\
            \\ This is a bug, please report it!
        , .{err_msg});
        return err;
    };

    try setLuaPackagePath(aai, lua, htt_root);

    // loading after to allow us to patch in the zig functions
    //
    // this permits documenting stubs using ldoc
    try engine.registerZigFuncs(lua);

    // TODO: load httprelude.lua
    const htt_prelude = @embedFile("./htt_prelude.lua");
    lua.doString(htt_prelude) catch |err| {
        const err_msg = lua.toString(-1) catch unreachable;
        std.log.err(
            \\ Error Evaluating htt prelude code:
            \\ ---
            \\ {s}
            \\ ---
            \\
            \\ This is a bug, please report it!
        , .{err_msg});
        return err;
    };

    _ = try lua.getGlobal("htt");
    _ = lua.getField(-1, "dofile_with_tb");
    _ = lua.pushString(script_fpath);
    lua.call(1, 2);
    if (!lua.isNil(-1)) {
        const err = try lua.toString(-1);
        std.debug.print("{s}\n", .{err});
        return PrgErrors.ErrorHandled;
    }
}

fn run(script_fpath: []const u8) !void {
    doRun(script_fpath) catch |err| {
        switch (err) {
            // errors where we have informed the user, but can do nothing more
            error.ErrorHandled => {},
            else => {
                std.debug.print("Program aborted due to unhandled error of type: {s}\n", .{@errorName(err)});
            },
        }
        std.process.exit(1);
    };
}

pub fn main() !void {
    var app = yazap.App.init(std.heap.page_allocator, "htt", "general-purpose template-driven code generator");
    defer app.deinit();

    var htt = app.rootCommand();

    try htt.addArg(Arg.positional("script", "path to your script", null));
    const matches = try app.parseProcess();

    if (matches.containsArg("script")) {
        const script_fpath = matches.getSingleValue("script").?;
        run(script_fpath) catch {
            std.process.exit(1);
        };
    } else {
        try app.displayHelp();
        std.process.exit(2);
    }
}
