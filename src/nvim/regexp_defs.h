// NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE
//
// This is NOT the original regular expression code as written by Henry
// Spencer.  This code has been modified specifically for use with Vim, and
// should not be used apart from compiling Vim.  If you want a good regular
// expression library, get the original code.
//
// NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE NOTICE

#pragma once

#include <stdbool.h>
#include <stdint.h>

#include "nvim/pos_defs.h"
#include "nvim/types_defs.h"

enum {
  /// The number of sub-matches is limited to 10.
  /// The first one (index 0) is the whole match, referenced with "\0".
  /// The second one (index 1) is the first sub-match, referenced with "\1".
  /// This goes up to the tenth (index 9), referenced with "\9".
  NSUBEXP = 10,
};

typedef struct regengine regengine_T;

/// Structure to be used for multi-line matching.
/// Sub-match "no" starts in line "startpos[no].lnum" column "startpos[no].col"
/// and ends in line "endpos[no].lnum" just before column "endpos[no].col".
/// The line numbers are relative to the first line, thus startpos[0].lnum is
/// always 0.
/// When there is no match, the line number is -1.
typedef struct {
  regprog_T *regprog;
  lpos_T startpos[NSUBEXP];
  lpos_T endpos[NSUBEXP];

  colnr_T rmm_matchcol;  ///< match start without "\zs"
  int rmm_ic;
  colnr_T rmm_maxcol;  ///< when not zero: maximum column
} regmmatch_T;

/// Used for "magic_overruled".
typedef enum {
  OPTION_MAGIC_NOT_SET,  ///< p_magic not overruled
  OPTION_MAGIC_ON,       ///< magic on inside regexp
  OPTION_MAGIC_OFF,      ///< magic off inside regexp
} optmagic_T;

/// Magicness of a pattern, used by regexp code.
/// The order and values matter:
///  magic <= MAGIC_OFF includes MAGIC_NONE
///  magic >= MAGIC_ON  includes MAGIC_ALL
typedef enum {
  MAGIC_NONE = 1,  ///< "\V" very unmagic
  MAGIC_OFF = 2,   ///< "\M" or 'magic' off
  MAGIC_ON = 3,    ///< "\m" or 'magic'
  MAGIC_ALL = 4,   ///< "\v" very magic
} magic_T;

/// Structure to be used for single-line matching.
/// Sub-match "no" starts at "startp[no]" and ends just before "endp[no]".
/// When there is no match, the pointer is NULL.
typedef struct {
  regprog_T *regprog;
  char *startp[NSUBEXP];
  char *endp[NSUBEXP];

  colnr_T rm_matchcol;  ///< match start without "\zs"
  bool rm_ic;
} regmatch_T;

/// Structure used to store external references: "\z\(\)" to "\z\1".
/// Use a reference count to avoid the need to copy this around.  When it goes
/// from 1 to zero the matches need to be freed.
typedef struct {
  int16_t refcnt;
  uint8_t *matches[NSUBEXP];
} reg_extmatch_T;

/// Flags used by vim_regsub() and vim_regsub_both()
enum {
  REGSUB_COPY      = 1,
  REGSUB_MAGIC     = 2,
  REGSUB_BACKSLASH = 4,
};
