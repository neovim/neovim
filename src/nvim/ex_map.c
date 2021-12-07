// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// ex_map.c: functions for mappings and abbreviations

#include <assert.h>
#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "nvim/ascii.h"
#include "nvim/assert.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/event/loop.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/ex_map.h"
#include "nvim/ex_session.h"
#include "nvim/func_attr.h"
#include "nvim/garray.h"
#include "nvim/getchar.h"
#include "nvim/keymap.h"
#include "nvim/lua/executor.h"
#include "nvim/main.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/os/fileio.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/plines.h"
#include "nvim/regexp.h"
#include "nvim/screen.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/ui.h"
#include "nvim/undo.h"
#include "nvim/vim.h"

/// List used for abbreviations.
static mapblock_T *first_abbr = NULL;  // first entry in abbrlist

// Each mapping is put in one of the MAX_MAPHASH hash lists,
// to speed up finding it.
static mapblock_T *(maphash[MAX_MAPHASH]);
static bool maphash_valid = false;

// Make a hash value for a mapping.
// "mode" is the lower 4 bits of the State for the mapping.
// "c1" is the first character of the "lhs".
// Returns a value between 0 and 255, index in maphash.
// Put Normal/Visual mode mappings mostly separately from Insert/Cmdline mode.
#define MAP_HASH(mode, \
                 c1) (((mode) & \
                       (NORMAL + VISUAL + SELECTMODE + \
                        OP_PENDING + TERM_FOCUS)) ? (c1) : ((c1) ^ 0x80))

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "ex_map.c.generated.h"
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

bool is_maphash_valid(void)
{
  return maphash_valid;
}

/// Initialize maphash[] for first use.
static void validate_maphash(void)
{
  if (!maphash_valid) {
    memset(maphash, 0, sizeof(maphash));
    maphash_valid = true;
  }
}

