#pragma once

#include "nvim/api/private/defs.h"

typedef struct {
  OptionalKeys is_set__empty_;
} Dict(empty);

typedef struct {
  OptionalKeys is_set__context_;
  ArrayOf(String) types;
} Dict(context);

typedef struct {
  OptionalKeys is_set__set_decoration_provider_;
  LuaRefOf(("start" _, Integer tick), *Boolean) on_start;
  LuaRefOf(("buf" _, Integer bufnr, Integer tick)) on_buf;
  LuaRefOf(("win" _, Integer winid, Integer bufnr, Integer toprow, Integer botrow),
           *Boolean) on_win;
  LuaRefOf(("line" _, Integer winid, Integer bufnr, Integer row), *Boolean) on_line;
  LuaRefOf(("range" _, Integer winid, Integer bufnr, Integer start_row, Integer start_col,
            Integer end_row, Integer end_col), *Boolean) on_range;
  LuaRefOf(("end" _, Integer tick)) on_end;
  LuaRefOf(("hl_def" _)) _on_hl_def;
  LuaRefOf(("spell_nav" _)) _on_spell_nav;
  LuaRefOf(("conceal_line" _)) _on_conceal_line;
} Dict(set_decoration_provider);

typedef struct {
  OptionalKeys is_set__set_extmark_;
  Integer id;
  Integer end_line;
  Integer end_row;
  Integer end_col;
  Object hl_group;
  Array virt_text;
  Enum("eol", "eol_right_align", "overlay", "right_align", "inline") virt_text_pos;
  Integer virt_text_win_col;
  Boolean virt_text_hide;
  Boolean virt_text_repeat_linebreak;
  Boolean hl_eol;
  Enum("replace", "combine", "blend") hl_mode;
  Boolean invalidate;
  Boolean ephemeral;
  Integer priority;
  Boolean right_gravity;
  Boolean end_right_gravity;
  Array virt_lines;
  Boolean virt_lines_above;
  Boolean virt_lines_leftcol;
  Enum("trunc", "scroll") virt_lines_overflow;
  Boolean strict;
  String sign_text;
  HLGroupID sign_hl_group;
  HLGroupID number_hl_group;
  HLGroupID line_hl_group;
  HLGroupID cursorline_hl_group;
  String conceal;
  String conceal_lines;
  Boolean spell;
  Boolean ui_watched;
  Boolean undo_restore;
  String url;
  Boolean scoped;

  Integer _subpriority;
} Dict(set_extmark);

typedef struct {
  OptionalKeys is_set__get_extmark_;
  Boolean details;
  Boolean hl_name;
} Dict(get_extmark);

typedef struct {
  OptionalKeys is_set__get_extmarks_;
  Integer limit;
  Boolean details;
  Boolean hl_name;
  Boolean overlap;
  String type;
} Dict(get_extmarks);

typedef struct {
  OptionalKeys is_set__keymap_;
  Boolean noremap;
  Boolean nowait;
  Boolean silent;
  Boolean script;
  Boolean expr;
  Boolean unique;
  LuaRef callback;
  String desc;
  Boolean replace_keycodes;
} Dict(keymap);

typedef struct {
  Boolean builtin;
} Dict(get_commands);

typedef struct {
  OptionalKeys is_set__user_command_;
  Object addr;
  Boolean bang;
  Boolean bar;
  Object complete;
  Object count;
  Object desc;
  Boolean force;
  Boolean keepscript;
  Object nargs;
  Object preview;
  Object range;
  Boolean register_ DictKey(register);
} Dict(user_command);

typedef struct {
  OptionalKeys is_set__win_config_;
  Float row;
  Float col;
  Integer width;
  Integer height;
  Enum("NW", "NE", "SW", "SE") anchor;
  Enum("cursor", "editor", "laststatus", "mouse", "tabline", "win") relative;
  Enum("left", "right", "above", "below") split;
  Window win;
  ArrayOf(Integer) bufpos;
  Boolean external;
  Boolean focusable;
  Boolean mouse;
  Boolean vertical;
  Integer zindex;
  Union(ArrayOf(String), Enum("none", "single", "double", "rounded", "solid", "shadow")) border;
  Object title;
  Enum("center", "left", "right") title_pos;
  Object footer;
  Enum("center", "left", "right") footer_pos;
  Enum("minimal") style;
  Boolean noautocmd;
  Boolean fixed;
  Boolean hide;
  Integer _cmdline_offset;
} Dict(win_config);

typedef struct {
  Boolean is_lua;
  Boolean do_source;
} Dict(runtime);

