// This is a Zig implementation of https://gist.github.com/mepcotterell/6f0a779befe388ab822764255e3776ae .

const std = @import("std");

pub fn atomicFlagTestAndSet(flag: *u1) u1 {
    return @atomicRmw(u1, flag, .Xchg, 1, .SeqCst);
}

pub const Semaphore = struct {
    const Self = @This();

    value: std.atomic.Int(i8) = std.atomic.Int(i8).init(0),
    is_mutated: u1          = 0,

    pub fn init() void {
        .value = std.atomic.Int(u8).init(0);
        .is_mutated = 0;
    }

    fn wait(self: *Self) void {
        while(1 == atomicFlagTestAndSet(&self.is_mutated)) {}

        while(self.value.get() <= 0) {}
        const previous_value = self.value.decr();

        _ = @atomicRmw(u1, &self.is_mutated, .Xchg, @as(u1, 0), .SeqCst);
    }

    pub fn signal(self: *Self) i32 {
        return self.value.fetchAdd(1);
    } 
};

pub fn main() !void {
    const Context = struct{
        const Self = @This();

        ping: []const u8 = "ping",
        pong: []const u8 = "pong",

        sem: Semaphore = Semaphore{},

        fn Ping(self: *Self) void {
            while (true) {
                self.sem.wait();
                self.critical(self.ping);
                _ = self.sem.signal();
            }
        }
        
        fn Pong(self: *Self) void {
            while (true) {
                self.sem.wait();
                self.critical(self.pong);
                _ = self.sem.signal();
            }
        }

        pub fn critical(self: Self, arg_str: []const u8) void {
            var str = arg_str;
            var len: usize = str.len;
            {
                var i: usize = 0;
                for (str) |byte| {
                    const ch = [_]u8{byte};
                    std.debug.print("{}\n", .{ch});
                }
            }
            std.debug.print("\n", .{});
        }

    };

    var context = Context{}; 
    context.sem.value.set(1);
    const ping = try std.Thread.spawn(&context, Context.Ping);
    const pong = try std.Thread.spawn(&context, Context.Pong);

    ping.wait();
    pong.wait();
}

var lock_stream: u1 = 0;
test "Atomic Test and Set" {
    var t: u1 = 0;
    std.debug.print("\ntt was     = {}\n", .{t});
    var res = atomicFlagTestAndSet(&t);
    std.debug.print("res is     = {}\n", .{res});
    std.debug.print("t is now = {}\n", .{t});
    res = atomicFlagTestAndSet(&t);
    std.debug.print("res is now = {}\n", .{res});
    
    const Context = struct{
        x: i32 = -1,

        fn appendNumber(self: *@This()) void {
            while(1 == atomicFlagTestAndSet(&lock_stream)) {}
            self.x += 1;
            std.debug.print("thread {}\n", .{self.x});
            lock_stream = 0;
        }
    };

    var threads = std.ArrayList(*std.Thread).init(std.heap.c_allocator);
    var thread_index: usize = 0;
    const thread_count: usize = 11;
    var context = Context{};
    while (thread_index < thread_count) : (thread_index += 1) {
        try threads.append(try std.Thread.spawn(&context, Context.appendNumber));
    }

    for (threads.items) |thread| {
        thread.wait();
    }
      
    threads.deinit();
}
