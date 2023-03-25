return {
  { 'context', {
    "types";
  }};
  { 'set_decoration_provider', {
    "on_start";
    "on_buf";
    "on_win";
    "on_line";
    "on_end";
    "_on_hl_def";
    "_on_spell_nav";
  }};
  { 'set_extmark', {
    "id";
    "end_line";
    "end_row";
    "end_col";
    "hl_group";
    "virt_text";
    "virt_text_pos";
    "virt_text_win_col";
    "virt_text_hide";
    "hl_eol";
    "hl_mode";
    "ephemeral";
    "priority";
    "right_gravity";
    "end_right_gravity";
    "virt_lines";
    "virt_lines_above";
    "virt_lines_leftcol";
    "strict";
    "sign_text";
    "sign_hl_group";
    "number_hl_group";
    "line_hl_group";
    "cursorline_hl_group";
    "conceal";
    "spell";
    "ui_watched";
  }};
  { 'keymap', {
    "noremap";
    "nowait";
    "silent";
    "script";
    "expr";
    "unique";
    "callback";
    "desc";
    "replace_keycodes";
  }};
  { 'get_commands', {
    "builtin";
  }};
  { 'user_command', {
    "addr";
    "bang";
    "bar";
    "complete";
    "count";
    "desc";
    "force";
    "keepscript";
    "nargs";
    "preview";
    "range";
    "register";
  }};
  { 'float_config', {
    "row";
    "col";
    "width";
    "height";
    "anchor";
    "relative";
    "win";
    "bufpos";
    "external";
    "focusable";
    "zindex";
    "border";
    "title";
    "title_pos";
    "style";
    "noautocmd";
  }};
  { 'runtime', {
    "is_lua";
    "do_source";
  }};
  { 'eval_statusline', {
    "winid";
    "maxwidth";
    "fillchar";
    "highlights";
    "use_winbar";
    "use_tabline";
  }};
  { 'option', {
    "scope";
    "win";
    "buf";
    "filetype";
  }};
  { 'highlight', {
    "bold";
    "standout";
    "strikethrough";
    "underline";
    "undercurl";
    "underdouble";
    "underdotted";
    "underdashed";
    "italic";
    "reverse";
    "altfont";
    "nocombine";
    "default";
    "cterm";
    "foreground"; "fg";
    "background"; "bg";
    "ctermfg";
    "ctermbg";
    "special"; "sp";
    "link";
    "global_link";
    "fallback";
    "blend";
    "fg_indexed";
    "bg_indexed";
  }};
  { 'highlight_cterm', {
    "bold";
    "standout";
    "strikethrough";
    "underline";
    "undercurl";
    "underdouble";
    "underdotted";
    "underdashed";
    "italic";
    "reverse";
    "altfont";
    "nocombine";
  }};
  { 'get_highlight', {
    "id";
    "name";
    "link";
  }};
  -- Autocmds
  { 'clear_autocmds', {
    "buffer";
    "event";
    "group";
    "pattern";
  }};
  { 'create_autocmd', {
    "buffer";
    "callback";
    "command";
    "desc";
    "group";
    "nested";
    "once";
    "pattern";
  }};
  { 'exec_autocmds', {
    "buffer";
    "group";
    "modeline";
    "pattern";
    "data";
  }};
  { 'get_autocmds', {
    "event";
    "group";
    "pattern";
    "buffer";
  }};
  { 'create_augroup', {
    "clear";
  }};
  { 'cmd', {
    "cmd";
    "range";
    "count";
    "reg";
    "bang";
    "args";
    "magic";
    "mods";
    "nargs";
    "addr";
    "nextcmd";
  }};
  { 'cmd_magic', {
    "file";
    "bar";
  }};
  { 'cmd_mods', {
    "silent";
    "emsg_silent";
    "unsilent";
    "filter";
    "sandbox";
    "noautocmd";
    "browse";
    "confirm";
    "hide";
    "horizontal";
    "keepalt";
    "keepjumps";
    "keepmarks";
    "keeppatterns";
    "lockmarks";
    "noswapfile";
    "tab";
    "verbose";
    "vertical";
    "split";
  }};
  { 'cmd_mods_filter', {
    "pattern";
    "force";
  }};
  { 'cmd_opts', {
    "output";
  }};
  { 'echo_opts', {
    "verbose";
  }};
  { 'exec_opts', {
    "output";
  }};
}
