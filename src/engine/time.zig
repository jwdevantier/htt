const std = @import("std");
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;

fn sleep(l: *Lua) i32 {
    const ns = l.checkInteger(1);
    if (ns < 0) {
        l.argError(1, "ns must be a positive number");
    }
    std.time.sleep(@intCast(ns));
    return 0;
}

fn timestamp(l: *Lua) i32 {
    l.pushInteger(@as(c_longlong, std.time.timestamp()));
    return 1;
}

fn timestamp_ms(l: *Lua) i32 {
    l.pushInteger(@as(c_longlong, std.time.milliTimestamp()));
    return 1;
}

pub fn registerFuncs(lua: *Lua, htt_tbl_ndx: i32) !void {
    const top = lua.getTop();
    _ = lua.getField(htt_tbl_ndx, "time");

    lua.pushFunction(ziglua.wrap(timestamp));
    lua.setField(-2, "timestamp");

    lua.pushFunction(ziglua.wrap(timestamp_ms));
    lua.setField(-2, "timestamp_ms");

    lua.pushFunction(ziglua.wrap(sleep));
    lua.setField(-2, "sleep");

    lua.pushInteger(std.time.ns_per_us);
    lua.setField(-2, "ns_per_us");

    lua.pushInteger(std.time.ns_per_ms);
    lua.setField(-2, "ns_per_ms");

    lua.pushInteger(std.time.ns_per_s);
    lua.setField(-2, "ns_per_s");

    lua.pushInteger(std.time.ns_per_min);
    lua.setField(-2, "ns_per_min");

    lua.setTop(top);
}
