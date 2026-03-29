const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const uncrustify = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    const uncrustify_exe = b.addExecutable(.{
        .name = "uncrustify",
        .root_module = uncrustify,
    });
    const upstream = b.dependency("uncrustify", .{});
    uncrustify.addCSourceFiles(.{
        .root = upstream.path(""),
        .files = &.{
            "src/ChunkStack.cpp",
            "src/align/add.cpp",
            "src/align/align.cpp",
            "src/align/asm_colon.cpp",
            "src/align/assign.cpp",
            "src/align/braced_init_list.cpp",
            "src/align/eigen_comma_init.cpp",
            "src/align/func_params.cpp",
            "src/align/func_proto.cpp",
            "src/align/init_brace.cpp",
            "src/align/left_shift.cpp",
            "src/align/log_al.cpp",
            "src/align/nl_cont.cpp",
            "src/align/oc_decl_colon.cpp",
            "src/align/oc_msg_colons.cpp",
            "src/align/oc_msg_spec.cpp",
            "src/align/preprocessor.cpp",
            "src/align/quick_align_again.cpp",
            "src/align/same_func_call_params.cpp",
            "src/align/stack.cpp",
            "src/align/struct_initializers.cpp",
            "src/align/tab_column.cpp",
            "src/align/tools.cpp",
            "src/align/trailing_comments.cpp",
            "src/align/typedefs.cpp",
            "src/align/var_def_brace.cpp",
            "src/args.cpp",
            "src/backup.cpp",
            "src/braces.cpp",
            "src/calculate_closing_brace_position.cpp",
            "src/change_int_types.cpp",
            "src/chunk.cpp",
            "src/compat_posix.cpp",
            "src/compat_win32.cpp",
            "src/detect.cpp",
            "src/ifdef_over_whole_file.cpp",
            "src/indent.cpp",
            "src/keywords.cpp",
            "src/lang_pawn.cpp",
            "src/language_names.cpp",
            "src/language_tools.cpp",
            "src/log_rules.cpp",
            "src/logger.cpp",
            "src/logmask.cpp",
            "src/mark_change.cpp",
            "src/md5.cpp",
            "src/newlines/add.cpp",
            "src/newlines/after.cpp",
            "src/newlines/annotations.cpp",
            "src/newlines/before_return.cpp",
            "src/newlines/between.cpp",
            "src/newlines/blank_line.cpp",
            "src/newlines/brace_pair.cpp",
            "src/newlines/can_increase_nl.cpp",
            "src/newlines/case.cpp",
            "src/newlines/chunk_pos.cpp",
            "src/newlines/class_colon_pos.cpp",
            "src/newlines/cleanup.cpp",
            "src/newlines/collapse_empty_body.cpp",
            "src/newlines/cuddle_uncuddle.cpp",
            "src/newlines/del_between.cpp",
            "src/newlines/do_else.cpp",
            "src/newlines/do_it_newlines_func_pre_blank_lines.cpp",
            "src/newlines/double_newline.cpp",
            "src/newlines/double_space_struct_enum_union.cpp",
            "src/newlines/eat_start_end.cpp",
            "src/newlines/end_newline.cpp",
            "src/newlines/enum.cpp",
            "src/newlines/force.cpp",
            "src/newlines/func.cpp",
            "src/newlines/func_pre_blank_lines.cpp",
            "src/newlines/functions_remove_extra_blank_lines.cpp",
            "src/newlines/get_closing_brace.cpp",
            "src/newlines/iarf.cpp",
            "src/newlines/if_for_while_switch.cpp",
            "src/newlines/is_func_call_or_def.cpp",
            "src/newlines/is_func_proto_group.cpp",
            "src/newlines/is_var_def.cpp",
            "src/newlines/min_after.cpp",
            "src/newlines/namespace.cpp",
            "src/newlines/oc_msg.cpp",
            "src/newlines/one_liner.cpp",
            "src/newlines/remove.cpp",
            "src/newlines/remove_next_newlines.cpp",
            "src/newlines/setup_newline_add.cpp",
            "src/newlines/sparens.cpp",
            "src/newlines/squeeze.cpp",
            "src/newlines/struct_union.cpp",
            "src/newlines/template.cpp",
            "src/newlines/var_def_blk.cpp",
            "src/option.cpp",
            "src/options_for_QT.cpp",
            "src/output.cpp",
            "src/parens.cpp",
            "src/parent_for_pp.cpp",
            "src/parsing_frame.cpp",
            "src/parsing_frame_stack.cpp",
            "src/pcf_flags.cpp",
            "src/punctuators.cpp",
            "src/reindent_line.cpp",
            "src/remove_duplicate_include.cpp",
            "src/remove_extra_returns.cpp",
            "src/rewrite_infinite_loops.cpp",
            "src/semicolons.cpp",
            "src/sorting.cpp",
            "src/space.cpp",
            "src/token_is_within_trailing_return.cpp",
            "src/tokenizer/EnumStructUnionParser.cpp",
            "src/tokenizer/brace_cleanup.cpp",
            "src/tokenizer/check_double_brace_init.cpp",
            "src/tokenizer/check_template.cpp",
            "src/tokenizer/combine.cpp",
            "src/tokenizer/combine_fix_mark.cpp",
            "src/tokenizer/combine_labels.cpp",
            "src/tokenizer/combine_skip.cpp",
            "src/tokenizer/combine_tools.cpp",
            "src/tokenizer/cs_top_is_question.cpp",
            "src/tokenizer/enum_cleanup.cpp",
            "src/tokenizer/flag_braced_init_list.cpp",
            "src/tokenizer/flag_decltype.cpp",
            "src/tokenizer/flag_parens.cpp",
            "src/tokenizer/mark_functor.cpp",
            "src/tokenizer/mark_question_colon.cpp",
            "src/tokenizer/parameter_pack_cleanup.cpp",
            "src/tokenizer/tokenize.cpp",
            "src/tokenizer/tokenize_cleanup.cpp",
            "src/too_big_for_nl_max.cpp",
            "src/unc_ctype.cpp",
            "src/unc_text.cpp",
            "src/unc_tools.cpp",
            "src/uncrustify.cpp",
            "src/uncrustify_types.cpp",
            "src/unicode.cpp",
            "src/universalindentgui.cpp",
            "src/width.cpp",
        },
    });
    uncrustify.addIncludePath(upstream.path("src"));

    // option_enum.h
    const gen_option_enum_h = b.addSystemCommand(&.{"python"});
    gen_option_enum_h.addFileArg(upstream.path("scripts/make_option_enum.py"));
    const option_enum_h = gen_option_enum_h.addOutputFileArg("option_enum.h");
    gen_option_enum_h.addFileArg(upstream.path("src/option.h"));
    gen_option_enum_h.addFileArg(upstream.path("src/option_enum.h.in"));
    uncrustify.addIncludePath(option_enum_h.dirname());

    // option_enum.cpp
    const gen_option_enum_cpp = b.addSystemCommand(&.{"python"});
    gen_option_enum_cpp.addFileArg(upstream.path("scripts/make_option_enum.py"));
    const option_enum_cpp = gen_option_enum_cpp.addOutputFileArg("option_enum.cpp");
    gen_option_enum_cpp.addFileArg(upstream.path("src/option.h"));
    gen_option_enum_cpp.addFileArg(upstream.path("src/option_enum.cpp.in"));
    uncrustify.addCSourceFile(.{ .file = option_enum_cpp });

    // options.cpp
    const gen_options_cpp = b.addSystemCommand(&.{"python"});
    gen_options_cpp.addFileArg(upstream.path("scripts/make_options.py"));
    const options_cpp = gen_options_cpp.addOutputFileArg("options.cpp");
    gen_options_cpp.addFileArg(upstream.path("src/options.h"));
    gen_options_cpp.addFileArg(upstream.path("src/options.cpp.in"));
    uncrustify.addCSourceFile(.{ .file = options_cpp });

    // punctuator_table.h
    const gen_punctuator_table_h = b.addSystemCommand(&.{"python"});
    gen_punctuator_table_h.addFileArg(upstream.path("scripts/make_punctuator_table.py"));
    const punctuator_table_h = gen_punctuator_table_h.addOutputFileArg("punctuator_table.h");
    gen_punctuator_table_h.addFileArg(upstream.path("src/symbols_table.h"));
    uncrustify.addIncludePath(punctuator_table_h.dirname());

    // config.h
    const config_h = b.addConfigHeader(.{
        .style = .{ .cmake = upstream.path("src/config.h.in") },
    }, .{
        .HAVE_INTTYPES_H = 1,
        .HAVE_MEMORY_H = 1,
        .HAVE_MEMSET = 1,
        .HAVE_STDBOOL_H = 1,
        .HAVE_STDINT_H = 1,
        .HAVE_STDLIB_H = 1,
        .HAVE_STRCASECMP = 1,
        .HAVE_STRCHR = 1,
        .HAVE_STRDUP = 1,
        .HAVE_STRERROR = 1,
        .HAVE_STRINGS_H = 1,
        .HAVE_STRING_H = 1,
        .HAVE_STRTOL = 1,
        .HAVE_STRTOUL = 1,
        .HAVE_SYS_STAT_H = 1,
        .HAVE_SYS_TYPES_H = 1,
        .HAVE_UNISTD_H = 1,
        .HAVE_UTIME_H = 1,
        .HAVE__BOOL = 1,
        .STDC_HEADERS = 1,
        .PACKAGE = null,
        .PACKAGE_BUGREPORT = null,
        .PACKAGE_NAME = null,
        .PACKAGE_STRING = null,
        .PACKAGE_TARNAME = null,
        .PACKAGE_URL = null,
        .PACKAGE_VERSION = null,
        .VERSION = null,
    });
    uncrustify.addConfigHeader(config_h);

    // uncrustify_version.h
    const uncrustify_version_h = b.addConfigHeader(
        .{
            .style = .{ .autoconf_at = upstream.path("src/uncrustify_version.h.in") },
        },
        .{ .UNCRUSTIFY_VERSION = "0.82.0" },
    );
    uncrustify.addConfigHeader(uncrustify_version_h);

    // token_names.h
    const gen_token_names = b.addSystemCommand(&.{"python"});
    gen_token_names.addFileArg(b.path("gen_token_names.py"));
    gen_token_names.addFileArg(upstream.path("src/token_enum.h"));
    const token_names_h = gen_token_names.addOutputFileArg("token_names.h");
    uncrustify.addIncludePath(token_names_h.dirname());

    b.installArtifact(uncrustify_exe);
}
