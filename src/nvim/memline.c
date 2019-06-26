// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// for debugging
// #define CHECK(c, s) do { if (c) EMSG(s); } while (0)
#define CHECK(c, s) do { } while (0)

/*
 * memline.c: Contains the functions for appending, deleting and changing the
 * text lines. The memfile functions are used to store the information in
 * blocks of memory, backed up by a file. The structure of the information is
 * a tree.  The root of the tree is a pointer block. The leaves of the tree
 * are data blocks. In between may be several layers of pointer blocks,
 * forming branches.
 *
 * Three types of blocks are used:
 * - Block nr 0 contains information for recovery
 * - Pointer blocks contain list of pointers to other blocks.
 * - Data blocks contain the actual text.
 *
 * Block nr 0 contains the block0 structure (see below).
 *
 * Block nr 1 is the first pointer block. It is the root of the tree.
 * Other pointer blocks are branches.
 *
 *  If a line is too big to fit in a single page, the block containing that
 *  line is made big enough to hold the line. It may span several pages.
 *  Otherwise all blocks are one page.
 *
 *  A data block that was filled when starting to edit a file and was not
 *  changed since then, can have a negative block number. This means that it
 *  has not yet been assigned a place in the file. When recovering, the lines
 *  in this data block can be read from the original file. When the block is
 *  changed (lines appended/deleted/changed) or when it is flushed it gets a
 *  positive number. Use mf_trans_del() to get the new number, before calling
 *  mf_get().
 */

#include <assert.h>
#include <errno.h>
#include <inttypes.h>
#include <string.h>
#include <stdbool.h>
#include <fcntl.h>

#include "nvim/ascii.h"
#include "nvim/vim.h"
#include "nvim/memline.h"
#include "nvim/buffer.h"
#include "nvim/cursor.h"
#include "nvim/eval.h"
#include "nvim/getchar.h"
#include "nvim/fileio.h"
#include "nvim/func_attr.h"
#include "nvim/main.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memfile.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/misc1.h"
#include "nvim/option.h"
#include "nvim/os_unix.h"
#include "nvim/path.h"
#include "nvim/screen.h"
#include "nvim/sha256.h"
#include "nvim/spell.h"
#include "nvim/strings.h"
#include "nvim/ui.h"
#include "nvim/version.h"
#include "nvim/undo.h"
#include "nvim/window.h"
#include "nvim/os/os.h"
#include "nvim/os/process.h"
#include "nvim/os/input.h"

#ifndef UNIX            /* it's in os/unix_defs.h for Unix */
# include <time.h>
#endif

typedef struct block0 ZERO_BL;              /* contents of the first block */
typedef struct pointer_block PTR_BL;        /* contents of a pointer block */
typedef struct data_block DATA_BL;          /* contents of a data block */
typedef struct pointer_entry PTR_EN;        /* block/line-count pair */

#define DATA_ID        (('d' << 8) + 'a')   /* data block id */
#define PTR_ID         (('p' << 8) + 't')   /* pointer block id */
#define BLOCK0_ID0     'b'                  /* block 0 id 0 */
#define BLOCK0_ID1     '0'                  /* block 0 id 1 */

/*
 * pointer to a block, used in a pointer block
 */
struct pointer_entry {
  blocknr_T pe_bnum;            /* block number */
  linenr_T pe_line_count;       /* number of lines in this branch */
  linenr_T pe_old_lnum;         /* lnum for this block (for recovery) */
  int pe_page_count;            /* number of pages in block pe_bnum */
};

/*
 * A pointer block contains a list of branches in the tree.
 */
struct pointer_block {
  uint16_t pb_id;               /* ID for pointer block: PTR_ID */
  uint16_t pb_count;            /* number of pointers in this block */
  uint16_t pb_count_max;        /* maximum value for pb_count */
  PTR_EN pb_pointer[1];         /* list of pointers to blocks (actually longer)
                                 * followed by empty space until end of page */
};

/*
 * A data block is a leaf in the tree.
 *
 * The text of the lines is at the end of the block. The text of the first line
 * in the block is put at the end, the text of the second line in front of it,
 * etc. Thus the order of the lines is the opposite of the line number.
 */
struct data_block {
  uint16_t db_id;               /* ID for data block: DATA_ID */
  unsigned db_free;             /* free space available */
  unsigned db_txt_start;        /* byte where text starts */
  unsigned db_txt_end;          /* byte just after data block */
  linenr_T db_line_count;       /* number of lines in this block */
  unsigned db_index[1];         /* index for start of line (actually bigger)
                                 * followed by empty space upto db_txt_start
                                 * followed by the text in the lines until
                                 * end of page */
};

/*
 * The low bits of db_index hold the actual index. The topmost bit is
 * used for the global command to be able to mark a line.
 * This method is not clean, but otherwise there would be at least one extra
 * byte used for each line.
 * The mark has to be in this place to keep it with the correct line when other
 * lines are inserted or deleted.
 */
#define DB_MARKED       ((unsigned)1 << ((sizeof(unsigned) * 8) - 1))
#define DB_INDEX_MASK   (~DB_MARKED)

#define INDEX_SIZE  (sizeof(unsigned))      /* size of one db_index entry */
#define HEADER_SIZE (sizeof(DATA_BL) - INDEX_SIZE)  /* size of data block header */

#define B0_FNAME_SIZE_ORG       900     /* what it was in older versions */
#define B0_FNAME_SIZE_NOCRYPT   898     /* 2 bytes used for other things */
#define B0_FNAME_SIZE_CRYPT     890     /* 10 bytes used for other things */
#define B0_UNAME_SIZE           40
#define B0_HNAME_SIZE           40
/*
 * Restrict the numbers to 32 bits, otherwise most compilers will complain.
 * This won't detect a 64 bit machine that only swaps a byte in the top 32
 * bits, but that is crazy anyway.
 */
#define B0_MAGIC_LONG   0x30313233L
#define B0_MAGIC_INT    0x20212223L
#define B0_MAGIC_SHORT  0x10111213L
#define B0_MAGIC_CHAR   0x55

/*
 * Block zero holds all info about the swap file.
 *
 * NOTE: DEFINITION OF BLOCK 0 SHOULD NOT CHANGE! It would make all existing
 * swap files unusable!
 *
 * If size of block0 changes anyway, adjust MIN_SWAP_PAGE_SIZE in vim.h!!
 *
 * This block is built up of single bytes, to make it portable across
 * different machines. b0_magic_* is used to check the byte order and size of
 * variables, because the rest of the swap file is not portable.
 */
struct block0 {
  char_u b0_id[2];              ///< ID for block 0: BLOCK0_ID0 and BLOCK0_ID1.
  char_u b0_version[10];        /* Vim version string */
  char_u b0_page_size[4];       /* number of bytes per page */
  char_u b0_mtime[4];           /* last modification time of file */
  char_u b0_ino[4];             /* inode of b0_fname */
  char_u b0_pid[4];             /* process id of creator (or 0) */
  char_u b0_uname[B0_UNAME_SIZE];        /* name of user (uid if no name) */
  char_u b0_hname[B0_HNAME_SIZE];        /* host name (if it has a name) */
  char_u b0_fname[B0_FNAME_SIZE_ORG];        /* name of file being edited */
  long b0_magic_long;           /* check for byte order of long */
  int b0_magic_int;             /* check for byte order of int */
  short b0_magic_short;         /* check for byte order of short */
  char_u b0_magic_char;         /* check for last char */
};

/*
 * Note: b0_dirty and b0_flags are put at the end of the file name.  For very
 * long file names in older versions of Vim they are invalid.
 * The 'fileencoding' comes before b0_flags, with a NUL in front.  But only
 * when there is room, for very long file names it's omitted.
 */
#define B0_DIRTY        0x55
#define b0_dirty        b0_fname[B0_FNAME_SIZE_ORG - 1]

/*
 * The b0_flags field is new in Vim 7.0.
 */
#define b0_flags        b0_fname[B0_FNAME_SIZE_ORG - 2]

/* The lowest two bits contain the fileformat.  Zero means it's not set
 * (compatible with Vim 6.x), otherwise it's EOL_UNIX + 1, EOL_DOS + 1 or
 * EOL_MAC + 1. */
#define B0_FF_MASK      3

/* Swap file is in directory of edited file.  Used to find the file from
 * different mount points. */
#define B0_SAME_DIR     4

/* The 'fileencoding' is at the end of b0_fname[], with a NUL in front of it.
 * When empty there is only the NUL. */
#define B0_HAS_FENC     8

#define STACK_INCR      5       /* nr of entries added to ml_stack at a time */

/*
 * The line number where the first mark may be is remembered.
 * If it is 0 there are no marks at all.
 * (always used for the current buffer only, no buffer change possible while
 * executing a global command).
 */
static linenr_T lowest_marked = 0;

/*
 * arguments for ml_find_line()
 */
#define ML_DELETE       0x11        /* delete line */
#define ML_INSERT       0x12        /* insert line */
#define ML_FIND         0x13        /* just find the line */
#define ML_FLUSH        0x02        /* flush locked block */
#define ML_SIMPLE(x)    (x & 0x10)  /* DEL, INS or FIND */

/* argument for ml_upd_block0() */
typedef enum {
  UB_FNAME = 0          /* update timestamp and filename */
  , UB_SAME_DIR         /* update the B0_SAME_DIR flag */
} upd_block0_T;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "memline.c.generated.h"
#endif

/*
 * Open a new memline for "buf".
 *
 * Return FAIL for failure, OK otherwise.
 */
int ml_open(buf_T *buf)
{
  bhdr_T      *hp = NULL;
  ZERO_BL     *b0p;
  PTR_BL      *pp;
  DATA_BL     *dp;

  /*
   * init fields in memline struct
   */
  buf->b_ml.ml_stack_size = 0;   /* no stack yet */
  buf->b_ml.ml_stack = NULL;    /* no stack yet */
  buf->b_ml.ml_stack_top = 0;   /* nothing in the stack */
  buf->b_ml.ml_locked = NULL;   /* no cached block */
  buf->b_ml.ml_line_lnum = 0;   /* no cached line */
  buf->b_ml.ml_chunksize = NULL;

  if (cmdmod.noswapfile) {
    buf->b_p_swf = false;
  }

  /*
   * When 'updatecount' is non-zero swap file may be opened later.
   */
  if (!buf->terminal && p_uc && buf->b_p_swf) {
    buf->b_may_swap = true;
  } else {
    buf->b_may_swap = false;
  }

  // Open the memfile.  No swap file is created yet.
  memfile_T *mfp = mf_open(NULL, 0);
  if (mfp == NULL) {
    goto error;
  }

  buf->b_ml.ml_mfp = mfp;
  buf->b_ml.ml_flags = ML_EMPTY;
  buf->b_ml.ml_line_count = 1;
  curwin->w_nrwidth_line_count = 0;


  /*
   * fill block0 struct and write page 0
   */
  hp = mf_new(mfp, false, 1);
  if (hp->bh_bnum != 0) {
    IEMSG(_("E298: Didn't get block nr 0?"));
    goto error;
  }
  b0p = hp->bh_data;

  b0p->b0_id[0] = BLOCK0_ID0;
  b0p->b0_id[1] = BLOCK0_ID1;
  b0p->b0_magic_long = (long)B0_MAGIC_LONG;
  b0p->b0_magic_int = (int)B0_MAGIC_INT;
  b0p->b0_magic_short = (short)B0_MAGIC_SHORT;
  b0p->b0_magic_char = B0_MAGIC_CHAR;
  xstrlcpy(xstpcpy((char *) b0p->b0_version, "VIM "), Version, 6);
  long_to_char((long)mfp->mf_page_size, b0p->b0_page_size);

  if (!buf->b_spell) {
    b0p->b0_dirty = buf->b_changed ? B0_DIRTY : 0;
    b0p->b0_flags = get_fileformat(buf) + 1;
    set_b0_fname(b0p, buf);
    (void)os_get_user_name((char *)b0p->b0_uname, B0_UNAME_SIZE);
    b0p->b0_uname[B0_UNAME_SIZE - 1] = NUL;
    os_get_hostname((char *)b0p->b0_hname, B0_HNAME_SIZE);
    b0p->b0_hname[B0_HNAME_SIZE - 1] = NUL;
    long_to_char(os_get_pid(), b0p->b0_pid);
  }

  /*
   * Always sync block number 0 to disk, so we can check the file name in
   * the swap file in findswapname(). Don't do this for a help files or
   * a spell buffer though.
   * Only works when there's a swapfile, otherwise it's done when the file
   * is created.
   */
  mf_put(mfp, hp, true, false);
  if (!buf->b_help && !B_SPELL(buf))
    (void)mf_sync(mfp, 0);

  /*
   * Fill in root pointer block and write page 1.
   */
  if ((hp = ml_new_ptr(mfp)) == NULL)
    goto error;
  if (hp->bh_bnum != 1) {
    IEMSG(_("E298: Didn't get block nr 1?"));
    goto error;
  }
  pp = hp->bh_data;
  pp->pb_count = 1;
  pp->pb_pointer[0].pe_bnum = 2;
  pp->pb_pointer[0].pe_page_count = 1;
  pp->pb_pointer[0].pe_old_lnum = 1;
  pp->pb_pointer[0].pe_line_count = 1;      /* line count after insertion */
  mf_put(mfp, hp, true, false);

  /*
   * Allocate first data block and create an empty line 1.
   */
  hp = ml_new_data(mfp, false, 1);
  if (hp->bh_bnum != 2) {
    IEMSG(_("E298: Didn't get block nr 2?"));
    goto error;
  }

  dp = hp->bh_data;
  dp->db_index[0] = --dp->db_txt_start;         /* at end of block */
  dp->db_free -= 1 + INDEX_SIZE;
  dp->db_line_count = 1;
  *((char_u *)dp + dp->db_txt_start) = NUL;     /* empty line */

  return OK;

error:
  if (mfp != NULL) {
    if (hp) {
      mf_put(mfp, hp, false, false);
    }
    mf_close(mfp, true);  // will also xfree(mfp->mf_fname)
  }
  buf->b_ml.ml_mfp = NULL;
  return FAIL;
}

/*
 * ml_setname() is called when the file name of "buf" has been changed.
 * It may rename the swap file.
 */
void ml_setname(buf_T *buf)
{
  int success = FALSE;
  memfile_T   *mfp;
  char_u      *fname;
  char_u      *dirp;

  mfp = buf->b_ml.ml_mfp;
  if (mfp->mf_fd < 0) {             /* there is no swap file yet */
    /*
     * When 'updatecount' is 0 and 'noswapfile' there is no swap file.
     * For help files we will make a swap file now.
     */
    if (p_uc != 0 && !cmdmod.noswapfile) {
      ml_open_file(buf); /* create a swap file */
    }
    return;
  }

  /*
   * Try all directories in the 'directory' option.
   */
  dirp = p_dir;
  bool found_existing_dir = false;
  for (;; ) {
    if (*dirp == NUL)               /* tried all directories, fail */
      break;
    fname = (char_u *)findswapname(buf, (char **)&dirp, (char *)mfp->mf_fname,
                                   &found_existing_dir);
    /* alloc's fname */
    if (dirp == NULL)               /* out of memory */
      break;
    if (fname == NULL)              /* no file name found for this dir */
      continue;

    /* if the file name is the same we don't have to do anything */
    if (fnamecmp(fname, mfp->mf_fname) == 0) {
      xfree(fname);
      success = TRUE;
      break;
    }
    /* need to close the swap file before renaming */
    if (mfp->mf_fd >= 0) {
      close(mfp->mf_fd);
      mfp->mf_fd = -1;
    }

    /* try to rename the swap file */
    if (vim_rename(mfp->mf_fname, fname) == 0) {
      success = TRUE;
      mf_free_fnames(mfp);
      mf_set_fnames(mfp, fname);
      ml_upd_block0(buf, UB_SAME_DIR);
      break;
    }
    xfree(fname);                /* this fname didn't work, try another */
  }

  if (mfp->mf_fd == -1) {           /* need to (re)open the swap file */
    mfp->mf_fd = os_open((char *)mfp->mf_fname, O_RDWR, 0);
    if (mfp->mf_fd < 0) {
      /* could not (re)open the swap file, what can we do???? */
      EMSG(_("E301: Oops, lost the swap file!!!"));
      return;
    }
    (void)os_set_cloexec(mfp->mf_fd);
  }
  if (!success)
    EMSG(_("E302: Could not rename swap file"));
}

/*
 * Open a file for the memfile for all buffers that are not readonly or have
 * been modified.
 * Used when 'updatecount' changes from zero to non-zero.
 */
void ml_open_files(void)
{
  FOR_ALL_BUFFERS(buf) {
    if (!buf->b_p_ro || buf->b_changed) {
      ml_open_file(buf);
    }
  }
}

/*
 * Open a swap file for an existing memfile, if there is no swap file yet.
 * If we are unable to find a file name, mf_fname will be NULL
 * and the memfile will be in memory only (no recovery possible).
 */
void ml_open_file(buf_T *buf)
{
  memfile_T   *mfp;
  char_u      *fname;
  char_u      *dirp;

  mfp = buf->b_ml.ml_mfp;
  if (mfp == NULL || mfp->mf_fd >= 0 || !buf->b_p_swf || cmdmod.noswapfile
      || buf->terminal) {
    return; /* nothing to do */
  }

  /* For a spell buffer use a temp file name. */
  if (buf->b_spell) {
    fname = vim_tempname();
    if (fname != NULL)
      (void)mf_open_file(mfp, fname);           /* consumes fname! */
    buf->b_may_swap = false;
    return;
  }

  /*
   * Try all directories in 'directory' option.
   */
  dirp = p_dir;
  bool found_existing_dir = false;
  for (;; ) {
    if (*dirp == NUL)
      break;
    // There is a small chance that between choosing the swap file name
    // and creating it, another Vim creates the file.  In that case the
    // creation will fail and we will use another directory.
    fname = (char_u *)findswapname(buf, (char **)&dirp, NULL,
                                   &found_existing_dir);
    if (dirp == NULL)
      break;        /* out of memory */
    if (fname == NULL)
      continue;
    if (mf_open_file(mfp, fname) == OK) {       /* consumes fname! */
      ml_upd_block0(buf, UB_SAME_DIR);

      /* Flush block zero, so others can read it */
      if (mf_sync(mfp, MFS_ZERO) == OK) {
        /* Mark all blocks that should be in the swapfile as dirty.
         * Needed for when the 'swapfile' option was reset, so that
         * the swap file was deleted, and then on again. */
        mf_set_dirty(mfp);
        break;
      }
      /* Writing block 0 failed: close the file and try another dir */
      mf_close_file(buf, false);
    }
  }

  if (mfp->mf_fname == NULL) {          /* Failed! */
    need_wait_return = TRUE;            /* call wait_return later */
    ++no_wait_return;
    (void)EMSG2(_(
            "E303: Unable to open swap file for \"%s\", recovery impossible"),
        buf_spname(buf) != NULL ? buf_spname(buf) : buf->b_fname);
    --no_wait_return;
  }

  /* don't try to open a swap file again */
  buf->b_may_swap = false;
}

