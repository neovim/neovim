const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("unibilium", .{});
    const lib = b.addStaticLibrary(.{
        .name = "unibilium",
        .target = target,
        .optimize = optimize,
    });

    lib.addIncludePath(upstream.path(""));

    lib.installHeader(upstream.path("unibilium.h"), "unibilium.h");

    lib.linkLibC();

    lib.addCSourceFiles(.{ .root = upstream.path(""), .files = &.{
        "unibilium.c",
        "uninames.c",
        "uniutil.c",
    }, .flags = &.{"-DTERMINFO_DIRS=\"/etc/terminfo:/usr/share/terminfo\""} });

    b.installArtifact(lib);
}
