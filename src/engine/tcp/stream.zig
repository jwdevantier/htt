const std = @import("std");
const net = std.net;
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;
const wrapGcFn = @import("../luatils.zig").wrapGcFn;
const address = @import("address.zig");
const buffer = @import("buffer.zig");
const lt = @import("../luatils.zig");

const Stream = struct { val: net.Stream };
pub const S_ID = "Stream";

pub fn checkStream(l: *Lua, ndx: i32) *Stream {
    return l.checkUserdata(Stream, ndx, S_ID);
}

fn sGarbageCollect(l: *Lua, self: *Stream) c_int {
    _ = l;
    self.val.close();
    return 0;
}

fn sMetaTable(l: *Lua, obj_tbl_ndx: i32) void {
    const top = l.getTop();
    l.pushValue(obj_tbl_ndx);

    l.newMetatable(S_ID) catch {
        l.setMetatable(-2);
        return;
    };

    l.pushFunction(wrapGcFn(Stream, S_ID, sGarbageCollect));
    l.setField(-2, "__gc");

    l.pushFunction(ziglua.wrap(sSend));
    l.setField(-2, "send");

    l.pushFunction(ziglua.wrap(sRecv));
    l.setField(-2, "recv");

    l.pushFunction(ziglua.wrap(sRecvAtLeast));
    l.setField(-2, "recv_at_least");

    l.pushValue(-1); // => [<o> <mt> <mt>]
    l.setField(-2, "__index"); // => [<o> <mt>]
    l.setMetatable(-2); // => [<o>];

    l.setTop(top);
}

fn sSend(l: *Lua) i32 {
    const self = checkStream(l, 1);
    const buf = buffer.checkBuffer(l, 2);
    const slice = if (l.getTop() > 2)
        buf.slice()[0..lt.checkUsize(l, 3)]
    else
        buf.slice();

    self.val.writeAll(slice) catch |err| {
        _ = l.pushString(@errorName(err));
        return 1;
    };

    return 0;
}

fn sRecvAtLeast_(l: *Lua, self: *Stream, buf: *buffer.Buffer, slice: []u8, min_bytes: usize) i32 {
    if (slice.len < min_bytes) {
        l.argError(3, "request too large for remaining space");
    }

    const bytes_read = self.val.readAtLeast(slice, min_bytes) catch |err| {
        l.pushNil();
        _ = l.pushString(@errorName(err));
        return 2;
    };

    lt.pushUsize(l, bytes_read);

    // bytes_read can be less than n, iff EOS.
    if (bytes_read < min_bytes) {
        _ = l.pushString("EOS");
        return 2;
    }

    buf.pos += bytes_read;

    return 1;
}

fn sRecvExactly(l: *Lua, self: *Stream, buf: *buffer.Buffer, n: usize) i32 {
    if (n == 0) { // nothing requested, fast exit
        return 0;
    }
    return sRecvAtLeast_(l, self, buf, buf.slice()[0..n], n);
}

fn sRecv(l: *Lua) i32 {
    const self = checkStream(l, 1);
    const buf = buffer.checkBuffer(l, 2);

    if (l.getTop() > 2) {
        return sRecvExactly(l, self, buf, lt.checkUsize(l, 3));
    }

    const bytes_read = self.val.read(buf.slice()) catch |err| {
        l.pushNil();
        _ = l.pushString(@errorName(err));
        return 2;
    };
    buf.pos += bytes_read;
    lt.pushUsize(l, bytes_read);
    return 1;
}

fn sRecvAtLeast(l: *Lua) i32 {
    const self = checkStream(l, 1);
    const buf = buffer.checkBuffer(l, 2);
    const min = lt.checkUsize(l, 3);

    return sRecvAtLeast_(l, self, buf, buf.slice(), min);
}

pub fn connect(l: *Lua) i32 {
    const addr = l.checkUserdata(address.Address, 1, address.AddressId);

    const stream = net.tcpConnectToAddress(addr.val) catch |err| {
        l.pushNil();
        _ = l.pushString(@errorName(err));
        return 2;
    };

    const inst = l.newUserdata(Stream, @sizeOf(Stream));
    inst.val = stream;

    sMetaTable(l, -1);
    return 1;
}
