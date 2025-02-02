const std = @import("std");
const tk = @import("tokamak");
const zqlite = @import("zqlite");

var server_instance: *const *tk.Server = undefined;

const Region = struct {
    RegionID: i64,
    RegionDescription: []const u8,
};

const routes: []const tk.Route = &.{
    .get("/Regions/:id", regionDetail),
};

fn regionDetail(alloc: std.mem.Allocator, conn: zqlite.Conn, id: i64) !Region {
    const query = "select * from Regions where RegionID=?";
    if (try conn.row(query, .{id})) |row| {
        defer row.deinit();
        return .{
            .RegionID = row.int(0),
            .RegionDescription = try std.fmt.allocPrint(
                alloc,
                "{s}",
                .{row.text(1)},
            ),
        };
    }
    return error.NotFound;
}

pub fn main() !void {
    std.debug.print("Starting\n", .{});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var conn = db_connect();
    var cx = .{&conn};

    const lopts: tk.ListenOptions = .{ .port = 8000 };

    const initopts: tk.ServerOptions = .{
        .listen = lopts,
        .injector = tk.Injector.init(&cx, null),
    };

    // call our shutdown function (below) when
    // SIGINT or SIGTERM are received
    std.posix.sigaction(std.posix.SIG.INT, &.{
        .handler = .{ .handler = shutdown },
        .mask = std.posix.empty_sigset,
        .flags = 0,
    }, null);
    std.posix.sigaction(std.posix.SIG.TERM, &.{
        .handler = .{ .handler = shutdown },
        .mask = std.posix.empty_sigset,
        .flags = 0,
    }, null);

    const server = try tk.Server.init(
        gpa.allocator(),
        routes,
        initopts,
    );
    defer server.deinit();
    server_instance = &server;

    try server.start();
}

fn shutdown(_: c_int) callconv(.C) void {
    server_instance.*.stop();
    std.debug.print("\nStopped\n", .{});
}

fn db_connect() !zqlite.Conn {
    return try zqlite.open(
        "./northwind.db",
        zqlite.OpenFlags.EXResCode,
    );
}

test "Test fetching ID 2 from Region" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var alloc = gpa.allocator();
    const conn = try db_connect();

    const result = try regionDetail(alloc, conn, 2);
    std.debug.assert(
        std.mem.eql(u8, result.RegionDescription, "Western"),
    );
    std.debug.assert(result.RegionID == 2);
    alloc.free(result.RegionDescription);
}
