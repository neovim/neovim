// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/*
 * undo.c: multi level undo facility
 *
 * The saved lines are stored in a list of lists (one for each buffer):
 *
 * b_u_oldhead------------------------------------------------+
 *                                                            |
 *                                                            V
 *                +--------------+    +--------------+    +--------------+
 * b_u_newhead--->| u_header     |    | u_header     |    | u_header     |
 *                |     uh_next------>|     uh_next------>|     uh_next---->NULL
 *         NULL<--------uh_prev  |<---------uh_prev  |<---------uh_prev  |
 *                |     uh_entry |    |     uh_entry |    |     uh_entry |
 *                +--------|-----+    +--------|-----+    +--------|-----+
 *                         |                   |                   |
 *                         V                   V                   V
 *                +--------------+    +--------------+    +--------------+
 *                | u_entry      |    | u_entry      |    | u_entry      |
 *                |     ue_next  |    |     ue_next  |    |     ue_next  |
 *                +--------|-----+    +--------|-----+    +--------|-----+
 *                         |                   |                   |
 *                         V                   V                   V
 *                +--------------+            NULL                NULL
 *                | u_entry      |
 *                |     ue_next  |
 *                +--------|-----+
 *                         |
 *                         V
 *                        etc.
 *
 * Each u_entry list contains the information for one undo or redo.
 * curbuf->b_u_curhead points to the header of the last undo (the next redo),
 * or is NULL if nothing has been undone (end of the branch).
 *
 * For keeping alternate undo/redo branches the uh_alt field is used.  Thus at
 * each point in the list a branch may appear for an alternate to redo.  The
 * uh_seq field is numbered sequentially to be able to find a newer or older
 * branch.
 *
 *                 +---------------+    +---------------+
 * b_u_oldhead --->| u_header      |    | u_header      |
 *                 |   uh_alt_next ---->|   uh_alt_next ----> NULL
 *         NULL <----- uh_alt_prev |<------ uh_alt_prev |
 *                 |   uh_prev     |    |   uh_prev     |
 *                 +-----|---------+    +-----|---------+
 *                       |                    |
 *                       V                    V
 *                 +---------------+    +---------------+
 *                 | u_header      |    | u_header      |
 *                 |   uh_alt_next |    |   uh_alt_next |
 * b_u_newhead --->|   uh_alt_prev |    |   uh_alt_prev |
 *                 |   uh_prev     |    |   uh_prev     |
 *                 +-----|---------+    +-----|---------+
 *                       |                    |
 *                       V                    V
 *                     NULL             +---------------+    +---------------+
 *                                      | u_header      |    | u_header      |
 *                                      |   uh_alt_next ---->|   uh_alt_next |
 *                                      |   uh_alt_prev |<------ uh_alt_prev |
 *                                      |   uh_prev     |    |   uh_prev     |
 *                                      +-----|---------+    +-----|---------+
 *                                            |                    |
 *                                           etc.                 etc.
 *
 *
 * All data is allocated and will all be freed when the buffer is unloaded.
 */

/* Uncomment the next line for including the u_check() function.  This warns
 * for errors in the debug information. */
/* #define U_DEBUG 1 */
#define UH_MAGIC 0x18dade       /* value for uh_magic when in use */
#define UE_MAGIC 0xabc123       /* value for ue_magic when in use */

#include <assert.h>
#include <inttypes.h>
#include <limits.h>
#include <stdbool.h>
#include <string.h>
#include <fcntl.h>

#include "nvim/buffer.h"
#include "nvim/ascii.h"
#include "nvim/change.h"
#include "nvim/undo.h"
#include "nvim/cursor.h"
#include "nvim/edit.h"
#include "nvim/fileio.h"
#include "nvim/fold.h"
#include "nvim/buffer_updates.h"
#include "nvim/mark.h"
#include "nvim/memline.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/memory.h"
#include "nvim/garray.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/sha256.h"
#include "nvim/state.h"
#include "nvim/strings.h"
#include "nvim/types.h"
#include "nvim/os/os.h"
#include "nvim/os/time.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "undo.c.generated.h"
#endif

/* used in undo_end() to report number of added and deleted lines */
static long u_newcount, u_oldcount;

/*
 * When 'u' flag included in 'cpoptions', we behave like vi.  Need to remember
 * the action that "u" should do.
 */
static bool undo_undoes = false;

static int lastmark = 0;

#if defined(U_DEBUG)
/*
 * Check the undo structures for being valid.  Print a warning when something
 * looks wrong.
 */
static int seen_b_u_curhead;
static int seen_b_u_newhead;
static int header_count;

static void u_check_tree(u_header_T *uhp,
    u_header_T *exp_uh_next,
    u_header_T *exp_uh_alt_prev) {
  u_entry_T *uep;

  if (uhp == NULL)
    return;
  ++header_count;
  if (uhp == curbuf->b_u_curhead && ++seen_b_u_curhead > 1) {
    EMSG("b_u_curhead found twice (looping?)");
    return;
  }
  if (uhp == curbuf->b_u_newhead && ++seen_b_u_newhead > 1) {
    EMSG("b_u_newhead found twice (looping?)");
    return;
  }

  if (uhp->uh_magic != UH_MAGIC)
    EMSG("uh_magic wrong (may be using freed memory)");
  else {
    /* Check pointers back are correct. */
    if (uhp->uh_next.ptr != exp_uh_next) {
      EMSG("uh_next wrong");
      smsg("expected: 0x%x, actual: 0x%x",
          exp_uh_next, uhp->uh_next.ptr);
    }
    if (uhp->uh_alt_prev.ptr != exp_uh_alt_prev) {
      EMSG("uh_alt_prev wrong");
      smsg("expected: 0x%x, actual: 0x%x",
          exp_uh_alt_prev, uhp->uh_alt_prev.ptr);
    }

    /* Check the undo tree at this header. */
    for (uep = uhp->uh_entry; uep != NULL; uep = uep->ue_next) {
      if (uep->ue_magic != UE_MAGIC) {
        EMSG("ue_magic wrong (may be using freed memory)");
        break;
      }
    }

    /* Check the next alt tree. */
    u_check_tree(uhp->uh_alt_next.ptr, uhp->uh_next.ptr, uhp);

    /* Check the next header in this branch. */
    u_check_tree(uhp->uh_prev.ptr, uhp, NULL);
  }
}

static void u_check(int newhead_may_be_NULL)                 {
  seen_b_u_newhead = 0;
  seen_b_u_curhead = 0;
  header_count = 0;

  u_check_tree(curbuf->b_u_oldhead, NULL, NULL);

  if (seen_b_u_newhead == 0 && curbuf->b_u_oldhead != NULL
      && !(newhead_may_be_NULL && curbuf->b_u_newhead == NULL))
    EMSGN("b_u_newhead invalid: 0x%x", curbuf->b_u_newhead);
  if (curbuf->b_u_curhead != NULL && seen_b_u_curhead == 0)
    EMSGN("b_u_curhead invalid: 0x%x", curbuf->b_u_curhead);
  if (header_count != curbuf->b_u_numhead) {
    EMSG("b_u_numhead invalid");
    smsg("expected: %" PRId64 ", actual: %" PRId64,
        (int64_t)header_count, (int64_t)curbuf->b_u_numhead);
  }
}

#endif

/*
 * Save the current line for both the "u" and "U" command.
 * Careful: may trigger autocommands that reload the buffer.
 * Returns OK or FAIL.
 */
int u_save_cursor(void)
{
  linenr_T cur = curwin->w_cursor.lnum;
  linenr_T top = cur > 0 ? cur - 1 : 0;
  linenr_T bot = cur + 1;

  return u_save(top, bot);
}

/*
 * Save the lines between "top" and "bot" for both the "u" and "U" command.
 * "top" may be 0 and bot may be curbuf->b_ml.ml_line_count + 1.
 * Careful: may trigger autocommands that reload the buffer.
 * Returns FAIL when lines could not be saved, OK otherwise.
 */
int u_save(linenr_T top, linenr_T bot)
{
  if (undo_off)
    return OK;

  if (top >= bot || bot > (curbuf->b_ml.ml_line_count + 1)) {
    return FAIL;        /* rely on caller to do error messages */
  }

  if (top + 2 == bot)
    u_saveline((linenr_T)(top + 1));

  return u_savecommon(top, bot, (linenr_T)0, FALSE);
}

/*
 * Save the line "lnum" (used by ":s" and "~" command).
 * The line is replaced, so the new bottom line is lnum + 1.
 * Careful: may trigger autocommands that reload the buffer.
 * Returns FAIL when lines could not be saved, OK otherwise.
 */
int u_savesub(linenr_T lnum)
{
  if (undo_off)
    return OK;

  return u_savecommon(lnum - 1, lnum + 1, lnum + 1, FALSE);
}

/*
 * A new line is inserted before line "lnum" (used by :s command).
 * The line is inserted, so the new bottom line is lnum + 1.
 * Careful: may trigger autocommands that reload the buffer.
 * Returns FAIL when lines could not be saved, OK otherwise.
 */
int u_inssub(linenr_T lnum)
{
  if (undo_off)
    return OK;

  return u_savecommon(lnum - 1, lnum, lnum + 1, FALSE);
}

/*
 * Save the lines "lnum" - "lnum" + nlines (used by delete command).
 * The lines are deleted, so the new bottom line is lnum, unless the buffer
 * becomes empty.
 * Careful: may trigger autocommands that reload the buffer.
 * Returns FAIL when lines could not be saved, OK otherwise.
 */
int u_savedel(linenr_T lnum, long nlines)
{
  if (undo_off)
    return OK;

  return u_savecommon(lnum - 1, lnum + nlines,
      nlines == curbuf->b_ml.ml_line_count ? 2 : lnum, FALSE);
}

/// Return true when undo is allowed. Otherwise print an error message and
/// return false.
///
/// @return true if undo is allowed.
bool undo_allowed(void)
{
  /* Don't allow changes when 'modifiable' is off.  */
  if (!MODIFIABLE(curbuf)) {
    EMSG(_(e_modifiable));
    return false;
  }

  // In the sandbox it's not allowed to change the text.
  if (sandbox != 0) {
    EMSG(_(e_sandbox));
    return false;
  }

  /* Don't allow changes in the buffer while editing the cmdline.  The
   * caller of getcmdline() may get confused. */
  if (textlock != 0) {
    EMSG(_(e_secure));
    return false;
  }

  return true;
}

/// Get the 'undolevels' value for the current buffer.
static long get_undolevel(void)
{
  if (curbuf->b_p_ul == NO_LOCAL_UNDOLEVEL) {
    return p_ul;
  }
  return curbuf->b_p_ul;
}

static inline void zero_fmark_additional_data(fmark_T *fmarks)
{
  for (size_t i = 0; i < NMARKS; i++) {
    tv_dict_unref(fmarks[i].additional_data);
    fmarks[i].additional_data = NULL;
  }
}

/*
 * Common code for various ways to save text before a change.
 * "top" is the line above the first changed line.
 * "bot" is the line below the last changed line.
 * "newbot" is the new bottom line.  Use zero when not known.
 * "reload" is TRUE when saving for a buffer reload.
 * Careful: may trigger autocommands that reload the buffer.
 * Returns FAIL when lines could not be saved, OK otherwise.
 */
