const std = @import("std");
const LazyPath = std.Build.LazyPath;
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

    const cross_compiling = b.option(bool, "cross", "cross compile") orelse false;
    // TODO(bfredl): option to set nlua0 target explicitly when cross compiling?
    const target_host = if (cross_compiling) b.graph.host else target;
    const optimize_host = .ReleaseSafe;

    const t = target.result;
    const tag = t.os.tag;

    // puc lua 5.1 is not ReleaseSafe "safe"
    const optimize_lua = if (optimize == .Debug or optimize == .ReleaseSafe) .ReleaseSmall else optimize;

    const use_luajit = b.option(bool, "luajit", "use luajit") orelse false;
    const host_use_luajit = if (cross_compiling) false else use_luajit;
    const E = enum { luajit, lua51 };

    const ziglua = b.dependency("lua_wrapper", .{
        .target = target,
        .optimize = optimize_lua,
        .lang = if (use_luajit) E.luajit else E.lua51,
        .shared = false,
    });

    const ziglua_host = if (cross_compiling) b.dependency("lua_wrapper", .{
        .target = target_host,
        .optimize = optimize_lua,
        .lang = if (host_use_luajit) E.luajit else E.lua51,
        .shared = false,
    }) else ziglua;

    const lpeg = b.dependency("lpeg", .{});

    const iconv_apple = if (cross_compiling and tag.isDarwin()) b.lazyDependency("iconv_apple", .{ .target = target, .optimize = optimize }) else null;

    // this is currently not necessary, as ziglua currently doesn't use lazy dependencies
    // to circumvent ziglua.artifact() failing in a bad way.
    // const lua = lazyArtifact(ziglua, "lua") orelse return;
    const lua = ziglua.artifact("lua");

    const libuv_dep = b.dependency("libuv", .{ .target = target, .optimize = optimize });
    const libuv = libuv_dep.artifact("uv");

    const libluv = try build_lua.build_libluv(b, target, optimize, lua, libuv);

    const utf8proc = b.dependency("utf8proc", .{ .target = target, .optimize = optimize });
    const unibilium = b.dependency("unibilium", .{ .target = target, .optimize = optimize });
    // TODO(bfredl): fix upstream bugs with UBSAN
    const treesitter = b.dependency("treesitter", .{ .target = target, .optimize = .ReleaseFast });

    const nlua0 = build_lua.build_nlua0(b, target_host, optimize_host, host_use_luajit, ziglua_host, lpeg);

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

    const is_windows = (target.result.os.tag == .windows);
    // TODO(bfredl): these should just become subdirs..
    const windows_only = [_][]const u8{ "pty_proc_win.c", "pty_proc_win.h", "pty_conpty_win.c", "pty_conpty_win.h", "os_win_console.c", "win_defs.h" };
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
                try nvim_sources.append(.{ .name = b.fmt("{s}{s}", .{ s, entry.name }), .api_export = api_export });
            }
            if (std.mem.eql(u8, ".h", entry.name[entry.name.len - 2 ..])) {
                try nvim_headers.append(b.fmt("{s}{s}", .{ s, entry.name }));
                if (api_export and !std.mem.eql(u8, "ui_events.in.h", entry.name)) {
                    try api_headers.append(b.path(b.fmt("src/nvim/{s}{s}", .{ s, entry.name })));
                }
            }
        }
    }

    const gen_config = b.addWriteFiles();

    const version_lua = gen_config.add("nvim_version.lua", lua_version_info(b));

    var config_str = b.fmt("zig build -Doptimize={s}", .{@tagName(optimize)});
    if (cross_compiling) {
        config_str = b.fmt("{s} -Dcross -Dtarget={s} (host: {s})", .{ config_str, try t.linuxTriple(b.allocator), try b.graph.host.result.linuxTriple(b.allocator) });
    }

    const versiondef_step = b.addConfigHeader(.{ .style = .{ .cmake = b.path("cmake.config/versiondef.h.in") } }, .{
        .NVIM_VERSION_MAJOR = version.major,
        .NVIM_VERSION_MINOR = version.minor,
        .NVIM_VERSION_PATCH = version.patch,
        .NVIM_VERSION_PRERELEASE = version.prerelease,
        .NVIM_VERSION_MEDIUM = "",
        .VERSION_STRING = "TODO", // TODO(bfredl): not sure what to put here. summary already in "config_str"
        .CONFIG = config_str,
    });
    _ = gen_config.addCopyFile(versiondef_step.getOutput(), "auto/versiondef.h"); // run_preprocessor() workaronnd

    const isLinux = tag == .linux;
    const modernUnix = tag.isDarwin() or tag.isBSD() or isLinux;

    const ptrwidth = t.ptrBitWidth() / 8;
    const sysconfig_step = b.addConfigHeader(.{ .style = .{ .cmake = b.path("cmake.config/config.h.in") } }, .{
        .SIZEOF_INT = t.cTypeByteSize(.int),
        .SIZEOF_INTMAX_T = t.cTypeByteSize(.longlong), // TODO
        .SIZEOF_LONG = t.cTypeByteSize(.long),
        .SIZEOF_SIZE_T = ptrwidth,
        .SIZEOF_VOID_PTR = ptrwidth,

        .PROJECT_NAME = "nvim",

        .HAVE__NSGETENVIRON = tag.isDarwin(),
        .HAVE_FD_CLOEXEC = modernUnix,
        .HAVE_FSEEKO = modernUnix,
        .HAVE_LANGINFO_H = modernUnix,
        .HAVE_NL_LANGINFO_CODESET = modernUnix,
        .HAVE_NL_MSG_CAT_CNTR = t.isGnuLibC(),
        .HAVE_PWD_FUNCS = modernUnix,
        .HAVE_READLINK = modernUnix,
        .HAVE_STRNLEN = modernUnix,
        .HAVE_STRCASECMP = modernUnix,
        .HAVE_STRINGS_H = modernUnix,
        .HAVE_STRNCASECMP = modernUnix,
        .HAVE_STRPTIME = modernUnix,
        .HAVE_XATTR = isLinux,
        .HAVE_SYS_SDT_H = false,
        .HAVE_SYS_UTSNAME_H = modernUnix,
        .HAVE_SYS_WAIT_H = false, // unused
        .HAVE_TERMIOS_H = modernUnix,
        .HAVE_WORKING_LIBINTL = t.isGnuLibC(),
        .UNIX = modernUnix,
        .CASE_INSENSITIVE_FILENAME = tag.isDarwin() or tag == .windows,
        .HAVE_SYS_UIO_H = modernUnix,
        .HAVE_READV = modernUnix,
        .HAVE_DIRFD_AND_FLOCK = modernUnix,
        .HAVE_FORKPTY = modernUnix and !tag.isDarwin(), // also on Darwin but we lack the headers :(
        .HAVE_BE64TOH = modernUnix and !tag.isDarwin(),
        .ORDER_BIG_ENDIAN = t.cpu.arch.endian() == .big,
        .ENDIAN_INCLUDE_FILE = "endian.h",
        .HAVE_EXECINFO_BACKTRACE = modernUnix and !t.isMuslLibC(),
        .HAVE_BUILTIN_ADD_OVERFLOW = true,
        .HAVE_WIMPLICIT_FALLTHROUGH_FLAG = true,
        .HAVE_BITSCANFORWARD64 = null,

        .VTERM_TEST_FILE = "test/vterm_test_output", // TODO(bfredl): revisit when porting libvterm tests
    });

    _ = gen_config.addCopyFile(sysconfig_step.getOutput(), "auto/config.h"); // run_preprocessor() workaronnd
    _ = gen_config.add("auto/pathdef.h", b.fmt(
        \\char *default_vim_dir = "/usr/local/share/nvim";
        \\char *default_vimruntime_dir = "";
        \\char *default_lib_dir = "/usr/local/lib/nvim";
    , .{}));

    // TODO(bfredl): include git version when available
    const medium = b.fmt("v{}.{}.{}{s}+zig", .{ version.major, version.minor, version.patch, version.prerelease });
    const versiondef_git = gen_config.add("auto/versiondef_git.h", b.fmt(
        \\#define NVIM_VERSION_MEDIUM "{s}"
        \\#define NVIM_VERSION_BUILD "???"
        \\
    , .{medium}));

    // TODO(zig): using getEmittedIncludeTree() is ugly af. we want run_preprocessor()
    // to use the std.build.Module include_path thing
    const include_path = &.{
        b.path("src/"),
        gen_config.getDirectory(),
        lua.getEmittedIncludeTree(),
        libuv.getEmittedIncludeTree(),
        libluv.getEmittedIncludeTree(),
        utf8proc.artifact("utf8proc").getEmittedIncludeTree(),
        unibilium.artifact("unibilium").getEmittedIncludeTree(),
        treesitter.artifact("tree-sitter").getEmittedIncludeTree(),
    };

    const gen_headers, const funcs_data = try gen.nvim_gen_sources(b, nlua0, &nvim_sources, &nvim_headers, &api_headers, include_path, target, versiondef_git, version_lua);

    const test_config_step = b.addWriteFiles();
    _ = test_config_step.add("test/cmakeconfig/paths.lua", try test_config(b, gen_headers.getDirectory()));

    const test_gen_step = b.step("gen_headers", "debug: output generated headers");
    const config_install = b.addInstallDirectory(.{ .source_dir = gen_config.getDirectory(), .install_dir = .prefix, .install_subdir = "config/" });
    test_gen_step.dependOn(&config_install.step);
    test_gen_step.dependOn(&b.addInstallDirectory(.{ .source_dir = gen_headers.getDirectory(), .install_dir = .prefix, .install_subdir = "headers/" }).step);

    const nvim_exe = b.addExecutable(.{
        .name = "nvim",
        .target = target,
        .optimize = optimize,
    });

    nvim_exe.linkLibrary(lua);
    nvim_exe.linkLibrary(libuv);
    nvim_exe.linkLibrary(libluv);
    if (iconv_apple) |iconv| {
        nvim_exe.linkLibrary(iconv.artifact("iconv"));
    }
    nvim_exe.linkLibrary(utf8proc.artifact("utf8proc"));
    nvim_exe.linkLibrary(unibilium.artifact("unibilium"));
    nvim_exe.linkLibrary(treesitter.artifact("tree-sitter"));
    nvim_exe.addIncludePath(b.path("src"));
    nvim_exe.addIncludePath(gen_config.getDirectory());
    nvim_exe.addIncludePath(gen_headers.getDirectory());
    build_lua.add_lua_modules(nvim_exe.root_module, lpeg, use_luajit, false);

    const src_paths = try b.allocator.alloc([]u8, nvim_sources.items.len);
    for (nvim_sources.items, 0..) |s, i| {
        src_paths[i] = b.fmt("src/nvim/{s}", .{s.name});
    }

    const flags = [_][]const u8{
        "-std=gnu99",
        "-DINCLUDE_GENERATED_DECLARATIONS",
        "-DZIG_BUILD",
        "-D_GNU_SOURCE",
        if (use_luajit) "" else "-DNVIM_VENDOR_BIT",
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

    const nvim_exe_step = b.step("nvim_bin", "only the binary (not a fully working install!)");
    const nvim_exe_install = b.addInstallArtifact(nvim_exe, .{});

    nvim_exe_step.dependOn(&nvim_exe_install.step);

    const gen_runtime = try runtime.nvim_gen_runtime(b, nlua0, nvim_exe, funcs_data);
    const runtime_install = b.addInstallDirectory(.{ .source_dir = gen_runtime.getDirectory(), .install_dir = .prefix, .install_subdir = "runtime/" });

    const nvim = b.step("nvim", "build the editor");

    nvim.dependOn(&nvim_exe_install.step);
    nvim.dependOn(&runtime_install.step);

    const lua_dev_deps = b.dependency("lua_dev_deps", .{});

    const test_deps = b.step("test_deps", "test prerequisites");
    test_deps.dependOn(&nvim_exe_install.step);
    test_deps.dependOn(&runtime_install.step);

    test_deps.dependOn(test_fixture(b, "shell-test", null, target, optimize));
    test_deps.dependOn(test_fixture(b, "tty-test", libuv, target, optimize));
    test_deps.dependOn(test_fixture(b, "pwsh-test", null, target, optimize));
    test_deps.dependOn(test_fixture(b, "printargs-test", null, target, optimize));
    test_deps.dependOn(test_fixture(b, "printenv-test", null, target, optimize));
    test_deps.dependOn(test_fixture(b, "streams-test", libuv, target, optimize));

    const parser_c = b.dependency("treesitter_c", .{ .target = target, .optimize = optimize });
    test_deps.dependOn(add_ts_parser(b, "c", parser_c.path("."), false, target, optimize));
    const parser_markdown = b.dependency("treesitter_markdown", .{ .target = target, .optimize = optimize });
    test_deps.dependOn(add_ts_parser(b, "markdown", parser_markdown.path("tree-sitter-markdown/"), true, target, optimize));
    test_deps.dependOn(add_ts_parser(b, "markdown_inline", parser_markdown.path("tree-sitter-markdown-inline/"), true, target, optimize));
    const parser_vim = b.dependency("treesitter_vim", .{ .target = target, .optimize = optimize });
    test_deps.dependOn(add_ts_parser(b, "vim", parser_vim.path("."), true, target, optimize));
    const parser_vimdoc = b.dependency("treesitter_vimdoc", .{ .target = target, .optimize = optimize });
    test_deps.dependOn(add_ts_parser(b, "vimdoc", parser_vimdoc.path("."), false, target, optimize));
    const parser_lua = b.dependency("treesitter_lua", .{ .target = target, .optimize = optimize });
    test_deps.dependOn(add_ts_parser(b, "lua", parser_lua.path("."), true, target, optimize));
    const parser_query = b.dependency("treesitter_query", .{ .target = target, .optimize = optimize });
    test_deps.dependOn(add_ts_parser(b, "query", parser_query.path("."), false, target, optimize));

    try tests.test_steps(b, nvim_exe, test_deps, lua_dev_deps.path("."), test_config_step.getDirectory());
}

