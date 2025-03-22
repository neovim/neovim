const std = @import("std");
const LazyPath = std.Build.LazyPath;

pub fn test_steps(b: *std.Build, nvim_bin: *std.Build.Step.Compile, depend_on: *std.Build.Step, lua_deps: LazyPath, config_dir: LazyPath) !void {
    const test_step = b.addRunArtifact(nvim_bin);
    test_step.addArg("-ll");
    test_step.addFileArg(b.path("./test/lua_runner.lua"));
    test_step.addDirectoryArg(lua_deps);
    test_step.addArgs(&.{ "busted", "-v", "-o", "test.busted.outputHandlers.nvim", "--lazy" });
    // TODO: a bit funky with paths, should work even if we run "zig build" in a nested dir
    test_step.addArg("./test/functional/preload.lua"); // TEST_TYPE!!
    test_step.addArg("--lpath=./src/?.lua");
    test_step.addArg("--lpath=./runtime/lua/?.lua");
    test_step.addArg("--lpath=./?.lua");
    test_step.addPrefixedFileArg("--lpath=", config_dir.path(b, "?.lua")); // FULING: not a real file but works anyway?
    // TODO: $BUSTED_ARGS user hook
    // TODO: TEST_TAG
    // TODO: TEST_FILTER
    if (b.args) |args| {
        test_step.addArgs(args);
    } else {
        test_step.addArg("./test/functional/");
    }

    test_step.step.dependOn(depend_on);

    const env = test_step.getEnvMap();
    try env.put("VIMRUNTIME", "./runtime");
    try env.put("NVIM_RPLUGIN_MANIFEST", "./Xtest_xdg/Xtest_rplugin_manifest");
    try env.put("XDG_CONFIG_HOME", "./Xtest_xdg/config");
    try env.put("XDG_DATA_HOME", "./Xtest_xdg/share");
    try env.put("XDG_STATE_HOME", "./Xtest_xdg/state");
    try env.put("NVIM_LOG_FILE", "./.nvimlog_zig"); // TODO: conditional!!!

    env.remove("NVIM");
    env.remove("XDG_DATA_DIRS");

    const functionaltest_step = b.step("functionaltest", "run functionaltests");
    functionaltest_step.dependOn(&test_step.step);
}
