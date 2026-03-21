const std = @import("std");
const LazyPath = std.Build.LazyPath;

pub const SourceItem = struct { name: []u8, api_export: bool };

pub fn nvim_gen_runtime(
    b: *std.Build,
    nlua0: *std.Build.Step.Compile,
    funcs_data: LazyPath,
) !*std.Build.Step.WriteFile {
    const gen_runtime = b.addWriteFiles();

    {
        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/gen/gen_vimvim.lua"));
        const file = gen_step.addOutputFileArg("generated.vim");
        _ = gen_runtime.addCopyFile(file, "syntax/vim/generated.vim");
        gen_step.addFileArg(funcs_data);
        gen_step.addFileArg(b.path("src/nvim/options.lua"));
        gen_step.addFileArg(b.path("src/nvim/auevents.lua"));
        gen_step.addFileArg(b.path("src/nvim/ex_cmds.lua"));
        gen_step.addFileArg(b.path("src/nvim/vvars.lua"));
    }

    {
        const install_doc_files = b.addInstallDirectory(.{ .source_dir = b.path("runtime/doc"), .install_dir = .prefix, .install_subdir = "runtime/doc" });
        gen_runtime.step.dependOn(&install_doc_files.step);

        const gen_step = b.addRunArtifact(nlua0);
        gen_step.addFileArg(b.path("src/gen/gen_helptags.lua"));
        const file = gen_step.addOutputFileArg("tags");
        _ = gen_runtime.addCopyFile(file, "doc/tags");
        gen_step.addDirectoryArg(b.path("runtime/doc"));
        gen_step.has_side_effects = true; // workaround: missing detection of input changes
    }

    return gen_runtime;
}
