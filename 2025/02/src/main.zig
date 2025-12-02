const std = @import("std");

// Way too slow. Should parallelize the find_invalid_ids function calls by using threads.

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const file = try std.fs.cwd().openFile("input", .{});
    defer file.close();
    var buffer: [1024]u8 = undefined;

    var list: std.ArrayList(u64) = .empty;
    defer list.deinit(allocator);

    const bytes_read = try file.read(&buffer);
    var ranges = std.mem.tokenizeAny(u8, buffer[0..bytes_read], ",");

    while (ranges.next()) |range| {
        var start_end = std.mem.splitScalar(u8, range, '-');
        const start = try std.fmt.parseInt(u64, start_end.next() orelse break, 10);
        const end = try std.fmt.parseInt(u64, std.mem.trim(u8, start_end.next() orelse break, &std.ascii.whitespace), 10);
        std.debug.assert(start_end.next() == null);
        std.debug.print("Processing range {d}-{d}\n", .{ start, end });
        try find_invalid_ids(start, end, &list, allocator);
    }
    var sum: u64 = 0;
    for (list.items) |item| {
        sum += item;
    }
    std.debug.print("{d}\n", .{sum});
}

fn find_invalid_ids(start: u64, end: u64, list: *std.ArrayList(u64), allocator: std.mem.Allocator) !void {
    for (start..end + 1) |num| {
        const string_num = try std.fmt.allocPrint(allocator, "{d}", .{num});
        defer allocator.free(string_num);
        for (1..(string_num.len / 2) + 1) |i| {
            const has_pattern: bool = std.mem.eql(u8, string_num[0..i], string_num[i..]);
            if (has_pattern) {
                std.debug.print("Found repeated pattern {s} in number {s}\n", .{ string_num[0..i], string_num });
                try list.*.append(allocator, num);
                break;
            }
        }
    }
}
