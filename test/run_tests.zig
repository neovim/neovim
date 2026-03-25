const std = @import("std");
const LazyPath = std.Build.LazyPath;

pub fn testStep(b: *std.Build, kind: []const u8, nvim_bin: *std.Build.Step.Compile, config_dir: LazyPath, include_path: ?[]const LazyPath) !*std.Build.Step.Run {
    const test_step = b.addRunArtifact(nvim_bin);
    test_step.addArg("-ll");
    test_step.addFileArg(b.path("./test/runner.lua"));
    if (include_path) |paths| {
        for (paths) |path| {
            test_step.addPrefixedDirectoryArg("-I", path);
        }
    }
    test_step.addArg("-v");
    test_step.addArg(b.fmt("--helper=./test/{s}/preload.lua", .{kind}));
    test_step.addArg("--lpath=./src/?.lua");
    test_step.addArg("--lpath=./runtime/lua/?.lua");
    test_step.addArg("--lpath=./?.lua");
    test_step.addPrefixedFileArg("--lpath=", config_dir.path(b, "?.lua")); // FULING: not a real file but works anyway?
    // TODO(bfredl): look into a TEST_ARGS user hook, TEST_TAG, TEST_FILTER.
    if (b.args) |args| {
        test_step.addArgs(args); // accept TEST_FILE as a positional argument
    } else {
        test_step.addArg(b.fmt("./test/{s}/", .{kind}));
    }

    const env = test_step.getEnvMap();
    try env.put("NVIM_TEST", "1");
    try env.put("VIMRUNTIME", "runtime");
    try env.put("NVIM_RPLUGIN_MANIFEST", "Xtest_xdg/Xtest_rplugin_manifest");
    try env.put("XDG_CONFIG_HOME", "Xtest_xdg/config");
    try env.put("XDG_DATA_HOME", "Xtest_xdg/share");
    try env.put("XDG_STATE_HOME", "Xtest_xdg/state");
    try env.put("TMPDIR", b.fmt("{s}/Xtest_tmpdir", .{b.install_path}));
    try env.put("NVIM_LOG_FILE", b.fmt("{s}/Xtest_nvimlog", .{b.install_path}));

    env.remove("NVIM");
    env.remove("XDG_DATA_DIRS");
    return test_step;
}

pub fn test_steps(b: *std.Build, nvim_bin: *std.Build.Step.Compile, depend_on: *std.Build.Step, config_dir: LazyPath, unit_paths: ?[]const LazyPath) !void {
    const empty_dir = b.addWriteFiles();
    _ = empty_dir.add(".touch", "");
    const tmpdir_create = b.addInstallDirectory(.{ .source_dir = empty_dir.getDirectory(), .install_dir = .prefix, .install_subdir = "Xtest_tmpdir/" });

    const functional_tests = try testStep(b, "functional", nvim_bin, config_dir, null);
    functional_tests.step.dependOn(depend_on);
    functional_tests.step.dependOn(&tmpdir_create.step);

    const functionaltest_step = b.step("functionaltest", "run functional tests");
    functionaltest_step.dependOn(&functional_tests.step);

    if (unit_paths) |paths| {
        const unit_tests = try testStep(b, "unit", nvim_bin, config_dir, paths);
        unit_tests.step.dependOn(depend_on);
        unit_tests.step.dependOn(&tmpdir_create.step);

        const unittest_step = b.step("unittest", "run unit tests");
        unittest_step.dependOn(&unit_tests.step);
    }
}
