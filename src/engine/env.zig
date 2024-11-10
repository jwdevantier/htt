const std = @import("std");
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const wrapGcFn = @import("luatils.zig").wrapGcFn;
const builtin = @import("builtin");
const version = @import("../version.zig");

fn api_version(l: *Lua) i32 {
    l.pushNumber(version.API_VERSION_MAJOR);
    l.pushNumber(version.API_VERSION_MINOR);
    return 2;
}

fn htt_path_(l: *Lua) !i32 {
    const a = l.allocator();
    const bin_path = try std.fs.selfExePathAlloc(a);
    defer a.free(bin_path);
    _ = l.pushString(bin_path);
    return 1;
}

// provide absolute path to HTT binary
fn htt_path(l: *Lua) i32 {
    return htt_path_(l) catch {
        return 0;
    };
}

// get absolute path to the root output directory
fn out_path(l: *Lua) i32 {
    _ = l.getGlobal("HTT_OUT_PATH") catch {
        return 0;
    };
    return 1;
}

pub fn registerFuncs(lua: *Lua, htt_tbl_ndx: i32) !void {
    const top = lua.getTop();
    _ = lua.getField(htt_tbl_ndx, "env");

    lua.pushFunction(ziglua.wrap(api_version));
    lua.setField(-2, "apiversion");

    lua.pushFunction(ziglua.wrap(htt_path));
    lua.setField(-2, "htt_path");

    lua.pushFunction(ziglua.wrap(out_path));
    lua.setField(-2, "out_path");

    lua.setTop(top);
}
