const std = @import("std");
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try PrintHelpMessageAndExit();
        return;
    }

}

}

fn PrintHelpMessageAndExit() !void {
    const helpMessage =
        \\ help - show this help
        \\ add - <description> - add a new task
        \\ update - <id> <description> - update a task's description
        \\ delete - <id> - delete a task
        \\ list - <?status:"todo"|"in-progress"|"done"> - list tasks 
        \\ mark-in-progress - <id> - mark a task as in-progress
        \\ mark-done - <id> - mark a task as done
        \\ NOTE: fields marked with a question mark are optional, the first optional param is ALWAYS the default
    ;
    try stdout.print("{s}\n", .{helpMessage});
    std.process.exit(0);
}

