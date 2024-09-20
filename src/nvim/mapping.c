// mapping.c: Code for mappings and abbreviations.

#include <assert.h>
#include <lauxlib.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_session.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/getchar.h"
#include "nvim/getchar_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/keycodes.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/mapping.h"
#include "nvim/mapping_defs.h"
#include "nvim/mbyte.h"
#include "nvim/mbyte_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/pos_defs.h"
#include "nvim/regexp.h"
#include "nvim/regexp_defs.h"
#include "nvim/runtime.h"
#include "nvim/search.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_defs.h"
#include "nvim/vim_defs.h"

/// List used for abbreviations.
static mapblock_T *first_abbr = NULL;  // first entry in abbrlist

// Each mapping is put in one of the MAX_MAPHASH hash lists,
// to speed up finding it.
static mapblock_T *(maphash[MAX_MAPHASH]) = { 0 };

// Make a hash value for a mapping.
// "mode" is the lower 4 bits of the State for the mapping.
// "c1" is the first character of the "lhs".
// Returns a value between 0 and 255, index in maphash.
// Put Normal/Visual mode mappings mostly separately from Insert/Cmdline mode.
#define MAP_HASH(mode, \
                 c1) (((mode) & \
                       (MODE_NORMAL | MODE_VISUAL | MODE_SELECT | \
                        MODE_OP_PENDING | MODE_TERMINAL)) ? (c1) : ((c1) ^ 0x80))

/// All possible |:map-arguments| usable in a |:map| command.
///
/// The <special> argument has no effect on mappings and is excluded from this
/// struct declaration. |:noremap| is included, since it behaves like a map
/// argument when used in a mapping.
///
/// @see mapblock_T
struct map_arguments {
  bool buffer;
  bool expr;
  bool noremap;
  bool nowait;
  bool script;
  bool silent;
  bool unique;
  bool replace_keycodes;

  /// The {lhs} of the mapping.
  ///
  /// vim limits this to MAXMAPLEN characters, allowing us to use a static
  /// buffer. Setting lhs_len to a value larger than MAXMAPLEN can signal
  /// that {lhs} was too long and truncated.
  char lhs[MAXMAPLEN + 1];
  size_t lhs_len;

  /// Unsimplifed {lhs} of the mapping. If no simplification has been done then alt_lhs_len is 0.
  char alt_lhs[MAXMAPLEN + 1];
  size_t alt_lhs_len;

  char *rhs;  /// The {rhs} of the mapping.
  size_t rhs_len;
  LuaRef rhs_lua;  /// lua function as {rhs}
  bool rhs_is_noop;  /// True when the {rhs} should be <Nop>.

  char *orig_rhs;  /// The original text of the {rhs}.
  size_t orig_rhs_len;
  char *desc;  /// map description
};
typedef struct map_arguments MapArguments;
#define MAP_ARGUMENTS_INIT { false, false, false, false, false, false, false, false, \
                             { 0 }, 0, { 0 }, 0, NULL, 0, LUA_NOREF, false, NULL, 0, NULL }

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mapping.c.generated.h"
#endif

static const char e_global_abbreviation_already_exists_for_str[]
  = N_("E224: Global abbreviation already exists for %s");
static const char e_global_mapping_already_exists_for_str[]
  = N_("E225: Global mapping already exists for %s");
static const char e_abbreviation_already_exists_for_str[]
  = N_("E226: Abbreviation already exists for %s");
static const char e_mapping_already_exists_for_str[]
  = N_("E227: Mapping already exists for %s");
static const char e_entries_missing_in_mapset_dict_argument[]
  = N_("E460: Entries missing in mapset() dict argument");
static const char e_illegal_map_mode_string_str[]
  = N_("E1276: Illegal map mode string: '%s'");

/// Get the start of the hashed map list for "state" and first character "c".
mapblock_T *get_maphash_list(int state, int c)
{
  return maphash[MAP_HASH(state, c)];
}

/// Get the buffer-local hashed map list for "state" and first character "c".
mapblock_T *get_buf_maphash_list(int state, int c)
{
  return curbuf->b_maphash[MAP_HASH(state, c)];
}

/// Delete one entry from the abbrlist or maphash[].
/// "mpp" is a pointer to the m_next field of the PREVIOUS entry!
static void mapblock_free(mapblock_T **mpp)
{
  mapblock_T *mp = *mpp;
  xfree(mp->m_keys);
  if (mp->m_alt != NULL) {
    mp->m_alt->m_alt = NULL;
  } else {
    NLUA_CLEAR_REF(mp->m_luaref);
    xfree(mp->m_str);
    xfree(mp->m_orig_str);
    xfree(mp->m_desc);
  }
  *mpp = mp->m_next;
  xfree(mp);
}

/// put characters to represent the map mode in a string buffer
///
/// @param[out] buf must be at least 7 bytes (including NUL)
void map_mode_to_chars(int mode, char *buf)
  FUNC_ATTR_NONNULL_ALL
{
  char *p = buf;
  if ((mode & (MODE_INSERT | MODE_CMDLINE)) == (MODE_INSERT | MODE_CMDLINE)) {
    *p++ = '!';                           // :map!
  } else if (mode & MODE_INSERT) {
    *p++ = 'i';                           // :imap
  } else if (mode & MODE_LANGMAP) {
    *p++ = 'l';                           // :lmap
  } else if (mode & MODE_CMDLINE) {
    *p++ = 'c';                           // :cmap
  } else if ((mode & (MODE_NORMAL | MODE_VISUAL | MODE_SELECT | MODE_OP_PENDING))
             == (MODE_NORMAL | MODE_VISUAL | MODE_SELECT | MODE_OP_PENDING)) {
    *p++ = ' ';                           // :map
  } else {
    if (mode & MODE_NORMAL) {
      *p++ = 'n';                         // :nmap
    }
    if (mode & MODE_OP_PENDING) {
      *p++ = 'o';                         // :omap
    }
    if (mode & MODE_TERMINAL) {
      *p++ = 't';                         // :tmap
    }
    if ((mode & (MODE_VISUAL | MODE_SELECT)) == (MODE_VISUAL | MODE_SELECT)) {
      *p++ = 'v';                         // :vmap
    } else {
      if (mode & MODE_VISUAL) {
        *p++ = 'x';                       // :xmap
      }
      if (mode & MODE_SELECT) {
        *p++ = 's';                       // :smap
      }
    }
  }

  *p = NUL;
}

/// @param local  true for buffer-local map
static void showmap(mapblock_T *mp, bool local)
{
  if (message_filtered(mp->m_keys) && message_filtered(mp->m_str)
      && (mp->m_desc == NULL || message_filtered(mp->m_desc))) {
    return;
  }

  // When ext_messages is active, msg_didout is never set.
  if (msg_didout || msg_silent != 0 || ui_has(kUIMessages)) {
    msg_putchar('\n');
    if (got_int) {          // 'q' typed at MORE prompt
      return;
    }
  }

  char mapchars[7];
  map_mode_to_chars(mp->m_mode, mapchars);
  msg_puts(mapchars);
  size_t len = strlen(mapchars);

  while (++len <= 3) {
    msg_putchar(' ');
  }

  // Display the LHS.  Get length of what we write.
  len = (size_t)msg_outtrans_special(mp->m_keys, true, 0);
  do {
    msg_putchar(' ');                   // pad with blanks
    len++;
  } while (len < 12);

  if (mp->m_noremap == REMAP_NONE) {
    msg_puts_attr("*", HL_ATTR(HLF_8));
  } else if (mp->m_noremap == REMAP_SCRIPT) {
    msg_puts_attr("&", HL_ATTR(HLF_8));
  } else {
    msg_putchar(' ');
  }

  if (local) {
    msg_putchar('@');
  } else {
    msg_putchar(' ');
  }

  // Use false below if we only want things like <Up> to show up as such on
  // the rhs, and not M-x etc, true gets both -- webb
  if (mp->m_luaref != LUA_NOREF) {
    char *str = nlua_funcref_str(mp->m_luaref, NULL);
    msg_puts_attr(str, HL_ATTR(HLF_8));
    xfree(str);
  } else if (mp->m_str[0] == NUL) {
    msg_puts_attr("<Nop>", HL_ATTR(HLF_8));
  } else {
    msg_outtrans_special(mp->m_str, false, 0);
  }

  if (mp->m_desc != NULL) {
    msg_puts("\n                 ");  // Shift line to same level as rhs.
    msg_puts(mp->m_desc);
  }
  if (p_verbose > 0) {
    last_set_msg(mp->m_script_ctx);
  }
  msg_clr_eos();
}

/// Replace termcodes in the given LHS and RHS and store the results into the
/// `lhs` and `rhs` of the given @ref MapArguments struct.
///
/// `rhs` and `orig_rhs` will both point to new allocated buffers. `orig_rhs`
/// will hold a copy of the given `orig_rhs`.
///
/// The `*_len` variables will be set appropriately. If the length of
/// the final `lhs` exceeds `MAXMAPLEN`, `lhs_len` will be set equal to the
/// original larger length and `lhs` will be truncated.
///
/// If RHS should be <Nop>, `rhs` will be an empty string, `rhs_len` will be
/// zero, and `rhs_is_noop` will be set to true.
///
/// Any memory allocated by @ref replace_termcodes is freed before this function
/// returns.
///
/// @param[in] orig_lhs   Original mapping LHS, with characters to replace.
/// @param[in] orig_lhs_len   `strlen` of orig_lhs.
/// @param[in] orig_rhs   Original mapping RHS, with characters to replace.
/// @param[in] rhs_lua   Lua reference for Lua mappings.
/// @param[in] orig_rhs_len   `strlen` of orig_rhs.
/// @param[in] cpo_val  See param docs for @ref replace_termcodes.
/// @param[out] mapargs   MapArguments struct holding the replaced strings.
static bool set_maparg_lhs_rhs(const char *const orig_lhs, const size_t orig_lhs_len,
                               const char *const orig_rhs, const size_t orig_rhs_len,
                               const LuaRef rhs_lua, const char *const cpo_val,
                               MapArguments *const mapargs)
{
  char lhs_buf[128];

  // If mapping has been given as ^V<C_UP> say, then replace the term codes
  // with the appropriate two bytes. If it is a shifted special key, unshift
  // it too, giving another two bytes.
  //
  // replace_termcodes() may move the result to allocated memory, which
  // needs to be freed later (*lhs_buf and *rhs_buf).
  // replace_termcodes() also removes CTRL-Vs and sometimes backslashes.
  // If something like <C-H> is simplified to 0x08 then mark it as simplified
  // and also add en entry with a modifier.
  bool did_simplify = false;
  const int flags = REPTERM_FROM_PART | REPTERM_DO_LT;
  char *bufarg = lhs_buf;
  char *replaced = replace_termcodes(orig_lhs, orig_lhs_len, &bufarg, 0,
                                     flags, &did_simplify, cpo_val);
  if (replaced == NULL) {
    return false;
  }
  mapargs->lhs_len = strlen(replaced);
  xstrlcpy(mapargs->lhs, replaced, sizeof(mapargs->lhs));
  if (did_simplify) {
    replaced = replace_termcodes(orig_lhs, orig_lhs_len, &bufarg, 0,
                                 flags | REPTERM_NO_SIMPLIFY, NULL, cpo_val);
    if (replaced == NULL) {
      return false;
    }
    mapargs->alt_lhs_len = strlen(replaced);
    xstrlcpy(mapargs->alt_lhs, replaced, sizeof(mapargs->alt_lhs));
  } else {
    mapargs->alt_lhs_len = 0;
  }

  set_maparg_rhs(orig_rhs, orig_rhs_len, rhs_lua, 0, cpo_val, mapargs);

  return true;
}

