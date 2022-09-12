// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// mapping.c: Code for mappings and abbreviations.

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/api/private/converter.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii.h"
#include "nvim/assert.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_session.h"
#include "nvim/func_attr.h"
#include "nvim/garray.h"
#include "nvim/getchar.h"
#include "nvim/keycodes.h"
#include "nvim/lua/executor.h"
#include "nvim/mapping.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/regexp.h"
#include "nvim/runtime.h"
#include "nvim/ui.h"
#include "nvim/vim.h"

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

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mapping.c.generated.h"
#endif

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

/// Retrieve the mapblock at the index either globally or for a certain buffer
///
/// @param  index  The index in the maphash[]
/// @param  buf  The buffer to get the maphash from. NULL for global
mapblock_T *get_maphash(int index, buf_T *buf)
    FUNC_ATTR_PURE
{
  if (index >= MAX_MAPHASH) {
    return NULL;
  }

  return (buf == NULL) ? maphash[index] : buf->b_maphash[index];
}

/// Delete one entry from the abbrlist or maphash[].
/// "mpp" is a pointer to the m_next field of the PREVIOUS entry!
static void mapblock_free(mapblock_T **mpp)
{
  mapblock_T *mp;

  mp = *mpp;
  xfree(mp->m_keys);
  if (!mp->m_simplified) {
    NLUA_CLEAR_REF(mp->m_luaref);
    xfree(mp->m_str);
    xfree(mp->m_orig_str);
  }
  xfree(mp->m_desc);
  *mpp = mp->m_next;
  xfree(mp);
}

/// Return characters to represent the map mode in an allocated string
///
/// @return [allocated] NUL-terminated string with characters.
static char *map_mode_to_chars(int mode)
  FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_RET
{
  garray_T mapmode;

  ga_init(&mapmode, 1, 7);

  if ((mode & (MODE_INSERT | MODE_CMDLINE)) == (MODE_INSERT | MODE_CMDLINE)) {
    ga_append(&mapmode, '!');                           // :map!
  } else if (mode & MODE_INSERT) {
    ga_append(&mapmode, 'i');                           // :imap
  } else if (mode & MODE_LANGMAP) {
    ga_append(&mapmode, 'l');                           // :lmap
  } else if (mode & MODE_CMDLINE) {
    ga_append(&mapmode, 'c');                           // :cmap
  } else if ((mode & (MODE_NORMAL | MODE_VISUAL | MODE_SELECT | MODE_OP_PENDING))
             == (MODE_NORMAL | MODE_VISUAL | MODE_SELECT | MODE_OP_PENDING)) {
    ga_append(&mapmode, ' ');                           // :map
  } else {
    if (mode & MODE_NORMAL) {
      ga_append(&mapmode, 'n');                         // :nmap
    }
    if (mode & MODE_OP_PENDING) {
      ga_append(&mapmode, 'o');                         // :omap
    }
    if (mode & MODE_TERMINAL) {
      ga_append(&mapmode, 't');                         // :tmap
    }
    if ((mode & (MODE_VISUAL | MODE_SELECT)) == (MODE_VISUAL | MODE_SELECT)) {
      ga_append(&mapmode, 'v');                         // :vmap
    } else {
      if (mode & MODE_VISUAL) {
        ga_append(&mapmode, 'x');                       // :xmap
      }
      if (mode & MODE_SELECT) {
        ga_append(&mapmode, 's');                       // :smap
      }
    }
  }

  ga_append(&mapmode, NUL);
  return (char *)mapmode.ga_data;
}

