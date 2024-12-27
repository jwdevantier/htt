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

fn doString(lua: *Lua, name: [:0]const u8, buf: []const u8) !void {
    lua.loadBuffer(buf, name, .text) catch |err| {
        const err_msg = lua.toString(-1) catch unreachable;
        std.log.err(
            \\ Error Loading {s} Code:
            \\ ---
            \\ {s}
            \\ ---
            \\
            \\ This is a bug, please report it!
        , .{ name, err_msg });
        return err;
    };

    lua.protectedCall(0, ziglua.mult_return, 0) catch |err| {
        const err_msg = lua.toString(-1) catch unreachable;
        std.log.err(
            \\ Error Evaluating {s} Code:
            \\ ---
            \\ {s}
            \\ ---
            \\
            \\ This is a bug, please report it!
        , .{ name, err_msg });
        return err;
    };
}

fn resolveOutDirPath(a: Allocator, out_dir_arg: ?[]const u8) !?[]const u8 {
    if (out_dir_arg) |out_dir_path| {
        const cwd = try std.fs.cwd().realpathAlloc(a, ".");
        return try std.fs.path.resolve(a, &[_][]const u8{ cwd, out_dir_path });
    } else return null;
}

fn doRun(script_fpath_: []const u8, out_dir_arg: ?[]const u8) !void {
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

    const out_dir = try resolveOutDirPath(aai, out_dir_arg);
    defer if (out_dir) |slice| aai.free(slice);

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
    try doString(lua, "HTT Library", prelude);

    try setLuaPackagePath(aai, lua, htt_root);

    // loading after to allow us to patch in the zig functions
    //
    // this permits documenting stubs using ldoc
    try engine.registerZigFuncs(lua);

    // expose out directory to Lua side, not part of end-user API though
    if (out_dir) |val| {
        _ = lua.pushString(val);
    } else {
        _ = lua.pushString(htt_root);
    }
    lua.setGlobal("HTT_OUT_PATH");

    const htt_prelude = @embedFile("./htt_prelude.lua");
    try doString(lua, "HTT Loader", htt_prelude);

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

fn run(script_fpath: []const u8, out_dir: ?[]const u8) !void {
    doRun(script_fpath, out_dir) catch |err| {
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

fn write_typestubs(out_dir: ?[]const u8) !void {
    std.debug.print("writing typestubs\n", .{});
    if (out_dir) |o| {
        var htt_root_hndl = try std.fs.cwd().openDir(o, .{});
        defer htt_root_hndl.close();
        try htt_root_hndl.setAsCwd();
    }

    try std.fs.cwd().makePath(".luals");

    const typestub = try std.fs.cwd().createFile(
        ".luals/htt.lua",
        .{ .read = true, .truncate = true },
    );
    defer typestub.close();

    // Write the content
    try typestub.writeAll(@embedFile("./htt_typestubs.lua"));

    // Write config which instructs luals to look in the .luals directory for type-stubs
    const luals_conf = try std.fs.cwd().createFile(
        ".luarc.json",
        .{ .read = true, .truncate = true },
    );
    defer luals_conf.close();

    try luals_conf.writeAll(
        \\{
        \\    "workspace.library": [
        \\        "./.luals",
        \\    ]
        \\}
    );
}

pub fn main() !void {
    var app = yazap.App.init(std.heap.page_allocator, "htt", "general-purpose template-driven code generator");
    defer app.deinit();

    var htt = app.rootCommand();

    try htt.addArg(Arg.singleValueOption("out-dir", 'o', "directory where files are rendered out to (default: same as script file)"));
    try htt.addArg(Arg.booleanOption("init-lsp-conf", null, "Write LuaCATS type-stub file for HTT, so LuaLS can offer completions and type-checking"));
    try htt.addArg(Arg.positional("script", "path to your script", null));
    const matches = try app.parseProcess();

    if (matches.containsArg("init-lsp-conf")) {
        if (matches.containsArg("script")) {
            std.debug.print("Cannot provide a script to run when generating type-stubs\n", .{});
            std.process.exit(1);
        }
        write_typestubs(matches.getSingleValue("out-dir")) catch {
            std.process.exit(1);
        };
        return;
    }
    if (matches.containsArg("script")) {
        const script_fpath = matches.getSingleValue("script").?;
        run(script_fpath, matches.getSingleValue("out-dir")) catch {
            std.process.exit(1);
        };
    } else {
        try app.displayHelp();
        std.process.exit(2);
    }
}
