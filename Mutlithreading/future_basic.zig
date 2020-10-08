const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const testing = std.testing;
const Future = std.event.Future;
 
pub const io_mode = .evented;

pub fn main() void {
    if (builtin.single_threaded) return error.SkipZigTest;
    if (builtin.os.tag == .freebsd) return error.SkipZigTest;
    if (!std.io.is_async) return error.SkipZigTest;

    testFuture();
}

const taskFn = fn() void;

fn testFuture() void {
    var future1 = Future(taskFn).init();
    var future2 = Future(taskFn).init();

    future1.data = task1;
    future2.data = task2;

    var a = async waitOnFuture(&future1);
    var b = async waitOnFuture(&future2);
    resolveFuture(&future1);
    resolveFuture(&future2);

    const result1 = await a;
    const result2 = await b;
}

fn waitOnFuture(future: *Future(taskFn)) void {
    return future.get().*();
}

fn resolveFuture(future: *Future(taskFn)) void {
    future.resolve();
}

fn task1() void { std.debug.print(" TASK1 \n", .{}); }
fn task2() void { std.debug.print(" TASK2 \n", .{}); }