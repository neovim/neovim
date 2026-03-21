const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .name = "unibilium",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    if (b.lazyDependency("unibilium", .{})) |upstream| {
        lib.addIncludePath(upstream.path(""));

        lib.installHeader(upstream.path("unibilium.h"), "unibilium.h");

        lib.linkLibC();

        lib.addCSourceFiles(.{ .root = upstream.path(""), .files = &.{
            "unibilium.c",
            "uninames.c",
            "uniutil.c",
        }, .flags = &.{"-DTERMINFO_DIRS=\"/etc/terminfo:/usr/share/terminfo\""} });
    }

    b.installArtifact(lib);
}