int u_savecommon(linenr_T top, linenr_T bot, linenr_T newbot, int reload)
{
  linenr_T lnum;
  long i;
  u_header_T  *uhp;
  u_header_T  *old_curhead;
  u_entry_T   *uep;
  u_entry_T   *prev_uep;
  long size;

  if (!reload) {
    /* When making changes is not allowed return FAIL.  It's a crude way
     * to make all change commands fail. */
    if (!undo_allowed())
      return FAIL;


    /*
     * Saving text for undo means we are going to make a change.  Give a
     * warning for a read-only file before making the change, so that the
     * FileChangedRO event can replace the buffer with a read-write version
     * (e.g., obtained from a source control system).
     */
    change_warning(0);
    if (bot > curbuf->b_ml.ml_line_count + 1) {
      /* This happens when the FileChangedRO autocommand changes the
       * file in a way it becomes shorter. */
      EMSG(_("E881: Line count changed unexpectedly"));
      return FAIL;
    }
  }

#ifdef U_DEBUG
  u_check(FALSE);
#endif

  size = bot - top - 1;

  /*
   * If curbuf->b_u_synced == true make a new header.
   */
  if (curbuf->b_u_synced) {
    /* Need to create new entry in b_changelist. */
    curbuf->b_new_change = true;

    if (get_undolevel() >= 0) {
      /*
       * Make a new header entry.  Do this first so that we don't mess
       * up the undo info when out of memory.
       */
      uhp = xmalloc(sizeof(u_header_T));
#ifdef U_DEBUG
      uhp->uh_magic = UH_MAGIC;
#endif
    } else
      uhp = NULL;

    /*
     * If we undid more than we redid, move the entry lists before and
     * including curbuf->b_u_curhead to an alternate branch.
     */
    old_curhead = curbuf->b_u_curhead;
    if (old_curhead != NULL) {
      curbuf->b_u_newhead = old_curhead->uh_next.ptr;
      curbuf->b_u_curhead = NULL;
    }

    /*
     * free headers to keep the size right
     */
    while (curbuf->b_u_numhead > get_undolevel()
           && curbuf->b_u_oldhead != NULL) {
      u_header_T      *uhfree = curbuf->b_u_oldhead;

      if (uhfree == old_curhead)
        /* Can't reconnect the branch, delete all of it. */
        u_freebranch(curbuf, uhfree, &old_curhead);
      else if (uhfree->uh_alt_next.ptr == NULL)
        /* There is no branch, only free one header. */
        u_freeheader(curbuf, uhfree, &old_curhead);
      else {
        /* Free the oldest alternate branch as a whole. */
        while (uhfree->uh_alt_next.ptr != NULL)
          uhfree = uhfree->uh_alt_next.ptr;
        u_freebranch(curbuf, uhfree, &old_curhead);
      }
#ifdef U_DEBUG
      u_check(TRUE);
#endif
    }

    if (uhp == NULL) {                  /* no undo at all */
      if (old_curhead != NULL)
        u_freebranch(curbuf, old_curhead, NULL);
      curbuf->b_u_synced = false;
      return OK;
    }

    uhp->uh_prev.ptr = NULL;
    uhp->uh_next.ptr = curbuf->b_u_newhead;
    uhp->uh_alt_next.ptr = old_curhead;
    if (old_curhead != NULL) {
      uhp->uh_alt_prev.ptr = old_curhead->uh_alt_prev.ptr;
      if (uhp->uh_alt_prev.ptr != NULL)
        uhp->uh_alt_prev.ptr->uh_alt_next.ptr = uhp;
      old_curhead->uh_alt_prev.ptr = uhp;
      if (curbuf->b_u_oldhead == old_curhead)
        curbuf->b_u_oldhead = uhp;
    } else
      uhp->uh_alt_prev.ptr = NULL;
    if (curbuf->b_u_newhead != NULL)
      curbuf->b_u_newhead->uh_prev.ptr = uhp;

    uhp->uh_seq = ++curbuf->b_u_seq_last;
    curbuf->b_u_seq_cur = uhp->uh_seq;
    uhp->uh_time = time(NULL);
    uhp->uh_save_nr = 0;
    curbuf->b_u_time_cur = uhp->uh_time + 1;

    uhp->uh_walk = 0;
    uhp->uh_entry = NULL;
    uhp->uh_getbot_entry = NULL;
    uhp->uh_cursor = curwin->w_cursor;          /* save cursor pos. for undo */
    if (virtual_active() && curwin->w_cursor.coladd > 0)
      uhp->uh_cursor_vcol = getviscol();
    else
      uhp->uh_cursor_vcol = -1;

    /* save changed and buffer empty flag for undo */
    uhp->uh_flags = (curbuf->b_changed ? UH_CHANGED : 0) +
                    ((curbuf->b_ml.ml_flags & ML_EMPTY) ? UH_EMPTYBUF : 0);

    /* save named marks and Visual marks for undo */
    zero_fmark_additional_data(curbuf->b_namedm);
    memmove(uhp->uh_namedm, curbuf->b_namedm,
            sizeof(curbuf->b_namedm[0]) * NMARKS);
    uhp->uh_visual = curbuf->b_visual;

    curbuf->b_u_newhead = uhp;
    if (curbuf->b_u_oldhead == NULL)
      curbuf->b_u_oldhead = uhp;
    ++curbuf->b_u_numhead;
  } else {
    if (get_undolevel() < 0)            /* no undo at all */
      return OK;

    /*
     * When saving a single line, and it has been saved just before, it
     * doesn't make sense saving it again.  Saves a lot of memory when
     * making lots of changes inside the same line.
     * This is only possible if the previous change didn't increase or
     * decrease the number of lines.
     * Check the ten last changes.  More doesn't make sense and takes too
     * long.
     */
    if (size == 1) {
      uep = u_get_headentry();
      prev_uep = NULL;
      for (i = 0; i < 10; ++i) {
        if (uep == NULL)
          break;

        /* If lines have been inserted/deleted we give up.
         * Also when the line was included in a multi-line save. */
        if ((curbuf->b_u_newhead->uh_getbot_entry != uep
             ? (uep->ue_top + uep->ue_size + 1
                != (uep->ue_bot == 0
                    ? curbuf->b_ml.ml_line_count + 1
                    : uep->ue_bot))
             : uep->ue_lcount != curbuf->b_ml.ml_line_count)
            || (uep->ue_size > 1
                && top >= uep->ue_top
                && top + 2 <= uep->ue_top + uep->ue_size + 1))
          break;

        /* If it's the same line we can skip saving it again. */
        if (uep->ue_size == 1 && uep->ue_top == top) {
          if (i > 0) {
            /* It's not the last entry: get ue_bot for the last
             * entry now.  Following deleted/inserted lines go to
             * the re-used entry. */
            u_getbot();
            curbuf->b_u_synced = false;

            /* Move the found entry to become the last entry.  The
             * order of undo/redo doesn't matter for the entries
             * we move it over, since they don't change the line
             * count and don't include this line.  It does matter
             * for the found entry if the line count is changed by
             * the executed command. */
            prev_uep->ue_next = uep->ue_next;
            uep->ue_next = curbuf->b_u_newhead->uh_entry;
            curbuf->b_u_newhead->uh_entry = uep;
          }

          /* The executed command may change the line count. */
          if (newbot != 0)
            uep->ue_bot = newbot;
          else if (bot > curbuf->b_ml.ml_line_count)
            uep->ue_bot = 0;
          else {
            uep->ue_lcount = curbuf->b_ml.ml_line_count;
            curbuf->b_u_newhead->uh_getbot_entry = uep;
          }
          return OK;
        }
        prev_uep = uep;
        uep = uep->ue_next;
      }
    }

    /* find line number for ue_bot for previous u_save() */
    u_getbot();
  }

  /*
   * add lines in front of entry list
   */
  uep = xmalloc(sizeof(u_entry_T));
  memset(uep, 0, sizeof(u_entry_T));
#ifdef U_DEBUG
  uep->ue_magic = UE_MAGIC;
#endif

  uep->ue_size = size;
  uep->ue_top = top;
  if (newbot != 0)
    uep->ue_bot = newbot;
  /*
   * Use 0 for ue_bot if bot is below last line.
   * Otherwise we have to compute ue_bot later.
   */
  else if (bot > curbuf->b_ml.ml_line_count)
    uep->ue_bot = 0;
  else {
    uep->ue_lcount = curbuf->b_ml.ml_line_count;
    curbuf->b_u_newhead->uh_getbot_entry = uep;
  }

  if (size > 0) {
    uep->ue_array = xmalloc(sizeof(char_u *) * (size_t)size);
    for (i = 0, lnum = top + 1; i < size; ++i) {
      fast_breakcheck();
      if (got_int) {
        u_freeentry(uep, i);
        return FAIL;
      }
      uep->ue_array[i] = u_save_line(lnum++);
    }
  } else
    uep->ue_array = NULL;
  uep->ue_next = curbuf->b_u_newhead->uh_entry;
  curbuf->b_u_newhead->uh_entry = uep;
  curbuf->b_u_synced = false;
  undo_undoes = false;

#ifdef U_DEBUG
  u_check(FALSE);
#endif
  return OK;
}


# define UF_START_MAGIC     "Vim\237UnDo\345"  /* magic at start of undofile */
# define UF_START_MAGIC_LEN     9
# define UF_HEADER_MAGIC        0x5fd0  /* magic at start of header */
# define UF_HEADER_END_MAGIC    0xe7aa  /* magic after last header */
# define UF_ENTRY_MAGIC         0xf518  /* magic at start of entry */
# define UF_ENTRY_END_MAGIC     0x3581  /* magic after last entry */
# define UF_VERSION             2       /* 2-byte undofile version number */

/* extra fields for header */
# define UF_LAST_SAVE_NR        1

/* extra fields for uhp */
# define UHP_SAVE_NR            1

static char_u e_not_open[] = N_("E828: Cannot open undo file for writing: %s");

/*
 * Compute the hash for the current buffer text into hash[UNDO_HASH_SIZE].
 */
void u_compute_hash(char_u *hash)
{
  context_sha256_T ctx;
  linenr_T lnum;
  char_u              *p;

  sha256_start(&ctx);
  for (lnum = 1; lnum <= curbuf->b_ml.ml_line_count; ++lnum) {
    p = ml_get(lnum);
    sha256_update(&ctx, p, (uint32_t)(STRLEN(p) + 1));
  }
  sha256_finish(&ctx, hash);
}

/// Return an allocated string of the full path of the target undofile.
///
/// @param[in]  buf_ffname  Full file name for which undo file location should
///                         be found.
/// @param[in]  reading  If true, find the file to read by traversing all of the
///                      directories in &undodir. If false use the first
///                      existing directory. If none of the directories in
///                      &undodir option exist then last directory in the list
///                      will be automatically created.
///
/// @return [allocated] File name to read from/write to or NULL.
char *u_get_undo_file_name(const char *const buf_ffname, const bool reading)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  char *dirp;
  char dir_name[MAXPATHL + 1];
  char *munged_name = NULL;
  char *undo_file_name = NULL;
  const char *ffname = buf_ffname;
#ifdef HAVE_READLINK
  char fname_buf[MAXPATHL];
#endif

  if (ffname == NULL) {
    return NULL;
  }

#ifdef HAVE_READLINK
  // Expand symlink in the file name, so that we put the undo file with the
  // actual file instead of with the symlink.
  if (resolve_symlink((const char_u *)ffname, (char_u *)fname_buf) == OK) {
    ffname = fname_buf;
  }
#endif

  // Loop over 'undodir'.  When reading find the first file that exists.
  // When not reading use the first directory that exists or ".".
  dirp = (char *) p_udir;
  while (*dirp != NUL) {
    size_t dir_len = copy_option_part((char_u **)&dirp, (char_u *)dir_name,
                                      MAXPATHL, ",");
    if (dir_len == 1 && dir_name[0] == '.') {
      // Use same directory as the ffname,
      // "dir/name" -> "dir/.name.un~"
      const size_t ffname_len = strlen(ffname);
      undo_file_name = xmalloc(ffname_len + 6);
      memmove(undo_file_name, ffname, ffname_len + 1);
      char *const tail = (char *) path_tail((char_u *) undo_file_name);
      const size_t tail_len = strlen(tail);
      memmove(tail + 1, tail, tail_len + 1);
      *tail = '.';
      memmove(tail + tail_len + 1, ".un~", sizeof(".un~"));
    } else {
      dir_name[dir_len] = NUL;
      bool has_directory = os_isdir((char_u *)dir_name);
      if (!has_directory && *dirp == NUL && !reading) {
        // Last directory in the list does not exist, create it.
        int ret;
        char *failed_dir;
        if ((ret = os_mkdir_recurse(dir_name, 0755, &failed_dir)) != 0) {
          EMSG3(_("E5003: Unable to create directory \"%s\" for undo file: %s"),
                failed_dir, os_strerror(ret));
          xfree(failed_dir);
        } else {
          has_directory = true;
        }
      }
      if (has_directory) {
        if (munged_name == NULL) {
          munged_name = xstrdup(ffname);
          for (char *p = munged_name; *p != NUL; MB_PTR_ADV(p)) {
            if (vim_ispathsep(*p)) {
              *p = '%';
            }
          }
        }
        undo_file_name = concat_fnames(dir_name, munged_name, true);
      }
    }

    // When reading check if the file exists.
    if (undo_file_name != NULL
        && (!reading || os_path_exists((char_u *)undo_file_name))) {
      break;
    }
    XFREE_CLEAR(undo_file_name);
  }

  xfree(munged_name);
  return undo_file_name;
}

/// Display an error for corrupted undo file
///
/// @param[in]  mesg  Identifier of the corruption kind.
/// @param[in]  file_name  File in which error occurred.
static void corruption_error(const char *const mesg,
                             const char *const file_name)
  FUNC_ATTR_NONNULL_ALL
{
  EMSG3(_("E825: Corrupted undo file (%s): %s"), mesg, file_name);
}

static void u_free_uhp(u_header_T *uhp)
{
  u_entry_T   *nuep;
  u_entry_T   *uep;

  uep = uhp->uh_entry;
  while (uep != NULL) {
    nuep = uep->ue_next;
    u_freeentry(uep, uep->ue_size);
    uep = nuep;
  }
  xfree(uhp);
}

