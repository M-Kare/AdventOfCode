const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const cwd = std.fs.cwd();
    const file = try cwd.openFile("input", .{});
    defer file.close();

    var read_buffer: [64]u8 = undefined;
    var reader = file.reader(std.testing.io, &read_buffer);

    var line = std.Io.Writer.Allocating.init(allocator);
    defer line.deinit();

    var value: u32 = 50;
    var counter: u32 = 0;
    var line_counter: u32 = 0;

    while (true) {
        _ = reader.interface.streamDelimiter(&line.writer, '\n') catch |err| {
            if (err == error.EndOfStream) break;
        };
        _ = reader.interface.toss(1);

        try handle_instruction(line.written(), &counter, &value);
        std.debug.print("{s} -> {d}\n", .{ line.written(), value });
        line.clearRetainingCapacity();
        line_counter += 1;
    }
    std.debug.print("Lines: {d}, Counter: {d}\n", .{ line_counter, counter });
}

fn handle_instruction(instruction: []const u8, counter: *u32, value: *u32) !void {
    const direction = instruction[0];
    var amount: u32 = try std.fmt.parseInt(u32, instruction[1..], 10);
    a: switch (direction) {
        'R', 'r' => {
            counter.* += (value.* + amount) / 100;
            std.debug.print("0 * {d} encountered: ", .{(value.* + amount) / 100});
            value.* = (value.* + amount) % 100;
            if (value.* == 0) {
                counter.* -= 1;
            }
        },
        'L', 'l' => value.* = std.math.sub(u32, value.*, amount) catch {
            if (value.* != 0) {
                std.debug.print("0 encountered: ", .{});
                counter.* += 1;
            }
            amount = amount - value.*;
            value.* = 100;
            continue :a 'L';
        },
        //'L', 'l' => {
        //    const lmao: i64 = @as(i64, @intCast(value.*)) - amount;
        //    const lmao2: u32 = @truncate(@abs(lmao) % 100);
        //    value.* = 99 - lmao2;
        //},
        else => unreachable,
    }
    if (value.* == 0) {
        counter.* += 1;
    }
}
