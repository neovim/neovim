const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream = b.dependency("libiconv", .{});
    const lib = b.addStaticLibrary(.{
        .name = "iconv",
        .target = target,
        .optimize = optimize,
    });

    lib.addIncludePath(b.path("include/"));
    lib.addIncludePath(upstream.path(""));
    lib.addIncludePath(upstream.path("citrus/"));
    lib.addIncludePath(upstream.path("libcharset/"));
    lib.addIncludePath(upstream.path("libiconv_modules/UTF8/"));
    // zig any-macos-any headers already includes iconv, it just cannot link without a SDK
    // lib.installHeader(upstream.path("iconv.h"), "iconv.h");

    lib.linkLibC();

    lib.addCSourceFiles(.{ .root = upstream.path(""), .files = &.{
        "citrus/bsd_iconv.c",
        "citrus/citrus_bcs.c",
        "citrus/citrus_bcs_strtol.c",
        "citrus/citrus_bcs_strtoul.c",
        "citrus/citrus_csmapper.c",
        "citrus/citrus_db.c",
        "citrus/citrus_db_factory.c",
        "citrus/citrus_db_hash.c",
        "citrus/citrus_esdb.c",
        "citrus/citrus_hash.c",
        "citrus/citrus_iconv.c",
        "citrus/citrus_lookup.c",
        "citrus/citrus_lookup_factory.c",
        "citrus/citrus_mapper.c",
        "citrus/citrus_memstream.c",
        "citrus/citrus_mmap.c",
        "citrus/citrus_module.c",
        "citrus/citrus_none.c",
        "citrus/citrus_pivot_factory.c",
        "citrus/citrus_prop.c",
        "citrus/citrus_stdenc.c",
        "citrus/__iconv.c",
        "citrus/iconv.c",
        "citrus/iconv_canonicalize.c",
        "citrus/iconv_close.c",
        "citrus/iconv_compat.c",
        "citrus/iconvctl.c",
        "citrus/__iconv_free_list.c",
        "citrus/__iconv_get_list.c",
        "citrus/iconvlist.c",
        "citrus/iconv_open.c",
        "citrus/iconv_open_into.c",
        "citrus/iconv_set_relocation_prefix.c",
        "libcharset/libcharset.c",
        "libiconv_modules/BIG5/citrus_big5.c",
        "libiconv_modules/DECHanyu/citrus_dechanyu.c",
        "libiconv_modules/DECKanji/citrus_deckanji.c",
        "libiconv_modules/EUC/citrus_euc.c",
        "libiconv_modules/EUCTW/citrus_euctw.c",
        "libiconv_modules/GBK2K/citrus_gbk2k.c",
        "libiconv_modules/HZ/citrus_hz.c",
        "libiconv_modules/iconv_none/citrus_iconv_none.c",
        "libiconv_modules/iconv_std/citrus_iconv_std.c",
        "libiconv_modules/ISO2022/citrus_iso2022.c",
        "libiconv_modules/JOHAB/citrus_johab.c",
        "libiconv_modules/mapper_646/citrus_mapper_646.c",
        "libiconv_modules/mapper_none/citrus_mapper_none.c",
        "libiconv_modules/mapper_serial/citrus_mapper_serial.c",
        "libiconv_modules/mapper_std/citrus_mapper_std.c",
        "libiconv_modules/mapper_zone/citrus_mapper_zone.c",
        "libiconv_modules/MSKanji/citrus_mskanji.c",
        "libiconv_modules/UES/citrus_ues.c",
        "libiconv_modules/UTF1632/citrus_utf1632.c",
        "libiconv_modules/UTF7/citrus_utf7.c",
        "libiconv_modules/UTF8/citrus_utf8.c",
        "libiconv_modules/UTF8MAC/citrus_utf8mac.c",
        "libiconv_modules/VIQR/citrus_viqr.c",
        "libiconv_modules/ZW/citrus_zw.c",
    }, .flags = &.{
        "-D_PATH_I18NMODULE=\"/usr/lib/i18n\"",
        "-D_PATH_ESDB=\"/usr/share/i18n/esdb\"",
        "-D_PATH_CSMAPPER=\"/usr/share/i18n/csmapper\"",
    } });

    b.installArtifact(lib);
}