/// If still need to create a swap file, and starting to edit a not-readonly
/// file, or reading into an existing buffer, create a swap file now.
///
/// @param newfile reading file into new buffer
void check_need_swap(int newfile)
{
  int old_msg_silent = msg_silent;  // might be reset by an E325 message
  msg_silent = 0;  // If swap dialog prompts for input, user needs to see it!

  if (curbuf->b_may_swap && (!curbuf->b_p_ro || !newfile)) {
    ml_open_file(curbuf);
  }

  msg_silent = old_msg_silent;
}

/*
 * Close memline for buffer 'buf'.
 * If 'del_file' is TRUE, delete the swap file
 */
void ml_close(buf_T *buf, int del_file)
{
  if (buf->b_ml.ml_mfp == NULL)                 /* not open */
    return;
  mf_close(buf->b_ml.ml_mfp, del_file);       /* close the .swp file */
  if (buf->b_ml.ml_line_lnum != 0 && (buf->b_ml.ml_flags & ML_LINE_DIRTY))
    xfree(buf->b_ml.ml_line_ptr);
  xfree(buf->b_ml.ml_stack);
  XFREE_CLEAR(buf->b_ml.ml_chunksize);
  buf->b_ml.ml_mfp = NULL;

  /* Reset the "recovered" flag, give the ATTENTION prompt the next time
   * this buffer is loaded. */
  buf->b_flags &= ~BF_RECOVERED;
}

/*
 * Close all existing memlines and memfiles.
 * Only used when exiting.
 * When 'del_file' is TRUE, delete the memfiles.
 * But don't delete files that were ":preserve"d when we are POSIX compatible.
 */
void ml_close_all(int del_file)
{
  FOR_ALL_BUFFERS(buf) {
    ml_close(buf, del_file && ((buf->b_flags & BF_PRESERVED) == 0));
  }
  spell_delete_wordlist();      /* delete the internal wordlist */
  vim_deltempdir();             /* delete created temp directory */
}

/*
 * Close all memfiles for not modified buffers.
 * Only use just before exiting!
 */
void ml_close_notmod(void)
{
  FOR_ALL_BUFFERS(buf) {
    if (!bufIsChanged(buf)) {
      ml_close(buf, TRUE);          /* close all not-modified buffers */
    }
  }
}

/*
 * Update the timestamp in the .swp file.
 * Used when the file has been written.
 */
void ml_timestamp(buf_T *buf)
{
  ml_upd_block0(buf, UB_FNAME);
}

/// Checks whether the IDs in b0 are valid.
static bool ml_check_b0_id(ZERO_BL *b0p)
  FUNC_ATTR_NONNULL_ALL
{
  return b0p->b0_id[0] == BLOCK0_ID0 && b0p->b0_id[1] == BLOCK0_ID1;
}

/// Checks whether all strings in b0 are valid (i.e. nul-terminated).
static bool ml_check_b0_strings(ZERO_BL *b0p)
  FUNC_ATTR_NONNULL_ALL
{
  return (memchr(b0p->b0_version, NUL, 10)
          && memchr(b0p->b0_uname, NUL, B0_UNAME_SIZE)
          && memchr(b0p->b0_hname, NUL, B0_HNAME_SIZE)
          && memchr(b0p->b0_fname, NUL, B0_FNAME_SIZE_CRYPT));  // -V512
}

/*
 * Update the timestamp or the B0_SAME_DIR flag of the .swp file.
 */
static void ml_upd_block0(buf_T *buf, upd_block0_T what)
{
  memfile_T   *mfp;
  bhdr_T      *hp;
  ZERO_BL     *b0p;

  mfp = buf->b_ml.ml_mfp;
  if (mfp == NULL || (hp = mf_get(mfp, 0, 1)) == NULL)
    return;
  b0p = hp->bh_data;
  if (ml_check_b0_id(b0p) == FAIL) {
    IEMSG(_("E304: ml_upd_block0(): Didn't get block 0??"));
  } else {
    if (what == UB_FNAME) {
      set_b0_fname(b0p, buf);
    } else {    // what == UB_SAME_DIR
      set_b0_dir_flag(b0p, buf);
    }
  }
  mf_put(mfp, hp, true, false);
}

/*
 * Write file name and timestamp into block 0 of a swap file.
 * Also set buf->b_mtime.
 * Don't use NameBuff[]!!!
 */
static void set_b0_fname(ZERO_BL *b0p, buf_T *buf)
{
  if (buf->b_ffname == NULL)
    b0p->b0_fname[0] = NUL;
  else {
    char uname[B0_UNAME_SIZE];

    /*
     * For a file under the home directory of the current user, we try to
     * replace the home directory path with "~user". This helps when
     * editing the same file on different machines over a network.
     * First replace home dir path with "~/" with home_replace().
     * Then insert the user name to get "~user/".
     */
    home_replace(NULL, buf->b_ffname, b0p->b0_fname,
        B0_FNAME_SIZE_CRYPT, TRUE);
    if (b0p->b0_fname[0] == '~') {
      /* If there is no user name or it is too long, don't use "~/" */
      int retval = os_get_user_name(uname, B0_UNAME_SIZE);
      size_t ulen = STRLEN(uname);
      size_t flen = STRLEN(b0p->b0_fname);
      if (retval == FAIL || ulen + flen > B0_FNAME_SIZE_CRYPT - 1) {
        STRLCPY(b0p->b0_fname, buf->b_ffname, B0_FNAME_SIZE_CRYPT);
      } else {
        memmove(b0p->b0_fname + ulen + 1, b0p->b0_fname + 1, flen);
        memmove(b0p->b0_fname + 1, uname, ulen);
      }
    }
    FileInfo file_info;
    if (os_fileinfo((char *)buf->b_ffname, &file_info)) {
      long_to_char(file_info.stat.st_mtim.tv_sec, b0p->b0_mtime);
      long_to_char((long)os_fileinfo_inode(&file_info), b0p->b0_ino);
      buf_store_file_info(buf, &file_info);
      buf->b_mtime_read = buf->b_mtime;
    } else {
      long_to_char(0L, b0p->b0_mtime);
      long_to_char(0L, b0p->b0_ino);
      buf->b_mtime = 0;
      buf->b_mtime_read = 0;
      buf->b_orig_size = 0;
      buf->b_orig_mode = 0;
    }
  }

  /* Also add the 'fileencoding' if there is room. */
  add_b0_fenc(b0p, curbuf);
}

/*
 * Update the B0_SAME_DIR flag of the swap file.  It's set if the file and the
 * swapfile for "buf" are in the same directory.
 * This is fail safe: if we are not sure the directories are equal the flag is
 * not set.
 */
static void set_b0_dir_flag(ZERO_BL *b0p, buf_T *buf)
{
  if (same_directory(buf->b_ml.ml_mfp->mf_fname, buf->b_ffname))
    b0p->b0_flags |= B0_SAME_DIR;
  else
    b0p->b0_flags &= ~B0_SAME_DIR;
}

/*
 * When there is room, add the 'fileencoding' to block zero.
 */
static void add_b0_fenc(ZERO_BL *b0p, buf_T *buf)
{
  int n;
  int size = B0_FNAME_SIZE_NOCRYPT;

  n = (int)STRLEN(buf->b_p_fenc);
  if ((int)STRLEN(b0p->b0_fname) + n + 1 > size)
    b0p->b0_flags &= ~B0_HAS_FENC;
  else {
    memmove((char *)b0p->b0_fname + size - n,
        (char *)buf->b_p_fenc, (size_t)n);
    *(b0p->b0_fname + size - n - 1) = NUL;
    b0p->b0_flags |= B0_HAS_FENC;
  }
}


/*
 * Try to recover curbuf from the .swp file.
 */
void ml_recover(void)
{
  buf_T       *buf = NULL;
  memfile_T   *mfp = NULL;
  char_u      *fname;
  char_u      *fname_used = NULL;
  bhdr_T      *hp = NULL;
  ZERO_BL     *b0p;
  int b0_ff;
  char_u      *b0_fenc = NULL;
  PTR_BL      *pp;
  DATA_BL     *dp;
  infoptr_T   *ip;
  blocknr_T bnum;
  int page_count;
  int len;
  int directly;
  linenr_T lnum;
  char_u      *p;
  int i;
  long error;
  int cannot_open;
  linenr_T line_count;
  bool has_error;
  int idx;
  int top;
  int txt_start;
  off_T size;
  int called_from_main;
  int serious_error = TRUE;
  long mtime;
  int attr;
  int orig_file_status = NOTDONE;

  recoverymode = TRUE;
  called_from_main = (curbuf->b_ml.ml_mfp == NULL);
  attr = HL_ATTR(HLF_E);

  // If the file name ends in ".s[a-w][a-z]" we assume this is the swap file.
  // Otherwise a search is done to find the swap file(s).
  fname = curbuf->b_fname;
  if (fname == NULL)                /* When there is no file name */
    fname = (char_u *)"";
  len = (int)STRLEN(fname);
  if (len >= 4
      && STRNICMP(fname + len - 4, ".s", 2) == 0
      && vim_strchr((char_u *)"abcdefghijklmnopqrstuvw",
                    TOLOWER_ASC(fname[len - 2])) != NULL
      && ASCII_ISALPHA(fname[len - 1])) {
    directly = TRUE;
    fname_used = vim_strsave(fname);     /* make a copy for mf_open() */
  } else {
    directly = FALSE;

    /* count the number of matching swap files */
    len = recover_names(fname, FALSE, 0, NULL);
    if (len == 0) {                 /* no swap files found */
      EMSG2(_("E305: No swap file found for %s"), fname);
      goto theend;
    }
    if (len == 1)                   /* one swap file found, use it */
      i = 1;
    else {                          /* several swap files found, choose */
      /* list the names of the swap files */
      (void)recover_names(fname, TRUE, 0, NULL);
      msg_putchar('\n');
      MSG_PUTS(_("Enter number of swap file to use (0 to quit): "));
      i = get_number(FALSE, NULL);
      if (i < 1 || i > len)
        goto theend;
    }
    /* get the swap file name that will be used */
    (void)recover_names(fname, FALSE, i, &fname_used);
  }
  if (fname_used == NULL)
    goto theend;  // user chose invalid number.

  /* When called from main() still need to initialize storage structure */
  if (called_from_main && ml_open(curbuf) == FAIL)
    getout(1);

  /*
   * Allocate a buffer structure for the swap file that is used for recovery.
   * Only the memline in it is really used.
   */
  buf = xmalloc(sizeof(buf_T));

  /*
   * init fields in memline struct
   */
  buf->b_ml.ml_stack_size = 0;          /* no stack yet */
  buf->b_ml.ml_stack = NULL;            /* no stack yet */
  buf->b_ml.ml_stack_top = 0;           /* nothing in the stack */
  buf->b_ml.ml_line_lnum = 0;           /* no cached line */
  buf->b_ml.ml_locked = NULL;           /* no locked block */
  buf->b_ml.ml_flags = 0;

  /*
   * open the memfile from the old swap file
   */
  p = vim_strsave(fname_used);   /* save "fname_used" for the message:
                                    mf_open() will consume "fname_used"! */
  mfp = mf_open(fname_used, O_RDONLY);
  fname_used = p;
  if (mfp == NULL || mfp->mf_fd < 0) {
    EMSG2(_("E306: Cannot open %s"), fname_used);
    goto theend;
  }
  buf->b_ml.ml_mfp = mfp;

  /*
   * The page size set in mf_open() might be different from the page size
   * used in the swap file, we must get it from block 0.  But to read block
   * 0 we need a page size.  Use the minimal size for block 0 here, it will
   * be set to the real value below.
   */
  mfp->mf_page_size = MIN_SWAP_PAGE_SIZE;

  /*
   * try to read block 0
   */
  if ((hp = mf_get(mfp, 0, 1)) == NULL) {
    msg_start();
    MSG_PUTS_ATTR(_("Unable to read block 0 from "), attr | MSG_HIST);
    msg_outtrans_attr(mfp->mf_fname, attr | MSG_HIST);
    MSG_PUTS_ATTR(_(
            "\nMaybe no changes were made or Vim did not update the swap file."),
        attr | MSG_HIST);
    msg_end();
    goto theend;
  }
  b0p = hp->bh_data;
  if (STRNCMP(b0p->b0_version, "VIM 3.0", 7) == 0) {
    msg_start();
    msg_outtrans_attr(mfp->mf_fname, MSG_HIST);
    MSG_PUTS_ATTR(_(" cannot be used with this version of Vim.\n"),
        MSG_HIST);
    MSG_PUTS_ATTR(_("Use Vim version 3.0.\n"), MSG_HIST);
    msg_end();
    goto theend;
  }
  if (ml_check_b0_id(b0p) == FAIL) {
    EMSG2(_("E307: %s does not look like a Vim swap file"), mfp->mf_fname);
    goto theend;
  }
  if (b0_magic_wrong(b0p)) {
    msg_start();
    msg_outtrans_attr(mfp->mf_fname, attr | MSG_HIST);
    MSG_PUTS_ATTR(_(" cannot be used on this computer.\n"),
        attr | MSG_HIST);
    MSG_PUTS_ATTR(_("The file was created on "), attr | MSG_HIST);
    /* avoid going past the end of a corrupted hostname */
    b0p->b0_fname[0] = NUL;
    MSG_PUTS_ATTR(b0p->b0_hname, attr | MSG_HIST);
    MSG_PUTS_ATTR(_(",\nor the file has been damaged."), attr | MSG_HIST);
    msg_end();
    goto theend;
  }

  /*
   * If we guessed the wrong page size, we have to recalculate the
   * highest block number in the file.
   */
  if (mfp->mf_page_size != (unsigned)char_to_long(b0p->b0_page_size)) {
    unsigned previous_page_size = mfp->mf_page_size;

    mf_new_page_size(mfp, (unsigned)char_to_long(b0p->b0_page_size));
    if (mfp->mf_page_size < previous_page_size) {
      msg_start();
      msg_outtrans_attr(mfp->mf_fname, attr | MSG_HIST);
      MSG_PUTS_ATTR(_(
              " has been damaged (page size is smaller than minimum value).\n"),
          attr | MSG_HIST);
      msg_end();
      goto theend;
    }
    if ((size = vim_lseek(mfp->mf_fd, (off_T)0L, SEEK_END)) <= 0) {
      mfp->mf_blocknr_max = 0;              // no file or empty file
    } else {
      mfp->mf_blocknr_max = size / mfp->mf_page_size;
    }
    mfp->mf_infile_count = mfp->mf_blocknr_max;

    /* need to reallocate the memory used to store the data */
    p = xmalloc(mfp->mf_page_size);
    memmove(p, hp->bh_data, previous_page_size);
    xfree(hp->bh_data);
    hp->bh_data = p;
    b0p = hp->bh_data;
  }

  /*
   * If .swp file name given directly, use name from swap file for buffer.
   */
  if (directly) {
    expand_env(b0p->b0_fname, NameBuff, MAXPATHL);
    if (setfname(curbuf, NameBuff, NULL, TRUE) == FAIL)
      goto theend;
  }

  home_replace(NULL, mfp->mf_fname, NameBuff, MAXPATHL, TRUE);
  smsg(_("Using swap file \"%s\""), NameBuff);

  if (buf_spname(curbuf) != NULL)
    STRLCPY(NameBuff, buf_spname(curbuf), MAXPATHL);
  else
    home_replace(NULL, curbuf->b_ffname, NameBuff, MAXPATHL, TRUE);
  smsg(_("Original file \"%s\""), NameBuff);
  msg_putchar('\n');

  /*
   * check date of swap file and original file
   */
  FileInfo org_file_info;
  FileInfo swp_file_info;
  mtime = char_to_long(b0p->b0_mtime);
  if (curbuf->b_ffname != NULL
      && os_fileinfo((char *)curbuf->b_ffname, &org_file_info)
      && ((os_fileinfo((char *)mfp->mf_fname, &swp_file_info)
           && org_file_info.stat.st_mtim.tv_sec
              > swp_file_info.stat.st_mtim.tv_sec)
          || org_file_info.stat.st_mtim.tv_sec != mtime)) {
    EMSG(_("E308: Warning: Original file may have been changed"));
  }
  ui_flush();

  /* Get the 'fileformat' and 'fileencoding' from block zero. */
  b0_ff = (b0p->b0_flags & B0_FF_MASK);
  if (b0p->b0_flags & B0_HAS_FENC) {
    int fnsize = B0_FNAME_SIZE_NOCRYPT;

    for (p = b0p->b0_fname + fnsize; p > b0p->b0_fname && p[-1] != NUL; --p)
      ;
    b0_fenc = vim_strnsave(p, (int)(b0p->b0_fname + fnsize - p));
  }

  mf_put(mfp, hp, false, false);        /* release block 0 */
  hp = NULL;

  /*
   * Now that we are sure that the file is going to be recovered, clear the
   * contents of the current buffer.
   */
  while (!(curbuf->b_ml.ml_flags & ML_EMPTY)) {
    ml_delete((linenr_T)1, false);
  }

  /*
   * Try reading the original file to obtain the values of 'fileformat',
   * 'fileencoding', etc.  Ignore errors.  The text itself is not used.
   */
  if (curbuf->b_ffname != NULL)
    orig_file_status = readfile(curbuf->b_ffname, NULL, (linenr_T)0,
        (linenr_T)0, (linenr_T)MAXLNUM, NULL, READ_NEW);

  /* Use the 'fileformat' and 'fileencoding' as stored in the swap file. */
  if (b0_ff != 0)
    set_fileformat(b0_ff - 1, OPT_LOCAL);
  if (b0_fenc != NULL) {
    set_option_value("fenc", 0L, (char *)b0_fenc, OPT_LOCAL);
    xfree(b0_fenc);
  }
  unchanged(curbuf, TRUE);

  bnum = 1;             /* start with block 1 */
  page_count = 1;       /* which is 1 page */
  lnum = 0;             /* append after line 0 in curbuf */
  line_count = 0;
  idx = 0;              /* start with first index in block 1 */
  error = 0;
  buf->b_ml.ml_stack_top = 0;
  buf->b_ml.ml_stack = NULL;
  buf->b_ml.ml_stack_size = 0;          /* no stack yet */

  if (curbuf->b_ffname == NULL)
    cannot_open = TRUE;
  else
    cannot_open = FALSE;

  serious_error = FALSE;
  for (; !got_int; line_breakcheck()) {
    if (hp != NULL)
      mf_put(mfp, hp, false, false);            /* release previous block */

    /*
     * get block
     */
    if ((hp = mf_get(mfp, bnum, page_count)) == NULL) {
      if (bnum == 1) {
        EMSG2(_("E309: Unable to read block 1 from %s"), mfp->mf_fname);
        goto theend;
      }
      ++error;
      ml_append(lnum++, (char_u *)_("???MANY LINES MISSING"),
                (colnr_T)0, true);
    } else {          // there is a block
      pp = hp->bh_data;
      if (pp->pb_id == PTR_ID) {                /* it is a pointer block */
        /* check line count when using pointer block first time */
        if (idx == 0 && line_count != 0) {
          for (i = 0; i < (int)pp->pb_count; ++i)
            line_count -= pp->pb_pointer[i].pe_line_count;
          if (line_count != 0) {
            ++error;
            ml_append(lnum++, (char_u *)_("???LINE COUNT WRONG"),
                      (colnr_T)0, true);
          }
        }

        if (pp->pb_count == 0) {
          ml_append(lnum++, (char_u *)_("???EMPTY BLOCK"),
                    (colnr_T)0, true);
          error++;
        } else if (idx < (int)pp->pb_count) {         // go a block deeper
          if (pp->pb_pointer[idx].pe_bnum < 0) {
            /*
             * Data block with negative block number.
             * Try to read lines from the original file.
             * This is slow, but it works.
             */
            if (!cannot_open) {
              line_count = pp->pb_pointer[idx].pe_line_count;
              if (readfile(curbuf->b_ffname, NULL, lnum,
                           pp->pb_pointer[idx].pe_old_lnum - 1, line_count,
                           NULL, 0) != OK) {
                cannot_open = true;
              } else {
                lnum += line_count;
              }
            }
            if (cannot_open) {
              ++error;
              ml_append(lnum++, (char_u *)_("???LINES MISSING"),
                        (colnr_T)0, true);
            }
            ++idx;                  /* get same block again for next index */
            continue;
          }

          /*
           * going one block deeper in the tree
           */
          top = ml_add_stack(buf);  // new entry in stack
          ip = &(buf->b_ml.ml_stack[top]);
          ip->ip_bnum = bnum;
          ip->ip_index = idx;

          bnum = pp->pb_pointer[idx].pe_bnum;
          line_count = pp->pb_pointer[idx].pe_line_count;
          page_count = pp->pb_pointer[idx].pe_page_count;
          idx = 0;
          continue;
        }
      } else {            /* not a pointer block */
        dp = hp->bh_data;
        if (dp->db_id != DATA_ID) {             /* block id wrong */
          if (bnum == 1) {
            EMSG2(_("E310: Block 1 ID wrong (%s not a .swp file?)"),
                mfp->mf_fname);
            goto theend;
          }
          ++error;
          ml_append(lnum++, (char_u *)_("???BLOCK MISSING"),
                    (colnr_T)0, true);
        } else {
          // it is a data block
          // Append all the lines in this block
          has_error = false;
          // check length of block
          // if wrong, use length in pointer block
          if (page_count * mfp->mf_page_size != dp->db_txt_end) {
            ml_append(
                lnum++,
                (char_u *)_("??? from here until ???END lines"
                            " may be messed up"),
                (colnr_T)0, true);
            error++;
            has_error = true;
            dp->db_txt_end = page_count * mfp->mf_page_size;
          }

          /* make sure there is a NUL at the end of the block */
          *((char_u *)dp + dp->db_txt_end - 1) = NUL;

          /*
           * check number of lines in block
           * if wrong, use count in data block
           */
          if (line_count != dp->db_line_count) {
            ml_append(
                lnum++,
                (char_u *)_("??? from here until ???END lines"
                            " may have been inserted/deleted"),
                (colnr_T)0, true);
            error++;
            has_error = true;
          }

          for (i = 0; i < dp->db_line_count; ++i) {
            txt_start = (dp->db_index[i] & DB_INDEX_MASK);
            if (txt_start <= (int)HEADER_SIZE
                || txt_start >= (int)dp->db_txt_end) {
              p = (char_u *)"???";
              ++error;
            } else
              p = (char_u *)dp + txt_start;
            ml_append(lnum++, p, (colnr_T)0, true);
          }
          if (has_error) {
            ml_append(lnum++, (char_u *)_("???END"), (colnr_T)0, true);
          }
        }
      }
    }

    if (buf->b_ml.ml_stack_top == 0)            /* finished */
      break;

    /*
     * go one block up in the tree
     */
    ip = &(buf->b_ml.ml_stack[--(buf->b_ml.ml_stack_top)]);
    bnum = ip->ip_bnum;
    idx = ip->ip_index + 1;         /* go to next index */
    page_count = 1;
  }

  /*
   * Compare the buffer contents with the original file.  When they differ
   * set the 'modified' flag.
   * Lines 1 - lnum are the new contents.
   * Lines lnum + 1 to ml_line_count are the original contents.
   * Line ml_line_count + 1 in the dummy empty line.
   */
  if (orig_file_status != OK || curbuf->b_ml.ml_line_count != lnum * 2 + 1) {
    /* Recovering an empty file results in two lines and the first line is
     * empty.  Don't set the modified flag then. */
    if (!(curbuf->b_ml.ml_line_count == 2 && *ml_get(1) == NUL)) {
      changed_int();
      buf_inc_changedtick(curbuf);
    }
  } else {
    for (idx = 1; idx <= lnum; ++idx) {
      /* Need to copy one line, fetching the other one may flush it. */
      p = vim_strsave(ml_get(idx));
      i = STRCMP(p, ml_get(idx + lnum));
      xfree(p);
      if (i != 0) {
        changed_int();
        buf_inc_changedtick(curbuf);
        break;
      }
    }
  }

  /*
   * Delete the lines from the original file and the dummy line from the
   * empty buffer.  These will now be after the last line in the buffer.
   */
  while (curbuf->b_ml.ml_line_count > lnum
         && !(curbuf->b_ml.ml_flags & ML_EMPTY))
    ml_delete(curbuf->b_ml.ml_line_count, false);
  curbuf->b_flags |= BF_RECOVERED;

  recoverymode = FALSE;
  if (got_int)
    EMSG(_("E311: Recovery Interrupted"));
  else if (error) {
    ++no_wait_return;
    MSG(">>>>>>>>>>>>>");
    EMSG(_(
            "E312: Errors detected while recovering; look for lines starting with ???"));
    --no_wait_return;
    MSG(_("See \":help E312\" for more information."));
    MSG(">>>>>>>>>>>>>");
  } else {
    if (curbuf->b_changed) {
      MSG(_("Recovery completed. You should check if everything is OK."));
      MSG_PUTS(_(
              "\n(You might want to write out this file under another name\n"));
      MSG_PUTS(_("and run diff with the original file to check for changes)"));
    } else
      MSG(_("Recovery completed. Buffer contents equals file contents."));
    MSG_PUTS(_("\nYou may want to delete the .swp file now.\n\n"));
    cmdline_row = msg_row;
  }
  redraw_curbuf_later(NOT_VALID);

theend:
  xfree(fname_used);
  recoverymode = FALSE;
  if (mfp != NULL) {
    if (hp != NULL)
      mf_put(mfp, hp, false, false);
    mf_close(mfp, false);           /* will also xfree(mfp->mf_fname) */
  }
  if (buf != NULL) {  //may be NULL if swap file not found.
    xfree(buf->b_ml.ml_stack);
    xfree(buf);
  }
  if (serious_error && called_from_main)
    ml_close(curbuf, TRUE);
  else {
    apply_autocmds(EVENT_BUFREADPOST, NULL, curbuf->b_fname, FALSE, curbuf);
    apply_autocmds(EVENT_BUFWINENTER, NULL, curbuf->b_fname, FALSE, curbuf);
  }
  return;
}

