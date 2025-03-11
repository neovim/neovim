const std = @import("std");
const LazyPath = std.Build.LazyPath;

pub fn build_nlua0(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    use_luajit: bool,
    ziglua: *std.Build.Dependency,
    lpeg: *std.Build.Dependency,
) *std.Build.Step.Compile {
    const options = b.addOptions();
    options.addOption(bool, "use_luajit", use_luajit);

    const nlua0_exe = b.addExecutable(.{
        .name = "nlua0",
        .root_source_file = b.path("src/nlua0.zig"),
        .target = target,
        .optimize = optimize,
    });
    const nlua0_mod = nlua0_exe.root_module;

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/nlua0.zig"),
        .target = target,
        .optimize = optimize,
    });

    const embedded_data = b.addModule("embedded_data", .{
        .root_source_file = b.path("runtime/embedded_data.zig"),
    });

    for ([2]*std.Build.Module{ nlua0_mod, exe_unit_tests.root_module }) |mod| {
        mod.addImport("ziglua", ziglua.module("lua_wrapper"));
        mod.addImport("embedded_data", embedded_data);
        // addImport already links by itself. but we need headers as well..
        mod.linkLibrary(ziglua.artifact("lua"));

        mod.addOptions("options", options);

        mod.addIncludePath(b.path("src"));
        mod.addIncludePath(b.path("src/includes_fixmelater"));
        add_lua_modules(mod, lpeg, use_luajit, true);
    }

    // for debugging the nlua0 environment
    // like this: `zig build nlua0 -- script.lua {args}`
    const run_cmd = b.addRunArtifact(nlua0_exe);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("nlua0", "Run nlua0 build tool");
    run_step.dependOn(&run_cmd.step);

    b.installArtifact(nlua0_exe); // DEBUG

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test_nlua0", "Run unit tests for nlua0");
    test_step.dependOn(&run_exe_unit_tests.step);

    return nlua0_exe;
}

pub fn add_lua_modules(mod: *std.Build.Module, lpeg: *std.Build.Dependency, use_luajit: bool, is_nlua0: bool) void {
    const flags = [_][]const u8{
        // Standard version used in Lua Makefile
        "-std=gnu99",
        if (is_nlua0) "-DNVIM_NLUA0" else "",
    };

    mod.addIncludePath(lpeg.path(""));
    mod.addCSourceFiles(.{
        .files = &.{
            "src/mpack/lmpack.c",
            "src/mpack/mpack_core.c",
            "src/mpack/object.c",
            "src/mpack/conv.c",
            "src/mpack/rpc.c",
        },
        .flags = &flags,
    });
    mod.addCSourceFiles(.{
        .root = .{ .dependency = .{ .dependency = lpeg, .sub_path = "" } },
        .files = &.{
            "lpcap.c",
            "lpcode.c",
            "lpcset.c",
            "lpprint.c",
            "lptree.c",
            "lpvm.c",
        },
        .flags = &flags,
    });

    if (!use_luajit) {
        mod.addCSourceFiles(.{
            .files = &.{
                "src/bit.c",
            },
            .flags = &flags,
        });
    }
}

pub fn build_libluv(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    lua: *std.Build.Step.Compile,
    libuv: *std.Build.Step.Compile,
) !*std.Build.Step.Compile {
    const upstream = b.dependency("libluv", .{});
    const compat53 = b.dependency("lua_compat53", .{});
    const lib = b.addStaticLibrary(.{
        .name = "luv",
        .target = target,
        .optimize = optimize,
    });

    lib.linkLibrary(lua);
    lib.linkLibrary(libuv);

    lib.addIncludePath(upstream.path("src"));
    lib.addIncludePath(compat53.path("c-api"));

    lib.installHeader(upstream.path("src/luv.h"), "luv/luv.h");

    lib.addCSourceFiles(.{ .root = upstream.path("src/"), .files = &.{
        "luv.c",
    } });

    lib.addCSourceFiles(.{ .root = compat53.path("c-api"), .files = &.{
        "compat-5.3.c",
    } });

    return lib;
}
