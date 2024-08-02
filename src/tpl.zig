const std = @import("std");
const lexer = @import("tpl/lexer.zig");
const compiler = @import("tpl/compiler.zig");

pub const compile = compiler.compile;

test "simple test" {
    std.testing.refAllDecls(@This());
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(83);
    try std.testing.expectEqual(@as(i32, 83), list.pop());
}
