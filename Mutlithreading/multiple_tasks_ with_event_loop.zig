const std = @import("std");
const builtin = @import("builtin");

// Using io_mode = .evented already creates its own event loop and you can get that instance using std.event.Loop.instance.?
pub const io_mode = .evented;

var testRunDetachedData: usize = 0;
pub fn main() !void {
    var loop: std.event.Loop = std.event.Loop.instance.?.*;
    try loop.initMultiThreaded();
    defer loop.deinit();

    // Schedule the execution, won't actually start until we start the
    // event loop.
    try loop.runDetached(std.testing.allocator, testRunDetached, .{});
    try loop.runDetached(std.testing.allocator, a, .{});
    try loop.runDetached(std.testing.allocator, b, .{});
    try loop.runDetached(std.testing.allocator, c, .{});
    try loop.runDetached(std.testing.allocator, d, .{});
    try loop.runDetached(std.testing.allocator, e, .{});
    try loop.runDetached(std.testing.allocator, f, .{});
    try loop.runDetached(std.testing.allocator, g, .{});
    try loop.runDetached(std.testing.allocator, h, .{});
    try loop.runDetached(std.testing.allocator, i, .{});
    try loop.runDetached(std.testing.allocator, j, .{});

    // Now we can start the event loop. The function will return only
    // after all tasks have been completed, allowing us to synchonize
    // with the previous runDetached.
    loop.run();

    std.testing.expect(testRunDetachedData == 1);
}

fn testRunDetached() void { 
    testRunDetachedData += 1; 
    std.debug.print("ThreadID = {} => \ttestRunDetachedData = {}\n", .{std.Thread.getCurrentId(), testRunDetachedData}); 
}
fn a() void { std.debug.print("ThreadID = {} => \tDispatch a\n", .{std.Thread.getCurrentId()}); }
fn b() void { std.debug.print("ThreadID = {} => \tDispatch b\n", .{std.Thread.getCurrentId()}); }
fn c() void { std.debug.print("ThreadID = {} => \tDispatch c\n", .{std.Thread.getCurrentId()}); }
fn d() void { std.debug.print("ThreadID = {} => \tDispatch d\n", .{std.Thread.getCurrentId()}); }
fn e() void { std.debug.print("ThreadID = {} => \tDispatch e\n", .{std.Thread.getCurrentId()}); }
fn f() void { std.debug.print("ThreadID = {} => \tDispatch f\n", .{std.Thread.getCurrentId()}); }
fn g() void { std.debug.print("ThreadID = {} => \tDispatch g\n", .{std.Thread.getCurrentId()}); }
fn h() void { std.debug.print("ThreadID = {} => \tDispatch h\n", .{std.Thread.getCurrentId()}); }
fn i() void { std.debug.print("ThreadID = {} => \tDispatch i\n", .{std.Thread.getCurrentId()}); }
fn j() void { std.debug.print("ThreadID = {} => \tDispatch j\n", .{std.Thread.getCurrentId()}); }
