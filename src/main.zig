const std = @import("std");
const yaml_zig = @import("yaml_zig");

const single_template = struct{
    data: u32 = 0,
    bebe: []const u8 = "not_loaded",
    sex: struct {
        a: u32 = 0,
        b: u32 = 0,
        c: u8 = 0,
    } = .{}
};

const Address = struct{
    name: []const u8 = "", 
    value: []const u8 = ""
};
const Generic= struct{
    val1: []const u8 = "",
    val: u128 = 0,
    singao: i16 = 0
};
const template = struct{
    data: u32 = 0,
    bebe: []const u8 = "not_loaded",
    sex: struct {
        a: u32 = 0,
        b: u32 = 0,
        c: u8 = 0,
        exampleArray: ?[]Address = null,
        exampleSingle: ?[]Generic = null,
    } = .{}
};


const AddressList = struct{
    addresses: ?[]Address = null
};
pub fn main() !void {
    var mem: ?yaml_zig.Memory = null;
    const settings = yaml_zig.loadYaml(std.heap.page_allocator, "ips.yaml", AddressList, &mem);
    defer mem.?.free();

    if(settings.addresses)|addresses|{
        for(addresses) |add| {
            std.debug.print("{s}\n * IP: {s}\n\n", .{add.name, add.value});
        }
    }
}

const testing = std.testing;
test "Load the config" {
    var memory: ?yaml_zig.Memory = null;
    const settings = yaml_zig.loadYaml(std.testing.allocator, "data.yaml", single_template,&memory);
    defer memory.?.free();

    try testing.expectEqual(1, settings.data);
    try testing.expectEqualStrings("Hola pepe", settings.bebe);
    try testing.expectEqualDeep(@TypeOf(settings.sex){.a = 33, .b = 32, .c=99}, settings.sex);

    //std.debug.print("{}\n", .{settings});
}

pub fn compareArrays(T: type, expected: ?[]T, actual: ?[]T) !void{
    if(expected) |exp|{
        if(actual) |act| {
            for(exp, 0..) |el, i|{
                //std.debug.print("{}\n", .{el});
                try testing.expectEqualDeep(el, act[i]);
            }
            return;
        }
        return error.NullActual;
    }
}
test "Load the array config" {
    var memory: ?yaml_zig.Memory = null;
    const settings = yaml_zig.loadYaml(std.testing.allocator, "data.yaml", template,&memory);
    defer memory.?.free();

    const expected_result = template{
        .data = 1,
        .bebe = "Hola pepe",
        .sex = .{
            .a = 33,
            .b = 32,
            .c = 99,
            .exampleArray = try std.testing.allocator.alloc(Address, 2),
            .exampleSingle = try std.testing.allocator.alloc(Generic, 1)
        }
    };
    defer std.testing.allocator.free(expected_result.sex.exampleArray.?);
    defer std.testing.allocator.free(expected_result.sex.exampleSingle.?);
    expected_result.sex.exampleArray.?[0] = .{.name = "asd.com", .value="12346ab"};
    expected_result.sex.exampleArray.?[1] = .{.name = "pepe.com", .value="1asdba"};
    expected_result.sex.exampleSingle.?[0] = .{.val1 = "jaja", .val = 33, .singao = 2333};

    try testing.expectEqual(1, settings.data);
    try testing.expectEqualStrings("Hola pepe", settings.bebe);
    try compareArrays(Address, expected_result.sex.exampleArray, expected_result.sex.exampleArray);

    //std.debug.print("{}\n", .{settings});
}
