#ifndef NVIM_EX_DOCMD_H
#define NVIM_EX_DOCMD_H

#include "nvim/ex_cmds_defs.h"

/* flags for do_cmdline() */
#define DOCMD_VERBOSE   0x01    /* included command in error message */
#define DOCMD_NOWAIT    0x02    /* don't call wait_return() and friends */
#define DOCMD_REPEAT    0x04    /* repeat exec. until getline() returns NULL */
#define DOCMD_KEYTYPED  0x08    /* don't reset KeyTyped */
#define DOCMD_EXCRESET  0x10    /* reset exception environment (for debugging)*/
#define DOCMD_KEEPLINE  0x20    /* keep typed line for repeating with "." */

/* defines for eval_vars() */
#define VALID_PATH              1
#define VALID_HEAD              2

/* Values for exmode_active (0 is no exmode) */
#define EXMODE_NORMAL           1
#define EXMODE_VIM              2

/// The scope of a working-directory command like `:cd`.
///
/// Scopes are enumerated from lowest to highest. When adding a scope make sure
/// to update all functions using scopes as well, such as the implementation of
/// `getcwd()`. When using scopes as limits (e.g. in loops) don't use the scopes
/// directly, use `MIN_CD_SCOPE` and `MAX_CD_SCOPE` instead.
typedef enum {
  kCdScopeInvalid = -1,
  kCdScopeWindow,  ///< Affects one window.
  kCdScopeTab,     ///< Affects one tab page.
  kCdScopeGlobal,  ///< Affects the entire instance of Neovim.
} CdScope;
#define MIN_CD_SCOPE  kCdScopeWindow
#define MAX_CD_SCOPE  kCdScopeGlobal

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_docmd.h.generated.h"
#endif
#endif  // NVIM_EX_DOCMD_H
