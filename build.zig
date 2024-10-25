const std = @import("std");
const LazyPath = std.Build.LazyPath;

const version = struct {
    const major = 0;
    const minor = 11;
    const patch = 0;
    const prerelease = "-dev";

    const api_level = 12;
    const api_level_compat = 0;
    const api_prerelease = 0;
};

// TODO: upstreeeeaam
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
    // TODO: we might want self-cross-compiling nlua0 when really-cross-compiling nvim..
    const target_host = if (cross_compiling) b.host else target;
    const optimize_host = .ReleaseSafe;

    const t = target.result;
    const tag = t.os.tag;

    // puc lua 5.1 is not ReleaseSafe "safe"
    const optimize_lua = if (optimize == .Debug) .ReleaseSmall else optimize;

    const use_luajit = false;

    const ziglua = b.dependency("ziglua", .{
        .target = target,
        .optimize = optimize_lua,
        .lang = if (use_luajit) .luajit else .lua51,
        .shared = false,
    });

    const ziglua_host = if (cross_compiling) b.dependency("ziglua", .{
        .target = target_host,
        .optimize = optimize_lua,
        .lang = if (use_luajit) .luajit else .lua51,
        .shared = false,
    }) else ziglua;

    const lpeg = b.dependency("lpeg", .{});

    const iconv_apple = if (cross_compiling and tag.isDarwin()) b.lazyDependency("iconv_apple", .{ .target = target, .optimize = optimize }) else null;

    // const lua = ziglua.artifact("lua");
    const lua = lazyArtifact(ziglua, "lua") orelse return;

    const libuv_dep = b.dependency("libuv", .{ .target = target, .optimize = optimize });
    const libuv = libuv_dep.artifact("uv");

    const libluv = try build_libluv(b, target, optimize, lua, libuv);

    const utf8proc = b.dependency("utf8proc", .{ .target = target, .optimize = optimize });
    const unibilium = b.dependency("unibilium", .{ .target = target, .optimize = optimize });
    const treesitter = b.dependency("treesitter", .{ .target = target, .optimize = optimize });

    const nlua0 = build_nlua0(b, target_host, optimize_host, use_luajit, ziglua_host, lpeg);

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
    };

    // source names _relative_ src/nvim/, not including other src/ subdircs
    var nvim_sources = try std.ArrayList(struct { name: []u8, api_export: bool }).initCapacity(b.allocator, 100);
    var nvim_headers = try std.ArrayList([]u8).initCapacity(b.allocator, 100);

    // both source headers and the {module}.h.generated.h files
    var api_headers = try std.ArrayList(std.Build.LazyPath).initCapacity(b.allocator, 10);

    const is_windows = (target.result.os.tag == .windows);
    // TODO: these should just become subdirs..
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
    const gen_headers = b.addWriteFiles();

    const version_lua = gen_config.add("nvim_version.lua", lua_version_info(b));

    var config_str = b.fmt("build.zig -Doptimize={s}", .{@tagName(optimize)});
    if (cross_compiling) {
        config_str = b.fmt("{s} -Dtarget={s} (host: {s})", .{ config_str, try t.linuxTriple(b.allocator), try b.host.result.linuxTriple(b.allocator) });
    }

    const versiondef_step = b.addConfigHeader(.{ .style = .{ .cmake = b.path("src/versiondef.h.in") } }, .{
        .NVIM_VERSION_MAJOR = version.major,
        .NVIM_VERSION_MINOR = version.minor,
        .NVIM_VERSION_PATCH = version.patch,
        .NVIM_VERSION_PRERELEASE = version.prerelease,
        .VERSION_STRING = "TODOx", // TODO
        .CONFIG = config_str, // TODO: include optimize name
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
        .HAVE_NL_MSG_CAT_CNTR = isLinux,
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
        .HAVE_WORKING_LIBINTL = isLinux,
        .UNIX = modernUnix,
        .CASE_INSENSITIVE_FILENAME = tag.isDarwin() or tag == .windows,
        .HAVE_SYS_UIO_H = modernUnix,
        .HAVE_READV = modernUnix,
        .HAVE_DIRFD_AND_FLOCK = modernUnix,
        .HAVE_FORKPTY = modernUnix and !tag.isDarwin(), // TODO: also on darwin but we lack the headers :(buil

        .HAVE_BE64TOH = isLinux or tag.isBSD(),
        .ORDER_BIG_ENDIAN = t.cpu.arch.endian() == .big,
        .ENDIAN_INCLUDE_FILE = "endian.h",
        .HAVE_EXECINFO_BACKTRACE = modernUnix,
        .HAVE_BUILTIN_ADD_OVERFLOW = true,
        .HAVE_WIMPLICIT_FALLTHROUGH_FLAG = true,
        .HAVE_BITSCANFORWARD64 = null,
    });

    // TODO: not used yet
    _ = gen_config.addCopyFile(sysconfig_step.getOutput(), "auto/config.h"); // run_preprocessor() workaronnd

    // TODO: actually run git :p
    const medium = b.fmt("v{}.{}.{}{s}+zig", .{ version.major, version.minor, version.patch, version.prerelease });
    const versiondef_git = gen_config.add("auto/versiondef_git.h", b.fmt(
        \\#define NVIM_VERSION_MEDIUM "{s}"
        \\#define NVIM_VERSION_BUILD "baaaar"
        \\
    , .{medium}));

    // TODO(zig): using getEmittedIncludeTree() is ugly af. we want run_preprocessor()
    // to use the std.build.Module include_path thing
    const include_path = &.{
        b.path("src/"),
        b.path("src/includes_fixmelater/"),
        gen_config.getDirectory(),
        lua.getEmittedIncludeTree(),
        libuv.getEmittedIncludeTree(),
        libluv.getEmittedIncludeTree(),
        utf8proc.artifact("utf8proc").getEmittedIncludeTree(),
        unibilium.artifact("unibilium").getEmittedIncludeTree(),
        treesitter.artifact("tree-sitter").getEmittedIncludeTree(),
    };

    for (nvim_sources.items) |s| {
        const api_export = if (s.api_export) &api_headers else null;
        const input_file = b.path(b.fmt("src/nvim/{s}", .{s.name}));
        _ = try generate_header_for(b, s.name, input_file, api_export, nlua0, include_path, target, gen_headers, false);
    }

    for (nvim_headers.items) |s| {
        const input_file = b.path(b.fmt("src/nvim/{s}", .{s}));
        _ = try generate_header_for(b, s, input_file, null, nlua0, include_path, target, gen_headers, true);
    }

    {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/nvim/generators/gen_ex_cmds.lua"));
        _ = gen_header(b, gen_step, "ex_cmds_enum.generated.h", gen_headers);
        _ = gen_header(b, gen_step, "ex_cmds_defs.generated.h", gen_headers);
        gen_step.addFileArg(b.path("src/nvim/ex_cmds.lua"));
    }

    {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/nvim/generators/gen_options.lua"));
        _ = gen_header(b, gen_step, "options.generated.h", gen_headers);
        gen_step.addFileArg(b.path("src/nvim/options.lua"));
    }

    {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/nvim/generators/gen_options_enum.lua"));
        _ = gen_header(b, gen_step, "options_enum.generated.h", gen_headers);
        _ = gen_header(b, gen_step, "options_map.generated.h", gen_headers);
        gen_step.addFileArg(b.path("src/nvim/options.lua"));
    }

    {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/nvim/generators/gen_events.lua"));
        _ = gen_header(b, gen_step, "auevents_enum.generated.h", gen_headers);
        _ = gen_header(b, gen_step, "auevents_name_map.generated.h", gen_headers);
        gen_step.addFileArg(b.path("src/nvim/auevents.lua"));
    }

    {
        // TODO: LUAC_PRG is missing. tricky with cross-compiling..
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/nvim/generators/gen_char_blob.lua"));
        gen_step.addArg("-c");
        _ = gen_header(b, gen_step, "lua/vim_module.generated.h", gen_headers);
        // NB: vim._init_packages and vim.inspect must be be first and second ones
        // respectively, otherwise --luamod-dev won't work properly.
        const names = [_][]const u8{
            "_init_packages",
            "inspect",
            "_editor",
            "filetype",
            "fs",
            "F",
            "keymap",
            "loader",
            "_defaults",
            "_options",
            "shared",
        };
        for (names) |n| {
            gen_step.addFileArg(b.path(b.fmt("runtime/lua/vim/{s}.lua", .{n})));
            gen_step.addArg(b.fmt("vim.{s}", .{n}));
        }
    }

    const ui_metadata = ui_step: {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/nvim/generators/gen_api_ui_events.lua"));
        gen_step.addFileArg(b.path("src/nvim/api/ui_events.in.h"));
        _ = try gen_header_with_header(b, gen_step, "ui_events_call.generated.h", nlua0, include_path, target, gen_headers);
        _ = try gen_header_with_header(b, gen_step, "ui_events_remote.generated.h", nlua0, include_path, target, gen_headers);
        const ui_metadata = gen_step.addOutputFileArg("ui_metadata.mpack");
        _ = try gen_header_with_header(b, gen_step, "ui_events_client.generated.h", nlua0, include_path, target, gen_headers);
        gen_step.addFileArg(b.path("src/nvim/generators/c_grammar.lua"));
        break :ui_step ui_metadata;
    };

    const funcs_metadata = api_step: {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/nvim/generators/gen_api_dispatch.lua"));
        _ = try gen_header_with_header(b, gen_step, "api/private/dispatch_wrappers.generated.h", nlua0, include_path, target, gen_headers);
        _ = gen_header(b, gen_step, "api/private/api_metadata.generated.h", gen_headers);
        const funcs_metadata = gen_step.addOutputFileArg("funcs_metadata.mpack");
        _ = gen_header(b, gen_step, "lua_api_c_bindings.generated.h", gen_headers);
        _ = gen_header(b, gen_step, "keysets_defs.generated.h", gen_headers);
        gen_step.addFileArg(ui_metadata);
        gen_step.addFileArg(versiondef_git);
        gen_step.addFileArg(version_lua);
        gen_step.addFileArg(b.path("src/nvim/generators/c_grammar.lua"));
        gen_step.addFileArg(b.path("src/nvim/generators/dump_bin_array.lua"));
        gen_step.addFileArg(b.path("src/nvim/api/dispatch_deprecated.lua"));
        // now follows all .h files with exported functions
        for (api_headers.items) |h| {
            gen_step.addFileArg(h);
        }

        break :api_step funcs_metadata;
    };

    const funcs_data = eval_step: {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/nvim/generators/gen_eval.lua"));
        _ = gen_header(b, gen_step, "funcs.generated.h", gen_headers);
        gen_step.addFileArg(funcs_metadata);
        const funcs_data = gen_step.addOutputFileArg("funcs_data.mpack");
        gen_step.addFileArg(b.path("src/nvim/eval.lua"));
        break :eval_step funcs_data;
    };

    _ = funcs_data;

    const test_gen_step = b.step("wip", "rearrange the power of it all");
    const config_install = b.addInstallDirectory(.{ .source_dir = gen_config.getDirectory(), .install_dir = .prefix, .install_subdir = "config/" });
    test_gen_step.dependOn(&config_install.step);
    test_gen_step.dependOn(&b.addInstallDirectory(.{ .source_dir = gen_headers.getDirectory(), .install_dir = .prefix, .install_subdir = "headers/" }).step);

    const sysconfig_test_step = b.step("sysconfig_test", "test the system config");
    sysconfig_test_step.dependOn(&config_install.step);
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
    nvim_exe.addIncludePath(b.path("src/includes_fixmelater"));
    nvim_exe.addIncludePath(gen_config.getDirectory());
    nvim_exe.addIncludePath(gen_headers.getDirectory());
    add_lua_modules(&nvim_exe.root_module, lpeg, use_luajit, false);

    const src_paths = try b.allocator.alloc([]u8, nvim_sources.items.len);
    for (nvim_sources.items, 0..) |s, i| {
        src_paths[i] = b.fmt("src/nvim/{s}", .{s.name});
    }

    const flags = [_][]const u8{
        "-std=gnu99",
        "-DINCLUDE_GENERATED_DECLARATIONS",
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
        "src/vterm/encoding.c",
        "src/vterm/keyboard.c",
        "src/vterm/mouse.c",
        "src/vterm/parser.c",
        "src/vterm/pen.c",
        "src/vterm/screen.c",
        "src/vterm/state.c",
        "src/vterm/unicode.c",
        "src/vterm/vterm.c",
    }, .flags = &flags });

    const nvim_exe_step = b.step("nvim_bin", "only the binary (not a fully working install!)");
    nvim_exe_step.dependOn(&b.addInstallArtifact(nvim_exe, .{}).step);
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