pub fn test_fixture(
    b: *std.Build,
    name: []const u8,
    libuv: ?*std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Step {
    const fixture = b.addExecutable(.{
        .name = name,
        .target = target,
        .optimize = optimize,
    });
    const source = if (std.mem.eql(u8, name, "pwsh-test")) "shell-test" else name;
    fixture.addCSourceFile(.{ .file = b.path(b.fmt("./test/functional/fixtures/{s}.c", .{source})) });
    fixture.linkLibC();
    if (libuv) |uv| fixture.linkLibrary(uv);
    return &b.addInstallArtifact(fixture, .{}).step;
}

pub fn add_ts_parser(
    b: *std.Build,
    name: []const u8,
    parser_dir: LazyPath,
    scanner: bool,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
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

    const parser_install = b.addInstallArtifact(parser, .{ .dest_sub_path = b.fmt("parser/{s}.so", .{name}) });
    return &parser_install.step;
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
    , .{ v.major, v.minor, v.patch, v.prerelease.len > 0, v.api_level, v.api_level_compat, v.api_prerelease });
}

pub fn test_config(b: *std.Build, gen_dir: LazyPath) ![]u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const src_path = try b.build_root.handle.realpath(".", &buf);

    // we don't use test/cmakeconfig/paths.lua.in because it contains cmake specific logic
    return b.fmt(
        \\local M = {{}}
        \\
        \\M.include_paths = {{}}
        \\M.apple_sysroot = ""
        \\M.translations_enabled = "$ENABLE_TRANSLATIONS" == "ON"
        \\M.is_asan = "$ENABLE_ASAN_UBSAN" == "ON"
        \\M.is_zig_build = true
        \\M.vterm_test_file = "test/vterm_test_output"
        \\M.test_build_dir = "{[bin_dir]s}" -- bull
        \\M.test_source_path = "{[src_path]s}"
        \\M.test_lua_prg = ""
        \\M.test_luajit_prg = ""
        \\table.insert(M.include_paths, "{[gen_dir]}/include")
        \\table.insert(M.include_paths, "{[gen_dir]}/src/nvim/auto")
        \\
        \\return M
    , .{ .bin_dir = b.install_path, .src_path = src_path, .gen_dir = gen_dir });
}
