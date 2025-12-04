const std = @import("std");

// Faster but still relatively slow. Better solution would be to generate the numbers by only looking at the first half of the numbers in range and checking if the generated number is in range.

const Range = struct {
    start: u64,
    end: u64,

    pub fn init_from_string(range: []const u8) !Range {
        var start_end = std.mem.splitScalar(u8, range, '-');
        const start = try std.fmt.parseInt(u64, std.mem.trim(u8, start_end.next().?, &std.ascii.whitespace), 10);
        const end = try std.fmt.parseInt(u64, std.mem.trim(u8, start_end.next().?, &std.ascii.whitespace), 10);
        std.debug.assert(start_end.next() == null);
        return Range{ .start = start, .end = end };
    }
};

pub fn main() !void {
    var single_threaded_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer single_threaded_arena.deinit();

    var thread_safe_arena: std.heap.ThreadSafeAllocator = .{
        .child_allocator = single_threaded_arena.allocator(),
    };
    const arena = thread_safe_arena.allocator();

    const file = try std.fs.cwd().openFile("input", .{});
    //const file = try std.fs.cwd().openFile("input_test", .{});
    defer file.close();
    var buffer: [1024]u8 = undefined;

    var list: std.ArrayList(u64) = .empty;
    defer list.deinit(arena);

    const bytes_read = try file.read(&buffer);
    var tokenized_ranges = std.mem.tokenizeAny(u8, buffer[0..bytes_read], ",");
    var ranges: std.ArrayList(Range) = .empty;

    // Collect all ranges
    while (tokenized_ranges.next()) |range| {
        try ranges.append(arena, try Range.init_from_string(range));
    }

    // do calculations in parallel
    var wait_group: std.Thread.WaitGroup = .{};
    wait_group.reset();

    var thread_pool: std.Thread.Pool = undefined;
    try thread_pool.init(std.Thread.Pool.Options{
        .allocator = arena, // this is an arena allocator from `std.heap.ArenaAllocator`
    });
    defer thread_pool.deinit();

    for (ranges.items) |item| {
        thread_pool.spawnWg(&wait_group, find_invalid_ids, .{ item, &list, arena });
    }

    // wait for all threads to finish
    wait_group.wait();

    var sum: u64 = 0;
    for (list.items) |item| {
        sum += item;
    }
    std.debug.print("{d}\n", .{sum});
}

fn find_invalid_ids(range: Range, list: *std.ArrayList(u64), allocator: std.mem.Allocator) void {
    std.debug.print("Processing range {d}-{d}\n", .{ range.start, range.end });
    for (range.start..range.end + 1) |num| {
        const string_num = std.fmt.allocPrint(allocator, "{d}", .{num}) catch unreachable;
        defer allocator.free(string_num);
        for (1..(string_num.len / 2) + 1) |i| {
            const has_pattern: bool = std.mem.eql(u8, string_num[0..i], string_num[i..]);
            if (has_pattern) {
                std.debug.print("Found repeated pattern {s} in number {s}\n", .{ string_num[0..i], string_num });
                list.*.append(allocator, num) catch unreachable;
                break;
            }
        }
    }
}