/*
 * Find the names of swap files in current directory and the directory given
 * with the 'directory' option.
 *
 * Used to:
 * - list the swap files for "vim -r"
 * - count the number of swap files when recovering
 * - list the swap files when recovering
 * - find the name of the n'th swap file when recovering
 */
int 
recover_names (
    char_u *fname,             /* base for swap file name */
    int list,                       /* when TRUE, list the swap file names */
    int nr,                         /* when non-zero, return nr'th swap file name */
    char_u **fname_out        /* result when "nr" > 0 */
)
{
  int num_names;
  char_u      *(names[6]);
  char_u      *tail;
  char_u      *p;
  int num_files;
  int file_count = 0;
  char_u      **files;
  char_u      *dirp;
  char_u      *dir_name;
  char_u      *fname_res = NULL;
#ifdef HAVE_READLINK
  char_u fname_buf[MAXPATHL];
#endif

  if (fname != NULL) {
#ifdef HAVE_READLINK
    /* Expand symlink in the file name, because the swap file is created
     * with the actual file instead of with the symlink. */
    if (resolve_symlink(fname, fname_buf) == OK)
      fname_res = fname_buf;
    else
#endif
    fname_res = fname;
  }

  if (list) {
    /* use msg() to start the scrolling properly */
    msg((char_u *)_("Swap files found:"));
    msg_putchar('\n');
  }

  // Do the loop for every directory in 'directory'.
  // First allocate some memory to put the directory name in.
  dir_name = xmalloc(STRLEN(p_dir) + 1);
  dirp = p_dir;
  while (*dirp) {
    // Isolate a directory name from *dirp and put it in dir_name (we know
    // it is large enough, so use 31000 for length).
    // Advance dirp to next directory name.
    (void)copy_option_part(&dirp, dir_name, 31000, ",");

    if (dir_name[0] == '.' && dir_name[1] == NUL) {     /* check current dir */
      if (fname == NULL) {
        names[0] = vim_strsave((char_u *)"*.sw?");
        /* For Unix names starting with a dot are special.  MS-Windows
         * supports this too, on some file systems. */
        names[1] = vim_strsave((char_u *)".*.sw?");
        names[2] = vim_strsave((char_u *)".sw?");
        num_names = 3;
      } else
        num_names = recov_file_names(names, fname_res, TRUE);
    } else {                      /* check directory dir_name */
      if (fname == NULL) {
        names[0] = (char_u *)concat_fnames((char *)dir_name, "*.sw?", TRUE);
        /* For Unix names starting with a dot are special.  MS-Windows
         * supports this too, on some file systems. */
        names[1] = (char_u *)concat_fnames((char *)dir_name, ".*.sw?", TRUE);
        names[2] = (char_u *)concat_fnames((char *)dir_name, ".sw?", TRUE);
        num_names = 3;
      } else {
        int len = (int)STRLEN(dir_name);
        p = dir_name + len;
        if (after_pathsep((char *)dir_name, (char *)p)
            && len > 1
            && p[-1] == p[-2]) {
          // Ends with '//', Use Full path for swap name
          tail = (char_u *)make_percent_swname((char *)dir_name,
                                               (char *)fname_res);
        } else {
          tail = path_tail(fname_res);
          tail = (char_u *)concat_fnames((char *)dir_name, (char *)tail, TRUE);
        }
        num_names = recov_file_names(names, tail, FALSE);
        xfree(tail);
      }
    }

    if (num_names == 0)
      num_files = 0;
    else if (expand_wildcards(num_names, names, &num_files, &files,
                 EW_KEEPALL|EW_FILE|EW_SILENT) == FAIL)
      num_files = 0;

    /*
     * When no swap file found, wildcard expansion might have failed (e.g.
     * not able to execute the shell).
     * Try finding a swap file by simply adding ".swp" to the file name.
     */
    if (*dirp == NUL && file_count + num_files == 0 && fname != NULL) {
      char_u *swapname = (char_u *)modname((char *)fname_res, ".swp", TRUE);
      if (swapname != NULL) {
        if (os_path_exists(swapname)) {
          files = xmalloc(sizeof(char_u *));
          files[0] = swapname;
          swapname = NULL;
          num_files = 1;
        }
        xfree(swapname);
      }
    }

    /*
     * remove swapfile name of the current buffer, it must be ignored
     */
    if (curbuf->b_ml.ml_mfp != NULL
        && (p = curbuf->b_ml.ml_mfp->mf_fname) != NULL) {
      for (int i = 0; i < num_files; i++) {
        if (path_full_compare(p, files[i], true) & kEqualFiles) {
          // Remove the name from files[i].  Move further entries
          // down.  When the array becomes empty free it here, since
          // FreeWild() won't be called below.
          xfree(files[i]);
          if (--num_files == 0)
            xfree(files);
          else
            for (; i < num_files; ++i)
              files[i] = files[i + 1];
        }
      }
    }
    if (nr > 0) {
      file_count += num_files;
      if (nr <= file_count) {
        *fname_out = vim_strsave(
            files[nr - 1 + num_files - file_count]);
        dirp = (char_u *)"";                        /* stop searching */
      }
    } else if (list) {
      if (dir_name[0] == '.' && dir_name[1] == NUL) {
        if (fname == NULL)
          MSG_PUTS(_("   In current directory:\n"));
        else
          MSG_PUTS(_("   Using specified name:\n"));
      } else {
        MSG_PUTS(_("   In directory "));
        msg_home_replace(dir_name);
        MSG_PUTS(":\n");
      }

      if (num_files) {
        for (int i = 0; i < num_files; ++i) {
          /* print the swap file name */
          msg_outnum((long)++file_count);
          msg_puts(".    ");
          msg_puts((const char *)path_tail(files[i]));
          msg_putchar('\n');
          (void)swapfile_info(files[i]);
        }
      } else
        MSG_PUTS(_("      -- none --\n"));
      ui_flush();
    } else
      file_count += num_files;

    for (int i = 0; i < num_names; ++i)
      xfree(names[i]);
    if (num_files > 0)
      FreeWild(num_files, files);
  }
  xfree(dir_name);
  return file_count;
}

/*
 * Append the full path to name with path separators made into percent
 * signs, to dir. An unnamed buffer is handled as "" (<currentdir>/"")
 */
static char *make_percent_swname(const char *dir, char *name)
  FUNC_ATTR_NONNULL_ARG(1)
{
  char *d = NULL;
  char *f = fix_fname(name != NULL ? name : "");
  if (f != NULL) {
    char *s = xstrdup(f);
    for (d = s; *d != NUL; MB_PTR_ADV(d)) {
      if (vim_ispathsep(*d)) {
        *d = '%';
      }
    }
    d = concat_fnames(dir, s, TRUE);
    xfree(s);
    xfree(f);
  }
  return d;
}

static bool process_still_running;

/// Return information found in swapfile "fname" in dictionary "d".
/// This is used by the swapinfo() function.
void get_b0_dict(const char *fname, dict_T *d)
{
  int fd;
  struct block0 b0;

  if ((fd = os_open(fname, O_RDONLY, 0)) >= 0) {
    if (read_eintr(fd, &b0, sizeof(b0)) == sizeof(b0)) {
      if (ml_check_b0_id(&b0) == FAIL) {
        tv_dict_add_str(d, S_LEN("error"), "Not a swap file");
      } else if (b0_magic_wrong(&b0)) {
        tv_dict_add_str(d, S_LEN("error"), "Magic number mismatch");
      } else {
        // We have swap information.
        tv_dict_add_str_len(d, S_LEN("version"), (char *)b0.b0_version, 10);
        tv_dict_add_str_len(d, S_LEN("user"), (char *)b0.b0_uname,
                            B0_UNAME_SIZE);
        tv_dict_add_str_len(d, S_LEN("host"), (char *)b0.b0_hname,
                            B0_HNAME_SIZE);
        tv_dict_add_str_len(d, S_LEN("fname"), (char *)b0.b0_fname,
                            B0_FNAME_SIZE_ORG);

        tv_dict_add_nr(d, S_LEN("pid"), char_to_long(b0.b0_pid));
        tv_dict_add_nr(d, S_LEN("mtime"), char_to_long(b0.b0_mtime));
        tv_dict_add_nr(d, S_LEN("dirty"), b0.b0_dirty ? 1 : 0);
        tv_dict_add_nr(d, S_LEN("inode"), char_to_long(b0.b0_ino));
      }
    } else {
      tv_dict_add_str(d, S_LEN("error"), "Cannot read file");
    }
    close(fd);
  } else {
    tv_dict_add_str(d, S_LEN("error"), "Cannot open file");
  }
}

