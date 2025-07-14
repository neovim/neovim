#pragma once

#include <stdbool.h>
#include <stddef.h>

#include "nvim/eval/typval_defs.h"
#include "nvim/pos_defs.h"
#include "nvim/vim_defs.h"

typedef enum {
  XP_PREFIX_NONE,  ///< prefix not used
  XP_PREFIX_NO,    ///< "no" prefix for bool option
  XP_PREFIX_INV,   ///< "inv" prefix for bool option
} xp_prefix_T;

enum { EXPAND_BUF_LEN = 256, };

/// used for completion on the command line
typedef struct {
  char *xp_pattern;             ///< start of item to expand, guaranteed
                                ///< to be part of xp_line
  int xp_context;               ///< type of expansion
  size_t xp_pattern_len;        ///< bytes in xp_pattern before cursor
  xp_prefix_T xp_prefix;
  char *xp_arg;                 ///< completion function
  LuaRef xp_luaref;             ///< Ref to Lua completion function
  sctx_T xp_script_ctx;         ///< SCTX for completion function
  int xp_backslash;             ///< one of the XP_BS_ values
#ifndef BACKSLASH_IN_FILENAME
  bool xp_shell;                ///< true for a shell command, more
                                ///< characters need to be escaped
#endif
  int xp_numfiles;              ///< number of files found by file name completion
  int xp_col;                   ///< cursor position in line
  int xp_selected;              ///< selected index in completion
  char *xp_orig;                ///< originally expanded string
  char **xp_files;              ///< list of files
  char *xp_line;                ///< text being completed
  char xp_buf[EXPAND_BUF_LEN];  ///< buffer for returned match
  Direction xp_search_dir;      ///< Direction of search
  pos_T xp_pre_incsearch_pos;   ///< Cursor position before incsearch
} expand_T;

/// values for xp_backslash
enum {
  XP_BS_NONE  = 0,    ///< nothing special for backslashes
  XP_BS_ONE   = 0x1,  ///< uses one backslash before a space
  XP_BS_THREE = 0x2,  ///< uses three backslashes before a space
  XP_BS_COMMA = 0x4,  ///< commas need to be escaped with a backslash
};

/// values for xp_context when doing command line completion
enum {
  EXPAND_UNSUCCESSFUL = -2,
  EXPAND_OK = -1,
  EXPAND_NOTHING = 0,
  EXPAND_COMMANDS,
  EXPAND_FILES,
  EXPAND_DIRECTORIES,
  EXPAND_SETTINGS,
  EXPAND_BOOL_SETTINGS,
  EXPAND_TAGS,
  EXPAND_OLD_SETTING,
  EXPAND_HELP,
  EXPAND_BUFFERS,
  EXPAND_EVENTS,
  EXPAND_MENUS,
  EXPAND_SYNTAX,
  EXPAND_HIGHLIGHT,
  EXPAND_AUGROUP,
  EXPAND_USER_VARS,
  EXPAND_MAPPINGS,
  EXPAND_TAGS_LISTFILES,
  EXPAND_FUNCTIONS,
  EXPAND_USER_FUNC,
  EXPAND_EXPRESSION,
  EXPAND_MENUNAMES,
  EXPAND_USER_COMMANDS,
  EXPAND_USER_CMD_FLAGS,
  EXPAND_USER_NARGS,
  EXPAND_USER_COMPLETE,
  EXPAND_ENV_VARS,
  EXPAND_LANGUAGE,
  EXPAND_COLORS,
  EXPAND_COMPILER,
  EXPAND_USER_DEFINED,
  EXPAND_USER_LIST,
  EXPAND_USER_LUA,
  EXPAND_SHELLCMD,
  EXPAND_SIGN,
  EXPAND_PROFILE,
  EXPAND_FILETYPE,
  EXPAND_FILES_IN_PATH,
  EXPAND_OWNSYNTAX,
  EXPAND_LOCALES,
  EXPAND_HISTORY,
  EXPAND_USER,
  EXPAND_SYNTIME,
  EXPAND_USER_ADDR_TYPE,
  EXPAND_PACKADD,
  EXPAND_MESSAGES,
  EXPAND_MAPCLEAR,
  EXPAND_ARGLIST,
  EXPAND_DIFF_BUFFERS,
  EXPAND_BREAKPOINT,
  EXPAND_SCRIPTNAMES,
  EXPAND_RUNTIME,
  EXPAND_STRING_SETTING,
  EXPAND_SETTING_SUBTRACT,
  EXPAND_ARGOPT,
  EXPAND_KEYMAP,
  EXPAND_DIRS_IN_CDPATH,
  EXPAND_SHELLCMDLINE,
  EXPAND_FINDFUNC,
  EXPAND_FILETYPECMD,
  EXPAND_PATTERN_IN_BUF,
  EXPAND_RETAB,
  EXPAND_CHECKHEALTH,
  EXPAND_LUA,
};

/// Type used by ExpandGeneric()
typedef char *(*CompleteListItemGetter)(expand_T *, int);