typedef struct {
  OptionalKeys is_set__eval_statusline_;
  Window winid;
  Integer maxwidth;
  String fillchar;
  Boolean highlights;
  Boolean use_winbar;
  Boolean use_tabline;
  Integer use_statuscol_lnum;
} Dict(eval_statusline);

typedef struct {
  OptionalKeys is_set__option_;
  String scope;
  Window win;
  Buffer buf;
  String filetype;
} Dict(option);

typedef struct {
  OptionalKeys is_set__highlight_;
  Boolean bold;
  Boolean standout;
  Boolean strikethrough;
  Boolean underline;
  Boolean undercurl;
  Boolean underdouble;
  Boolean underdotted;
  Boolean underdashed;
  Boolean italic;
  Boolean reverse;
  Boolean altfont;
  Boolean nocombine;
  Boolean default_ DictKey(default);
  Union(Integer, String) cterm;
  Union(Integer, String) foreground;
  Union(Integer, String) fg;
  Union(Integer, String) background;
  Union(Integer, String) bg;
  Union(Integer, String) ctermfg;
  Union(Integer, String) ctermbg;
  Union(Integer, String) special;
  Union(Integer, String) sp;
  HLGroupID link;
  HLGroupID global_link;
  Boolean fallback;
  Integer blend;
  Boolean fg_indexed;
  Boolean bg_indexed;
  Boolean force;
  String url;
} Dict(highlight);

typedef struct {
  Boolean bold;
  Boolean standout;
  Boolean strikethrough;
  Boolean underline;
  Boolean undercurl;
  Boolean underdouble;
  Boolean underdotted;
  Boolean underdashed;
  Boolean italic;
  Boolean reverse;
  Boolean altfont;
  Boolean nocombine;
} Dict(highlight_cterm);

typedef struct {
  OptionalKeys is_set__get_highlight_;
  Integer id;
  String name;
  Boolean link;
  Boolean create;
} Dict(get_highlight);

typedef struct {
  OptionalKeys is_set__get_ns_;
  Window winid;
} Dict(get_ns);

typedef struct {
  OptionalKeys is_set__win_text_height_;
  Integer start_row;
  Integer end_row;
  Integer start_vcol;
  Integer end_vcol;
  Integer max_height;
} Dict(win_text_height);

typedef struct {
  OptionalKeys is_set__clear_autocmds_;
  Buffer buffer;
  Union(String, ArrayOf(String)) event;
  Union(Integer, String) group;
  Union(String, ArrayOf(String)) pattern;
} Dict(clear_autocmds);

typedef struct {
  OptionalKeys is_set__create_autocmd_;
  Buffer buffer;
  Union(String, LuaRefOf((DictAs(create_autocmd__callback_args) args), *Boolean)) callback;
  String command;
  String desc;
  Union(Integer, String) group;
  Boolean nested;
  Boolean once;
  Union(String, ArrayOf(String)) pattern;
} Dict(create_autocmd);

typedef struct {
  OptionalKeys is_set__exec_autocmds_;
  Buffer buffer;
  Union(Integer, String) group;
  Boolean modeline;
  Union(String, ArrayOf(String)) pattern;
  Object data;
} Dict(exec_autocmds);

typedef struct {
  OptionalKeys is_set__get_autocmds_;
  Union(String, ArrayOf(String)) event;
  Union(Integer, String) group;
  Union(String, ArrayOf(String)) pattern;
  Union(Integer, ArrayOf(Integer)) buffer;
  Integer id;
} Dict(get_autocmds);

typedef struct {
  OptionalKeys is_set__create_augroup_;
  Boolean clear;
} Dict(create_augroup);

typedef struct {
  OptionalKeys is_set__cmd_;
  String cmd;
  ArrayOf(Integer) range;
  Integer count;
  String reg;
  Boolean bang;
  ArrayOf(String) args;
  DictAs(cmd__magic) magic;
  DictAs(cmd__mods) mods;
  Union(Integer, Enum("?", "+", "*")) nargs;
  Enum("line", "arg", "buf", "load", "win", "tab", "qf", "none", "?") addr;
  String nextcmd;
} Dict(cmd);

typedef struct {
  OptionalKeys is_set__cmd_magic_;
  Boolean file;
  Boolean bar;
} Dict(cmd_magic);