/// Writes the undofile header.
///
/// @param bi   The buffer information
/// @param hash The hash of the buffer contents
//
/// @returns false in case of an error.
static bool serialize_header(bufinfo_T *bi, char_u *hash)
  FUNC_ATTR_NONNULL_ALL
{
  buf_T *buf = bi->bi_buf;
  FILE *fp = bi->bi_fp;

  // Start writing, first the magic marker and undo info version.
  if (fwrite(UF_START_MAGIC, UF_START_MAGIC_LEN, 1, fp) != 1) {
    return false;
  }

  undo_write_bytes(bi, UF_VERSION, 2);

  // Write a hash of the buffer text, so that we can verify it is
  // still the same when reading the buffer text.
  if (!undo_write(bi, hash, UNDO_HASH_SIZE)) {
    return false;
  }

  // Write buffer-specific data.
  undo_write_bytes(bi, (uintmax_t)buf->b_ml.ml_line_count, 4);
  size_t len = buf->b_u_line_ptr ? STRLEN(buf->b_u_line_ptr) : 0;
  undo_write_bytes(bi, len, 4);
  if (len > 0 && !undo_write(bi, buf->b_u_line_ptr, len)) {
    return false;
  }
  undo_write_bytes(bi, (uintmax_t)buf->b_u_line_lnum, 4);
  undo_write_bytes(bi, (uintmax_t)buf->b_u_line_colnr, 4);

  // Write undo structures header data.
  put_header_ptr(bi, buf->b_u_oldhead);
  put_header_ptr(bi, buf->b_u_newhead);
  put_header_ptr(bi, buf->b_u_curhead);

  undo_write_bytes(bi, (uintmax_t)buf->b_u_numhead, 4);
  undo_write_bytes(bi, (uintmax_t)buf->b_u_seq_last, 4);
  undo_write_bytes(bi, (uintmax_t)buf->b_u_seq_cur, 4);
  uint8_t time_buf[8];
  time_to_bytes(buf->b_u_time_cur, time_buf);
  undo_write(bi, time_buf, sizeof(time_buf));

  // Write optional fields.
  undo_write_bytes(bi, 4, 1);
  undo_write_bytes(bi, UF_LAST_SAVE_NR, 1);
  undo_write_bytes(bi, (uintmax_t)buf->b_u_save_nr_last, 4);

  // Write end marker.
  undo_write_bytes(bi, 0, 1);

  return true;
}

/// Writes an undo header.
///
/// @param bi  The buffer information
/// @param uhp The undo header to write
//
/// @returns false in case of an error.
static bool serialize_uhp(bufinfo_T *bi, u_header_T *uhp)
{
  if (!undo_write_bytes(bi, (uintmax_t)UF_HEADER_MAGIC, 2)) {
    return false;
  }

  put_header_ptr(bi, uhp->uh_next.ptr);
  put_header_ptr(bi, uhp->uh_prev.ptr);
  put_header_ptr(bi, uhp->uh_alt_next.ptr);
  put_header_ptr(bi, uhp->uh_alt_prev.ptr);
  undo_write_bytes(bi, (uintmax_t)uhp->uh_seq, 4);
  serialize_pos(bi, uhp->uh_cursor);
  undo_write_bytes(bi, (uintmax_t)uhp->uh_cursor_vcol, 4);
  undo_write_bytes(bi, (uintmax_t)uhp->uh_flags, 2);
  // Assume NMARKS will stay the same.
  for (size_t i = 0; i < (size_t)NMARKS; i++) {
    serialize_pos(bi, uhp->uh_namedm[i].mark);
  }
  serialize_visualinfo(bi, &uhp->uh_visual);
  uint8_t time_buf[8];
  time_to_bytes(uhp->uh_time, time_buf);
  undo_write(bi, time_buf, sizeof(time_buf));

  // Write optional fields.
  undo_write_bytes(bi, 4, 1);
  undo_write_bytes(bi, UHP_SAVE_NR, 1);
  undo_write_bytes(bi, (uintmax_t)uhp->uh_save_nr, 4);

  // Write end marker.
  undo_write_bytes(bi, 0, 1);

  // Write all the entries.
  for (u_entry_T *uep = uhp->uh_entry; uep; uep = uep->ue_next) {
    undo_write_bytes(bi, (uintmax_t)UF_ENTRY_MAGIC, 2);
    if (!serialize_uep(bi, uep)) {
      return false;
    }
  }
  undo_write_bytes(bi, (uintmax_t)UF_ENTRY_END_MAGIC, 2);
  return true;
}

static u_header_T *unserialize_uhp(bufinfo_T *bi,
                                   const char *file_name)
{
  u_header_T *uhp = xmalloc(sizeof(u_header_T));
  memset(uhp, 0, sizeof(u_header_T));
#ifdef U_DEBUG
  uhp->uh_magic = UH_MAGIC;
#endif
  uhp->uh_next.seq = undo_read_4c(bi);
  uhp->uh_prev.seq = undo_read_4c(bi);
  uhp->uh_alt_next.seq = undo_read_4c(bi);
  uhp->uh_alt_prev.seq = undo_read_4c(bi);
  uhp->uh_seq = undo_read_4c(bi);
  if (uhp->uh_seq <= 0) {
    corruption_error("uh_seq", file_name);
    xfree(uhp);
    return NULL;
  }
  unserialize_pos(bi, &uhp->uh_cursor);
  uhp->uh_cursor_vcol = undo_read_4c(bi);
  uhp->uh_flags = undo_read_2c(bi);
  const Timestamp cur_timestamp = os_time();
  for (size_t i = 0; i < (size_t)NMARKS; i++) {
    unserialize_pos(bi, &uhp->uh_namedm[i].mark);
    uhp->uh_namedm[i].timestamp = cur_timestamp;
    uhp->uh_namedm[i].fnum = 0;
  }
  unserialize_visualinfo(bi, &uhp->uh_visual);
  uhp->uh_time = undo_read_time(bi);

  // Unserialize optional fields.
  for (;; ) {
    int len = undo_read_byte(bi);

    if (len == 0 || len == EOF) {
      break;
    }
    int what = undo_read_byte(bi);
    switch (what) {
    case UHP_SAVE_NR:
      uhp->uh_save_nr = undo_read_4c(bi);
      break;
    default:
      // Field not supported, skip it.
      while (--len >= 0) {
        (void)undo_read_byte(bi);
      }
    }
  }

  // Unserialize the uep list.
  u_entry_T *last_uep = NULL;
  int c;
  while ((c = undo_read_2c(bi)) == UF_ENTRY_MAGIC) {
    bool error = false;
    u_entry_T *uep = unserialize_uep(bi, &error, file_name);
    if (last_uep == NULL) {
      uhp->uh_entry = uep;
    } else {
      last_uep->ue_next = uep;
    }
    last_uep = uep;
    if (uep == NULL || error) {
      u_free_uhp(uhp);
      return NULL;
    }
  }
  if (c != UF_ENTRY_END_MAGIC) {
    corruption_error("entry end", file_name);
    u_free_uhp(uhp);
    return NULL;
  }

  return uhp;
}

/// Serializes "uep".
///
/// @param bi  The buffer information
/// @param uep The undo entry to write
//
/// @returns false in case of an error.
static bool serialize_uep(bufinfo_T *bi, u_entry_T *uep)
{
  undo_write_bytes(bi, (uintmax_t)uep->ue_top, 4);
  undo_write_bytes(bi, (uintmax_t)uep->ue_bot, 4);
  undo_write_bytes(bi, (uintmax_t)uep->ue_lcount, 4);
  undo_write_bytes(bi, (uintmax_t)uep->ue_size, 4);

  for (size_t i = 0; i < (size_t)uep->ue_size; i++) {
    size_t len = STRLEN(uep->ue_array[i]);
    if (!undo_write_bytes(bi, len, 4)) {
      return false;
    }
    if (len > 0 && !undo_write(bi, uep->ue_array[i], len)) {
      return false;
    }
  }
  return true;
}

static u_entry_T *unserialize_uep(bufinfo_T * bi, bool *error,
                                  const char *file_name)
{
  u_entry_T *uep = xmalloc(sizeof(u_entry_T));
  memset(uep, 0, sizeof(u_entry_T));
#ifdef U_DEBUG
  uep->ue_magic = UE_MAGIC;
#endif
  uep->ue_top = undo_read_4c(bi);
  uep->ue_bot = undo_read_4c(bi);
  uep->ue_lcount = undo_read_4c(bi);
  uep->ue_size = undo_read_4c(bi);

  char_u **array = NULL;
  if (uep->ue_size > 0) {
    if ((size_t)uep->ue_size < SIZE_MAX / sizeof(char_u *)) {  // -V547
      array = xmalloc(sizeof(char_u *) * (size_t)uep->ue_size);
      memset(array, 0, sizeof(char_u *) * (size_t)uep->ue_size);
    }
  }
  uep->ue_array = array;

  for (size_t i = 0; i < (size_t)uep->ue_size; i++) {
    int line_len = undo_read_4c(bi);
    char_u *line;
    if (line_len >= 0) {
      line = undo_read_string(bi, (size_t)line_len);
    } else {
      line = NULL;
      corruption_error("line length", file_name);
    }
    if (line == NULL) {
      *error = true;
      return uep;
    }
    array[i] = line;
  }
  return uep;
}

/// Serializes "pos".
static void serialize_pos(bufinfo_T *bi, pos_T pos)
{
  undo_write_bytes(bi, (uintmax_t)pos.lnum, 4);
  undo_write_bytes(bi, (uintmax_t)pos.col, 4);
  undo_write_bytes(bi, (uintmax_t)pos.coladd, 4);
}

/// Unserializes the pos_T at the current position.
static void unserialize_pos(bufinfo_T *bi, pos_T *pos)
{
  pos->lnum = undo_read_4c(bi);
  if (pos->lnum < 0) {
    pos->lnum = 0;
  }
  pos->col = undo_read_4c(bi);
  if (pos->col < 0) {
    pos->col = 0;
  }
  pos->coladd = undo_read_4c(bi);
  if (pos->coladd < 0) {
    pos->coladd = 0;
  }
}

/// Serializes "info".
static void serialize_visualinfo(bufinfo_T *bi, visualinfo_T *info)
{
  serialize_pos(bi, info->vi_start);
  serialize_pos(bi, info->vi_end);
  undo_write_bytes(bi, (uintmax_t)info->vi_mode, 4);
  undo_write_bytes(bi, (uintmax_t)info->vi_curswant, 4);
}

/// Unserializes the visualinfo_T at the current position.
static void unserialize_visualinfo(bufinfo_T *bi, visualinfo_T *info)
{
  unserialize_pos(bi, &info->vi_start);
  unserialize_pos(bi, &info->vi_end);
  info->vi_mode = undo_read_4c(bi);
  info->vi_curswant = undo_read_4c(bi);
}

