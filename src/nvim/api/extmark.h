#pragma once

#include <stdint.h>  // IWYU pragma: keep

#include "nvim/api/keysets_defs.h"  // IWYU pragma: keep
#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/decoration_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/map_defs.h"
#include "nvim/types_defs.h"

EXTERN Map(String, int) namespace_ids INIT( = MAP_INIT);
EXTERN handle_T next_namespace_id INIT( = 1);

typedef struct {
  OptionalKeys is_set__set_extmark_;

  /// Id of the extmark to edit.
  Integer id;

  /// @deprecated
  Integer end_line;

  /// Ending line of the mark, 0-based inclusive.
  Integer end_row;

  /// Ending col of the mark, 0-based exclusive.
  Integer end_col;

  /// Name of the highlight group used to highlight this mark.
  HLGroupID hl_group;

  /// When true, for a multiline highlight covering the EOL of a line, continue
  /// the highlight for the rest of the screen line (just like for diff and
  /// cursorline highlight).
  Boolean hl_eol;

  /// Virtual text to link to this mark. A list of [text, highlight] tuples,
  /// each representing a text chunk with specified highlight. `highlight`
  /// element can either be a single highlight group, or an array of multiple
  /// highlight groups that will be stacked (highest priority last). A highlight
  /// group can be supplied either as a string or as an integer, the latter
  /// which can be obtained using |nvim_get_hl_id_by_name()|.
  Array virt_text;

  /// Position of virtual text. Possible values:
  /// - "eol": right after eol character (default).
  /// - "overlay": display over the specified column, without
  ///              shifting the underlying text.
  /// - "right_align": display right aligned in the window.
  /// - "inline": display at the specified column, and
  ///             shift the buffer text to the right as needed.
  String virt_text_pos;

  /// Position the virtual text at a fixed window column (starting from the
  /// first text column of the screen line) instead of "virt_text_pos".
  Integer virt_text_win_col;

  /// Hide the virtual text when the background text is selected or hidden
  /// because of scrolling with 'nowrap' or 'smoothscroll'. Currently only
  /// affects "overlay" virt_text.
  Boolean virt_text_hide;

  /// Repeat the virtual text on wrapped lines.
  Boolean virt_text_repeat_linebreak;

  /// Control how highlights are combined with the highlights of the text.
  /// Currently only affects virt_text highlights, but might affect `hl_group`
  /// in later versions.
  /// - "replace": only show the virt_text color. This is the default.
  /// - "combine": combine with background text color.
  /// - "blend": blend with background text color.
  ///            Not supported for "inline" virt_text.
  String hl_mode;

  /// Virtual lines to add next to this mark This should be an array over lines,
  /// where each line in turn is an array over [text, highlight] tuples. In
  /// general, buffer and window options do not affect the display of the text.
  /// In particular 'wrap' and 'linebreak' options do not take effect, so the
  /// number of extra screen lines will always match the size of the array.
  /// However the 'tabstop' buffer option is still used for hard tabs. By
  /// default lines are placed below the buffer line containing the mark.
  Array virt_lines;

  /// Place virtual lines above instead.
  Boolean virt_lines_above;

  /// Place extmarks in the leftmost column of the window, bypassing sign and
  /// number columns.
  Boolean virt_lines_leftcol;

  /// For use with |nvim_set_decoration_provider()| callbacks. The mark will
  /// only be used for the current redraw cycle, and not be permanently stored
  /// in the buffer.
  Boolean ephemeral;

  /// Indicates the direction the extmark will be shifted in when new text is
  /// inserted (true for right, false for left). Defaults to true.
  Boolean right_gravity;

  /// Indicates the direction the extmark end position (if it exists) will be
  /// shifted in when new text is inserted (true for right, false for left).
  /// (Default: `false`)
  Boolean end_right_gravity;

  /// Restore the exact position of the mark if text around the mark was deleted
  /// and then restored by undo.
  /// (Default: `true`)
  Boolean undo_restore;

  /// Indicates whether to hide the extmark if the entirety of its range is
  /// deleted. For hidden marks, an "invalid" key is added to the "details"
  /// array of |nvim_buf_get_extmarks()| and family. If "undo_restore" is false,
  /// the extmark is deleted instead.
  Boolean invalidate;

  /// A priority value for the highlight group, sign attribute or virtual text.
  /// For virtual text, item with highest priority is drawn last. For example
  /// treesitter highlighting uses a value of 100.
  Integer priority;

  /// Indicates extmark should not be placed if the line or column value is past
  /// the end of the buffer or end of the line respectively.
  /// (Default: `true`)
  Boolean strict;

  /// String of length 1-2 used to display in the sign column.
  String sign_text;

  /// sign_hl_group: name of the highlight group used to
  ///   highlight the sign column text.
  HLGroupID sign_hl_group;

  /// Name of the highlight group used to highlight the number column.
  HLGroupID number_hl_group;

  /// Name of the highlight group used to highlight the whole line.
  HLGroupID line_hl_group;

  /// Name of the highlight group used to highlight the sign column text when the
  /// cursor is on the same line as the mark and 'cursorline' is enabled.
  HLGroupID cursorline_hl_group;

  /// Should be either empty or a single character. Enable concealing similar to
  /// |:syn-conceal|. When a character is supplied it is used as |:syn-cchar|.
  /// "hl_group" is used as highlight for the cchar if provided, otherwise it
  /// defaults to |hl-Conceal|.
  String conceal;

  /// Indicates that spell checking should be performed within this extmark
  Boolean spell;

  /// Indicates the mark should be drawn
  /// by a UI. When set, the UI will receive win_extmark events.
  /// Note: the mark is positioned by virt_text attributes. Can be
  /// used together with virt_text.
  Boolean ui_watched;

  /// A URL to associate with this extmark. In the TUI, the OSC 8 control
  /// sequence is used to generate a clickable hyperlink to this URL.
  String url;

  /// Indicates that the extmark should only be displayed in the namespace
  /// scope.
  /// (experimental)
  Boolean scoped;

  Integer _subpriority;
} Dict(set_extmark);

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/extmark.h.generated.h"
#endif