/// @see set_maparg_lhs_rhs
static void set_maparg_rhs(const char *const orig_rhs, const size_t orig_rhs_len,
                           const LuaRef rhs_lua, const scid_T sid, const char *const cpo_val,
                           MapArguments *const mapargs)
{
  mapargs->rhs_lua = rhs_lua;

  if (rhs_lua == LUA_NOREF) {
    mapargs->orig_rhs_len = orig_rhs_len;
    mapargs->orig_rhs = xcalloc(mapargs->orig_rhs_len + 1, sizeof(char));
    xmemcpyz(mapargs->orig_rhs, orig_rhs, mapargs->orig_rhs_len);
    if (STRICMP(orig_rhs, "<nop>") == 0) {  // "<Nop>" means nothing
      mapargs->rhs = xcalloc(1, sizeof(char));  // single NUL-char
      mapargs->rhs_len = 0;
      mapargs->rhs_is_noop = true;
    } else {
      char *rhs_buf = NULL;
      char *replaced = replace_termcodes(orig_rhs, orig_rhs_len, &rhs_buf, sid,
                                         REPTERM_DO_LT, NULL, cpo_val);
      mapargs->rhs_len = strlen(replaced);
      // NB: replace_termcodes may produce an empty string even if orig_rhs is non-empty
      // (e.g. a single ^V, see :h map-empty-rhs)
      mapargs->rhs_is_noop = orig_rhs_len != 0 && mapargs->rhs_len == 0;
      mapargs->rhs = replaced;
    }
  } else {
    char tmp_buf[64];
    // orig_rhs is not used for Lua mappings, but still needs to be a string.
    mapargs->orig_rhs = xcalloc(1, sizeof(char));
    mapargs->orig_rhs_len = 0;
    // stores <lua>ref_no<cr> in map_str
    mapargs->rhs_len = (size_t)vim_snprintf(S_LEN(tmp_buf), "%c%c%c%d\r", K_SPECIAL,
                                            KS_EXTRA, KE_LUA, rhs_lua);
    mapargs->rhs = xstrdup(tmp_buf);
  }
}

/// Parse a string of |:map-arguments| into a @ref MapArguments struct.
///
/// Termcodes, backslashes, CTRL-V's, etc. inside the extracted {lhs} and
/// {rhs} are replaced by @ref set_maparg_lhs_rhs.
///
/// rhs and orig_rhs in the returned mapargs will be set to null or a pointer
/// to allocated memory and should be freed even on error.
///
/// @param[in]  strargs   String of map args, e.g. "<buffer> <expr><silent>".
///                       May contain leading or trailing whitespace.
/// @param[in]  is_unmap  True, if strargs should be parsed like an |:unmap|
///                       command. |:unmap| commands interpret *all* text to the
///                       right of the last map argument as the {lhs} of the
///                       mapping, i.e. a literal ' ' character is treated like
///                       a "<space>", rather than separating the {lhs} from the
///                       {rhs}.
/// @param[out] mapargs   MapArguments struct holding all extracted argument
///                       values.
/// @return 0 on success, 1 if invalid arguments are detected.
static int str_to_mapargs(const char *strargs, bool is_unmap, MapArguments *mapargs)
{
  const char *to_parse = strargs;
  to_parse = skipwhite(to_parse);
  CLEAR_POINTER(mapargs);

  // Accept <buffer>, <nowait>, <silent>, <expr>, <script>, and <unique> in
  // any order.
  while (true) {
    if (strncmp(to_parse, "<buffer>", 8) == 0) {
      to_parse = skipwhite(to_parse + 8);
      mapargs->buffer = true;
      continue;
    }

    if (strncmp(to_parse, "<nowait>", 8) == 0) {
      to_parse = skipwhite(to_parse + 8);
      mapargs->nowait = true;
      continue;
    }

    if (strncmp(to_parse, "<silent>", 8) == 0) {
      to_parse = skipwhite(to_parse + 8);
      mapargs->silent = true;
      continue;
    }

    // Ignore obsolete "<special>" modifier.
    if (strncmp(to_parse, "<special>", 9) == 0) {
      to_parse = skipwhite(to_parse + 9);
      continue;
    }

    if (strncmp(to_parse, "<script>", 8) == 0) {
      to_parse = skipwhite(to_parse + 8);
      mapargs->script = true;
      continue;
    }

    if (strncmp(to_parse, "<expr>", 6) == 0) {
      to_parse = skipwhite(to_parse + 6);
      mapargs->expr = true;
      continue;
    }

    if (strncmp(to_parse, "<unique>", 8) == 0) {
      to_parse = skipwhite(to_parse + 8);
      mapargs->unique = true;
      continue;
    }
    break;
  }

  // Find the next whitespace character, call that the end of {lhs}.
  //
  // If a character (e.g. whitespace) is immediately preceded by a CTRL-V,
  // "scan past" that character, i.e. don't "terminate" LHS with that character
  // if it's whitespace.
  //
  // Treat backslash like CTRL-V when 'cpoptions' does not contain 'B'.
  //
  // With :unmap, literal white space is included in the {lhs}; there is no
  // separate {rhs}.
  const char *lhs_end = to_parse;
  bool do_backslash = (vim_strchr(p_cpo, CPO_BSLASH) == NULL);
  while (*lhs_end && (is_unmap || !ascii_iswhite(*lhs_end))) {
    if ((lhs_end[0] == Ctrl_V || (do_backslash && lhs_end[0] == '\\'))
        && lhs_end[1] != NUL) {
      lhs_end++;  // skip CTRL-V or backslash
    }
    lhs_end++;
  }

  // {lhs_end} is a pointer to the "terminating whitespace" after {lhs}.
  // Use that to initialize {rhs_start}.
  const char *rhs_start = skipwhite(lhs_end);

  // Given {lhs} might be larger than MAXMAPLEN before replace_termcodes
  // (e.g. "<Space>" is longer than ' '), so first copy into a buffer.
  size_t orig_lhs_len = (size_t)(lhs_end - to_parse);
  if (orig_lhs_len >= 256) {
    return 1;
  }
  char lhs_to_replace[256];
  xmemcpyz(lhs_to_replace, to_parse, orig_lhs_len);

  size_t orig_rhs_len = strlen(rhs_start);
  if (!set_maparg_lhs_rhs(lhs_to_replace, orig_lhs_len,
                          rhs_start, orig_rhs_len, LUA_NOREF,
                          p_cpo, mapargs)) {
    return 1;
  }

  if (mapargs->lhs_len > MAXMAPLEN) {
    return 1;
  }
  return 0;
}

/// @param args  "rhs", "rhs_lua", "orig_rhs", "expr", "silent", "nowait",
///              "replace_keycodes" and "desc" fields are used.
/// @param sid  0 to use current_sctx
static mapblock_T *map_add(buf_T *buf, mapblock_T **map_table, mapblock_T **abbr_table,
                           const char *keys, MapArguments *args, int noremap, int mode,
                           bool is_abbr, scid_T sid, linenr_T lnum, bool simplified)
  FUNC_ATTR_NONNULL_RET
{
  mapblock_T *mp = xcalloc(1, sizeof(mapblock_T));

  // If CTRL-C has been mapped, don't always use it for Interrupting.
  if (*keys == Ctrl_C) {
    if (map_table == buf->b_maphash) {
      buf->b_mapped_ctrl_c |= mode;
    } else {
      mapped_ctrl_c |= mode;
    }
  }

  mp->m_keys = xstrdup(keys);
  mp->m_str = args->rhs;
  mp->m_orig_str = args->orig_rhs;
  mp->m_luaref = args->rhs_lua;
  mp->m_keylen = (int)strlen(mp->m_keys);
  mp->m_noremap = noremap;
  mp->m_nowait = args->nowait;
  mp->m_silent = args->silent;
  mp->m_mode = mode;
  mp->m_simplified = simplified;
  mp->m_expr = args->expr;
  mp->m_replace_keycodes = args->replace_keycodes;
  if (sid != 0) {
    mp->m_script_ctx.sc_sid = sid;
    mp->m_script_ctx.sc_lnum = lnum;
  } else {
    mp->m_script_ctx = current_sctx;
    mp->m_script_ctx.sc_lnum += SOURCING_LNUM;
    nlua_set_sctx(&mp->m_script_ctx);
  }
  mp->m_desc = args->desc;

  // add the new entry in front of the abbrlist or maphash[] list
  if (is_abbr) {
    mp->m_next = *abbr_table;
    *abbr_table = mp;
  } else {
    const int n = MAP_HASH(mp->m_mode, (uint8_t)mp->m_keys[0]);
    mp->m_next = map_table[n];
    map_table[n] = mp;
  }
  return mp;
}

