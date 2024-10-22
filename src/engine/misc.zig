const std = @import("std");
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const wrapGcFn = @import("luatils.zig").wrapGcFn;
const builtin = @import("builtin");
const version = @import("../version.zig");

pub fn api_version(l: *Lua) i32 {
    l.pushNumber(version.API_VERSION_MAJOR);
    l.pushNumber(version.API_VERSION_MINOR);
    return 2;
}

fn htt_bin_(l: *Lua) !i32 {
    const a = l.allocator();
    const bin_path = try std.fs.selfExePathAlloc(a);
    defer a.free(bin_path);
    _ = l.pushString(bin_path);
    return 1;
}

// provide absolute path to HTT binary
pub fn htt_bin(l: *Lua) i32 {
    return htt_bin_(l) catch {
        return 0;
    };
}
