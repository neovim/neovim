#pragma once

typedef struct vim_state VimState;

typedef int (*state_check_callback)(VimState *state);
typedef int (*state_execute_callback)(VimState *state, int key);

struct vim_state {
  state_check_callback check;
  state_execute_callback execute;
};

/// Values for State
///
/// The lower bits up to 0x80 are used to distinguish normal/visual/op_pending
/// /cmdline/insert/replace/terminal mode.  This is used for mapping.  If none
/// of these bits are set, no mapping is done.  See the comment above do_map().
/// The upper bits are used to distinguish between other states and variants of
/// the base modes.
enum {
  MODE_NORMAL      = 0x01,  ///< Normal mode, command expected
  MODE_VISUAL      = 0x02,  ///< Visual mode - use get_real_state()
  MODE_OP_PENDING  = 0x04,  ///< Normal mode, operator is pending - use get_real_state()
  MODE_CMDLINE     = 0x08,  ///< Editing the command line
  MODE_INSERT      = 0x10,  ///< Insert mode, also for Replace mode
  MODE_LANGMAP     = 0x20,  ///< Language mapping, can be combined with MODE_INSERT and MODE_CMDLINE
  MODE_SELECT      = 0x40,  ///< Select mode, use get_real_state()
  MODE_TERMINAL    = 0x80,  ///< Terminal mode

  MAP_ALL_MODES    = 0xff,  ///< all mode bits used for mapping

  REPLACE_FLAG     = 0x100,  ///< Replace mode flag
  MODE_REPLACE     = REPLACE_FLAG | MODE_INSERT,
  VREPLACE_FLAG    = 0x200,  ///< Virtual-replace mode flag
  MODE_VREPLACE    = REPLACE_FLAG | VREPLACE_FLAG | MODE_INSERT,
  MODE_LREPLACE    = REPLACE_FLAG | MODE_LANGMAP,

  MODE_NORMAL_BUSY = 0x1000 | MODE_NORMAL,  ///< Normal mode, busy with a command
  MODE_HITRETURN   = 0x2000 | MODE_NORMAL,  ///< waiting for return or command
  MODE_ASKMORE     = 0x3000,  ///< Asking if you want --more--
  MODE_SETWSIZE    = 0x4000,  ///< window size has changed
  MODE_EXTERNCMD   = 0x5000,  ///< executing an external command
  MODE_SHOWMATCH   = 0x6000 | MODE_INSERT,  ///< show matching paren
};