/// Sets or removes a mapping or abbreviation in buffer `buf`.
///
/// @param maptype    @see do_map
/// @param args  Fully parsed and "preprocessed" arguments for the
///              (un)map/abbrev command. Termcodes should have already been
///              replaced; whitespace, `<` and `>` signs, etc. in {lhs} and
///              {rhs} are assumed to be literal components of the mapping.
/// @param mode       @see do_map
/// @param is_abbrev  @see do_map
/// @param buf        Target Buffer
static int buf_do_map(int maptype, MapArguments *args, int mode, bool is_abbrev, buf_T *buf)
{
  int retval = 0;

  // If <buffer> was given, we'll be searching through the buffer's
  // mappings/abbreviations, not the globals.
  mapblock_T **map_table = args->buffer ? buf->b_maphash : maphash;
  mapblock_T **abbr_table = args->buffer ? &buf->b_first_abbr : &first_abbr;
  mapblock_T *mp_result[2] = { NULL, NULL };

  // For ":noremap" don't remap, otherwise do remap.
  int noremap = args->script ? REMAP_SCRIPT
                             : maptype == MAPTYPE_NOREMAP ? REMAP_NONE : REMAP_YES;

  const bool has_lhs = (args->lhs[0] != NUL);
  const bool has_rhs = args->rhs_lua != LUA_NOREF || (args->rhs[0] != NUL) || args->rhs_is_noop;
  const bool do_print = !has_lhs || (maptype != MAPTYPE_UNMAP && !has_rhs);

  // check for :unmap without argument
  if (maptype == MAPTYPE_UNMAP && !has_lhs) {
    retval = 1;
    goto theend;
  }

  const char *lhs = (char *)&args->lhs;
  const bool did_simplify = args->alt_lhs_len != 0;

  // The following is done twice if we have two versions of keys
  for (int keyround = 1; keyround <= 2; keyround++) {
    bool did_it = false;
    bool did_local = false;
    bool keyround1_simplified = keyround == 1 && did_simplify;
    int len = (int)args->lhs_len;

    if (keyround == 2) {
      if (!did_simplify) {
        break;
      }
      lhs = (char *)&args->alt_lhs;
      len = (int)args->alt_lhs_len;
    } else if (did_simplify && do_print) {
      // when printing always use the not-simplified map
      lhs = (char *)&args->alt_lhs;
      len = (int)args->alt_lhs_len;
    }

    // check arguments and translate function keys
    if (has_lhs) {
      if (len > MAXMAPLEN) {
        retval = 1;
        goto theend;
      }

      if (is_abbrev && maptype != MAPTYPE_UNMAP) {
        // If an abbreviation ends in a keyword character, the
        // rest must be all keyword-char or all non-keyword-char.
        // Otherwise we won't be able to find the start of it in a
        // vi-compatible way.
        int same = -1;

        const int first = vim_iswordp(lhs);
        int last = first;
        const char *p = lhs + utfc_ptr2len(lhs);
        int n = 1;
        while (p < lhs + len) {
          n++;                                  // nr of (multi-byte) chars
          last = vim_iswordp(p);                // type of last char
          if (same == -1 && last != first) {
            same = n - 1;                       // count of same char type
          }
          p += utfc_ptr2len(p);
        }
        if (last && n > 2 && same >= 0 && same < n - 1) {
          retval = 1;
          goto theend;
        }
        // An abbreviation cannot contain white space.
        for (n = 0; n < len; n++) {
          if (ascii_iswhite(lhs[n])) {
            retval = 1;
            goto theend;
          }
        }  // for
      }
    }

    if (has_lhs && has_rhs && is_abbrev) {  // if we will add an abbreviation,
      no_abbr = false;  // reset flag that indicates there are no abbreviations
    }

    if (do_print) {
      msg_start();
    }

    // Check if a new local mapping wasn't already defined globally.
    if (args->unique && map_table == buf->b_maphash && has_lhs && has_rhs
        && maptype != MAPTYPE_UNMAP) {
      // need to loop over all global hash lists
      for (int hash = 0; hash < 256 && !got_int; hash++) {
        mapblock_T *mp;
        if (is_abbrev) {
          if (hash != 0) {  // there is only one abbreviation list
            break;
          }
          mp = first_abbr;
        } else {
          mp = maphash[hash];
        }
        for (; mp != NULL && !got_int; mp = mp->m_next) {
          // check entries with the same mode
          if ((mp->m_mode & mode) != 0
              && mp->m_keylen == len
              && strncmp(mp->m_keys, lhs, (size_t)len) == 0) {
            if (is_abbrev) {
              semsg(_(e_global_abbreviation_already_exists_for_str), mp->m_keys);
            } else {
              semsg(_(e_global_mapping_already_exists_for_str), mp->m_keys);
            }
            retval = 5;
            goto theend;
          }
        }
      }
    }

    // When listing global mappings, also list buffer-local ones here.
    if (map_table != buf->b_maphash && !has_rhs && maptype != MAPTYPE_UNMAP) {
      // need to loop over all global hash lists
      for (int hash = 0; hash < 256 && !got_int; hash++) {
        mapblock_T *mp;
        if (is_abbrev) {
          if (hash != 0) {  // there is only one abbreviation list
            break;
          }
          mp = buf->b_first_abbr;
        } else {
          mp = buf->b_maphash[hash];
        }
        for (; mp != NULL && !got_int; mp = mp->m_next) {
          // check entries with the same mode
          if (!mp->m_simplified && (mp->m_mode & mode) != 0) {
            if (!has_lhs) {  // show all entries
              showmap(mp, true);
              did_local = true;
            } else {
              int n = mp->m_keylen;
              if (strncmp(mp->m_keys, lhs, (size_t)(n < len ? n : len)) == 0) {
                showmap(mp, true);
                did_local = true;
              }
            }
          }
        }
      }
    }

    // Find an entry in the maphash[] list that matches.
    // For :unmap we may loop two times: once to try to unmap an entry with a
    // matching 'from' part, a second time, if the first fails, to unmap an
    // entry with a matching 'to' part. This was done to allow ":ab foo bar"
    // to be unmapped by typing ":unab foo", where "foo" will be replaced by
    // "bar" because of the abbreviation.
    for (int round = 0; (round == 0 || maptype == MAPTYPE_UNMAP) && round <= 1
         && !did_it && !got_int; round++) {
      int hash_start, hash_end;
      if ((round == 0 && has_lhs) || is_abbrev) {
        // just use one hash
        hash_start = is_abbrev ? 0 : MAP_HASH(mode, (uint8_t)lhs[0]);
        hash_end = hash_start + 1;
      } else {
        // need to loop over all hash lists
        hash_start = 0;
        hash_end = 256;
      }
      for (int hash = hash_start; hash < hash_end && !got_int; hash++) {
        mapblock_T **mpp = is_abbrev ? abbr_table : &(map_table[hash]);
        for (mapblock_T *mp = *mpp; mp != NULL && !got_int; mp = *mpp) {
          if ((mp->m_mode & mode) == 0) {
            // skip entries with wrong mode
            mpp = &(mp->m_next);
            continue;
          }
          if (!has_lhs) {                      // show all entries
            if (!mp->m_simplified) {
              showmap(mp, map_table != maphash);
              did_it = true;
            }
          } else {                          // do we have a match?
            int n;
            const char *p;
            if (round) {              // second round: Try unmap "rhs" string
              n = (int)strlen(mp->m_str);
              p = mp->m_str;
            } else {
              n = mp->m_keylen;
              p = mp->m_keys;
            }
            if (strncmp(p, lhs, (size_t)(n < len ? n : len)) == 0) {
              if (maptype == MAPTYPE_UNMAP) {
                // Delete entry.
                // Only accept a full match.  For abbreviations
                // we ignore trailing space when matching with
                // the "lhs", since an abbreviation can't have
                // trailing space.
                if (n != len && (!is_abbrev || round || n > len || *skipwhite(lhs + n) != NUL)) {
                  mpp = &(mp->m_next);
                  continue;
                }
                // In keyround for simplified keys, don't unmap
                // a mapping without m_simplified flag.
                if (keyround1_simplified && !mp->m_simplified) {
                  break;
                }
                // We reset the indicated mode bits. If nothing
                // is left the entry is deleted below.
                mp->m_mode &= ~mode;
                did_it = true;  // remember we did something
              } else if (!has_rhs) {  // show matching entry
                if (!mp->m_simplified) {
                  showmap(mp, map_table != maphash);
                  did_it = true;
                }
              } else if (n != len) {  // new entry is ambiguous
                mpp = &(mp->m_next);
                continue;
              } else if (keyround1_simplified && !mp->m_simplified) {
                // In keyround for simplified keys, don't replace
                // a mapping without m_simplified flag.
                did_it = true;
                break;
              } else if (args->unique) {
                if (is_abbrev) {
                  semsg(_(e_abbreviation_already_exists_for_str), p);
                } else {
                  semsg(_(e_mapping_already_exists_for_str), p);
                }
                retval = 5;
                goto theend;
              } else {
                // new rhs for existing entry
                mp->m_mode &= ~mode;  // remove mode bits
                if (mp->m_mode == 0 && !did_it) {  // reuse entry
                  if (mp->m_alt != NULL) {
                    mp->m_alt = mp->m_alt->m_alt = NULL;
                  } else {
                    NLUA_CLEAR_REF(mp->m_luaref);
                    xfree(mp->m_str);
                    xfree(mp->m_orig_str);
                    xfree(mp->m_desc);
                  }
                  mp->m_str = args->rhs;
                  mp->m_orig_str = args->orig_rhs;
                  mp->m_luaref = args->rhs_lua;
                  mp->m_noremap = noremap;
                  mp->m_nowait = args->nowait;
                  mp->m_silent = args->silent;
                  mp->m_mode = mode;
                  mp->m_simplified = keyround1_simplified;
                  mp->m_expr = args->expr;
                  mp->m_replace_keycodes = args->replace_keycodes;
                  mp->m_script_ctx = current_sctx;
                  mp->m_script_ctx.sc_lnum += SOURCING_LNUM;
                  nlua_set_sctx(&mp->m_script_ctx);
                  mp->m_desc = args->desc;
                  mp_result[keyround - 1] = mp;
                  did_it = true;
                }
              }
              if (mp->m_mode == 0) {  // entry can be deleted
                mapblock_free(mpp);
                continue;  // continue with *mpp
              }

              // May need to put this entry into another hash list.
              int new_hash = MAP_HASH(mp->m_mode, (uint8_t)mp->m_keys[0]);
              if (!is_abbrev && new_hash != hash) {
                *mpp = mp->m_next;
                mp->m_next = map_table[new_hash];
                map_table[new_hash] = mp;

                continue;  // continue with *mpp
              }
            }
          }
          mpp = &(mp->m_next);
        }
      }
    }

    if (maptype == MAPTYPE_UNMAP) {
      // delete entry
      if (!did_it) {
        if (!keyround1_simplified) {
          retval = 2;  // no match
        }
      } else if (*lhs == Ctrl_C) {
        // If CTRL-C has been unmapped, reuse it for Interrupting.
        if (map_table == buf->b_maphash) {
          buf->b_mapped_ctrl_c &= ~mode;
        } else {
          mapped_ctrl_c &= ~mode;
        }
      }
      continue;
    }

    if (!has_lhs || !has_rhs) {
      // print entries
      if (!did_it && !did_local) {
        if (is_abbrev) {
          msg(_("No abbreviation found"), 0);
        } else {
          msg(_("No mapping found"), 0);
        }
      }
      goto theend;  // listing finished
    }

    if (did_it) {
      continue;  // have added the new entry already
    }

    // Get here when adding a new entry to the maphash[] list or abbrlist.
    mp_result[keyround - 1] = map_add(buf, map_table, abbr_table, lhs,
                                      args, noremap, mode, is_abbrev,
                                      0,  // sid
                                      0,  // lnum
                                      keyround1_simplified);
  }

  if (mp_result[0] != NULL && mp_result[1] != NULL) {
    mp_result[0]->m_alt = mp_result[1];
    mp_result[1]->m_alt = mp_result[0];
  }

theend:
  if (mp_result[0] != NULL || mp_result[1] != NULL) {
    args->rhs = NULL;
    args->orig_rhs = NULL;
    args->rhs_lua = LUA_NOREF;
    args->desc = NULL;
  }
  return retval;
}

/// Set or remove a mapping or an abbreviation in the current buffer, OR
/// display (matching) mappings/abbreviations.
///
/// ```vim
/// map[!]                          " show all key mappings
/// map[!] {lhs}                    " show key mapping for {lhs}
/// map[!] {lhs} {rhs}              " set key mapping for {lhs} to {rhs}
/// noremap[!] {lhs} {rhs}          " same, but no remapping for {rhs}
/// unmap[!] {lhs}                  " remove key mapping for {lhs}
/// abbr                            " show all abbreviations
/// abbr {lhs}                      " show abbreviations for {lhs}
/// abbr {lhs} {rhs}                " set abbreviation for {lhs} to {rhs}
/// noreabbr {lhs} {rhs}            " same, but no remapping for {rhs}
/// unabbr {lhs}                    " remove abbreviation for {lhs}
///
/// for :map   mode is MODE_NORMAL | MODE_VISUAL | MODE_SELECT | MODE_OP_PENDING
/// for :map!  mode is MODE_INSERT | MODE_CMDLINE
/// for :cmap  mode is MODE_CMDLINE
/// for :imap  mode is MODE_INSERT
/// for :lmap  mode is MODE_LANGMAP
/// for :nmap  mode is MODE_NORMAL
/// for :vmap  mode is MODE_VISUAL | MODE_SELECT
/// for :xmap  mode is MODE_VISUAL
/// for :smap  mode is MODE_SELECT
/// for :omap  mode is MODE_OP_PENDING
/// for :tmap  mode is MODE_TERMINAL
///
/// for :abbr  mode is MODE_INSERT | MODE_CMDLINE
/// for :iabbr mode is MODE_INSERT
/// for :cabbr mode is MODE_CMDLINE
/// ```
///
/// @param maptype  MAPTYPE_MAP for |:map|
///                 MAPTYPE_UNMAP for |:unmap|
///                 MAPTYPE_NOREMAP for |:noremap|.
/// @param arg      C-string containing the arguments of the map/abbrev
///                 command, i.e. everything except the initial `:[X][nore]map`.
///                 - Cannot be a read-only string; it will be modified.
/// @param mode   Bitflags representing the mode in which to set the mapping.
///               See @ref get_map_mode.
/// @param is_abbrev  True if setting an abbreviation, false otherwise.
///
/// @return 0 on success. On failure, will return one of the following:
///         - 1 for invalid arguments
///         - 2 for no match
///         - 4 for out of mem (deprecated, WON'T HAPPEN)
///         - 5 for entry not unique
///
int do_map(int maptype, char *arg, int mode, bool is_abbrev)
{
  MapArguments parsed_args;
  int result = str_to_mapargs(arg, maptype == MAPTYPE_UNMAP, &parsed_args);
  switch (result) {
  case 0:
    break;
  case 1:
    // invalid arguments
    goto free_and_return;
  default:
    assert(false && "Unknown return code from str_to_mapargs!");
    result = -1;
    goto free_and_return;
  }  // switch

  result = buf_do_map(maptype, &parsed_args, mode, is_abbrev, curbuf);

free_and_return:
  xfree(parsed_args.rhs);
  xfree(parsed_args.orig_rhs);
  return result;
}

/// Get the mapping mode from the command name.
static int get_map_mode(char **cmdp, bool forceit)
{
  int mode;

  char *p = *cmdp;
  int modec = (uint8_t)(*p++);
  if (modec == 'i') {
    mode = MODE_INSERT;                                                  // :imap
  } else if (modec == 'l') {
    mode = MODE_LANGMAP;                                                 // :lmap
  } else if (modec == 'c') {
    mode = MODE_CMDLINE;                                                 // :cmap
  } else if (modec == 'n' && *p != 'o') {  // avoid :noremap
    mode = MODE_NORMAL;                                                  // :nmap
  } else if (modec == 'v') {
    mode = MODE_VISUAL | MODE_SELECT;                                    // :vmap
  } else if (modec == 'x') {
    mode = MODE_VISUAL;                                                  // :xmap
  } else if (modec == 's') {
    mode = MODE_SELECT;                                                  // :smap
  } else if (modec == 'o') {
    mode = MODE_OP_PENDING;                                              // :omap
  } else if (modec == 't') {
    mode = MODE_TERMINAL;                                                // :tmap
  } else {
    p--;
    if (forceit) {
      mode = MODE_INSERT | MODE_CMDLINE;                                 // :map !
    } else {
      mode = MODE_VISUAL | MODE_SELECT | MODE_NORMAL | MODE_OP_PENDING;  // :map
    }
  }

  *cmdp = p;
  return mode;
}

