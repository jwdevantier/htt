const std = @import("std");
const ziglua = @import("ziglua");
const Lua = ziglua.Lua;

pub const RcRef = struct {
    l: *Lua,
    refid: i32,
    refcount: usize,

    pub fn init(l: *Lua, ptr: *anyopaque) !RcRef {
        l.pushLightUserdata(ptr);
        return RcRef{
            .l = l,
            .refid = try l.ref(ziglua.registry_index),
            .refcount = 1,
        };
    }

    pub fn ref(self: *RcRef) !void {
        if (self.refcount == 0) {
            return error.RefSpent;
        }
        self.refcount += 1;
    }

    pub fn unref(self: *RcRef) void {
        std.debug.assert(self.refcount > 0);
        self.refcount -= 1;
        if (self.refcount == 0) {
            self.l.unref(ziglua.registry_index, self.refid);
            self.refid = ziglua.ref_nil; // mark as spent
        }
    }
};
