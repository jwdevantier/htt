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
