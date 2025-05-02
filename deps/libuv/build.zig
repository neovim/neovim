const std = @import("std");

// Based on mitchellh/zig-libuv, with changes.
pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("libuv", .{});
    const lib = b.addStaticLibrary(.{
        .name = "uv",
        .target = target,
        .optimize = optimize,
    });

    lib.addIncludePath(upstream.path("include"));
    lib.addIncludePath(upstream.path("src"));

    lib.installHeadersDirectory(upstream.path("include"), ".", .{});

    if (target.result.os.tag == .windows) {
        lib.linkSystemLibrary("psapi");
        lib.linkSystemLibrary("user32");
        lib.linkSystemLibrary("advapi32");
        lib.linkSystemLibrary("iphlpapi");
        lib.linkSystemLibrary("userenv");
        lib.linkSystemLibrary("ws2_32");
    }
    if (target.result.os.tag == .linux) {
        lib.linkSystemLibrary("pthread");
    }
    lib.linkLibC();

    if (target.result.os.tag != .windows) {
        lib.root_module.addCMacro("FILE_OFFSET_BITS", "64");
        lib.root_module.addCMacro("_LARGEFILE_SOURCE", "");
    }

    if (target.result.os.tag == .linux) {
        lib.root_module.addCMacro("_GNU_SOURCE", "");
        lib.root_module.addCMacro("_POSIX_C_SOURCE", "200112");
    }

    if (target.result.os.tag.isDarwin()) {
        lib.root_module.addCMacro("_DARWIN_UNLIMITED_SELECT", "1");
        lib.root_module.addCMacro("_DARWIN_USE_64_BIT_INODE", "1");
    }

    const root = upstream.path("");

    // C files common to all platforms
    lib.addCSourceFiles(.{ .root = root, .files = &.{
        "src/fs-poll.c",
        "src/idna.c",
        "src/inet.c",
        "src/random.c",
        "src/strscpy.c",
        "src/strtok.c",
        "src/threadpool.c",
        "src/timer.c",
        "src/uv-common.c",
        "src/uv-data-getter-setters.c",
        "src/version.c",
    } });

    if (target.result.os.tag != .windows) {
        lib.addCSourceFiles(.{ .root = root, .files = &.{
            "src/unix/async.c",
            "src/unix/core.c",
            "src/unix/dl.c",
            "src/unix/fs.c",
            "src/unix/getaddrinfo.c",
            "src/unix/getnameinfo.c",
            "src/unix/loop-watcher.c",
            "src/unix/loop.c",
            "src/unix/pipe.c",
            "src/unix/poll.c",
            "src/unix/process.c",
            "src/unix/random-devurandom.c",
            "src/unix/signal.c",
            "src/unix/stream.c",
            "src/unix/tcp.c",
            "src/unix/thread.c",
            "src/unix/tty.c",
            "src/unix/udp.c",
        } });
    }

    if (target.result.os.tag == .linux or target.result.os.tag.isDarwin()) {
        lib.addCSourceFiles(.{ .root = root, .files = &.{
            "src/unix/proctitle.c",
        } });
    }

    if (target.result.os.tag == .linux) {
        lib.addCSourceFiles(.{ .root = root, .files = &.{
            "src/unix/linux.c",
            "src/unix/procfs-exepath.c",
            "src/unix/random-getrandom.c",
            "src/unix/random-sysctl-linux.c",
        } });
    }

    if (target.result.os.tag.isBSD()) {
        lib.addCSourceFiles(.{ .root = root, .files = &.{
            "src/unix/bsd-ifaddrs.c",
            "src/unix/kqueue.c",
        } });
    }

    if (target.result.os.tag.isDarwin() or target.result.os.tag == .openbsd) {
        lib.addCSourceFiles(.{ .root = root, .files = &.{
            "src/unix/random-getentropy.c",
        } });
    }

    if (target.result.os.tag.isDarwin()) {
        lib.addCSourceFiles(.{ .root = root, .files = &.{
            "src/unix/darwin-proctitle.c",
            "src/unix/darwin.c",
            "src/unix/fsevents.c",
        } });
    }

    b.installArtifact(lib);
}