/// Give information about an existing swap file.
/// Returns timestamp (0 when unknown).
static time_t swapfile_info(char_u *fname)
{
  assert(fname != NULL);
  int fd;
  struct block0 b0;
  time_t x = (time_t)0;
  char            *p;
#ifdef UNIX
  char uname[B0_UNAME_SIZE];
#endif

  /* print the swap file date */
  FileInfo file_info;
  if (os_fileinfo((char *)fname, &file_info)) {
#ifdef UNIX
    /* print name of owner of the file */
    if (os_get_uname(file_info.stat.st_uid, uname, B0_UNAME_SIZE) == OK) {
      MSG_PUTS(_("          owned by: "));
      msg_outtrans((char_u *)uname);
      MSG_PUTS(_("   dated: "));
    } else
#endif
    MSG_PUTS(_("             dated: "));
    x = file_info.stat.st_mtim.tv_sec;
    p = ctime(&x);  // includes '\n'
    if (p == NULL)
      MSG_PUTS("(invalid)\n");
    else
      MSG_PUTS(p);
  }

  /*
   * print the original file name
   */
  fd = os_open((char *)fname, O_RDONLY, 0);
  if (fd >= 0) {
    if (read_eintr(fd, &b0, sizeof(b0)) == sizeof(b0)) {
      if (STRNCMP(b0.b0_version, "VIM 3.0", 7) == 0) {
        MSG_PUTS(_("         [from Vim version 3.0]"));
      } else if (ml_check_b0_id(&b0) == FAIL) {
        MSG_PUTS(_("         [does not look like a Vim swap file]"));
      } else if (!ml_check_b0_strings(&b0)) {
        MSG_PUTS(_("         [garbled strings (not nul terminated)]"));
      } else {
        MSG_PUTS(_("         file name: "));
        if (b0.b0_fname[0] == NUL)
          MSG_PUTS(_("[No Name]"));
        else
          msg_outtrans(b0.b0_fname);

        MSG_PUTS(_("\n          modified: "));
        MSG_PUTS(b0.b0_dirty ? _("YES") : _("no"));

        if (*(b0.b0_uname) != NUL) {
          MSG_PUTS(_("\n         user name: "));
          msg_outtrans(b0.b0_uname);
        }

        if (*(b0.b0_hname) != NUL) {
          if (*(b0.b0_uname) != NUL)
            MSG_PUTS(_("   host name: "));
          else
            MSG_PUTS(_("\n         host name: "));
          msg_outtrans(b0.b0_hname);
        }

        if (char_to_long(b0.b0_pid) != 0L) {
          MSG_PUTS(_("\n        process ID: "));
          msg_outnum(char_to_long(b0.b0_pid));
          if (os_proc_running((int)char_to_long(b0.b0_pid))) {
            MSG_PUTS(_(" (STILL RUNNING)"));
            process_still_running = true;
          }
        }

        if (b0_magic_wrong(&b0)) {
          MSG_PUTS(_("\n         [not usable on this computer]"));
        }
      }
    } else
      MSG_PUTS(_("         [cannot be read]"));
    close(fd);
  } else
    MSG_PUTS(_("         [cannot be opened]"));
  msg_putchar('\n');

  return x;
}

/// Returns TRUE if the swap file looks OK and there are no changes, thus it
/// can be safely deleted.
static time_t swapfile_unchanged(char *fname)
{
  struct block0 b0;
  int ret = true;

  // Swap file must exist.
  if (!os_path_exists((char_u *)fname)) {
    return false;
  }

  // must be able to read the first block
  int fd = os_open(fname, O_RDONLY, 0);
  if (fd < 0) {
    return false;
  }
  if (read_eintr(fd, &b0, sizeof(b0)) != sizeof(b0)) {
    close(fd);
    return false;
  }

  // the ID and magic number must be correct
  if (ml_check_b0_id(&b0) == FAIL|| b0_magic_wrong(&b0)) {
    ret = false;
  }

  // must be unchanged
  if (b0.b0_dirty) {
    ret = false;
  }

  // process must be known and not running.
  long pid = char_to_long(b0.b0_pid);
  if (pid == 0L || os_proc_running((int)pid)) {
    ret = false;
  }

  // TODO(bram): Should we check if the swap file was created on the current
  // system?  And the current user?

  close(fd);
  return ret;
}

static int recov_file_names(char_u **names, char_u *path, int prepend_dot)
  FUNC_ATTR_NONNULL_ALL
{
  int num_names = 0;

  // May also add the file name with a dot prepended, for swap file in same
  // dir as original file.
  if (prepend_dot) {
    names[num_names] = (char_u *)modname((char *)path, ".sw?", TRUE);
    if (names[num_names] == NULL)
      return num_names;
    ++num_names;
  }

  // Form the normal swap file name pattern by appending ".sw?".
  names[num_names] = (char_u *)concat_fnames((char *)path, ".sw?", FALSE);
  if (num_names >= 1) {     /* check if we have the same name twice */
    char_u *p = names[num_names - 1];
    int i = (int)STRLEN(names[num_names - 1]) - (int)STRLEN(names[num_names]);
    if (i > 0)
      p += i;               /* file name has been expanded to full path */

    if (STRCMP(p, names[num_names]) != 0)
      ++num_names;
    else
      xfree(names[num_names]);
  } else
    ++num_names;

  return num_names;
}

/*
 * sync all memlines
 *
 * If 'check_file' is TRUE, check if original file exists and was not changed.
 * If 'check_char' is TRUE, stop syncing when character becomes available, but
 * always sync at least one block.
 */
void ml_sync_all(int check_file, int check_char, bool do_fsync)
{
  FOR_ALL_BUFFERS(buf) {
    if (buf->b_ml.ml_mfp == NULL || buf->b_ml.ml_mfp->mf_fname == NULL)
      continue;                             /* no file */

    ml_flush_line(buf);                     /* flush buffered line */
                                            /* flush locked block */
    (void)ml_find_line(buf, (linenr_T)0, ML_FLUSH);
    if (bufIsChanged(buf) && check_file && mf_need_trans(buf->b_ml.ml_mfp)
        && buf->b_ffname != NULL) {
      /*
       * If the original file does not exist anymore or has been changed
       * call ml_preserve() to get rid of all negative numbered blocks.
       */
      FileInfo file_info;
      if (!os_fileinfo((char *)buf->b_ffname, &file_info)
          || file_info.stat.st_mtim.tv_sec != buf->b_mtime_read
          || os_fileinfo_size(&file_info) != buf->b_orig_size) {
        ml_preserve(buf, false, do_fsync);
        did_check_timestamps = false;
        need_check_timestamps = true;           // give message later
      }
    }
    if (buf->b_ml.ml_mfp->mf_dirty) {
      (void)mf_sync(buf->b_ml.ml_mfp, (check_char ? MFS_STOP : 0)
                    | (do_fsync && bufIsChanged(buf) ? MFS_FLUSH : 0));
      if (check_char && os_char_avail()) {      // character available now
        break;
      }
    }
  }
}

/*
 * sync one buffer, including negative blocks
 *
 * after this all the blocks are in the swap file
 *
 * Used for the :preserve command and when the original file has been
 * changed or deleted.
 *
 * when message is TRUE the success of preserving is reported
 */
void ml_preserve(buf_T *buf, int message, bool do_fsync)
{
  bhdr_T      *hp;
  linenr_T lnum;
  memfile_T   *mfp = buf->b_ml.ml_mfp;
  int status;
  int got_int_save = got_int;

  if (mfp == NULL || mfp->mf_fname == NULL) {
    if (message)
      EMSG(_("E313: Cannot preserve, there is no swap file"));
    return;
  }

  /* We only want to stop when interrupted here, not when interrupted
   * before. */
  got_int = FALSE;

  ml_flush_line(buf);                               // flush buffered line
  (void)ml_find_line(buf, (linenr_T)0, ML_FLUSH);   // flush locked block
  status = mf_sync(mfp, MFS_ALL | (do_fsync ? MFS_FLUSH : 0));

  /* stack is invalid after mf_sync(.., MFS_ALL) */
  buf->b_ml.ml_stack_top = 0;

  /*
   * Some of the data blocks may have been changed from negative to
   * positive block number. In that case the pointer blocks need to be
   * updated.
   *
   * We don't know in which pointer block the references are, so we visit
   * all data blocks until there are no more translations to be done (or
   * we hit the end of the file, which can only happen in case a write fails,
   * e.g. when file system if full).
   * ml_find_line() does the work by translating the negative block numbers
   * when getting the first line of each data block.
   */
  if (mf_need_trans(mfp) && !got_int) {
    lnum = 1;
    while (mf_need_trans(mfp) && lnum <= buf->b_ml.ml_line_count) {
      hp = ml_find_line(buf, lnum, ML_FIND);
      if (hp == NULL) {
        status = FAIL;
        goto theend;
      }
      CHECK(buf->b_ml.ml_locked_low != lnum, "low != lnum");
      lnum = buf->b_ml.ml_locked_high + 1;
    }
    (void)ml_find_line(buf, (linenr_T)0, ML_FLUSH);  // flush locked block
    // sync the updated pointer blocks
    if (mf_sync(mfp, MFS_ALL | (do_fsync ? MFS_FLUSH : 0)) == FAIL) {
      status = FAIL;
    }
    buf->b_ml.ml_stack_top = 0;  // stack is invalid now
  }
theend:
  got_int |= got_int_save;

  if (message) {
    if (status == OK)
      MSG(_("File preserved"));
    else
      EMSG(_("E314: Preserve failed"));
  }
}

/*
 * NOTE: The pointer returned by the ml_get_*() functions only remains valid
 * until the next call!
 *  line1 = ml_get(1);
 *  line2 = ml_get(2);	// line1 is now invalid!
 * Make a copy of the line if necessary.
 */
/*
 * Return a pointer to a (read-only copy of a) line.
 *
 * On failure an error message is given and IObuff is returned (to avoid
 * having to check for error everywhere).
 */
char_u *ml_get(linenr_T lnum)
{
  return ml_get_buf(curbuf, lnum, FALSE);
}

/*
 * Return pointer to position "pos".
 */
char_u *ml_get_pos(pos_T *pos)
{
  return ml_get_buf(curbuf, pos->lnum, FALSE) + pos->col;
}

/*
 * Return a pointer to a line in a specific buffer
 *
 * "will_change": if TRUE mark the buffer dirty (chars in the line will be
 * changed)
 */
char_u *
ml_get_buf (
    buf_T *buf,
    linenr_T lnum,
    bool will_change                        // line will be changed
)
{
  bhdr_T      *hp;
  DATA_BL     *dp;
  char_u      *ptr;
  static int recursive = 0;

  if (lnum > buf->b_ml.ml_line_count) { /* invalid line number */
    if (recursive == 0) {
      // Avoid giving this message for a recursive call, may happen when
      // the GUI redraws part of the text.
      recursive++;
      IEMSGN(_("E315: ml_get: invalid lnum: %" PRId64), lnum);
      recursive--;
    }
errorret:
    STRCPY(IObuff, "???");
    return IObuff;
  }
  if (lnum <= 0)                        /* pretend line 0 is line 1 */
    lnum = 1;

  if (buf->b_ml.ml_mfp == NULL)         /* there are no lines */
    return (char_u *)"";

  /*
   * See if it is the same line as requested last time.
   * Otherwise may need to flush last used line.
   * Don't use the last used line when 'swapfile' is reset, need to load all
   * blocks.
   */
  if (buf->b_ml.ml_line_lnum != lnum) {
    ml_flush_line(buf);

    /*
     * Find the data block containing the line.
     * This also fills the stack with the blocks from the root to the data
     * block and releases any locked block.
     */
    if ((hp = ml_find_line(buf, lnum, ML_FIND)) == NULL) {
      if (recursive == 0) {
        // Avoid giving this message for a recursive call, may happen
        // when the GUI redraws part of the text.
        recursive++;
        IEMSGN(_("E316: ml_get: cannot find line %" PRId64), lnum);
        recursive--;
      }
      goto errorret;
    }

    dp = hp->bh_data;

    ptr = (char_u *)dp +
          ((dp->db_index[lnum - buf->b_ml.ml_locked_low]) & DB_INDEX_MASK);
    buf->b_ml.ml_line_ptr = ptr;
    buf->b_ml.ml_line_lnum = lnum;
    buf->b_ml.ml_flags &= ~ML_LINE_DIRTY;
  }
  if (will_change)
    buf->b_ml.ml_flags |= (ML_LOCKED_DIRTY | ML_LOCKED_POS);

  return buf->b_ml.ml_line_ptr;
}

/*
 * Check if a line that was just obtained by a call to ml_get
 * is in allocated memory.
 */
int ml_line_alloced(void)
{
  return curbuf->b_ml.ml_flags & ML_LINE_DIRTY;
}

/*
 * Append a line after lnum (may be 0 to insert a line in front of the file).
 * "line" does not need to be allocated, but can't be another line in a
 * buffer, unlocking may make it invalid.
 *
 *   newfile: TRUE when starting to edit a new file, meaning that pe_old_lnum
 *		will be set for recovery
 * Check: The caller of this function should probably also call
 * appended_lines().
 *
 * return FAIL for failure, OK otherwise
 */
int ml_append(
    linenr_T lnum,                  // append after this line (can be 0)
    char_u *line,                   // text of the new line
    colnr_T len,                    // length of new line, including NUL, or 0
    bool newfile                    // flag, see above
)
{
  /* When starting up, we might still need to create the memfile */
  if (curbuf->b_ml.ml_mfp == NULL && open_buffer(FALSE, NULL, 0) == FAIL)
    return FAIL;

  if (curbuf->b_ml.ml_line_lnum != 0)
    ml_flush_line(curbuf);
  return ml_append_int(curbuf, lnum, line, len, newfile, FALSE);
}

/*
 * Like ml_append() but for an arbitrary buffer.  The buffer must already have
 * a memline.
 */
int ml_append_buf(
    buf_T *buf,
    linenr_T lnum,                  // append after this line (can be 0)
    char_u *line,                   // text of the new line
    colnr_T len,                    // length of new line, including NUL, or 0
    bool newfile                    // flag, see above
)
{
  if (buf->b_ml.ml_mfp == NULL)
    return FAIL;

  if (buf->b_ml.ml_line_lnum != 0)
    ml_flush_line(buf);
  return ml_append_int(buf, lnum, line, len, newfile, FALSE);
}