/// Clear all mappings (":mapclear") or abbreviations (":abclear").
/// "abbr" should be false for mappings, true for abbreviations.
/// This function used to be called map_clear().
static void do_mapclear(char *cmdp, char *arg, int forceit, int abbr)
{
  bool local = strcmp(arg, "<buffer>") == 0;
  if (!local && *arg != NUL) {
    emsg(_(e_invarg));
    return;
  }

  int mode = get_map_mode(&cmdp, forceit);
  map_clear_mode(curbuf, mode, local, abbr);
}

/// Clear all mappings in "mode".
///
/// @param buf,  buffer for local mappings
/// @param mode  mode in which to delete
/// @param local  true for buffer-local mappings
/// @param abbr  true for abbreviations
void map_clear_mode(buf_T *buf, int mode, bool local, bool abbr)
{
  for (int hash = 0; hash < 256; hash++) {
    mapblock_T **mpp;
    if (abbr) {
      if (hash > 0) {           // there is only one abbrlist
        break;
      }
      if (local) {
        mpp = &buf->b_first_abbr;
      } else {
        mpp = &first_abbr;
      }
    } else {
      if (local) {
        mpp = &buf->b_maphash[hash];
      } else {
        mpp = &maphash[hash];
      }
    }
    while (*mpp != NULL) {
      mapblock_T *mp = *mpp;
      if (mp->m_mode & mode) {
        mp->m_mode &= ~mode;
        if (mp->m_mode == 0) {       // entry can be deleted
          mapblock_free(mpp);
          continue;
        }
        // May need to put this entry into another hash list.
        int new_hash = MAP_HASH(mp->m_mode, (uint8_t)mp->m_keys[0]);
        if (!abbr && new_hash != hash) {
          *mpp = mp->m_next;
          if (local) {
            mp->m_next = buf->b_maphash[new_hash];
            buf->b_maphash[new_hash] = mp;
          } else {
            mp->m_next = maphash[new_hash];
            maphash[new_hash] = mp;
          }
          continue;                     // continue with *mpp
        }
      }
      mpp = &(mp->m_next);
    }
  }
}

/// Check if a map exists that has given string in the rhs
///
/// Also checks mappings local to the current buffer.
///
/// @param[in]  str  String which mapping must have in the rhs. Termcap codes
///                  are recognized in this argument.
/// @param[in]  modechars  Mode(s) in which mappings are checked.
/// @param[in]  abbr  true if checking abbreviations in place of mappings.
///
/// @return true if there is at least one mapping with given parameters.
bool map_to_exists(const char *const str, const char *const modechars, const bool abbr)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
{
  int mode = 0;

  char *buf = NULL;
  const char *const rhs = replace_termcodes(str, strlen(str), &buf, 0,
                                            REPTERM_DO_LT, NULL, p_cpo);

#define MAPMODE(mode, modechars, chr, modeflags) \
  do { \
    if (strchr(modechars, chr) != NULL) { \
      (mode) |= (modeflags); \
    } \
  } while (0)
  MAPMODE(mode, modechars, 'n', MODE_NORMAL);
  MAPMODE(mode, modechars, 'v', MODE_VISUAL | MODE_SELECT);
  MAPMODE(mode, modechars, 'x', MODE_VISUAL);
  MAPMODE(mode, modechars, 's', MODE_SELECT);
  MAPMODE(mode, modechars, 'o', MODE_OP_PENDING);
  MAPMODE(mode, modechars, 'i', MODE_INSERT);
  MAPMODE(mode, modechars, 'l', MODE_LANGMAP);
  MAPMODE(mode, modechars, 'c', MODE_CMDLINE);
#undef MAPMODE

  bool retval = map_to_exists_mode(rhs, mode, abbr);
  xfree(buf);

  return retval;
}

/// Check if a map exists that has given string in the rhs
///
/// Also checks mappings local to the current buffer.
///
/// @param[in]  rhs  String which mapping must have in the rhs. Termcap codes
///                  are recognized in this argument.
/// @param[in]  mode  Mode(s) in which mappings are checked.
/// @param[in]  abbr  true if checking abbreviations in place of mappings.
///
/// @return true if there is at least one mapping with given parameters.
bool map_to_exists_mode(const char *const rhs, const int mode, const bool abbr)
{
  bool exp_buffer = false;

  // Do it twice: once for global maps and once for local maps.
  while (true) {
    for (int hash = 0; hash < 256; hash++) {
      mapblock_T *mp;
      if (abbr) {
        if (hash > 0) {  // There is only one abbr list.
          break;
        }
        if (exp_buffer) {
          mp = curbuf->b_first_abbr;
        } else {
          mp = first_abbr;
        }
      } else if (exp_buffer) {
        mp = curbuf->b_maphash[hash];
      } else {
        mp = maphash[hash];
      }
      for (; mp; mp = mp->m_next) {
        if ((mp->m_mode & mode) && strstr(mp->m_str, rhs) != NULL) {
          return true;
        }
      }
    }
    if (exp_buffer) {
      break;
    }
    exp_buffer = true;
  }

  return false;
}

/// Used below when expanding mapping/abbreviation names.
static int expand_mapmodes = 0;
static bool expand_isabbrev = false;
static bool expand_buffer = false;

/// Translate an internal mapping/abbreviation representation into the
/// corresponding external one recognized by :map/:abbrev commands.
///
/// This function is called when expanding mappings/abbreviations on the
/// command-line.
///
/// It uses a growarray to build the translation string since the latter can be
/// wider than the original description. The caller has to free the string
/// afterwards.
///
/// @param[in] cpo_val  See param docs for @ref replace_termcodes.
///
/// @return  NULL when there is a problem.
static char *translate_mapping(const char *const str_in, const char *const cpo_val)
{
  const uint8_t *str = (const uint8_t *)str_in;
  garray_T ga;
  ga_init(&ga, 1, 40);

  const bool cpo_bslash = (vim_strchr(cpo_val, CPO_BSLASH) != NULL);

  for (; *str; str++) {
    int c = *str;
    if (c == K_SPECIAL && str[1] != NUL && str[2] != NUL) {
      int modifiers = 0;
      if (str[1] == KS_MODIFIER) {
        str++;
        modifiers = *++str;
        c = *++str;
      }

      if (c == K_SPECIAL && str[1] != NUL && str[2] != NUL) {
        c = TO_SPECIAL(str[1], str[2]);
        if (c == K_ZERO) {
          // display <Nul> as ^@
          c = NUL;
        }
        str += 2;
      }
      if (IS_SPECIAL(c) || modifiers) {         // special key
        ga_concat(&ga, get_special_key_name(c, modifiers));
        continue;         // for (str)
      }
    }

    if (c == ' ' || c == '\t' || c == Ctrl_J || c == Ctrl_V
        || c == '<' || (c == '\\' && !cpo_bslash)) {
      ga_append(&ga, cpo_bslash ? Ctrl_V : '\\');
    }

    if (c) {
      ga_append(&ga, (uint8_t)c);
    }
  }
  ga_append(&ga, NUL);
  return (char *)ga.ga_data;
}

/// Work out what to complete when doing command line completion of mapping
/// or abbreviation names.
///
/// @param forceit  true if '!' given
/// @param isabbrev  true if abbreviation
/// @param isunmap  true if unmap/unabbrev command
char *set_context_in_map_cmd(expand_T *xp, char *cmd, char *arg, bool forceit, bool isabbrev,
                             bool isunmap, cmdidx_T cmdidx)
{
  if (forceit && cmdidx != CMD_map && cmdidx != CMD_unmap) {
    xp->xp_context = EXPAND_NOTHING;
  } else {
    if (isunmap) {
      expand_mapmodes = get_map_mode(&cmd, forceit || isabbrev);
    } else {
      expand_mapmodes = MODE_INSERT | MODE_CMDLINE;
      if (!isabbrev) {
        expand_mapmodes |= MODE_VISUAL | MODE_SELECT | MODE_NORMAL | MODE_OP_PENDING;
      }
    }
    expand_isabbrev = isabbrev;
    xp->xp_context = EXPAND_MAPPINGS;
    expand_buffer = false;
    while (true) {
      if (strncmp(arg, "<buffer>", 8) == 0) {
        expand_buffer = true;
        arg = skipwhite(arg + 8);
        continue;
      }
      if (strncmp(arg, "<unique>", 8) == 0) {
        arg = skipwhite(arg + 8);
        continue;
      }
      if (strncmp(arg, "<nowait>", 8) == 0) {
        arg = skipwhite(arg + 8);
        continue;
      }
      if (strncmp(arg, "<silent>", 8) == 0) {
        arg = skipwhite(arg + 8);
        continue;
      }
      if (strncmp(arg, "<special>", 9) == 0) {
        arg = skipwhite(arg + 9);
        continue;
      }
      if (strncmp(arg, "<script>", 8) == 0) {
        arg = skipwhite(arg + 8);
        continue;
      }
      if (strncmp(arg, "<expr>", 6) == 0) {
        arg = skipwhite(arg + 6);
        continue;
      }
      break;
    }
    xp->xp_pattern = arg;
  }

  return NULL;
}

/// Find all mapping/abbreviation names that match regexp "regmatch".
/// For command line expansion of ":[un]map" and ":[un]abbrev" in all modes.
/// @return OK if matches found, FAIL otherwise.
int ExpandMappings(char *pat, regmatch_T *regmatch, int *numMatches, char ***matches)
{
  const bool fuzzy = cmdline_fuzzy_complete(pat);

  *numMatches = 0;                    // return values in case of FAIL
  *matches = NULL;

  garray_T ga;
  if (!fuzzy) {
    ga_init(&ga, sizeof(char *), 3);
  } else {
    ga_init(&ga, sizeof(fuzmatch_str_T), 3);
  }

  // First search in map modifier arguments
  for (int i = 0; i < 7; i++) {
    char *p;
    if (i == 0) {
      p = "<silent>";
    } else if (i == 1) {
      p = "<unique>";
    } else if (i == 2) {
      p = "<script>";
    } else if (i == 3) {
      p = "<expr>";
    } else if (i == 4 && !expand_buffer) {
      p = "<buffer>";
    } else if (i == 5) {
      p = "<nowait>";
    } else if (i == 6) {
      p = "<special>";
    } else {
      continue;
    }

    bool match;
    int score = 0;
    if (!fuzzy) {
      match = vim_regexec(regmatch, p, 0);
    } else {
      score = fuzzy_match_str(p, pat);
      match = (score != 0);
    }

    if (!match) {
      continue;
    }

    if (fuzzy) {
      GA_APPEND(fuzmatch_str_T, &ga, ((fuzmatch_str_T){
        .idx = ga.ga_len,
        .str = xstrdup(p),
        .score = score,
      }));
    } else {
      GA_APPEND(char *, &ga, xstrdup(p));
    }
  }

  for (int hash = 0; hash < 256; hash++) {
    mapblock_T *mp;
    if (expand_isabbrev) {
      if (hash > 0) {    // only one abbrev list
        break;  // for (hash)
      }
      mp = first_abbr;
    } else if (expand_buffer) {
      mp = curbuf->b_maphash[hash];
    } else {
      mp = maphash[hash];
    }
    for (; mp; mp = mp->m_next) {
      if (mp->m_simplified || !(mp->m_mode & expand_mapmodes)) {
        continue;
      }

      char *p = translate_mapping(mp->m_keys, p_cpo);
      if (p == NULL) {
        continue;
      }

      bool match;
      int score = 0;
      if (!fuzzy) {
        match = vim_regexec(regmatch, p, 0);
      } else {
        score = fuzzy_match_str(p, pat);
        match = (score != 0);
      }

      if (!match) {
        xfree(p);
        continue;
      }

      if (fuzzy) {
        GA_APPEND(fuzmatch_str_T, &ga, ((fuzmatch_str_T){
          .idx = ga.ga_len,
          .str = p,
          .score = score,
        }));
      } else {
        GA_APPEND(char *, &ga, p);
      }
    }  // for (mp)
  }  // for (hash)

  if (ga.ga_len == 0) {
    return FAIL;
  }

  if (!fuzzy) {
    *matches = ga.ga_data;
    *numMatches = ga.ga_len;
  } else {
    fuzzymatches_to_strmatches(ga.ga_data, matches, ga.ga_len, false);
    *numMatches = ga.ga_len;
  }

  int count = *numMatches;
  if (count > 1) {
    // Sort the matches
    // Fuzzy matching already sorts the matches
    if (!fuzzy) {
      sort_strings(*matches, count);
    }

    // Remove multiple entries
    char **ptr1 = *matches;
    char **ptr2 = ptr1 + 1;
    char **ptr3 = ptr1 + count;

    while (ptr2 < ptr3) {
      if (strcmp(*ptr1, *ptr2) != 0) {
        *++ptr1 = *ptr2++;
      } else {
        xfree(*ptr2++);
        count--;
      }
    }
  }

  *numMatches = count;
  return count == 0 ? FAIL : OK;
}