/// Write the undo tree in an undo file.
///
/// @param[in]  name  Name of the undo file or NULL if this function needs to
///                   generate the undo file name based on buf->b_ffname.
/// @param[in]  forceit  True for `:wundo!`, false otherwise.
/// @param[in]  buf  Buffer for which undo file is written.
/// @param[in]  hash  Hash value of the buffer text. Must have #UNDO_HASH_SIZE
///                   size.
void u_write_undo(const char *const name, const bool forceit, buf_T *const buf,
                  char_u *const hash)
  FUNC_ATTR_NONNULL_ARG(3, 4)
{
  u_header_T  *uhp;
  char *file_name;
  int mark;
#ifdef U_DEBUG
  int headers_written = 0;
#endif
  int fd;
  FILE        *fp = NULL;
  int perm;
  bool write_ok = false;
  bufinfo_T bi;

  if (name == NULL) {
    file_name = u_get_undo_file_name((char *) buf->b_ffname, false);
    if (file_name == NULL) {
      if (p_verbose > 0) {
        verbose_enter();
        smsg(_("Cannot write undo file in any directory in 'undodir'"));
        verbose_leave();
      }
      return;
    }
  } else {
    file_name = (char *) name;
  }

  /*
   * Decide about the permission to use for the undo file.  If the buffer
   * has a name use the permission of the original file.  Otherwise only
   * allow the user to access the undo file.
   */
  perm = 0600;
  if (buf->b_ffname != NULL) {
    perm = os_getperm((const char *)buf->b_ffname);
    if (perm < 0) {
      perm = 0600;
    }
  }

  // Strip any sticky and executable bits.
  perm = perm & 0666;

  /* If the undo file already exists, verify that it actually is an undo
   * file, and delete it. */
  if (os_path_exists((char_u *)file_name)) {
    if (name == NULL || !forceit) {
      /* Check we can read it and it's an undo file. */
      fd = os_open(file_name, O_RDONLY, 0);
      if (fd < 0) {
        if (name != NULL || p_verbose > 0) {
          if (name == NULL)
            verbose_enter();
          smsg(_("Will not overwrite with undo file, cannot read: %s"),
               file_name);
          if (name == NULL)
            verbose_leave();
        }
        goto theend;
      } else {
        char_u mbuf[UF_START_MAGIC_LEN];
        ssize_t len = read_eintr(fd, mbuf, UF_START_MAGIC_LEN);
        close(fd);
        if (len < UF_START_MAGIC_LEN
            || memcmp(mbuf, UF_START_MAGIC, UF_START_MAGIC_LEN) != 0) {
          if (name != NULL || p_verbose > 0) {
            if (name == NULL)
              verbose_enter();
            smsg(_("Will not overwrite, this is not an undo file: %s"),
                 file_name);
            if (name == NULL)
              verbose_leave();
          }
          goto theend;
        }
      }
    }
    os_remove(file_name);
  }

  /* If there is no undo information at all, quit here after deleting any
   * existing undo file. */
  if (buf->b_u_numhead == 0 && buf->b_u_line_ptr == NULL) {
    if (p_verbose > 0) {
      verb_msg(_("Skipping undo file write, nothing to undo"));
    }
    goto theend;
  }

  fd = os_open(file_name, O_CREAT|O_WRONLY|O_EXCL|O_NOFOLLOW, perm);
  if (fd < 0) {
    EMSG2(_(e_not_open), file_name);
    goto theend;
  }
  (void)os_setperm(file_name, perm);
  if (p_verbose > 0) {
    verbose_enter();
    smsg(_("Writing undo file: %s"), file_name);
    verbose_leave();
  }

#ifdef U_DEBUG
  /* Check there is no problem in undo info before writing. */
  u_check(FALSE);
#endif

#ifdef UNIX
  /*
   * Try to set the group of the undo file same as the original file. If
   * this fails, set the protection bits for the group same as the
   * protection bits for others.
   */
  FileInfo file_info_old;
  FileInfo file_info_new;
  if (buf->b_ffname != NULL
      && os_fileinfo((char *)buf->b_ffname, &file_info_old)
      && os_fileinfo(file_name, &file_info_new)
      && file_info_old.stat.st_gid != file_info_new.stat.st_gid
      && os_fchown(fd, (uv_uid_t)-1, (uv_gid_t)file_info_old.stat.st_gid)) {
    os_setperm(file_name, (perm & 0707) | ((perm & 07) << 3));
  }
#endif

  fp = fdopen(fd, "w");
  if (fp == NULL) {
    EMSG2(_(e_not_open), file_name);
    close(fd);
    os_remove(file_name);
    goto theend;
  }

  /* Undo must be synced. */
  u_sync(TRUE);

  /*
   * Write the header.
   */
  bi.bi_buf = buf;
  bi.bi_fp = fp;
  if (!serialize_header(&bi, hash)) {
    goto write_error;
  }

  /*
   * Iteratively serialize UHPs and their UEPs from the top down.
   */
  mark = ++lastmark;
  uhp = buf->b_u_oldhead;
  while (uhp != NULL) {
    /* Serialize current UHP if we haven't seen it */
    if (uhp->uh_walk != mark) {
      uhp->uh_walk = mark;
#ifdef U_DEBUG
      ++headers_written;
#endif
      if (!serialize_uhp(&bi, uhp)) {
        goto write_error;
      }
    }

    /* Now walk through the tree - algorithm from undo_time(). */
    if (uhp->uh_prev.ptr != NULL && uhp->uh_prev.ptr->uh_walk != mark)
      uhp = uhp->uh_prev.ptr;
    else if (uhp->uh_alt_next.ptr != NULL
             && uhp->uh_alt_next.ptr->uh_walk != mark)
      uhp = uhp->uh_alt_next.ptr;
    else if (uhp->uh_next.ptr != NULL && uhp->uh_alt_prev.ptr == NULL
             && uhp->uh_next.ptr->uh_walk != mark)
      uhp = uhp->uh_next.ptr;
    else if (uhp->uh_alt_prev.ptr != NULL)
      uhp = uhp->uh_alt_prev.ptr;
    else
      uhp = uhp->uh_next.ptr;
  }

  if (undo_write_bytes(&bi, (uintmax_t)UF_HEADER_END_MAGIC, 2)) {
    write_ok = true;
  }
#ifdef U_DEBUG
  if (headers_written != buf->b_u_numhead) {
    EMSGN("Written %" PRId64 " headers, ...", headers_written);
    EMSGN("... but numhead is %" PRId64, buf->b_u_numhead);
  }
#endif

write_error:
  fclose(fp);
  if (!write_ok)
    EMSG2(_("E829: write error in undo file: %s"), file_name);

#ifdef HAVE_ACL
  if (buf->b_ffname != NULL) {
    vim_acl_T acl;

    /* For systems that support ACL: get the ACL from the original file. */
    acl = mch_get_acl(buf->b_ffname);
    mch_set_acl((char_u *)file_name, acl);
    mch_free_acl(acl);
  }
#endif

theend:
  if (file_name != name)
    xfree(file_name);
}

/// Loads the undo tree from an undo file.
/// If "name" is not NULL use it as the undo file name. This also means being
/// a bit more verbose.
/// Otherwise use curbuf->b_ffname to generate the undo file name.
/// "hash[UNDO_HASH_SIZE]" must be the hash value of the buffer text.
void u_read_undo(char *name, char_u *hash, char_u *orig_name)
  FUNC_ATTR_NONNULL_ARG(2)
{
  u_header_T **uhp_table = NULL;
  char_u *line_ptr = NULL;

  char *file_name;
  if (name == NULL) {
    file_name = u_get_undo_file_name((char *) curbuf->b_ffname, true);
    if (file_name == NULL) {
      return;
    }

#ifdef UNIX
    // For safety we only read an undo file if the owner is equal to the
    // owner of the text file or equal to the current user.
    FileInfo file_info_orig;
    FileInfo file_info_undo;
    if (os_fileinfo((char *)orig_name, &file_info_orig)
        && os_fileinfo((char *)file_name, &file_info_undo)
        && file_info_orig.stat.st_uid != file_info_undo.stat.st_uid
        && file_info_undo.stat.st_uid != getuid()) {
      if (p_verbose > 0) {
        verbose_enter();
        smsg(_("Not reading undo file, owner differs: %s"),
             file_name);
        verbose_leave();
      }
      return;
    }
#endif
  } else {
    file_name = (char *) name;
  }

  if (p_verbose > 0) {
    verbose_enter();
    smsg(_("Reading undo file: %s"), file_name);
    verbose_leave();
  }

  FILE *fp = os_fopen(file_name, "r");
  if (fp == NULL) {
    if (name != NULL || p_verbose > 0) {
      EMSG2(_("E822: Cannot open undo file for reading: %s"), file_name);
    }
    goto error;
  }

  bufinfo_T bi;
  bi.bi_buf = curbuf;
  bi.bi_fp = fp;

  // Read the undo file header.
  char_u magic_buf[UF_START_MAGIC_LEN];
  if (fread(magic_buf, UF_START_MAGIC_LEN, 1, fp) != 1
      || memcmp(magic_buf, UF_START_MAGIC, UF_START_MAGIC_LEN) != 0) {
    EMSG2(_("E823: Not an undo file: %s"), file_name);
    goto error;
  }
  int version = get2c(fp);
  if (version != UF_VERSION) {
    EMSG2(_("E824: Incompatible undo file: %s"), file_name);
    goto error;
  }

  char_u read_hash[UNDO_HASH_SIZE];
  if (!undo_read(&bi, read_hash, UNDO_HASH_SIZE)) {
    corruption_error("hash", file_name);
    goto error;
  }
  linenr_T line_count = (linenr_T)undo_read_4c(&bi);
  if (memcmp(hash, read_hash, UNDO_HASH_SIZE) != 0
      || line_count != curbuf->b_ml.ml_line_count) {
    if (p_verbose > 0 || name != NULL) {
      if (name == NULL) {
        verbose_enter();
      }
      give_warning((char_u *)
          _("File contents changed, cannot use undo info"), true);
      if (name == NULL) {
        verbose_leave();
      }
    }
    goto error;
  }

  // Read undo data for "U" command.
  int str_len = undo_read_4c(&bi);
  if (str_len < 0) {
    goto error;
  }

  if (str_len > 0) {
    line_ptr = undo_read_string(&bi, (size_t)str_len);
  }
  linenr_T line_lnum = (linenr_T)undo_read_4c(&bi);
  colnr_T line_colnr = (colnr_T)undo_read_4c(&bi);
  if (line_lnum < 0 || line_colnr < 0) {
    corruption_error("line lnum/col", file_name);
    goto error;
  }

  // Begin general undo data
  int old_header_seq = undo_read_4c(&bi);
  int new_header_seq = undo_read_4c(&bi);
  int cur_header_seq = undo_read_4c(&bi);
  int num_head = undo_read_4c(&bi);
  int seq_last = undo_read_4c(&bi);
  int seq_cur = undo_read_4c(&bi);
  time_t seq_time = undo_read_time(&bi);

  // Optional header fields.
  long last_save_nr = 0;
  for (;; ) {
    int len = undo_read_byte(&bi);

    if (len == 0 || len == EOF) {
      break;
    }
    int what = undo_read_byte(&bi);
    switch (what) {
      case UF_LAST_SAVE_NR:
        last_save_nr = undo_read_4c(&bi);
        break;

      default:
        // field not supported, skip
        while (--len >= 0) {
          (void)undo_read_byte(&bi);
        }
    }
  }

  // uhp_table will store the freshly created undo headers we allocate
  // until we insert them into curbuf. The table remains sorted by the
  // sequence numbers of the headers.
  // When there are no headers uhp_table is NULL.
  if (num_head > 0) {
    if ((size_t)num_head < SIZE_MAX / sizeof(*uhp_table)) {  // -V547
      uhp_table = xmalloc((size_t)num_head * sizeof(*uhp_table));
    }
  }

  long num_read_uhps = 0;

  int c;
  while ((c = undo_read_2c(&bi)) == UF_HEADER_MAGIC) {
    if (num_read_uhps >= num_head) {
      corruption_error("num_head too small", file_name);
      goto error;
    }

    u_header_T *uhp = unserialize_uhp(&bi, file_name);
    if (uhp == NULL) {
      goto error;
    }
    uhp_table[num_read_uhps++] = uhp;
  }

  if (num_read_uhps != num_head) {
    corruption_error("num_head", file_name);
    goto error;
  }
  if (c != UF_HEADER_END_MAGIC) {
    corruption_error("end marker", file_name);
    goto error;
  }

#ifdef U_DEBUG
  size_t amount = num_head * sizeof(int) + 1;
  int *uhp_table_used = xmalloc(amount);
  memset(uhp_table_used, 0, amount);
# define SET_FLAG(j) ++ uhp_table_used[j]
#else
# define SET_FLAG(j)
#endif

  // We have put all of the headers into a table. Now we iterate through the
  // table and swizzle each sequence number we have stored in uh_*_seq into
  // a pointer corresponding to the header with that sequence number.
  short old_idx = -1, new_idx = -1, cur_idx = -1;
  for (int i = 0; i < num_head; i++) {
    u_header_T *uhp = uhp_table[i];
    if (uhp == NULL) {
      continue;
    }
    for (int j = 0; j < num_head; j++) {
      if (uhp_table[j] != NULL && i != j
          && uhp_table[i]->uh_seq == uhp_table[j]->uh_seq) {
        corruption_error("duplicate uh_seq", file_name);
        goto error;
      }
    }
    for (int j = 0; j < num_head; j++) {
      if (uhp_table[j] != NULL
          && uhp_table[j]->uh_seq == uhp->uh_next.seq) {
        uhp->uh_next.ptr = uhp_table[j];
        SET_FLAG(j);
        break;
      }
    }
    for (int j = 0; j < num_head; j++) {
      if (uhp_table[j] != NULL
          && uhp_table[j]->uh_seq == uhp->uh_prev.seq) {
        uhp->uh_prev.ptr = uhp_table[j];
        SET_FLAG(j);
        break;
      }
    }
    for (int j = 0; j < num_head; j++) {
      if (uhp_table[j] != NULL
          && uhp_table[j]->uh_seq == uhp->uh_alt_next.seq) {
        uhp->uh_alt_next.ptr = uhp_table[j];
        SET_FLAG(j);
        break;
      }
    }
    for (int j = 0; j < num_head; j++) {
      if (uhp_table[j] != NULL
          && uhp_table[j]->uh_seq == uhp->uh_alt_prev.seq) {
        uhp->uh_alt_prev.ptr = uhp_table[j];
        SET_FLAG(j);
        break;
      }
    }
    if (old_header_seq > 0 && old_idx < 0 && uhp->uh_seq == old_header_seq) {
      assert(i <= SHRT_MAX);
      old_idx = (short)i;
      SET_FLAG(i);
    }
    if (new_header_seq > 0 && new_idx < 0 && uhp->uh_seq == new_header_seq) {
      assert(i <= SHRT_MAX);
      new_idx = (short)i;
      SET_FLAG(i);
    }
    if (cur_header_seq > 0 && cur_idx < 0 && uhp->uh_seq == cur_header_seq) {
      assert(i <= SHRT_MAX);
      cur_idx = (short)i;
      SET_FLAG(i);
    }
  }

  // Now that we have read the undo info successfully, free the current undo
  // info and use the info from the file.
  u_blockfree(curbuf);
  curbuf->b_u_oldhead = old_idx < 0 ? NULL : uhp_table[old_idx];
  curbuf->b_u_newhead = new_idx < 0 ? NULL : uhp_table[new_idx];
  curbuf->b_u_curhead = cur_idx < 0 ? NULL : uhp_table[cur_idx];
  curbuf->b_u_line_ptr = line_ptr;
  curbuf->b_u_line_lnum = line_lnum;
  curbuf->b_u_line_colnr = line_colnr;
  curbuf->b_u_numhead = num_head;
  curbuf->b_u_seq_last = seq_last;
  curbuf->b_u_seq_cur = seq_cur;
  curbuf->b_u_time_cur = seq_time;
  curbuf->b_u_save_nr_last = last_save_nr;
  curbuf->b_u_save_nr_cur = last_save_nr;

  curbuf->b_u_synced = true;
  xfree(uhp_table);

#ifdef U_DEBUG
  for (int i = 0; i < num_head; i++) {
    if (uhp_table_used[i] == 0) {
      EMSGN("uhp_table entry %" PRId64 " not used, leaking memory", i);
    }
  }
  xfree(uhp_table_used);
  u_check(TRUE);
#endif

  if (name != NULL) {
    smsg(_("Finished reading undo file %s"), file_name);
  }
  goto theend;

error:
  xfree(line_ptr);
  if (uhp_table != NULL) {
    for (long i = 0; i < num_read_uhps; i++)
      if (uhp_table[i] != NULL) {
        u_free_uhp(uhp_table[i]);
      }
    xfree(uhp_table);
  }

theend:
  if (fp != NULL) {
    fclose(fp);
  }
  if (file_name != name) {
    xfree(file_name);
  }
}

