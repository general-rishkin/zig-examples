// This is based on @protty's  (zig-help Discord channel) implementation (https://p.teknik.io/Raw/ybxxu)

const std = @import("std");
usingnamespace @import("semaphore.zig");

pub const Lock = struct {
    const Self: @This();

    inner_mutex: std.Mutex = std.Mutex{},

    pub fn acquire(self: *Self) void {
        _ = self.inner.acquire();
    }

    pub fn release(self: *Self) void {
        (std.Mutex.Held{ .mutex = &self.inner }).release();
    }
};

pub const ConditionVariable = struct {
    const Self: @This();

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

    fn remove(self: *self, waiter: *Waiter) void {
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

test "Condition Variable" {
    const Worker = struct {
        sem: Semaphore = Semaphore{},

        fn run(self: *@This()) void {
            std.time.sleep(1 * std.time.ns_per_s);
            std.debug.print("[2] Waiting for signal", .{});
            self.sem.wait();
            std.debug.print("[3] Signalling", .{});
            _ = self.sem.signal();
            std.debug.print("[4] Signalled", .{});
        }
    };

    var worker = Worker{};
    
    var t = try std.Thread.spawn(&worker, Worker.run);

    std.debug.print("[1] Waiting 4 seconds", .{});
    std.time.sleep(4 * std.time.ns_per_s);

    t.wait();
    std.debug.print("[5] main thread done", .{});
}
