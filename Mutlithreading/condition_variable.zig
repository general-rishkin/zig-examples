// This is based on @protty's  (zig-help Discord channel) implementation (https://p.teknik.io/Raw/ybxxu)

const std = @import("std");
usingnamespace @import("semaphore.zig");

pub const Lock = struct {
    const Self = @This();

    inner_mutex: std.Mutex = std.Mutex{},

    pub fn acquire(self: *Self) void {
        _ = self.inner_mutex.acquire();
    }

    pub fn release(self: *Self) void {
        (std.Mutex.Held{ .mutex = &self.inner_mutex }).release();
    }
};

pub const ConditionVariable = struct {
    const Self = @This();

    head: ?*Waiter = null,

    const Waiter = struct {
        prev: ?*Waiter,
        next: ?*Waiter,
        last: *Waiter,
        event: std.ResetEvent,
    };

    pub fn wait(self: *Self, lock: *Lock) void {
        var waiter: Waiter = undefined;
        waiter.event = std.ResetEvent.init();
        defer waiter.event.deinit();

        self.push(&waiter);
        lock.release();

        waiter.event.wait();
        lock.acquire();
    }

    pub fn timedWait(self: *Self, lock: *Lock, timeout: u64) error{TimedOut}!void {
        var waiter: Waiter = undefined;
        waiter.event = std.ResetEvent.init();
        defer waiter.event.deinit();

        self.push(&waiter);
        lock.release();

        const timed_out = blk: {
            if (waiter.event.timedWait(timeout)) |_| {
                break :blk false;
            } else |_| {
                break :blk true;
            }
        };

        lock.acquire();
        self.remove(&waiter);

        if (timed_out)
            return error.TimedOut;
    }

    pub fn signal(self: *Self) void {
        if (self.pop()) |waiter|
            waiter.event.set();
    }

    pub fn broadcast(self: *Self) void {
        while (self.pop()) |waiter|
            waiter.event.set();
    }

    fn push(self: *Self, waiter: *Waiter) void {
        waiter.next = null;
        waiter.last = waiter;

        if (self.head) |head| {
            waiter.prev = head.last;
            head.last.next = waiter;
            head.last = waiter;
        } else {
            waiter.prev = null;
            self.head = waiter;
        }
    }

    fn pop(self: *Self) ?*Waiter {
        const waiter = self.head orelse return null;
        self.remove(waiter);
        return waiter;
    }

    fn remove(self: *Self, waiter: *Waiter) void {
        const head = self.head orelse return;

        if (waiter.prev) |prev|
            prev.next = waiter.next;
        if (waiter.next) |next|
            next.prev = waiter.prev;

        if (head == waiter) {
            self.head = waiter.next;
            if (self.head) |new_head|
                new_head.last = head.last;
        } else if (head.last == waiter) {
            head.last = waiter.prev.?;
        }

        waiter.prev = null;
        waiter.next = null;
        waiter.last = waiter;
    }
};

test "C++'s condition_variable::notify_one" {
    // http://www.cplusplus.com/reference/condition_variable/condition_variable/notify_one/
    
    const ThreadContext = struct {
        const Self = @This();

        cargo: u32 = 0,
        cv_produce: ConditionVariable = ConditionVariable{},
        cv_consume: ConditionVariable = ConditionVariable{},

        fn consumer(self: *Self) void {
            var lock = Lock{};
            while (0 == self.cargo) self.cv_consume.wait(&lock);
            std.debug.print("Thread {} => consuming => {}\n", .{std.Thread.getCurrentId(), self.cargo});
            self.cargo = 0;
            self.cv_produce.signal();
        }

        fn producer(self: *Self) void {
            var lock = Lock{};
            while (0 != self.cargo) self.cv_produce.wait(&lock);
            self.cargo = std.Thread.getCurrentId();
            self.cv_consume.signal();
        }
    };

    std.debug.print("\n\n", .{});

    var thread_context = ThreadContext{};
    
    const thread_count = 11;
    var consumers: [thread_count]*std.Thread = undefined;
    var producers: [thread_count]*std.Thread = undefined;

    for (consumers) |*cs| {
        cs.* = try std.Thread.spawn(&thread_context, ThreadContext.consumer);
    }

    for (producers) |*pd| {
        pd.* = try std.Thread.spawn(&thread_context, ThreadContext.producer);
    }

    for (consumers) |cs|
        cs.wait();

    for (producers) |pd|
        pd.wait();
}

test "C++'s condition_variable::notify_all" {
    // http://www.cplusplus.com/reference/condition_variable/condition_variable/notify_all/

    const ThreadContext = struct {
        const Self = @This();

        ready: bool                             = false,
        condition_variable: ConditionVariable   = ConditionVariable{},

        fn print_id(self: *Self) void {
            var lock = Lock{};
            while (false == self.ready) self.condition_variable.wait(&lock);
            std.debug.print("Thread ID = {}\n", .{std.Thread.getCurrentId()});
        }

        fn go(self: *Self) void {
            var lock = Lock{};
            self.ready = true;
            self.condition_variable.broadcast();
        }
    };

    std.debug.print("\n\n", .{});
    var thread_context = ThreadContext{};
    
    const thread_count = 11;
    var threads: [thread_count]*std.Thread = undefined;

    for (threads) |*thread| {
        thread.* = try std.Thread.spawn(&thread_context, ThreadContext.print_id);
    }

    thread_context.go();
    for (threads) |thread|
        thread.wait();
}
