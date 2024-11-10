const std = @import("std");
const ziglua = @import("ziglua");
const wrapGcFn = @import("../luatils.zig").wrapGcFn;
const Lua = ziglua.Lua;

pub const Buffer = struct {
    val: std.ArrayList(u8),
    pos: usize,

    pub inline fn slice(self: *@This()) []u8 {
        return self.val.allocatedSlice()[self.pos..];
    }

    pub inline fn remaining(self: *@This()) usize {
        return self.slice().len;
    }
};

pub const BufferId = "Buffer";

pub fn asNative(comptime T: type, x: T) T {
    return x;
}

pub fn checkBuffer(l: *Lua, ndx: i32) *Buffer {
    return l.checkUserdata(Buffer, ndx, BufferId);
}

fn bGarbageCollect(l: *Lua, self: *Buffer) c_int {
    _ = l;
    self.val.deinit();
    return 0;
}

fn bMetaTable(l: *Lua, obj_tbl_ndx: i32) void {
    const top = l.getTop();
    l.pushValue(obj_tbl_ndx);

    l.newMetatable(BufferId) catch {
        l.setMetatable(-2);
        return;
    };

    l.pushFunction(wrapGcFn(Buffer, BufferId, bGarbageCollect));
    l.setField(-2, "__gc");

    // report number of bytes remaining between pos and end of buffer
    l.pushFunction(ziglua.wrap(bRemaining));
    l.setField(-2, "remaining");

    // report size (capacity)
    l.pushFunction(ziglua.wrap(bSize));
    l.setField(-2, "size");

    // set new capacity, will shrink or grow as needed, might fail
    l.pushFunction(ziglua.wrap(bSetSize));
    l.setField(-2, "setSize");

    l.pushFunction(ziglua.wrap(bSeek));
    l.setField(-2, "seek");

    l.pushFunction(ziglua.wrap(bSeekStart));
    l.setField(-2, "seek_start");

    l.pushFunction(ziglua.wrap(bSeekEnd));
    l.setField(-2, "seek_end");

    l.pushFunction(ziglua.wrap(bTell));
    l.setField(-2, "tell");

    // Native-endian writers
    l.pushFunction(ziglua.wrap(WriteIntFn.get(u8, asNative)));
    l.setField(-2, "writeU8");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(u16, asNative)));
    l.setField(-2, "writeU16");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(u32, asNative)));
    l.setField(-2, "writeU32");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(u64, asNative)));
    l.setField(-2, "writeU64");

    l.pushFunction(ziglua.wrap(WriteIntFn.get(i8, asNative)));
    l.setField(-2, "writeI8");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(i16, asNative)));
    l.setField(-2, "writeI16");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(i32, asNative)));
    l.setField(-2, "writeI32");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(i64, asNative)));
    l.setField(-2, "writeI64");

    // Little-endian writers
    l.pushFunction(ziglua.wrap(WriteIntFn.get(u8, std.mem.nativeToLittle)));
    l.setField(-2, "writeU8Le");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(u16, std.mem.nativeToLittle)));
    l.setField(-2, "writeU16Le");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(u32, std.mem.nativeToLittle)));
    l.setField(-2, "writeU32Le");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(u64, std.mem.nativeToLittle)));
    l.setField(-2, "writeU64Le");

    l.pushFunction(ziglua.wrap(WriteIntFn.get(i8, std.mem.nativeToLittle)));
    l.setField(-2, "writeI8Le");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(i16, std.mem.nativeToLittle)));
    l.setField(-2, "writeI16Le");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(i32, std.mem.nativeToLittle)));
    l.setField(-2, "writeI32Le");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(i64, std.mem.nativeToLittle)));
    l.setField(-2, "writeI64Le");

    // Big-endian writers
    l.pushFunction(ziglua.wrap(WriteIntFn.get(u8, std.mem.nativeToBig)));
    l.setField(-2, "writeU8Be");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(u16, std.mem.nativeToBig)));
    l.setField(-2, "writeU16Be");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(u32, std.mem.nativeToBig)));
    l.setField(-2, "writeU32Be");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(u64, std.mem.nativeToBig)));
    l.setField(-2, "writeU64Be");

    l.pushFunction(ziglua.wrap(WriteIntFn.get(i8, std.mem.nativeToBig)));
    l.setField(-2, "writeI8Be");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(i16, std.mem.nativeToBig)));
    l.setField(-2, "writeI16Be");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(i32, std.mem.nativeToBig)));
    l.setField(-2, "writeI32Be");
    l.pushFunction(ziglua.wrap(WriteIntFn.get(i64, std.mem.nativeToBig)));
    l.setField(-2, "writeI64Be");

    // Misc writers
    l.pushFunction(ziglua.wrap(bWriteString));
    l.setField(-2, "writeString");

    l.pushFunction(ziglua.wrap(bWriteBool));
    l.setField(-2, "writeBool");

    // Native-endian readers
    l.pushFunction(ziglua.wrap(ReadIntFn.get(u8, asNative)));
    l.setField(-2, "readU8");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(u16, asNative)));
    l.setField(-2, "readU16");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(u32, asNative)));
    l.setField(-2, "readU32");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(u64, asNative)));
    l.setField(-2, "readU64");

    l.pushFunction(ziglua.wrap(ReadIntFn.get(i8, asNative)));
    l.setField(-2, "readI8");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(i16, asNative)));
    l.setField(-2, "readI16");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(i32, asNative)));
    l.setField(-2, "readI32");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(i64, asNative)));
    l.setField(-2, "readI64");

    // Little-endian readers
    l.pushFunction(ziglua.wrap(ReadIntFn.get(u8, std.mem.nativeToLittle)));
    l.setField(-2, "readU8Le");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(u16, std.mem.nativeToLittle)));
    l.setField(-2, "readU16Le");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(u32, std.mem.nativeToLittle)));
    l.setField(-2, "readU32Le");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(u64, std.mem.nativeToLittle)));
    l.setField(-2, "readU64Le");

    l.pushFunction(ziglua.wrap(ReadIntFn.get(i8, std.mem.nativeToLittle)));
    l.setField(-2, "readI8Le");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(i16, std.mem.nativeToLittle)));
    l.setField(-2, "readI16Le");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(i32, std.mem.nativeToLittle)));
    l.setField(-2, "readI32Le");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(i64, std.mem.nativeToLittle)));
    l.setField(-2, "readI64Le");

    // Big-endian readers
    l.pushFunction(ziglua.wrap(ReadIntFn.get(u8, std.mem.nativeToBig)));
    l.setField(-2, "readU8Be");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(u16, std.mem.nativeToBig)));
    l.setField(-2, "readU16Be");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(u32, std.mem.nativeToBig)));
    l.setField(-2, "readU32Be");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(u64, std.mem.nativeToBig)));
    l.setField(-2, "readU64Be");

    l.pushFunction(ziglua.wrap(ReadIntFn.get(i8, std.mem.nativeToBig)));
    l.setField(-2, "readI8Be");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(i16, std.mem.nativeToBig)));
    l.setField(-2, "readI16Be");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(i32, std.mem.nativeToBig)));
    l.setField(-2, "readI32Be");
    l.pushFunction(ziglua.wrap(ReadIntFn.get(i64, std.mem.nativeToBig)));
    l.setField(-2, "readI64Be");

    // String and bool readers
    l.pushFunction(ziglua.wrap(bReadString));
    l.setField(-2, "readString");

    l.pushFunction(ziglua.wrap(bReadBool));
    l.setField(-2, "readBool");

    l.pushValue(-1); // => [<o> <mt> <mt>]
    l.setField(-2, "__index"); // => [<o> <mt>]
    l.setMetatable(-2); // => [<o>];

    l.setTop(top);
}