pub fn gen_header(
    b: *std.Build,
    gen_step: *std.Build.Step.Run,
    name: []const u8,
    gen_headers: *std.Build.Step.WriteFile,
) std.Build.LazyPath {
    _ = b;
    const header = gen_step.addOutputFileArg(name);
    _ = gen_headers.addCopyFile(header, name);
    return header;
}

pub fn gen_header_with_header(
    b: *std.Build,
    gen_step: *std.Build.Step.Run,
    name: []const u8,
    nlua0: *std.Build.Step.Compile,
    include_path: []const LazyPath,
    target: ?std.Build.ResolvedTarget,
    gen_headers: *std.Build.Step.WriteFile,
) !std.Build.LazyPath {
    if (name.len < 12 or !std.mem.eql(u8, ".generated.h", name[name.len - 12 ..])) return error.InvalidBaseName;
    const h = gen_header(b, gen_step, name, gen_headers);
    _ = try generate_header_for(b, b.fmt("{s}.h", .{name[0 .. name.len - 12]}), h, null, nlua0, include_path, target, gen_headers, false);
    return h;
}

pub const PreprocessorOptions = struct {
    include_dirs: []const LazyPath = &.{},
    c_macros: []const []const u8 = &.{},
    target: ?std.Build.ResolvedTarget = null,
};