/// Writes a sequence of bytes to the undo file.
///
/// @param bi  The buffer info
/// @param ptr The byte buffer to write
/// @param len The number of bytes to write
///
/// @returns false in case of an error.
static bool undo_write(bufinfo_T *bi, uint8_t *ptr, size_t len)
  FUNC_ATTR_NONNULL_ARG(1)
{
  return fwrite(ptr, len, 1, bi->bi_fp) == 1;
}

/// Writes a number, most significant bit first, in "len" bytes.
///
/// Must match with undo_read_?c() functions.
///
/// @param bi  The buffer info
/// @param nr  The number to write
/// @param len The number of bytes to use when writing the number.
///
/// @returns false in case of an error.
static bool undo_write_bytes(bufinfo_T *bi, uintmax_t nr, size_t len)
{
  assert(len > 0);
  uint8_t buf[8];
  for (size_t i = len - 1, bufi = 0; bufi < len; i--, bufi++) {
    buf[bufi] = (uint8_t)(nr >> (i * 8));
  }
  return undo_write(bi, buf, len);
}

/// Writes the pointer to an undo header.
///
/// Instead of writing the pointer itself, we use the sequence
/// number of the header. This is converted back to pointers
/// when reading.
static void put_header_ptr(bufinfo_T *bi, u_header_T *uhp)
{
  assert(uhp == NULL || uhp->uh_seq >= 0);
  undo_write_bytes(bi, (uint64_t)(uhp != NULL ? uhp->uh_seq : 0), 4);
}

static int undo_read_4c(bufinfo_T *bi)
{
  return get4c(bi->bi_fp);
}

static int undo_read_2c(bufinfo_T *bi)
{
  return get2c(bi->bi_fp);
}

static int undo_read_byte(bufinfo_T *bi)
{
  return getc(bi->bi_fp);
}

static time_t undo_read_time(bufinfo_T *bi)
{
  return get8ctime(bi->bi_fp);
}

/// Reads "buffer[size]" from the undo file.
///
/// @param bi     The buffer info
/// @param buffer Character buffer to read data into
/// @param size   The size of the character buffer
///
/// @returns false in case of an error.
static bool undo_read(bufinfo_T *bi, uint8_t *buffer, size_t size)
  FUNC_ATTR_NONNULL_ARG(1)
{
  const bool retval = fread(buffer, size, 1, bi->bi_fp) == 1;
  if (!retval) {
    // Error may be checked for only later.  Fill with zeros,
    // so that the reader won't use garbage.
    memset(buffer, 0, size);
  }
  return retval;
}

/// Reads a string of length "len" from "bi->bi_fd" and appends a zero to it.
///
/// @param len can be zero to allocate an empty line.
///
/// @returns a pointer to allocated memory or NULL in case of an error.
static uint8_t *undo_read_string(bufinfo_T *bi, size_t len)
{
  uint8_t *ptr = xmallocz(len);
  if (len > 0 && !undo_read(bi, ptr, len)) {
    xfree(ptr);
    return NULL;
  }
  return ptr;
}

/*
 * If 'cpoptions' contains 'u': Undo the previous undo or redo (vi compatible).
 * If 'cpoptions' does not contain 'u': Always undo.
 */
void u_undo(int count)
{
  /*
   * If we get an undo command while executing a macro, we behave like the
   * original vi. If this happens twice in one macro the result will not
   * be compatible.
   */
  if (curbuf->b_u_synced == false) {
    u_sync(TRUE);
    count = 1;
  }

  if (vim_strchr(p_cpo, CPO_UNDO) == NULL) {
    undo_undoes = true;
  } else {
    undo_undoes = !undo_undoes;
  }
  u_doit(count, false, true);
}

/*
 * If 'cpoptions' contains 'u': Repeat the previous undo or redo.
 * If 'cpoptions' does not contain 'u': Always redo.
 */
void u_redo(int count)
{
  if (vim_strchr(p_cpo, CPO_UNDO) == NULL) {
    undo_undoes = false;
  }

  u_doit(count, false, true);
}

/// Undo and remove the branch from the undo tree.
/// Also moves the cursor (as a "normal" undo would).
bool u_undo_and_forget(int count)
{
  if (curbuf->b_u_synced == false) {
    u_sync(true);
    count = 1;
  }
  undo_undoes = true;
  u_doit(count, true,
         // Don't send nvim_buf_lines_event for u_undo_and_forget().
         false);

  if (curbuf->b_u_curhead == NULL) {
    // nothing was undone.
    return false;
  }

  // Delete the current redo header
  // set the redo header to the next alternative branch (if any)
  // otherwise we will be in the leaf state
  u_header_T *to_forget = curbuf->b_u_curhead;
  curbuf->b_u_newhead = to_forget->uh_next.ptr;
  curbuf->b_u_curhead = to_forget->uh_alt_next.ptr;
  if (curbuf->b_u_curhead) {
    to_forget->uh_alt_next.ptr = NULL;
    curbuf->b_u_curhead->uh_alt_prev.ptr = to_forget->uh_alt_prev.ptr;
    curbuf->b_u_seq_cur = curbuf->b_u_curhead->uh_next.ptr ?
        curbuf->b_u_curhead->uh_next.ptr->uh_seq : 0;
  } else if (curbuf->b_u_newhead) {
    curbuf->b_u_seq_cur = curbuf->b_u_newhead->uh_seq;
  }
  if (to_forget->uh_alt_prev.ptr) {
    to_forget->uh_alt_prev.ptr->uh_alt_next.ptr = curbuf->b_u_curhead;
  }
  if (curbuf->b_u_newhead) {
    curbuf->b_u_newhead->uh_prev.ptr = curbuf->b_u_curhead;
  }
  if (curbuf->b_u_seq_last == to_forget->uh_seq) {
    curbuf->b_u_seq_last--;
  }
  u_freebranch(curbuf, to_forget, NULL);
  return true;
}

/// Undo or redo, depending on `undo_undoes`, `count` times.
///
/// @param startcount How often to undo or redo
/// @param quiet If `true`, don't show messages
/// @param do_buf_event If `true`, send the changedtick with the buffer updates
static void u_doit(int startcount, bool quiet, bool do_buf_event)
{
  int count = startcount;

  if (!undo_allowed())
    return;

  u_newcount = 0;
  u_oldcount = 0;
  if (curbuf->b_ml.ml_flags & ML_EMPTY)
    u_oldcount = -1;
  while (count--) {
    /* Do the change warning now, so that it triggers FileChangedRO when
     * needed.  This may cause the file to be reloaded, that must happen
     * before we do anything, because it may change curbuf->b_u_curhead
     * and more. */
    change_warning(0);

    if (undo_undoes) {
      if (curbuf->b_u_curhead == NULL)                  /* first undo */
        curbuf->b_u_curhead = curbuf->b_u_newhead;
      else if (get_undolevel() > 0)                     /* multi level undo */
        /* get next undo */
        curbuf->b_u_curhead = curbuf->b_u_curhead->uh_next.ptr;
      /* nothing to undo */
      if (curbuf->b_u_numhead == 0 || curbuf->b_u_curhead == NULL) {
        /* stick curbuf->b_u_curhead at end */
        curbuf->b_u_curhead = curbuf->b_u_oldhead;
        beep_flush();
        if (count == startcount - 1) {
          MSG(_("Already at oldest change"));
          return;
        }
        break;
      }

      u_undoredo(true, do_buf_event);
    } else {
      if (curbuf->b_u_curhead == NULL || get_undolevel() <= 0) {
        beep_flush();           /* nothing to redo */
        if (count == startcount - 1) {
          MSG(_("Already at newest change"));
          return;
        }
        break;
      }

      u_undoredo(false, do_buf_event);

      /* Advance for next redo.  Set "newhead" when at the end of the
       * redoable changes. */
      if (curbuf->b_u_curhead->uh_prev.ptr == NULL)
        curbuf->b_u_newhead = curbuf->b_u_curhead;
      curbuf->b_u_curhead = curbuf->b_u_curhead->uh_prev.ptr;
    }
  }
  u_undo_end(undo_undoes, false, quiet);
}

