const std = @import("std");

fn loadFile(allocator: std.mem.Allocator, path: []const u8) ![]u8{
    var file = try std.fs.cwd().openFile(path, .{.mode = .read_only});
    defer file.close();
    return try file.readToEndAlloc(allocator, std.math.maxInt(u32));
}

const Entry = struct{
    spaces: usize = 0,
    name: ?[]const u8 = null,
    value: ?[]const u8 = null,
};
fn parseLine(line: *[]const u8) Entry{
    var i: usize = 0;
    var name_end_index: usize = 0;
    var result = Entry{};

    if(line.len == 0)
        return result;
    
    //First count spaces
    while(i < line.len and (line.*[i] == ' ' or line.*[i] == '\t')){
        result.spaces+=1;
        i+=1;
    }

    //Seek for :
    while(i < line.len and (line.*[i] != ':')){
        i+=1;
    }

    //From last space to : is the name of the value
    result.name = line.*[result.spaces..(i)];
    
    //Seek for the start of the string
    while(i < line.len and (line.*[i] == ' ' or line.*[i] == '\t' or line.*[i] == ':')){
        i+=1;
    }

    //Remove spaces from the end.
    name_end_index = i;
    i = line.len;
    while(i > name_end_index and (line.*[i-1] == ' ' or line.*[i-1] == '\t' or line.*[i-1] == '\n')){
        i-=1;
    }

    result.value = line.*[name_end_index..(i)];
    return result;

}

fn iterateStruct(
    comptime T: type, //This type changes while iterating.
    result: *T, 
    name: []const u8, 
    level: usize, 
    it: *StringIterator
) void{
    var _l: ?[]const u8 = "";
    if(level != 0)
        _l = it.next();

    if(_l) |l| {
        const entry = parseLine(@constCast(&l));

        if(entry.name != null and !std.mem.eql(u8, name, entry.name.?))
            std.debug.print("[ ERROR ](FileParser): Error on line: {d}, expected: {s}, found: {?s}\n", .{
                it.iterated_lines,
                name,
                entry.name
            });

        std.debug.print(" - File Name: {?s}\n", .{entry.name});
        std.debug.print(" - File Value: {?s}\n", .{entry.value});

        tselect: switch (@typeInfo(T)) {
            .@"struct" => {

                if(@hasField(T, "len") and @hasField(T, "ptr")){
                    //Its an slice
                    
                    if(@field(T, "ptr").type == .@"pointer"){
                        //Its an array
                    }


                    break: tselect;
                }

                inline for(std.meta.fields(T)) |field| 
                    iterateStruct(field.type, &@field(result, field.name), field.name, level+1, it);
                
                break: tselect;

            },
            .int => {

                const val = std.fmt.parseInt(T, entry.value.?, 10) catch 0;
                std.debug.print("{d} Number: {s}, value: {d}\n", .{level, name, val});
                result.* = val;
                
                break: tselect;
            },
            .float => {
                const val = std.fmt.parseFloat(T, entry.value.?) catch 0;
                std.debug.print("{d} Number: {s}, value: {d}\n", .{level, name, val});

                result.* = val;

                break: tselect;
            },
            .pointer => |field| {
                std.debug.print("{s}\n", .{@typeName(T)});

                switch (@typeInfo(field.child)) {
                    .int => |int| {
                        //Check if the ptr is []const u8. We will use it as string.
                        if(int.bits == 8 and field.is_const){
                            //String
                            std.debug.print("{d} String: {s}\n", .{level, name});
                            result.* = entry.value.?;
                            break: tselect;
                        }

                        //Array of something else
                        std.debug.print("{d} Slice: {s}\n", .{level, name});
                    }, else => {
                        @compileError("Cannot have pointers inside a yaml file");
                    }
                }
                break: tselect;
            },
            else => {
                std.debug.print("{d} {any}", .{level, T});
                break: tselect;
            }
        }             
    }
}

const StringIterator = struct{
    string: *[]const u8,
    separator: u8,
    index: usize = 0,
    iterated_lines: usize = 0,
    pub fn next(Self: *StringIterator) ?[]const u8{
        var i: usize = Self.index;
        var entered: bool = false;
        var result: ?[]const u8 = null;


        Self.iterated_lines += 1;

        while(i < Self.string.len){
            entered = true;

            if(Self.string.*[i] == Self.separator){
                result = Self.string.*[Self.index..i];
                Self.index = i+1;
                //Se hace return aqui para no ir al caso final
                return result;
            }

            i+=1;
        }


        //Si el archivo no acaba en nueva línea.
        if(entered)
            return Self.string.*[Self.index..Self.string.len];

        return null;
    }
};

pub fn loadYaml(allocator: std.mem.Allocator, file: []const u8, comptime template: type, memory: *?[]u8) template{

    var res = template{};

    if(memory.* == null){
        memory.* = loadFile(allocator, file) catch {
            return template{};
        };
        //defer allocator.free(loaded_data);
        //std.debug.print("Texto: {s}\n", .{loaded_data});
        std.debug.print("Cooking: \n", .{});
        
        var sit = StringIterator{
            .string = @ptrCast(&(memory.*.?)),
            .separator = '\n'
        };

        iterateStruct(template,&res, "", 0, &(sit));
    }

    return res;
}

const eql = std.testing.expectEqualSlices;
test "String Iterator test"{


    //Con intro al final del archio
    var a: []const u8 = "Hola\nPerikillo el de los palotes\n";
    var it = StringIterator{ .separator = '\n', .string = &a };
    try eql(u8, "Hola", it.next().?);
    try eql(u8, "Perikillo el de los palotes", it.next().?);
    try std.testing.expect(it.next() == null);

    //Sin intro al final del archio
    var b: []const u8 = "Hola\nPerikillo el de los palotes";
    var it2 = StringIterator{ .separator = '\n', .string = &b };
    try eql(u8, "Hola", it2.next().?);
    try eql(u8, "Perikillo el de los palotes", it2.next().?);
    try std.testing.expect(it.next() == null);
    
}

test "Entry parser test"{
    const line1: []const u8 = "  asdasd: me meotio";
    const line2: []const u8 = "asdasd2: me meotio2\n";
    const line3: []const u8 = "asdasd3:\n";
    const line4: []const u8 = "asdasd3:         \n";

    var entry = parseLine(@constCast(&line1));
    try eql(u8, "asdasd",entry.name.?);
    try eql(u8, "me meotio",entry.value.?);

    entry = parseLine(@constCast(&line2));
    try eql(u8, "asdasd2",entry.name.?);
    try eql(u8, "me meotio2",entry.value.?);

    entry = parseLine(@constCast(&line3));
    try eql(u8, "asdasd3",entry.name.?);
    try eql(u8, "",entry.value.?);

    entry = parseLine(@constCast(&line4));
    try eql(u8, "asdasd3",entry.name.?);
    try eql(u8, "",entry.value.?);
}
