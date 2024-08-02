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
