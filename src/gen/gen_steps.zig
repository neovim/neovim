const std = @import("std");
const LazyPath = std.Build.LazyPath;

pub const SourceItem = struct { name: []u8, api_export: bool };

pub fn nvim_gen_sources(
    b: *std.Build,
    nlua0: *std.Build.Step.Compile,
    nvim_sources: *std.ArrayList(SourceItem),
    nvim_headers: *std.ArrayList([]u8),
    api_headers: *std.ArrayList(LazyPath),
    include_path: []const LazyPath,
    target: std.Build.ResolvedTarget,
    versiondef_git: LazyPath,
    version_lua: LazyPath,
) !struct { *std.Build.Step.WriteFile, LazyPath } {
    const gen_headers = b.addWriteFiles();

    for (nvim_sources.items) |s| {
        const api_export = if (s.api_export) api_headers else null;
        const input_file = b.path(b.fmt("src/nvim/{s}", .{s.name}));
        _ = try generate_header_for(b, s.name, input_file, api_export, nlua0, include_path, target, gen_headers, false);
    }

    for (nvim_headers.items) |s| {
        const input_file = b.path(b.fmt("src/nvim/{s}", .{s}));
        _ = try generate_header_for(b, s, input_file, null, nlua0, include_path, target, gen_headers, true);
    }

    {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/gen/gen_ex_cmds.lua"));
        _ = gen_header(b, gen_step, "ex_cmds_enum.generated.h", gen_headers);
        _ = gen_header(b, gen_step, "ex_cmds_defs.generated.h", gen_headers);
        gen_step.addFileArg(b.path("src/nvim/ex_cmds.lua"));
    }

    {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/gen/gen_options.lua"));
        _ = gen_header(b, gen_step, "options.generated.h", gen_headers);
        _ = gen_header(b, gen_step, "options_enum.generated.h", gen_headers);
        _ = gen_header(b, gen_step, "options_map.generated.h", gen_headers);
        _ = gen_header(b, gen_step, "option_vars.generated.h", gen_headers);
        gen_step.addFileArg(b.path("src/nvim/options.lua"));

        const test_gen_step = b.step("wipopt", "debug one nlua0 (options)");
        test_gen_step.dependOn(&gen_step.step);
    }

    {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/gen/gen_events.lua"));
        _ = gen_header(b, gen_step, "auevents_enum.generated.h", gen_headers);
        _ = gen_header(b, gen_step, "auevents_name_map.generated.h", gen_headers);
        gen_step.addFileArg(b.path("src/nvim/auevents.lua"));
    }

    {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/gen/gen_keycodes.lua"));
        _ = gen_header(b, gen_step, "keycode_names.generated.h", gen_headers);
        gen_step.addFileArg(b.path("src/nvim/keycodes.lua"));
    }

    {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/gen/gen_char_blob.lua"));
        // TODO(bfredl): LUAC_PRG is missing. tricky with cross-compiling..
        // gen_step.addArg("-c");
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
        gen_step.addFileArg(b.path("src/gen/gen_api_ui_events.lua"));
        gen_step.addFileArg(b.path("src/nvim/api/ui_events.in.h"));
        _ = try gen_header_with_header(b, gen_step, "ui_events_call.generated.h", nlua0, include_path, target, gen_headers);
        _ = try gen_header_with_header(b, gen_step, "ui_events_remote.generated.h", nlua0, include_path, target, gen_headers);
        const ui_metadata = gen_step.addOutputFileArg("ui_metadata.mpack");
        _ = try gen_header_with_header(b, gen_step, "ui_events_client.generated.h", nlua0, include_path, target, gen_headers);
        break :ui_step ui_metadata;
    };

    const funcs_metadata = api_step: {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/gen/gen_api_dispatch.lua"));
        _ = try gen_header_with_header(b, gen_step, "api/private/dispatch_wrappers.generated.h", nlua0, include_path, target, gen_headers);
        _ = gen_header(b, gen_step, "api/private/api_metadata.generated.h", gen_headers);
        const funcs_metadata = gen_step.addOutputFileArg("funcs_metadata.mpack");
        _ = gen_header(b, gen_step, "lua_api_c_bindings.generated.h", gen_headers);
        _ = gen_header(b, gen_step, "keysets_defs.generated.h", gen_headers);
        gen_step.addFileArg(ui_metadata);
        gen_step.addFileArg(versiondef_git);
        gen_step.addFileArg(version_lua);
        gen_step.addFileArg(b.path("src/gen/dump_bin_array.lua"));
        gen_step.addFileArg(b.path("src/nvim/api/dispatch_deprecated.lua"));
        // now follows all .h files with exported functions
        for (api_headers.items) |h| {
            gen_step.addFileArg(h);
        }

        break :api_step funcs_metadata;
    };

    const funcs_data = eval_step: {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/gen/gen_eval.lua"));
        _ = gen_header(b, gen_step, "funcs.generated.h", gen_headers);
        gen_step.addFileArg(funcs_metadata);
        const funcs_data = gen_step.addOutputFileArg("funcs_data.mpack");
        gen_step.addFileArg(b.path("src/nvim/eval.lua"));
        break :eval_step funcs_data;
    };

    return .{ gen_headers, funcs_data };
}

fn gen_header(
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

fn gen_header_with_header(
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

fn run_preprocessor(
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
    // upstream issue: include path logic for addCSourceFiles and TranslateC is _very_ different
    for (options.include_dirs) |include_dir| {
        run_step.addArg("-I");
        run_step.addDirectoryArg(include_dir);
    }
    for (options.c_macros) |c_macro| {
        run_step.addArg(b.fmt("-D{s}", .{c_macro}));
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

fn generate_header_for(
    b: *std.Build,
    name: []const u8,
    input_file: LazyPath,
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
        .c_macros = &.{ "_GNU_SOURCE", "ZIG_BUILD" },
        .target = target,
    });
    const run_step = b.addRunArtifact(nlua0);
    run_step.addFileArg(b.path("src/gen/gen_declarations.lua"));
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
