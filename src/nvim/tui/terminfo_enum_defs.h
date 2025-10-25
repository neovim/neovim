// genenerated by src/gen/gen_terminfo.lua

#pragma once

typedef enum {
  kTerm_carriage_return,
  kTerm_change_scroll_region,
  kTerm_clear_screen,
  kTerm_clr_eol,
  kTerm_clr_eos,
  kTerm_cursor_address,
  kTerm_cursor_down,
  kTerm_cursor_invisible,
  kTerm_cursor_left,
  kTerm_cursor_home,
  kTerm_cursor_normal,
  kTerm_cursor_up,
  kTerm_cursor_right,
  kTerm_delete_line,
  kTerm_enter_bold_mode,
  kTerm_enter_ca_mode,
  kTerm_enter_italics_mode,
  kTerm_enter_reverse_mode,
  kTerm_enter_standout_mode,
  kTerm_enter_underline_mode,
  kTerm_erase_chars,
  kTerm_exit_attribute_mode,
  kTerm_exit_ca_mode,
  kTerm_from_status_line,
  kTerm_insert_line,
  kTerm_keypad_local,
  kTerm_keypad_xmit,
  kTerm_parm_delete_line,
  kTerm_parm_down_cursor,
  kTerm_parm_insert_line,
  kTerm_parm_left_cursor,
  kTerm_parm_right_cursor,
  kTerm_parm_up_cursor,
  kTerm_set_a_background,
  kTerm_set_a_foreground,
  kTerm_set_attributes,
  kTerm_set_lr_margin,
  kTerm_to_status_line,
#define kTermExtOffset kTerm_reset_cursor_style
  kTerm_reset_cursor_style,
  kTerm_set_cursor_style,
  kTerm_enter_strikethrough_mode,
  kTerm_set_rgb_foreground,
  kTerm_set_rgb_background,
  kTerm_set_cursor_color,
  kTerm_reset_cursor_color,
  kTerm_set_underline_style,
  kTermCount,  // sentinel
} TerminfoDef;

// TODO(bfredl): physical F-keys beyond F12 are uncommon. But terminfo
// likes to present chords with shift and/or ctrl and F keys as high
// F-key numbers. The same chords can also be recognized by driver-csi.c
// but will then be encoded as chords. We might actually prefer that but it is
// potentially breaking change.
#define kTerminfoFuncKeyMax 63
typedef enum {
  kTermKey_backspace,
  kTermKey_beg,
  kTermKey_btab,
  kTermKey_clear,
  kTermKey_dc,
  kTermKey_end,
  kTermKey_find,
  kTermKey_home,
  kTermKey_ic,
  kTermKey_left,
  kTermKey_npage,
  kTermKey_ppage,
  kTermKey_select,
  kTermKey_suspend,
  kTermKey_undo,
  kTermKeyCount,
} TerminfoKey;