/// @param local  true for buffer-local map
static void showmap(mapblock_T *mp, bool local)
{
  size_t len = 1;

  if (message_filtered((char *)mp->m_keys) && message_filtered(mp->m_str)
      && (mp->m_desc == NULL || message_filtered(mp->m_desc))) {
    return;
  }

  if (msg_didout || msg_silent != 0) {
    msg_putchar('\n');
    if (got_int) {          // 'q' typed at MORE prompt
      return;
    }
  }

  {
    char *const mapchars = map_mode_to_chars(mp->m_mode);
    msg_puts(mapchars);
    len = strlen(mapchars);
    xfree(mapchars);
  }

  while (++len <= 3) {
    msg_putchar(' ');
  }

  // Display the LHS.  Get length of what we write.
  len = (size_t)msg_outtrans_special((char *)mp->m_keys, true, 0);
  do {
    msg_putchar(' ');                   // padd with blanks
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
    char *str = nlua_funcref_str(mp->m_luaref);
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
/// @param[in] cpo_flags  See param docs for @ref replace_termcodes.
/// @param[out] mapargs   MapArguments struct holding the replaced strings.
static bool set_maparg_lhs_rhs(const char *const orig_lhs, const size_t orig_lhs_len,
                               const char *const orig_rhs, const size_t orig_rhs_len,
                               const LuaRef rhs_lua, const int cpo_flags,
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
  // If something like <C-H> is simplified to 0x08 then mark it as simplified.
  bool did_simplify = false;
  const int flags = REPTERM_FROM_PART | REPTERM_DO_LT;
  char *bufarg = lhs_buf;
  char *replaced = replace_termcodes(orig_lhs, orig_lhs_len, &bufarg, flags, &did_simplify,
                                     cpo_flags);
  if (replaced == NULL) {
    return false;
  }
  mapargs->lhs_len = strlen(replaced);
  STRLCPY(mapargs->lhs, replaced, sizeof(mapargs->lhs));
  if (did_simplify) {
    replaced = replace_termcodes(orig_lhs, orig_lhs_len, &bufarg, flags | REPTERM_NO_SIMPLIFY,
                                 NULL, cpo_flags);
    if (replaced == NULL) {
      return false;
    }
    mapargs->alt_lhs_len = strlen(replaced);
    STRLCPY(mapargs->alt_lhs, replaced, sizeof(mapargs->alt_lhs));
  } else {
    mapargs->alt_lhs_len = 0;
  }

  set_maparg_rhs(orig_rhs, orig_rhs_len, rhs_lua, cpo_flags, mapargs);

  return true;
}

/// @see set_maparg_lhs_rhs
static void set_maparg_rhs(const char *const orig_rhs, const size_t orig_rhs_len,
                           const LuaRef rhs_lua, const int cpo_flags, MapArguments *const mapargs)
{
  mapargs->rhs_lua = rhs_lua;

  if (rhs_lua == LUA_NOREF) {
    mapargs->orig_rhs_len = orig_rhs_len;
    mapargs->orig_rhs = xcalloc(mapargs->orig_rhs_len + 1, sizeof(char_u));
    STRLCPY(mapargs->orig_rhs, orig_rhs, mapargs->orig_rhs_len + 1);
    if (STRICMP(orig_rhs, "<nop>") == 0) {  // "<Nop>" means nothing
      mapargs->rhs = xcalloc(1, sizeof(char_u));  // single NUL-char
      mapargs->rhs_len = 0;
      mapargs->rhs_is_noop = true;
    } else {
      char *rhs_buf = NULL;
      char *replaced = replace_termcodes(orig_rhs, orig_rhs_len, &rhs_buf, REPTERM_DO_LT, NULL,
                                         cpo_flags);
      mapargs->rhs_len = strlen(replaced);
      // NB: replace_termcodes may produce an empty string even if orig_rhs is non-empty
      // (e.g. a single ^V, see :h map-empty-rhs)
      mapargs->rhs_is_noop = orig_rhs_len != 0 && mapargs->rhs_len == 0;
      mapargs->rhs = replaced;
    }
  } else {
    char tmp_buf[64];
    // orig_rhs is not used for Lua mappings, but still needs to be a string.
    mapargs->orig_rhs = xcalloc(1, sizeof(char_u));
    mapargs->orig_rhs_len = 0;
    // stores <lua>ref_no<cr> in map_str
    mapargs->rhs_len = (size_t)vim_snprintf(S_LEN(tmp_buf), "%c%c%c%d\r", K_SPECIAL,
                                            (char_u)KS_EXTRA, KE_LUA, rhs_lua);
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
static int str_to_mapargs(const char_u *strargs, bool is_unmap, MapArguments *mapargs)
{
  const char_u *to_parse = strargs;
  to_parse = (char_u *)skipwhite((char *)to_parse);
  CLEAR_POINTER(mapargs);

  // Accept <buffer>, <nowait>, <silent>, <expr>, <script>, and <unique> in
  // any order.
  while (true) {
    if (STRNCMP(to_parse, "<buffer>", 8) == 0) {
      to_parse = (char_u *)skipwhite((char *)to_parse + 8);
      mapargs->buffer = true;
      continue;
    }

    if (STRNCMP(to_parse, "<nowait>", 8) == 0) {
      to_parse = (char_u *)skipwhite((char *)to_parse + 8);
      mapargs->nowait = true;
      continue;
    }

    if (STRNCMP(to_parse, "<silent>", 8) == 0) {
      to_parse = (char_u *)skipwhite((char *)to_parse + 8);
      mapargs->silent = true;
      continue;
    }

    // Ignore obsolete "<special>" modifier.
    if (STRNCMP(to_parse, "<special>", 9) == 0) {
      to_parse = (char_u *)skipwhite((char *)to_parse + 9);
      continue;
    }

    if (STRNCMP(to_parse, "<script>", 8) == 0) {
      to_parse = (char_u *)skipwhite((char *)to_parse + 8);
      mapargs->script = true;
      continue;
    }

    if (STRNCMP(to_parse, "<expr>", 6) == 0) {
      to_parse = (char_u *)skipwhite((char *)to_parse + 6);
      mapargs->expr = true;
      continue;
    }

    if (STRNCMP(to_parse, "<unique>", 8) == 0) {
      to_parse = (char_u *)skipwhite((char *)to_parse + 8);
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
  const char *lhs_end = (char *)to_parse;
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
  const char_u *rhs_start = (char_u *)skipwhite((char *)lhs_end);

  // Given {lhs} might be larger than MAXMAPLEN before replace_termcodes
  // (e.g. "<Space>" is longer than ' '), so first copy into a buffer.
  size_t orig_lhs_len = (size_t)((char_u *)lhs_end - to_parse);
  if (orig_lhs_len >= 256) {
    return 1;
  }
  char_u lhs_to_replace[256];
  STRLCPY(lhs_to_replace, to_parse, orig_lhs_len + 1);

  size_t orig_rhs_len = STRLEN(rhs_start);
  if (!set_maparg_lhs_rhs((char *)lhs_to_replace, orig_lhs_len,
                          (char *)rhs_start, orig_rhs_len, LUA_NOREF,
                          CPO_TO_CPO_FLAGS, mapargs)) {
    return 1;
  }

  if (mapargs->lhs_len > MAXMAPLEN) {
    return 1;
  }
  return 0;
}

/// @param args  "rhs", "rhs_lua", "orig_rhs", "expr", "silent", "nowait", "replace_keycodes" and
///              and "desc" fields are used.
///              "rhs", "rhs_lua", "orig_rhs" fields are cleared if "simplified" is false.
/// @param sid  -1 to use current_sctx
static void map_add(buf_T *buf, mapblock_T **map_table, mapblock_T **abbr_table, const char *keys,
                    MapArguments *args, int noremap, int mode, bool is_abbr, scid_T sid,
                    linenr_T lnum, bool simplified)
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

  mp->m_keys = (uint8_t *)xstrdup(keys);
  mp->m_str = args->rhs;
  mp->m_orig_str = (char *)args->orig_rhs;
  mp->m_luaref = args->rhs_lua;
  if (!simplified) {
    args->rhs = NULL;
    args->orig_rhs = NULL;
    args->rhs_lua = LUA_NOREF;
  }
  mp->m_keylen = (int)STRLEN(mp->m_keys);
  mp->m_noremap = noremap;
  mp->m_nowait = args->nowait;
  mp->m_silent = args->silent;
  mp->m_mode = mode;
  mp->m_simplified = simplified;
  mp->m_expr = args->expr;
  mp->m_replace_keycodes = args->replace_keycodes;
  if (sid >= 0) {
    mp->m_script_ctx.sc_sid = sid;
    mp->m_script_ctx.sc_lnum = lnum;
  } else {
    mp->m_script_ctx = current_sctx;
    mp->m_script_ctx.sc_lnum += SOURCING_LNUM;
    nlua_set_sctx(&mp->m_script_ctx);
  }
  mp->m_desc = NULL;
  if (args->desc != NULL) {
    mp->m_desc = xstrdup(args->desc);
  }

  // add the new entry in front of the abbrlist or maphash[] list
  if (is_abbr) {
    mp->m_next = *abbr_table;
    *abbr_table = mp;
  } else {
    const int n = MAP_HASH(mp->m_mode, mp->m_keys[0]);
    mp->m_next = map_table[n];
    map_table[n] = mp;
  }
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
  mapblock_T *mp, **mpp;
  const char_u *p;
  int n;
  int retval = 0;
  mapblock_T **abbr_table;
  mapblock_T **map_table;
  int noremap;

  map_table = maphash;
  abbr_table = &first_abbr;

  // For ":noremap" don't remap, otherwise do remap.
  if (maptype == MAPTYPE_NOREMAP) {
    noremap = REMAP_NONE;
  } else {
    noremap = REMAP_YES;
  }

  if (args->buffer) {
    // If <buffer> was given, we'll be searching through the buffer's
    // mappings/abbreviations, not the globals.
    map_table = buf->b_maphash;
    abbr_table = &buf->b_first_abbr;
  }
  if (args->script) {
    noremap = REMAP_SCRIPT;
  }

  const bool has_lhs = (args->lhs[0] != NUL);
  const bool has_rhs = args->rhs_lua != LUA_NOREF || (args->rhs[0] != NUL) || args->rhs_is_noop;
  const bool do_print = !has_lhs || (maptype != MAPTYPE_UNMAP && !has_rhs);

  // check for :unmap without argument
  if (maptype == MAPTYPE_UNMAP && !has_lhs) {
    retval = 1;
    goto theend;
  }

  const char_u *lhs = (char_u *)&args->lhs;
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
      lhs = (char_u *)&args->alt_lhs;
      len = (int)args->alt_lhs_len;
    } else if (did_simplify && do_print) {
      // when printing always use the not-simplified map
      lhs = (char_u *)&args->alt_lhs;
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
        p = lhs + utfc_ptr2len((char *)lhs);
        n = 1;
        while (p < lhs + len) {
          n++;                                  // nr of (multi-byte) chars
          last = vim_iswordp(p);                // type of last char
          if (same == -1 && last != first) {
            same = n - 1;                       // count of same char type
          }
          p += utfc_ptr2len((char *)p);
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
              && STRNCMP(mp->m_keys, lhs, (size_t)len) == 0) {
            if (is_abbrev) {
              semsg(_("E224: global abbreviation already exists for %s"),
                    mp->m_keys);
            } else {
              semsg(_("E225: global mapping already exists for %s"), mp->m_keys);
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
              n = mp->m_keylen;
              if (STRNCMP(mp->m_keys, lhs, (size_t)(n < len ? n : len)) == 0) {
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
      if (has_lhs || is_abbrev) {
        // just use one hash
        hash_start = is_abbrev ? 0 : MAP_HASH(mode, lhs[0]);
        hash_end = hash_start + 1;
      } else {
        // need to loop over all hash lists
        hash_start = 0;
        hash_end = 256;
      }
      for (int hash = hash_start; hash < hash_end && !got_int; hash++) {
        mpp = is_abbrev ?  abbr_table :  &(map_table[hash]);
        for (mp = *mpp; mp != NULL && !got_int; mp = *mpp) {
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
            if (round) {              // second round: Try unmap "rhs" string
              n = (int)strlen(mp->m_str);
              p = (char_u *)mp->m_str;
            } else {
              n = mp->m_keylen;
              p = mp->m_keys;
            }
            if (STRNCMP(p, lhs, (size_t)(n < len ? n : len)) == 0) {
              if (maptype == MAPTYPE_UNMAP) {
                // Delete entry.
                // Only accept a full match.  For abbreviations
                // we ignore trailing space when matching with
                // the "lhs", since an abbreviation can't have
                // trailing space.
                if (n != len && (!is_abbrev || round || n > len
                                 || *skipwhite((char *)lhs + n) != NUL)) {
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
                  semsg(_("E226: abbreviation already exists for %s"), p);
                } else {
                  semsg(_("E227: mapping already exists for %s"), p);
                }
                retval = 5;
                goto theend;
              } else {
                // new rhs for existing entry
                mp->m_mode &= ~mode;  // remove mode bits
                if (mp->m_mode == 0 && !did_it) {  // reuse entry
                  XFREE_CLEAR(mp->m_desc);
                  if (!mp->m_simplified) {
                    NLUA_CLEAR_REF(mp->m_luaref);
                    XFREE_CLEAR(mp->m_str);
                    XFREE_CLEAR(mp->m_orig_str);
                  }
                  mp->m_str = args->rhs;
                  mp->m_orig_str = (char *)args->orig_rhs;
                  mp->m_luaref = args->rhs_lua;
                  if (!keyround1_simplified) {
                    args->rhs = NULL;
                    args->orig_rhs = NULL;
                    args->rhs_lua = LUA_NOREF;
                  }
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
                  if (args->desc != NULL) {
                    mp->m_desc = xstrdup(args->desc);
                  }
                  did_it = true;
                }
              }
              if (mp->m_mode == 0) {  // entry can be deleted
                mapblock_free(mpp);
                continue;  // continue with *mpp
              }

              // May need to put this entry into another hash list.
              int new_hash = MAP_HASH(mp->m_mode, mp->m_keys[0]);
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
          msg(_("No abbreviation found"));
        } else {
          msg(_("No mapping found"));
        }
      }
      goto theend;  // listing finished
    }

    if (did_it) {
      continue;  // have added the new entry already
    }

    // Get here when adding a new entry to the maphash[] list or abbrlist.
    map_add(buf, map_table, abbr_table, (char *)lhs, args, noremap, mode, is_abbrev,
            -1,  // sid
            0,   // lnum
            keyround1_simplified);
  }

theend:
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
///                 MAPTYPE_NOREMAP for |noremap|.
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
int do_map(int maptype, char_u *arg, int mode, bool is_abbrev)
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
  char *p;
  int modec;
  int mode;

  p = *cmdp;
  modec = (uint8_t)(*p++);
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
  int mode;
  int local;

  local = (strcmp(arg, "<buffer>") == 0);
  if (!local && *arg != NUL) {
    emsg(_(e_invarg));
    return;
  }

  mode = get_map_mode(&cmdp, forceit);
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
  mapblock_T *mp, **mpp;
  int hash;
  int new_hash;

  for (hash = 0; hash < 256; hash++) {
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
      mp = *mpp;
      if (mp->m_mode & mode) {
        mp->m_mode &= ~mode;
        if (mp->m_mode == 0) {       // entry can be deleted
          mapblock_free(mpp);
          continue;
        }
        // May need to put this entry into another hash list.
        new_hash = MAP_HASH(mp->m_mode, mp->m_keys[0]);
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
  int retval;

  char *buf = NULL;
  const char_u *const rhs = (char_u *)replace_termcodes(str, strlen(str),
                                                        &buf, REPTERM_DO_LT,
                                                        NULL, CPO_TO_CPO_FLAGS);

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

  retval = map_to_exists_mode((char *)rhs, mode, abbr);
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
int map_to_exists_mode(const char *const rhs, const int mode, const bool abbr)
{
  mapblock_T *mp;
  int hash;
  bool exp_buffer = false;

  // Do it twice: once for global maps and once for local maps.
  for (;;) {
    for (hash = 0; hash < 256; hash++) {
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
/// @param cpo_flags  Value of various flags present in &cpo
///
/// @return  NULL when there is a problem.
static char_u *translate_mapping(char_u *str, int cpo_flags)
{
  garray_T ga;
  ga_init(&ga, 1, 40);

  bool cpo_bslash = !(cpo_flags&FLAG_CPO_BSLASH);

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
        ga_concat(&ga, (char *)get_special_key_name(c, modifiers));
        continue;         // for (str)
      }
    }

    if (c == ' ' || c == '\t' || c == Ctrl_J || c == Ctrl_V
        || (c == '\\' && !cpo_bslash)) {
      ga_append(&ga, cpo_bslash ? Ctrl_V : '\\');
    }

    if (c) {
      ga_append(&ga, (char)c);
    }
  }
  ga_append(&ga, NUL);
  return (char_u *)(ga.ga_data);
}

/// Work out what to complete when doing command line completion of mapping
/// or abbreviation names.
///
/// @param forceit  true if '!' given
/// @param isabbrev  true if abbreviation
/// @param isunmap  true if unmap/unabbrev command
char_u *set_context_in_map_cmd(expand_T *xp, char *cmd, char_u *arg, bool forceit, bool isabbrev,
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
    for (;;) {
      if (STRNCMP(arg, "<buffer>", 8) == 0) {
        expand_buffer = true;
        arg = (char_u *)skipwhite((char *)arg + 8);
        continue;
      }
      if (STRNCMP(arg, "<unique>", 8) == 0) {
        arg = (char_u *)skipwhite((char *)arg + 8);
        continue;
      }
      if (STRNCMP(arg, "<nowait>", 8) == 0) {
        arg = (char_u *)skipwhite((char *)arg + 8);
        continue;
      }
      if (STRNCMP(arg, "<silent>", 8) == 0) {
        arg = (char_u *)skipwhite((char *)arg + 8);
        continue;
      }
      if (STRNCMP(arg, "<special>", 9) == 0) {
        arg = (char_u *)skipwhite((char *)arg + 9);
        continue;
      }
      if (STRNCMP(arg, "<script>", 8) == 0) {
        arg = (char_u *)skipwhite((char *)arg + 8);
        continue;
      }
      if (STRNCMP(arg, "<expr>", 6) == 0) {
        arg = (char_u *)skipwhite((char *)arg + 6);
        continue;
      }
      break;
    }
    xp->xp_pattern = (char *)arg;
  }

  return NULL;
}

/// Find all mapping/abbreviation names that match regexp "regmatch".
/// For command line expansion of ":[un]map" and ":[un]abbrev" in all modes.
/// @return OK if matches found, FAIL otherwise.
int ExpandMappings(regmatch_T *regmatch, int *num_file, char ***file)
{
  mapblock_T *mp;
  int hash;
  int count;
  int round;
  char *p;
  int i;

  *num_file = 0;                    // return values in case of FAIL
  *file = NULL;

  // round == 1: Count the matches.
  // round == 2: Build the array to keep the matches.
  for (round = 1; round <= 2; round++) {
    count = 0;

    for (i = 0; i < 7; i++) {
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

      if (vim_regexec(regmatch, p, (colnr_T)0)) {
        if (round == 1) {
          count++;
        } else {
          (*file)[count++] = xstrdup(p);
        }
      }
    }

    for (hash = 0; hash < 256; hash++) {
      if (expand_isabbrev) {
        if (hash > 0) {    // only one abbrev list
          break;           // for (hash)
        }
        mp = first_abbr;
      } else if (expand_buffer) {
        mp = curbuf->b_maphash[hash];
      } else {
        mp = maphash[hash];
      }
      for (; mp; mp = mp->m_next) {
        if (mp->m_mode & expand_mapmodes) {
          p = (char *)translate_mapping(mp->m_keys, CPO_TO_CPO_FLAGS);
          if (p != NULL && vim_regexec(regmatch, p, (colnr_T)0)) {
            if (round == 1) {
              count++;
            } else {
              (*file)[count++] = p;
              p = NULL;
            }
          }
          xfree(p);
        }
      }       // for (mp)
    }     // for (hash)

    if (count == 0) {  // no match found
      break;       // for (round)
    }

    if (round == 1) {
      *file = xmalloc((size_t)count * sizeof(char_u *));
    }
  }   // for (round)

  if (count > 1) {
    // Sort the matches
    sort_strings(*file, count);

    // Remove multiple entries
    char **ptr1 = *file;
    char **ptr2 = ptr1 + 1;
    char **ptr3 = ptr1 + count;

    while (ptr2 < ptr3) {
      if (strcmp(*ptr1, *ptr2)) {
        *++ptr1 = *ptr2++;
      } else {
        xfree(*ptr2++);
        count--;
      }
    }
  }

  *num_file = count;
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
bool check_abbr(int c, char_u *ptr, int col, int mincol)
{
  int len;
  int scol;                     // starting column of the abbr.
  int j;
  char_u *s;
  char_u tb[MB_MAXBYTES + 4];
  mapblock_T *mp;
  mapblock_T *mp2;
  int clen = 0;                 // length in characters
  bool is_id = true;

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

  {
    bool vim_abbr;
    char_u *p = mb_prevptr(ptr, ptr + col);
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
        p += utfc_ptr2len((char *)p);
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
    len = col - scol;
    mp = curbuf->b_first_abbr;
    mp2 = first_abbr;
    if (mp == NULL) {
      mp = mp2;
      mp2 = NULL;
    }
    for (; mp;
         mp->m_next == NULL ? (mp = mp2, mp2 = NULL) :
         (mp = mp->m_next)) {
      int qlen = mp->m_keylen;
      char *q = (char *)mp->m_keys;
      int match;

      if (strchr((const char *)mp->m_keys, K_SPECIAL) != NULL) {
        // Might have K_SPECIAL escaped mp->m_keys.
        q = xstrdup((char *)mp->m_keys);
        vim_unescape_ks((char_u *)q);
        qlen = (int)STRLEN(q);
      }
      // find entries with right mode and keys
      match = (mp->m_mode & State)
              && qlen == len
              && !STRNCMP(q, ptr, (size_t)len);
      if (q != (char *)mp->m_keys) {
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
      j = 0;
      if (c != Ctrl_RSB) {
        // special key code, split up
        if (IS_SPECIAL(c) || c == K_SPECIAL) {
          tb[j++] = K_SPECIAL;
          tb[j++] = (char_u)K_SECOND(c);
          tb[j++] = (char_u)K_THIRD(c);
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
          char_u *escaped = (char_u *)vim_strsave_escape_ks((char *)tb + j);
          if (escaped != NULL) {
            newlen = (int)STRLEN(escaped);
            memmove(tb + j, escaped, (size_t)newlen);
            j += newlen;
            xfree(escaped);
          }
        }
        tb[j] = NUL;
        // insert the last typed char
        (void)ins_typebuf((char *)tb, 1, 0, true, mp->m_silent);
      }
      if (mp->m_expr) {
        s = (char_u *)eval_map_expr(mp, c);
      } else {
        s = (char_u *)mp->m_str;
      }
      if (s != NULL) {
        // insert the to string
        (void)ins_typebuf((char *)s, mp->m_noremap, 0, true, mp->m_silent);
        // no abbrev. for these chars
        typebuf.tb_no_abbr_cnt += (int)STRLEN(s) + j + 1;
        if (mp->m_expr) {
          xfree(s);
        }
      }

      tb[0] = Ctrl_H;
      tb[1] = NUL;
      len = clen;  // Delete characters instead of bytes
      while (len-- > 0) {  // delete the from string
        (void)ins_typebuf((char *)tb, 1, 0, true, mp->m_silent);
      }
      return true;
    }
  }
  return false;
}

/// Evaluate the RHS of a mapping or abbreviations and take care of escaping
/// special characters.
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
    vim_unescape_ks((char_u *)expr);
  }

  // Forbid changing text or using ":normal" to avoid most of the bad side
  // effects.  Also restore the cursor position.
  textlock++;
  ex_normal_lock++;
  set_vim_var_char(c);    // set v:char to the typed character
  const pos_T save_cursor = curwin->w_cursor;
  const int save_msg_col = msg_col;
  const int save_msg_row = msg_row;
  if (mp->m_luaref != LUA_NOREF) {
    Error err = ERROR_INIT;
    Array args = ARRAY_DICT_INIT;
    Object ret = nlua_call_ref(mp->m_luaref, NULL, args, true, &err);
    if (ret.type == kObjectTypeString) {
      p = xstrndup(ret.data.string.data, ret.data.string.size);
    }
    api_free_object(ret);
    if (err.type != kErrorTypeNone) {
      semsg_multiline("E5108: %s", err.msg);
      api_clear_error(&err);
    }
  } else {
    p = eval_to_string(expr, NULL, false);
    xfree(expr);
  }
  textlock--;
  ex_normal_lock--;
  curwin->w_cursor = save_cursor;
  msg_col = save_msg_col;
  msg_row = save_msg_row;

  if (p == NULL) {
    return NULL;
  }

  char *res = NULL;

  if (mp->m_replace_keycodes) {
    replace_termcodes(p, STRLEN(p), &res, REPTERM_DO_LT, NULL, CPO_TO_CPO_FLAGS);
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
  mapblock_T *mp;
  char_u c1, c2, c3;
  char_u *p;
  char *cmd;
  int abbr;
  int hash;
  bool did_cpo = false;

  // Do the loop twice: Once for mappings, once for abbreviations.
  // Then loop over all map hash lists.
  for (abbr = 0; abbr < 2; abbr++) {
    for (hash = 0; hash < 256; hash++) {
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
        for (p = (char_u *)mp->m_str; *p != NUL; p++) {
          if (p[0] == K_SPECIAL && p[1] == KS_EXTRA
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
        c1 = NUL;
        c2 = NUL;
        c3 = NUL;
        if (abbr) {
          cmd = "abbr";
        } else {
          cmd = "map";
        }
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
        do {
          // do this twice if c2 is set, 3 times with c3 */
          // When outputting <> form, need to make sure that 'cpo'
          // is set to the Vim default.
          if (!did_cpo) {
            if (*mp->m_str == NUL) {  // Will use <Nop>.
              did_cpo = true;
            } else {
              const char specials[] = { (char)(uint8_t)K_SPECIAL, NL, NUL };
              if (strpbrk((const char *)mp->m_str, specials) != NULL
                  || strpbrk((const char *)mp->m_keys, specials) != NULL) {
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
              || put_escstr(fd, (char_u *)mp->m_str, 1) == FAIL
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
int put_escstr(FILE *fd, char_u *strstart, int what)
{
  char_u *str = strstart;
  int c;

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

    c = *str;
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
        if (fputs((char *)get_special_key_name(c, modifiers), fd) < 0) {
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
               || (what == 1 && str == strstart && c == ' ')
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
char_u *check_map(char_u *keys, int mode, int exact, int ign_mod, int abbr, mapblock_T **mp_ptr,
                  int *local_ptr, int *rhs_lua)
{
  int len, minlen;
  mapblock_T *mp;
  *rhs_lua = LUA_NOREF;

  len = (int)STRLEN(keys);
  for (int local = 1; local >= 0; local--) {
    // loop over all hash lists
    for (int hash = 0; hash < 256; hash++) {
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
          char_u *s = mp->m_keys;
          int keylen = mp->m_keylen;
          if (ign_mod && keylen >= 3
              && s[0] == K_SPECIAL && s[1] == KS_MODIFIER) {
            s += 3;
            keylen -= 3;
          }
          minlen = keylen < len ? keylen : len;
          if (STRNCMP(s, keys, minlen) == 0) {
            if (mp_ptr != NULL) {
              *mp_ptr = mp;
            }
            if (local_ptr != NULL) {
              *local_ptr = local;
            }
            *rhs_lua = mp->m_luaref;
            return mp->m_luaref == LUA_NOREF ? (char_u *)mp->m_str : NULL;
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

  if (map_to_exists(name, mode, abbr)) {
    rettv->vval.v_number = true;
  } else {
    rettv->vval.v_number = false;
  }
}

/// Fill a Dictionary with all applicable maparg() like dictionaries
///
/// @param mp            The maphash that contains the mapping information
/// @param buffer_value  The "buffer" value
/// @param compatible    True for compatible with old maparg() dict
///
/// @return  A Dictionary.
static Dictionary mapblock_fill_dict(const mapblock_T *const mp, const char *lhsrawalt,
                                     const long buffer_value, const bool compatible)
  FUNC_ATTR_NONNULL_ARG(1)
{
  Dictionary dict = ARRAY_DICT_INIT;
  char *const lhs = str2special_save((const char *)mp->m_keys, compatible, !compatible);
  char *const mapmode = map_mode_to_chars(mp->m_mode);
  varnumber_T noremap_value;

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
    PUT(dict, "callback", LUAREF_OBJ(api_new_luaref(mp->m_luaref)));
  } else {
    PUT(dict, "rhs", STRING_OBJ(compatible
                                ? cstr_to_string(mp->m_orig_str)
                                : cstr_as_string(str2special_save(mp->m_str, false, true))));
  }
  if (mp->m_desc != NULL) {
    PUT(dict, "desc", STRING_OBJ(cstr_to_string(mp->m_desc)));
  }
  PUT(dict, "lhs", STRING_OBJ(cstr_as_string(lhs)));
  PUT(dict, "lhsraw", STRING_OBJ(cstr_to_string((const char *)mp->m_keys)));
  if (lhsrawalt != NULL) {
    // Also add the value for the simplified entry.
    PUT(dict, "lhsrawalt", STRING_OBJ(cstr_to_string(lhsrawalt)));
  }
  PUT(dict, "noremap", INTEGER_OBJ(noremap_value));
  PUT(dict, "script", INTEGER_OBJ(mp->m_noremap == REMAP_SCRIPT ? 1 : 0));
  PUT(dict, "expr", INTEGER_OBJ(mp->m_expr ? 1 : 0));
  PUT(dict, "silent", INTEGER_OBJ(mp->m_silent ? 1 : 0));
  PUT(dict, "sid", INTEGER_OBJ((varnumber_T)mp->m_script_ctx.sc_sid));
  PUT(dict, "lnum", INTEGER_OBJ((varnumber_T)mp->m_script_ctx.sc_lnum));
  PUT(dict, "buffer", INTEGER_OBJ((varnumber_T)buffer_value));
  PUT(dict, "nowait", INTEGER_OBJ(mp->m_nowait ? 1 : 0));
  if (mp->m_replace_keycodes) {
    PUT(dict, "replace_keycodes", INTEGER_OBJ(1));
  }
  PUT(dict, "mode", STRING_OBJ(cstr_as_string(mapmode)));

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

  char_u *keys_simplified
    = (char_u *)replace_termcodes(keys, strlen(keys), &keys_buf, flags, &did_simplify,
                                  CPO_TO_CPO_FLAGS);
  mapblock_T *mp = NULL;
  int buffer_local;
  LuaRef rhs_lua;
  char_u *rhs = check_map(keys_simplified, mode, exact, false, abbr, &mp, &buffer_local, &rhs_lua);
  if (did_simplify) {
    // When the lhs is being simplified the not-simplified keys are
    // preferred for printing, like in do_map().
    (void)replace_termcodes(keys,
                            strlen(keys),
                            &alt_keys_buf, flags | REPTERM_NO_SIMPLIFY, NULL,
                            CPO_TO_CPO_FLAGS);
    rhs = check_map((char_u *)alt_keys_buf, mode, exact, false, abbr, &mp, &buffer_local, &rhs_lua);
  }

  if (!get_dict) {
    // Return a string.
    if (rhs != NULL) {
      if (*rhs == NUL) {
        rettv->vval.v_string = xstrdup("<Nop>");
      } else {
        rettv->vval.v_string = str2special_save((char *)rhs, false, false);
      }
    } else if (rhs_lua != LUA_NOREF) {
      rettv->vval.v_string = nlua_funcref_str(mp->m_luaref);
    }
  } else {
    // Return a dictionary.
    if (mp != NULL && (rhs != NULL || rhs_lua != LUA_NOREF)) {
      Dictionary dict = mapblock_fill_dict(mp,
                                           did_simplify ? (char *)keys_simplified : NULL,
                                           buffer_local, true);
      (void)object_to_vim(DICTIONARY_OBJ(dict), rettv, NULL);
      api_free_dictionary(dict);
    } else {
      // Return an empty dictionary.
      tv_dict_alloc_ret(rettv);
    }
  }

  xfree(keys_buf);
  xfree(alt_keys_buf);
}

/// "mapset()" function
void f_mapset(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  char buf[NUMBUFLEN];
  const char *which = tv_get_string_buf_chk(&argvars[0], buf);
  if (which == NULL) {
    return;
  }
  const int mode = get_map_mode((char **)&which, 0);
  const bool is_abbr = tv_get_number(&argvars[1]) != 0;

  if (argvars[2].v_type != VAR_DICT) {
    emsg(_(e_dictreq));
    return;
  }
  dict_T *d = argvars[2].vval.v_dict;

  // Get the values in the same order as above in get_maparg().
  char *lhs = tv_dict_get_string(d, "lhs", false);
  char *lhsraw = tv_dict_get_string(d, "lhsraw", false);
  char *lhsrawalt = tv_dict_get_string(d, "lhsrawalt", false);
  char *orig_rhs = tv_dict_get_string(d, "rhs", false);
  LuaRef rhs_lua = LUA_NOREF;
  dictitem_T *callback_di = tv_dict_find(d, S_LEN("callback"));
  if (callback_di != NULL) {
    Object callback_obj = vim_to_object(&callback_di->di_tv);
    if (callback_obj.type == kObjectTypeLuaRef && callback_obj.data.luaref != LUA_NOREF) {
      rhs_lua = callback_obj.data.luaref;
      orig_rhs = "";
      callback_obj.data.luaref = LUA_NOREF;
    }
    api_free_object(callback_obj);
  }
  if (lhs == NULL || lhsraw == NULL || orig_rhs == NULL) {
    emsg(_("E460: entries missing in mapset() dict argument"));
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
    .desc = tv_dict_get_string(d, "desc", false),
  };
  set_maparg_rhs(orig_rhs, strlen(orig_rhs), rhs_lua, CPO_TO_CPO_FLAGS, &args);
  scid_T sid = (scid_T)tv_dict_get_number(d, "sid");
  linenr_T lnum = (linenr_T)tv_dict_get_number(d, "lnum");
  bool buffer = tv_dict_get_number(d, "buffer") != 0;
  // mode from the dict is not used

  mapblock_T **map_table = buffer ? curbuf->b_maphash : maphash;
  mapblock_T **abbr_table = buffer ? &curbuf->b_first_abbr : &first_abbr;

  // Delete any existing mapping for this lhs and mode.
  MapArguments unmap_args = MAP_ARGUMENTS_INIT;
  set_maparg_lhs_rhs(lhs, strlen(lhs), "", 0, LUA_NOREF, 0, &unmap_args);
  unmap_args.buffer = buffer;
  buf_do_map(MAPTYPE_UNMAP, &unmap_args, mode, false, curbuf);
  xfree(unmap_args.rhs);
  xfree(unmap_args.orig_rhs);

  if (lhsrawalt != NULL) {
    map_add(curbuf, map_table, abbr_table, lhsrawalt, &args, noremap, mode, is_abbr,
            sid, lnum, true);
  }
  map_add(curbuf, map_table, abbr_table, lhsraw, &args, noremap, mode, is_abbr,
          sid, lnum, false);
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
  set_maparg_lhs_rhs(lhs, strlen(lhs), rhs, strlen(rhs), LUA_NOREF, 0, &args);
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
  unsigned int a = 0;
  assert(langmap_mapga.ga_len >= 0);
  unsigned int b = (unsigned int)langmap_mapga.ga_len;

  // Do a binary search for an existing entry.
  while (a != b) {
    unsigned int i = (a + b) / 2;
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
          ((unsigned int)langmap_mapga.ga_len - a) * sizeof(langmap_entry_T));
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
    langmap_mapchar[i] = (char_u)i;      // we init with a one-to-one map
  }
  ga_init(&langmap_mapga, sizeof(langmap_entry_T), 8);
}

/// Called when langmap option is set; the language map can be
/// changed at any time!
void langmap_set(void)
{
  char_u *p;
  char_u *p2;
  int from, to;

  ga_clear(&langmap_mapga);                 // clear the previous map first
  langmap_init();                           // back to one-to-one map

  for (p = (char_u *)p_langmap; p[0] != NUL;) {
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
      from = utf_ptr2char((char *)p);
      to = NUL;
      if (p2 == NULL) {
        MB_PTR_ADV(p);
        if (p[0] != ',') {
          if (p[0] == '\\') {
            p++;
          }
          to = utf_ptr2char((char *)p);
        }
      } else {
        if (p2[0] != ',') {
          if (p2[0] == '\\') {
            p2++;
          }
          to = utf_ptr2char((char *)p2);
        }
      }
      if (to == NUL) {
        semsg(_("E357: 'langmap': Matching character missing for %s"),
              transchar(from));
        return;
      }

      if (from >= 256) {
        langmap_set_entry(from, to);
      } else {
        assert(to <= UCHAR_MAX);
        langmap_mapchar[from & 255] = (char_u)to;
      }

      // Advance to next pair
      MB_PTR_ADV(p);
      if (p2 != NULL) {
        MB_PTR_ADV(p2);
        if (*p == ';') {
          p = p2;
          if (p[0] != NUL) {
            if (p[0] != ',') {
              semsg(_("E358: 'langmap': Extra characters after semicolon: %s"),
                    p);
              return;
            }
            p++;
          }
          break;
        }
      }
    }
  }
}

static void do_exmap(exarg_T *eap, int isabbrev)
{
  int mode;
  char *cmdp = eap->cmd;
  mode = get_map_mode(&cmdp, eap->forceit || isabbrev);

  switch (do_map((*cmdp == 'n') ? MAPTYPE_NOREMAP
                 : (*cmdp == 'u') ? MAPTYPE_UNMAP : MAPTYPE_MAP,
                 (char_u *)eap->arg, mode, isabbrev)) {
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
  // If we are sourcing .exrc or .vimrc in current directory we
  // print the mappings for security reasons.
  if (secure) {
    secure = 2;
    msg_outtrans(eap->cmd);
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

  if (opts != NULL && opts->callback.type == kObjectTypeLuaRef) {
    lua_funcref = opts->callback.data.luaref;
    opts->callback.data.luaref = LUA_NOREF;
  }
  MapArguments parsed_args = MAP_ARGUMENTS_INIT;
  if (opts) {
#define KEY_TO_BOOL(name) \
  parsed_args.name = api_object_to_bool(opts->name, #name, false, err); \
  if (ERROR_SET(err)) { \
    goto fail_and_free; \
  }

    KEY_TO_BOOL(nowait);
    KEY_TO_BOOL(noremap);
    KEY_TO_BOOL(silent);
    KEY_TO_BOOL(script);
    KEY_TO_BOOL(expr);
    KEY_TO_BOOL(unique);
    KEY_TO_BOOL(replace_keycodes);
#undef KEY_TO_BOOL
  }
  parsed_args.buffer = !global;

  if (parsed_args.replace_keycodes && !parsed_args.expr) {
    api_set_error(err, kErrorTypeValidation,  "\"replace_keycodes\" requires \"expr\"");
    goto fail_and_free;
  }

  if (!set_maparg_lhs_rhs(lhs.data, lhs.size,
                          rhs.data, rhs.size, lua_funcref,
                          CPO_TO_CPO_FLAGS, &parsed_args)) {
    api_set_error(err, kErrorTypeValidation,  "LHS exceeds maximum map length: %s", lhs.data);
    goto fail_and_free;
  }

  if (opts != NULL && opts->desc.type == kObjectTypeString) {
    parsed_args.desc = string_to_cstr(opts->desc.data.string);
  } else {
    parsed_args.desc = NULL;
  }
  if (parsed_args.lhs_len > MAXMAPLEN || parsed_args.alt_lhs_len > MAXMAPLEN) {
    api_set_error(err, kErrorTypeValidation,  "LHS exceeds maximum map length: %s", lhs.data);
    goto fail_and_free;
  }

  if (mode.size > 1) {
    api_set_error(err, kErrorTypeValidation, "Shortname is too long: %s", mode.data);
    goto fail_and_free;
  }
  int mode_val;  // integer value of the mapping mode, to be passed to do_map()
  char *p = (mode.size) ? mode.data : "m";
  if (STRNCMP(p, "!", 2) == 0) {
    mode_val = get_map_mode(&p, true);  // mapmode-ic
  } else {
    mode_val = get_map_mode(&p, false);
    if (mode_val == (MODE_VISUAL | MODE_SELECT | MODE_NORMAL | MODE_OP_PENDING) && mode.size > 0) {
      // get_map_mode() treats unrecognized mode shortnames as ":map".
      // This is an error unless the given shortname was empty string "".
      api_set_error(err, kErrorTypeValidation, "Invalid mode shortname: \"%s\"", p);
      goto fail_and_free;
    }
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

  switch (buf_do_map(maptype_val, &parsed_args, mode_val, 0, target_buf)) {
  case 0:
    break;
  case 1:
    api_set_error(err, kErrorTypeException, (char *)e_invarg, 0);
    goto fail_and_free;
  case 2:
    api_set_error(err, kErrorTypeException, (char *)e_nomap, 0);
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
ArrayOf(Dictionary) keymap_array(String mode, buf_T *buf)
{
  Array mappings = ARRAY_DICT_INIT;

  // Convert the string mode to the integer mode
  // that is stored within each mapblock
  char *p = mode.data;
  int int_mode = get_map_mode(&p, 0);

  // Determine the desired buffer value
  long buffer_value = (buf == NULL) ? 0 : buf->handle;

  for (int i = 0; i < MAX_MAPHASH; i++) {
    for (const mapblock_T *current_maphash = get_maphash(i, buf);
         current_maphash;
         current_maphash = current_maphash->m_next) {
      if (current_maphash->m_simplified) {
        continue;
      }
      // Check for correct mode
      if (int_mode & current_maphash->m_mode) {
        ADD(mappings,
            DICTIONARY_OBJ(mapblock_fill_dict(current_maphash, NULL, buffer_value, false)));
      }
    }
  }

  return mappings;
}
