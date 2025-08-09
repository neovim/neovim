const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("utf8proc", .{});
    const lib = b.addLibrary(.{
        .name = "utf8proc",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    lib.addIncludePath(upstream.path(""));
    lib.installHeader(upstream.path("utf8proc.h"), "utf8proc.h");

    lib.linkLibC();

    lib.addCSourceFiles(.{ .root = upstream.path(""), .files = &.{
        "utf8proc.c",
    } });

    b.installArtifact(lib);
}
