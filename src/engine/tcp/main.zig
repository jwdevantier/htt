const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const std = @import("std");
const net = std.net;

const address = @import("address.zig");
const stream = @import("stream.zig");
const buffer = @import("buffer.zig");

pub fn registerFuncs(lua: *Lua, htt_tbl_ndx: i32) !void {
    const top = lua.getTop();
    _ = lua.getField(htt_tbl_ndx, "tcp");

    lua.pushFunction(ziglua.wrap(address.parseIp));
    lua.setField(-2, "addr");

    lua.pushFunction(ziglua.wrap(stream.connect));
    lua.setField(-2, "connect");

    lua.pushFunction(ziglua.wrap(buffer.Init));
    lua.setField(-2, "buffer");

    lua.setTop(top);
}
