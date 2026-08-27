const std = @import("std");
const gen = @import("gen/gen_steps.zig");

pub fn lintSources(
    b: *std.Build,
    nvim_sources: std.ArrayList(gen.SourceItem),
    nvim_headers: std.ArrayList([]u8),
) !std.ArrayList([]const u8) {
    var lint_sources: std.ArrayList([]const u8) = try .initCapacity(b.allocator, 0);
    for (nvim_sources.items) |source| {
        try lint_sources.append(b.allocator, b.fmt("src/nvim/{s}", .{source.name}));
    }
    for (nvim_headers.items) |header| {
        try lint_sources.append(b.allocator, b.fmt("src/nvim/{s}", .{header}));
    }
    try lint_sources.append(b.allocator, "src/tee/tee.c");
    try lint_sources.append(b.allocator, "src/xxd/xxd.c");
    return lint_sources;
}

pub fn addSteps(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    cdb_step: *std.Build.Step,
    nvim_exe_install: *std.Build.Step.InstallArtifact,
    nvim_sources: std.ArrayList(gen.SourceItem),
    nvim_headers: std.ArrayList([]u8),
    ci_build: bool,
) !void {
    const lintc = b.step("lintc", "Lint C source");
    var lint_sources = try lintSources(b, nvim_sources, nvim_headers);
    defer lint_sources.deinit(b.allocator);
    const lintc_uncrustify = addLintcUncrustifyStep(b, lint_sources);
    lintc.dependOn(lintc_uncrustify);
    const lintc_clint = addLintcClintStep(b, nvim_exe_install, lint_sources, ci_build);
    lintc.dependOn(lintc_clint);
    const lintc_clang_tidy = try addLintcClangtidyStep(b, cdb_step, nvim_exe_install, target, lint_sources);
    lintc.dependOn(lintc_clang_tidy);
    try addFormatcStep(b, lint_sources);
}

fn addLintcUncrustifyStep(
    b: *std.Build,
    lint_sources: std.ArrayList([]const u8),
) *std.Build.Step {
    const lintc_uncrustify = b.step("lintc-uncrustify", "Check formatting of C source with uncrustify");
    const uncrustify = b.dependency("uncrustify", .{
        .target = b.graph.host,
        .optimize = .ReleaseFast,
    });
    const uncrustify_exe = uncrustify.artifact("uncrustify");
    for (lint_sources.items) |file| {
        const run = b.addRunArtifact(uncrustify_exe);
        run.addArgs(&.{ "-c", "src/uncrustify.cfg", "-q", "--check" });
        run.addFileArg(b.path(file));
        run.expectExitCode(0);
        lintc_uncrustify.dependOn(&run.step);
    }
    return lintc_uncrustify;
}

fn addLintcClangtidyStep(
    b: *std.Build,
    cdb_step: *std.Build.Step,
    nvim_exe_install: *std.Build.Step.InstallArtifact,
    target: std.Build.ResolvedTarget,
    lint_sources: std.ArrayList([]const u8),
) !*std.Build.Step {
    const lintc_clang_tidy = b.step("lintc-clang-tidy", "Lint C source with clang-tidy");
    var exclusions: std.ArrayList([]const u8) = try .initCapacity(b.allocator, 0);
    defer exclusions.deinit(b.allocator);
    try exclusions.appendSlice(b.allocator, &.{
        "src/nvim/eval/typval_encode.c.h",
        "src/nvim/api/ui_events.in.h",
        "src/xxd/xxd.c",
    });
    if (target.result.os.tag == .windows) {
        try exclusions.appendSlice(b.allocator, &.{
            "src/nvim/os/pty_proc_unix.h",
            "src/nvim/os/unix_defs.h",
        });
    } else {
        try exclusions.appendSlice(b.allocator, &.{
            "src/nvim/os/win_defs.h",
            "src/nvim/os/pty_proc_win.h",
            "src/nvim/os/pty_conpty_win.h",
            "src/nvim/os/os_win_console.h",
        });
    }

    outer: for (lint_sources.items) |file| {
        for (exclusions.items) |exclusion| {
            if (std.mem.eql(u8, exclusion, file)) continue :outer;
        }
        const run = b.addSystemCommand(&.{"clang-tidy"});
        run.step.dependOn(cdb_step);
        run.step.dependOn(&nvim_exe_install.step);
        run.addFileArg(b.path(file));
        run.addArg("--quiet");
        run.expectStdOutEqual("");
        lintc_clang_tidy.dependOn(&run.step);
    }
    return lintc_clang_tidy;
}

fn addLintcClintStep(
    b: *std.Build,
    // use InstallArtifact instead of nvim_exe so that cache is not busted
    // for every file to be linted
    nvim_exe_install: *std.Build.Step.InstallArtifact,
    lint_sources: std.ArrayList([]const u8),
    ci_build: bool,
) *std.Build.Step {
    const lintc_clint = b.step("lintc-clint", "Lint C source with clint");
    const exclusions = [_][]const u8{ "src/nvim/tui/terminfo_defs.h", "src/xxd/xxd.c" };
    const nvim_path = b.getInstallPath(.bin, nvim_exe_install.artifact.out_filename);

    outer: for (lint_sources.items) |file| {
        for (exclusions) |exclusion| {
            if (std.mem.endsWith(u8, file, exclusion)) continue :outer;
        }
        const run = b.addSystemCommand(&.{nvim_path});
        run.step.dependOn(&nvim_exe_install.step);
        run.addArgs(&.{ "-u", "NONE", "-l" });
        run.addFileArg(b.path("src/clint.lua"));
        if (ci_build) {
            run.addArg("--output=gh_action");
        } else {
            run.addArg("--output=vs7");
        }
        run.addFileArg(b.path(file));
        run.expectStdOutEqual("");
        lintc_clint.dependOn(&run.step);
    }
    return lintc_clint;
}

fn addFormatcStep(
    b: *std.Build,
    lint_sources: std.ArrayList([]const u8),
) !void {
    const formatc = b.step("formatc", "Format C source with uncrustify");
    const uncrustify = b.dependency("uncrustify", .{
        .target = b.graph.host,
        .optimize = .ReleaseFast,
    });
    const uncrustify_exe = uncrustify.artifact("uncrustify");

    const update = b.addUpdateSourceFiles();
    for (lint_sources.items) |file| {
        const run = b.addRunArtifact(uncrustify_exe);
        run.addArgs(&.{ "-c", "src/uncrustify.cfg", "-f" });
        run.addFileArg(b.path(file));
        run.addArg("-o");
        const output_name = try std.mem.replaceOwned(u8, b.allocator, file, "/", "-");
        const output = run.addOutputFileArg(output_name);
        update.addCopyFileToSource(output, file);
    }
    formatc.dependOn(&update.step);
}