// Check for an abbreviation.
// Cursor is at ptr[col].
// When inserting, mincol is where insert started.
// For the command line, mincol is what is to be skipped over.
// "c" is the character typed before check_abbr was called.  It may have
// ABBR_OFF added to avoid prepending a CTRL-V to it.
//
// Historic vi practice: The last character of an abbreviation must be an id
// character ([a-zA-Z0-9_]). The characters in front of it must be all id
// characters or all non-id characters. This allows for abbr. "#i" to
// "#include".
//
// Vim addition: Allow for abbreviations that end in a non-keyword character.
// Then there must be white space before the abbr.
//
// Return true if there is an abbreviation, false if not.
bool check_abbr(int c, char *ptr, int col, int mincol)
{
  uint8_t tb[MB_MAXBYTES + 4];
  int clen = 0;                 // length in characters

  if (typebuf.tb_no_abbr_cnt) {  // abbrev. are not recursive
    return false;
  }

  // no remapping implies no abbreviation, except for CTRL-]
  if (noremap_keys() && c != Ctrl_RSB) {
    return false;
  }

  // Check for word before the cursor: If it ends in a keyword char all
  // chars before it must be keyword chars or non-keyword chars, but not
  // white space. If it ends in a non-keyword char we accept any characters
  // before it except white space.
  if (col == 0) {  // cannot be an abbr.
    return false;
  }

  int scol;  // starting column of the abbr.

  {
    bool is_id = true;
    bool vim_abbr;
    char *p = mb_prevptr(ptr, ptr + col);
    if (!vim_iswordp(p)) {
      vim_abbr = true;    // Vim added abbr.
    } else {
      vim_abbr = false;   // vi compatible abbr.
      if (p > ptr) {
        is_id = vim_iswordp(mb_prevptr(ptr, p));
      }
    }
    clen = 1;
    while (p > ptr + mincol) {
      p = mb_prevptr(ptr, p);
      if (ascii_isspace(*p) || (!vim_abbr && is_id != vim_iswordp(p))) {
        p += utfc_ptr2len(p);
        break;
      }
      clen++;
    }
    scol = (int)(p - ptr);
  }

  if (scol < mincol) {
    scol = mincol;
  }
  if (scol < col) {             // there is a word in front of the cursor
    ptr += scol;
    int len = col - scol;
    mapblock_T *mp = curbuf->b_first_abbr;
    mapblock_T *mp2 = first_abbr;
    if (mp == NULL) {
      mp = mp2;
      mp2 = NULL;
    }
    for (; mp;
         mp->m_next == NULL ? (mp = mp2, mp2 = NULL)
                            : (mp = mp->m_next)) {
      int qlen = mp->m_keylen;
      char *q = mp->m_keys;

      if (strchr(mp->m_keys, K_SPECIAL) != NULL) {
        // Might have K_SPECIAL escaped mp->m_keys.
        q = xstrdup(mp->m_keys);
        vim_unescape_ks(q);
        qlen = (int)strlen(q);
      }
      // find entries with right mode and keys
      int match = (mp->m_mode & State)
                  && qlen == len
                  && !strncmp(q, ptr, (size_t)len);
      if (q != mp->m_keys) {
        xfree(q);
      }
      if (match) {
        break;
      }
    }
    if (mp != NULL) {
      // Found a match:
      // Insert the rest of the abbreviation in typebuf.tb_buf[].
      // This goes from end to start.
      //
      // Characters 0x000 - 0x100: normal chars, may need CTRL-V,
      // except K_SPECIAL: Becomes K_SPECIAL KS_SPECIAL KE_FILLER
      // Characters where IS_SPECIAL() == true: key codes, need
      // K_SPECIAL. Other characters (with ABBR_OFF): don't use CTRL-V.
      //
      // Character CTRL-] is treated specially - it completes the
      // abbreviation, but is not inserted into the input stream.
      int j = 0;
      if (c != Ctrl_RSB) {
        // special key code, split up
        if (IS_SPECIAL(c) || c == K_SPECIAL) {
          tb[j++] = K_SPECIAL;
          tb[j++] = (uint8_t)K_SECOND(c);
          tb[j++] = (uint8_t)K_THIRD(c);
        } else {
          if (c < ABBR_OFF && (c < ' ' || c > '~')) {
            tb[j++] = Ctrl_V;                   // special char needs CTRL-V
          }
          // if ABBR_OFF has been added, remove it here.
          if (c >= ABBR_OFF) {
            c -= ABBR_OFF;
          }
          int newlen = utf_char2bytes(c, (char *)tb + j);
          tb[j + newlen] = NUL;
          // Need to escape K_SPECIAL.
          char *escaped = vim_strsave_escape_ks((char *)tb + j);
          if (escaped != NULL) {
            newlen = (int)strlen(escaped);
            memmove(tb + j, escaped, (size_t)newlen);
            j += newlen;
            xfree(escaped);
          }
        }
        tb[j] = NUL;
        // insert the last typed char
        ins_typebuf((char *)tb, 1, 0, true, mp->m_silent);
      }

      // copy values here, calling eval_map_expr() may make "mp" invalid!
      const int noremap = mp->m_noremap;
      const bool silent = mp->m_silent;
      const bool expr = mp->m_expr;

      char *s;
      if (expr) {
        s = eval_map_expr(mp, c);
      } else {
        s = mp->m_str;
      }
      if (s != NULL) {
        // insert the to string
        ins_typebuf(s, noremap, 0, true, silent);
        // no abbrev. for these chars
        typebuf.tb_no_abbr_cnt += (int)strlen(s) + j + 1;
        if (expr) {
          xfree(s);
        }
      }

      tb[0] = Ctrl_H;
      tb[1] = NUL;
      len = clen;  // Delete characters instead of bytes
      while (len-- > 0) {  // delete the from string
        ins_typebuf((char *)tb, 1, 0, true, silent);
      }
      return true;
    }
  }
  return false;
}

/// Evaluate the RHS of a mapping or abbreviations and take care of escaping
/// special characters.
/// Careful: after this "mp" will be invalid if the mapping was deleted.
///
/// @param c  NUL or typed character for abbreviation
char *eval_map_expr(mapblock_T *mp, int c)
{
  char *p = NULL;
  char *expr = NULL;

  // Remove escaping of K_SPECIAL, because "str" is in a format to be used as
  // typeahead.
  if (mp->m_luaref == LUA_NOREF) {
    expr = xstrdup(mp->m_str);
    vim_unescape_ks(expr);
  }

  const bool replace_keycodes = mp->m_replace_keycodes;

  // Forbid changing text or using ":normal" to avoid most of the bad side
  // effects.  Also restore the cursor position.
  expr_map_lock++;
  set_vim_var_char(c);    // set v:char to the typed character
  const pos_T save_cursor = curwin->w_cursor;
  const int save_msg_col = msg_col;
  const int save_msg_row = msg_row;
  if (mp->m_luaref != LUA_NOREF) {
    Error err = ERROR_INIT;
    Array args = ARRAY_DICT_INIT;
    Object ret = nlua_call_ref(mp->m_luaref, NULL, args, kRetObject, NULL, &err);
    if (ret.type == kObjectTypeString) {
      p = string_to_cstr(ret.data.string);
    }
    api_free_object(ret);
    if (err.type != kErrorTypeNone) {
      semsg_multiline("E5108: %s", err.msg);
      api_clear_error(&err);
    }
  } else {
    p = eval_to_string(expr, false, false);
    xfree(expr);
  }
  expr_map_lock--;
  curwin->w_cursor = save_cursor;
  msg_col = save_msg_col;
  msg_row = save_msg_row;

  if (p == NULL) {
    return NULL;
  }

  char *res = NULL;

  if (replace_keycodes) {
    replace_termcodes(p, strlen(p), &res, 0, REPTERM_DO_LT, NULL, p_cpo);
  } else {
    // Escape K_SPECIAL in the result to be able to use the string as typeahead.
    res = vim_strsave_escape_ks(p);
  }
  xfree(p);

  return res;
}

/// Write map commands for the current mappings to an .exrc file.
/// Return FAIL on error, OK otherwise.
///
/// @param buf  buffer for local mappings or NULL
int makemap(FILE *fd, buf_T *buf)
{
  bool did_cpo = false;

  // Do the loop twice: Once for mappings, once for abbreviations.
  // Then loop over all map hash lists.
  for (int abbr = 0; abbr < 2; abbr++) {
    for (int hash = 0; hash < 256; hash++) {
      mapblock_T *mp;
      if (abbr) {
        if (hash > 0) {                 // there is only one abbr list
          break;
        }
        if (buf != NULL) {
          mp = buf->b_first_abbr;
        } else {
          mp = first_abbr;
        }
      } else {
        if (buf != NULL) {
          mp = buf->b_maphash[hash];
        } else {
          mp = maphash[hash];
        }
      }

      for (; mp; mp = mp->m_next) {
        // skip script-local mappings
        if (mp->m_noremap == REMAP_SCRIPT) {
          continue;
        }

        // skip Lua mappings and mappings that contain a <SNR> (script-local thing),
        // they probably don't work when loaded again
        if (mp->m_luaref != LUA_NOREF) {
          continue;
        }
        char *p;
        for (p = mp->m_str; *p != NUL; p++) {
          if ((uint8_t)p[0] == K_SPECIAL && (uint8_t)p[1] == KS_EXTRA
              && p[2] == KE_SNR) {
            break;
          }
        }
        if (*p != NUL) {
          continue;
        }

        // It's possible to create a mapping and then ":unmap" certain
        // modes.  We recreate this here by mapping the individual
        // modes, which requires up to three of them.
        char c1 = NUL;
        char c2 = NUL;
        char c3 = NUL;
        char *cmd = abbr ? "abbr" : "map";
        switch (mp->m_mode) {
        case MODE_NORMAL | MODE_VISUAL | MODE_SELECT | MODE_OP_PENDING:
          break;
        case MODE_NORMAL:
          c1 = 'n';
          break;
        case MODE_VISUAL:
          c1 = 'x';
          break;
        case MODE_SELECT:
          c1 = 's';
          break;
        case MODE_OP_PENDING:
          c1 = 'o';
          break;
        case MODE_NORMAL | MODE_VISUAL:
          c1 = 'n';
          c2 = 'x';
          break;
        case MODE_NORMAL | MODE_SELECT:
          c1 = 'n';
          c2 = 's';
          break;
        case MODE_NORMAL | MODE_OP_PENDING:
          c1 = 'n';
          c2 = 'o';
          break;
        case MODE_VISUAL | MODE_SELECT:
          c1 = 'v';
          break;
        case MODE_VISUAL | MODE_OP_PENDING:
          c1 = 'x';
          c2 = 'o';
          break;
        case MODE_SELECT | MODE_OP_PENDING:
          c1 = 's';
          c2 = 'o';
          break;
        case MODE_NORMAL | MODE_VISUAL | MODE_SELECT:
          c1 = 'n';
          c2 = 'v';
          break;
        case MODE_NORMAL | MODE_VISUAL | MODE_OP_PENDING:
          c1 = 'n';
          c2 = 'x';
          c3 = 'o';
          break;
        case MODE_NORMAL | MODE_SELECT | MODE_OP_PENDING:
          c1 = 'n';
          c2 = 's';
          c3 = 'o';
          break;
        case MODE_VISUAL | MODE_SELECT | MODE_OP_PENDING:
          c1 = 'v';
          c2 = 'o';
          break;
        case MODE_CMDLINE | MODE_INSERT:
          if (!abbr) {
            cmd = "map!";
          }
          break;
        case MODE_CMDLINE:
          c1 = 'c';
          break;
        case MODE_INSERT:
          c1 = 'i';
          break;
        case MODE_LANGMAP:
          c1 = 'l';
          break;
        case MODE_TERMINAL:
          c1 = 't';
          break;
        default:
          iemsg(_("E228: makemap: Illegal mode"));
          return FAIL;
        }
        do {  // do this twice if c2 is set, 3 times with c3
          // When outputting <> form, need to make sure that 'cpo'
          // is set to the Vim default.
          if (!did_cpo) {
            if (*mp->m_str == NUL) {  // Will use <Nop>.
              did_cpo = true;
            } else {
              const char specials[] = { (char)(uint8_t)K_SPECIAL, NL, NUL };
              if (strpbrk(mp->m_str, specials) != NULL || strpbrk(mp->m_keys, specials) != NULL) {
                did_cpo = true;
              }
            }
            if (did_cpo) {
              if (fprintf(fd, "let s:cpo_save=&cpo") < 0
                  || put_eol(fd) < 0
                  || fprintf(fd, "set cpo&vim") < 0
                  || put_eol(fd) < 0) {
                return FAIL;
              }
            }
          }
          if (c1 && putc(c1, fd) < 0) {
            return FAIL;
          }
          if (mp->m_noremap != REMAP_YES && fprintf(fd, "nore") < 0) {
            return FAIL;
          }
          if (fputs(cmd, fd) < 0) {
            return FAIL;
          }
          if (buf != NULL && fputs(" <buffer>", fd) < 0) {
            return FAIL;
          }
          if (mp->m_nowait && fputs(" <nowait>", fd) < 0) {
            return FAIL;
          }
          if (mp->m_silent && fputs(" <silent>", fd) < 0) {
            return FAIL;
          }
          if (mp->m_expr && fputs(" <expr>", fd) < 0) {
            return FAIL;
          }

          if (putc(' ', fd) < 0
              || put_escstr(fd, mp->m_keys, 0) == FAIL
              || putc(' ', fd) < 0
              || put_escstr(fd, mp->m_str, 1) == FAIL
              || put_eol(fd) < 0) {
            return FAIL;
          }
          c1 = c2;
          c2 = c3;
          c3 = NUL;
        } while (c1 != NUL);
      }
    }
  }
  if (did_cpo) {
    if (fprintf(fd, "let &cpo=s:cpo_save") < 0
        || put_eol(fd) < 0
        || fprintf(fd, "unlet s:cpo_save") < 0
        || put_eol(fd) < 0) {
      return FAIL;
    }
  }
  return OK;
}