static int ml_append_int(
    buf_T *buf,
    linenr_T lnum,                  // append after this line (can be 0)
    char_u *line,                   // text of the new line
    colnr_T len,                    // length of line, including NUL, or 0
    bool newfile,                   // flag, see above
    int mark                        // mark the new line
)
{
  int i;
  int line_count;               /* number of indexes in current block */
  int offset;
  int from, to;
  int space_needed;             /* space needed for new line */
  int page_size;
  int page_count;
  int db_idx;                   /* index for lnum in data block */
  bhdr_T      *hp;
  memfile_T   *mfp;
  DATA_BL     *dp;
  PTR_BL      *pp;
  infoptr_T   *ip;

  /* lnum out of range */
  if (lnum > buf->b_ml.ml_line_count || buf->b_ml.ml_mfp == NULL)
    return FAIL;

  if (lowest_marked && lowest_marked > lnum)
    lowest_marked = lnum + 1;

  if (len == 0)
    len = (colnr_T)STRLEN(line) + 1;            /* space needed for the text */
  space_needed = len + INDEX_SIZE;      /* space needed for text + index */

  mfp = buf->b_ml.ml_mfp;
  page_size = mfp->mf_page_size;

  /*
   * find the data block containing the previous line
   * This also fills the stack with the blocks from the root to the data block
   * This also releases any locked block.
   */
  if ((hp = ml_find_line(buf, lnum == 0 ? (linenr_T)1 : lnum,
           ML_INSERT)) == NULL)
    return FAIL;

  buf->b_ml.ml_flags &= ~ML_EMPTY;

  if (lnum == 0)                /* got line one instead, correct db_idx */
    db_idx = -1;                /* careful, it is negative! */
  else
    db_idx = lnum - buf->b_ml.ml_locked_low;
  /* get line count before the insertion */
  line_count = buf->b_ml.ml_locked_high - buf->b_ml.ml_locked_low;

  dp = hp->bh_data;

  /*
   * If
   * - there is not enough room in the current block
   * - appending to the last line in the block
   * - not appending to the last line in the file
   * insert in front of the next block.
   */
  if ((int)dp->db_free < space_needed && db_idx == line_count - 1
      && lnum < buf->b_ml.ml_line_count) {
    /*
     * Now that the line is not going to be inserted in the block that we
     * expected, the line count has to be adjusted in the pointer blocks
     * by using ml_locked_lineadd.
     */
    --(buf->b_ml.ml_locked_lineadd);
    --(buf->b_ml.ml_locked_high);
    if ((hp = ml_find_line(buf, lnum + 1, ML_INSERT)) == NULL)
      return FAIL;

    db_idx = -1;                    /* careful, it is negative! */
    /* get line count before the insertion */
    line_count = buf->b_ml.ml_locked_high - buf->b_ml.ml_locked_low;
    CHECK(buf->b_ml.ml_locked_low != lnum + 1, "locked_low != lnum + 1");

    dp = hp->bh_data;
  }

  ++buf->b_ml.ml_line_count;

  if ((int)dp->db_free >= space_needed) {       /* enough room in data block */
    /*
     * Insert new line in existing data block, or in data block allocated above.
     */
    dp->db_txt_start -= len;
    dp->db_free -= space_needed;
    ++(dp->db_line_count);

    /*
     * move the text of the lines that follow to the front
     * adjust the indexes of the lines that follow
     */
    if (line_count > db_idx + 1) {          /* if there are following lines */
      /*
       * Offset is the start of the previous line.
       * This will become the character just after the new line.
       */
      if (db_idx < 0)
        offset = dp->db_txt_end;
      else
        offset = ((dp->db_index[db_idx]) & DB_INDEX_MASK);
      memmove((char *)dp + dp->db_txt_start,
          (char *)dp + dp->db_txt_start + len,
          (size_t)(offset - (dp->db_txt_start + len)));
      for (i = line_count - 1; i > db_idx; --i)
        dp->db_index[i + 1] = dp->db_index[i] - len;
      dp->db_index[db_idx + 1] = offset - len;
    } else                                  /* add line at the end */
      dp->db_index[db_idx + 1] = dp->db_txt_start;

    /*
     * copy the text into the block
     */
    memmove((char *)dp + dp->db_index[db_idx + 1], line, (size_t)len);
    if (mark)
      dp->db_index[db_idx + 1] |= DB_MARKED;

    /*
     * Mark the block dirty.
     */
    buf->b_ml.ml_flags |= ML_LOCKED_DIRTY;
    if (!newfile)
      buf->b_ml.ml_flags |= ML_LOCKED_POS;
  } else {        /* not enough space in data block */
    /*
     * If there is not enough room we have to create a new data block and copy some
     * lines into it.
     * Then we have to insert an entry in the pointer block.
     * If this pointer block also is full, we go up another block, and so on, up
     * to the root if necessary.
     * The line counts in the pointer blocks have already been adjusted by
     * ml_find_line().
     */
    long line_count_left, line_count_right;
    int page_count_left, page_count_right;
    bhdr_T      *hp_left;
    bhdr_T      *hp_right;
    bhdr_T      *hp_new;
    int lines_moved;
    int data_moved = 0;                     /* init to shut up gcc */
    int total_moved = 0;                    /* init to shut up gcc */
    DATA_BL     *dp_right, *dp_left;
    int stack_idx;
    int in_left;
    int lineadd;
    blocknr_T bnum_left, bnum_right;
    linenr_T lnum_left, lnum_right;
    int pb_idx;
    PTR_BL      *pp_new;

    /*
     * We are going to allocate a new data block. Depending on the
     * situation it will be put to the left or right of the existing
     * block.  If possible we put the new line in the left block and move
     * the lines after it to the right block. Otherwise the new line is
     * also put in the right block. This method is more efficient when
     * inserting a lot of lines at one place.
     */
    if (db_idx < 0) {           /* left block is new, right block is existing */
      lines_moved = 0;
      in_left = TRUE;
      /* space_needed does not change */
    } else {                  /* left block is existing, right block is new */
      lines_moved = line_count - db_idx - 1;
      if (lines_moved == 0)
        in_left = FALSE;                /* put new line in right block */
                                        /* space_needed does not change */
      else {
        data_moved = ((dp->db_index[db_idx]) & DB_INDEX_MASK) -
                     dp->db_txt_start;
        total_moved = data_moved + lines_moved * INDEX_SIZE;
        if ((int)dp->db_free + total_moved >= space_needed) {
          in_left = TRUE;               /* put new line in left block */
          space_needed = total_moved;
        } else {
          in_left = FALSE;                  /* put new line in right block */
          space_needed += total_moved;
        }
      }
    }

    page_count = ((space_needed + HEADER_SIZE) + page_size - 1) / page_size;
    hp_new = ml_new_data(mfp, newfile, page_count);
    if (db_idx < 0) {           /* left block is new */
      hp_left = hp_new;
      hp_right = hp;
      line_count_left = 0;
      line_count_right = line_count;
    } else {                  /* right block is new */
      hp_left = hp;
      hp_right = hp_new;
      line_count_left = line_count;
      line_count_right = 0;
    }
    dp_right = hp_right->bh_data;
    dp_left = hp_left->bh_data;
    bnum_left = hp_left->bh_bnum;
    bnum_right = hp_right->bh_bnum;
    page_count_left = hp_left->bh_page_count;
    page_count_right = hp_right->bh_page_count;

    /*
     * May move the new line into the right/new block.
     */
    if (!in_left) {
      dp_right->db_txt_start -= len;
      dp_right->db_free -= len + INDEX_SIZE;
      dp_right->db_index[0] = dp_right->db_txt_start;
      if (mark)
        dp_right->db_index[0] |= DB_MARKED;

      memmove((char *)dp_right + dp_right->db_txt_start,
          line, (size_t)len);
      ++line_count_right;
    }
    /*
     * may move lines from the left/old block to the right/new one.
     */
    if (lines_moved) {
      /*
       */
      dp_right->db_txt_start -= data_moved;
      dp_right->db_free -= total_moved;
      memmove((char *)dp_right + dp_right->db_txt_start,
          (char *)dp_left + dp_left->db_txt_start,
          (size_t)data_moved);
      offset = dp_right->db_txt_start - dp_left->db_txt_start;
      dp_left->db_txt_start += data_moved;
      dp_left->db_free += total_moved;

      /*
       * update indexes in the new block
       */
      for (to = line_count_right, from = db_idx + 1;
           from < line_count_left; ++from, ++to)
        dp_right->db_index[to] = dp->db_index[from] + offset;
      line_count_right += lines_moved;
      line_count_left -= lines_moved;
    }

    /*
     * May move the new line into the left (old or new) block.
     */
    if (in_left) {
      dp_left->db_txt_start -= len;
      dp_left->db_free -= len + INDEX_SIZE;
      dp_left->db_index[line_count_left] = dp_left->db_txt_start;
      if (mark)
        dp_left->db_index[line_count_left] |= DB_MARKED;
      memmove((char *)dp_left + dp_left->db_txt_start,
          line, (size_t)len);
      ++line_count_left;
    }

    if (db_idx < 0) {           /* left block is new */
      lnum_left = lnum + 1;
      lnum_right = 0;
    } else {                  /* right block is new */
      lnum_left = 0;
      if (in_left)
        lnum_right = lnum + 2;
      else
        lnum_right = lnum + 1;
    }
    dp_left->db_line_count = line_count_left;
    dp_right->db_line_count = line_count_right;

    /*
     * release the two data blocks
     * The new one (hp_new) already has a correct blocknumber.
     * The old one (hp, in ml_locked) gets a positive blocknumber if
     * we changed it and we are not editing a new file.
     */
    if (lines_moved || in_left)
      buf->b_ml.ml_flags |= ML_LOCKED_DIRTY;
    if (!newfile && db_idx >= 0 && in_left)
      buf->b_ml.ml_flags |= ML_LOCKED_POS;
    mf_put(mfp, hp_new, true, false);

    /*
     * flush the old data block
     * set ml_locked_lineadd to 0, because the updating of the
     * pointer blocks is done below
     */
    lineadd = buf->b_ml.ml_locked_lineadd;
    buf->b_ml.ml_locked_lineadd = 0;
    ml_find_line(buf, (linenr_T)0, ML_FLUSH);       /* flush data block */

    /*
     * update pointer blocks for the new data block
     */
    for (stack_idx = buf->b_ml.ml_stack_top - 1; stack_idx >= 0;
         --stack_idx) {
      ip = &(buf->b_ml.ml_stack[stack_idx]);
      pb_idx = ip->ip_index;
      if ((hp = mf_get(mfp, ip->ip_bnum, 1)) == NULL)
        return FAIL;
      pp = hp->bh_data;         /* must be pointer block */
      if (pp->pb_id != PTR_ID) {
        IEMSG(_("E317: pointer block id wrong 3"));
        mf_put(mfp, hp, false, false);
        return FAIL;
      }
      /*
       * TODO: If the pointer block is full and we are adding at the end
       * try to insert in front of the next block
       */
      /* block not full, add one entry */
      if (pp->pb_count < pp->pb_count_max) {
        if (pb_idx + 1 < (int)pp->pb_count)
          memmove(&pp->pb_pointer[pb_idx + 2],
              &pp->pb_pointer[pb_idx + 1],
              (size_t)(pp->pb_count - pb_idx - 1) * sizeof(PTR_EN));
        ++pp->pb_count;
        pp->pb_pointer[pb_idx].pe_line_count = line_count_left;
        pp->pb_pointer[pb_idx].pe_bnum = bnum_left;
        pp->pb_pointer[pb_idx].pe_page_count = page_count_left;
        pp->pb_pointer[pb_idx + 1].pe_line_count = line_count_right;
        pp->pb_pointer[pb_idx + 1].pe_bnum = bnum_right;
        pp->pb_pointer[pb_idx + 1].pe_page_count = page_count_right;

        if (lnum_left != 0)
          pp->pb_pointer[pb_idx].pe_old_lnum = lnum_left;
        if (lnum_right != 0)
          pp->pb_pointer[pb_idx + 1].pe_old_lnum = lnum_right;

        mf_put(mfp, hp, true, false);
        buf->b_ml.ml_stack_top = stack_idx + 1;             /* truncate stack */

        if (lineadd) {
          --(buf->b_ml.ml_stack_top);
          /* fix line count for rest of blocks in the stack */
          ml_lineadd(buf, lineadd);
          /* fix stack itself */
          buf->b_ml.ml_stack[buf->b_ml.ml_stack_top].ip_high +=
            lineadd;
          ++(buf->b_ml.ml_stack_top);
        }

        /*
         * We are finished, break the loop here.
         */
        break;
      } else {                        /* pointer block full */
        /*
         * split the pointer block
         * allocate a new pointer block
         * move some of the pointer into the new block
         * prepare for updating the parent block
         */
        for (;; ) {             /* do this twice when splitting block 1 */
          hp_new = ml_new_ptr(mfp);
          if (hp_new == NULL)               /* TODO: try to fix tree */
            return FAIL;
          pp_new = hp_new->bh_data;

          if (hp->bh_bnum != 1)
            break;

          /*
           * if block 1 becomes full the tree is given an extra level
           * The pointers from block 1 are moved into the new block.
           * block 1 is updated to point to the new block
           * then continue to split the new block
           */
          memmove(pp_new, pp, (size_t)page_size);
          pp->pb_count = 1;
          pp->pb_pointer[0].pe_bnum = hp_new->bh_bnum;
          pp->pb_pointer[0].pe_line_count = buf->b_ml.ml_line_count;
          pp->pb_pointer[0].pe_old_lnum = 1;
          pp->pb_pointer[0].pe_page_count = 1;
          mf_put(mfp, hp, true, false);             /* release block 1 */
          hp = hp_new;                          /* new block is to be split */
          pp = pp_new;
          CHECK(stack_idx != 0, _("stack_idx should be 0"));
          ip->ip_index = 0;
          ++stack_idx;                  /* do block 1 again later */
        }
        /*
         * move the pointers after the current one to the new block
         * If there are none, the new entry will be in the new block.
         */
        total_moved = pp->pb_count - pb_idx - 1;
        if (total_moved) {
          memmove(&pp_new->pb_pointer[0],
              &pp->pb_pointer[pb_idx + 1],
              (size_t)(total_moved) * sizeof(PTR_EN));
          pp_new->pb_count = total_moved;
          pp->pb_count -= total_moved - 1;
          pp->pb_pointer[pb_idx + 1].pe_bnum = bnum_right;
          pp->pb_pointer[pb_idx + 1].pe_line_count = line_count_right;
          pp->pb_pointer[pb_idx + 1].pe_page_count = page_count_right;
          if (lnum_right)
            pp->pb_pointer[pb_idx + 1].pe_old_lnum = lnum_right;
        } else {
          pp_new->pb_count = 1;
          pp_new->pb_pointer[0].pe_bnum = bnum_right;
          pp_new->pb_pointer[0].pe_line_count = line_count_right;
          pp_new->pb_pointer[0].pe_page_count = page_count_right;
          pp_new->pb_pointer[0].pe_old_lnum = lnum_right;
        }
        pp->pb_pointer[pb_idx].pe_bnum = bnum_left;
        pp->pb_pointer[pb_idx].pe_line_count = line_count_left;
        pp->pb_pointer[pb_idx].pe_page_count = page_count_left;
        if (lnum_left)
          pp->pb_pointer[pb_idx].pe_old_lnum = lnum_left;
        lnum_left = 0;
        lnum_right = 0;

        /*
         * recompute line counts
         */
        line_count_right = 0;
        for (i = 0; i < (int)pp_new->pb_count; ++i)
          line_count_right += pp_new->pb_pointer[i].pe_line_count;
        line_count_left = 0;
        for (i = 0; i < (int)pp->pb_count; ++i)
          line_count_left += pp->pb_pointer[i].pe_line_count;

        bnum_left = hp->bh_bnum;
        bnum_right = hp_new->bh_bnum;
        page_count_left = 1;
        page_count_right = 1;
        mf_put(mfp, hp, true, false);
        mf_put(mfp, hp_new, true, false);
      }
    }

    /*
     * Safety check: fallen out of for loop?
     */
    if (stack_idx < 0) {
      IEMSG(_("E318: Updated too many blocks?"));
      buf->b_ml.ml_stack_top = 0;       // invalidate stack
    }
  }

  /* The line was inserted below 'lnum' */
  ml_updatechunk(buf, lnum + 1, (long)len, ML_CHNK_ADDLINE);
  return OK;
}

/*
 * Replace line lnum, with buffering, in current buffer.
 *
 * If "copy" is TRUE, make a copy of the line, otherwise the line has been
 * copied to allocated memory already.
 *
 * Check: The caller of this function should probably also call
 * changed_lines(), unless update_screen(NOT_VALID) is used.
 *
 * return FAIL for failure, OK otherwise
 */
int ml_replace(linenr_T lnum, char_u *line, bool copy)
{
  if (line == NULL)             /* just checking... */
    return FAIL;

  /* When starting up, we might still need to create the memfile */
  if (curbuf->b_ml.ml_mfp == NULL && open_buffer(FALSE, NULL, 0) == FAIL)
    return FAIL;

  if (copy) {
    line = vim_strsave(line);
  }
  if (curbuf->b_ml.ml_line_lnum != lnum)            /* other line buffered */
    ml_flush_line(curbuf);                          /* flush it */
  else if (curbuf->b_ml.ml_flags & ML_LINE_DIRTY)   /* same line allocated */
    xfree(curbuf->b_ml.ml_line_ptr);             /* free it */
  curbuf->b_ml.ml_line_ptr = line;
  curbuf->b_ml.ml_line_lnum = lnum;
  curbuf->b_ml.ml_flags = (curbuf->b_ml.ml_flags | ML_LINE_DIRTY) & ~ML_EMPTY;

  return OK;
}

/// Delete line `lnum` in the current buffer.
///
/// @note The caller of this function should probably also call
/// deleted_lines() after this.
///
/// @param message  Show "--No lines in buffer--" message.
/// @return FAIL for failure, OK otherwise
int ml_delete(linenr_T lnum, bool message)
{
  ml_flush_line(curbuf);
  return ml_delete_int(curbuf, lnum, message);
}

static int ml_delete_int(buf_T *buf, linenr_T lnum, bool message)
{
  bhdr_T      *hp;
  memfile_T   *mfp;
  DATA_BL     *dp;
  PTR_BL      *pp;
  infoptr_T   *ip;
  int count;                /* number of entries in block */
  int idx;
  int stack_idx;
  int text_start;
  int line_start;
  long line_size;
  int i;

  if (lnum < 1 || lnum > buf->b_ml.ml_line_count)
    return FAIL;

  if (lowest_marked && lowest_marked > lnum)
    lowest_marked--;

  /*
   * If the file becomes empty the last line is replaced by an empty line.
   */
  if (buf->b_ml.ml_line_count == 1) {       /* file becomes empty */
    if (message
        )
      set_keep_msg((char_u *)_(no_lines_msg), 0);

    i = ml_replace((linenr_T)1, (char_u *)"", true);
    buf->b_ml.ml_flags |= ML_EMPTY;

    return i;
  }

  /*
   * find the data block containing the line
   * This also fills the stack with the blocks from the root to the data block
   * This also releases any locked block.
   */
  mfp = buf->b_ml.ml_mfp;
  if (mfp == NULL)
    return FAIL;

  if ((hp = ml_find_line(buf, lnum, ML_DELETE)) == NULL)
    return FAIL;

  dp = hp->bh_data;
  /* compute line count before the delete */
  count = (long)(buf->b_ml.ml_locked_high)
          - (long)(buf->b_ml.ml_locked_low) + 2;
  idx = lnum - buf->b_ml.ml_locked_low;

  --buf->b_ml.ml_line_count;

  line_start = ((dp->db_index[idx]) & DB_INDEX_MASK);
  if (idx == 0)                 /* first line in block, text at the end */
    line_size = dp->db_txt_end - line_start;
  else
    line_size = ((dp->db_index[idx - 1]) & DB_INDEX_MASK) - line_start;


  /*
   * special case: If there is only one line in the data block it becomes empty.
   * Then we have to remove the entry, pointing to this data block, from the
   * pointer block. If this pointer block also becomes empty, we go up another
   * block, and so on, up to the root if necessary.
   * The line counts in the pointer blocks have already been adjusted by
   * ml_find_line().
   */
  if (count == 1) {
    mf_free(mfp, hp);           /* free the data block */
    buf->b_ml.ml_locked = NULL;

    for (stack_idx = buf->b_ml.ml_stack_top - 1; stack_idx >= 0;
         --stack_idx) {
      buf->b_ml.ml_stack_top = 0;           /* stack is invalid when failing */
      ip = &(buf->b_ml.ml_stack[stack_idx]);
      idx = ip->ip_index;
      if ((hp = mf_get(mfp, ip->ip_bnum, 1)) == NULL)
        return FAIL;
      pp = hp->bh_data;         /* must be pointer block */
      if (pp->pb_id != PTR_ID) {
        IEMSG(_("E317: pointer block id wrong 4"));
        mf_put(mfp, hp, false, false);
        return FAIL;
      }
      count = --(pp->pb_count);
      if (count == 0)               /* the pointer block becomes empty! */
        mf_free(mfp, hp);
      else {
        if (count != idx)               /* move entries after the deleted one */
          memmove(&pp->pb_pointer[idx], &pp->pb_pointer[idx + 1],
              (size_t)(count - idx) * sizeof(PTR_EN));
        mf_put(mfp, hp, true, false);

        buf->b_ml.ml_stack_top = stack_idx;             /* truncate stack */
        /* fix line count for rest of blocks in the stack */
        if (buf->b_ml.ml_locked_lineadd != 0) {
          ml_lineadd(buf, buf->b_ml.ml_locked_lineadd);
          buf->b_ml.ml_stack[buf->b_ml.ml_stack_top].ip_high +=
            buf->b_ml.ml_locked_lineadd;
        }
        ++(buf->b_ml.ml_stack_top);

        break;
      }
    }
    CHECK(stack_idx < 0, _("deleted block 1?"));
  } else {
    /*
     * delete the text by moving the next lines forwards
     */
    text_start = dp->db_txt_start;
    memmove((char *)dp + text_start + line_size,
        (char *)dp + text_start, (size_t)(line_start - text_start));

    /*
     * delete the index by moving the next indexes backwards
     * Adjust the indexes for the text movement.
     */
    for (i = idx; i < count - 1; ++i)
      dp->db_index[i] = dp->db_index[i + 1] + line_size;

    dp->db_free += line_size + INDEX_SIZE;
    dp->db_txt_start += line_size;
    --(dp->db_line_count);

    /*
     * mark the block dirty and make sure it is in the file (for recovery)
     */
    buf->b_ml.ml_flags |= (ML_LOCKED_DIRTY | ML_LOCKED_POS);
  }

  ml_updatechunk(buf, lnum, line_size, ML_CHNK_DELLINE);
  return OK;
}

/*
 * set the B_MARKED flag for line 'lnum'
 */