const WriteIntFn = struct {
    fn get(comptime T: type, comptime to_endian: fn (type, T) T) fn (*Lua) i32 {
        return struct {
            fn write(l: *Lua) i32 {
                const self = checkBuffer(l, 1);

                // Bounds check
                if (self.pos + @sizeOf(T) > self.val.items.len) {
                    l.raiseErrorStr("write would be out-of-bounds", .{});
                }

                const value = l.checkInteger(2);
                const num = @as(T, @intCast(value));

                const converted = to_endian(T, num);
                const bytes = std.mem.asBytes(&converted);

                @memcpy(self.slice()[0..@sizeOf(T)], bytes);
                self.pos += @sizeOf(T);

                return 0;
            }
        }.write;
    }
};

fn bWriteString(l: *Lua) i32 {
    const self = checkBuffer(l, 1);
    const str = l.checkString(2);

    // Bounds check
    if (self.pos + str.len > self.val.items.len) {
        l.raiseErrorStr("write would be out-of-bounds", .{});
    }

    @memcpy(self.slice()[0..str.len], str);
    self.pos += str.len;

    return 0;
}

fn bWriteBool(l: *Lua) i32 {
    const self = checkBuffer(l, 1);
    const value = l.toBoolean(2);
    const byte: u8 = if (value) 1 else 0;

    // Bounds check
    if (self.pos + 1 > self.val.items.len) {
        l.raiseErrorStr("write would be out-of-bounds", .{});
    }

    self.val.items[self.pos] = byte;
    self.pos += 1;

    return 0;
}