/// Delete one entry from the abbrlist or maphash[].
/// "mpp" is a pointer to the m_next field of the PREVIOUS entry!
static void mapblock_free(mapblock_T **mpp)
{
  mapblock_T *mp;

  mp = *mpp;
  xfree(mp->m_keys);
  xfree(mp->m_str);
  xfree(mp->m_orig_str);
  *mpp = mp->m_next;
  xfree(mp);
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
/// If RHS is equal to "<Nop>", `rhs` will be the empty string, `rhs_len`
/// will be zero, and `rhs_is_noop` will be set to true.
///
/// Any memory allocated by @ref replace_termcodes is freed before this function
/// returns.
///
/// @param[in] orig_lhs   Original mapping LHS, with characters to replace.
/// @param[in] orig_lhs_len   `strlen` of orig_lhs.
/// @param[in] orig_rhs   Original mapping RHS, with characters to replace.
/// @param[in] orig_rhs_len   `strlen` of orig_rhs.
/// @param[in] cpo_flags  See param docs for @ref replace_termcodes.
/// @param[out] mapargs   MapArguments struct holding the replaced strings.
void set_maparg_lhs_rhs(const char_u *orig_lhs, const size_t orig_lhs_len, const char_u *orig_rhs,
                        const size_t orig_rhs_len, int cpo_flags, MapArguments *mapargs)
{
  char_u *lhs_buf = NULL;
  char_u *rhs_buf = NULL;

  // If mapping has been given as ^V<C_UP> say, then replace the term codes
  // with the appropriate two bytes. If it is a shifted special key, unshift
  // it too, giving another two bytes.
  //
  // replace_termcodes() may move the result to allocated memory, which
  // needs to be freed later (*lhs_buf and *rhs_buf).
  // replace_termcodes() also removes CTRL-Vs and sometimes backslashes.
  char_u *replaced = replace_termcodes(orig_lhs, orig_lhs_len, &lhs_buf,
                                       true, true, true, cpo_flags);
  mapargs->lhs_len = STRLEN(replaced);
  STRLCPY(mapargs->lhs, replaced, sizeof(mapargs->lhs));

  mapargs->orig_rhs_len = orig_rhs_len;
  mapargs->orig_rhs = xcalloc(mapargs->orig_rhs_len + 1, sizeof(char_u));
  STRLCPY(mapargs->orig_rhs, orig_rhs, mapargs->orig_rhs_len + 1);

  if (STRICMP(orig_rhs, "<nop>") == 0) {  // "<Nop>" means nothing
    mapargs->rhs = xcalloc(1, sizeof(char_u));  // single null-char
    mapargs->rhs_len = 0;
    mapargs->rhs_is_noop = true;
  } else {
    replaced = replace_termcodes(orig_rhs, orig_rhs_len, &rhs_buf,
                                 false, true, true, cpo_flags);
    mapargs->rhs_len = STRLEN(replaced);
    mapargs->rhs_is_noop = false;
    mapargs->rhs = xcalloc(mapargs->rhs_len + 1, sizeof(char_u));
    STRLCPY(mapargs->rhs, replaced, mapargs->rhs_len + 1);
  }

  xfree(lhs_buf);
  xfree(rhs_buf);
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
int str_to_mapargs(const char_u *strargs, bool is_unmap, MapArguments *mapargs)
{
  const char_u *to_parse = strargs;
  to_parse = skipwhite(to_parse);
  MapArguments parsed_args;  // copy these into mapargs "all at once" when done
  memset(&parsed_args, 0, sizeof(parsed_args));

  // Accept <buffer>, <nowait>, <silent>, <expr>, <script>, and <unique> in
  // any order.
  while (true) {
    if (STRNCMP(to_parse, "<buffer>", 8) == 0) {
      to_parse = skipwhite(to_parse + 8);
      parsed_args.buffer = true;
      continue;
    }

    if (STRNCMP(to_parse, "<nowait>", 8) == 0) {
      to_parse = skipwhite(to_parse + 8);
      parsed_args.nowait = true;
      continue;
    }

    if (STRNCMP(to_parse, "<silent>", 8) == 0) {
      to_parse = skipwhite(to_parse + 8);
      parsed_args.silent = true;
      continue;
    }

    // Ignore obsolete "<special>" modifier.
    if (STRNCMP(to_parse, "<special>", 9) == 0) {
      to_parse = skipwhite(to_parse + 9);
      continue;
    }

    if (STRNCMP(to_parse, "<script>", 8) == 0) {
      to_parse = skipwhite(to_parse + 8);
      parsed_args.script = true;
      continue;
    }

    if (STRNCMP(to_parse, "<expr>", 6) == 0) {
      to_parse = skipwhite(to_parse + 6);
      parsed_args.expr = true;
      continue;
    }

    if (STRNCMP(to_parse, "<unique>", 8) == 0) {
      to_parse = skipwhite(to_parse + 8);
      parsed_args.unique = true;
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
  const char_u *lhs_end = to_parse;
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
  const char_u *rhs_start = skipwhite(lhs_end);

  // Given {lhs} might be larger than MAXMAPLEN before replace_termcodes
  // (e.g. "<Space>" is longer than ' '), so first copy into a buffer.
  size_t orig_lhs_len = (size_t)(lhs_end - to_parse);
  char_u *lhs_to_replace = xcalloc(orig_lhs_len + 1, sizeof(char_u));
  STRLCPY(lhs_to_replace, to_parse, orig_lhs_len + 1);

  size_t orig_rhs_len = STRLEN(rhs_start);
  set_maparg_lhs_rhs(lhs_to_replace, orig_lhs_len,
                     rhs_start, orig_rhs_len,
                     CPO_TO_CPO_FLAGS, &parsed_args);

  xfree(lhs_to_replace);

  *mapargs = parsed_args;

  if (parsed_args.lhs_len > MAXMAPLEN) {
    return 1;
  }
  return 0;
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
int buf_do_map(int maptype, MapArguments *args, int mode, bool is_abbrev, buf_T *buf)
{
  mapblock_T *mp, **mpp;
  char_u *p;
  int n;
  int len = 0;  // init for GCC
  int did_it = false;
  int did_local = false;
  int round;
  int retval = 0;
  int hash;
  int new_hash;
  mapblock_T **abbr_table;
  mapblock_T **map_table;
  int noremap;

  map_table = maphash;
  abbr_table = &first_abbr;

  // For ":noremap" don't remap, otherwise do remap.
  if (maptype == 2) {
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

  validate_maphash();

  bool has_lhs = (args->lhs[0] != NUL);
  bool has_rhs = (args->rhs[0] != NUL) || args->rhs_is_noop;

  // check for :unmap without argument
  if (maptype == 1 && !has_lhs) {
    retval = 1;
    goto theend;
  }

  char_u *lhs = (char_u *)&args->lhs;
  char_u *rhs = args->rhs;
  char_u *orig_rhs = args->orig_rhs;

  // check arguments and translate function keys
  if (has_lhs) {
    len = (int)args->lhs_len;
    if (len > MAXMAPLEN) {
      retval = 1;
      goto theend;
    }

    if (is_abbrev && maptype != 1) {
      //
      // If an abbreviation ends in a keyword character, the
      // rest must be all keyword-char or all non-keyword-char.
      // Otherwise we won't be able to find the start of it in a
      // vi-compatible way.
      //
      int same = -1;

      const int first = vim_iswordp(lhs);
      int last = first;
      p = lhs + utfc_ptr2len(lhs);
      n = 1;
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

  if (!has_lhs || (maptype != 1 && !has_rhs)) {
    msg_start();
  }

  // Check if a new local mapping wasn't already defined globally.
  if (map_table == buf->b_maphash && has_lhs && has_rhs && maptype != 1) {
    // need to loop over all global hash lists
    for (hash = 0; hash < 256 && !got_int; hash++) {
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
            && args->unique
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
  if (map_table != buf->b_maphash && !has_rhs && maptype != 1) {
    // need to loop over all global hash lists
    for (hash = 0; hash < 256 && !got_int; hash++) {
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
        if ((mp->m_mode & mode) != 0) {
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
  for (round = 0; (round == 0 || maptype == 1) && round <= 1
       && !did_it && !got_int; round++) {
    // need to loop over all hash lists
    for (hash = 0; hash < 256 && !got_int; hash++) {
      if (is_abbrev) {
        if (hash > 0) {  // there is only one abbreviation list
          break;
        }
        mpp = abbr_table;
      } else {
        mpp = &(map_table[hash]);
      }
      for (mp = *mpp; mp != NULL && !got_int; mp = *mpp) {
        if (!(mp->m_mode & mode)) {         // skip entries with wrong mode
          mpp = &(mp->m_next);
          continue;
        }
        if (!has_lhs) {                      // show all entries
          showmap(mp, map_table != maphash);
          did_it = true;
        } else {                          // do we have a match?
          if (round) {              // second round: Try unmap "rhs" string
            n = (int)STRLEN(mp->m_str);
            p = mp->m_str;
          } else {
            n = mp->m_keylen;
            p = mp->m_keys;
          }
          if (STRNCMP(p, lhs, (size_t)(n < len ? n : len)) == 0) {
            if (maptype == 1) {  // delete entry
              // Only accept a full match.  For abbreviations we
              // ignore trailing space when matching with the
              // "lhs", since an abbreviation can't have
              // trailing space.
              if (n != len && (!is_abbrev || round || n > len
                               || *skipwhite(lhs + n) != NUL)) {
                mpp = &(mp->m_next);
                continue;
              }
              // We reset the indicated mode bits. If nothing is
              // left the entry is deleted below.
              mp->m_mode &= ~mode;
              did_it = true;  // remember we did something
            } else if (!has_rhs) {  // show matching entry
              showmap(mp, map_table != maphash);
              did_it = true;
            } else if (n != len) {  // new entry is ambiguous
              mpp = &(mp->m_next);
              continue;
            } else if (args->unique) {
              if (is_abbrev) {
                semsg(_("E226: abbreviation already exists for %s"), p);
              } else {
                semsg(_("E227: mapping already exists for %s"), p);
              }
              retval = 5;
              goto theend;
            } else {  // new rhs for existing entry
              mp->m_mode &= ~mode;  // remove mode bits
              if (mp->m_mode == 0 && !did_it) {  // reuse entry
                xfree(mp->m_str);
                mp->m_str = vim_strsave(rhs);
                xfree(mp->m_orig_str);
                mp->m_orig_str = vim_strsave(orig_rhs);
                mp->m_noremap = noremap;
                mp->m_nowait = args->nowait;
                mp->m_silent = args->silent;
                mp->m_mode = mode;
                mp->m_expr = args->expr;
                mp->m_script_ctx = current_sctx;
                mp->m_script_ctx.sc_lnum += sourcing_lnum;
                did_it = true;
              }
            }
            if (mp->m_mode == 0) {  // entry can be deleted
              mapblock_free(mpp);
              continue;  // continue with *mpp
            }

            // May need to put this entry into another hash list.
            new_hash = MAP_HASH(mp->m_mode, mp->m_keys[0]);
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

  if (maptype == 1) {  // delete entry
    if (!did_it) {
      retval = 2;  // no match
    } else if (*lhs == Ctrl_C) {
      // If CTRL-C has been unmapped, reuse it for Interrupting.
      if (map_table == buf->b_maphash) {
        buf->b_mapped_ctrl_c &= ~mode;
      } else {
        mapped_ctrl_c &= ~mode;
      }
    }
    goto theend;
  }

  if (!has_lhs || !has_rhs) {  // print entries
    if (!did_it && !did_local) {
      if (is_abbrev) {
        msg(_("No abbreviation found"));
      } else {
        msg(_("No mapping found"));
      }
    }
    goto theend;  // listing finished
  }

  if (did_it) {  // have added the new entry already
    goto theend;
  }

  // Get here when adding a new entry to the maphash[] list or abbrlist.
  mp = xmalloc(sizeof(mapblock_T));

  // If CTRL-C has been mapped, don't always use it for Interrupting.
  if (*lhs == Ctrl_C) {
    if (map_table == buf->b_maphash) {
      buf->b_mapped_ctrl_c |= mode;
    } else {
      mapped_ctrl_c |= mode;
    }
  }

  mp->m_keys = vim_strsave(lhs);
  mp->m_str = vim_strsave(rhs);
  mp->m_orig_str = vim_strsave(orig_rhs);
  mp->m_keylen = (int)STRLEN(mp->m_keys);
  mp->m_noremap = noremap;
  mp->m_nowait = args->nowait;
  mp->m_silent = args->silent;
  mp->m_mode = mode;
  mp->m_expr = args->expr;
  mp->m_script_ctx = current_sctx;
  mp->m_script_ctx.sc_lnum += sourcing_lnum;

  // add the new entry in front of the abbrlist or maphash[] list
  if (is_abbrev) {
    mp->m_next = *abbr_table;
    *abbr_table = mp;
  } else {
    n = MAP_HASH(mp->m_mode, mp->m_keys[0]);
    mp->m_next = map_table[n];
    map_table[n] = mp;
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
/// for :map   mode is NORMAL + VISUAL + SELECTMODE + OP_PENDING
/// for :map!  mode is INSERT + CMDLINE
/// for :cmap  mode is CMDLINE
/// for :imap  mode is INSERT
/// for :lmap  mode is LANGMAP
/// for :nmap  mode is NORMAL
/// for :vmap  mode is VISUAL + SELECTMODE
/// for :xmap  mode is VISUAL
/// for :smap  mode is SELECTMODE
/// for :omap  mode is OP_PENDING
/// for :tmap  mode is TERM_FOCUS
///
/// for :abbr  mode is INSERT + CMDLINE
/// for :iabbr mode is INSERT
/// for :cabbr mode is CMDLINE
/// ```
///
/// @param maptype  0 for |:map|, 1 for |:unmap|, 2 for |noremap|.
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
  int result = str_to_mapargs(arg, maptype == 1, &parsed_args);
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
int get_map_mode(char_u **cmdp, bool forceit)
{
  char_u *p;
  int modec;
  int mode;

  p = *cmdp;
  modec = *p++;
  if (modec == 'i') {
    mode = INSERT;                              // :imap
  } else if (modec == 'l') {
    mode = LANGMAP;                             // :lmap
  } else if (modec == 'c') {
    mode = CMDLINE;                             // :cmap
  } else if (modec == 'n' && *p != 'o') {       // avoid :noremap
    mode = NORMAL;                              // :nmap
  } else if (modec == 'v') {
    mode = VISUAL + SELECTMODE;                 // :vmap
  } else if (modec == 'x') {
    mode = VISUAL;                              // :xmap
  } else if (modec == 's') {
    mode = SELECTMODE;                          // :smap
  } else if (modec == 'o') {
    mode = OP_PENDING;                          // :omap
  } else if (modec == 't') {
    mode = TERM_FOCUS;                          // :tmap
  } else {
    p--;
    if (forceit) {
      mode = INSERT + CMDLINE;                  // :map !
    } else {
      mode = VISUAL + SELECTMODE + NORMAL + OP_PENDING;  // :map
    }
  }

  *cmdp = p;
  return mode;
}

/// Clear all mappings or abbreviations.
/// 'abbr' should be FALSE for mappings, TRUE for abbreviations.
void map_clear_mode(char_u *cmdp, char_u *arg, int forceit, int abbr)
{
  int mode;
  int local;

  local = (STRCMP(arg, "<buffer>") == 0);
  if (!local && *arg != NUL) {
    emsg(_(e_invarg));
    return;
  }

  mode = get_map_mode(&cmdp, forceit);
  map_clear_int(curbuf, mode,
                local,
                abbr);
}

/// Clear all mappings in "mode".
///
/// @param buf,  buffer for local mappings
/// @param mode  mode in which to delete
/// @param local  true for buffer-local mappings
/// @param abbr  true for abbreviations
void map_clear_int(buf_T *buf, int mode, bool local, bool abbr)
{
  mapblock_T *mp, **mpp;
  int hash;
  int new_hash;

  validate_maphash();

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

/// Return characters to represent the map mode in an allocated string
///
/// @return [allocated] NUL-terminated string with characters.
char *map_mode_to_chars(int mode)
  FUNC_ATTR_MALLOC FUNC_ATTR_NONNULL_RET
{
  garray_T mapmode;

  ga_init(&mapmode, 1, 7);

  if ((mode & (INSERT + CMDLINE)) == INSERT + CMDLINE) {
    ga_append(&mapmode, '!');                           // :map!
  } else if (mode & INSERT) {
    ga_append(&mapmode, 'i');                           // :imap
  } else if (mode & LANGMAP) {
    ga_append(&mapmode, 'l');                           // :lmap
  } else if (mode & CMDLINE) {
    ga_append(&mapmode, 'c');                           // :cmap
  } else if ((mode & (NORMAL + VISUAL + SELECTMODE + OP_PENDING))
             == NORMAL + VISUAL + SELECTMODE + OP_PENDING) {
    ga_append(&mapmode, ' ');                           // :map
  } else {
    if (mode & NORMAL) {
      ga_append(&mapmode, 'n');                         // :nmap
    }
    if (mode & OP_PENDING) {
      ga_append(&mapmode, 'o');                         // :omap
    }
    if (mode & TERM_FOCUS) {
      ga_append(&mapmode, 't');                         // :tmap
    }
    if ((mode & (VISUAL + SELECTMODE)) == VISUAL + SELECTMODE) {
      ga_append(&mapmode, 'v');                         // :vmap
    } else {
      if (mode & VISUAL) {
        ga_append(&mapmode, 'x');                       // :xmap
      }
      if (mode & SELECTMODE) {
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

  if (message_filtered(mp->m_keys) && message_filtered(mp->m_str)) {
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
  len = (size_t)msg_outtrans_special(mp->m_keys, true, 0);
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

  // Use FALSE below if we only want things like <Up> to show up as such on
  // the rhs, and not M-x etc, TRUE gets both -- webb
  if (*mp->m_str == NUL) {
    msg_puts_attr("<Nop>", HL_ATTR(HLF_8));
  } else {
    // Remove escaping of CSI, because "m_str" is in a format to be used
    // as typeahead.
    char_u *s = vim_strsave(mp->m_str);
    vim_unescape_csi(s);
    msg_outtrans_special(s, false, 0);
    xfree(s);
  }
  if (p_verbose > 0) {
    last_set_msg(mp->m_script_ctx);
  }
  ui_flush();                          // show one line at a time
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

  char_u *buf;
  char_u *const rhs = replace_termcodes((const char_u *)str, strlen(str), &buf,
                                        false, true, true,
                                        CPO_TO_CPO_FLAGS);

#define MAPMODE(mode, modechars, chr, modeflags) \
  do { \
    if (strchr(modechars, chr) != NULL) { \
      mode |= modeflags; \
    } \
  } while (0)
  MAPMODE(mode, modechars, 'n', NORMAL);
  MAPMODE(mode, modechars, 'v', VISUAL|SELECTMODE);
  MAPMODE(mode, modechars, 'x', VISUAL);
  MAPMODE(mode, modechars, 's', SELECTMODE);
  MAPMODE(mode, modechars, 'o', OP_PENDING);
  MAPMODE(mode, modechars, 'i', INSERT);
  MAPMODE(mode, modechars, 'l', LANGMAP);
  MAPMODE(mode, modechars, 'c', CMDLINE);
#undef MAPMODE

  retval = map_to_exists_mode((const char *)rhs, mode, abbr);
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

  validate_maphash();

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
        if ((mp->m_mode & mode)
            && strstr((char *)mp->m_str, rhs) != NULL) {
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

// Used below when expanding mapping/abbreviation names.
static int expand_mapmodes = 0;
static bool expand_isabbrev = false;
static bool expand_buffer = false;

/// Work out what to complete when doing command line completion of mapping
/// or abbreviation names.
///
/// @param forceit  true if '!' given
/// @param isabbrev  true if abbreviation
/// @param isunmap  true if unmap/unabbrev command
char_u *set_context_in_map_cmd(expand_T *xp, char_u *cmd, char_u *arg, bool forceit, bool isabbrev,
                               bool isunmap, cmdidx_T cmdidx)
{
  if (forceit && cmdidx != CMD_map && cmdidx != CMD_unmap) {
    xp->xp_context = EXPAND_NOTHING;
  } else {
    if (isunmap) {
      expand_mapmodes = get_map_mode(&cmd, forceit || isabbrev);
    } else {
      expand_mapmodes = INSERT + CMDLINE;
      if (!isabbrev) {
        expand_mapmodes += VISUAL + SELECTMODE + NORMAL + OP_PENDING;
      }
    }
    expand_isabbrev = isabbrev;
    xp->xp_context = EXPAND_MAPPINGS;
    expand_buffer = false;
    for (;;) {
      if (STRNCMP(arg, "<buffer>", 8) == 0) {
        expand_buffer = true;
        arg = skipwhite(arg + 8);
        continue;
      }
      if (STRNCMP(arg, "<unique>", 8) == 0) {
        arg = skipwhite(arg + 8);
        continue;
      }
      if (STRNCMP(arg, "<nowait>", 8) == 0) {
        arg = skipwhite(arg + 8);
        continue;
      }
      if (STRNCMP(arg, "<silent>", 8) == 0) {
        arg = skipwhite(arg + 8);
        continue;
      }
      if (STRNCMP(arg, "<special>", 9) == 0) {
        arg = skipwhite(arg + 9);
        continue;
      }
      if (STRNCMP(arg, "<script>", 8) == 0) {
        arg = skipwhite(arg + 8);
        continue;
      }
      if (STRNCMP(arg, "<expr>", 6) == 0) {
        arg = skipwhite(arg + 6);
        continue;
      }
      break;
    }
    xp->xp_pattern = arg;
  }

  return NULL;
}

// Find all mapping/abbreviation names that match regexp "regmatch".
// For command line expansion of ":[un]map" and ":[un]abbrev" in all modes.
// Return OK if matches found, FAIL otherwise.
int ExpandMappings(regmatch_T *regmatch, int *num_file, char_u ***file)
{
  mapblock_T *mp;
  int hash;
  int count;
  int round;
  char_u *p;
  int i;

  validate_maphash();

  *num_file = 0;                    // return values in case of FAIL
  *file = NULL;

  // round == 1: Count the matches.
  // round == 2: Build the array to keep the matches.
  for (round = 1; round <= 2; round++) {
    count = 0;

    for (i = 0; i < 7; i++) {
      if (i == 0) {
        p = (char_u *)"<silent>";
      } else if (i == 1) {
        p = (char_u *)"<unique>";
      } else if (i == 2) {
        p = (char_u *)"<script>";
      } else if (i == 3) {
        p = (char_u *)"<expr>";
      } else if (i == 4 && !expand_buffer) {
        p = (char_u *)"<buffer>";
      } else if (i == 5) {
        p = (char_u *)"<nowait>";
      } else if (i == 6) {
        p = (char_u *)"<special>";
      } else {
        continue;
      }

      if (vim_regexec(regmatch, p, (colnr_T)0)) {
        if (round == 1) {
          count++;
        } else {
          (*file)[count++] = vim_strsave(p);
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
          p = translate_mapping(mp->m_keys, CPO_TO_CPO_FLAGS);
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
      *file = (char_u **)xmalloc((size_t)count * sizeof(char_u *));
    }
  }   // for (round)

  if (count > 1) {
    char_u **ptr1;
    char_u **ptr2;
    char_u **ptr3;

    // Sort the matches
    sort_strings(*file, count);

    // Remove multiple entries
    ptr1 = *file;
    ptr2 = ptr1 + 1;
    ptr3 = ptr1 + count;

    while (ptr2 < ptr3) {
      if (STRCMP(*ptr1, *ptr2)) {
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
      char_u *q = mp->m_keys;
      int match;

      if (strchr((const char *)mp->m_keys, K_SPECIAL) != NULL) {
        // Might have CSI escaped mp->m_keys.
        q = vim_strsave(mp->m_keys);
        vim_unescape_csi(q);
        qlen = (int)STRLEN(q);
      }
      // find entries with right mode and keys
      match = (mp->m_mode & State)
              && qlen == len
              && !STRNCMP(q, ptr, (size_t)len);
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
      // Characters where IS_SPECIAL() == TRUE: key codes, need
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
          int newlen = utf_char2bytes(c, tb + j);
          tb[j + newlen] = NUL;
          // Need to escape K_SPECIAL.
          char_u *escaped = vim_strsave_escape_csi(tb + j);
          if (escaped != NULL) {
            newlen = (int)STRLEN(escaped);
            memmove(tb + j, escaped, (size_t)newlen);
            j += newlen;
            xfree(escaped);
          }
        }
        tb[j] = NUL;
        // insert the last typed char
        (void)ins_typebuf(tb, 1, 0, true, mp->m_silent);
      }
      if (mp->m_expr) {
        s = eval_map_expr(mp->m_str, c);
      } else {
        s = mp->m_str;
      }
      if (s != NULL) {
        // insert the to string
        (void)ins_typebuf(s, mp->m_noremap, 0, true, mp->m_silent);
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
        (void)ins_typebuf(tb, 1, 0, true, mp->m_silent);
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
char_u *eval_map_expr(char_u *str, int c)
{
  char_u *res;
  char_u *p;
  char_u *expr;
  char_u *save_cmd;
  pos_T save_cursor;
  int save_msg_col;
  int save_msg_row;

  // Remove escaping of CSI, because "str" is in a format to be used as
  // typeahead.
  expr = vim_strsave(str);
  vim_unescape_csi(expr);

  save_cmd = save_cmdline_alloc();

  // Forbid changing text or using ":normal" to avoid most of the bad side
  // effects.  Also restore the cursor position.
  textlock++;
  ex_normal_lock++;
  set_vim_var_char(c);    // set v:char to the typed character
  save_cursor = curwin->w_cursor;
  save_msg_col = msg_col;
  save_msg_row = msg_row;
  p = eval_to_string(expr, NULL, false);
  textlock--;
  ex_normal_lock--;
  curwin->w_cursor = save_cursor;
  msg_col = save_msg_col;
  msg_row = save_msg_row;

  restore_cmdline_alloc(save_cmd);
  xfree(expr);

  if (p == NULL) {
    return NULL;
  }
  // Escape CSI in the result to be able to use the string as typeahead.
  res = vim_strsave_escape_csi(p);
  xfree(p);

  return res;
}

/// Copy "p" to allocated memory, escaping K_SPECIAL and CSI so that the result
/// can be put in the typeahead buffer.
char_u *vim_strsave_escape_csi(char_u *p)
{
  // Need a buffer to hold up to three times as much.  Four in case of an
  // illegal utf-8 byte:
  // 0xc0 -> 0xc3 - 0x80 -> 0xc3 K_SPECIAL KS_SPECIAL KE_FILLER
  char_u *res = xmalloc(STRLEN(p) * 4 + 1);
  char_u *d = res;
  for (char_u *s = p; *s != NUL;) {
    if (s[0] == K_SPECIAL && s[1] != NUL && s[2] != NUL) {
      // Copy special key unmodified.
      *d++ = *s++;
      *d++ = *s++;
      *d++ = *s++;
    } else {
      // Add character, possibly multi-byte to destination, escaping
      // CSI and K_SPECIAL. Be careful, it can be an illegal byte!
      d = add_char2buf(utf_ptr2char(s), d);
      s += utf_ptr2len(s);
    }
  }
  *d = NUL;

  return res;
}

/// Remove escaping from CSI and K_SPECIAL characters.  Reverse of
/// vim_strsave_escape_csi().  Works in-place.
void vim_unescape_csi(char_u *p)
{
  char_u *s = p, *d = p;

  while (*s != NUL) {
    if (s[0] == K_SPECIAL && s[1] == KS_SPECIAL && s[2] == KE_FILLER) {
      *d++ = K_SPECIAL;
      s += 3;
    } else if ((s[0] == K_SPECIAL || s[0] == CSI)
               && s[1] == KS_EXTRA && s[2] == (int)KE_CSI) {
      *d++ = CSI;
      s += 3;
    } else {
      *d++ = *s++;
    }
  }
  *d = NUL;
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

  validate_maphash();

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

        // skip mappings that contain a <SNR> (script-local thing),
        // they probably don't work when loaded again
        for (p = mp->m_str; *p != NUL; p++) {
          if (p[0] == K_SPECIAL && p[1] == KS_EXTRA
              && p[2] == (int)KE_SNR) {
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
        case NORMAL + VISUAL + SELECTMODE + OP_PENDING:
          break;
        case NORMAL:
          c1 = 'n';
          break;
        case VISUAL:
          c1 = 'x';
          break;
        case SELECTMODE:
          c1 = 's';
          break;
        case OP_PENDING:
          c1 = 'o';
          break;
        case NORMAL + VISUAL:
          c1 = 'n';
          c2 = 'x';
          break;
        case NORMAL + SELECTMODE:
          c1 = 'n';
          c2 = 's';
          break;
        case NORMAL + OP_PENDING:
          c1 = 'n';
          c2 = 'o';
          break;
        case VISUAL + SELECTMODE:
          c1 = 'v';
          break;
        case VISUAL + OP_PENDING:
          c1 = 'x';
          c2 = 'o';
          break;
        case SELECTMODE + OP_PENDING:
          c1 = 's';
          c2 = 'o';
          break;
        case NORMAL + VISUAL + SELECTMODE:
          c1 = 'n';
          c2 = 'v';
          break;
        case NORMAL + VISUAL + OP_PENDING:
          c1 = 'n';
          c2 = 'x';
          c3 = 'o';
          break;
        case NORMAL + SELECTMODE + OP_PENDING:
          c1 = 'n';
          c2 = 's';
          c3 = 'o';
          break;
        case VISUAL + SELECTMODE + OP_PENDING:
          c1 = 'v';
          c2 = 'o';
          break;
        case CMDLINE + INSERT:
          if (!abbr) {
            cmd = "map!";
          }
          break;
        case CMDLINE:
          c1 = 'c';
          break;
        case INSERT:
          c1 = 'i';
          break;
        case LANGMAP:
          c1 = 'l';
          break;
        case TERM_FOCUS:
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
    // K_SPECIAL and CSI bytes.
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
                  int *local_ptr)
{
  int len, minlen;
  mapblock_T *mp;

  validate_maphash();

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
            return mp->m_str;
          }
        }
      }
    }
  }

  return NULL;
}

/// Add a mapping. Unlike @ref do_map this copies the {map} argument, so
/// static or read-only strings can be used.
///
/// @param map  C-string containing the arguments of the map/abbrev command,
///             i.e. everything except the initial `:[X][nore]map`.
/// @param mode  Bitflags representing the mode in which to set the mapping.
///              See @ref get_map_mode.
/// @param nore  If true, make a non-recursive mapping.
void add_map(char_u *map, int mode, bool nore)
{
  char_u *s;
  char_u *cpo_save = p_cpo;

  p_cpo = (char_u *)"";         // Allow <> notation
  // Need to put string in allocated memory, because do_map() will modify it.
  s = vim_strsave(map);
  (void)do_map(nore ? 2 : 0, s, mode, false);
  xfree(s);
  p_cpo = cpo_save;
}

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

static void do_exmap(exarg_T *eap, bool isabbrev)
{
  int mode;
  char_u *cmdp;

  cmdp = eap->cmd;
  mode = get_map_mode(&cmdp, eap->forceit || isabbrev);

  switch (do_map((*cmdp == 'n') ? 2 : (*cmdp == 'u'),
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
  map_clear_mode(eap->cmd, eap->arg, eap->forceit, false);
}

/// ":abclear" and friends.
void ex_abclear(exarg_T *eap)
{
  map_clear_mode(eap->cmd, eap->arg, true, true);
}
