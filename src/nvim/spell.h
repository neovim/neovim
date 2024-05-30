#pragma once

#include <stdbool.h>

#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/spell_defs.h"  // IWYU pragma: keep
#include "nvim/vim_defs.h"  // IWYU pragma: keep

/// First language that is loaded, start of the linked list of loaded languages.
extern slang_T *first_lang;

/// file used for "zG" and "zW"
extern char *int_wordlist;

extern spelltab_T spelltab;
extern bool did_set_spelltab;

extern char *e_format;

// Remember what "z?" replaced.
extern char *repl_from;
extern char *repl_to;

/// Values for behaviour in spell_move_to
typedef enum {
  SMT_ALL = 0,  ///< Move to "all" words
  SMT_BAD,      ///< Move to "bad" words only
  SMT_RARE,     ///< Move to "rare" words only
} smt_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "spell.h.generated.h"
#endif