// write escape string to file
// "what": 0 for :map lhs, 1 for :map rhs, 2 for :set
//
// return FAIL for failure, OK otherwise
int put_escstr(FILE *fd, char *strstart, int what)
{
  uint8_t *str = (uint8_t *)strstart;

  // :map xx <Nop>
  if (*str == NUL && what == 1) {
    if (fprintf(fd, "<Nop>") < 0) {
      return FAIL;
    }
    return OK;
  }

  for (; *str != NUL; str++) {
    // Check for a multi-byte character, which may contain escaped
    // K_SPECIAL bytes.
    const char *p = mb_unescape((const char **)&str);
    if (p != NULL) {
      while (*p != NUL) {
        if (fputc(*p++, fd) < 0) {
          return FAIL;
        }
      }
      str--;
      continue;
    }

    int c = *str;
    // Special key codes have to be translated to be able to make sense
    // when they are read back.
    if (c == K_SPECIAL && what != 2) {
      int modifiers = 0;
      if (str[1] == KS_MODIFIER) {
        modifiers = str[2];
        str += 3;
        c = *str;
      }
      if (c == K_SPECIAL) {
        c = TO_SPECIAL(str[1], str[2]);
        str += 2;
      }
      if (IS_SPECIAL(c) || modifiers) {         // special key
        if (fputs(get_special_key_name(c, modifiers), fd) < 0) {
          return FAIL;
        }
        continue;
      }
    }

    // A '\n' in a map command should be written as <NL>.
    // A '\n' in a set command should be written as \^V^J.
    if (c == NL) {
      if (what == 2) {
        if (fprintf(fd, "\\\026\n") < 0) {
          return FAIL;
        }
      } else {
        if (fprintf(fd, "<NL>") < 0) {
          return FAIL;
        }
      }
      continue;
    }

    // Some characters have to be escaped with CTRL-V to
    // prevent them from misinterpreted in DoOneCmd().
    // A space, Tab and '"' has to be escaped with a backslash to
    // prevent it to be misinterpreted in do_set().
    // A space has to be escaped with a CTRL-V when it's at the start of a
    // ":map" rhs.
    // A '<' has to be escaped with a CTRL-V to prevent it being
    // interpreted as the start of a special key name.
    // A space in the lhs of a :map needs a CTRL-V.
    if (what == 2 && (ascii_iswhite(c) || c == '"' || c == '\\')) {
      if (putc('\\', fd) < 0) {
        return FAIL;
      }
    } else if (c < ' ' || c > '~' || c == '|'
               || (what == 0 && c == ' ')
               || (what == 1 && str == (uint8_t *)strstart && c == ' ')
               || (what != 2 && c == '<')) {
      if (putc(Ctrl_V, fd) < 0) {
        return FAIL;
      }
    }
    if (putc(c, fd) < 0) {
      return FAIL;
    }
  }
  return OK;
}

/// Check the string "keys" against the lhs of all mappings.
/// Return pointer to rhs of mapping (mapblock->m_str).
/// NULL when no mapping found.
///
/// @param exact  require exact match
/// @param ign_mod  ignore preceding modifier
/// @param abbr  do abbreviations
/// @param mp_ptr  return: pointer to mapblock or NULL
/// @param local_ptr  return: buffer-local mapping or NULL
char *check_map(char *keys, int mode, int exact, int ign_mod, int abbr, mapblock_T **mp_ptr,
                int *local_ptr, int *rhs_lua)
{
  *rhs_lua = LUA_NOREF;

  int len = (int)strlen(keys);
  for (int local = 1; local >= 0; local--) {
    // loop over all hash lists
    for (int hash = 0; hash < 256; hash++) {
      mapblock_T *mp;
      if (abbr) {
        if (hash > 0) {                 // there is only one list.
          break;
        }
        if (local) {
          mp = curbuf->b_first_abbr;
        } else {
          mp = first_abbr;
        }
      } else if (local) {
        mp = curbuf->b_maphash[hash];
      } else {
        mp = maphash[hash];
      }
      for (; mp != NULL; mp = mp->m_next) {
        // skip entries with wrong mode, wrong length and not matching ones
        if ((mp->m_mode & mode) && (!exact || mp->m_keylen == len)) {
          char *s = mp->m_keys;
          int keylen = mp->m_keylen;
          if (ign_mod && keylen >= 3
              && (uint8_t)s[0] == K_SPECIAL && (uint8_t)s[1] == KS_MODIFIER) {
            s += 3;
            keylen -= 3;
          }
          int minlen = keylen < len ? keylen : len;
          if (strncmp(s, keys, (size_t)minlen) == 0) {
            if (mp_ptr != NULL) {
              *mp_ptr = mp;
            }
            if (local_ptr != NULL) {
              *local_ptr = local;
            }
            *rhs_lua = mp->m_luaref;
            return mp->m_luaref == LUA_NOREF ? mp->m_str : NULL;
          }
        }
      }
    }
  }

  return NULL;
}

/// "hasmapto()" function
void f_hasmapto(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *mode;
  const char *const name = tv_get_string(&argvars[0]);
  bool abbr = false;
  char buf[NUMBUFLEN];
  if (argvars[1].v_type == VAR_UNKNOWN) {
    mode = "nvo";
  } else {
    mode = tv_get_string_buf(&argvars[1], buf);
    if (argvars[2].v_type != VAR_UNKNOWN) {
      abbr = tv_get_number(&argvars[2]);
    }
  }

  rettv->vval.v_number = map_to_exists(name, mode, abbr);
}

/// Fill a Dict with all applicable maparg() like dictionaries
///
/// @param mp            The maphash that contains the mapping information
/// @param buffer_value  The "buffer" value
/// @param abbr          True if abbreviation
/// @param compatible    True for compatible with old maparg() dict
///
/// @return  Dict.
static Dict mapblock_fill_dict(const mapblock_T *const mp, const char *lhsrawalt,
                               const int buffer_value, const bool abbr, const bool compatible,
                               Arena *arena)
  FUNC_ATTR_NONNULL_ARG(1)
{
  Dict dict = arena_dict(arena, 19);
  char *const lhs = str2special_arena(mp->m_keys, compatible, !compatible, arena);
  char *mapmode = arena_alloc(arena, 7, false);
  map_mode_to_chars(mp->m_mode, mapmode);
  int noremap_value;

  if (compatible) {
    // Keep old compatible behavior
    // This is unable to determine whether a mapping is a <script> mapping
    noremap_value = !!mp->m_noremap;
  } else {
    // Distinguish between <script> mapping
    // If it's not a <script> mapping, check if it's a noremap
    noremap_value = mp->m_noremap == REMAP_SCRIPT ? 2 : !!mp->m_noremap;
  }

  if (mp->m_luaref != LUA_NOREF) {
    PUT_C(dict, "callback", LUAREF_OBJ(api_new_luaref(mp->m_luaref)));
  } else {
    String rhs = cstr_as_string(compatible
                                ? mp->m_orig_str
                                : str2special_arena(mp->m_str, false, true, arena));
    PUT_C(dict, "rhs", STRING_OBJ(rhs));
  }
  if (mp->m_desc != NULL) {
    PUT_C(dict, "desc", CSTR_AS_OBJ(mp->m_desc));
  }
  PUT_C(dict, "lhs", CSTR_AS_OBJ(lhs));
  PUT_C(dict, "lhsraw", CSTR_AS_OBJ(mp->m_keys));
  if (lhsrawalt != NULL) {
    // Also add the value for the simplified entry.
    PUT_C(dict, "lhsrawalt", CSTR_AS_OBJ(lhsrawalt));
  }
  PUT_C(dict, "noremap", INTEGER_OBJ(noremap_value));
  PUT_C(dict, "script", INTEGER_OBJ(mp->m_noremap == REMAP_SCRIPT ? 1 : 0));
  PUT_C(dict, "expr", INTEGER_OBJ(mp->m_expr ? 1 : 0));
  PUT_C(dict, "silent", INTEGER_OBJ(mp->m_silent ? 1 : 0));
  PUT_C(dict, "sid", INTEGER_OBJ(mp->m_script_ctx.sc_sid));
  PUT_C(dict, "scriptversion", INTEGER_OBJ(1));
  PUT_C(dict, "lnum", INTEGER_OBJ(mp->m_script_ctx.sc_lnum));
  PUT_C(dict, "buffer", INTEGER_OBJ(buffer_value));
  PUT_C(dict, "nowait", INTEGER_OBJ(mp->m_nowait ? 1 : 0));
  if (mp->m_replace_keycodes) {
    PUT_C(dict, "replace_keycodes", INTEGER_OBJ(1));
  }
  PUT_C(dict, "mode", CSTR_AS_OBJ(mapmode));
  PUT_C(dict, "abbr", INTEGER_OBJ(abbr ? 1 : 0));
  PUT_C(dict, "mode_bits", INTEGER_OBJ(mp->m_mode));

  return dict;
}

