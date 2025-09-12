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
        const gen_step = b.addRunArtifact(nvim_bin);
        gen_step.step.dependOn(&install_doc_files.step);
        gen_step.addArgs(&.{ "-u", "NONE", "-i", "NONE", "-e", "--headless", "-c", "helptags ++t doc", "-c", "quit" });
        // TODO(bfredl): ugly on purpose. nvim should be able to generate "tags" at a specificed destination
        const install_path: std.Build.LazyPath = .{ .cwd_relative = b.install_path };
        gen_step.setCwd(install_path.path(b, "runtime/"));

        gen_runtime.step.dependOn(&gen_step.step);
    }

    return gen_runtime;
}