// TODO: this should be suggested to upstream
pub fn run_preprocessor(
    b: *std.Build,
    src: LazyPath,
    output_name: []const u8,
    options: PreprocessorOptions,
) !LazyPath {
    const run_step = std.Build.Step.Run.create(b, b.fmt("preprocess to get {s}", .{output_name}));
    run_step.addArgs(&.{ b.graph.zig_exe, "cc", "-E" });
    run_step.addFileArg(src);
    run_step.addArg("-o");
    const output = run_step.addOutputFileArg(output_name);
    // TODO: include path logic for addCSourceFiles and TranslateC is _very_ different
    for (options.include_dirs) |include_dir| {
        run_step.addArg("-I");
        run_step.addDirectoryArg(include_dir);
    }
    for (options.c_macros) |c_macro| {
        run_step.addArg(b.fmt("-D{s}", .{c_macro}));
        run_step.addArg(c_macro);
    }
    if (options.target) |t| {
        if (!t.query.isNative()) {
            run_step.addArgs(&.{
                "-target", try t.query.zigTriple(b.allocator),
            });
        }
    }
    run_step.addArgs(&.{ "-MMD", "-MF" });
    _ = run_step.addDepFileOutputArg(b.fmt("{s}.d", .{output_name}));
    return output;
}

pub fn generate_header_for(
    b: *std.Build,
    name: []const u8,
    input_file: std.Build.LazyPath,
    api_export: ?*std.ArrayList(LazyPath),
    nlua0: *std.Build.Step.Compile,
    include_path: []const LazyPath,
    target: ?std.Build.ResolvedTarget,
    gen_headers: *std.Build.Step.WriteFile,
    nvim_header: bool,
) !*std.Build.Step.Run {
    if (name.len < 2 or !(std.mem.eql(u8, ".c", name[name.len - 2 ..]) or std.mem.eql(u8, ".h", name[name.len - 2 ..]))) return error.InvalidBaseName;
    const basename = name[0 .. name.len - 2];
    const i_file = try run_preprocessor(b, input_file, b.fmt("{s}.i", .{basename}), .{
        .include_dirs = include_path,
        .c_macros = &.{ "HAVE_UNIBILIUM", "_GNU_SOURCE" },
        .target = target,
    });
    const run_step = b.addRunArtifact(nlua0);
    run_step.addFileArg(b.path("src/nvim/generators/gen_declarations.lua"));
    run_step.addFileArg(input_file);
    const gen_name = b.fmt("{s}.{s}.generated.h", .{ basename, if (nvim_header) "h.inline" else "c" });
    _ = gen_header(b, run_step, gen_name, gen_headers);
    if (nvim_header) {
        run_step.addArg("SKIP");
    } else {
        const h_file = gen_header(b, run_step, b.fmt("{s}.h.generated.h", .{basename}), gen_headers);
        if (api_export) |api_files| {
            try api_files.append(h_file);
        }
    }

    run_step.addFileArg(i_file);
    run_step.addArg(gen_name);
    return run_step;
}

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
    const nlua0_mod = &nlua0_exe.root_module;

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/nlua0.zig"),
        .target = target,
        .optimize = optimize,
    });

    // TODO: need mod.addLibraryPathFromDependency(ziglua)
    // nlua0_mod.include_dirs.append(nlua0_mod.owner.allocator, .{ .other_step = ziglua_mod }) catch @panic("OOM");

    const embedded_data = b.addModule("embedded_data", .{
        .root_source_file = b.path("runtime/embedded_data.zig"),
    });

    for ([2]*std.Build.Module{ nlua0_mod, &exe_unit_tests.root_module }) |mod| {
        mod.addImport("ziglua", ziglua.module("ziglua"));
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
