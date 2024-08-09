const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("vterm", .{});
    const lib = b.addStaticLibrary(.{
        .name = "vterm",
        .target = target,
        .optimize = optimize,
    });

    lib.addIncludePath(upstream.path("src/"));
    lib.addIncludePath(upstream.path("include/"));
    // local additions: DECdrawing.inc and uk.inc (u w8t m8)
    lib.addIncludePath(b.path("include/"));

    lib.installHeadersDirectory(upstream.path("include"), ".", .{});

    lib.linkLibC();

    lib.addCSourceFiles(.{ .root = upstream.path("src"), .files = &.{
        "encoding.c",
        "keyboard.c",
        "mouse.c",
        "parser.c",
        "pen.c",
        "screen.c",
        "state.c",
        "unicode.c",
        "vterm.c",
    } });

    b.installArtifact(lib);
}
