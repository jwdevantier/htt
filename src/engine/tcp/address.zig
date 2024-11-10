const std = @import("std");
const net = std.net;
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const wrapGcFn = @import("../luatils.zig").wrapGcFn;

pub const Address = struct { val: net.Address };
pub const AddressId = "Address";

// TODO: could possibly hang on to the str/port
fn aMetaTable(l: *Lua, obj_tbl_ndx: i32) void {
    const top = l.getTop();
    l.pushValue(obj_tbl_ndx);

    l.newMetatable(AddressId) catch {
        l.setMetatable(-2);
        return;
    };

    l.pushValue(-1); // => [<o> <mt> <mt>]
    l.setField(-2, "__index"); // => [<o> <mt>]
    l.setMetatable(-2); // => [<o>];

    l.setTop(top);
}

pub fn parseIp(l: *Lua) i32 {
    const name = l.checkString(1);
    const port_ = l.checkInteger(2);
    const port: u16 = std.math.cast(u16, port_) orelse {
        l.pushNil();
        _ = l.pushString("invalid port number");
        return 2;
    };
    const addr = net.Address.parseIp(name, port) catch |err| {
        const a = l.allocator();
        l.pushNil();
        const msg = std.fmt.allocPrint(a, "error resolving address: {s}", .{@errorName(err)}) catch {
            _ = l.pushString(@errorName(err));
            return 2;
        };
        defer a.free(msg);
        _ = l.pushString(msg);
        return 2;
    };

    const inst = l.newUserdata(Address, @sizeOf(Address));
    inst.val = addr;

    aMetaTable(l, -1);
    return 1;
}