static void get_maparg(typval_T *argvars, typval_T *rettv, int exact)
{
  // Return empty string for failure.
  rettv->v_type = VAR_STRING;
  rettv->vval.v_string = NULL;

  char *keys = (char *)tv_get_string(&argvars[0]);
  if (*keys == NUL) {
    return;
  }

  const char *which;
  char buf[NUMBUFLEN];
  bool abbr = false;
  bool get_dict = false;

  if (argvars[1].v_type != VAR_UNKNOWN) {
    which = tv_get_string_buf_chk(&argvars[1], buf);
    if (argvars[2].v_type != VAR_UNKNOWN) {
      abbr = (bool)tv_get_number(&argvars[2]);
      if (argvars[3].v_type != VAR_UNKNOWN) {
        get_dict = (bool)tv_get_number(&argvars[3]);
      }
    }
  } else {
    which = "";
  }
  if (which == NULL) {
    return;
  }

  char *keys_buf = NULL;
  char *alt_keys_buf = NULL;
  bool did_simplify = false;
  const int flags = REPTERM_FROM_PART | REPTERM_DO_LT;
  const int mode = get_map_mode((char **)&which, 0);

  char *keys_simplified = replace_termcodes(keys, strlen(keys), &keys_buf, 0,
                                            flags, &did_simplify, p_cpo);
  mapblock_T *mp = NULL;
  int buffer_local;
  LuaRef rhs_lua;
  char *rhs = check_map(keys_simplified, mode, exact, false, abbr, &mp, &buffer_local,
                        &rhs_lua);
  if (did_simplify) {
    // When the lhs is being simplified the not-simplified keys are
    // preferred for printing, like in do_map().
    replace_termcodes(keys, strlen(keys), &alt_keys_buf, 0,
                      flags | REPTERM_NO_SIMPLIFY, NULL, p_cpo);
    rhs = check_map(alt_keys_buf, mode, exact, false, abbr, &mp, &buffer_local, &rhs_lua);
  }

  if (!get_dict) {
    // Return a string.
    if (rhs != NULL) {
      if (*rhs == NUL) {
        rettv->vval.v_string = xstrdup("<Nop>");
      } else {
        rettv->vval.v_string = str2special_save(rhs, false, false);
      }
    } else if (rhs_lua != LUA_NOREF) {
      rettv->vval.v_string = nlua_funcref_str(mp->m_luaref, NULL);
    }
  } else {
    // Return a dictionary.
    if (mp != NULL && (rhs != NULL || rhs_lua != LUA_NOREF)) {
      Arena arena = ARENA_EMPTY;
      Dict dict = mapblock_fill_dict(mp, did_simplify ? keys_simplified : NULL,
                                     buffer_local, abbr, true, &arena);
      object_to_vim_take_luaref(&DICT_OBJ(dict), rettv, true, NULL);
      arena_mem_free(arena_finish(&arena));
    } else {
      // Return an empty dictionary.
      tv_dict_alloc_ret(rettv);
    }
  }

  xfree(keys_buf);
  xfree(alt_keys_buf);
}

/// Get the mapping mode from the mode string.
/// It may contain multiple characters, eg "nox", or "!", or ' '
/// Return 0 if there is an error.
static int get_map_mode_string(const char *const mode_string, const bool abbr)
{
  const char *p = mode_string;
  const int MASK_V = MODE_VISUAL | MODE_SELECT;
  const int MASK_MAP = MODE_VISUAL | MODE_SELECT | MODE_NORMAL | MODE_OP_PENDING;
  const int MASK_BANG = MODE_INSERT | MODE_CMDLINE;

  if (*p == NUL) {
    p = " ";  // compatibility
  }
  int mode = 0;
  int modec;
  while ((modec = (uint8_t)(*p++))) {
    int tmode;
    switch (modec) {
    case 'i':
      tmode = MODE_INSERT; break;
    case 'l':
      tmode = MODE_LANGMAP; break;
    case 'c':
      tmode = MODE_CMDLINE; break;
    case 'n':
      tmode = MODE_NORMAL; break;
    case 'x':
      tmode = MODE_VISUAL; break;
    case 's':
      tmode = MODE_SELECT; break;
    case 'o':
      tmode = MODE_OP_PENDING; break;
    case 't':
      tmode = MODE_TERMINAL; break;
    case 'v':
      tmode = MASK_V; break;
    case '!':
      tmode = MASK_BANG; break;
    case ' ':
      tmode = MASK_MAP; break;
    default:
      return 0;  // error, unknown mode character
    }
    mode |= tmode;
  }
  if ((abbr && (mode & ~MASK_BANG) != 0)
      || (!abbr && (mode & (mode - 1)) != 0  // more than one bit set
          && (
              // false if multiple bits set in mode and mode is fully
              // contained in one mask
              !(((mode & MASK_BANG) != 0 && (mode & ~MASK_BANG) == 0)
                || ((mode & MASK_MAP) != 0 && (mode & ~MASK_MAP) == 0))))) {
    return 0;
  }

  return mode;
}

/// "mapset()" function
void f_mapset(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const char *which;
  char buf[NUMBUFLEN];
  int is_abbr;
  dict_T *d;

  // If first arg is a dict, then that's the only arg permitted.
  const bool dict_only = argvars[0].v_type == VAR_DICT;

  if (dict_only) {
    d = argvars[0].vval.v_dict;
    which = tv_dict_get_string(d, "mode", false);
    is_abbr = (int)tv_dict_get_bool(d, "abbr", -1);
    if (which == NULL || is_abbr < 0) {
      emsg(_(e_entries_missing_in_mapset_dict_argument));
      return;
    }
  } else {
    which = tv_get_string_buf_chk(&argvars[0], buf);
    if (which == NULL) {
      return;
    }
    is_abbr = (int)tv_get_bool(&argvars[1]);
    if (tv_check_for_dict_arg(argvars, 2) == FAIL) {
      return;
    }
    d = argvars[2].vval.v_dict;
  }
  const int mode = get_map_mode_string(which, is_abbr);
  if (mode == 0) {
    semsg(_(e_illegal_map_mode_string_str), which);
    return;
  }

  // Get the values in the same order as above in get_maparg().
  char *lhs = tv_dict_get_string(d, "lhs", false);
  char *lhsraw = tv_dict_get_string(d, "lhsraw", false);
  char *lhsrawalt = tv_dict_get_string(d, "lhsrawalt", false);
  char *orig_rhs = tv_dict_get_string(d, "rhs", false);
  LuaRef rhs_lua = LUA_NOREF;
  dictitem_T *callback_di = tv_dict_find(d, S_LEN("callback"));
  if (callback_di != NULL) {
    if (callback_di->di_tv.v_type == VAR_FUNC) {
      ufunc_T *fp = find_func(callback_di->di_tv.vval.v_string);
      if (fp != NULL && (fp->uf_flags & FC_LUAREF)) {
        rhs_lua = api_new_luaref(fp->uf_luaref);
        orig_rhs = "";
      }
    }
  }
  if (lhs == NULL || lhsraw == NULL || orig_rhs == NULL) {
    emsg(_(e_entries_missing_in_mapset_dict_argument));
    api_free_luaref(rhs_lua);
    return;
  }

  int noremap = tv_dict_get_number(d, "noremap") != 0 ? REMAP_NONE : 0;
  if (tv_dict_get_number(d, "script") != 0) {
    noremap = REMAP_SCRIPT;
  }
  MapArguments args = {
    .expr = tv_dict_get_number(d, "expr") != 0,
    .silent = tv_dict_get_number(d, "silent") != 0,
    .nowait = tv_dict_get_number(d, "nowait") != 0,
    .replace_keycodes = tv_dict_get_number(d, "replace_keycodes") != 0,
    .desc = tv_dict_get_string(d, "desc", true),
  };
  scid_T sid = (scid_T)tv_dict_get_number(d, "sid");
  linenr_T lnum = (linenr_T)tv_dict_get_number(d, "lnum");
  bool buffer = tv_dict_get_number(d, "buffer") != 0;
  // mode from the dict is not used

  set_maparg_rhs(orig_rhs, strlen(orig_rhs), rhs_lua, sid, p_cpo, &args);

  mapblock_T **map_table = buffer ? curbuf->b_maphash : maphash;
  mapblock_T **abbr_table = buffer ? &curbuf->b_first_abbr : &first_abbr;

  // Delete any existing mapping for this lhs and mode.
  MapArguments unmap_args = MAP_ARGUMENTS_INIT;
  set_maparg_lhs_rhs(lhs, strlen(lhs), "", 0, LUA_NOREF, p_cpo, &unmap_args);
  unmap_args.buffer = buffer;
  buf_do_map(MAPTYPE_UNMAP, &unmap_args, mode, is_abbr, curbuf);
  xfree(unmap_args.rhs);
  xfree(unmap_args.orig_rhs);

  mapblock_T *mp_result[2] = { NULL, NULL };

  mp_result[0] = map_add(curbuf, map_table, abbr_table, lhsraw, &args,
                         noremap, mode, is_abbr, sid, lnum, false);
  if (lhsrawalt != NULL) {
    mp_result[1] = map_add(curbuf, map_table, abbr_table, lhsrawalt, &args,
                           noremap, mode, is_abbr, sid, lnum, true);
  }

  if (mp_result[0] != NULL && mp_result[1] != NULL) {
    mp_result[0]->m_alt = mp_result[1];
    mp_result[1]->m_alt = mp_result[0];
  }
}

/// "maplist()" function
void f_maplist(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  const int flags = REPTERM_FROM_PART | REPTERM_DO_LT;
  const bool abbr = argvars[0].v_type != VAR_UNKNOWN && tv_get_bool(&argvars[0]);

  tv_list_alloc_ret(rettv, kListLenUnknown);

  // Do it twice: once for global maps and once for local maps.
  for (int buffer_local = 0; buffer_local <= 1; buffer_local++) {
    for (int hash = 0; hash < 256; hash++) {
      mapblock_T *mp;
      if (abbr) {
        if (hash > 0) {  // there is only one abbr list
          break;
        }
        if (buffer_local) {
          mp = curbuf->b_first_abbr;
        } else {
          mp = first_abbr;
        }
      } else if (buffer_local) {
        mp = curbuf->b_maphash[hash];
      } else {
        mp = maphash[hash];
      }
      for (; mp; mp = mp->m_next) {
        if (mp->m_simplified) {
          continue;
        }

        char *keys_buf = NULL;
        bool did_simplify = false;

        Arena arena = ARENA_EMPTY;
        char *lhs = str2special_arena(mp->m_keys, true, false, &arena);
        replace_termcodes(lhs, strlen(lhs), &keys_buf, 0, flags, &did_simplify,
                          p_cpo);

        Dict dict = mapblock_fill_dict(mp, did_simplify ? keys_buf : NULL, buffer_local, abbr, true,
                                       &arena);
        typval_T d = TV_INITIAL_VALUE;
        object_to_vim_take_luaref(&DICT_OBJ(dict), &d, true, NULL);
        assert(d.v_type == VAR_DICT);
        tv_list_append_dict(rettv->vval.v_list, d.vval.v_dict);
        arena_mem_free(arena_finish(&arena));
        xfree(keys_buf);
      }
    }
  }
}

/// "maparg()" function
void f_maparg(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  get_maparg(argvars, rettv, true);
}

/// "mapcheck()" function
void f_mapcheck(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  get_maparg(argvars, rettv, false);
}

/// Add a mapping. Unlike @ref do_map this copies the string arguments, so
/// static or read-only strings can be used.
///
/// @param lhs  C-string containing the lhs of the mapping
/// @param rhs  C-string containing the rhs of the mapping
/// @param mode  Bitflags representing the mode in which to set the mapping.
///              See @ref get_map_mode.
/// @param buffer  If true, make a buffer-local mapping for curbuf
void add_map(char *lhs, char *rhs, int mode, bool buffer)
{
  MapArguments args = MAP_ARGUMENTS_INIT;
  set_maparg_lhs_rhs(lhs, strlen(lhs), rhs, strlen(rhs), LUA_NOREF, p_cpo, &args);
  args.buffer = buffer;

  buf_do_map(MAPTYPE_NOREMAP, &args, mode, false, curbuf);
  xfree(args.rhs);
  xfree(args.orig_rhs);
}

/// Any character has an equivalent 'langmap' character.  This is used for
/// keyboards that have a special language mode that sends characters above
/// 128 (although other characters can be translated too).  The "to" field is a
/// Vim command character.  This avoids having to switch the keyboard back to
/// ASCII mode when leaving Insert mode.
///
/// langmap_mapchar[] maps any of 256 chars to an ASCII char used for Vim
/// commands.
/// langmap_mapga.ga_data is a sorted table of langmap_entry_T.
/// This does the same as langmap_mapchar[] for characters >= 256.
///
/// With multi-byte support use growarray for 'langmap' chars >= 256
typedef struct {
  int from;
  int to;
} langmap_entry_T;

static garray_T langmap_mapga = GA_EMPTY_INIT_VALUE;