// Undo or redo over the timeline.
// When "step" is negative go back in time, otherwise goes forward in time.
// When "sec" is false make "step" steps, when "sec" is true use "step" as
// seconds.
// When "file" is true use "step" as a number of file writes.
// When "absolute" is true use "step" as the sequence number to jump to.
// "sec" must be false then.
void undo_time(long step, bool sec, bool file, bool absolute)
{
  long target;
  long closest;
  long closest_start;
  long closest_seq = 0;
  long val;
  u_header_T      *uhp = NULL;
  u_header_T      *last;
  int mark;
  int nomark = 0;  // shut up compiler
  int round;
  bool dosec = sec;
  bool dofile = file;
  bool above = false;
  bool did_undo = true;

  /* First make sure the current undoable change is synced. */
  if (curbuf->b_u_synced == false)
    u_sync(TRUE);

  u_newcount = 0;
  u_oldcount = 0;
  if (curbuf->b_ml.ml_flags & ML_EMPTY)
    u_oldcount = -1;

  /* "target" is the node below which we want to be.
   * Init "closest" to a value we can't reach. */
  if (absolute) {
    target = step;
    closest = -1;
  } else {
    if (dosec) {
      target = (long)(curbuf->b_u_time_cur) + step;
    } else if (dofile) {
      if (step < 0) {
        /* Going back to a previous write. If there were changes after
         * the last write, count that as moving one file-write, so
         * that ":earlier 1f" undoes all changes since the last save. */
        uhp = curbuf->b_u_curhead;
        if (uhp != NULL)
          uhp = uhp->uh_next.ptr;
        else
          uhp = curbuf->b_u_newhead;
        if (uhp != NULL && uhp->uh_save_nr != 0)
          /* "uh_save_nr" was set in the last block, that means
           * there were no changes since the last write */
          target = curbuf->b_u_save_nr_cur + step;
        else
          /* count the changes since the last write as one step */
          target = curbuf->b_u_save_nr_cur + step + 1;
        if (target <= 0)
          /* Go to before first write: before the oldest change. Use
           * the sequence number for that. */
          dofile = false;
      } else {
        /* Moving forward to a newer write. */
        target = curbuf->b_u_save_nr_cur + step;
        if (target > curbuf->b_u_save_nr_last) {
          /* Go to after last write: after the latest change. Use
           * the sequence number for that. */
          target = curbuf->b_u_seq_last + 1;
          dofile = false;
        }
      }
    } else
      target = curbuf->b_u_seq_cur + step;
    if (step < 0) {
      if (target < 0)
        target = 0;
      closest = -1;
    } else {
      if (dosec) {
        closest = (long)(os_time() + 1);
      } else if (dofile) {
        closest = curbuf->b_u_save_nr_last + 2;
      } else {
        closest = curbuf->b_u_seq_last + 2;
      }
      if (target >= closest) {
        target = closest - 1;
      }
    }
  }
  closest_start = closest;
  closest_seq = curbuf->b_u_seq_cur;

  // When "target" is 0; Back to origin.
  if (target == 0) {
    mark = lastmark;  // avoid that GCC complains
    goto target_zero;
  }

  /*
   * May do this twice:
   * 1. Search for "target", update "closest" to the best match found.
   * 2. If "target" not found search for "closest".
   *
   * When using the closest time we use the sequence number in the second
   * round, because there may be several entries with the same time.
   */
  for (round = 1; round <= 2; ++round) {
    /* Find the path from the current state to where we want to go.  The
     * desired state can be anywhere in the undo tree, need to go all over
     * it.  We put "nomark" in uh_walk where we have been without success,
     * "mark" where it could possibly be. */
    mark = ++lastmark;
    nomark = ++lastmark;

    if (curbuf->b_u_curhead == NULL)            /* at leaf of the tree */
      uhp = curbuf->b_u_newhead;
    else
      uhp = curbuf->b_u_curhead;

    while (uhp != NULL) {
      uhp->uh_walk = mark;
      if (dosec) {
        val = (long)(uhp->uh_time);
      } else if (dofile) {
        val = uhp->uh_save_nr;
      } else {
        val = uhp->uh_seq;
      }

      if (round == 1 && !(dofile && val == 0)) {
        /* Remember the header that is closest to the target.
         * It must be at least in the right direction (checked with
         * "b_u_seq_cur").  When the timestamp is equal find the
         * highest/lowest sequence number. */
        if ((step < 0 ? uhp->uh_seq <= curbuf->b_u_seq_cur
             : uhp->uh_seq > curbuf->b_u_seq_cur)
            && ((dosec && val == closest)
                ? (step < 0
                   ? uhp->uh_seq < closest_seq
                                   : uhp->uh_seq > closest_seq)
                : closest == closest_start
                || (val > target
                    ? (closest > target
                       ? val - target <= closest - target
                       : val - target <= target - closest)
                    : (closest > target
                       ? target - val <= closest - target
                       : target - val <= target - closest)))) {
          closest = val;
          closest_seq = uhp->uh_seq;
        }
      }

      /* Quit searching when we found a match.  But when searching for a
       * time we need to continue looking for the best uh_seq. */
      if (target == val && !dosec) {
        target = uhp->uh_seq;
        break;
      }

      /* go down in the tree if we haven't been there */
      if (uhp->uh_prev.ptr != NULL && uhp->uh_prev.ptr->uh_walk != nomark
          && uhp->uh_prev.ptr->uh_walk != mark)
        uhp = uhp->uh_prev.ptr;

      /* go to alternate branch if we haven't been there */
      else if (uhp->uh_alt_next.ptr != NULL
               && uhp->uh_alt_next.ptr->uh_walk != nomark
               && uhp->uh_alt_next.ptr->uh_walk != mark)
        uhp = uhp->uh_alt_next.ptr;

      /* go up in the tree if we haven't been there and we are at the
       * start of alternate branches */
      else if (uhp->uh_next.ptr != NULL && uhp->uh_alt_prev.ptr == NULL
               && uhp->uh_next.ptr->uh_walk != nomark
               && uhp->uh_next.ptr->uh_walk != mark) {
        /* If still at the start we don't go through this change. */
        if (uhp == curbuf->b_u_curhead)
          uhp->uh_walk = nomark;
        uhp = uhp->uh_next.ptr;
      } else {
        /* need to backtrack; mark this node as useless */
        uhp->uh_walk = nomark;
        if (uhp->uh_alt_prev.ptr != NULL)
          uhp = uhp->uh_alt_prev.ptr;
        else
          uhp = uhp->uh_next.ptr;
      }
    }

    if (uhp != NULL)        /* found it */
      break;

    if (absolute) {
      EMSGN(_("E830: Undo number %" PRId64 " not found"), step);
      return;
    }

    if (closest == closest_start) {
      if (step < 0)
        MSG(_("Already at oldest change"));
      else
        MSG(_("Already at newest change"));
      return;
    }

    target = closest_seq;
    dosec = false;
    dofile = false;
    if (step < 0) {
      above = true;             // stop above the header
    }
  }

target_zero:
  // If we found it: Follow the path to go to where we want to be.
  if (uhp != NULL || target == 0) {
    // First go up the tree as much as needed.
    while (!got_int) {
      /* Do the change warning now, for the same reason as above. */
      change_warning(0);

      uhp = curbuf->b_u_curhead;
      if (uhp == NULL)
        uhp = curbuf->b_u_newhead;
      else
        uhp = uhp->uh_next.ptr;
      if (uhp == NULL
          || (target > 0 && uhp->uh_walk != mark)
          || (uhp->uh_seq == target && !above)) {
        break;
      }
      curbuf->b_u_curhead = uhp;
      u_undoredo(true, true);
      if (target > 0) {
        uhp->uh_walk = nomark;          // don't go back down here
      }
    }

    // When back to origin, redo is not needed.
    if (target > 0) {
      // And now go down the tree (redo), branching off where needed.
      while (!got_int) {
        // Do the change warning now, for the same reason as above.
        change_warning(0);

        uhp = curbuf->b_u_curhead;
        if (uhp == NULL) {
          break;
        }

        // Go back to the first branch with a mark.
        while (uhp->uh_alt_prev.ptr != NULL
               && uhp->uh_alt_prev.ptr->uh_walk == mark) {
          uhp = uhp->uh_alt_prev.ptr;
        }

        // Find the last branch with a mark, that's the one.
        last = uhp;
        while (last->uh_alt_next.ptr != NULL
               && last->uh_alt_next.ptr->uh_walk == mark) {
          last = last->uh_alt_next.ptr;
        }
        if (last != uhp) {
          // Make the used branch the first entry in the list of
          // alternatives to make "u" and CTRL-R take this branch.
          while (uhp->uh_alt_prev.ptr != NULL) {
            uhp = uhp->uh_alt_prev.ptr;
          }
          if (last->uh_alt_next.ptr != NULL) {
            last->uh_alt_next.ptr->uh_alt_prev.ptr = last->uh_alt_prev.ptr;
          }
          last->uh_alt_prev.ptr->uh_alt_next.ptr = last->uh_alt_next.ptr;
          last->uh_alt_prev.ptr = NULL;
          last->uh_alt_next.ptr = uhp;
          uhp->uh_alt_prev.ptr = last;

          if (curbuf->b_u_oldhead == uhp) {
            curbuf->b_u_oldhead = last;
          }
          uhp = last;
          if (uhp->uh_next.ptr != NULL) {
            uhp->uh_next.ptr->uh_prev.ptr = uhp;
          }
        }
        curbuf->b_u_curhead = uhp;

        if (uhp->uh_walk != mark) {
          break;            // must have reached the target
        }

        // Stop when going backwards in time and didn't find the exact
        // header we were looking for.
        if (uhp->uh_seq == target && above) {
          curbuf->b_u_seq_cur = target - 1;
          break;
        }

        u_undoredo(false, true);

        // Advance "curhead" to below the header we last used.  If it
        // becomes NULL then we need to set "newhead" to this leaf.
        if (uhp->uh_prev.ptr == NULL) {
          curbuf->b_u_newhead = uhp;
        }
        curbuf->b_u_curhead = uhp->uh_prev.ptr;
        did_undo = false;

        if (uhp->uh_seq == target) {    // found it!
          break;
        }

        uhp = uhp->uh_prev.ptr;
        if (uhp == NULL || uhp->uh_walk != mark) {
          // Need to redo more but can't find it...
          internal_error("undo_time()");
          break;
        }
      }
    }
  }
  u_undo_end(did_undo, absolute, false);
}

/// u_undoredo: common code for undo and redo
///
/// The lines in the file are replaced by the lines in the entry list at
/// curbuf->b_u_curhead. The replaced lines in the file are saved in the entry
/// list for the next undo/redo.
///
/// @param undo If `true`, go up the tree. Down if `false`.
/// @param do_buf_event If `true`, send buffer updates.
static void u_undoredo(int undo, bool do_buf_event)
{
  char_u      **newarray = NULL;
  linenr_T oldsize;
  linenr_T newsize;
  linenr_T top, bot;
  linenr_T lnum;
  linenr_T newlnum = MAXLNUM;
  long i;
  u_entry_T   *uep, *nuep;
  u_entry_T   *newlist = NULL;
  int old_flags;
  int new_flags;
  fmark_T namedm[NMARKS];
  visualinfo_T visualinfo;
  bool empty_buffer;                        // buffer became empty
  u_header_T  *curhead = curbuf->b_u_curhead;

  /* Don't want autocommands using the undo structures here, they are
   * invalid till the end. */
  block_autocmds();

#ifdef U_DEBUG
  u_check(FALSE);
#endif
  old_flags = curhead->uh_flags;
  new_flags = (curbuf->b_changed ? UH_CHANGED : 0) +
              ((curbuf->b_ml.ml_flags & ML_EMPTY) ? UH_EMPTYBUF : 0);
  setpcmark();

  /*
   * save marks before undo/redo
   */
  zero_fmark_additional_data(curbuf->b_namedm);
  memmove(namedm, curbuf->b_namedm, sizeof(curbuf->b_namedm[0]) * NMARKS);
  visualinfo = curbuf->b_visual;
  curbuf->b_op_start.lnum = curbuf->b_ml.ml_line_count;
  curbuf->b_op_start.col = 0;
  curbuf->b_op_end.lnum = 0;
  curbuf->b_op_end.col = 0;

  for (uep = curhead->uh_entry; uep != NULL; uep = nuep) {
    top = uep->ue_top;
    bot = uep->ue_bot;
    if (bot == 0)
      bot = curbuf->b_ml.ml_line_count + 1;
    if (top > curbuf->b_ml.ml_line_count || top >= bot
        || bot > curbuf->b_ml.ml_line_count + 1) {
      unblock_autocmds();
      IEMSG(_("E438: u_undo: line numbers wrong"));
      changed();                // don't want UNCHANGED now
      return;
    }

    oldsize = bot - top - 1;        /* number of lines before undo */
    newsize = uep->ue_size;         /* number of lines after undo */

    if (top < newlnum) {
      /* If the saved cursor is somewhere in this undo block, move it to
       * the remembered position.  Makes "gwap" put the cursor back
       * where it was. */
      lnum = curhead->uh_cursor.lnum;
      if (lnum >= top && lnum <= top + newsize + 1) {
        curwin->w_cursor = curhead->uh_cursor;
        newlnum = curwin->w_cursor.lnum - 1;
      } else {
        /* Use the first line that actually changed.  Avoids that
         * undoing auto-formatting puts the cursor in the previous
         * line. */
        for (i = 0; i < newsize && i < oldsize; ++i)
          if (STRCMP(uep->ue_array[i], ml_get(top + 1 + i)) != 0)
            break;
        if (i == newsize && newlnum == MAXLNUM && uep->ue_next == NULL) {
          newlnum = top;
          curwin->w_cursor.lnum = newlnum + 1;
        } else if (i < newsize)   {
          newlnum = top + i;
          curwin->w_cursor.lnum = newlnum + 1;
        }
      }
    }

    empty_buffer = false;

    /* delete the lines between top and bot and save them in newarray */
    if (oldsize > 0) {
      newarray = xmalloc(sizeof(char_u *) * (size_t)oldsize);
      /* delete backwards, it goes faster in most cases */
      for (lnum = bot - 1, i = oldsize; --i >= 0; --lnum) {
        /* what can we do when we run out of memory? */
        newarray[i] = u_save_line(lnum);
        /* remember we deleted the last line in the buffer, and a
         * dummy empty line will be inserted */
        if (curbuf->b_ml.ml_line_count == 1) {
          empty_buffer = true;
        }
        ml_delete(lnum, false);
      }
    } else
      newarray = NULL;

    /* insert the lines in u_array between top and bot */
    if (newsize) {
      for (lnum = top, i = 0; i < newsize; ++i, ++lnum) {
        /*
         * If the file is empty, there is an empty line 1 that we
         * should get rid of, by replacing it with the new line
         */
        if (empty_buffer && lnum == 0) {
          ml_replace((linenr_T)1, uep->ue_array[i], true);
        } else {
          ml_append(lnum, uep->ue_array[i], (colnr_T)0, false);
        }
        xfree(uep->ue_array[i]);
      }
      xfree((char_u *)uep->ue_array);
    }

    /* adjust marks */
    if (oldsize != newsize) {
      mark_adjust(top + 1, top + oldsize, (long)MAXLNUM,
                  (long)newsize - (long)oldsize, false);
      if (curbuf->b_op_start.lnum > top + oldsize) {
        curbuf->b_op_start.lnum += newsize - oldsize;
      }
      if (curbuf->b_op_end.lnum > top + oldsize) {
        curbuf->b_op_end.lnum += newsize - oldsize;
      }
    }

    changed_lines(top + 1, 0, bot, newsize - oldsize, do_buf_event);

    /* set '[ and '] mark */
    if (top + 1 < curbuf->b_op_start.lnum)
      curbuf->b_op_start.lnum = top + 1;
    if (newsize == 0 && top + 1 > curbuf->b_op_end.lnum)
      curbuf->b_op_end.lnum = top + 1;
    else if (top + newsize > curbuf->b_op_end.lnum)
      curbuf->b_op_end.lnum = top + newsize;

    u_newcount += newsize;
    u_oldcount += oldsize;
    uep->ue_size = oldsize;
    uep->ue_array = newarray;
    uep->ue_bot = top + newsize + 1;

    /*
     * insert this entry in front of the new entry list
     */
    nuep = uep->ue_next;
    uep->ue_next = newlist;
    newlist = uep;
  }

  curhead->uh_entry = newlist;
  curhead->uh_flags = new_flags;
  if ((old_flags & UH_EMPTYBUF) && BUFEMPTY()) {
    curbuf->b_ml.ml_flags |= ML_EMPTY;
  }
  if (old_flags & UH_CHANGED) {
    changed();
  } else {
    unchanged(curbuf, false, true);
  }

  // because the calls to changed()/unchanged() above will bump changedtick
  // again, we need to send a nvim_buf_lines_event with just the new value of
  // b:changedtick
  if (do_buf_event) {
    buf_updates_changedtick(curbuf);
  }

  /*
   * restore marks from before undo/redo
   */
  for (i = 0; i < NMARKS; ++i) {
    if (curhead->uh_namedm[i].mark.lnum != 0) {
      free_fmark(curbuf->b_namedm[i]);
      curbuf->b_namedm[i] = curhead->uh_namedm[i];
    }
    if (namedm[i].mark.lnum != 0) {
      curhead->uh_namedm[i] = namedm[i];
    } else {
      curhead->uh_namedm[i].mark.lnum = 0;
    }
  }
  if (curhead->uh_visual.vi_start.lnum != 0) {
    curbuf->b_visual = curhead->uh_visual;
    curhead->uh_visual = visualinfo;
  }

  /*
   * If the cursor is only off by one line, put it at the same position as
   * before starting the change (for the "o" command).
   * Otherwise the cursor should go to the first undone line.
   */
  if (curhead->uh_cursor.lnum + 1 == curwin->w_cursor.lnum
      && curwin->w_cursor.lnum > 1)
    --curwin->w_cursor.lnum;
  if (curwin->w_cursor.lnum <= curbuf->b_ml.ml_line_count) {
    if (curhead->uh_cursor.lnum == curwin->w_cursor.lnum) {
      curwin->w_cursor.col = curhead->uh_cursor.col;
      if (virtual_active() && curhead->uh_cursor_vcol >= 0)
        coladvance((colnr_T)curhead->uh_cursor_vcol);
      else
        curwin->w_cursor.coladd = 0;
    } else
      beginline(BL_SOL | BL_FIX);
  } else {
    /* We get here with the current cursor line being past the end (eg
     * after adding lines at the end of the file, and then undoing it).
     * check_cursor() will move the cursor to the last line.  Move it to
     * the first column here. */
    curwin->w_cursor.col = 0;
    curwin->w_cursor.coladd = 0;
  }

  /* Make sure the cursor is on an existing line and column. */
  check_cursor();

  /* Remember where we are for "g-" and ":earlier 10s". */
  curbuf->b_u_seq_cur = curhead->uh_seq;
  if (undo)
    /* We are below the previous undo.  However, to make ":earlier 1s"
     * work we compute this as being just above the just undone change. */
    curbuf->b_u_seq_cur = curhead->uh_next.ptr ?
        curhead->uh_next.ptr->uh_seq : 0;

  /* Remember where we are for ":earlier 1f" and ":later 1f". */
  if (curhead->uh_save_nr != 0) {
    if (undo)
      curbuf->b_u_save_nr_cur = curhead->uh_save_nr - 1;
    else
      curbuf->b_u_save_nr_cur = curhead->uh_save_nr;
  }

  /* The timestamp can be the same for multiple changes, just use the one of
   * the undone/redone change. */
  curbuf->b_u_time_cur = curhead->uh_time;

  unblock_autocmds();
#ifdef U_DEBUG
  u_check(FALSE);
#endif
}

