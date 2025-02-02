const std = @import("std");
const tk = @import("tokamak");
const zqlite = @import("zqlite");

const Region = struct {
    RegionID: i64,
    RegionDescription: []const u8,
};

const routes: []const tk.Route = &.{
    .get("/Regions/:id", regionDetail),
};

fn regionDetail(res: *tk.Response, conn: zqlite.Conn, id: i64) !void {
    if (try conn.row(
        "select * from Regions where RegionID=?",
        .{id},
    )) |row| {
        defer row.deinit();
        const result = Region{
            .RegionID = row.int(0),
            .RegionDescription = row.text(1),
        };
        try res.json(result, .{});
    } else {
        res.status = 404;
        res.body = "Not Found";
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var conn = try zqlite.open(
        "./northwind.db",
        zqlite.OpenFlags.EXResCode,
    );
    var cx = .{&conn};

    const lopts: tk.ListenOptions = .{ .port = 8000 };

    const initopts: tk.ServerOptions = .{
        .listen = lopts,
        .injector = tk.Injector.init(&cx, null),
    };

    const server = try tk.Server.init(
        gpa.allocator(),
        routes,
        initopts,
    );
    defer server.deinit();

    try server.start();
}