typedef struct {
  OptionalKeys is_set__cmd_mods_;
  Boolean silent;
  Boolean emsg_silent;
  Boolean unsilent;
  Dict filter;
  Boolean sandbox;
  Boolean noautocmd;
  Boolean browse;
  Boolean confirm;
  Boolean hide;
  Boolean horizontal;
  Boolean keepalt;
  Boolean keepjumps;
  Boolean keepmarks;
  Boolean keeppatterns;
  Boolean lockmarks;
  Boolean noswapfile;
  Integer tab;
  Integer verbose;
  Boolean vertical;
  String split;
} Dict(cmd_mods);

typedef struct {
  OptionalKeys is_set__cmd_mods_filter_;
  String pattern;
  Boolean force;
} Dict(cmd_mods_filter);

typedef struct {
  Boolean output;
} Dict(cmd_opts);

typedef struct {
  OptionalKeys is_set__echo_opts_;
  Boolean err;
  Boolean verbose;
  String kind;
  Union(Integer, String) id;
  String title;
  String status;
  Integer percent;
  DictOf(Object) data;
} Dict(echo_opts);

typedef struct {
  Boolean output;
} Dict(exec_opts);

typedef struct {
  OptionalKeys is_set__buf_attach_;
  LuaRefOf(("lines" _,
            Integer bufnr,
            Integer changedtick,
            Integer first,
            Integer last_old,
            Integer last_new,
            Integer byte_count,
            Integer *deleted_codepoints,
            Integer *deleted_codeunits), *Boolean) on_lines;
  LuaRefOf(("bytes" _,
            Integer bufnr,
            Integer changedtick,
            Integer start_row,
            Integer start_col,
            Integer start_byte,
            Integer old_end_row,
            Integer old_end_col,
            Integer old_end_byte,
            Integer new_end_row,
            Integer new_end_col,
            Integer new_end_byte), *Boolean) on_bytes;
  LuaRefOf(("changedtick" _, Integer bufnr, Integer changedtick)) on_changedtick;
  LuaRefOf(("detach" _, Integer bufnr)) on_detach;
  LuaRefOf(("reload" _, Integer bufnr)) on_reload;
  Boolean utf_sizes;
  Boolean preview;
} Dict(buf_attach);

typedef struct {
  OptionalKeys is_set__buf_delete_;
  Boolean force;
  Boolean unload;
} Dict(buf_delete);

typedef struct {
  OptionalKeys is_set__open_term_;
  LuaRefOf(("input" _, Integer term, Integer bufnr, any data)) on_input;
  Boolean force_crlf;
} Dict(open_term);

typedef struct {
  OptionalKeys is_set__complete_set_;
  String info;
} Dict(complete_set);

typedef struct {
  OptionalKeys is_set__xdl_diff_;
  LuaRefOf((Integer start_a, Integer count_a, Integer start_b, Integer count_b),
           *Integer) on_hunk;
  String result_type;
  String algorithm;
  Integer ctxlen;
  Integer interhunkctxlen;
  Union(Boolean, Integer) linematch;
  Boolean ignore_whitespace;
  Boolean ignore_whitespace_change;
  Boolean ignore_whitespace_change_at_eol;
  Boolean ignore_cr_at_eol;
  Boolean ignore_blank_lines;
  Boolean indent_heuristic;
} Dict(xdl_diff);

typedef struct {
  OptionalKeys is_set__redraw_;
  Boolean flush;
  Boolean cursor;
  Boolean valid;
  Boolean statuscolumn;
  Boolean statusline;
  Boolean tabline;
  Boolean winbar;
  Array range;
  Window win;
  Buffer buf;
} Dict(redraw);

typedef struct {
  OptionalKeys is_set__ns_opts_;
  Array wins;
} Dict(ns_opts);

typedef struct {
  OptionalKeys is_set___shada_search_pat_;
  Boolean magic DictKey(sm);
  Boolean smartcase DictKey(sc);
  Boolean has_line_offset DictKey(sl);
  Boolean place_cursor_at_end DictKey(se);
  Boolean is_last_used DictKey(su);
  Boolean is_substitute_pattern DictKey(ss);
  Boolean highlighted DictKey(sh);
  Boolean search_backward DictKey(sb);
  Integer offset DictKey(so);
  String pat DictKey(sp);
} Dict(_shada_search_pat);

typedef struct {
  OptionalKeys is_set___shada_mark_;
  Integer n;
  Integer l;
  Integer c;
  String f;
} Dict(_shada_mark);

typedef struct {
  OptionalKeys is_set___shada_register_;
  StringArray rc;
  Boolean ru;
  Integer rt;
  Integer n;
  Integer rw;
} Dict(_shada_register);

typedef struct {
  OptionalKeys is_set___shada_buflist_item_;
  Integer l;
  Integer c;
  String f;
} Dict(_shada_buflist_item);
