#ifndef NVIM_API_KEYSETS_H
#define NVIM_API_KEYSETS_H

#include "nvim/api/private/defs.h"

typedef struct {
  Object types;
} Dict(context);

typedef struct {
  Object on_start;
  Object on_buf;
  Object on_win;
  Object on_line;
  Object on_end;
  Object _on_hl_def;
  Object _on_spell_nav;
} Dict(set_decoration_provider);

typedef struct {
  Object id;
  Object end_line;
  Object end_row;
  Object end_col;
  Object hl_group;
  Object virt_text;
  Object virt_text_pos;
  Object virt_text_win_col;
  Object virt_text_hide;
  Object hl_eol;
  Object hl_mode;
  Object ephemeral;
  Object priority;
  Object right_gravity;
  Object end_right_gravity;
  Object virt_lines;
  Object virt_lines_above;
  Object virt_lines_leftcol;
  Object strict;
  Object sign_text;
  Object sign_hl_group;
  Object number_hl_group;
  Object line_hl_group;
  Object cursorline_hl_group;
  Object conceal;
  Object spell;
  Object ui_watched;
} Dict(set_extmark);

typedef struct {
  Object noremap;
  Object nowait;
  Object silent;
  Object script;
  Object expr;
  Object unique;
  Object callback;
  Object desc;
  Object replace_keycodes;
} Dict(keymap);

typedef struct {
  Object builtin;
} Dict(get_commands);

typedef struct {
  Object addr;
  Object bang;
  Object bar;
  Object complete;
  Object count;
  Object desc;
  Object force;
  Object keepscript;
  Object nargs;
  Object preview;
  Object range;
  Object register_;
} Dict(user_command);

typedef struct {
  Object row;
  Object col;
  Object width;
  Object height;
  Object anchor;
  Object relative;
  Object win;
  Object bufpos;
  Object external;
  Object focusable;
  Object zindex;
  Object border;
  Object title;
  Object title_pos;
  Object style;
  Object noautocmd;
} Dict(float_config);

typedef struct {
  Object is_lua;
  Object do_source;
} Dict(runtime);

typedef struct {
  Object winid;
  Object maxwidth;
  Object fillchar;
  Object highlights;
  Object use_winbar;
  Object use_tabline;
  Object use_statuscol_lnum;
} Dict(eval_statusline);

typedef struct {
  Object scope;
  Object win;
  Object buf;
  Object filetype;
} Dict(option);

typedef struct {
  Object bold;
  Object standout;
  Object strikethrough;
  Object underline;
  Object undercurl;
  Object underdouble;
  Object underdotted;
  Object underdashed;
  Object italic;
  Object reverse;
  Object altfont;
  Object nocombine;
  Object default_;
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
  Object fallback;
  Object blend;
  Object fg_indexed;
  Object bg_indexed;
} Dict(highlight);

typedef struct {
  Object bold;
  Object standout;
  Object strikethrough;
  Object underline;
  Object undercurl;
  Object underdouble;
  Object underdotted;
  Object underdashed;
  Object italic;
  Object reverse;
  Object altfont;
  Object nocombine;
} Dict(highlight_cterm);

typedef struct {
  Object id;
  Object name;
  Object link;
} Dict(get_highlight);

typedef struct {
  Object buffer;
  Object event;
  Object group;
  Object pattern;
} Dict(clear_autocmds);

typedef struct {
  Object buffer;
  Object callback;
  Object command;
  Object desc;
  Object group;
  Object nested;
  Object once;
  Object pattern;
} Dict(create_autocmd);

typedef struct {
  Object buffer;
  Object group;
  Object modeline;
  Object pattern;
  Object data;
} Dict(exec_autocmds);

typedef struct {
  Object event;
  Object group;
  Object pattern;
  Object buffer;
} Dict(get_autocmds);

typedef struct {
  Object clear;
} Dict(create_augroup);

typedef struct {
  Object cmd;
  Object range;
  Object count;
  Object reg;
  Object bang;
  Object args;
  Object magic;
  Object mods;
  Object nargs;
  Object addr;
  Object nextcmd;
} Dict(cmd);

typedef struct {
  Object file;
  Object bar;
} Dict(cmd_magic);

typedef struct {
  Object silent;
  Object emsg_silent;
  Object unsilent;
  Object filter;
  Object sandbox;
  Object noautocmd;
  Object browse;
  Object confirm;
  Object hide;
  Object horizontal;
  Object keepalt;
  Object keepjumps;
  Object keepmarks;
  Object keeppatterns;
  Object lockmarks;
  Object noswapfile;
  Object tab;
  Object verbose;
  Object vertical;
  Object split;
} Dict(cmd_mods);

typedef struct {
  Object pattern;
  Object force;
} Dict(cmd_mods_filter);

typedef struct {
  Object output;
} Dict(cmd_opts);

typedef struct {
  Object verbose;
} Dict(echo_opts);

typedef struct {
  Object output;
} Dict(exec_opts);

#endif  // NVIM_API_KEYSETS_H
