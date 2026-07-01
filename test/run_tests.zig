const std = @import("std");
const LazyPath = std.Build.LazyPath;

pub fn testStep(b: *std.Build, kind: []const u8, nvim_bin: *std.Build.Step.Compile, config_dir: LazyPath, include_path: ?[]const LazyPath) !*std.Build.Step.Run {
    const test_step = b.addRunArtifact(nvim_bin);
    test_step.addArg("-l");
    test_step.addFileArg(b.path("./test/runner.lua"));
    if (include_path) |paths| {
        for (paths) |path| {
            test_step.addPrefixedDirectoryArg("-I", path);
        }
    }
    test_step.addArg(b.fmt("-P{s}", .{b.install_path}));
    // TODO(bfredl): investigate parallell test groups like in cmake
    test_step.addArg(b.fmt("-X{s}/Xdg_dir", .{b.install_path}));
    test_step.addArg("-v");
    test_step.addArg(b.fmt("--helper=./test/{s}/preload.lua", .{kind}));
    test_step.addPrefixedFileArg("--lpath=", config_dir.path(b, "?.lua")); // FULING: not a real file but works anyway?
    test_step.addArg(b.fmt("--default-path=./test/{s}", .{kind}));
    if (b.args) |args| test_step.addArgs(args);

    const env = test_step.getEnvMap();
    try env.put("NVIM_TEST", "1");

    _ = env.swapRemove("NVIM");
    _ = env.swapRemove("XDG_DATA_DIRS");
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

        const unittest_step = b.step("unittest", "run unit tests");
        unittest_step.dependOn(&unit_tests.step);
    }
}
