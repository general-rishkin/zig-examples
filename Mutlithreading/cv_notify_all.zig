const std = @import("std");

/// Single-producer, many-consumer.
/// This example reproduces the example for C++'s condition_variable::notify_all 
/// from http://www.cplusplus.com/reference/condition_variable/condition_variable/notify_all/ . 

const Context = struct {
    const Self = @This();

    ready: bool = false,
    in: std.ResetEvent = std.ResetEvent.init(),
    threads_list: std.ArrayList(*std.Thread) = std.ArrayList(*std.Thread).init(std.heap.c_allocator),
    
    fn init(self: *Self, thread_count: usize) !void {
        var thread_index: usize = 0;
        while (thread_index < thread_count) : (thread_index += 1) {
            try self.threads_list.append(try std.Thread.spawn(self, Context.receiver));
        }
    }

    fn deinit(self: *Self) void {
        for (self.threads_list.items) |thread|
            thread.wait();
            
        self.in.deinit();
        self.threads_list.deinit();
        self.* = undefined;
    }

    fn sender(self: *Self) void {
        std.testing.expect(self.ready == false);
        self.ready = true;
        self.in.set();
    }

    fn receiver(self: *Self) void {
        self.in.wait();
        
        std.debug.print("Thread {}\n", .{std.Thread.getCurrentId()});
    }
};

pub fn main() !void {
    const thread_count: usize = 11;
    var context = Context{}; 
    try context.init(thread_count);
    defer context.deinit();
    
    std.debug.print("{} threads ready to race...\n", .{thread_count});
    context.sender();
}
