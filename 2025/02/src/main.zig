const std = @import("std");

// Faster but still relatively slow. Better solution would be to generate the numbers by only looking at the first half of the numbers in range and checking if the generated number is in range.

const Range = struct {
    start_num: u64,
    start: []const u8,
    end_num: u64,
    end: []const u8,

    pub fn init_from_string(range: []const u8) !Range {
        var start_end = std.mem.splitScalar(u8, range, '-');
        const start = std.mem.trim(u8, start_end.next().?, &std.ascii.whitespace);
        const start_num = try std.fmt.parseInt(u64, std.mem.trim(u8, start, &std.ascii.whitespace), 10);
        const end = std.mem.trim(u8, start_end.next().?, &std.ascii.whitespace);
        const end_num = try std.fmt.parseInt(u64, std.mem.trim(u8, end, &std.ascii.whitespace), 10);
        std.debug.assert(start_end.next() == null);
        return Range{ .start = start, .start_num = start_num, .end = end, .end_num = end_num };
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
        var set: std.AutoArrayHashMap(u64, void) = std.AutoArrayHashMap(u64, void).init(arena);
        defer set.deinit();
        try generate_invalid_ids_in_range(item, &set, arena);
        try list.appendSlice(arena, set.keys());
        //thread_pool.spawnWg(&wait_group, find_invalid_ids, .{ item, &list, arena });
    }

    // wait for all threads to finish
    wait_group.wait();

    var sum: u64 = 0;
    for (list.items) |item| {
        sum += item;
    }
    std.debug.print("Sum of #{d} elements = {d}\n", .{ list.items.len, sum });
}

fn generate_invalid_ids_in_range(range: Range, set: anytype, allocator: std.mem.Allocator) !void {
    //std.debug.print("Processing range {d}-{d}\n", .{ range.start_num, range.end_num });
    const first_half_start = if (range.start.len < 2) range.start else range.start[0..(range.start.len / 2)];
    const first_half_start_num: u64 = try std.fmt.parseInt(u64, first_half_start, 10);
    var first_half_end = if (range.end.len < 2) range.end else range.end[0..(range.end.len / 2)];
    var first_half_end_num: u64 = try std.fmt.parseInt(u64, first_half_end, 10);
    if (first_half_start_num > first_half_end_num) {
        first_half_end = range.end[0 .. first_half_end.len + 1];
        first_half_end_num = try std.fmt.parseInt(u64, first_half_end, 10);
    }
    for (first_half_start_num..first_half_end_num + 1) |pattern| {
        const pattern_str = try std.fmt.allocPrint(allocator, "{d}", .{pattern});
        defer allocator.free(pattern_str);
        for (1..pattern_str.len + 1) |i| {
            const slice = pattern_str[0..i];
            var generated: std.ArrayList(u8) = .empty;
            defer generated.deinit(allocator);
            var len = range.start.len;
            while (len <= range.end.len) : (len += 1) {
                for (0..(len / slice.len)) |_| {
                    try generated.appendSlice(allocator, slice);
                }
                //std.debug.print("Generated pattern {s}\n", .{generated.items});
                const generated_num = try std.fmt.parseInt(u64, generated.items, 10);
                if (generated.items.len > 1 and generated_num <= range.end_num and generated_num >= range.start_num) {
                    try set.*.put(generated_num, {});
                    std.debug.print("Found repeated pattern {d} in number {s}-{s}\n", .{ generated_num, range.start, range.end });
                }
                generated.clearAndFree(allocator);
            }
        }
    }
}

fn find_invalid_ids(range: Range, list: *std.ArrayList(u64), allocator: std.mem.Allocator) void {
    std.debug.print("Processing range {d}-{d}\n", .{ range.start_num, range.end_num });
    for (range.start_num..range.end_num + 1) |num| {
        const string_num = std.fmt.allocPrint(allocator, "{d}", .{num}) catch unreachable;
        defer allocator.free(string_num);
        if (string_num.len % 2 != 0) {
            continue;
        }
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
