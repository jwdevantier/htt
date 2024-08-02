const std = @import("std");
pub const lexer = @import("tpl.zig");
pub const ltest = @import("tpl/test_lexer.zig");
pub const lcomp = @import("tpl/compiler.zig");

test {
    std.testing.refAllDecls(@This());
}
