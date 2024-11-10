const ziglua = @import("ziglua");
const Lua = ziglua.Lua;

pub fn wrapGcFn(comptime T: type, comptime typeName: [:0]const u8, comptime f: fn (*Lua, *T) c_int) ziglua.CFn {
    return struct {
        fn inner(state: ?*ziglua.LuaState) callconv(.C) c_int {
            const lua: *Lua = @as(*Lua, @ptrCast(state.?));
            const udata: *T = lua.checkUserdata(T, 1, typeName);
            return @call(.auto, f, .{ lua, udata });
        }
    }.inner;
}

pub fn checkUsize(l: *Lua, ndx: i32) usize {
    const ival = l.checkInteger(ndx); // TODO: check and catch ourselves, to have same err msg
    if (ival < 0) {
        l.typeError(ndx, "usize");
    }
    return @as(usize, @intCast(ival));
}

pub fn pushUsize(l: *Lua, val: usize) void {
    l.pushInteger(@as(c_longlong, @intCast(val)));
}
