#pragma once

#include "nvim/api/private/defs.h"

typedef struct {
  OptionalKeys is_set__empty_;
} Dict(empty);

typedef struct {
  OptionalKeys is_set__context_;
  Array types;
} Dict(context);

typedef struct {
  OptionalKeys is_set__set_decoration_provider_;
  LuaRef on_start;
  LuaRef on_buf;
  LuaRef on_win;
  LuaRef on_line;
  LuaRef on_end;
  LuaRef _on_hl_def;
  LuaRef _on_spell_nav;
} Dict(set_decoration_provider);

typedef struct {
  OptionalKeys is_set__set_extmark_;
  Integer id;
  Integer end_line;
  Integer end_row;
  Integer end_col;
  HLGroupID hl_group;
  Array virt_text;
  String virt_text_pos;
  Integer virt_text_win_col;
  Boolean virt_text_hide;
  Boolean virt_text_repeat_linebreak;
  Boolean hl_eol;
  String hl_mode;
  Boolean invalidate;
  Boolean ephemeral;
  Integer priority;
  Boolean right_gravity;
  Boolean end_right_gravity;
  Array virt_lines;
  Boolean virt_lines_above;
  Boolean virt_lines_leftcol;
  Boolean strict;
  String sign_text;
  HLGroupID sign_hl_group;
  HLGroupID number_hl_group;
  HLGroupID line_hl_group;
  HLGroupID cursorline_hl_group;
  String conceal;
  Boolean spell;
  Boolean ui_watched;
  Boolean undo_restore;
  String url;
  Boolean scoped;
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
  Boolean register_;
} Dict(user_command);

typedef struct {
  OptionalKeys is_set__win_config_;
  Float row;
  Float col;
  Integer width;
  Integer height;
  String anchor;
  String relative;
  String split;
  Window win;
  Array bufpos;
  Boolean external;
  Boolean focusable;
  Boolean vertical;
  Integer zindex;
  Object border;
  Object title;
  String title_pos;
  Object footer;
  String footer_pos;
  String style;
  Boolean noautocmd;
  Boolean fixed;
  Boolean hide;
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
  Boolean default_;
  Object cterm;
  Object foreground;
  Object fg;
  Object background;
  Object bg;
  Object ctermfg;
  Object ctermbg;
  Object special;
  Object sp;
  Object link;
  Object global_link;
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
} Dict(win_text_height);

typedef struct {
  OptionalKeys is_set__clear_autocmds_;
  Buffer buffer;
  Object event;
  Object group;
  Object pattern;
} Dict(clear_autocmds);

typedef struct {
  OptionalKeys is_set__create_autocmd_;
  Buffer buffer;
  Object callback;
  String command;
  String desc;
  Object group;
  Boolean nested;
  Boolean once;
  Object pattern;
} Dict(create_autocmd);

typedef struct {
  OptionalKeys is_set__exec_autocmds_;
  Buffer buffer;
  Object group;
  Boolean modeline;
  Object pattern;
  Object data;
} Dict(exec_autocmds);

typedef struct {
  OptionalKeys is_set__get_autocmds_;
  Object event;
  Object group;
  Object pattern;
  Object buffer;
} Dict(get_autocmds);

typedef struct {
  Object clear;
} Dict(create_augroup);

typedef struct {
  OptionalKeys is_set__cmd_;
  String cmd;
  Array range;
  Integer count;
  String reg;
  Boolean bang;
  Array args;
  Dictionary magic;
  Dictionary mods;
  Object nargs;
  Object addr;
  Object nextcmd;
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
  Dictionary filter;
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
  Boolean verbose;
} Dict(echo_opts);

typedef struct {
  Boolean output;
} Dict(exec_opts);

typedef struct {
  OptionalKeys is_set__buf_attach_;
  LuaRef on_lines;
  LuaRef on_bytes;
  LuaRef on_changedtick;
  LuaRef on_detach;
  LuaRef on_reload;
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
  LuaRef on_input;
  Boolean force_crlf;
} Dict(open_term);

typedef struct {
  OptionalKeys is_set__complete_set_;
  String info;
} Dict(complete_set);

typedef struct {
  OptionalKeys is_set__xdl_diff_;
  LuaRef on_hunk;
  String result_type;
  String algorithm;
  Integer ctxlen;
  Integer interhunkctxlen;
  Object linematch;
  Boolean ignore_whitespace;
  Boolean ignore_whitespace_change;
  Boolean ignore_whitespace_change_at_eol;
  Boolean ignore_cr_at_eol;
  Boolean ignore_blank_lines;
  Boolean indent_heuristic;
} Dict(xdl_diff);
