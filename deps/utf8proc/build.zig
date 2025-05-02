const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("utf8proc", .{});
    const lib = b.addStaticLibrary(.{
        .name = "utf8proc",
        .target = target,
        .optimize = optimize,
    });

    lib.addIncludePath(upstream.path(""));
    lib.installHeader(upstream.path("utf8proc.h"), "utf8proc.h");

    lib.linkLibC();

    lib.addCSourceFiles(.{ .root = upstream.path(""), .files = &.{
        "utf8proc.c",
    } });

    b.installArtifact(lib);
}
