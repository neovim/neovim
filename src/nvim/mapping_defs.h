#pragma once

#include <stdbool.h>

#include "nvim/eval/typval_defs.h"

enum { MAXMAPLEN = 50, };  ///< Maximum length of key sequence to be mapped.

/// Structure used for mappings and abbreviations.
typedef struct mapblock mapblock_T;
struct mapblock {
  mapblock_T *m_next;       ///< next mapblock in list
  mapblock_T *m_alt;        ///< pointer to mapblock of the same mapping
                            ///< with an alternative form of m_keys, or NULL
                            ///< if there is no such mapblock
  char *m_keys;             ///< mapped from, lhs
  char *m_str;              ///< mapped to, rhs
  char *m_orig_str;         ///< rhs as entered by the user
  LuaRef m_luaref;          ///< lua function reference as rhs
  int m_keylen;             ///< strlen(m_keys)
  int m_mode;               ///< valid mode
  int m_simplified;         ///< m_keys was simplified
  int m_noremap;            ///< if non-zero no re-mapping for m_str
  char m_silent;            ///< <silent> used, don't echo commands
  char m_nowait;            ///< <nowait> used
  char m_expr;              ///< <expr> used, m_str is an expression
  sctx_T m_script_ctx;      ///< SCTX where map was defined
  char *m_desc;             ///< description of mapping
  bool m_replace_keycodes;  ///< replace keycodes in result of expression
};