void ml_setmarked(linenr_T lnum)
{
  bhdr_T    *hp;
  DATA_BL *dp;
  /* invalid line number */
  if (lnum < 1 || lnum > curbuf->b_ml.ml_line_count
      || curbuf->b_ml.ml_mfp == NULL)
    return;                         /* give error message? */

  if (lowest_marked == 0 || lowest_marked > lnum)
    lowest_marked = lnum;

  /*
   * find the data block containing the line
   * This also fills the stack with the blocks from the root to the data block
   * This also releases any locked block.
   */
  if ((hp = ml_find_line(curbuf, lnum, ML_FIND)) == NULL)
    return;                 /* give error message? */

  dp = hp->bh_data;
  dp->db_index[lnum - curbuf->b_ml.ml_locked_low] |= DB_MARKED;
  curbuf->b_ml.ml_flags |= ML_LOCKED_DIRTY;
}

/*
 * find the first line with its B_MARKED flag set
 */
linenr_T ml_firstmarked(void)
{
  bhdr_T      *hp;
  DATA_BL     *dp;
  linenr_T lnum;
  int i;

  if (curbuf->b_ml.ml_mfp == NULL)
    return (linenr_T) 0;

  /*
   * The search starts with lowest_marked line. This is the last line where
   * a mark was found, adjusted by inserting/deleting lines.
   */
  for (lnum = lowest_marked; lnum <= curbuf->b_ml.ml_line_count; ) {
    /*
     * Find the data block containing the line.
     * This also fills the stack with the blocks from the root to the data
     * block This also releases any locked block.
     */
    if ((hp = ml_find_line(curbuf, lnum, ML_FIND)) == NULL)
      return (linenr_T)0;                   /* give error message? */

    dp = hp->bh_data;

    for (i = lnum - curbuf->b_ml.ml_locked_low;
         lnum <= curbuf->b_ml.ml_locked_high; ++i, ++lnum)
      if ((dp->db_index[i]) & DB_MARKED) {
        (dp->db_index[i]) &= DB_INDEX_MASK;
        curbuf->b_ml.ml_flags |= ML_LOCKED_DIRTY;
        lowest_marked = lnum + 1;
        return lnum;
      }
  }

  return (linenr_T) 0;
}

/*
 * clear all DB_MARKED flags
 */
void ml_clearmarked(void)
{
  bhdr_T      *hp;
  DATA_BL     *dp;
  linenr_T lnum;
  int i;

  if (curbuf->b_ml.ml_mfp == NULL)          /* nothing to do */
    return;

  /*
   * The search starts with line lowest_marked.
   */
  for (lnum = lowest_marked; lnum <= curbuf->b_ml.ml_line_count; ) {
    /*
     * Find the data block containing the line.
     * This also fills the stack with the blocks from the root to the data
     * block and releases any locked block.
     */
    if ((hp = ml_find_line(curbuf, lnum, ML_FIND)) == NULL)
      return;                   /* give error message? */

    dp = hp->bh_data;

    for (i = lnum - curbuf->b_ml.ml_locked_low;
         lnum <= curbuf->b_ml.ml_locked_high; ++i, ++lnum)
      if ((dp->db_index[i]) & DB_MARKED) {
        (dp->db_index[i]) &= DB_INDEX_MASK;
        curbuf->b_ml.ml_flags |= ML_LOCKED_DIRTY;
      }
  }

  lowest_marked = 0;
  return;
}

/*
 * flush ml_line if necessary
 */
static void ml_flush_line(buf_T *buf)
{
  bhdr_T      *hp;
  DATA_BL     *dp;
  linenr_T lnum;
  char_u      *new_line;
  char_u      *old_line;
  colnr_T new_len;
  int old_len;
  int extra;
  int idx;
  int start;
  int count;
  int i;
  static int entered = FALSE;

  if (buf->b_ml.ml_line_lnum == 0 || buf->b_ml.ml_mfp == NULL)
    return;             /* nothing to do */

  if (buf->b_ml.ml_flags & ML_LINE_DIRTY) {
    /* This code doesn't work recursively. */
    if (entered)
      return;
    entered = TRUE;

    lnum = buf->b_ml.ml_line_lnum;
    new_line = buf->b_ml.ml_line_ptr;

    hp = ml_find_line(buf, lnum, ML_FIND);
    if (hp == NULL) {
      IEMSGN(_("E320: Cannot find line %" PRId64), lnum);
    } else {
      dp = hp->bh_data;
      idx = lnum - buf->b_ml.ml_locked_low;
      start = ((dp->db_index[idx]) & DB_INDEX_MASK);
      old_line = (char_u *)dp + start;
      if (idx == 0)             /* line is last in block */
        old_len = dp->db_txt_end - start;
      else                      /* text of previous line follows */
        old_len = (dp->db_index[idx - 1] & DB_INDEX_MASK) - start;
      new_len = (colnr_T)STRLEN(new_line) + 1;
      extra = new_len - old_len;            /* negative if lines gets smaller */

      /*
       * if new line fits in data block, replace directly
       */
      if ((int)dp->db_free >= extra) {
        /* if the length changes and there are following lines */
        count = buf->b_ml.ml_locked_high - buf->b_ml.ml_locked_low + 1;
        if (extra != 0 && idx < count - 1) {
          /* move text of following lines */
          memmove((char *)dp + dp->db_txt_start - extra,
              (char *)dp + dp->db_txt_start,
              (size_t)(start - dp->db_txt_start));

          /* adjust pointers of this and following lines */
          for (i = idx + 1; i < count; ++i)
            dp->db_index[i] -= extra;
        }
        dp->db_index[idx] -= extra;

        /* adjust free space */
        dp->db_free -= extra;
        dp->db_txt_start -= extra;

        /* copy new line into the data block */
        memmove(old_line - extra, new_line, (size_t)new_len);
        buf->b_ml.ml_flags |= (ML_LOCKED_DIRTY | ML_LOCKED_POS);
        /* The else case is already covered by the insert and delete */
        ml_updatechunk(buf, lnum, (long)extra, ML_CHNK_UPDLINE);
      } else {
        // Cannot do it in one data block: Delete and append.
        // Append first, because ml_delete_int() cannot delete the
        // last line in a buffer, which causes trouble for a buffer
        // that has only one line.
        // Don't forget to copy the mark!
        // How about handling errors???
        (void)ml_append_int(buf, lnum, new_line, new_len, false,
                            (dp->db_index[idx] & DB_MARKED));
        (void)ml_delete_int(buf, lnum, false);
      }
    }
    xfree(new_line);

    entered = FALSE;
  }

  buf->b_ml.ml_line_lnum = 0;
}

/*
 * create a new, empty, data block
 */
static bhdr_T *ml_new_data(memfile_T *mfp, bool negative, int page_count)
{
  assert(page_count >= 0);
  bhdr_T *hp = mf_new(mfp, negative, (unsigned)page_count);
  DATA_BL *dp = hp->bh_data;
  dp->db_id = DATA_ID;
  dp->db_txt_start = dp->db_txt_end = page_count * mfp->mf_page_size;
  dp->db_free = dp->db_txt_start - HEADER_SIZE;
  dp->db_line_count = 0;

  return hp;
}

/*
 * create a new, empty, pointer block
 */
static bhdr_T *ml_new_ptr(memfile_T *mfp)
{
  bhdr_T *hp = mf_new(mfp, false, 1);
  PTR_BL *pp = hp->bh_data;
  pp->pb_id = PTR_ID;
  pp->pb_count = 0;
  pp->pb_count_max = (mfp->mf_page_size - sizeof(PTR_BL)) / sizeof(PTR_EN) + 1;

  return hp;
}

/*
 * lookup line 'lnum' in a memline
 *
 *   action: if ML_DELETE or ML_INSERT the line count is updated while searching
 *	     if ML_FLUSH only flush a locked block
 *	     if ML_FIND just find the line
 *
 * If the block was found it is locked and put in ml_locked.
 * The stack is updated to lead to the locked block. The ip_high field in
 * the stack is updated to reflect the last line in the block AFTER the
 * insert or delete, also if the pointer block has not been updated yet. But
 * if ml_locked != NULL ml_locked_lineadd must be added to ip_high.
 *
 * return: NULL for failure, pointer to block header otherwise
 */
static bhdr_T *ml_find_line(buf_T *buf, linenr_T lnum, int action)
{
  DATA_BL     *dp;
  PTR_BL      *pp;
  infoptr_T   *ip;
  bhdr_T      *hp;
  memfile_T   *mfp;
  linenr_T t;
  blocknr_T bnum, bnum2;
  int dirty;
  linenr_T low, high;
  int top;
  int page_count;
  int idx;

  mfp = buf->b_ml.ml_mfp;

  /*
   * If there is a locked block check if the wanted line is in it.
   * If not, flush and release the locked block.
   * Don't do this for ML_INSERT_SAME, because the stack need to be updated.
   * Don't do this for ML_FLUSH, because we want to flush the locked block.
   * Don't do this when 'swapfile' is reset, we want to load all the blocks.
   */
  if (buf->b_ml.ml_locked) {
    if (ML_SIMPLE(action)
        && buf->b_ml.ml_locked_low <= lnum
        && buf->b_ml.ml_locked_high >= lnum) {
      // remember to update pointer blocks and stack later
      if (action == ML_INSERT) {
        ++(buf->b_ml.ml_locked_lineadd);
        ++(buf->b_ml.ml_locked_high);
      } else if (action == ML_DELETE) {
        --(buf->b_ml.ml_locked_lineadd);
        --(buf->b_ml.ml_locked_high);
      }
      return buf->b_ml.ml_locked;
    }

    mf_put(mfp, buf->b_ml.ml_locked, buf->b_ml.ml_flags & ML_LOCKED_DIRTY,
        buf->b_ml.ml_flags & ML_LOCKED_POS);
    buf->b_ml.ml_locked = NULL;

    /*
     * If lines have been added or deleted in the locked block, need to
     * update the line count in pointer blocks.
     */
    if (buf->b_ml.ml_locked_lineadd != 0)
      ml_lineadd(buf, buf->b_ml.ml_locked_lineadd);
  }

  if (action == ML_FLUSH)           /* nothing else to do */
    return NULL;

  bnum = 1;                         /* start at the root of the tree */
  page_count = 1;
  low = 1;
  high = buf->b_ml.ml_line_count;

  if (action == ML_FIND) {      /* first try stack entries */
    for (top = buf->b_ml.ml_stack_top - 1; top >= 0; --top) {
      ip = &(buf->b_ml.ml_stack[top]);
      if (ip->ip_low <= lnum && ip->ip_high >= lnum) {
        bnum = ip->ip_bnum;
        low = ip->ip_low;
        high = ip->ip_high;
        buf->b_ml.ml_stack_top = top;           /* truncate stack at prev entry */
        break;
      }
    }
    if (top < 0)
      buf->b_ml.ml_stack_top = 0;               /* not found, start at the root */
  } else        /* ML_DELETE or ML_INSERT */
    buf->b_ml.ml_stack_top = 0;         /* start at the root */

  /*
   * search downwards in the tree until a data block is found
   */
  for (;; ) {
    if ((hp = mf_get(mfp, bnum, page_count)) == NULL)
      goto error_noblock;

    /*
     * update high for insert/delete
     */
    if (action == ML_INSERT)
      ++high;
    else if (action == ML_DELETE)
      --high;

    dp = hp->bh_data;
    if (dp->db_id == DATA_ID) {         /* data block */
      buf->b_ml.ml_locked = hp;
      buf->b_ml.ml_locked_low = low;
      buf->b_ml.ml_locked_high = high;
      buf->b_ml.ml_locked_lineadd = 0;
      buf->b_ml.ml_flags &= ~(ML_LOCKED_DIRTY | ML_LOCKED_POS);
      return hp;
    }

    pp = (PTR_BL *)(dp);                /* must be pointer block */
    if (pp->pb_id != PTR_ID) {
      IEMSG(_("E317: pointer block id wrong"));
      goto error_block;
    }

    top = ml_add_stack(buf);  // add new entry to stack
    ip = &(buf->b_ml.ml_stack[top]);
    ip->ip_bnum = bnum;
    ip->ip_low = low;
    ip->ip_high = high;
    ip->ip_index = -1;                  /* index not known yet */

    dirty = FALSE;
    for (idx = 0; idx < (int)pp->pb_count; ++idx) {
      t = pp->pb_pointer[idx].pe_line_count;
      CHECK(t == 0, _("pe_line_count is zero"));
      if ((low += t) > lnum) {
        ip->ip_index = idx;
        bnum = pp->pb_pointer[idx].pe_bnum;
        page_count = pp->pb_pointer[idx].pe_page_count;
        high = low - 1;
        low -= t;

        /*
         * a negative block number may have been changed
         */
        if (bnum < 0) {
          bnum2 = mf_trans_del(mfp, bnum);
          if (bnum != bnum2) {
            bnum = bnum2;
            pp->pb_pointer[idx].pe_bnum = bnum;
            dirty = TRUE;
          }
        }

        break;
      }
    }
    if (idx >= (int)pp->pb_count) {         // past the end: something wrong!
      if (lnum > buf->b_ml.ml_line_count) {
        IEMSGN(_("E322: line number out of range: %" PRId64 " past the end"),
               lnum - buf->b_ml.ml_line_count);

      } else {
        IEMSGN(_("E323: line count wrong in block %" PRId64), bnum);
      }
      goto error_block;
    }
    if (action == ML_DELETE) {
      pp->pb_pointer[idx].pe_line_count--;
      dirty = TRUE;
    } else if (action == ML_INSERT) {
      pp->pb_pointer[idx].pe_line_count++;
      dirty = TRUE;
    }
    mf_put(mfp, hp, dirty, false);
  }

error_block:
  mf_put(mfp, hp, false, false);
error_noblock:
  /*
   * If action is ML_DELETE or ML_INSERT we have to correct the tree for
   * the incremented/decremented line counts, because there won't be a line
   * inserted/deleted after all.
   */
  if (action == ML_DELETE)
    ml_lineadd(buf, 1);
  else if (action == ML_INSERT)
    ml_lineadd(buf, -1);
  buf->b_ml.ml_stack_top = 0;
  return NULL;
}

/*
 * add an entry to the info pointer stack
 *
 * return number of the new entry
 */
static int ml_add_stack(buf_T *buf)
{
  int top = buf->b_ml.ml_stack_top;

  /* may have to increase the stack size */
  if (top == buf->b_ml.ml_stack_size) {
    CHECK(top > 0, _("Stack size increases"));     /* more than 5 levels??? */

    buf->b_ml.ml_stack_size += STACK_INCR;
    size_t new_size = sizeof(infoptr_T) * buf->b_ml.ml_stack_size;
    buf->b_ml.ml_stack = xrealloc(buf->b_ml.ml_stack, new_size);
  }

  buf->b_ml.ml_stack_top++;
  return top;
}

/*
 * Update the pointer blocks on the stack for inserted/deleted lines.
 * The stack itself is also updated.
 *
 * When an insert/delete line action fails, the line is not inserted/deleted,
 * but the pointer blocks have already been updated. That is fixed here by
 * walking through the stack.
 *
 * Count is the number of lines added, negative if lines have been deleted.
 */
static void ml_lineadd(buf_T *buf, int count)
{
  int idx;
  infoptr_T   *ip;
  PTR_BL      *pp;
  memfile_T   *mfp = buf->b_ml.ml_mfp;
  bhdr_T      *hp;

  for (idx = buf->b_ml.ml_stack_top - 1; idx >= 0; --idx) {
    ip = &(buf->b_ml.ml_stack[idx]);
    if ((hp = mf_get(mfp, ip->ip_bnum, 1)) == NULL)
      break;
    pp = hp->bh_data;       /* must be pointer block */
    if (pp->pb_id != PTR_ID) {
      mf_put(mfp, hp, false, false);
      IEMSG(_("E317: pointer block id wrong 2"));
      break;
    }
    pp->pb_pointer[ip->ip_index].pe_line_count += count;
    ip->ip_high += count;
    mf_put(mfp, hp, true, false);
  }
}

#if defined(HAVE_READLINK)
/*
 * Resolve a symlink in the last component of a file name.
 * Note that f_resolve() does it for every part of the path, we don't do that
 * here.
 * If it worked returns OK and the resolved link in "buf[MAXPATHL]".
 * Otherwise returns FAIL.
 */
int resolve_symlink(const char_u *fname, char_u *buf)
{
  char_u tmp[MAXPATHL];
  int ret;
  int depth = 0;

  if (fname == NULL)
    return FAIL;

  /* Put the result so far in tmp[], starting with the original name. */
  STRLCPY(tmp, fname, MAXPATHL);

  for (;; ) {
    /* Limit symlink depth to 100, catch recursive loops. */
    if (++depth == 100) {
      EMSG2(_("E773: Symlink loop for \"%s\""), fname);
      return FAIL;
    }

    ret = readlink((char *)tmp, (char *)buf, MAXPATHL - 1);
    if (ret <= 0) {
      if (errno == EINVAL || errno == ENOENT) {
        /* Found non-symlink or not existing file, stop here.
         * When at the first level use the unmodified name, skip the
         * call to vim_FullName(). */
        if (depth == 1)
          return FAIL;

        /* Use the resolved name in tmp[]. */
        break;
      }

      /* There must be some error reading links, use original name. */
      return FAIL;
    }
    buf[ret] = NUL;

    // Check whether the symlink is relative or absolute.
    // If it's relative, build a new path based on the directory
    // portion of the filename (if any) and the path the symlink
    // points to.
    if (path_is_absolute(buf)) {
      STRCPY(tmp, buf);
    } else {
      char_u *tail = path_tail(tmp);
      if (STRLEN(tail) + STRLEN(buf) >= MAXPATHL) {
        return FAIL;
      }
      STRCPY(tail, buf);
    }
  }

  /*
   * Try to resolve the full name of the file so that the swapfile name will
   * be consistent even when opening a relative symlink from different
   * working directories.
   */
  return vim_FullName((char *)tmp, (char *)buf, MAXPATHL, TRUE);
}
#endif

/*
 * Make swap file name out of the file name and a directory name.
 * Returns pointer to allocated memory or NULL.
 */
