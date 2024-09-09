const std = @import("std");
const fs = std.fs;
const json = std.json;
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

    const cwd = try std.process.getCwdAlloc(allocator);
    defer allocator.free(cwd);

    const fileName = "tasks.json";
    var pathBuffer: [1024]u8 = undefined;
    const path = try std.fmt.bufPrint(&pathBuffer, "{s}/{s}", .{ cwd, fileName });

    const file = fs.openFileAbsolute(path, .{ .mode = fs.File.OpenMode.read_write }) catch try fs.createFileAbsolute(path, .{ .read = true });
    defer file.close();

    try ProcessCMD(args, file, path, allocator);
}

fn ProcessCMD(processArgs: [][:0]u8, fileHandle: ?fs.File, path: []const u8, allocator: std.mem.Allocator) !void {
    const cmd = processArgs[1];
    if (std.mem.eql(u8, cmd, "help")) {
        try PrintHelpMessageAndExit();
    } else if (std.mem.eql(u8, cmd, "add")) {
        if (processArgs.len < 3) {
            try stdout.print("Error: missing a description.\n", .{});
            return;
        }
        const subCmd = processArgs[2];
        try Task.AddNewTask(fileHandle.?, subCmd, path, allocator);
    } else if (std.mem.eql(u8, cmd, "delete")) {
        if (processArgs.len < 3) {
            try stdout.print("Error: missing an id.\n", .{});
            return;
        }
        const taskId = processArgs[2];
        try Task.DeleteTask(fileHandle.?, try std.fmt.parseInt(usize, taskId, 10), path, allocator);
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

const Task = struct {
    id: usize,
    description: []const u8,
    status: []const u8,
    createdAt: []const u8,
    updatedAt: []const u8,

    pub fn AddNewTask(file: fs.File, taskDescription: []const u8, path: []const u8, allocator: std.mem.Allocator) !void {
        const readData = file.readToEndAlloc(allocator, 2048) catch |err| {
            try stdout.print("Error Reading file: {any}\n", .{err});
            return;
        };
        defer allocator.free(readData);

        var file_out = try fs.cwd().createFile(path, .{});
        defer file_out.close();

        if (readData.len == 0) {
            const newTask = Task{
                .id = 1,
                .description = taskDescription,
                .status = "todo",
                .createdAt = "2024-09-05T14:30:00",
                .updatedAt = "2024-09-06T09:00:00",
            };
            const newTasks = [_]Task{newTask};

            json.stringify(newTasks, .{}, file_out.writer()) catch |err| {
                try stdout.print("Error stringifying json: {any}\n", .{err});
                return;
            };
            try stdout.print("Task added successfully (ID: 1).\n", .{});
            return;
        }

        var jsonData = try json.parseFromSlice([]Task, allocator, readData, .{});
        defer jsonData.deinit();

        const newTask = Task{
            .id = jsonData.value[jsonData.value.len - 1].id + 1,
            .description = taskDescription,
            .status = "todo",
            .createdAt = "2024-09-05T14:30:00",
            .updatedAt = "2024-09-06T09:00:00",
        };
        var newTasks: []Task = try allocator.alloc(Task, jsonData.value.len + 1);
        defer allocator.free(newTasks);

        for (jsonData.value, 0..) |task, i| {
            newTasks[i] = task;
        }
        newTasks[newTasks.len - 1] = newTask;

        json.stringify(newTasks, .{}, file_out.writer()) catch |err| {
            try stdout.print("Error stringifying json: {any}\n", .{err});
            return;
        };
        try stdout.print("Task added successfully (ID: {d}).\n", .{newTask.id});
    }

    pub fn DeleteTask(file: fs.File, id: usize, path: []const u8, allocator: std.mem.Allocator) !void {
        const readData = file.readToEndAlloc(allocator, 2048) catch |err| {
            try stdout.print("Error Reading file: {any}\n", .{err});
            return;
        };
        defer allocator.free(readData);

        var jsonData = try json.parseFromSlice([]Task, allocator, readData, .{});
        defer jsonData.deinit();

        var newTasks: []Task = try allocator.alloc(Task, jsonData.value.len - 1);
        defer allocator.free(newTasks);

        var i: usize = 0;
        for (jsonData.value) |task| {
            if (id == task.id) continue;
            newTasks[i] = task;
            i += 1;
        }

        var file_out = try fs.cwd().createFile(path, .{});
        defer file_out.close();

        json.stringify(newTasks, .{}, file_out.writer()) catch |err| {
            try stdout.print("Error stringifying json: {any}\n", .{err});
            return;
        };
    }
};
