const std = @import("std");
const LazyPath = std.Build.LazyPath;

pub fn testStep(b: *std.Build, kind: []const u8, nvim_bin: *std.Build.Step.Compile, config_dir: LazyPath, include_path: ?[]const LazyPath) !*std.Build.Step.Run {
    const test_step = b.addRunArtifact(nvim_bin);
    test_step.addArg("-l");
    test_step.addFileArg(b.path("test/runner.lua"));
    if (include_path) |paths| {
        for (paths) |path| {
            test_step.addPrefixedDirectoryArg("-I", path);
        }
    }
    const install_path = b.getInstallPath(.prefix, ".");
    if (b.graph.host.result.os.tag != .windows) {
        test_step.setCwd(.{ .cwd_relative = b.fmt("{s}/Xtest_xdg", .{install_path}) });
    }
    test_step.addArg(b.fmt("-P{s}", .{install_path}));
    test_step.addArg("-v");
    test_step.addPrefixedFileArg("--helper=", b.path(b.fmt("test/{s}/preload.lua", .{kind})));
    test_step.addDecoratedDirectoryArg("--lpath=", b.path("src"), "/?.lua");
    test_step.addDecoratedDirectoryArg("--lpath=", b.path("runtime/lua"), "/?.lua");
    test_step.addDecoratedDirectoryArg("--lpath=", b.path("."), "/?.lua");
    test_step.addPrefixedFileArg("--lpath=", config_dir.path(b, "?.lua")); // FULING: not a real file but works anyway?
    test_step.addDecoratedDirectoryArg("--default-path=", b.path("test"), b.fmt("/{s}", .{kind}));
    if (b.args) |args| test_step.addArgs(args);

    const env = test_step.getEnvMap();
    try env.put("NVIM_TEST", "1");
    try env.put("VIMRUNTIME", try b.build_root.join(b.graph.arena, &.{"runtime"}));
    try env.put("NVIM_RPLUGIN_MANIFEST", b.fmt("{s}/Xtest_xdg/Xtest_rplugin_manifest", .{install_path}));
    try env.put("XDG_CONFIG_HOME", b.fmt("{s}/Xtest_xdg/config", .{install_path}));
    try env.put("XDG_DATA_HOME", b.fmt("{s}/Xtest_xdg/share", .{install_path}));
    try env.put("XDG_STATE_HOME", b.fmt("{s}/Xtest_xdg/state", .{install_path}));

    _ = env.swapRemove("NVIM");
    _ = env.swapRemove("XDG_DATA_DIRS");
    return test_step;
}

pub fn test_steps(b: *std.Build, nvim_bin: *std.Build.Step.Compile, depend_on: *std.Build.Step, config_dir: LazyPath, unit_paths: ?[]const LazyPath) !void {
    const empty_dir = b.addWriteFiles();
    _ = empty_dir.add(".touch", "");
    const tmpdir_create = b.addInstallDirectory(.{ .source_dir = empty_dir.getDirectory(), .install_dir = .prefix, .install_subdir = "Xtest_tmpdir/" });
    const install_path = b.getInstallPath(.prefix, ".");
    const xdgdir_step = xdgdir: {
        if (b.graph.host.result.os.tag == .windows) {
            const xdgdir_create = b.addInstallDirectory(.{ .source_dir = empty_dir.getDirectory(), .install_dir = .prefix, .install_subdir = "Xtest_xdg/" });
            break :xdgdir &xdgdir_create.step;
        }
        const xdgdir_setup = b.addSystemCommand(&.{
            "sh",
            "-c",
            "mkdir -p \"$1\" && ln -sfn \"$2\" \"$1/runtime\" && ln -sfn \"$3\" \"$1/src\" && ln -sfn \"$4\" \"$1/test\" && ln -sfn \"$5\" \"$1/README.md\"",
            "setup-test-xdg",
            b.fmt("{s}/Xtest_xdg", .{install_path}),
            try b.build_root.join(b.graph.arena, &.{"runtime"}),
            try b.build_root.join(b.graph.arena, &.{"src"}),
            try b.build_root.join(b.graph.arena, &.{"test"}),
            try b.build_root.join(b.graph.arena, &.{"README.md"}),
        });
        break :xdgdir &xdgdir_setup.step;
    };

    const functional_tests = try testStep(b, "functional", nvim_bin, config_dir, null);
    functional_tests.step.dependOn(depend_on);
    functional_tests.step.dependOn(&tmpdir_create.step);
    functional_tests.step.dependOn(xdgdir_step);

    const functionaltest_step = b.step("functionaltest", "run functional tests");
    functionaltest_step.dependOn(&functional_tests.step);

    const old_tests = b.addRunArtifact(nvim_bin);
    old_tests.addArg("-l");
    old_tests.addFileArg(b.path("./test/old/runner.lua"));
    if (b.args) |args| {
        old_tests.addArgs(args); // accept TEST_FILE as a positional argument
    }
    const env = old_tests.getEnvMap();
    try env.put("BUILD_DIR", b.install_path);

    const oldtest_step = b.step("oldtest", "run old tests");
    oldtest_step.dependOn(&old_tests.step);
    oldtest_step.dependOn(depend_on);

    if (unit_paths) |paths| {
        const unit_tests = try testStep(b, "unit", nvim_bin, config_dir, paths);
        unit_tests.step.dependOn(depend_on);
        unit_tests.step.dependOn(&tmpdir_create.step);
        unit_tests.step.dependOn(xdgdir_step);

        const unittest_step = b.step("unittest", "run unit tests");
        unittest_step.dependOn(&unit_tests.step);
    }
}