char_u *makeswapname(char_u *fname, char_u *ffname, buf_T *buf, char_u *dir_name)
{
  char_u      *r, *s;
  char_u      *fname_res = fname;
#ifdef HAVE_READLINK
  char_u fname_buf[MAXPATHL];
#endif
  int len = (int)STRLEN(dir_name);

  s = dir_name + len;
  if (after_pathsep((char *)dir_name, (char *)s)
      && len > 1
      && s[-1] == s[-2]) {  // Ends with '//', Use Full path
    r = NULL;
    if ((s = (char_u *)make_percent_swname((char *)dir_name, (char *)fname)) != NULL) {
      r = (char_u *)modname((char *)s, ".swp", FALSE);
      xfree(s);
    }
    return r;
  }

#ifdef HAVE_READLINK
  /* Expand symlink in the file name, so that we put the swap file with the
   * actual file instead of with the symlink. */
  if (resolve_symlink(fname, fname_buf) == OK)
    fname_res = fname_buf;
#endif

  // Prepend a '.' to the swap file name for the current directory.
  r = (char_u *)modname((char *)fname_res, ".swp",
              dir_name[0] == '.' && dir_name[1] == NUL);
  if (r == NULL)            /* out of memory */
    return NULL;

  s = get_file_in_dir(r, dir_name);
  xfree(r);
  return s;
}

/*
 * Get file name to use for swap file or backup file.
 * Use the name of the edited file "fname" and an entry in the 'dir' or 'bdir'
 * option "dname".
 * - If "dname" is ".", return "fname" (swap file in dir of file).
 * - If "dname" starts with "./", insert "dname" in "fname" (swap file
 *   relative to dir of file).
 * - Otherwise, prepend "dname" to the tail of "fname" (swap file in specific
 *   dir).
 *
 * The return value is an allocated string and can be NULL.
 */
char_u *
get_file_in_dir (
    char_u *fname,
    char_u *dname         /* don't use "dirname", it is a global for Alpha */
)
{
  char_u      *t;
  char_u      *tail;
  char_u      *retval;
  int save_char;

  tail = path_tail(fname);

  if (dname[0] == '.' && dname[1] == NUL)
    retval = vim_strsave(fname);
  else if (dname[0] == '.' && vim_ispathsep(dname[1])) {
    if (tail == fname)              /* no path before file name */
      retval = (char_u *)concat_fnames((char *)dname + 2, (char *)tail, TRUE);
    else {
      save_char = *tail;
      *tail = NUL;
      t = (char_u *)concat_fnames((char *)fname, (char *)dname + 2, TRUE);
      *tail = save_char;
      retval = (char_u *)concat_fnames((char *)t, (char *)tail, TRUE);
      xfree(t);
    }
  } else {
    retval = (char_u *)concat_fnames((char *)dname, (char *)tail, TRUE);
  }

  return retval;
}


/*
 * Print the ATTENTION message: info about an existing swap file.
 */
static void 
attention_message (
    buf_T *buf,           /* buffer being edited */
    char_u *fname         /* swap file name */
)
{
  assert(buf->b_fname != NULL);
  time_t x, sx;
  char        *p;

  ++no_wait_return;
  (void)EMSG(_("E325: ATTENTION"));
  MSG_PUTS(_("\nFound a swap file by the name \""));
  msg_home_replace(fname);
  MSG_PUTS("\"\n");
  sx = swapfile_info(fname);
  MSG_PUTS(_("While opening file \""));
  msg_outtrans(buf->b_fname);
  MSG_PUTS("\"\n");
  FileInfo file_info;
  if (!os_fileinfo((char *)buf->b_fname, &file_info)) {
    MSG_PUTS(_("      CANNOT BE FOUND"));
  } else {
    MSG_PUTS(_("             dated: "));
    x = file_info.stat.st_mtim.tv_sec;
    p = ctime(&x);  // includes '\n'
    if (p == NULL)
      MSG_PUTS("(invalid)\n");
    else
      MSG_PUTS(p);
    if (sx != 0 && x > sx)
      MSG_PUTS(_("      NEWER than swap file!\n"));
  }
  /* Some of these messages are long to allow translation to
   * other languages. */
  MSG_PUTS(_("\n(1) Another program may be editing the same file.  If this is"
             " the case,\n    be careful not to end up with two different"
             " instances of the same\n    file when making changes."
             "  Quit, or continue with caution.\n"));
  MSG_PUTS(_("(2) An edit session for this file crashed.\n"));
  MSG_PUTS(_("    If this is the case, use \":recover\" or \"vim -r "));
  msg_outtrans(buf->b_fname);
  MSG_PUTS(_("\"\n    to recover the changes (see \":help recovery\").\n"));
  MSG_PUTS(_("    If you did this already, delete the swap file \""));
  msg_outtrans(fname);
  MSG_PUTS(_("\"\n    to avoid this message.\n"));
  cmdline_row = msg_row;
  --no_wait_return;
}


/*
 * Trigger the SwapExists autocommands.
 * Returns a value for equivalent to do_dialog() (see below):
 * 0: still need to ask for a choice
 * 1: open read-only
 * 2: edit anyway
 * 3: recover
 * 4: delete it
 * 5: quit
 * 6: abort
 */
static int do_swapexists(buf_T *buf, char_u *fname)
{
  set_vim_var_string(VV_SWAPNAME, (char *) fname, -1);
  set_vim_var_string(VV_SWAPCHOICE, NULL, -1);

  /* Trigger SwapExists autocommands with <afile> set to the file being
   * edited.  Disallow changing directory here. */
  ++allbuf_lock;
  apply_autocmds(EVENT_SWAPEXISTS, buf->b_fname, NULL, FALSE, NULL);
  --allbuf_lock;

  set_vim_var_string(VV_SWAPNAME, NULL, -1);

  switch (*get_vim_var_str(VV_SWAPCHOICE)) {
  case 'o': return 1;
  case 'e': return 2;
  case 'r': return 3;
  case 'd': return 4;
  case 'q': return 5;
  case 'a': return 6;
  }

  return 0;
}

/// Find out what name to use for the swap file for buffer 'buf'.
///
/// Several names are tried to find one that does not exist. Last directory in
/// option is automatically created.
///
/// @note If BASENAMELEN is not correct, you will get error messages for
///   not being able to open the swap or undo file.
/// @note May trigger SwapExists autocmd, pointers may change!
///
/// @param[in]  buf  Buffer for which swap file names needs to be found.
/// @param[in,out]  dirp  Pointer to a list of directories. When out of memory,
///                       is set to NULL. Is advanced to the next directory in
///                       the list otherwise.
/// @param[in]  old_fname  Allowed existing swap file name. Except for this
///                        case, name of the non-existing file is used.
/// @param[in,out]  found_existing_dir  If points to true, then new directory
///                                     for swap file is not created. At first
///                                     findswapname() call this argument must
///                                     point to false. This parameter may only
///                                     be set to true by this function, it is
///                                     never set to false.
///
/// @return [allocated] Name of the swap file.
static char *findswapname(buf_T *buf, char **dirp, char *old_fname,
                          bool *found_existing_dir)
  FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_NONNULL_ARG(1, 2, 4)
{
  char *fname;
  size_t n;
  char *dir_name;
  char *buf_fname = (char *) buf->b_fname;

  /*
   * Isolate a directory name from *dirp and put it in dir_name.
   * First allocate some memory to put the directory name in.
   */
  const size_t dir_len = strlen(*dirp) + 1;
  dir_name = xmalloc(dir_len);
  (void)copy_option_part((char_u **) dirp, (char_u *) dir_name, dir_len, ",");

  /*
   * we try different names until we find one that does not exist yet
   */
  fname = (char *)makeswapname((char_u *)buf_fname, buf->b_ffname, buf,
                               (char_u *)dir_name);

  for (;; ) {
    if (fname == NULL) {        // must be out of memory
      break;
    }
    if ((n = strlen(fname)) == 0) {        // safety check
      XFREE_CLEAR(fname);
      break;
    }
    // check if the swapfile already exists
    // Extra security check: When a swap file is a symbolic link, this
    // is most likely a symlink attack.
    FileInfo file_info;
    bool file_or_link_found = os_fileinfo_link(fname, &file_info);
    if (!file_or_link_found) {
      break;
    }

    // A file name equal to old_fname is OK to use.
    if (old_fname != NULL && fnamecmp(fname, old_fname) == 0) {
      break;
    }

    // get here when file already exists
    if (fname[n - 2] == 'w' && fname[n - 1] == 'p') {   // first try
      // If we get here the ".swp" file really exists.
      // Give an error message, unless recovering, no file name, we are
      // viewing a help file or when the path of the file is different
      // (happens when all .swp files are in one directory).
      if (!recoverymode && buf_fname != NULL
          && !buf->b_help && !(buf->b_flags & BF_DUMMY)) {
        int fd;
        struct block0 b0;
        int differ = FALSE;

        // Try to read block 0 from the swap file to get the original
        // file name (and inode number).
        fd = os_open(fname, O_RDONLY, 0);
        if (fd >= 0) {
          if (read_eintr(fd, &b0, sizeof(b0)) == sizeof(b0)) {
            // If the swapfile has the same directory as the
            // buffer don't compare the directory names, they can
            // have a different mountpoint.
            if (b0.b0_flags & B0_SAME_DIR) {
              if (fnamecmp(path_tail(buf->b_ffname),
                           path_tail(b0.b0_fname)) != 0
                  || !same_directory((char_u *)fname, buf->b_ffname)) {
                // Symlinks may point to the same file even
                // when the name differs, need to check the
                // inode too.
                expand_env(b0.b0_fname, NameBuff, MAXPATHL);
                if (fnamecmp_ino(buf->b_ffname, NameBuff,
                    char_to_long(b0.b0_ino))) {
                  differ = TRUE;
                }
              }
            } else {
              // The name in the swap file may be
              // "~user/path/file".  Expand it first.
              expand_env(b0.b0_fname, NameBuff, MAXPATHL);
              if (fnamecmp_ino(buf->b_ffname, NameBuff,
                  char_to_long(b0.b0_ino))) {
                differ = TRUE;
              }
            }
          }
          close(fd);
        }

        // give the ATTENTION message when there is an old swap file
        // for the current file, and the buffer was not recovered. */
        if (differ == false && !(curbuf->b_flags & BF_RECOVERED)
            && vim_strchr(p_shm, SHM_ATTENTION) == NULL) {
          int choice = 0;

          process_still_running = false;
          // It's safe to delete the swap file if all these are true:
          // - the edited file exists
          // - the swap file has no changes and looks OK
          if (os_path_exists(buf->b_fname) && swapfile_unchanged(fname)) {
            choice = 4;
            if (p_verbose > 0) {
              verb_msg(_("Found a swap file that is not useful, deleting it"));
            }
          }

          // If there is a SwapExists autocommand and we can handle the
          // response, trigger it.  It may return 0 to ask the user anyway.
          if (choice == 0
              && swap_exists_action != SEA_NONE
              && has_autocmd(EVENT_SWAPEXISTS, (char_u *)buf_fname, buf)) {
            choice = do_swapexists(buf, (char_u *)fname);
          }

          if (choice == 0) {
            // Show info about the existing swap file.
            attention_message(buf, (char_u *)fname);

            // We don't want a 'q' typed at the more-prompt
            // interrupt loading a file.
            got_int = false;

            // If vimrc has "simalt ~x" we don't want it to
            // interfere with the prompt here.
            flush_buffers(FLUSH_TYPEAHEAD);
          }

          if (swap_exists_action != SEA_NONE && choice == 0) {
            const char *const sw_msg_1 = _("Swap file \"");
            const char *const sw_msg_2 = _("\" already exists!");

            const size_t fname_len = strlen(fname);
            const size_t sw_msg_1_len = strlen(sw_msg_1);
            const size_t sw_msg_2_len = strlen(sw_msg_2);

            const size_t name_len = sw_msg_1_len + fname_len + sw_msg_2_len + 5;

            char *const name = xmalloc(name_len);
            memcpy(name, sw_msg_1, sw_msg_1_len + 1);
            home_replace(NULL, (char_u *)fname, (char_u *)&name[sw_msg_1_len],
                         fname_len, true);
            xstrlcat(name, sw_msg_2, name_len);
            choice = do_dialog(VIM_WARNING, (char_u *)_("VIM - ATTENTION"),
                               (char_u *)name,
                               process_still_running
                               ? (char_u *)_(
                                   "&Open Read-Only\n&Edit anyway\n&Recover"
                                   "\n&Quit\n&Abort") :
                               (char_u *)_(
                                   "&Open Read-Only\n&Edit anyway\n&Recover"
                                   "\n&Delete it\n&Quit\n&Abort"),
                               1, NULL, false);

            if (process_still_running && choice >= 4) {
              choice++;                 // Skip missing "Delete it" button.
            }
            xfree(name);

            // pretend screen didn't scroll, need redraw anyway
            // TODO(bfredl): when doing the message grid refactor,
            // simplify this special case.
            msg_scrolled = 0;
            redraw_all_later(NOT_VALID);
          }

          if (choice > 0) {
            switch (choice) {
            case 1:
              buf->b_p_ro = TRUE;
              break;
            case 2:
              break;
            case 3:
              swap_exists_action = SEA_RECOVER;
              break;
            case 4:
              os_remove(fname);
              break;
            case 5:
              swap_exists_action = SEA_QUIT;
              break;
            case 6:
              swap_exists_action = SEA_QUIT;
              got_int = TRUE;
              break;
            }

            // If the file was deleted this fname can be used.
            if (!os_path_exists((char_u *)fname)) {
              break;
            }
          } else {
            MSG_PUTS("\n");
            if (msg_silent == 0)
              /* call wait_return() later */
              need_wait_return = TRUE;
          }

        }
      }
    }

    /*
     * Change the ".swp" extension to find another file that can be used.
     * First decrement the last char: ".swo", ".swn", etc.
     * If that still isn't enough decrement the last but one char: ".svz"
     * Can happen when editing many "No Name" buffers.
     */
    if (fname[n - 1] == 'a') {          /* ".s?a" */
      if (fname[n - 2] == 'a') {        /* ".saa": tried enough, give up */
        EMSG(_("E326: Too many swap files found"));
        XFREE_CLEAR(fname);
        break;
      }
      --fname[n - 2];                   /* ".svz", ".suz", etc. */
      fname[n - 1] = 'z' + 1;
    }
    --fname[n - 1];                     /* ".swo", ".swn", etc. */
  }

  if (os_isdir((char_u *) dir_name)) {
    *found_existing_dir = true;
  } else if (!*found_existing_dir && **dirp == NUL) {
    int ret;
    char *failed_dir;
    if ((ret = os_mkdir_recurse(dir_name, 0755, &failed_dir)) != 0) {
      EMSG3(_("E303: Unable to create directory \"%s\" for swap file, "
              "recovery impossible: %s"),
            failed_dir, os_strerror(ret));
      xfree(failed_dir);
    }
  }

  xfree(dir_name);
  return fname;
}

static int b0_magic_wrong(ZERO_BL *b0p)
{
  return b0p->b0_magic_long != (long)B0_MAGIC_LONG
         || b0p->b0_magic_int != (int)B0_MAGIC_INT
         || b0p->b0_magic_short != (short)B0_MAGIC_SHORT
         || b0p->b0_magic_char != B0_MAGIC_CHAR;
}

/*
 * Compare current file name with file name from swap file.
 * Try to use inode numbers when possible.
 * Return non-zero when files are different.
 *
 * When comparing file names a few things have to be taken into consideration:
 * - When working over a network the full path of a file depends on the host.
 *   We check the inode number if possible.  It is not 100% reliable though,
 *   because the device number cannot be used over a network.
 * - When a file does not exist yet (editing a new file) there is no inode
 *   number.
 * - The file name in a swap file may not be valid on the current host.  The
 *   "~user" form is used whenever possible to avoid this.
 *
 * This is getting complicated, let's make a table:
 *
 *		ino_c  ino_s  fname_c  fname_s	differ =
 *
 * both files exist -> compare inode numbers:
 *		!= 0   != 0	X	 X	ino_c != ino_s
 *
 * inode number(s) unknown, file names available -> compare file names
 *		== 0	X	OK	 OK	fname_c != fname_s
 *		 X     == 0	OK	 OK	fname_c != fname_s
 *
 * current file doesn't exist, file for swap file exist, file name(s) not
 * available -> probably different
 *		== 0   != 0    FAIL	 X	TRUE
 *		== 0   != 0	X	FAIL	TRUE
 *
 * current file exists, inode for swap unknown, file name(s) not
 * available -> probably different
 *		!= 0   == 0    FAIL	 X	TRUE
 *		!= 0   == 0	X	FAIL	TRUE
 *
 * current file doesn't exist, inode for swap unknown, one file name not
 * available -> probably different
 *		== 0   == 0    FAIL	 OK	TRUE
 *		== 0   == 0	OK	FAIL	TRUE
 *
 * current file doesn't exist, inode for swap unknown, both file names not
 * available -> compare file names
 *		== 0   == 0    FAIL	FAIL	fname_c != fname_s
 *
 * Only the last 32 bits of the inode will be used. This can't be changed
 * without making the block 0 incompatible with 32 bit versions.
 */

static bool fnamecmp_ino(
    char_u *fname_c,              // current file name
    char_u *fname_s,              // file name from swap file
    long ino_block0
)
{
  uint64_t ino_c = 0;               /* ino of current file */
  uint64_t ino_s;                   /* ino of file from swap file */
  char_u buf_c[MAXPATHL];           /* full path of fname_c */
  char_u buf_s[MAXPATHL];           /* full path of fname_s */
  int retval_c;                     /* flag: buf_c valid */
  int retval_s;                     /* flag: buf_s valid */

  FileInfo file_info;
  if (os_fileinfo((char *)fname_c, &file_info)) {
    ino_c = os_fileinfo_inode(&file_info);
  }

  /*
   * First we try to get the inode from the file name, because the inode in
   * the swap file may be outdated.  If that fails (e.g. this path is not
   * valid on this machine), use the inode from block 0.
   */
  if (os_fileinfo((char *)fname_s, &file_info)) {
    ino_s = os_fileinfo_inode(&file_info);
  } else {
    ino_s = (uint64_t)ino_block0;
  }

  if (ino_c && ino_s)
    return ino_c != ino_s;

  /*
   * One of the inode numbers is unknown, try a forced vim_FullName() and
   * compare the file names.
   */
  retval_c = vim_FullName((char *)fname_c, (char *)buf_c, MAXPATHL, TRUE);
  retval_s = vim_FullName((char *)fname_s, (char *)buf_s, MAXPATHL, TRUE);
  if (retval_c == OK && retval_s == OK)
    return STRCMP(buf_c, buf_s) != 0;

  /*
   * Can't compare inodes or file names, guess that the files are different,
   * unless both appear not to exist at all, then compare with the file name
   * in the swap file.
   */
  if (ino_s == 0 && ino_c == 0 && retval_c == FAIL && retval_s == FAIL) {
    return STRCMP(fname_c, fname_s) != 0;
  }
  return true;
}