/// If we deleted or added lines, report the number of less/more lines.
/// Otherwise, report the number of changes (this may be incorrect
/// in some cases, but it's better than nothing).
static void u_undo_end(
    bool did_undo,    ///< just did an undo
    bool absolute,    ///< used ":undo N"
    bool quiet)
{
  char        *msgstr;
  u_header_T  *uhp;
  char_u msgbuf[80];

  if ((fdo_flags & FDO_UNDO) && KeyTyped)
    foldOpenCursor();

  if (quiet
      || global_busy        // no messages until global is finished
      || !messaging()) {    // 'lazyredraw' set, don't do messages now
    return;
  }

  if (curbuf->b_ml.ml_flags & ML_EMPTY)
    --u_newcount;

  u_oldcount -= u_newcount;
  if (u_oldcount == -1)
    msgstr = N_("more line");
  else if (u_oldcount < 0)
    msgstr = N_("more lines");
  else if (u_oldcount == 1)
    msgstr = N_("line less");
  else if (u_oldcount > 1)
    msgstr = N_("fewer lines");
  else {
    u_oldcount = u_newcount;
    if (u_newcount == 1)
      msgstr = N_("change");
    else
      msgstr = N_("changes");
  }

  if (curbuf->b_u_curhead != NULL) {
    /* For ":undo N" we prefer a "after #N" message. */
    if (absolute && curbuf->b_u_curhead->uh_next.ptr != NULL) {
      uhp = curbuf->b_u_curhead->uh_next.ptr;
      did_undo = false;
    } else if (did_undo) {
      uhp = curbuf->b_u_curhead;
    } else {
      uhp = curbuf->b_u_curhead->uh_next.ptr;
    }
  } else {
    uhp = curbuf->b_u_newhead;
  }

  if (uhp == NULL)
    *msgbuf = NUL;
  else
    u_add_time(msgbuf, sizeof(msgbuf), uhp->uh_time);

  {
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_buffer == curbuf && wp->w_p_cole > 0) {
        redraw_win_later(wp, NOT_VALID);
      }
    }
  }

  smsg_attr_keep(
      0,
      _("%" PRId64 " %s; %s #%" PRId64 "  %s"),
      u_oldcount < 0 ? (int64_t)-u_oldcount : (int64_t)u_oldcount,
      _(msgstr),
      did_undo ? _("before") : _("after"),
      uhp == NULL ? (int64_t)0L : (int64_t)uhp->uh_seq,
      msgbuf);
}

/*
 * u_sync: stop adding to the current entry list
 */
void
u_sync(
    int force               // Also sync when no_u_sync is set.
)
{
  /* Skip it when already synced or syncing is disabled. */
  if (curbuf->b_u_synced || (!force && no_u_sync > 0))
    return;
  if (get_undolevel() < 0)
    curbuf->b_u_synced = true;      /* no entries, nothing to do */
  else {
    u_getbot();                     /* compute ue_bot of previous u_save */
    curbuf->b_u_curhead = NULL;
  }
}

/*
 * ":undolist": List the leafs of the undo tree
 */
void ex_undolist(exarg_T *eap)
{
  garray_T ga;
  u_header_T  *uhp;
  int mark;
  int nomark;
  int changes = 1;

  /*
   * 1: walk the tree to find all leafs, put the info in "ga".
   * 2: sort the lines
   * 3: display the list
   */
  mark = ++lastmark;
  nomark = ++lastmark;
  ga_init(&ga, (int)sizeof(char *), 20);

  uhp = curbuf->b_u_oldhead;
  while (uhp != NULL) {
    if (uhp->uh_prev.ptr == NULL && uhp->uh_walk != nomark
        && uhp->uh_walk != mark) {
      vim_snprintf((char *)IObuff, IOSIZE, "%6ld %7d  ",
                   uhp->uh_seq, changes);
      u_add_time(IObuff + STRLEN(IObuff), IOSIZE - STRLEN(IObuff),
          uhp->uh_time);
      if (uhp->uh_save_nr > 0) {
        while (STRLEN(IObuff) < 33)
          STRCAT(IObuff, " ");
        vim_snprintf_add((char *)IObuff, IOSIZE,
            "  %3ld", uhp->uh_save_nr);
      }
      GA_APPEND(char_u *, &ga, vim_strsave(IObuff));
    }

    uhp->uh_walk = mark;

    /* go down in the tree if we haven't been there */
    if (uhp->uh_prev.ptr != NULL && uhp->uh_prev.ptr->uh_walk != nomark
        && uhp->uh_prev.ptr->uh_walk != mark) {
      uhp = uhp->uh_prev.ptr;
      ++changes;
    }
    /* go to alternate branch if we haven't been there */
    else if (uhp->uh_alt_next.ptr != NULL
             && uhp->uh_alt_next.ptr->uh_walk != nomark
             && uhp->uh_alt_next.ptr->uh_walk != mark)
      uhp = uhp->uh_alt_next.ptr;

    /* go up in the tree if we haven't been there and we are at the
     * start of alternate branches */
    else if (uhp->uh_next.ptr != NULL && uhp->uh_alt_prev.ptr == NULL
             && uhp->uh_next.ptr->uh_walk != nomark
             && uhp->uh_next.ptr->uh_walk != mark) {
      uhp = uhp->uh_next.ptr;
      --changes;
    } else {
      /* need to backtrack; mark this node as done */
      uhp->uh_walk = nomark;
      if (uhp->uh_alt_prev.ptr != NULL)
        uhp = uhp->uh_alt_prev.ptr;
      else {
        uhp = uhp->uh_next.ptr;
        --changes;
      }
    }
  }

  if (GA_EMPTY(&ga))
    MSG(_("Nothing to undo"));
  else {
    sort_strings((char_u **)ga.ga_data, ga.ga_len);

    msg_start();
    msg_puts_attr(_("number changes  when               saved"),
                  HL_ATTR(HLF_T));
    for (int i = 0; i < ga.ga_len && !got_int; i++) {
      msg_putchar('\n');
      if (got_int) {
        break;
      }
      msg_puts(((const char **)ga.ga_data)[i]);
    }
    msg_end();

    ga_clear_strings(&ga);
  }
}

/*
 * Put the timestamp of an undo header in "buf[buflen]" in a nice format.
 */
static void u_add_time(char_u *buf, size_t buflen, time_t tt)
{
  struct tm curtime;

  if (time(NULL) - tt >= 100) {
    os_localtime_r(&tt, &curtime);
    if (time(NULL) - tt < (60L * 60L * 12L))
      /* within 12 hours */
      (void)strftime((char *)buf, buflen, "%H:%M:%S", &curtime);
    else
      /* longer ago */
      (void)strftime((char *)buf, buflen, "%Y/%m/%d %H:%M:%S", &curtime);
  } else {
    int64_t seconds = time(NULL) - tt;
    vim_snprintf((char *)buf, buflen,
                 NGETTEXT("%" PRId64 " second ago",
                          "%" PRId64 " seconds ago", (uint32_t)seconds),
                 seconds);
  }
}

/*
 * ":undojoin": continue adding to the last entry list
 */
void ex_undojoin(exarg_T *eap)
{
  if (curbuf->b_u_newhead == NULL) {
    return;                 // nothing changed before
  }
  if (curbuf->b_u_curhead != NULL) {
    EMSG(_("E790: undojoin is not allowed after undo"));
    return;
  }
  if (!curbuf->b_u_synced) {
    return;                 // already unsynced
  }
  if (get_undolevel() < 0) {
    return;                 // no entries, nothing to do
  } else {
    curbuf->b_u_synced = false;  // Append next change to last entry
  }
}

/*
 * Called after writing or reloading the file and setting b_changed to FALSE.
 * Now an undo means that the buffer is modified.
 */
void u_unchanged(buf_T *buf)
{
  u_unch_branch(buf->b_u_oldhead);
  buf->b_did_warn = false;
}

/*
 * After reloading a buffer which was saved for 'undoreload': Find the first
 * line that was changed and set the cursor there.
 */
