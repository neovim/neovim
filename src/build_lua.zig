const std = @import("std");
const build = @import("../build.zig");
const LazyPath = std.Build.LazyPath;

pub fn build_nlua0(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    use_luajit: bool,
    ziglua: *std.Build.Dependency,
    lpeg: ?*std.Build.Dependency,
    libluv: ?*std.Build.Step.Compile,
    system_integration_options: build.SystemIntegrationOptions,
) !*std.Build.Step.Compile {
    const options = b.addOptions();
    options.addOption(bool, "use_luajit", use_luajit);

    const nlua0_exe = b.addExecutable(.{
        .name = "nlua0",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/nlua0.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    const nlua0_mod = nlua0_exe.root_module;

    const exe_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/nlua0.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    const embedded_data = b.addModule("embedded_data", .{
        .root_source_file = b.path("runtime/embedded_data.zig"),
    });

    for ([2]*std.Build.Module{ nlua0_mod, exe_unit_tests.root_module }) |mod| {
        mod.addImport("ziglua", ziglua.module("zlua"));
        mod.addImport("embedded_data", embedded_data);
        // addImport already links by itself. but we need headers as well..
        if (system_integration_options.lua) {
            const system_lua_lib = if (use_luajit) "luajit" else "lua5.1";
            mod.linkSystemLibrary(system_lua_lib, .{});
        } else {
            mod.linkLibrary(ziglua.artifact("lua"));
        }
        if (libluv) |luv| {
            mod.linkLibrary(luv);
        } else {
            mod.linkSystemLibrary("luv", .{});
        }

        mod.addOptions("options", options);

        mod.addIncludePath(b.path("src"));
        mod.addIncludePath(b.path("src/includes_fixmelater"));
        try add_lua_modules(b, target.result, mod, lpeg, use_luajit, true, system_integration_options);
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

pub fn add_lua_modules(
    b: *std.Build,
    target: std.Target,
    mod: *std.Build.Module,
    lpeg_dep: ?*std.Build.Dependency,
    use_luajit: bool,
    is_nlua0: bool,
    system_integration_options: build.SystemIntegrationOptions,
) !void {
    const flags = [_][]const u8{
        // Standard version used in Lua Makefile
        "-std=gnu99",
        if (is_nlua0) "-DNVIM_NLUA0" else "",
    };

    if (lpeg_dep) |lpeg| {
        mod.addIncludePath(lpeg.path(""));
    }
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
    if (system_integration_options.lpeg) {
        if (try findLpeg(b, target)) |lpeg_lib| {
            mod.addLibraryPath(.{ .cwd_relative = std.fs.path.dirname(lpeg_lib).? });
            mod.addObjectFile(.{ .cwd_relative = lpeg_lib });
        }
    } else if (lpeg_dep) |lpeg| {
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
    }

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
    lua: ?*std.Build.Step.Compile,
    libuv: *std.Build.Step.Compile,
    use_luajit: bool,
) !*std.Build.Step.Compile {
    const upstream = b.lazyDependency("luv", .{});
    const compat53 = b.lazyDependency("lua_compat53", .{});
    const lib = b.addLibrary(.{
        .name = "luv",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });

    if (lua) |lua_lib| {
        lib.root_module.linkLibrary(lua_lib);
    } else {
        const system_lua_lib = if (use_luajit) "luajit" else "lua5.1";
        lib.root_module.linkSystemLibrary(system_lua_lib, .{});
    }
    lib.linkLibrary(libuv);

    if (upstream) |dep| {
        lib.addIncludePath(dep.path("src"));
        lib.installHeader(dep.path("src/luv.h"), "luv/luv.h");
        lib.addCSourceFiles(.{ .root = dep.path("src/"), .files = &.{
            "luv.c",
        } });
    }
    if (compat53) |dep| {
        lib.addIncludePath(dep.path("c-api"));
        lib.addCSourceFiles(.{ .root = dep.path("c-api"), .files = &.{
            "compat-5.3.c",
        } });
    }

    return lib;
}

fn findLpeg(b: *std.Build, target: std.Target) !?[]const u8 {
    const filenames = [_][]const u8{
        "lpeg_a",
        "lpeg",
        "liblpeg_a",
        "lpeg.so",
        b.fmt("lpeg{s}", .{target.dynamicLibSuffix()}),
    };
    var code: u8 = 0;
    const dirs_stdout = std.mem.trimEnd(u8, try b.runAllowFail(&[_][]const u8{
        "pkg-config",
        "--variable=pc_system_libdirs",
        "--keep-system-cflags",
        "pkg-config",
    }, &code, .Ignore), "\r\n");
    var paths: std.ArrayList([]const u8) = try .initCapacity(b.allocator, 0);
    var path_it = std.mem.tokenizeAny(u8, dirs_stdout, " ,");
    while (path_it.next()) |dir| {
        try paths.append(b.allocator, dir);
        try paths.append(b.allocator, b.fmt("{s}/lua/5.1", .{dir}));
    }
    for (paths.items) |path| {
        var dir = std.fs.openDirAbsolute(path, .{}) catch continue;
        defer dir.close();
        for (filenames) |filename| {
            dir.access(filename, .{}) catch continue;
            return b.fmt("{s}/{s}", .{ path, filename });
        }
    }
    return null;
}
