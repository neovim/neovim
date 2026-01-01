const std = @import("std");
const LazyPath = std.Build.LazyPath;
const Compile = std.Build.Step.Compile;
const build_lua = @import("src/build_lua.zig");
const gen = @import("src/gen/gen_steps.zig");
const runtime = @import("runtime/gen_runtime.zig");
const tests = @import("test/run_tests.zig");

const version = struct {
    const major = 0;
    const minor = 12;
    const patch = 0;
    const prerelease = "-dev";

    const api_level = 14;
    const api_level_compat = 0;
    const api_prerelease = true;
};

pub const SystemIntegrationOptions = packed struct {
    lpeg: bool,
    lua: bool,
    tree_sitter: bool,
    unibilium: bool,
    utf8proc: bool,
    uv: bool,
};

// TODO(bfredl): this is for an upstream issue
pub fn lazyArtifact(d: *std.Build.Dependency, name: []const u8) ?*std.Build.Step.Compile {
    var found: ?*std.Build.Step.Compile = null;
    for (d.builder.install_tls.step.dependencies.items) |dep_step| {
        const inst = dep_step.cast(std.Build.Step.InstallArtifact) orelse continue;
        if (std.mem.eql(u8, inst.artifact.name, name)) {
            if (found != null) std.debug.panic("artifact name '{s}' is ambiguous", .{name});
            found = inst.artifact;
        }
    }
    return found;
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const t = target.result;
    const os_tag = t.os.tag;
    const is_windows = (os_tag == .windows);
    const is_linux = (os_tag == .linux);
    const is_darwin = os_tag.isDarwin();
    const modern_unix = is_darwin or os_tag.isBSD() or is_linux;

    const cross_compiling = b.option(bool, "cross", "cross compile") orelse false;
    // TODO(bfredl): option to set nlua0 target explicitly when cross compiling?
    const target_host = if (cross_compiling) b.graph.host else target;
    // without cross_compiling we like to reuse libluv etc at the same optimize level
    const optimize_host = if (cross_compiling) .ReleaseSafe else optimize;

    const use_unibilium = b.option(bool, "unibilium", "use unibilium") orelse true;

    // puc lua 5.1 is not ReleaseSafe "safe"
    const optimize_lua = if (optimize == .Debug or optimize == .ReleaseSafe) .ReleaseSmall else optimize;

    const arch = t.cpu.arch;
    const default_luajit = (is_linux and arch == .x86_64) or (is_darwin and arch == .aarch64);
    const use_luajit = b.option(bool, "luajit", "use luajit") orelse default_luajit;
    const lualib_name = if (use_luajit) "luajit" else "lua5.1";
    const host_use_luajit = if (cross_compiling) false else use_luajit;
    const E = enum { luajit, lua51 };

    const system_integration_options = SystemIntegrationOptions{
        .lpeg = b.systemIntegrationOption("lpeg", .{}),
        .lua = b.systemIntegrationOption("lua", .{}),
        .tree_sitter = b.systemIntegrationOption("tree-sitter", .{}),
        .unibilium = b.systemIntegrationOption("unibilium", .{}),
        .utf8proc = b.systemIntegrationOption("utf8proc", .{}),
        .uv = b.systemIntegrationOption("uv", .{}),
    };

    const ziglua = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize_lua,
        .lang = if (use_luajit) E.luajit else E.lua51,
        .shared = false,
        .system_lua = system_integration_options.lua,
    });
    const ziglua_host = if (cross_compiling) b.dependency("zlua", .{
        .target = target_host,
        .optimize = .ReleaseSmall,
        .lang = if (host_use_luajit) E.luajit else E.lua51,
        .system_lua = system_integration_options.lua,
        .shared = false,
    }) else ziglua;
    var lua: ?*Compile = null;
    var libuv: ?*Compile = null;
    var libluv: ?*Compile = null;
    var libluv_host: ?*Compile = null;
    if (!system_integration_options.lua) {
        // this is currently not necessary, as ziglua currently doesn't use lazy dependencies
        // to circumvent ziglua.artifact() failing in a bad way.
        lua = lazyArtifact(ziglua, "lua") orelse return;
        if (cross_compiling) {
            _ = lazyArtifact(ziglua_host, "lua") orelse return;
        }
    }
    if (!system_integration_options.uv) {
        if (b.lazyDependency("libuv", .{ .target = target, .optimize = optimize })) |dep| {
            libuv = dep.artifact("uv");
            libluv = try build_lua.build_libluv(b, target, optimize, lua, libuv.?, use_luajit);

            libluv_host = if (cross_compiling) libluv_host: {
                const libuv_dep_host = b.lazyDependency("libuv", .{
                    .target = target_host,
                    .optimize = optimize_host,
                });
                const libuv_host = libuv_dep_host.?.artifact("uv");
                break :libluv_host try build_lua.build_libluv(
                    b,
                    target_host,
                    optimize_host,
                    ziglua_host.artifact("lua"),
                    libuv_host,
                    host_use_luajit,
                );
            } else libluv;
        }
    }

    const lpeg = if (system_integration_options.lpeg) null else b.lazyDependency("lpeg", .{});

    const iconv = if (is_windows or is_darwin) b.lazyDependency("libiconv", .{
        .target = target,
        .optimize = optimize,
    }) else null;

    const utf8proc = if (system_integration_options.utf8proc) null else b.lazyDependency("utf8proc", .{
        .target = target,
        .optimize = optimize,
    });
    const unibilium = if (use_unibilium and !system_integration_options.unibilium) b.lazyDependency("unibilium", .{
        .target = target,
        .optimize = optimize,
    }) else null;

    // TODO(bfredl): fix upstream bugs with UBSAN
    const optimize_ts = .ReleaseFast;
    const treesitter = if (system_integration_options.tree_sitter) null else b.lazyDependency("treesitter", .{
        .target = target,
        .optimize = optimize_ts,
    });

    const nlua0 = try build_lua.build_nlua0(
        b,
        target_host,
        optimize_host,
        host_use_luajit,
        ziglua_host,
        lpeg,
        libluv_host,
        system_integration_options,
    );

    // usual caveat emptor: might need to force a rebuild if the only change is
    // addition of new .c files, as those are not seen by any hash
    const subdirs = [_][]const u8{
        "", // src/nvim itself
        "os/",
        "api/",
        "api/private/",
        "msgpack_rpc/",
        "tui/",
        "tui/termkey/",
        "event/",
        "eval/",
        "lib/",
        "lua/",
        "viml/",
        "viml/parser/",
        "vterm/",
    };

    // source names _relative_ src/nvim/, not including other src/ subdircs
    var nvim_sources = try std.ArrayList(gen.SourceItem).initCapacity(b.allocator, 100);
    var nvim_headers = try std.ArrayList([]u8).initCapacity(b.allocator, 100);

    // both source headers and the {module}.h.generated.h files
    var api_headers = try std.ArrayList(std.Build.LazyPath).initCapacity(b.allocator, 10);

    // TODO(bfredl): these should just become subdirs..
    const windows_only = [_][]const u8{
        "pty_proc_win.c",
        "pty_proc_win.h",
        "pty_conpty_win.c",
        "pty_conpty_win.h",
        "os_win_console.c",
        "win_defs.h",
    };
    const unix_only = [_][]const u8{ "unix_defs.h", "pty_proc_unix.c", "pty_proc_unix.h" };
    const exclude_list = if (is_windows) &unix_only else &windows_only;

    const src_dir = b.build_root.handle;
    for (subdirs) |s| {
        var dir = try src_dir.openDir(b.fmt("src/nvim/{s}", .{s}), .{ .iterate = true });
        defer dir.close();
        var it = dir.iterateAssumeFirstIteration();
        const api_export = std.mem.eql(u8, s, "api/");
        const os_check = std.mem.eql(u8, s, "os/");
        entries: while (try it.next()) |entry| {
            if (entry.name.len < 3) continue;
            if (entry.name[0] < 'a' or entry.name[0] > 'z') continue;
            if (os_check) {
                for (exclude_list) |name| {
                    if (std.mem.eql(u8, name, entry.name)) {
                        continue :entries;
                    }
                }
            }
            if (std.mem.eql(u8, ".c", entry.name[entry.name.len - 2 ..])) {
                try nvim_sources.append(b.allocator, .{
                    .name = b.fmt("{s}{s}", .{ s, entry.name }),
                    .api_export = api_export,
                });
            }
            if (std.mem.eql(u8, ".h", entry.name[entry.name.len - 2 ..])) {
                try nvim_headers.append(b.allocator, b.fmt("{s}{s}", .{ s, entry.name }));
                if (api_export and !std.mem.eql(u8, "ui_events.in.h", entry.name)) {
                    try api_headers.append(b.allocator, b.path(b.fmt("src/nvim/{s}{s}", .{ s, entry.name })));
                }
            }
        }
    }

    const support_unittests = use_luajit;

    const gen_config = b.addWriteFiles();

    const version_lua = gen_config.add("nvim_version.lua", lua_version_info(b));

    var config_str = b.fmt("zig build -Doptimize={s}", .{@tagName(optimize)});
    if (cross_compiling) {
        config_str = b.fmt("{s} -Dcross -Dtarget={s} (host: {s})", .{
            config_str,
            try t.linuxTriple(b.allocator),
            try b.graph.host.result.linuxTriple(b.allocator),
        });
    }

    const versiondef_step = b.addConfigHeader(.{
        .style = .{ .cmake = b.path("cmake.config/versiondef.h.in") },
    }, .{
        .NVIM_VERSION_MAJOR = version.major,
        .NVIM_VERSION_MINOR = version.minor,
        .NVIM_VERSION_PATCH = version.patch,
        .NVIM_VERSION_PRERELEASE = version.prerelease,
        .NVIM_VERSION_MEDIUM = "",
        .VERSION_STRING = "TODO", // TODO(bfredl): not sure what to put here. summary already in "config_str"
        .CONFIG = config_str,
    });
    _ = gen_config.addCopyFile(versiondef_step.getOutput(), "auto/versiondef.h"); // run_preprocessor() workaronnd

    const ptrwidth = t.ptrBitWidth() / 8;
    const sysconfig_step = b.addConfigHeader(.{
        .style = .{ .cmake = b.path("cmake.config/config.h.in") },
    }, .{
        .SIZEOF_INT = t.cTypeByteSize(.int),
        .SIZEOF_INTMAX_T = t.cTypeByteSize(.longlong), // TODO
        .SIZEOF_LONG = t.cTypeByteSize(.long),
        .SIZEOF_SIZE_T = ptrwidth,
        .SIZEOF_VOID_PTR = ptrwidth,

        .PROJECT_NAME = "nvim",

        .HAVE__NSGETENVIRON = is_darwin,
        .HAVE_FD_CLOEXEC = modern_unix,
        .HAVE_FSEEKO = modern_unix,
        .HAVE_LANGINFO_H = modern_unix,
        .HAVE_NL_LANGINFO_CODESET = modern_unix,
        .HAVE_NL_MSG_CAT_CNTR = t.isGnuLibC(),
        .HAVE_PWD_FUNCS = modern_unix,
        .HAVE_READLINK = modern_unix,
        .HAVE_STRNLEN = modern_unix,
        .HAVE_STRCASECMP = modern_unix,
        .HAVE_STRINGS_H = modern_unix,
        .HAVE_STRNCASECMP = modern_unix,
        .HAVE_STRPTIME = modern_unix,
        .HAVE_XATTR = is_linux,
        .HAVE_SYS_SDT_H = false,
        .HAVE_SYS_UTSNAME_H = modern_unix,
        .HAVE_SYS_WAIT_H = false, // unused
        .HAVE_TERMIOS_H = modern_unix,
        .HAVE_WORKING_LIBINTL = t.isGnuLibC(),
        .UNIX = modern_unix,
        .CASE_INSENSITIVE_FILENAME = is_darwin or is_windows,
        .HAVE_SYS_UIO_H = modern_unix,
        .HAVE_READV = modern_unix,
        .HAVE_DIRFD_AND_FLOCK = modern_unix,
        .HAVE_FORKPTY = modern_unix and !is_darwin, // also on Darwin but we lack the headers :(
        .HAVE_BE64TOH = modern_unix and !is_darwin,
        .ORDER_BIG_ENDIAN = t.cpu.arch.endian() == .big,
        .ENDIAN_INCLUDE_FILE = "endian.h",
        .HAVE_EXECINFO_BACKTRACE = modern_unix and !t.isMuslLibC(),
        .HAVE_BUILTIN_ADD_OVERFLOW = true,
        .HAVE_WIMPLICIT_FALLTHROUGH_FLAG = true,
        .HAVE_BITSCANFORWARD64 = null,

        .VTERM_TEST_FILE = "test/vterm_test_output", // TODO(bfredl): revisit when porting libvterm tests
    });

    const system_install_path = b.option([]const u8, "install-path", "Install path (for packagers)");
    const install_path = system_install_path orelse b.install_path;
    const lib_dir = if (system_install_path) |path| b.fmt("{s}/lib", .{path}) else b.lib_dir;
    _ = gen_config.addCopyFile(sysconfig_step.getOutput(), "auto/config.h"); // run_preprocessor() workaronnd

    _ = gen_config.add("auto/pathdef.h", b.fmt(
        \\char *default_vim_dir = "{s}/share/nvim";
        \\char *default_vimruntime_dir = "";
        \\char *default_lib_dir = "{s}/nvim";
        // b.lib_dir is typically b.install_path + "/lib" but may be overridden
    , .{ try replace_backslashes(b, install_path), try replace_backslashes(b, lib_dir) }));

    const opt_version_string = b.option(
        []const u8,
        "version-string",
        "Override Neovim version string. Default is to find out with git.",
    );
    const version_medium = if (opt_version_string) |version_string| version_string else v: {
        var code: u8 = undefined;
        const version_string = b.fmt("v{d}.{d}.{d}", .{
            version.major,
            version.minor,
            version.patch,
        });
        const git_describe_untrimmed = b.runAllowFail(&[_][]const u8{
            "git",
            "-C", b.build_root.path orelse ".", // affects the --git-dir argument
            "--git-dir", ".git", // affected by the -C argument
            "describe", "--dirty", "--match", "v*.*.*", //
        }, &code, .Ignore) catch {
            break :v version_string;
        };
        const git_describe = std.mem.trim(u8, git_describe_untrimmed, " \n\r");

        const num_parts = std.mem.count(u8, git_describe, "-") + 1;
        if (num_parts < 3) {
            break :v version_string; // achtung: unrecognized format
        }

        var it = std.mem.splitScalar(u8, git_describe, '-');
        const tagged_ancestor = it.first();
        _ = tagged_ancestor;
        const commit_height = it.next().?;
        const commit_id = it.next().?;
        const maybe_dirty = it.next();

        // Check that the commit hash is prefixed with a 'g' (a Git convention).
        if (commit_id.len < 1 or commit_id[0] != 'g') {
            std.debug.print("Unexpected `git describe` output: {s}\n", .{git_describe});
            break :v version_string;
        }

        const dirty_tag = if (maybe_dirty) |dirty| b.fmt("-{s}", .{dirty}) else "";

        break :v b.fmt("{s}-dev-{s}+{s}{s}", .{ version_string, commit_height, commit_id, dirty_tag });
    };

    const versiondef_git = gen_config.add("auto/versiondef_git.h", b.fmt(
        \\#define NVIM_VERSION_MEDIUM "{s}"
        \\#define NVIM_VERSION_BUILD "zig"
        \\
    , .{version_medium}));

    // TODO(zig): using getEmittedIncludeTree() is ugly af. we want unittests
    // to reuse the std.build.Module include_path thing
    var unittest_include_path: std.ArrayList(LazyPath) = try .initCapacity(b.allocator, 2);
    try unittest_include_path.append(b.allocator, b.path("src/"));
    try unittest_include_path.append(b.allocator, gen_config.getDirectory());
    if (system_integration_options.lua) {
        try appendSystemIncludePath(b, &unittest_include_path, lualib_name);
    } else if (lua) |compile| {
        try unittest_include_path.append(b.allocator, compile.getEmittedIncludeTree());
    }
    if (system_integration_options.uv) {
        try appendSystemIncludePath(b, &unittest_include_path, "libuv");
        try appendSystemIncludePath(b, &unittest_include_path, "libluv");
    } else {
        if (libuv) |compile| try unittest_include_path.append(b.allocator, compile.getEmittedIncludeTree());
        if (libluv) |compile| try unittest_include_path.append(b.allocator, compile.getEmittedIncludeTree());
    }
    if (system_integration_options.utf8proc) {
        try appendSystemIncludePath(b, &unittest_include_path, "libutf8proc");
    } else if (utf8proc) |dep| {
        try unittest_include_path.append(b.allocator, dep.artifact("utf8proc").getEmittedIncludeTree());
    }
    if (use_unibilium) {
        if (system_integration_options.unibilium) {
            try appendSystemIncludePath(b, &unittest_include_path, "unibilium");
        } else if (unibilium) |dep| {
            try unittest_include_path.append(b.allocator, dep.artifact("unibilium").getEmittedIncludeTree());
        }
    }
    if (system_integration_options.tree_sitter) {
        try appendSystemIncludePath(b, &unittest_include_path, "tree-sitter");
    } else if (treesitter) |dep| {
        try unittest_include_path.append(b.allocator, dep.artifact("tree-sitter").getEmittedIncludeTree());
    }
    if (iconv) |dep| {
        try unittest_include_path.append(b.allocator, dep.artifact("iconv").getEmittedIncludeTree());
    }

    const gen_headers, const funcs_data = try gen.nvim_gen_sources(
        b,
        nlua0,
        &nvim_sources,
        &nvim_headers,
        &api_headers,
        versiondef_git,
        version_lua,
    );

    const test_config_step = b.addWriteFiles();
    _ = test_config_step.add("test/cmakeconfig/paths.lua", try test_config(b));

    const test_gen_step = b.step("gen_headers", "debug: output generated headers");
    const config_install = b.addInstallDirectory(.{
        .source_dir = gen_config.getDirectory(),
        .install_dir = .prefix,
        .install_subdir = "config/",
    });
    test_gen_step.dependOn(&config_install.step);
    test_gen_step.dependOn(&b.addInstallDirectory(.{
        .source_dir = gen_headers.getDirectory(),
        .install_dir = .prefix,
        .install_subdir = "headers/",
    }).step);

    const nvim_exe = b.addExecutable(.{
        .name = "nvim",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    nvim_exe.rdynamic = true; // -E

    if (system_integration_options.lua) {
        nvim_exe.root_module.linkSystemLibrary(lualib_name, .{});
    } else if (lua) |compile| {
        nvim_exe.root_module.linkLibrary(compile);
    }
    if (system_integration_options.uv) {
        nvim_exe.root_module.linkSystemLibrary("libuv", .{});
        nvim_exe.root_module.linkSystemLibrary("libluv", .{});
    } else {
        if (libuv) |compile| nvim_exe.root_module.linkLibrary(compile);
        if (libluv) |compile| nvim_exe.root_module.linkLibrary(compile);
    }
    if (iconv) |dep| nvim_exe.linkLibrary(dep.artifact("iconv"));
    if (system_integration_options.utf8proc) {
        nvim_exe.root_module.linkSystemLibrary("utf8proc", .{});
    } else if (utf8proc) |dep| {
        nvim_exe.root_module.linkLibrary(dep.artifact("utf8proc"));
    }
    if (use_unibilium) {
        if (system_integration_options.unibilium) {
            nvim_exe.root_module.linkSystemLibrary("unibilium", .{});
        } else if (unibilium) |dep| {
            nvim_exe.root_module.linkLibrary(dep.artifact("unibilium"));
        }
    }
    if (system_integration_options.tree_sitter) {
        nvim_exe.root_module.linkSystemLibrary("tree-sitter", .{});
    } else if (treesitter) |dep| {
        nvim_exe.root_module.linkLibrary(dep.artifact("tree-sitter"));
    }
    if (is_windows) {
        nvim_exe.linkSystemLibrary("netapi32");
    }
    nvim_exe.addIncludePath(b.path("src"));
    nvim_exe.addIncludePath(gen_config.getDirectory());
    nvim_exe.addIncludePath(gen_headers.getDirectory());
    try build_lua.add_lua_modules(
        b,
        t,
        nvim_exe.root_module,
        lpeg,
        use_luajit,
        false,
        system_integration_options,
    );

    var unit_test_sources = try std.ArrayList([]u8).initCapacity(b.allocator, 10);
    if (support_unittests) {
        var unit_test_fixtures = try src_dir.openDir("test/unit/fixtures/", .{ .iterate = true });
        defer unit_test_fixtures.close();
        var it = unit_test_fixtures.iterateAssumeFirstIteration();
        while (try it.next()) |entry| {
            if (entry.name.len < 3) continue;
            if (std.mem.eql(u8, ".c", entry.name[entry.name.len - 2 ..])) {
                try unit_test_sources.append(b.allocator, b.fmt("test/unit/fixtures/{s}", .{entry.name}));
            }
        }
    }

    const src_paths = try b.allocator.alloc([]u8, nvim_sources.items.len + unit_test_sources.items.len);
    for (nvim_sources.items, 0..) |s, i| {
        src_paths[i] = b.fmt("src/nvim/{s}", .{s.name});
    }
    @memcpy(src_paths[nvim_sources.items.len..], unit_test_sources.items);

    const flags = [_][]const u8{
        "-std=gnu99",
        "-DZIG_BUILD",
        "-D_GNU_SOURCE",
        if (support_unittests) "-DUNIT_TESTING" else "",
        if (use_luajit) "" else "-DNVIM_VENDOR_BIT",
        if (is_windows) "-DMSWIN" else "",
        if (is_windows) "-DWIN32_LEAN_AND_MEAN" else "",
        if (is_windows) "-DUTF8PROC_STATIC" else "",
        if (use_unibilium) "-DHAVE_UNIBILIUM" else "",
    };
    nvim_exe.addCSourceFiles(.{ .files = src_paths, .flags = &flags });

    nvim_exe.addCSourceFiles(.{ .files = &.{
        "src/xdiff/xdiffi.c",
        "src/xdiff/xemit.c",
        "src/xdiff/xhistogram.c",
        "src/xdiff/xpatience.c",
        "src/xdiff/xprepare.c",
        "src/xdiff/xutils.c",
        "src/cjson/lua_cjson.c",
        "src/cjson/fpconv.c",
        "src/cjson/strbuf.c",
    }, .flags = &flags });

    if (is_windows) {
        nvim_exe.addWin32ResourceFile(.{ .file = b.path("src/nvim/os/nvim.rc") });
    }

    const nvim_exe_step = b.step("nvim_bin", "only the binary (not a fully working install!)");
    const nvim_exe_install = b.addInstallArtifact(nvim_exe, .{});

    nvim_exe_step.dependOn(&nvim_exe_install.step);

    const gen_runtime = try runtime.nvim_gen_runtime(b, nlua0, funcs_data);

    const lua_dev_deps = b.dependency("lua_dev_deps", .{});

    const test_deps = b.step("test_deps", "test prerequisites");
    test_deps.dependOn(&nvim_exe_install.step);
    // running tests doesn't require copying the static runtime, only the generated stuff
    const test_runtime_install = b.addInstallDirectory(.{
        .source_dir = gen_runtime.getDirectory(),
        .install_dir = .prefix,
        .install_subdir = "runtime/",
    });
    test_deps.dependOn(&test_runtime_install.step);

    const nvim_dev = b.step("nvim_dev", "build the editor for development");
    b.default_step = nvim_dev;

    nvim_dev.dependOn(&nvim_exe_install.step);
    nvim_dev.dependOn(&test_runtime_install.step);

    // run from dev environment
    const run_cmd = b.addRunArtifact(nvim_exe);
    run_cmd.setEnvironmentVariable("VIMRUNTIME", try b.build_root.join(b.graph.arena, &.{"runtime"}));
    run_cmd.setEnvironmentVariable("NVIM_ZIG_INSTALL_DIR", b.getInstallPath(.prefix, "runtime"));
    run_cmd.step.dependOn(nvim_dev);
    run_cmd.addArgs(&.{ "--cmd", "let &rtp = &rtp.','.$NVIM_ZIG_INSTALL_DIR" });
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run_dev", "run the editor (for development)");
    run_step.dependOn(&run_cmd.step);

    // installation
    const install = b.getInstallStep();
    install.dependOn(&nvim_exe_install.step);
    b.installDirectory(.{
        .source_dir = b.path("runtime/"),
        .install_dir = .prefix,
        .install_subdir = "share/nvim/runtime/",
    });
    b.installDirectory(.{
        .source_dir = gen_runtime.getDirectory(),
        .install_dir = .prefix,
        .install_subdir = "share/nvim/runtime/",
    });

    test_deps.dependOn(test_fixture(b, "shell-test", false, false, null, target, optimize, &flags));
    test_deps.dependOn(test_fixture(
        b,
        "tty-test",
        true,
        system_integration_options.uv,
        libuv,
        target,
        optimize,
        &flags,
    ));
    test_deps.dependOn(test_fixture(b, "pwsh-test", false, false, null, target, optimize, &flags));
    test_deps.dependOn(test_fixture(b, "printargs-test", false, false, null, target, optimize, &flags));
    test_deps.dependOn(test_fixture(b, "printenv-test", false, false, null, target, optimize, &flags));
    test_deps.dependOn(test_fixture(
        b,
        "streams-test",
        true,
        system_integration_options.uv,
        libuv,
        target,
        optimize,
        &flags,
    ));

    // xxd - hex dump utility (vendored from Vim)
    const xxd_exe = b.addExecutable(.{
        .name = "xxd",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });
    xxd_exe.addCSourceFile(.{ .file = b.path("src/xxd/xxd.c") });
    xxd_exe.linkLibC();
    test_deps.dependOn(&b.addInstallArtifact(xxd_exe, .{}).step);

    const parser_c = b.dependency("treesitter_c", .{ .target = target, .optimize = optimize_ts });
    test_deps.dependOn(add_ts_parser(b, "c", parser_c.path("."), false, target, optimize_ts, .test_));
    install.dependOn(add_ts_parser(b, "c", parser_c.path("."), false, target, optimize_ts, .install));

    const parser_markdown = b.dependency("treesitter_markdown", .{ .target = target, .optimize = optimize_ts });
    test_deps.dependOn(add_ts_parser(b, "markdown", parser_markdown.path("tree-sitter-markdown/"), true, target, optimize_ts, .test_));
    install.dependOn(add_ts_parser(b, "markdown", parser_markdown.path("tree-sitter-markdown/"), true, target, optimize_ts, .install));
    test_deps.dependOn(add_ts_parser(b, "markdown_inline", parser_markdown.path("tree-sitter-markdown-inline/"), true, target, optimize_ts, .test_));
    install.dependOn(add_ts_parser(b, "markdown_inline", parser_markdown.path("tree-sitter-markdown-inline/"), true, target, optimize_ts, .install));

    const parser_vim = b.dependency("treesitter_vim", .{ .target = target, .optimize = optimize_ts });
    test_deps.dependOn(add_ts_parser(b, "vim", parser_vim.path("."), true, target, optimize_ts, .test_));
    install.dependOn(add_ts_parser(b, "vim", parser_vim.path("."), true, target, optimize_ts, .install));

    const parser_vimdoc = b.dependency("treesitter_vimdoc", .{ .target = target, .optimize = optimize_ts });
    test_deps.dependOn(add_ts_parser(b, "vimdoc", parser_vimdoc.path("."), false, target, optimize_ts, .test_));
    install.dependOn(add_ts_parser(b, "vimdoc", parser_vimdoc.path("."), false, target, optimize_ts, .install));

    const parser_lua = b.dependency("treesitter_lua", .{ .target = target, .optimize = optimize_ts });
    test_deps.dependOn(add_ts_parser(b, "lua", parser_lua.path("."), true, target, optimize_ts, .test_));
    install.dependOn(add_ts_parser(b, "lua", parser_lua.path("."), true, target, optimize_ts, .install));

    const parser_query = b.dependency("treesitter_query", .{ .target = target, .optimize = optimize_ts });
    test_deps.dependOn(add_ts_parser(b, "query", parser_query.path("."), false, target, optimize_ts, .test_));
    install.dependOn(add_ts_parser(b, "query", parser_query.path("."), false, target, optimize_ts, .install));

    var unit_headers: ?[]const LazyPath = null;
    if (support_unittests) {
        try unittest_include_path.append(b.allocator, gen_headers.getDirectory());
        unit_headers = unittest_include_path.items;
    }
    try tests.test_steps(
        b,
        nvim_exe,
        test_deps,
        lua_dev_deps.path("."),
        test_config_step.getDirectory(),
        unit_headers,
    );
}

pub fn test_fixture(
    b: *std.Build,
    name: []const u8,
    use_libuv: bool,
    use_system_libuv: bool,
    libuv: ?*std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    flags: []const []const u8,
) *std.Build.Step {
    const fixture = b.addExecutable(.{
        .name = name,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });
    const source = if (std.mem.eql(u8, name, "pwsh-test")) "shell-test" else name;
    if (std.mem.eql(u8, name, "printenv-test")) {
        fixture.mingw_unicode_entry_point = true; // uses UNICODE on WINDOWS :scream:
    }

    fixture.addCSourceFile(.{
        .file = b.path(b.fmt("./test/functional/fixtures/{s}.c", .{source})),
        .flags = flags,
    });
    fixture.linkLibC();
    if (use_libuv) {
        if (use_system_libuv) {
            fixture.root_module.linkSystemLibrary("libuv", .{});
        } else if (libuv) |uv| {
            fixture.linkLibrary(uv);
        }
    }
    return &b.addInstallArtifact(fixture, .{}).step;
}

pub fn add_ts_parser(
    b: *std.Build,
    name: []const u8,
    parser_dir: LazyPath,
    scanner: bool,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    path: enum { test_, install },
) *std.Build.Step {
    const parser = b.addLibrary(.{
        .name = name,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
    });
    parser.addCSourceFile(.{ .file = parser_dir.path(b, "src/parser.c") });
    if (scanner) parser.addCSourceFile(.{ .file = parser_dir.path(b, "src/scanner.c") });
    parser.addIncludePath(parser_dir.path(b, "src"));
    parser.linkLibC();

    switch (path) {
        .install => {
            const parser_install = b.addInstallArtifact(parser, .{
                .dest_dir = .{ .override = .{ .custom = "share/nvim/runtime/parser" } },
                .dest_sub_path = b.fmt("{s}.so", .{name}),
            });
            return &parser_install.step;
        },
        .test_ => {
            const parser_install = b.addInstallArtifact(parser, .{
                .dest_sub_path = b.fmt("parser/{s}.so", .{name}),
            });
            return &parser_install.step;
        },
    }
}

pub fn lua_version_info(b: *std.Build) []u8 {
    const v = version;
    return b.fmt(
        \\return {{
        \\  {{"major", {}}},
        \\  {{"minor", {}}},
        \\  {{"patch", {}}},
        \\  {{"prerelease", {}}},
        \\  {{"api_level", {}}},
        \\  {{"api_compatible", {}}},
        \\  {{"api_prerelease", {}}},
        \\}}
    , .{
        v.major,
        v.minor,
        v.patch,
        v.prerelease.len > 0,
        v.api_level,
        v.api_level_compat,
        v.api_prerelease,
    });
}

/// Replace all backslashes in `input` with with forward slashes when the target is Windows.
/// Returned memory is stored in `b.graph.arena`.
fn replace_backslashes(b: *std.Build, input: []const u8) ![]const u8 {
    return if (b.graph.host.result.os.tag == .windows)
        std.mem.replaceOwned(u8, b.graph.arena, input, "\\", "/")
    else
        input;
}

pub fn test_config(b: *std.Build) ![]u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const src_path = try b.build_root.handle.realpath(".", &buf);

    // we don't use test/cmakeconfig/paths.lua.in because it contains cmake specific logic
    return b.fmt(
        \\local M = {{}}
        \\
        \\M.apple_sysroot = ""
        \\M.translations_enabled = "$ENABLE_TRANSLATIONS" == "ON"
        \\M.is_asan = "$ENABLE_ASAN_UBSAN" == "ON"
        \\M.is_zig_build = true
        \\M.vterm_test_file = "test/vterm_test_output"
        \\M.test_build_dir = "{[bin_dir]s}" -- bull
        \\M.test_source_path = "{[src_path]s}"
        \\M.test_lua_prg = ""
        \\M.test_luajit_prg = ""
        \\ -- include path passed on the cmdline, see test/lua_runner.lua
        \\M.include_paths = _G.c_include_path or {{}}
        \\
        \\return M
    , .{ .bin_dir = try replace_backslashes(b, b.install_path), .src_path = try replace_backslashes(b, src_path) });
}

fn appendSystemIncludePath(
    b: *std.Build,
    path: *std.ArrayList(LazyPath),
    system_name: []const u8,
) !void {
    var code: u8 = 0;
    const stdout = try b.runAllowFail(
        &[_][]const u8{ "pkg-config", system_name, "--cflags-only-I", "--keep-system-cflags" },
        &code,
        .Ignore,
    );
    if (code != 0) return std.Build.PkgConfigError.PkgConfigFailed;
    var arg_it = std.mem.tokenizeAny(u8, stdout, " \r\n\t");
    while (arg_it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-I")) {
            // -I /foo/bar
            const dir = arg_it.next() orelse return std.Build.PkgConfigError.PkgConfigInvalidOutput;
            try path.append(b.allocator, .{ .cwd_relative = dir });
        } else if (std.mem.startsWith(u8, arg, "-I")) {
            // -I/foo/bar
            const dir = arg[("-I".len)..];
            try path.append(b.allocator, .{ .cwd_relative = dir });
        }
    }
}