void u_find_first_changed(void)
{
  u_header_T  *uhp = curbuf->b_u_newhead;
  u_entry_T   *uep;
  linenr_T lnum;

  if (curbuf->b_u_curhead != NULL || uhp == NULL)
    return;      /* undid something in an autocmd? */

  /* Check that the last undo block was for the whole file. */
  uep = uhp->uh_entry;
  if (uep->ue_top != 0 || uep->ue_bot != 0)
    return;

  for (lnum = 1; lnum < curbuf->b_ml.ml_line_count
       && lnum <= uep->ue_size; ++lnum)
    if (STRCMP(ml_get_buf(curbuf, lnum, FALSE),
            uep->ue_array[lnum - 1]) != 0) {
      clearpos(&(uhp->uh_cursor));
      uhp->uh_cursor.lnum = lnum;
      return;
    }
  if (curbuf->b_ml.ml_line_count != uep->ue_size) {
    /* lines added or deleted at the end, put the cursor there */
    clearpos(&(uhp->uh_cursor));
    uhp->uh_cursor.lnum = lnum;
  }
}

/*
 * Increase the write count, store it in the last undo header, what would be
 * used for "u".
 */
void u_update_save_nr(buf_T *buf)
{
  u_header_T  *uhp;

  ++buf->b_u_save_nr_last;
  buf->b_u_save_nr_cur = buf->b_u_save_nr_last;
  uhp = buf->b_u_curhead;
  if (uhp != NULL)
    uhp = uhp->uh_next.ptr;
  else
    uhp = buf->b_u_newhead;
  if (uhp != NULL)
    uhp->uh_save_nr = buf->b_u_save_nr_last;
}

static void u_unch_branch(u_header_T *uhp)
{
  u_header_T  *uh;

  for (uh = uhp; uh != NULL; uh = uh->uh_prev.ptr) {
    uh->uh_flags |= UH_CHANGED;
    if (uh->uh_alt_next.ptr != NULL)
      u_unch_branch(uh->uh_alt_next.ptr);           /* recursive */
  }
}

/*
 * Get pointer to last added entry.
 * If it's not valid, give an error message and return NULL.
 */
static u_entry_T *u_get_headentry(void)
{
  if (curbuf->b_u_newhead == NULL || curbuf->b_u_newhead->uh_entry == NULL) {
    IEMSG(_("E439: undo list corrupt"));
    return NULL;
  }
  return curbuf->b_u_newhead->uh_entry;
}

/*
 * u_getbot(): compute the line number of the previous u_save
 *		It is called only when b_u_synced is false.
 */
static void u_getbot(void)
{
  u_entry_T   *uep;
  linenr_T extra;

  uep = u_get_headentry();      /* check for corrupt undo list */
  if (uep == NULL)
    return;

  uep = curbuf->b_u_newhead->uh_getbot_entry;
  if (uep != NULL) {
    /*
     * the new ue_bot is computed from the number of lines that has been
     * inserted (0 - deleted) since calling u_save. This is equal to the
     * old line count subtracted from the current line count.
     */
    extra = curbuf->b_ml.ml_line_count - uep->ue_lcount;
    uep->ue_bot = uep->ue_top + uep->ue_size + 1 + extra;
    if (uep->ue_bot < 1 || uep->ue_bot > curbuf->b_ml.ml_line_count) {
      IEMSG(_("E440: undo line missing"));
      uep->ue_bot = uep->ue_top + 1;        // assume all lines deleted, will
                                            // get all the old lines back
                                            // without deleting the current
                                            // ones
    }

    curbuf->b_u_newhead->uh_getbot_entry = NULL;
  }

  curbuf->b_u_synced = true;
}

/*
 * Free one header "uhp" and its entry list and adjust the pointers.
 */
static void
u_freeheader(
    buf_T *buf,
    u_header_T *uhp,
    u_header_T **uhpp         // if not NULL reset when freeing this header
)
{
  u_header_T      *uhap;

  /* When there is an alternate redo list free that branch completely,
   * because we can never go there. */
  if (uhp->uh_alt_next.ptr != NULL)
    u_freebranch(buf, uhp->uh_alt_next.ptr, uhpp);

  if (uhp->uh_alt_prev.ptr != NULL)
    uhp->uh_alt_prev.ptr->uh_alt_next.ptr = NULL;

  /* Update the links in the list to remove the header. */
  if (uhp->uh_next.ptr == NULL)
    buf->b_u_oldhead = uhp->uh_prev.ptr;
  else
    uhp->uh_next.ptr->uh_prev.ptr = uhp->uh_prev.ptr;

  if (uhp->uh_prev.ptr == NULL)
    buf->b_u_newhead = uhp->uh_next.ptr;
  else
    for (uhap = uhp->uh_prev.ptr; uhap != NULL;
         uhap = uhap->uh_alt_next.ptr)
      uhap->uh_next.ptr = uhp->uh_next.ptr;

  u_freeentries(buf, uhp, uhpp);
}

/*
 * Free an alternate branch and any following alternate branches.
 */
static void
u_freebranch(
    buf_T *buf,
    u_header_T *uhp,
    u_header_T **uhpp         // if not NULL reset when freeing this header
)
{
  u_header_T      *tofree, *next;

  /* If this is the top branch we may need to use u_freeheader() to update
   * all the pointers. */
  if (uhp == buf->b_u_oldhead) {
    while (buf->b_u_oldhead != NULL)
      u_freeheader(buf, buf->b_u_oldhead, uhpp);
    return;
  }

  if (uhp->uh_alt_prev.ptr != NULL)
    uhp->uh_alt_prev.ptr->uh_alt_next.ptr = NULL;

  next = uhp;
  while (next != NULL) {
    tofree = next;
    if (tofree->uh_alt_next.ptr != NULL)
      u_freebranch(buf, tofree->uh_alt_next.ptr, uhpp);         /* recursive */
    next = tofree->uh_prev.ptr;
    u_freeentries(buf, tofree, uhpp);
  }
}

/*
 * Free all the undo entries for one header and the header itself.
 * This means that "uhp" is invalid when returning.
 */
static void
u_freeentries(
    buf_T *buf,
    u_header_T *uhp,
    u_header_T **uhpp         // if not NULL reset when freeing this header
)
{
  u_entry_T       *uep, *nuep;

  /* Check for pointers to the header that become invalid now. */
  if (buf->b_u_curhead == uhp)
    buf->b_u_curhead = NULL;
  if (buf->b_u_newhead == uhp)
    buf->b_u_newhead = NULL;      /* freeing the newest entry */
  if (uhpp != NULL && uhp == *uhpp)
    *uhpp = NULL;

  for (uep = uhp->uh_entry; uep != NULL; uep = nuep) {
    nuep = uep->ue_next;
    u_freeentry(uep, uep->ue_size);
  }

#ifdef U_DEBUG
  uhp->uh_magic = 0;
#endif
  xfree((char_u *)uhp);
  --buf->b_u_numhead;
}

/*
 * free entry 'uep' and 'n' lines in uep->ue_array[]
 */
static void u_freeentry(u_entry_T *uep, long n)
{
  while (n > 0)
    xfree(uep->ue_array[--n]);
  xfree((char_u *)uep->ue_array);
#ifdef U_DEBUG
  uep->ue_magic = 0;
#endif
  xfree((char_u *)uep);
}

/*
 * invalidate the undo buffer; called when storage has already been released
 */
void u_clearall(buf_T *buf)
{
  buf->b_u_newhead = buf->b_u_oldhead = buf->b_u_curhead = NULL;
  buf->b_u_synced = true;
  buf->b_u_numhead = 0;
  buf->b_u_line_ptr = NULL;
  buf->b_u_line_lnum = 0;
}

/*
 * save the line "lnum" for the "U" command
 */
void u_saveline(linenr_T lnum)
{
  if (lnum == curbuf->b_u_line_lnum)        /* line is already saved */
    return;
  if (lnum < 1 || lnum > curbuf->b_ml.ml_line_count)   /* should never happen */
    return;
  u_clearline();
  curbuf->b_u_line_lnum = lnum;
  if (curwin->w_cursor.lnum == lnum)
    curbuf->b_u_line_colnr = curwin->w_cursor.col;
  else
    curbuf->b_u_line_colnr = 0;
  curbuf->b_u_line_ptr = u_save_line(lnum);
}

/*
 * clear the line saved for the "U" command
 * (this is used externally for crossing a line while in insert mode)
 */
void u_clearline(void)
{
  if (curbuf->b_u_line_ptr != NULL) {
    XFREE_CLEAR(curbuf->b_u_line_ptr);
    curbuf->b_u_line_lnum = 0;
  }
}

/*
 * Implementation of the "U" command.
 * Differentiation from vi: "U" can be undone with the next "U".
 * We also allow the cursor to be in another line.
 * Careful: may trigger autocommands that reload the buffer.
 */
void u_undoline(void)
{
  colnr_T t;
  char_u  *oldp;

  if (undo_off)
    return;

  if (curbuf->b_u_line_ptr == NULL
      || curbuf->b_u_line_lnum > curbuf->b_ml.ml_line_count) {
    beep_flush();
    return;
  }

  /* first save the line for the 'u' command */
  if (u_savecommon(curbuf->b_u_line_lnum - 1,
          curbuf->b_u_line_lnum + 1, (linenr_T)0, FALSE) == FAIL)
    return;
  oldp = u_save_line(curbuf->b_u_line_lnum);
  ml_replace(curbuf->b_u_line_lnum, curbuf->b_u_line_ptr, true);
  changed_bytes(curbuf->b_u_line_lnum, 0);
  xfree(curbuf->b_u_line_ptr);
  curbuf->b_u_line_ptr = oldp;

  t = curbuf->b_u_line_colnr;
  if (curwin->w_cursor.lnum == curbuf->b_u_line_lnum)
    curbuf->b_u_line_colnr = curwin->w_cursor.col;
  curwin->w_cursor.col = t;
  curwin->w_cursor.lnum = curbuf->b_u_line_lnum;
  check_cursor_col();
}

/*
 * Free all allocated memory blocks for the buffer 'buf'.
 */
void u_blockfree(buf_T *buf)
{
  while (buf->b_u_oldhead != NULL) {
#ifndef NDEBUG
    u_header_T *previous_oldhead = buf->b_u_oldhead;
#endif

    u_freeheader(buf, buf->b_u_oldhead, NULL);
    assert(buf->b_u_oldhead != previous_oldhead);
  }
  xfree(buf->b_u_line_ptr);
}

/*
 * u_save_line(): allocate memory and copy line 'lnum' into it.
 */
static char_u *u_save_line(linenr_T lnum)
{
  return vim_strsave(ml_get(lnum));
}

/// Check if the 'modified' flag is set, or 'ff' has changed (only need to
/// check the first character, because it can only be "dos", "unix" or "mac").
/// "nofile" and "scratch" type buffers are considered to always be unchanged.
///
/// @param buf The buffer to check
///
/// @return true if the buffer has changed
bool bufIsChanged(buf_T *buf)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  return !bt_dontwrite(buf) && (buf->b_changed || file_ff_differs(buf, true));
}

// Return true if any buffer has changes.  Also buffers that are not written.
bool anyBufIsChanged(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  FOR_ALL_BUFFERS(buf) {
    if (bufIsChanged(buf)) {
      return true;
    }
  }
  return false;
}

/// @see bufIsChanged
/// @return true if the current buffer has changed
bool curbufIsChanged(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  return bufIsChanged(curbuf);
}

/// Append the list of undo blocks to a newly allocated list
///
/// For use in undotree(). Recursive.
///
/// @param[in]  first_uhp  Undo blocks list to start with.
///
/// @return [allocated] List with a representation of undo blocks.
list_T *u_eval_tree(const u_header_T *const first_uhp)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_RET
{
  list_T *const list = tv_list_alloc(kListLenMayKnow);

  for (const u_header_T *uhp = first_uhp; uhp != NULL; uhp = uhp->uh_prev.ptr) {
    dict_T *const dict = tv_dict_alloc();
    tv_dict_add_nr(dict, S_LEN("seq"), (varnumber_T)uhp->uh_seq);
    tv_dict_add_nr(dict, S_LEN("time"), (varnumber_T)uhp->uh_time);
    if (uhp == curbuf->b_u_newhead) {
      tv_dict_add_nr(dict, S_LEN("newhead"), 1);
    }
    if (uhp == curbuf->b_u_curhead) {
      tv_dict_add_nr(dict, S_LEN("curhead"), 1);
    }
    if (uhp->uh_save_nr > 0) {
      tv_dict_add_nr(dict, S_LEN("save"), (varnumber_T)uhp->uh_save_nr);
    }

    if (uhp->uh_alt_next.ptr != NULL) {
      // Recursive call to add alternate undo tree.
      tv_dict_add_list(dict, S_LEN("alt"), u_eval_tree(uhp->uh_alt_next.ptr));
    }

    tv_list_append_dict(list, dict);
  }

  return list;
}
