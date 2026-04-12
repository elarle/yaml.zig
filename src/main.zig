const std = @import("std");
const yaml_zig = @import("yaml_zig");

const template = struct{
    data: u32 = 0,
    bebe: []const u8 = "not_loaded",
    sex: struct {
        a: u32 = 0,
        b: u32 = 0
    } = .{}
};

pub fn main() !void {
    const settings = yaml_zig.loadYaml(std.heap.page_allocator, "data.yaml", template);
    std.debug.print("{}\n", .{settings});
}

const testing = std.testing;
test "Load the config" {
    const settings = yaml_zig.loadYaml(std.testing.allocator, "data.yaml", template);

    try testing.expectEqual(1, settings.data);
    try testing.expectEqualStrings("Hola pepe", settings.bebe);
    try testing.expectEqualDeep(@TypeOf(settings.sex){.a = 33, .b = 32}, settings.sex);

    std.debug.print("{}\n", .{settings});
}
