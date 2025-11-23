const std = @import("std");

const line_length = 12;

pub fn main() !void {
    var mem = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = mem.allocator();

    const argv = try std.process.argsAlloc(allocator);

    if (argv.len != 3)
        @panic("invalid arguments. requries fake-xxd <input> <output>");

    const blob = try std.fs.cwd().readFileAlloc(allocator, argv[1], 1 << 20);

    const symbol_name = try allocator.dupe(u8, std.fs.path.basename(argv[1]));

    for (symbol_name) |*c| {
        c.* = switch (c.*) {
            'a'...'z', 'A'...'Z', '0'...'9', '_' => c.*,
            else => '_',
        };
    }

    var output_buffer: [1024]u8 = undefined;
    var output = try std.fs.cwd().atomicFile(argv[2], .{ .write_buffer = &output_buffer });
    defer output.deinit();

    const writer = &output.file_writer.interface;

    try writer.print("unsigned char {s}[] = {{\n", .{symbol_name});

    for (blob, 0..blob.len) |char, index| {
        if ((index % line_length) == 0) {
            if (index > 0) {
                try writer.writeAll(",\n  ");
            } else {
                try writer.writeAll("  ");
            }
        } else {
            try writer.writeAll(", ");
        }

        try writer.print("0x{X:0>2}", .{char});
    }
    if ((blob.len % line_length) == 0) {
        try writer.writeAll("\n");
    }

    try writer.print("}};\nunsigned int {s}_len = {d};\n", .{ symbol_name, blob.len });

    try output.finish();

    //

}
