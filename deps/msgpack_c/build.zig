const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("msgpack_c", .{});
    const lib = b.addStaticLibrary(.{
        .name = "msgpack_c",
        .target = target,
        .optimize = optimize,
    });

    // via getEmittedIncludeTree to merge in configs properly
    // lib.addIncludePath(upstream.path("include"));
    lib.addIncludePath(upstream.path("src"));

    // TODO: actually detect BIG-lyness of `target`
    const sysdep = b.addConfigHeader(.{
        .style = .{ .cmake = upstream.path("cmake/sysdep.h.in") },
        .include_path = "msgpack/sysdep.h",
    }, .{ .MSGPACK_ENDIAN_BIG_BYTE = "0", .MSGPACK_ENDIAN_LITTLE_BYTE = "1" });
    lib.addConfigHeader(sysdep);

    const pack_template = b.addConfigHeader(.{
        .style = .{ .cmake = upstream.path("cmake/pack_template.h.in") },
        .include_path = "msgpack/pack_template.h",
    }, .{ .MSGPACK_ENDIAN_BIG_BYTE = "0", .MSGPACK_ENDIAN_LITTLE_BYTE = "1" });
    lib.addConfigHeader(pack_template);

    lib.installHeadersDirectory(upstream.path("include"), ".", .{});
    lib.installConfigHeader(sysdep);
    lib.installConfigHeader(pack_template);
    lib.addIncludePath(lib.getEmittedIncludeTree());

    lib.linkLibC();

    lib.addCSourceFiles(.{ .root = upstream.path(""), .files = &.{
        "src/objectc.c",
        "src/unpack.c",
        "src/version.c",
        "src/vrefbuffer.c",
        "src/zone.c",
    } });

    b.installArtifact(lib);
}