/// Search for an entry in "langmap_mapga" for "from".  If found set the "to"
/// field.  If not found insert a new entry at the appropriate location.
static void langmap_set_entry(int from, int to)
{
  langmap_entry_T *entries = (langmap_entry_T *)(langmap_mapga.ga_data);
  unsigned a = 0;
  assert(langmap_mapga.ga_len >= 0);
  unsigned b = (unsigned)langmap_mapga.ga_len;

  // Do a binary search for an existing entry.
  while (a != b) {
    unsigned i = (a + b) / 2;
    int d = entries[i].from - from;

    if (d == 0) {
      entries[i].to = to;
      return;
    }
    if (d < 0) {
      a = i + 1;
    } else {
      b = i;
    }
  }

  ga_grow(&langmap_mapga, 1);

  // insert new entry at position "a"
  entries = (langmap_entry_T *)(langmap_mapga.ga_data) + a;
  memmove(entries + 1, entries,
          ((unsigned)langmap_mapga.ga_len - a) * sizeof(langmap_entry_T));
  langmap_mapga.ga_len++;
  entries[0].from = from;
  entries[0].to = to;
}

/// Apply 'langmap' to multi-byte character "c" and return the result.
int langmap_adjust_mb(int c)
{
  langmap_entry_T *entries = (langmap_entry_T *)(langmap_mapga.ga_data);
  int a = 0;
  int b = langmap_mapga.ga_len;

  while (a != b) {
    int i = (a + b) / 2;
    int d = entries[i].from - c;

    if (d == 0) {
      return entries[i].to;        // found matching entry
    }
    if (d < 0) {
      a = i + 1;
    } else {
      b = i;
    }
  }
  return c;    // no entry found, return "c" unmodified
}

void langmap_init(void)
{
  for (int i = 0; i < 256; i++) {
    langmap_mapchar[i] = (uint8_t)i;      // we init with a one-to-one map
  }
  ga_init(&langmap_mapga, sizeof(langmap_entry_T), 8);
}

/// Called when langmap option is set; the language map can be
/// changed at any time!
const char *did_set_langmap(optset_T *args)
{
  ga_clear(&langmap_mapga);  // clear the previous map first
  langmap_init();            // back to one-to-one map

  for (char *p = p_langmap; p[0] != NUL;) {
    char *p2;
    for (p2 = p; p2[0] != NUL && p2[0] != ',' && p2[0] != ';';
         MB_PTR_ADV(p2)) {
      if (p2[0] == '\\' && p2[1] != NUL) {
        p2++;
      }
    }
    if (p2[0] == ';') {
      p2++;                 // abcd;ABCD form, p2 points to A
    } else {
      p2 = NULL;            // aAbBcCdD form, p2 is NULL
    }
    while (p[0]) {
      if (p[0] == ',') {
        p++;
        break;
      }
      if (p[0] == '\\' && p[1] != NUL) {
        p++;
      }
      int from = utf_ptr2char(p);
      int to = NUL;
      if (p2 == NULL) {
        MB_PTR_ADV(p);
        if (p[0] != ',') {
          if (p[0] == '\\') {
            p++;
          }
          to = utf_ptr2char(p);
        }
      } else {
        if (p2[0] != ',') {
          if (p2[0] == '\\') {
            p2++;
          }
          to = utf_ptr2char(p2);
        }
      }
      if (to == NUL) {
        snprintf(args->os_errbuf, args->os_errbuflen,
                 _("E357: 'langmap': Matching character missing for %s"),
                 transchar(from));
        return args->os_errbuf;
      }

      if (from >= 256) {
        langmap_set_entry(from, to);
      } else {
        assert(to <= UCHAR_MAX);
        langmap_mapchar[from & 255] = (uint8_t)to;
      }

      // Advance to next pair
      MB_PTR_ADV(p);
      if (p2 != NULL) {
        MB_PTR_ADV(p2);
        if (*p == ';') {
          p = p2;
          if (p[0] != NUL) {
            if (p[0] != ',') {
              snprintf(args->os_errbuf, args->os_errbuflen,
                       _("E358: 'langmap': Extra characters after semicolon: %s"),
                       p);
              return args->os_errbuf;
            }
            p++;
          }
          break;
        }
      }
    }
  }

  return NULL;
}

static void do_exmap(exarg_T *eap, int isabbrev)
{
  char *cmdp = eap->cmd;
  int mode = get_map_mode(&cmdp, eap->forceit || isabbrev);

  switch (do_map((*cmdp == 'n') ? MAPTYPE_NOREMAP
                                : (*cmdp == 'u') ? MAPTYPE_UNMAP : MAPTYPE_MAP,
                 eap->arg, mode, isabbrev)) {
  case 1:
    emsg(_(e_invarg));
    break;
  case 2:
    emsg(isabbrev ? _(e_noabbr) : _(e_nomap));
    break;
  }
}

/// ":abbreviate" and friends.
void ex_abbreviate(exarg_T *eap)
{
  do_exmap(eap, true);          // almost the same as mapping
}

/// ":map" and friends.
void ex_map(exarg_T *eap)
{
  // If we are in a secure mode we print the mappings for security reasons.
  if (secure) {
    secure = 2;
    msg_outtrans(eap->cmd, 0);
    msg_putchar('\n');
  }
  do_exmap(eap, false);
}

/// ":unmap" and friends.
void ex_unmap(exarg_T *eap)
{
  do_exmap(eap, false);
}

/// ":mapclear" and friends.
void ex_mapclear(exarg_T *eap)
{
  do_mapclear(eap->cmd, eap->arg, eap->forceit, false);
}

/// ":abclear" and friends.
void ex_abclear(exarg_T *eap)
{
  do_mapclear(eap->cmd, eap->arg, true, true);
}

/// Set, tweak, or remove a mapping in a mode. Acts as the implementation for
/// functions like @ref nvim_buf_set_keymap.
///
/// Arguments are handled like @ref nvim_set_keymap unless noted.
/// @param  buffer    Buffer handle for a specific buffer, or 0 for the current
///                   buffer, or -1 to signify global behavior ("all buffers")
/// @param  is_unmap  When true, removes the mapping that matches {lhs}.
void modify_keymap(uint64_t channel_id, Buffer buffer, bool is_unmap, String mode, String lhs,
                   String rhs, Dict(keymap) *opts, Error *err)
{
  LuaRef lua_funcref = LUA_NOREF;
  bool global = (buffer == -1);
  if (global) {
    buffer = 0;
  }
  buf_T *target_buf = find_buffer_by_handle(buffer, err);

  if (!target_buf) {
    return;
  }

  const sctx_T save_current_sctx = api_set_sctx(channel_id);

  MapArguments parsed_args = MAP_ARGUMENTS_INIT;
  if (opts) {
    parsed_args.nowait = opts->nowait;
    parsed_args.noremap = opts->noremap;
    parsed_args.silent = opts->silent;
    parsed_args.script = opts->script;
    parsed_args.expr = opts->expr;
    parsed_args.unique = opts->unique;
    parsed_args.replace_keycodes = opts->replace_keycodes;
    if (HAS_KEY(opts, keymap, callback)) {
      lua_funcref = opts->callback;
      opts->callback = LUA_NOREF;
    }
    if (HAS_KEY(opts, keymap, desc)) {
      parsed_args.desc = string_to_cstr(opts->desc);
    }
  }
  parsed_args.buffer = !global;

  if (parsed_args.replace_keycodes && !parsed_args.expr) {
    api_set_error(err, kErrorTypeValidation,  "\"replace_keycodes\" requires \"expr\"");
    goto fail_and_free;
  }

  if (!set_maparg_lhs_rhs(lhs.data, lhs.size,
                          rhs.data, rhs.size, lua_funcref,
                          p_cpo, &parsed_args)) {
    api_set_error(err, kErrorTypeValidation,  "LHS exceeds maximum map length: %s", lhs.data);
    goto fail_and_free;
  }

  if (parsed_args.lhs_len > MAXMAPLEN || parsed_args.alt_lhs_len > MAXMAPLEN) {
    api_set_error(err, kErrorTypeValidation,  "LHS exceeds maximum map length: %s", lhs.data);
    goto fail_and_free;
  }

  char *p = mode.size > 0 ? mode.data : "m";
  bool forceit = *p == '!';
  // integer value of the mapping mode, to be passed to do_map()
  int mode_val = get_map_mode(&p, forceit);
  if (forceit) {
    assert(p == mode.data);
    p++;
  }
  bool is_abbrev = (mode_val & (MODE_INSERT | MODE_CMDLINE)) != 0 && *p == 'a';
  if (is_abbrev) {
    p++;
  }
  if (mode.size > 0 && (size_t)(p - mode.data) != mode.size) {
    api_set_error(err, kErrorTypeValidation, "Invalid mode shortname: \"%s\"", mode.data);
    goto fail_and_free;
  }

  if (parsed_args.lhs_len == 0) {
    api_set_error(err, kErrorTypeValidation, "Invalid (empty) LHS");
    goto fail_and_free;
  }

  bool is_noremap = parsed_args.noremap;
  assert(!(is_unmap && is_noremap));

  if (!is_unmap && lua_funcref == LUA_NOREF
      && (parsed_args.rhs_len == 0 && !parsed_args.rhs_is_noop)) {
    if (rhs.size == 0) {  // assume that the user wants RHS to be a <Nop>
      parsed_args.rhs_is_noop = true;
    } else {
      abort();  // should never happen
    }
  } else if (is_unmap && (parsed_args.rhs_len || parsed_args.rhs_lua != LUA_NOREF)) {
    if (parsed_args.rhs_len) {
      api_set_error(err, kErrorTypeValidation,
                    "Gave nonempty RHS in unmap command: %s", parsed_args.rhs);
    } else {
      api_set_error(err, kErrorTypeValidation, "Gave nonempty RHS for unmap");
    }
    goto fail_and_free;
  }

  // buf_do_map() reads noremap/unmap as its own argument.
  int maptype_val = MAPTYPE_MAP;
  if (is_unmap) {
    maptype_val = MAPTYPE_UNMAP;
  } else if (is_noremap) {
    maptype_val = MAPTYPE_NOREMAP;
  }

  switch (buf_do_map(maptype_val, &parsed_args, mode_val, is_abbrev, target_buf)) {
  case 0:
    break;
  case 1:
    api_set_error(err, kErrorTypeException, e_invarg, 0);
    goto fail_and_free;
  case 2:
    api_set_error(err, kErrorTypeException, e_nomap, 0);
    goto fail_and_free;
  case 5:
    api_set_error(err, kErrorTypeException,
                  "E227: mapping already exists for %s", parsed_args.lhs);
    goto fail_and_free;
  default:
    assert(false && "Unrecognized return code!");
    goto fail_and_free;
  }  // switch

fail_and_free:
  current_sctx = save_current_sctx;
  NLUA_CLEAR_REF(parsed_args.rhs_lua);
  xfree(parsed_args.rhs);
  xfree(parsed_args.orig_rhs);
  xfree(parsed_args.desc);
}

/// Get an array containing dictionaries describing mappings
/// based on mode and buffer id
///
/// @param  mode  The abbreviation for the mode
/// @param  buf  The buffer to get the mapping array. NULL for global
/// @returns Array of maparg()-like dictionaries describing mappings
ArrayOf(Dict) keymap_array(String mode, buf_T *buf, Arena *arena)
{
  ArrayBuilder mappings = KV_INITIAL_VALUE;
  kvi_init(mappings);

  char *p = mode.size > 0 ? mode.data : "m";
  bool forceit = *p == '!';
  // Convert the string mode to the integer mode stored within each mapblock.
  int int_mode = get_map_mode(&p, forceit);
  if (forceit) {
    assert(p == mode.data);
    p++;
  }
  bool is_abbrev = (int_mode & (MODE_INSERT | MODE_CMDLINE)) != 0 && *p == 'a';

  // Determine the desired buffer value
  int buffer_value = (buf == NULL) ? 0 : buf->handle;

  for (int i = 0; i < (is_abbrev ? 1 : MAX_MAPHASH); i++) {
    for (const mapblock_T *current_maphash = is_abbrev
                                             ? (buf ? buf->b_first_abbr : first_abbr)
                                             : (buf ? buf->b_maphash[i] : maphash[i]);
         current_maphash;
         current_maphash = current_maphash->m_next) {
      if (current_maphash->m_simplified) {
        continue;
      }
      // Check for correct mode
      if (int_mode & current_maphash->m_mode) {
        kvi_push(mappings, DICT_OBJ(mapblock_fill_dict(current_maphash, NULL, buffer_value,
                                                       is_abbrev, false, arena)));
      }
    }
  }

  return arena_take_arraybuilder(arena, &mappings);
}