const ReadIntFn = struct {
    fn get(comptime T: type, comptime from_endian: fn (type, T) T) fn (*Lua) i32 {
        return struct {
            fn read(l: *Lua) i32 {
                const self = checkBuffer(l, 1);
                // Bounds check
                if (self.pos + @sizeOf(T) > self.val.items.len) {
                    l.raiseErrorStr("read would be out-of-bounds", .{});
                }

                // Read the bytes at offset
                const bytes = self.val.items[self.pos .. self.pos + @sizeOf(T)];
                const value = std.mem.bytesAsValue(T, bytes[0..@sizeOf(T)]);
                const native_value = from_endian(T, value.*);

                l.pushInteger(@as(i64, @intCast(native_value)));
                self.pos += @sizeOf(T);
                return 1;
            }
        }.read;
    }
};

fn bReadString(l: *Lua) i32 {
    const self = checkBuffer(l, 1);
    const length = @as(usize, @intCast(l.checkInteger(2)));

    // Bounds check
    if (self.pos + length > self.val.items.len) {
        l.raiseErrorStr("read would be out-of-bounds", .{});
    }

    const str = self.val.items[self.pos .. self.pos + length];
    _ = l.pushString(str);
    self.pos += length;
    return 1;
}

fn bReadBool(l: *Lua) i32 {
    const self = checkBuffer(l, 1);

    // Bounds check
    if (self.pos + 1 > self.val.items.len) {
        l.raiseErrorStr("read would be out-of-bounds", .{});
    }

    const value = self.val.items[self.pos];
    l.pushBoolean(value != 0);
    self.pos += @sizeOf(@TypeOf(value));
    return 1;
}

fn bRemaining(l: *Lua) i32 {
    const self = checkBuffer(l, 1);
    l.pushInteger(@as(c_longlong, @intCast(self.remaining())));
    return 1;
}

fn bSize(l: *Lua) i32 {
    const self = checkBuffer(l, 1);
    l.pushInteger(@as(c_longlong, @intCast(self.val.capacity)));
    return 1;
}

fn bSetSize(l: *Lua) i32 {
    const self = checkBuffer(l, 1);
    const num_ = l.checkInteger(2);
    if (num_ < 0) {
        _ = l.pushString("cannot provide a negative capacity");
        return 1;
    }
    const num = @as(usize, @intCast(num_));

    if (num < self.val.capacity) {
        self.val.shrinkAndFree(num);
        if (self.pos > num) {
            self.pos = num;
        }
    } else {
        self.val.ensureTotalCapacity(num) catch |err| {
            _ = l.pushString(@errorName(err));
            return 1;
        };
    }
    return 0;
}

fn bSeek(l: *Lua) i32 {
    const self = checkBuffer(l, 1);
    const num_ = l.checkInteger(2);
    if (num_ < 0) {
        l.argError(1, "cannot use negative indices with seek");
    }
    const num = @as(usize, @intCast(num_));

    if (num > self.val.items.len) {
        l.argError(1, "seek out of bounds");
    }

    self.pos = num;
    return 0;
}

fn bSeekStart(l: *Lua) i32 {
    const self = checkBuffer(l, 1);
    self.pos = 0;
    return 0;
}

fn bSeekEnd(l: *Lua) i32 {
    const self = checkBuffer(l, 1);
    self.pos = self.val.items.len;
    return 0;
}

fn bTell(l: *Lua) i32 {
    const self = checkBuffer(l, 1);
    l.pushInteger(@as(c_longlong, @intCast(self.pos)));
    return 1;
}

pub fn Init(l: *Lua) i32 {
    const cap_ = if (l.getTop() >= 1) l.checkInteger(1) else 200;
    const cap: usize = std.math.cast(usize, cap_) orelse {
        l.pushNil();
        _ = l.pushString("invalid port number");
        return 2;
    };

    const a = l.allocator();
    var list_with_capacity = std.ArrayList(u8).initCapacity(a, cap) catch |err| {
        l.pushNil();
        _ = l.pushString(@errorName(err));
        return 2;
    };

    // we just initialized with this size, to this will always work
    list_with_capacity.resize(cap) catch unreachable;

    const inst = l.newUserdata(Buffer, @sizeOf(Buffer));
    inst.*.val = list_with_capacity;
    inst.*.pos = 0;

    bMetaTable(l, -1);
    return 1;
}