/*
 * Move a long integer into a four byte character array.
 * Used for machine independency in block zero.
 */
static void long_to_char(long n, char_u *s)
{
  s[0] = (char_u)(n & 0xff);
  n = (unsigned)n >> 8;
  s[1] = (char_u)(n & 0xff);
  n = (unsigned)n >> 8;
  s[2] = (char_u)(n & 0xff);
  n = (unsigned)n >> 8;
  s[3] = (char_u)(n & 0xff);
}

static long char_to_long(char_u *s)
{
  long retval;

  retval = s[3];
  retval <<= 8;
  retval |= s[2];
  retval <<= 8;
  retval |= s[1];
  retval <<= 8;
  retval |= s[0];

  return retval;
}

/*
 * Set the flags in the first block of the swap file:
 * - file is modified or not: buf->b_changed
 * - 'fileformat'
 * - 'fileencoding'
 */
void ml_setflags(buf_T *buf)
{
  bhdr_T      *hp;
  ZERO_BL     *b0p;

  if (!buf->b_ml.ml_mfp)
    return;
  for (hp = buf->b_ml.ml_mfp->mf_used_last; hp != NULL; hp = hp->bh_prev) {
    if (hp->bh_bnum == 0) {
      b0p = hp->bh_data;
      b0p->b0_dirty = buf->b_changed ? B0_DIRTY : 0;
      b0p->b0_flags = (b0p->b0_flags & ~B0_FF_MASK)
                      | (get_fileformat(buf) + 1);
      add_b0_fenc(b0p, buf);
      hp->bh_flags |= BH_DIRTY;
      mf_sync(buf->b_ml.ml_mfp, MFS_ZERO);
      break;
    }
  }
}

#define MLCS_MAXL 800   /* max no of lines in chunk */
#define MLCS_MINL 400   /* should be half of MLCS_MAXL */

/*
 * Keep information for finding byte offset of a line, updtype may be one of:
 * ML_CHNK_ADDLINE: Add len to parent chunk, possibly splitting it
 *	   Careful: ML_CHNK_ADDLINE may cause ml_find_line() to be called.
 * ML_CHNK_DELLINE: Subtract len from parent chunk, possibly deleting it
 * ML_CHNK_UPDLINE: Add len to parent chunk, as a signed entity.
 */
static void ml_updatechunk(buf_T *buf, linenr_T line, long len, int updtype)
{
  static buf_T        *ml_upd_lastbuf = NULL;
  static linenr_T ml_upd_lastline;
  static linenr_T ml_upd_lastcurline;
  static int ml_upd_lastcurix;

  linenr_T curline = ml_upd_lastcurline;
  int curix = ml_upd_lastcurix;
  long size;
  chunksize_T         *curchnk;
  int rest;
  bhdr_T              *hp;
  DATA_BL             *dp;

  if (buf->b_ml.ml_usedchunks == -1 || len == 0)
    return;
  if (buf->b_ml.ml_chunksize == NULL) {
    buf->b_ml.ml_chunksize = xmalloc(sizeof(chunksize_T) * 100);
    buf->b_ml.ml_numchunks = 100;
    buf->b_ml.ml_usedchunks = 1;
    buf->b_ml.ml_chunksize[0].mlcs_numlines = 1;
    buf->b_ml.ml_chunksize[0].mlcs_totalsize = 1;
  }

  if (updtype == ML_CHNK_UPDLINE && buf->b_ml.ml_line_count == 1) {
    /*
     * First line in empty buffer from ml_flush_line() -- reset
     */
    buf->b_ml.ml_usedchunks = 1;
    buf->b_ml.ml_chunksize[0].mlcs_numlines = 1;
    buf->b_ml.ml_chunksize[0].mlcs_totalsize =
      (long)STRLEN(buf->b_ml.ml_line_ptr) + 1;
    return;
  }

  /*
   * Find chunk that our line belongs to, curline will be at start of the
   * chunk.
   */
  if (buf != ml_upd_lastbuf || line != ml_upd_lastline + 1
      || updtype != ML_CHNK_ADDLINE) {
    for (curline = 1, curix = 0;
         curix < buf->b_ml.ml_usedchunks - 1
                 && line >= curline +
                             buf->b_ml.ml_chunksize[curix].mlcs_numlines;
         curix++) {
      curline += buf->b_ml.ml_chunksize[curix].mlcs_numlines;
    }
  } else if (curix < buf->b_ml.ml_usedchunks - 1
             && line >= curline + buf->b_ml.ml_chunksize[curix].mlcs_numlines) {
    // Adjust cached curix & curline
    curline += buf->b_ml.ml_chunksize[curix].mlcs_numlines;
    curix++;
  }
  curchnk = buf->b_ml.ml_chunksize + curix;

  if (updtype == ML_CHNK_DELLINE)
    len = -len;
  curchnk->mlcs_totalsize += len;
  if (updtype == ML_CHNK_ADDLINE) {
    curchnk->mlcs_numlines++;

    /* May resize here so we don't have to do it in both cases below */
    if (buf->b_ml.ml_usedchunks + 1 >= buf->b_ml.ml_numchunks) {
      buf->b_ml.ml_numchunks = buf->b_ml.ml_numchunks * 3 / 2;
      buf->b_ml.ml_chunksize = (chunksize_T *)
                               xrealloc(buf->b_ml.ml_chunksize,
          sizeof(chunksize_T) * buf->b_ml.ml_numchunks);
    }

    if (buf->b_ml.ml_chunksize[curix].mlcs_numlines >= MLCS_MAXL) {
      int count;                    /* number of entries in block */
      int idx;
      int text_end;
      int linecnt;

      memmove(buf->b_ml.ml_chunksize + curix + 1,
          buf->b_ml.ml_chunksize + curix,
          (buf->b_ml.ml_usedchunks - curix) *
          sizeof(chunksize_T));
      /* Compute length of first half of lines in the split chunk */
      size = 0;
      linecnt = 0;
      while (curline < buf->b_ml.ml_line_count
             && linecnt < MLCS_MINL) {
        if ((hp = ml_find_line(buf, curline, ML_FIND)) == NULL) {
          buf->b_ml.ml_usedchunks = -1;
          return;
        }
        dp = hp->bh_data;
        count = (long)(buf->b_ml.ml_locked_high) -
                (long)(buf->b_ml.ml_locked_low) + 1;
        idx = curline - buf->b_ml.ml_locked_low;
        curline = buf->b_ml.ml_locked_high + 1;
        if (idx == 0)        /* first line in block, text at the end */
          text_end = dp->db_txt_end;
        else
          text_end = ((dp->db_index[idx - 1]) & DB_INDEX_MASK);
        /* Compute index of last line to use in this MEMLINE */
        rest = count - idx;
        if (linecnt + rest > MLCS_MINL) {
          idx += MLCS_MINL - linecnt - 1;
          linecnt = MLCS_MINL;
        } else {
          idx = count - 1;
          linecnt += rest;
        }
        size += text_end - ((dp->db_index[idx]) & DB_INDEX_MASK);
      }
      buf->b_ml.ml_chunksize[curix].mlcs_numlines = linecnt;
      buf->b_ml.ml_chunksize[curix + 1].mlcs_numlines -= linecnt;
      buf->b_ml.ml_chunksize[curix].mlcs_totalsize = size;
      buf->b_ml.ml_chunksize[curix + 1].mlcs_totalsize -= size;
      buf->b_ml.ml_usedchunks++;
      ml_upd_lastbuf = NULL;         /* Force recalc of curix & curline */
      return;
    } else if (buf->b_ml.ml_chunksize[curix].mlcs_numlines >= MLCS_MINL
               && curix == buf->b_ml.ml_usedchunks - 1
               && buf->b_ml.ml_line_count - line <= 1) {
      /*
       * We are in the last chunk and it is cheap to crate a new one
       * after this. Do it now to avoid the loop above later on
       */
      curchnk = buf->b_ml.ml_chunksize + curix + 1;
      buf->b_ml.ml_usedchunks++;
      if (line == buf->b_ml.ml_line_count) {
        curchnk->mlcs_numlines = 0;
        curchnk->mlcs_totalsize = 0;
      } else {
        /*
         * Line is just prior to last, move count for last
         * This is the common case  when loading a new file
         */
        hp = ml_find_line(buf, buf->b_ml.ml_line_count, ML_FIND);
        if (hp == NULL) {
          buf->b_ml.ml_usedchunks = -1;
          return;
        }
        dp = hp->bh_data;
        if (dp->db_line_count == 1)
          rest = dp->db_txt_end - dp->db_txt_start;
        else
          rest =
            ((dp->db_index[dp->db_line_count - 2]) & DB_INDEX_MASK)
            - dp->db_txt_start;
        curchnk->mlcs_totalsize = rest;
        curchnk->mlcs_numlines = 1;
        curchnk[-1].mlcs_totalsize -= rest;
        curchnk[-1].mlcs_numlines -= 1;
      }
    }
  } else if (updtype == ML_CHNK_DELLINE) {
    curchnk->mlcs_numlines--;
    ml_upd_lastbuf = NULL;       /* Force recalc of curix & curline */
    if (curix < (buf->b_ml.ml_usedchunks - 1)
        && (curchnk->mlcs_numlines + curchnk[1].mlcs_numlines)
        <= MLCS_MINL) {
      curix++;
      curchnk = buf->b_ml.ml_chunksize + curix;
    } else if (curix == 0 && curchnk->mlcs_numlines <= 0) {
      buf->b_ml.ml_usedchunks--;
      memmove(buf->b_ml.ml_chunksize, buf->b_ml.ml_chunksize + 1,
          buf->b_ml.ml_usedchunks * sizeof(chunksize_T));
      return;
    } else if (curix == 0 || (curchnk->mlcs_numlines > 10
                              && (curchnk->mlcs_numlines +
                                  curchnk[-1].mlcs_numlines)
                              > MLCS_MINL)) {
      return;
    }

    /* Collapse chunks */
    curchnk[-1].mlcs_numlines += curchnk->mlcs_numlines;
    curchnk[-1].mlcs_totalsize += curchnk->mlcs_totalsize;
    buf->b_ml.ml_usedchunks--;
    if (curix < buf->b_ml.ml_usedchunks) {
      memmove(buf->b_ml.ml_chunksize + curix,
          buf->b_ml.ml_chunksize + curix + 1,
          (buf->b_ml.ml_usedchunks - curix) *
          sizeof(chunksize_T));
    }
    return;
  }
  ml_upd_lastbuf = buf;
  ml_upd_lastline = line;
  ml_upd_lastcurline = curline;
  ml_upd_lastcurix = curix;
}

/// Find offset for line or line with offset.
///
/// @param buf buffer to use
/// @param lnum if > 0, find offset of lnum, store offset in offp
///             if == 0, return line with offset *offp
/// @param offp Location where offset of line is stored, or to read offset to
///             use to find line. In the later case, store remaining offset.
/// @param no_ff ignore 'fileformat' option, always use one byte for NL.
///
/// @return -1 if information is not available
long ml_find_line_or_offset(buf_T *buf, linenr_T lnum, long *offp, bool no_ff)
{
  linenr_T curline;
  int curix;
  long size;
  bhdr_T      *hp;
  DATA_BL     *dp;
  int count;                    /* number of entries in block */
  int idx;
  int start_idx;
  int text_end;
  long offset;
  int len;
  int ffdos = !no_ff && (get_fileformat(buf) == EOL_DOS);
  int extra = 0;

  /* take care of cached line first */
  ml_flush_line(curbuf);

  if (buf->b_ml.ml_usedchunks == -1
      || buf->b_ml.ml_chunksize == NULL
      || lnum < 0)
    return -1;

  if (offp == NULL)
    offset = 0;
  else
    offset = *offp;
  if (lnum == 0 && offset <= 0)
    return 1;       /* Not a "find offset" and offset 0 _must_ be in line 1 */
  /*
   * Find the last chunk before the one containing our line. Last chunk is
   * special because it will never qualify
   */
  curline = 1;
  curix = size = 0;
  while (curix < buf->b_ml.ml_usedchunks - 1
         && ((lnum != 0
              && lnum >= curline + buf->b_ml.ml_chunksize[curix].mlcs_numlines)
             || (offset != 0
                 && offset > size +
                 buf->b_ml.ml_chunksize[curix].mlcs_totalsize
                 + ffdos * buf->b_ml.ml_chunksize[curix].mlcs_numlines))) {
    curline += buf->b_ml.ml_chunksize[curix].mlcs_numlines;
    size += buf->b_ml.ml_chunksize[curix].mlcs_totalsize;
    if (offset && ffdos)
      size += buf->b_ml.ml_chunksize[curix].mlcs_numlines;
    curix++;
  }

  while ((lnum != 0 && curline < lnum) || (offset != 0 && size < offset)) {
    if (curline > buf->b_ml.ml_line_count
        || (hp = ml_find_line(buf, curline, ML_FIND)) == NULL)
      return -1;
    dp = hp->bh_data;
    count = (long)(buf->b_ml.ml_locked_high) -
            (long)(buf->b_ml.ml_locked_low) + 1;
    start_idx = idx = curline - buf->b_ml.ml_locked_low;
    if (idx == 0)    /* first line in block, text at the end */
      text_end = dp->db_txt_end;
    else
      text_end = ((dp->db_index[idx - 1]) & DB_INDEX_MASK);
    /* Compute index of last line to use in this MEMLINE */
    if (lnum != 0) {
      if (curline + (count - idx) >= lnum)
        idx += lnum - curline - 1;
      else
        idx = count - 1;
    } else {
      extra = 0;
      while (offset >= size
             + text_end - (int)((dp->db_index[idx]) & DB_INDEX_MASK)
             + ffdos) {
        if (ffdos)
          size++;
        if (idx == count - 1) {
          extra = 1;
          break;
        }
        idx++;
      }
    }
    len = text_end - ((dp->db_index[idx]) & DB_INDEX_MASK);
    size += len;
    if (offset != 0 && size >= offset) {
      if (size + ffdos == offset)
        *offp = 0;
      else if (idx == start_idx)
        *offp = offset - size + len;
      else
        *offp = offset - size + len
                - (text_end - ((dp->db_index[idx - 1]) & DB_INDEX_MASK));
      curline += idx - start_idx + extra;
      if (curline > buf->b_ml.ml_line_count)
        return -1;              /* exactly one byte beyond the end */
      return curline;
    }
    curline = buf->b_ml.ml_locked_high + 1;
  }

  if (lnum != 0) {
    /* Count extra CR characters. */
    if (ffdos)
      size += lnum - 1;

    /* Don't count the last line break if 'noeol' and ('bin' or
     * 'nofixeol'). */
    if ((!buf->b_p_fixeol || buf->b_p_bin) && !buf->b_p_eol
        && lnum > buf->b_ml.ml_line_count) {
      size -= ffdos + 1;
    }
  }

  return size;
}

/// Goto byte in buffer with offset 'cnt'.
void goto_byte(long cnt)
{
  long boff = cnt;
  linenr_T lnum;

  ml_flush_line(curbuf);  // cached line may be dirty
  setpcmark();
  if (boff) {
    boff--;
  }
  lnum = ml_find_line_or_offset(curbuf, (linenr_T)0, &boff, false);
  if (lnum < 1) {         // past the end
    curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
    curwin->w_curswant = MAXCOL;
    coladvance((colnr_T)MAXCOL);
  } else {
    curwin->w_cursor.lnum = lnum;
    curwin->w_cursor.col = (colnr_T)boff;
    curwin->w_cursor.coladd = 0;
    curwin->w_set_curswant = TRUE;
  }
  check_cursor();

  // Make sure the cursor is on the first byte of a multi-byte char.
  if (has_mbyte) {
    mb_adjust_cursor();
  }
}

/// Increment the line pointer "lp" crossing line boundaries as necessary.
/// Return 1 when going to the next line.
/// Return 2 when moving forward onto a NUL at the end of the line).
/// Return -1 when at the end of file.
/// Return 0 otherwise.
int inc(pos_T *lp)
{
  // when searching position may be set to end of a line
  if (lp->col != MAXCOL) {
    const char_u *const p = ml_get_pos(lp);
    if (*p != NUL) {  // still within line, move to next char (may be NUL)
      const int l = utfc_ptr2len(p);

      lp->col += l;
      return ((p[l] != NUL) ? 0 : 2);
    }
  }
  if (lp->lnum != curbuf->b_ml.ml_line_count) {     // there is a next line
    lp->col = 0;
    lp->lnum++;
    lp->coladd = 0;
    return 1;
  }
  return -1;
}

/// Same as inc(), but skip NUL at the end of non-empty lines.
int incl(pos_T *lp)
{
  int r;

  if ((r = inc(lp)) >= 1 && lp->col) {
    r = inc(lp);
  }
  return r;
}

int dec(pos_T *lp)
{
  lp->coladd = 0;
  if (lp->col == MAXCOL) {
    // past end of line
    char_u *p = ml_get(lp->lnum);
    lp->col = (colnr_T)STRLEN(p);
    lp->col -= utf_head_off(p, p + lp->col);
    return 0;
  }

  if (lp->col > 0) {
    // still within line
    lp->col--;
    char_u *p = ml_get(lp->lnum);
    lp->col -= utf_head_off(p, p + lp->col);
    return 0;
  }
  if (lp->lnum > 1) {
    // there is a prior line
    lp->lnum--;
    char_u *p = ml_get(lp->lnum);
    lp->col = (colnr_T)STRLEN(p);
    lp->col -= utf_head_off(p, p + lp->col);
    return 1;
  }

  // at start of file
  return -1;
}

/// Same as dec(), but skip NUL at the end of non-empty lines.
int decl(pos_T *lp)
{
  int r;

  if ((r = dec(lp)) == 1 && lp->col) {
    r = dec(lp);
  }
  return r;
}
