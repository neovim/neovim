const std = @import("std");
const LazyPath = std.Build.LazyPath;

pub const SourceItem = struct { name: []u8, api_export: bool };

pub fn nvim_gen_runtime(
    b: *std.Build,
    nlua0: *std.Build.Step.Compile,
    nvim_bin: *std.Build.Step.Compile,
    funcs_data: LazyPath,
) !*std.Build.Step.WriteFile {
    const gen_runtime = b.addWriteFiles();

    {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/nvim/generators/gen_vimvim.lua"));
        const file = gen_step.addOutputFileArg("generated.vim");
        _ = gen_runtime.addCopyFile(file, "syntax/vim/generated.vim");
        gen_step.addFileArg(funcs_data);
        gen_step.addFileArg(b.path("src/nvim/options.lua"));
        gen_step.addFileArg(b.path("src/nvim/auevents.lua"));
        gen_step.addFileArg(b.path("src/nvim/ex_cmds.lua"));
        // gen_step.addFileArg(b.path("src/nvim/eval.c"));
    }

    _ = nvim_bin;

    return gen_runtime;
}
