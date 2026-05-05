local M = {}

M.fields = {}
M.fields.bools = { 'back_color_erase', 'Tc', 'RGB', 'Su' }
M.fields.ints = { 'max_colors', 'lines', 'columns' }

M.builtin_terminals = {
  { 'ansi', 'ansi_terminfo' },
  { 'ghostty', 'ghostty_terminfo' }, -- Note: ncurses defs do not exactly match what ghostty ships.
  { 'interix', 'interix_8colour_terminfo' },
  { 'iterm2', 'iterm_256colour_terminfo' },
  { 'linux', 'linux_16colour_terminfo' },
  { 'putty-256color', 'putty_256colour_terminfo' },
  { 'rxvt-256color', 'rxvt_256colour_terminfo' },
  { 'screen-256color', 'screen_256colour_terminfo' },
  { 'st-256color', 'st_256colour_terminfo' },
  { 'tmux-256color', 'tmux_256colour_terminfo' },
  { 'vte-256color', 'vte_256colour_terminfo' },
  { 'xterm-256color', 'xterm_256colour_terminfo' },
  { 'cygwin', 'cygwin_terminfo' },
  { 'win32con', 'win32con_terminfo' },
  { 'conemu', 'conemu_terminfo' },
  { 'vtpcon', 'vtpcon_terminfo' },
}

M.fields.strings = {
  'carriage_return',
  'change_scroll_region',
  'clear_screen',
  'clr_eol',
  'clr_eos',
  'cursor_address',
  'cursor_down',
  'cursor_invisible',
  'cursor_left',
  'cursor_home',
  'cursor_normal',
  'cursor_up',
  'cursor_right',
  'delete_line',
  'enter_blink_mode',
  'enter_bold_mode',
  'enter_ca_mode',
  'enter_dim_mode',
  'enter_italics_mode',
  'enter_reverse_mode',
  'enter_secure_mode',
  'enter_standout_mode',
  'enter_underline_mode',
  'erase_chars',
  'exit_attribute_mode',
  'exit_ca_mode',
  'from_status_line',
  'insert_line',
  'keypad_local',
  'keypad_xmit',
  'parm_delete_line',
  'parm_down_cursor',
  'parm_insert_line',
  'parm_left_cursor',
  'parm_right_cursor',
  'parm_up_cursor',
  'set_a_background',
  'set_a_foreground',
  'set_attributes',
  'set_lr_margin',
  'to_status_line',
}

M.fields.strings_ext = {
  -- the following are our custom name for extensions, see "extmap"
  { 'reset_cursor_style', 'Se' },
  { 'set_cursor_style', 'Ss' },
  -- terminfo describes strikethrough modes as rmxx/smxx with respect
  -- to the ECMA-48 strikeout/crossed-out attributes.
  { 'enter_strikethrough_mode', 'smxx' },
  { 'set_rgb_foreground', 'setrgbf' },
  { 'set_rgb_background', 'setrgbb' },
  { 'set_cursor_color', 'Cs' },
  { 'reset_cursor_color', 'Cr' },
  { 'set_underline_style', 'Smulx' },
}

-- Note: these are only consumed by driver-ti via it's table of "funcs" keys.
-- Second value is whether there is a "shift" variant in terminfo.
M.fields.termkeys = {
  { 'backspace', false },
  { 'beg', true }, -- sometimes known as: "begin"
  { 'btab', false },
  { 'clear', false },
  { 'dc', true },
  { 'end', true },
  { 'find', true },
  { 'home', true },
  { 'ic', true },
  { 'npage', false },
  { 'ppage', false },
  { 'select', false },
  { 'suspend', true },
  { 'undo', true },
  { 'left', true },
  { 'right', true },
}

M.fields.func_key_max = 63

return M
