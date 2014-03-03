/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

/*
 * This file contains various definitions of structures that are used by Vim
 */

/*
 * There is something wrong in the SAS compiler that makes typedefs not
 * valid in include files.  Has been fixed in version 6.58.
 */

/*
 * position in file or buffer
 */
typedef struct {
  linenr_T lnum;        /* line number */
  colnr_T col;          /* column number */
  colnr_T coladd;
} pos_T;

# define INIT_POS_T(l, c, ca) {l, c, ca}

/*
 * Same, but without coladd.
 */
typedef struct {
  linenr_T lnum;        /* line number */
  colnr_T col;          /* column number */
} lpos_T;

/*
 * Structure used for growing arrays.
 * This is used to store information that only grows, is deleted all at
 * once, and needs to be accessed by index.  See ga_clear() and ga_grow().
 */
typedef struct growarray {
  int ga_len;                       /* current number of items used */
  int ga_maxlen;                    /* maximum number of items possible */
  int ga_itemsize;                  /* sizeof(item) */
  int ga_growsize;                  /* number of items to grow each time */
  void    *ga_data;                 /* pointer to the first item */
} garray_T;

#define GA_EMPTY    {0, 0, 0, 0, NULL}

typedef struct window_S win_T;
typedef struct wininfo_S wininfo_T;
typedef struct frame_S frame_T;
typedef int scid_T;                             /* script ID */
typedef struct file_buffer buf_T;       /* forward declaration */

/*
 * This is here because regexp_defs.h needs pos_T and below regprog_T is used.
 */
#include "regexp_defs.h"

/*
 * This is here because gui.h needs the pos_T and win_T, and win_T needs gui.h
 * for scrollbar_T.
 */
# define guicolor_T int         /* avoid error in prototypes */

/*
 * marks: positions in a file
 * (a normal mark is a lnum/col pair, the same as a file position)
 */

/* (Note: for EBCDIC there are more than 26, because there are gaps in the
 * alphabet coding.  To minimize changes to the code, I decided to just
 * increase the number of possible marks. */
#define NMARKS          ('z' - 'a' + 1) /* max. # of named marks */
#define JUMPLISTSIZE    100             /* max. # of marks in jump list */
#define TAGSTACKSIZE    20              /* max. # of tags in tag stack */

typedef struct filemark {
  pos_T mark;                   /* cursor position */
  int fnum;                     /* file number */
} fmark_T;

/* Xtended file mark: also has a file name */
typedef struct xfilemark {
  fmark_T fmark;
  char_u      *fname;           /* file name, used when fnum == 0 */
} xfmark_T;

/*
 * The taggy struct is used to store the information about a :tag command.
 */
typedef struct taggy {
  char_u      *tagname;         /* tag name */
  fmark_T fmark;                /* cursor position BEFORE ":tag" */
  int cur_match;                /* match number */
  int cur_fnum;                 /* buffer number used for cur_match */
} taggy_T;

/*
 * Structure that contains all options that are local to a window.
 * Used twice in a window: for the current buffer and for all buffers.
 * Also used in wininfo_T.
 */
typedef struct {
  int wo_arab;
# define w_p_arab w_onebuf_opt.wo_arab  /* 'arabic' */
  int wo_diff;
# define w_p_diff w_onebuf_opt.wo_diff  /* 'diff' */
  long wo_fdc;
# define w_p_fdc w_onebuf_opt.wo_fdc    /* 'foldcolumn' */
  int wo_fdc_save;
# define w_p_fdc_save w_onebuf_opt.wo_fdc_save  /* 'foldenable' saved for diff mode */
  int wo_fen;
# define w_p_fen w_onebuf_opt.wo_fen    /* 'foldenable' */
  int wo_fen_save;
# define w_p_fen_save w_onebuf_opt.wo_fen_save  /* 'foldenable' saved for diff mode */
  char_u      *wo_fdi;
# define w_p_fdi w_onebuf_opt.wo_fdi    /* 'foldignore' */
  long wo_fdl;
# define w_p_fdl w_onebuf_opt.wo_fdl    /* 'foldlevel' */
  int wo_fdl_save;
# define w_p_fdl_save w_onebuf_opt.wo_fdl_save  /* 'foldlevel' state saved for diff mode */
  char_u      *wo_fdm;
# define w_p_fdm w_onebuf_opt.wo_fdm    /* 'foldmethod' */
  char_u      *wo_fdm_save;
# define w_p_fdm_save w_onebuf_opt.wo_fdm_save  /* 'fdm' saved for diff mode */
  long wo_fml;
# define w_p_fml w_onebuf_opt.wo_fml    /* 'foldminlines' */
  long wo_fdn;
# define w_p_fdn w_onebuf_opt.wo_fdn    /* 'foldnestmax' */
  char_u      *wo_fde;
# define w_p_fde w_onebuf_opt.wo_fde    /* 'foldexpr' */
  char_u      *wo_fdt;
#  define w_p_fdt w_onebuf_opt.wo_fdt   /* 'foldtext' */
  char_u      *wo_fmr;
# define w_p_fmr w_onebuf_opt.wo_fmr    /* 'foldmarker' */
  int wo_lbr;
# define w_p_lbr w_onebuf_opt.wo_lbr    /* 'linebreak' */
  int wo_list;
#define w_p_list w_onebuf_opt.wo_list   /* 'list' */
  int wo_nu;
#define w_p_nu w_onebuf_opt.wo_nu       /* 'number' */
  int wo_rnu;
#define w_p_rnu w_onebuf_opt.wo_rnu     /* 'relativenumber' */
  long wo_nuw;
# define w_p_nuw w_onebuf_opt.wo_nuw    /* 'numberwidth' */
  int wo_wfh;
# define w_p_wfh w_onebuf_opt.wo_wfh    /* 'winfixheight' */
  int wo_wfw;
# define w_p_wfw w_onebuf_opt.wo_wfw    /* 'winfixwidth' */
  int wo_pvw;
# define w_p_pvw w_onebuf_opt.wo_pvw    /* 'previewwindow' */
  int wo_rl;
# define w_p_rl w_onebuf_opt.wo_rl      /* 'rightleft' */
  char_u      *wo_rlc;
# define w_p_rlc w_onebuf_opt.wo_rlc    /* 'rightleftcmd' */
  long wo_scr;
#define w_p_scr w_onebuf_opt.wo_scr     /* 'scroll' */
  int wo_spell;
# define w_p_spell w_onebuf_opt.wo_spell /* 'spell' */
  int wo_cuc;
# define w_p_cuc w_onebuf_opt.wo_cuc    /* 'cursorcolumn' */
  int wo_cul;
# define w_p_cul w_onebuf_opt.wo_cul    /* 'cursorline' */
  char_u      *wo_cc;
# define w_p_cc w_onebuf_opt.wo_cc      /* 'colorcolumn' */
  char_u      *wo_stl;
#define w_p_stl w_onebuf_opt.wo_stl     /* 'statusline' */
  int wo_scb;
# define w_p_scb w_onebuf_opt.wo_scb    /* 'scrollbind' */
  int wo_diff_saved;           /* options were saved for starting diff mode */
# define w_p_diff_saved w_onebuf_opt.wo_diff_saved
  int wo_scb_save;              /* 'scrollbind' saved for diff mode*/
# define w_p_scb_save w_onebuf_opt.wo_scb_save
  int wo_wrap;
#define w_p_wrap w_onebuf_opt.wo_wrap   /* 'wrap' */
  int wo_wrap_save;             /* 'wrap' state saved for diff mode*/
# define w_p_wrap_save w_onebuf_opt.wo_wrap_save
  char_u      *wo_cocu;                 /* 'concealcursor' */
# define w_p_cocu w_onebuf_opt.wo_cocu
  long wo_cole;                         /* 'conceallevel' */
# define w_p_cole w_onebuf_opt.wo_cole
  int wo_crb;
# define w_p_crb w_onebuf_opt.wo_crb    /* 'cursorbind' */
  int wo_crb_save;              /* 'cursorbind' state saved for diff mode*/
# define w_p_crb_save w_onebuf_opt.wo_crb_save

  int wo_scriptID[WV_COUNT];            /* SIDs for window-local options */
# define w_p_scriptID w_onebuf_opt.wo_scriptID
} winopt_T;

/*
 * Window info stored with a buffer.
 *
 * Two types of info are kept for a buffer which are associated with a
 * specific window:
 * 1. Each window can have a different line number associated with a buffer.
 * 2. The window-local options for a buffer work in a similar way.
 * The window-info is kept in a list at b_wininfo.  It is kept in
 * most-recently-used order.
 */
struct wininfo_S {
  wininfo_T   *wi_next;         /* next entry or NULL for last entry */
  wininfo_T   *wi_prev;         /* previous entry or NULL for first entry */
  win_T       *wi_win;          /* pointer to window that did set wi_fpos */
  pos_T wi_fpos;                /* last cursor position in the file */
  int wi_optset;                /* TRUE when wi_opt has useful values */
  winopt_T wi_opt;              /* local window options */
  int wi_fold_manual;           /* copy of w_fold_manual */
  garray_T wi_folds;            /* clone of w_folds */
};

/*
 * Info used to pass info about a fold from the fold-detection code to the
 * code that displays the foldcolumn.
 */
typedef struct foldinfo {
  int fi_level;                 /* level of the fold; when this is zero the
                                   other fields are invalid */
  int fi_lnum;                  /* line number where fold starts */
  int fi_low_level;             /* lowest fold level that starts in the same
                                   line */
} foldinfo_T;

/* Structure to store info about the Visual area. */
typedef struct {
  pos_T vi_start;               /* start pos of last VIsual */
  pos_T vi_end;                 /* end position of last VIsual */
  int vi_mode;                  /* VIsual_mode of last VIsual */
  colnr_T vi_curswant;          /* MAXCOL from w_curswant */
} visualinfo_T;

/*
 * structures used for undo
 */

typedef struct u_entry u_entry_T;
typedef struct u_header u_header_T;
struct u_entry {
  u_entry_T   *ue_next;         /* pointer to next entry in list */
  linenr_T ue_top;              /* number of line above undo block */
  linenr_T ue_bot;              /* number of line below undo block */
  linenr_T ue_lcount;           /* linecount when u_save called */
  char_u      **ue_array;       /* array of lines in undo block */
  long ue_size;                 /* number of lines in ue_array */
#ifdef U_DEBUG
  int ue_magic;                 /* magic number to check allocation */
#endif
};

struct u_header {
  /* The following have a pointer and a number. The number is used when
   * reading the undo file in u_read_undo() */
  union {
    u_header_T *ptr;            /* pointer to next undo header in list */
    long seq;
  } uh_next;
  union {
    u_header_T *ptr;            /* pointer to previous header in list */
    long seq;
  } uh_prev;
  union {
    u_header_T *ptr;            /* pointer to next header for alt. redo */
    long seq;
  } uh_alt_next;
  union {
    u_header_T *ptr;            /* pointer to previous header for alt. redo */
    long seq;
  } uh_alt_prev;
  long uh_seq;                  /* sequence number, higher == newer undo */
  int uh_walk;                  /* used by undo_time() */
  u_entry_T   *uh_entry;        /* pointer to first entry */
  u_entry_T   *uh_getbot_entry;   /* pointer to where ue_bot must be set */
  pos_T uh_cursor;              /* cursor position before saving */
  long uh_cursor_vcol;
  int uh_flags;                 /* see below */
  pos_T uh_namedm[NMARKS];              /* marks before undo/after redo */
  visualinfo_T uh_visual;       /* Visual areas before undo/after redo */
  time_t uh_time;               /* timestamp when the change was made */
  long uh_save_nr;              /* set when the file was saved after the
                                   changes in this block */
#ifdef U_DEBUG
  int uh_magic;                 /* magic number to check allocation */
#endif
};

/* values for uh_flags */
#define UH_CHANGED  0x01        /* b_changed flag before undo/after redo */
#define UH_EMPTYBUF 0x02        /* buffer was empty */

/*
 * things used in memfile.c
 */

typedef struct block_hdr bhdr_T;
typedef struct memfile memfile_T;
typedef long blocknr_T;

/*
 * mf_hashtab_T is a chained hashtable with blocknr_T key and arbitrary
 * structures as items.  This is an intrusive data structure: we require
 * that items begin with mf_hashitem_T which contains the key and linked
 * list pointers.  List of items in each bucket is doubly-linked.
 */

typedef struct mf_hashitem_S mf_hashitem_T;

struct mf_hashitem_S {
  mf_hashitem_T   *mhi_next;
  mf_hashitem_T   *mhi_prev;
  blocknr_T mhi_key;
};

#define MHT_INIT_SIZE   64

typedef struct mf_hashtab_S {
  long_u mht_mask;                  /* mask used for hash value (nr of items
                                     * in array is "mht_mask" + 1) */
  long_u mht_count;                 /* nr of items inserted into hashtable */
  mf_hashitem_T   **mht_buckets;    /* points to mht_small_buckets or
                                     *dynamically allocated array */
  mf_hashitem_T   *mht_small_buckets[MHT_INIT_SIZE];     /* initial buckets */
  char mht_fixed;                   /* non-zero value forbids growth */
} mf_hashtab_T;

/*
 * for each (previously) used block in the memfile there is one block header.
 *
 * The block may be linked in the used list OR in the free list.
 * The used blocks are also kept in hash lists.
 *
 * The used list is a doubly linked list, most recently used block first.
 *	The blocks in the used list have a block of memory allocated.
 *	mf_used_count is the number of pages in the used list.
 * The hash lists are used to quickly find a block in the used list.
 * The free list is a single linked list, not sorted.
 *	The blocks in the free list have no block of memory allocated and
 *	the contents of the block in the file (if any) is irrelevant.
 */

struct block_hdr {
  mf_hashitem_T bh_hashitem;        /* header for hash table and key */
#define bh_bnum bh_hashitem.mhi_key /* block number, part of bh_hashitem */

  bhdr_T      *bh_next;             /* next block_hdr in free or used list */
  bhdr_T      *bh_prev;             /* previous block_hdr in used list */
  char_u      *bh_data;             /* pointer to memory (for used block) */
  int bh_page_count;                /* number of pages in this block */

#define BH_DIRTY    1
#define BH_LOCKED   2
  char bh_flags;                    /* BH_DIRTY or BH_LOCKED */
};

/*
 * when a block with a negative number is flushed to the file, it gets
 * a positive number. Because the reference to the block is still the negative
 * number, we remember the translation to the new positive number in the
 * double linked trans lists. The structure is the same as the hash lists.
 */
typedef struct nr_trans NR_TRANS;

struct nr_trans {
  mf_hashitem_T nt_hashitem;            /* header for hash table and key */
#define nt_old_bnum nt_hashitem.mhi_key /* old, negative, number */

  blocknr_T nt_new_bnum;                /* new, positive, number */
};

/*
 * structure used to store one block of the stuff/redo/recording buffers
 */
struct buffblock {
  struct buffblock    *b_next;          /* pointer to next buffblock */
  char_u b_str[1];                      /* contents (actually longer) */
};

/*
 * header used for the stuff buffer and the redo buffer
 */
struct buffheader {
  struct buffblock bh_first;            /* first (dummy) block of list */
  struct buffblock    *bh_curr;         /* buffblock for appending */
  int bh_index;                         /* index for reading */
  int bh_space;                         /* space in bh_curr for appending */
};

/*
 * used for completion on the command line
 */
typedef struct expand {
  int xp_context;                       /* type of expansion */
  char_u      *xp_pattern;              /* start of item to expand */
  int xp_pattern_len;                   /* bytes in xp_pattern before cursor */
  char_u      *xp_arg;                  /* completion function */
  int xp_scriptID;                      /* SID for completion function */
  int xp_backslash;                     /* one of the XP_BS_ values */
#ifndef BACKSLASH_IN_FILENAME
  int xp_shell;                         /* TRUE for a shell command, more
                                           characters need to be escaped */
#endif
  int xp_numfiles;                      /* number of files found by
                                                    file name completion */
  char_u      **xp_files;               /* list of files */
  char_u      *xp_line;                 /* text being completed */
  int xp_col;                           /* cursor position in line */
} expand_T;

/* values for xp_backslash */
#define XP_BS_NONE      0       /* nothing special for backslashes */
#define XP_BS_ONE       1       /* uses one backslash before a space */
#define XP_BS_THREE     2       /* uses three backslashes before a space */

/*
 * Command modifiers ":vertical", ":browse", ":confirm" and ":hide" set a flag.
 * This needs to be saved for recursive commands, put them in a structure for
 * easy manipulation.
 */
typedef struct {
  int hide;                             /* TRUE when ":hide" was used */
  int split;                            /* flags for win_split() */
  int tab;                              /* > 0 when ":tab" was used */
  int confirm;                          /* TRUE to invoke yes/no dialog */
  int keepalt;                          /* TRUE when ":keepalt" was used */
  int keepmarks;                        /* TRUE when ":keepmarks" was used */
  int keepjumps;                        /* TRUE when ":keepjumps" was used */
  int lockmarks;                        /* TRUE when ":lockmarks" was used */
  int keeppatterns;                     /* TRUE when ":keeppatterns" was used */
  char_u      *save_ei;                 /* saved value of 'eventignore' */
} cmdmod_T;

#define MF_SEED_LEN     8

struct memfile {
  char_u      *mf_fname;                /* name of the file */
  char_u      *mf_ffname;               /* idem, full path */
  int mf_fd;                            /* file descriptor */
  bhdr_T      *mf_free_first;           /* first block_hdr in free list */
  bhdr_T      *mf_used_first;           /* mru block_hdr in used list */
  bhdr_T      *mf_used_last;            /* lru block_hdr in used list */
  unsigned mf_used_count;               /* number of pages in used list */
  unsigned mf_used_count_max;           /* maximum number of pages in memory */
  mf_hashtab_T mf_hash;                 /* hash lists */
  mf_hashtab_T mf_trans;                /* trans lists */
  blocknr_T mf_blocknr_max;             /* highest positive block number + 1*/
  blocknr_T mf_blocknr_min;             /* lowest negative block number - 1 */
  blocknr_T mf_neg_count;               /* number of negative blocks numbers */
  blocknr_T mf_infile_count;            /* number of pages in the file */
  unsigned mf_page_size;                /* number of bytes in a page */
  int mf_dirty;                         /* TRUE if there are dirty blocks */
  buf_T       *mf_buffer;               /* bufer this memfile is for */
  char_u mf_seed[MF_SEED_LEN];          /* seed for encryption */

  /* Values for key, method and seed used for reading data blocks when
   * updating for a newly set key or method. Only when mf_old_key != NULL. */
  char_u      *mf_old_key;
  int mf_old_cm;
  char_u mf_old_seed[MF_SEED_LEN];
};

/*
 * things used in memline.c
 */
/*
 * When searching for a specific line, we remember what blocks in the tree
 * are the branches leading to that block. This is stored in ml_stack.  Each
 * entry is a pointer to info in a block (may be data block or pointer block)
 */
typedef struct info_pointer {
  blocknr_T ip_bnum;            /* block number */
  linenr_T ip_low;              /* lowest lnum in this block */
  linenr_T ip_high;             /* highest lnum in this block */
  int ip_index;                 /* index for block with current lnum */
} infoptr_T;    /* block/index pair */

typedef struct ml_chunksize {
  int mlcs_numlines;
  long mlcs_totalsize;
} chunksize_T;

/* Flags when calling ml_updatechunk() */

#define ML_CHNK_ADDLINE 1
#define ML_CHNK_DELLINE 2
#define ML_CHNK_UPDLINE 3

/*
 * the memline structure holds all the information about a memline
 */
typedef struct memline {
  linenr_T ml_line_count;       /* number of lines in the buffer */

  memfile_T   *ml_mfp;          /* pointer to associated memfile */

#define ML_EMPTY        1       /* empty buffer */
#define ML_LINE_DIRTY   2       /* cached line was changed and allocated */
#define ML_LOCKED_DIRTY 4       /* ml_locked was changed */
#define ML_LOCKED_POS   8       /* ml_locked needs positive block number */
  int ml_flags;

  infoptr_T   *ml_stack;        /* stack of pointer blocks (array of IPTRs) */
  int ml_stack_top;             /* current top if ml_stack */
  int ml_stack_size;            /* total number of entries in ml_stack */

  linenr_T ml_line_lnum;        /* line number of cached line, 0 if not valid */
  char_u      *ml_line_ptr;     /* pointer to cached line */

  bhdr_T      *ml_locked;       /* block used by last ml_get */
  linenr_T ml_locked_low;       /* first line in ml_locked */
  linenr_T ml_locked_high;      /* last line in ml_locked */
  int ml_locked_lineadd;            /* number of lines inserted in ml_locked */
  chunksize_T *ml_chunksize;
  int ml_numchunks;
  int ml_usedchunks;
} memline_T;


/*
 * Argument list: Array of file names.
 * Used for the global argument list and the argument lists local to a window.
 */
typedef struct arglist {
  garray_T al_ga;               /* growarray with the array of file names */
  int al_refcount;              /* number of windows using this arglist */
} alist_T;

/*
 * For each argument remember the file name as it was given, and the buffer
 * number that contains the expanded file name (required for when ":cd" is
 * used.
 */
typedef struct argentry {
  char_u      *ae_fname;        /* file name as specified */
  int ae_fnum;                  /* buffer number with expanded file name */
} aentry_T;

# define ALIST(win) (win)->w_alist
#define GARGLIST        ((aentry_T *)global_alist.al_ga.ga_data)
#define ARGLIST         ((aentry_T *)ALIST(curwin)->al_ga.ga_data)
#define WARGLIST(wp)    ((aentry_T *)ALIST(wp)->al_ga.ga_data)
#define AARGLIST(al)    ((aentry_T *)((al)->al_ga.ga_data))
#define GARGCOUNT       (global_alist.al_ga.ga_len)
#define ARGCOUNT        (ALIST(curwin)->al_ga.ga_len)
#define WARGCOUNT(wp)   (ALIST(wp)->al_ga.ga_len)

/*
 * A list used for saving values of "emsg_silent".  Used by ex_try() to save the
 * value of "emsg_silent" if it was non-zero.  When this is done, the CSF_SILENT
 * flag below is set.
 */

typedef struct eslist_elem eslist_T;
struct eslist_elem {
  int saved_emsg_silent;                /* saved value of "emsg_silent" */
  eslist_T    *next;                    /* next element on the list */
};

/*
 * For conditional commands a stack is kept of nested conditionals.
 * When cs_idx < 0, there is no conditional command.
 */
#define CSTACK_LEN      50

struct condstack {
  short cs_flags[CSTACK_LEN];           /* CSF_ flags */
  char cs_pending[CSTACK_LEN];          /* CSTP_: what's pending in ":finally"*/
  union {
    void    *csp_rv[CSTACK_LEN];        /* return typeval for pending return */
    void    *csp_ex[CSTACK_LEN];        /* exception for pending throw */
  }           cs_pend;
  void        *cs_forinfo[CSTACK_LEN];   /* info used by ":for" */
  int cs_line[CSTACK_LEN];              /* line nr of ":while"/":for" line */
  int cs_idx;                           /* current entry, or -1 if none */
  int cs_looplevel;                     /* nr of nested ":while"s and ":for"s */
  int cs_trylevel;                      /* nr of nested ":try"s */
  eslist_T    *cs_emsg_silent_list;     /* saved values of "emsg_silent" */
  char cs_lflags;                       /* loop flags: CSL_ flags */
};
# define cs_rettv       cs_pend.csp_rv
# define cs_exception   cs_pend.csp_ex

/* There is no CSF_IF, the lack of CSF_WHILE, CSF_FOR and CSF_TRY means ":if"
 * was used. */
# define CSF_TRUE       0x0001  /* condition was TRUE */
# define CSF_ACTIVE     0x0002  /* current state is active */
# define CSF_ELSE       0x0004  /* ":else" has been passed */
# define CSF_WHILE      0x0008  /* is a ":while" */
# define CSF_FOR        0x0010  /* is a ":for" */

# define CSF_TRY        0x0100  /* is a ":try" */
# define CSF_FINALLY    0x0200  /* ":finally" has been passed */
# define CSF_THROWN     0x0400  /* exception thrown to this try conditional */
# define CSF_CAUGHT     0x0800  /* exception caught by this try conditional */
# define CSF_SILENT     0x1000  /* "emsg_silent" reset by ":try" */
/* Note that CSF_ELSE is only used when CSF_TRY and CSF_WHILE are unset
 * (an ":if"), and CSF_SILENT is only used when CSF_TRY is set. */

/*
 * What's pending for being reactivated at the ":endtry" of this try
 * conditional:
 */
# define CSTP_NONE      0       /* nothing pending in ":finally" clause */
# define CSTP_ERROR     1       /* an error is pending */
# define CSTP_INTERRUPT 2       /* an interrupt is pending */
# define CSTP_THROW     4       /* a throw is pending */
# define CSTP_BREAK     8       /* ":break" is pending */
# define CSTP_CONTINUE  16      /* ":continue" is pending */
# define CSTP_RETURN    24      /* ":return" is pending */
# define CSTP_FINISH    32      /* ":finish" is pending */

/*
 * Flags for the cs_lflags item in struct condstack.
 */
# define CSL_HAD_LOOP    1      /* just found ":while" or ":for" */
# define CSL_HAD_ENDLOOP 2      /* just found ":endwhile" or ":endfor" */
# define CSL_HAD_CONT    4      /* just found ":continue" */
# define CSL_HAD_FINA    8      /* just found ":finally" */

/*
 * A list of error messages that can be converted to an exception.  "throw_msg"
 * is only set in the first element of the list.  Usually, it points to the
 * original message stored in that element, but sometimes it points to a later
 * message in the list.  See cause_errthrow() below.
 */
struct msglist {
  char_u              *msg;             /* original message */
  char_u              *throw_msg;       /* msg to throw: usually original one */
  struct msglist      *next;            /* next of several messages in a row */
};

/*
 * Structure describing an exception.
 * (don't use "struct exception", it's used by the math library).
 */
typedef struct vim_exception except_T;
struct vim_exception {
  int type;                             /* exception type */
  char_u              *value;           /* exception value */
  struct msglist      *messages;        /* message(s) causing error exception */
  char_u              *throw_name;      /* name of the throw point */
  linenr_T throw_lnum;                  /* line number of the throw point */
  except_T            *caught;          /* next exception on the caught stack */
};

/*
 * The exception types.
 */
#define ET_USER         0       /* exception caused by ":throw" command */
#define ET_ERROR        1       /* error exception */
#define ET_INTERRUPT    2       /* interrupt exception triggered by Ctrl-C */

/*
 * Structure to save the error/interrupt/exception state between calls to
 * enter_cleanup() and leave_cleanup().  Must be allocated as an automatic
 * variable by the (common) caller of these functions.
 */
typedef struct cleanup_stuff cleanup_T;
struct cleanup_stuff {
  int pending;                  /* error/interrupt/exception state */
  except_T *exception;          /* exception value */
};

/* struct passed to in_id_list() */
struct sp_syn {
  int inc_tag;                  /* ":syn include" unique tag */
  short id;                     /* highlight group ID of item */
  short       *cont_in_list;    /* cont.in group IDs, if non-zero */
};

/*
 * Each keyword has one keyentry, which is linked in a hash list.
 */
typedef struct keyentry keyentry_T;

struct keyentry {
  keyentry_T  *ke_next;         /* next entry with identical "keyword[]" */
  struct sp_syn k_syn;          /* struct passed to in_id_list() */
  short       *next_list;       /* ID list for next match (if non-zero) */
  int flags;
  int k_char;                   /* conceal substitute character */
  char_u keyword[1];            /* actually longer */
};

/*
 * Struct used to store one state of the state stack.
 */
typedef struct buf_state {
  int bs_idx;                    /* index of pattern */
  int bs_flags;                  /* flags for pattern */
  int bs_seqnr;                  /* stores si_seqnr */
  int bs_cchar;                  /* stores si_cchar */
  reg_extmatch_T *bs_extmatch;   /* external matches from start pattern */
} bufstate_T;

/*
 * syn_state contains the syntax state stack for the start of one line.
 * Used by b_sst_array[].
 */
typedef struct syn_state synstate_T;

struct syn_state {
  synstate_T  *sst_next;        /* next entry in used or free list */
  linenr_T sst_lnum;            /* line number for this state */
  union {
    bufstate_T sst_stack[SST_FIX_STATES];          /* short state stack */
    garray_T sst_ga;            /* growarray for long state stack */
  } sst_union;
  int sst_next_flags;           /* flags for sst_next_list */
  int sst_stacksize;            /* number of states on the stack */
  short       *sst_next_list;   /* "nextgroup" list in this state
                                 * (this is a copy, don't free it! */
  disptick_T sst_tick;          /* tick when last displayed */
  linenr_T sst_change_lnum;     /* when non-zero, change in this line
                                 * may have made the state invalid */
};

/*
 * Structure shared between syntax.c, screen.c and gui_x11.c.
 */
typedef struct attr_entry {
  short ae_attr;                        /* HL_BOLD, etc. */
  union {
    struct {
      char_u          *start;           /* start escape sequence */
      char_u          *stop;            /* stop escape sequence */
    } term;
    struct {
      /* These colors need to be > 8 bits to hold 256. */
      short_u fg_color;                 /* foreground color number */
      short_u bg_color;                 /* background color number */
    } cterm;
  } ae_u;
} attrentry_T;

#ifdef USE_ICONV
# ifdef HAVE_ICONV_H
#  include <iconv.h>
# else
#    include <errno.h>
typedef void *iconv_t;
# endif
#endif

/*
 * Used for the typeahead buffer: typebuf.
 */
typedef struct {
  char_u      *tb_buf;          /* buffer for typed characters */
  char_u      *tb_noremap;      /* mapping flags for characters in tb_buf[] */
  int tb_buflen;                /* size of tb_buf[] */
  int tb_off;                   /* current position in tb_buf[] */
  int tb_len;                   /* number of valid bytes in tb_buf[] */
  int tb_maplen;                /* nr of mapped bytes in tb_buf[] */
  int tb_silent;                /* nr of silently mapped bytes in tb_buf[] */
  int tb_no_abbr_cnt;           /* nr of bytes without abbrev. in tb_buf[] */
  int tb_change_cnt;            /* nr of time tb_buf was changed; never zero */
} typebuf_T;

/* Struct to hold the saved typeahead for save_typeahead(). */
typedef struct {
  typebuf_T save_typebuf;
  int typebuf_valid;                        /* TRUE when save_typebuf valid */
  int old_char;
  int old_mod_mask;
  struct buffheader save_stuffbuff;
#ifdef USE_INPUT_BUF
  char_u              *save_inputbuf;
#endif
} tasave_T;

/*
 * Used for conversion of terminal I/O and script files.
 */
typedef struct {
  int vc_type;                  /* zero or one of the CONV_ values */
  int vc_factor;                /* max. expansion factor */
# ifdef USE_ICONV
  iconv_t vc_fd;                /* for CONV_ICONV */
# endif
  int vc_fail;                  /* fail for invalid char, don't use '?' */
} vimconv_T;

/*
 * Structure used for reading from the viminfo file.
 */
typedef struct {
  char_u      *vir_line;        /* text of the current line */
  FILE        *vir_fd;          /* file descriptor */
  vimconv_T vir_conv;           /* encoding conversion */
} vir_T;

#define CONV_NONE               0
#define CONV_TO_UTF8            1
#define CONV_9_TO_UTF8          2
#define CONV_TO_LATIN1          3
#define CONV_TO_LATIN9          4
#define CONV_ICONV              5

/*
 * Structure used for mappings and abbreviations.
 */
typedef struct mapblock mapblock_T;
struct mapblock {
  mapblock_T  *m_next;          /* next mapblock in list */
  char_u      *m_keys;          /* mapped from, lhs */
  char_u      *m_str;           /* mapped to, rhs */
  char_u      *m_orig_str;      /* rhs as entered by the user */
  int m_keylen;                 /* strlen(m_keys) */
  int m_mode;                   /* valid mode */
  int m_noremap;                /* if non-zero no re-mapping for m_str */
  char m_silent;                /* <silent> used, don't echo commands */
  char m_nowait;                /* <nowait> used */
  char m_expr;                  /* <expr> used, m_str is an expression */
  scid_T m_script_ID;           /* ID of script where map was defined */
};

/*
 * Used for highlighting in the status line.
 */
struct stl_hlrec {
  char_u      *start;
  int userhl;                   /* 0: no HL, 1-9: User HL, < 0 for syn ID */
};


/*
 * Syntax items - usually buffer-specific.
 */

/* Item for a hashtable.  "hi_key" can be one of three values:
 * NULL:	   Never been used
 * HI_KEY_REMOVED: Entry was removed
 * Otherwise:	   Used item, pointer to the actual key; this usually is
 *		   inside the item, subtract an offset to locate the item.
 *		   This reduces the size of hashitem by 1/3.
 */
typedef struct hashitem_S {
  long_u hi_hash;               /* cached hash number of hi_key */
  char_u      *hi_key;
} hashitem_T;

/* The address of "hash_removed" is used as a magic number for hi_key to
 * indicate a removed item. */
#define HI_KEY_REMOVED &hash_removed
#define HASHITEM_EMPTY(hi) ((hi)->hi_key == NULL || (hi)->hi_key == \
                            &hash_removed)

/* Initial size for a hashtable.  Our items are relatively small and growing
 * is expensive, thus use 16 as a start.  Must be a power of 2. */
#define HT_INIT_SIZE 16

typedef struct hashtable_S {
  long_u ht_mask;               /* mask used for hash value (nr of items in
                                 * array is "ht_mask" + 1) */
  long_u ht_used;               /* number of items used */
  long_u ht_filled;             /* number of items used + removed */
  int ht_locked;                /* counter for hash_lock() */
  int ht_error;                 /* when set growing failed, can't add more
                                   items before growing works */
  hashitem_T  *ht_array;        /* points to the array, allocated when it's
                                   not "ht_smallarray" */
  hashitem_T ht_smallarray[HT_INIT_SIZE];      /* initial array */
} hashtab_T;

typedef long_u hash_T;          /* Type for hi_hash */


#if SIZEOF_INT <= 3             /* use long if int is smaller than 32 bits */
typedef long varnumber_T;
#else
typedef int varnumber_T;
#endif
typedef double float_T;

typedef struct listvar_S list_T;
typedef struct dictvar_S dict_T;

/*
 * Structure to hold an internal variable without a name.
 */
typedef struct {
  char v_type;              /* see below: VAR_NUMBER, VAR_STRING, etc. */
  char v_lock;              /* see below: VAR_LOCKED, VAR_FIXED */
  union {
    varnumber_T v_number;               /* number value */
    float_T v_float;                    /* floating number value */
    char_u          *v_string;          /* string value (can be NULL!) */
    list_T          *v_list;            /* list value (can be NULL!) */
    dict_T          *v_dict;            /* dict value (can be NULL!) */
  }           vval;
} typval_T;

/* Values for "v_type". */
#define VAR_UNKNOWN 0
#define VAR_NUMBER  1   /* "v_number" is used */
#define VAR_STRING  2   /* "v_string" is used */
#define VAR_FUNC    3   /* "v_string" is function name */
#define VAR_LIST    4   /* "v_list" is used */
#define VAR_DICT    5   /* "v_dict" is used */
#define VAR_FLOAT   6   /* "v_float" is used */

/* Values for "dv_scope". */
#define VAR_SCOPE     1 /* a:, v:, s:, etc. scope dictionaries */
#define VAR_DEF_SCOPE 2 /* l:, g: scope dictionaries: here funcrefs are not
                           allowed to mask existing functions */

/* Values for "v_lock". */
#define VAR_LOCKED  1   /* locked with lock(), can use unlock() */
#define VAR_FIXED   2   /* locked forever */

/*
 * Structure to hold an item of a list: an internal variable without a name.
 */
typedef struct listitem_S listitem_T;

struct listitem_S {
  listitem_T  *li_next;         /* next item in list */
  listitem_T  *li_prev;         /* previous item in list */
  typval_T li_tv;               /* type and value of the variable */
};

/*
 * Struct used by those that are using an item in a list.
 */
typedef struct listwatch_S listwatch_T;

struct listwatch_S {
  listitem_T          *lw_item;         /* item being watched */
  listwatch_T         *lw_next;         /* next watcher */
};

/*
 * Structure to hold info about a list.
 */
struct listvar_S {
  listitem_T  *lv_first;        /* first item, NULL if none */
  listitem_T  *lv_last;         /* last item, NULL if none */
  int lv_refcount;              /* reference count */
  int lv_len;                   /* number of items */
  listwatch_T *lv_watch;        /* first watcher, NULL if none */
  int lv_idx;                   /* cached index of an item */
  listitem_T  *lv_idx_item;     /* when not NULL item at index "lv_idx" */
  int lv_copyID;                /* ID used by deepcopy() */
  list_T      *lv_copylist;     /* copied list used by deepcopy() */
  char lv_lock;                 /* zero, VAR_LOCKED, VAR_FIXED */
  list_T      *lv_used_next;    /* next list in used lists list */
  list_T      *lv_used_prev;    /* previous list in used lists list */
};

/*
 * Structure to hold an item of a Dictionary.
 * Also used for a variable.
 * The key is copied into "di_key" to avoid an extra alloc/free for it.
 */
struct dictitem_S {
  typval_T di_tv;               /* type and value of the variable */
  char_u di_flags;              /* flags (only used for variable) */
  char_u di_key[1];             /* key (actually longer!) */
};

typedef struct dictitem_S dictitem_T;

#define DI_FLAGS_RO     1 /* "di_flags" value: read-only variable */
#define DI_FLAGS_RO_SBX 2 /* "di_flags" value: read-only in the sandbox */
#define DI_FLAGS_FIX    4 /* "di_flags" value: fixed variable, not allocated */
#define DI_FLAGS_LOCK   8 /* "di_flags" value: locked variable */

/*
 * Structure to hold info about a Dictionary.
 */
struct dictvar_S {
  char dv_lock;                 /* zero, VAR_LOCKED, VAR_FIXED */
  char dv_scope;                /* zero, VAR_SCOPE, VAR_DEF_SCOPE */
  int dv_refcount;              /* reference count */
  int dv_copyID;                /* ID used by deepcopy() */
  hashtab_T dv_hashtab;         /* hashtab that refers to the items */
  dict_T      *dv_copydict;     /* copied dict used by deepcopy() */
  dict_T      *dv_used_next;    /* next dict in used dicts list */
  dict_T      *dv_used_prev;    /* previous dict in used dicts list */
};

/* values for b_syn_spell: what to do with toplevel text */
#define SYNSPL_DEFAULT  0       /* spell check if @Spell not defined */
#define SYNSPL_TOP      1       /* spell check toplevel text */
#define SYNSPL_NOTOP    2       /* don't spell check toplevel text */

/* avoid #ifdefs for when b_spell is not available */
# define B_SPELL(buf)  ((buf)->b_spell)

typedef struct qf_info_S qf_info_T;

/*
 * Used for :syntime: timing of executing a syntax pattern.
 */
typedef struct {
  proftime_T total;             /* total time used */
  proftime_T slowest;           /* time of slowest call */
  long count;                   /* nr of times used */
  long match;                   /* nr of times matched */
} syn_time_T;

/*
 * These are items normally related to a buffer.  But when using ":ownsyntax"
 * a window may have its own instance.
 */
typedef struct {
  hashtab_T b_keywtab;                  /* syntax keywords hash table */
  hashtab_T b_keywtab_ic;               /* idem, ignore case */
  int b_syn_error;                      /* TRUE when error occurred in HL */
  int b_syn_ic;                         /* ignore case for :syn cmds */
  int b_syn_spell;                      /* SYNSPL_ values */
  garray_T b_syn_patterns;              /* table for syntax patterns */
  garray_T b_syn_clusters;              /* table for syntax clusters */
  int b_spell_cluster_id;               /* @Spell cluster ID or 0 */
  int b_nospell_cluster_id;             /* @NoSpell cluster ID or 0 */
  int b_syn_containedin;                /* TRUE when there is an item with a
                                           "containedin" argument */
  int b_syn_sync_flags;                 /* flags about how to sync */
  short b_syn_sync_id;                  /* group to sync on */
  long b_syn_sync_minlines;             /* minimal sync lines offset */
  long b_syn_sync_maxlines;             /* maximal sync lines offset */
  long b_syn_sync_linebreaks;           /* offset for multi-line pattern */
  char_u      *b_syn_linecont_pat;      /* line continuation pattern */
  regprog_T   *b_syn_linecont_prog;     /* line continuation program */
  syn_time_T b_syn_linecont_time;
  int b_syn_linecont_ic;                /* ignore-case flag for above */
  int b_syn_topgrp;                     /* for ":syntax include" */
  int b_syn_conceal;                    /* auto-conceal for :syn cmds */
  int b_syn_folditems;                  /* number of patterns with the HL_FOLD
                                           flag set */
  /*
   * b_sst_array[] contains the state stack for a number of lines, for the
   * start of that line (col == 0).  This avoids having to recompute the
   * syntax state too often.
   * b_sst_array[] is allocated to hold the state for all displayed lines,
   * and states for 1 out of about 20 other lines.
   * b_sst_array	pointer to an array of synstate_T
   * b_sst_len	number of entries in b_sst_array[]
   * b_sst_first	pointer to first used entry in b_sst_array[] or NULL
   * b_sst_firstfree	pointer to first free entry in b_sst_array[] or NULL
   * b_sst_freecount	number of free entries in b_sst_array[]
   * b_sst_check_lnum	entries after this lnum need to be checked for
   *			validity (MAXLNUM means no check needed)
   */
  synstate_T  *b_sst_array;
  int b_sst_len;
  synstate_T  *b_sst_first;
  synstate_T  *b_sst_firstfree;
  int b_sst_freecount;
  linenr_T b_sst_check_lnum;
  short_u b_sst_lasttick;       /* last display tick */

  /* for spell checking */
  garray_T b_langp;             /* list of pointers to slang_T, see spell.c */
  char_u b_spell_ismw[256];       /* flags: is midword char */
  char_u      *b_spell_ismw_mb;   /* multi-byte midword chars */
  char_u      *b_p_spc;         /* 'spellcapcheck' */
  regprog_T   *b_cap_prog;      /* program for 'spellcapcheck' */
  char_u      *b_p_spf;         /* 'spellfile' */
  char_u      *b_p_spl;         /* 'spelllang' */
  int b_cjk;                    /* all CJK letters as OK */
} synblock_T;


/*
 * buffer: structure that holds information about one file
 *
 * Several windows can share a single Buffer
 * A buffer is unallocated if there is no memfile for it.
 * A buffer is new if the associated file has never been loaded yet.
 */

struct file_buffer {
  memline_T b_ml;               /* associated memline (also contains line
                                   count) */

  buf_T       *b_next;          /* links in list of buffers */
  buf_T       *b_prev;

  int b_nwindows;               /* nr of windows open on this buffer */

  int b_flags;                  /* various BF_ flags */
  int b_closing;                /* buffer is being closed, don't let
                                   autocommands close it too. */

  /*
   * b_ffname has the full path of the file (NULL for no name).
   * b_sfname is the name as the user typed it (or NULL).
   * b_fname is the same as b_sfname, unless ":cd" has been done,
   *		then it is the same as b_ffname (NULL for no name).
   */
  char_u      *b_ffname;        /* full path file name */
  char_u      *b_sfname;        /* short file name */
  char_u      *b_fname;         /* current file name */

#ifdef UNIX
  int b_dev_valid;              /* TRUE when b_dev has a valid number */
  dev_t b_dev;                  /* device number */
  ino_t b_ino;                  /* inode number */
#endif

  int b_fnum;                   /* buffer number for this file. */

  int b_changed;                /* 'modified': Set to TRUE if something in the
                                   file has been changed and not written out. */
  int b_changedtick;            /* incremented for each change, also for undo */

  int b_saving;                 /* Set to TRUE if we are in the middle of
                                   saving the buffer. */

  /*
   * Changes to a buffer require updating of the display.  To minimize the
   * work, remember changes made and update everything at once.
   */
  int b_mod_set;                /* TRUE when there are changes since the last
                                   time the display was updated */
  linenr_T b_mod_top;           /* topmost lnum that was changed */
  linenr_T b_mod_bot;           /* lnum below last changed line, AFTER the
                                   change */
  long b_mod_xlines;            /* number of extra buffer lines inserted;
                                   negative when lines were deleted */

  wininfo_T   *b_wininfo;       /* list of last used info for each window */

  long b_mtime;                 /* last change time of original file */
  long b_mtime_read;            /* last change time when reading */
  off_t b_orig_size;            /* size of original file in bytes */
  int b_orig_mode;              /* mode of original file */

  pos_T b_namedm[NMARKS];         /* current named marks (mark.c) */

  /* These variables are set when VIsual_active becomes FALSE */
  visualinfo_T b_visual;
  int b_visual_mode_eval;            /* b_visual.vi_mode for visualmode() */

  pos_T b_last_cursor;          /* cursor position when last unloading this
                                   buffer */
  pos_T b_last_insert;          /* where Insert mode was left */
  pos_T b_last_change;          /* position of last change: '. mark */

  /*
   * the changelist contains old change positions
   */
  pos_T b_changelist[JUMPLISTSIZE];
  int b_changelistlen;                  /* number of active entries */
  int b_new_change;                     /* set by u_savecommon() */

  /*
   * Character table, only used in charset.c for 'iskeyword'
   * 32 bytes of 8 bits: 1 bit per character 0-255.
   */
  char_u b_chartab[32];

  /* Table used for mappings local to a buffer. */
  mapblock_T  *(b_maphash[256]);

  /* First abbreviation local to a buffer. */
  mapblock_T  *b_first_abbr;
  /* User commands local to the buffer. */
  garray_T b_ucmds;
  /*
   * start and end of an operator, also used for '[ and ']
   */
  pos_T b_op_start;
  pos_T b_op_end;

  int b_marks_read;             /* Have we read viminfo marks yet? */

  /*
   * The following only used in undo.c.
   */
  u_header_T  *b_u_oldhead;     /* pointer to oldest header */
  u_header_T  *b_u_newhead;     /* pointer to newest header; may not be valid
                                   if b_u_curhead is not NULL */
  u_header_T  *b_u_curhead;     /* pointer to current header */
  int b_u_numhead;              /* current number of headers */
  int b_u_synced;               /* entry lists are synced */
  long b_u_seq_last;            /* last used undo sequence number */
  long b_u_save_nr_last;          /* counter for last file write */
  long b_u_seq_cur;             /* hu_seq of header below which we are now */
  time_t b_u_time_cur;          /* uh_time of header below which we are now */
  long b_u_save_nr_cur;          /* file write nr after which we are now */

  /*
   * variables for "U" command in undo.c
   */
  char_u      *b_u_line_ptr;    /* saved line for "U" command */
  linenr_T b_u_line_lnum;       /* line number of line in u_line */
  colnr_T b_u_line_colnr;       /* optional column number */

  int b_scanned;                /* ^N/^P have scanned this buffer */

  /* flags for use of ":lmap" and IM control */
  long b_p_iminsert;            /* input mode for insert */
  long b_p_imsearch;            /* input mode for search */
#define B_IMODE_USE_INSERT -1   /*	Use b_p_iminsert value for search */
#define B_IMODE_NONE 0          /*	Input via none */
#define B_IMODE_LMAP 1          /*	Input via langmap */
#ifndef USE_IM_CONTROL
# define B_IMODE_LAST 1
#else
# define B_IMODE_IM 2           /*	Input via input method */
# define B_IMODE_LAST 2
#endif

  short b_kmap_state;           /* using "lmap" mappings */
# define KEYMAP_INIT    1       /* 'keymap' was set, call keymap_init() */
# define KEYMAP_LOADED  2       /* 'keymap' mappings have been loaded */
  garray_T b_kmap_ga;           /* the keymap table */

  /*
   * Options local to a buffer.
   * They are here because their value depends on the type of file
   * or contents of the file being edited.
   */
  int b_p_initialized;                  /* set when options initialized */

  int b_p_scriptID[BV_COUNT];           /* SIDs for buffer-local options */

  int b_p_ai;                   /* 'autoindent' */
  int b_p_ai_nopaste;           /* b_p_ai saved for paste mode */
  int b_p_ci;                   /* 'copyindent' */
  int b_p_bin;                  /* 'binary' */
  int b_p_bomb;                 /* 'bomb' */
  char_u      *b_p_bh;          /* 'bufhidden' */
  char_u      *b_p_bt;          /* 'buftype' */
  int b_p_bl;                   /* 'buflisted' */
  int b_p_cin;                  /* 'cindent' */
  char_u      *b_p_cino;        /* 'cinoptions' */
  char_u      *b_p_cink;        /* 'cinkeys' */
  char_u      *b_p_cinw;        /* 'cinwords' */
  char_u      *b_p_com;         /* 'comments' */
  char_u      *b_p_cms;         /* 'commentstring' */
  char_u      *b_p_cpt;         /* 'complete' */
  char_u      *b_p_cfu;         /* 'completefunc' */
  char_u      *b_p_ofu;         /* 'omnifunc' */
  int b_p_eol;                  /* 'endofline' */
  int b_p_et;                   /* 'expandtab' */
  int b_p_et_nobin;             /* b_p_et saved for binary mode */
  char_u      *b_p_fenc;        /* 'fileencoding' */
  char_u      *b_p_ff;          /* 'fileformat' */
  char_u      *b_p_ft;          /* 'filetype' */
  char_u      *b_p_fo;          /* 'formatoptions' */
  char_u      *b_p_flp;         /* 'formatlistpat' */
  int b_p_inf;                  /* 'infercase' */
  char_u      *b_p_isk;         /* 'iskeyword' */
  char_u      *b_p_def;         /* 'define' local value */
  char_u      *b_p_inc;         /* 'include' */
  char_u      *b_p_inex;        /* 'includeexpr' */
  long_u b_p_inex_flags;        /* flags for 'includeexpr' */
  char_u      *b_p_inde;        /* 'indentexpr' */
  long_u b_p_inde_flags;        /* flags for 'indentexpr' */
  char_u      *b_p_indk;        /* 'indentkeys' */
  char_u      *b_p_fex;         /* 'formatexpr' */
  long_u b_p_fex_flags;         /* flags for 'formatexpr' */
  char_u      *b_p_key;         /* 'key' */
  char_u      *b_p_kp;          /* 'keywordprg' */
  int b_p_lisp;                 /* 'lisp' */
  char_u      *b_p_mps;         /* 'matchpairs' */
  int b_p_ml;                   /* 'modeline' */
  int b_p_ml_nobin;             /* b_p_ml saved for binary mode */
  int b_p_ma;                   /* 'modifiable' */
  char_u      *b_p_nf;          /* 'nrformats' */
  int b_p_pi;                   /* 'preserveindent' */
  char_u      *b_p_qe;          /* 'quoteescape' */
  int b_p_ro;                   /* 'readonly' */
  long b_p_sw;                  /* 'shiftwidth' */
#ifndef SHORT_FNAME
  int b_p_sn;                   /* 'shortname' */
#endif
  int b_p_si;                   /* 'smartindent' */
  long b_p_sts;                 /* 'softtabstop' */
  long b_p_sts_nopaste;          /* b_p_sts saved for paste mode */
  char_u      *b_p_sua;         /* 'suffixesadd' */
  int b_p_swf;                  /* 'swapfile' */
  long b_p_smc;                 /* 'synmaxcol' */
  char_u      *b_p_syn;         /* 'syntax' */
  long b_p_ts;                  /* 'tabstop' */
  int b_p_tx;                   /* 'textmode' */
  long b_p_tw;                  /* 'textwidth' */
  long b_p_tw_nobin;            /* b_p_tw saved for binary mode */
  long b_p_tw_nopaste;          /* b_p_tw saved for paste mode */
  long b_p_wm;                  /* 'wrapmargin' */
  long b_p_wm_nobin;            /* b_p_wm saved for binary mode */
  long b_p_wm_nopaste;          /* b_p_wm saved for paste mode */
  char_u      *b_p_keymap;      /* 'keymap' */

  /* local values for options which are normally global */
  char_u      *b_p_gp;          /* 'grepprg' local value */
  char_u      *b_p_mp;          /* 'makeprg' local value */
  char_u      *b_p_efm;         /* 'errorformat' local value */
  char_u      *b_p_ep;          /* 'equalprg' local value */
  char_u      *b_p_path;        /* 'path' local value */
  int b_p_ar;                   /* 'autoread' local value */
  char_u      *b_p_tags;        /* 'tags' local value */
  char_u      *b_p_dict;        /* 'dictionary' local value */
  char_u      *b_p_tsr;         /* 'thesaurus' local value */
  long b_p_ul;                  /* 'undolevels' local value */
  int b_p_udf;                  /* 'undofile' */

  /* end of buffer options */

  /* values set from b_p_cino */
  int b_ind_level;
  int b_ind_open_imag;
  int b_ind_no_brace;
  int b_ind_first_open;
  int b_ind_open_extra;
  int b_ind_close_extra;
  int b_ind_open_left_imag;
  int b_ind_jump_label;
  int b_ind_case;
  int b_ind_case_code;
  int b_ind_case_break;
  int b_ind_param;
  int b_ind_func_type;
  int b_ind_comment;
  int b_ind_in_comment;
  int b_ind_in_comment2;
  int b_ind_cpp_baseclass;
  int b_ind_continuation;
  int b_ind_unclosed;
  int b_ind_unclosed2;
  int b_ind_unclosed_noignore;
  int b_ind_unclosed_wrapped;
  int b_ind_unclosed_whiteok;
  int b_ind_matching_paren;
  int b_ind_paren_prev;
  int b_ind_maxparen;
  int b_ind_maxcomment;
  int b_ind_scopedecl;
  int b_ind_scopedecl_code;
  int b_ind_java;
  int b_ind_js;
  int b_ind_keep_case_label;
  int b_ind_hash_comment;
  int b_ind_cpp_namespace;
  int b_ind_if_for_while;

  linenr_T b_no_eol_lnum;       /* non-zero lnum when last line of next binary
                                 * write should not have an end-of-line */

  int b_start_eol;              /* last line had eol when it was read */
  int b_start_ffc;              /* first char of 'ff' when edit started */
  char_u      *b_start_fenc;    /* 'fileencoding' when edit started or NULL */
  int b_bad_char;               /* "++bad=" argument when edit started or 0 */
  int b_start_bomb;             /* 'bomb' when it was read */

  dictitem_T b_bufvar;          /* variable for "b:" Dictionary */
  dict_T      *b_vars;          /* internal variables, local to buffer */

  char_u      *b_p_cm;          /* 'cryptmethod' */

  /* When a buffer is created, it starts without a swap file.  b_may_swap is
   * then set to indicate that a swap file may be opened later.  It is reset
   * if a swap file could not be opened.
   */
  int b_may_swap;
  int b_did_warn;               /* Set to 1 if user has been warned on first
                                   change of a read-only file */

  /* Two special kinds of buffers:
   * help buffer  - used for help files, won't use a swap file.
   * spell buffer - used for spell info, never displayed and doesn't have a
   *		      file name.
   */
  int b_help;                   /* TRUE for help file buffer (when set b_p_bt
                                   is "help") */
  int b_spell;                  /* TRUE for a spell file buffer, most fields
                                   are not used!  Use the B_SPELL macro to
                                   access b_spell without #ifdef. */

#ifndef SHORT_FNAME
  int b_shortname;              /* this file has an 8.3 file name */
#endif







  synblock_T b_s;               /* Info related to syntax highlighting.  w_s
                                 * normally points to this, but some windows
                                 * may use a different synblock_T. */



};


/*
 * Stuff for diff mode.
 */
# define DB_COUNT 4     /* up to four buffers can be diff'ed */

/*
 * Each diffblock defines where a block of lines starts in each of the buffers
 * and how many lines it occupies in that buffer.  When the lines are missing
 * in the buffer the df_count[] is zero.  This is all counted in
 * buffer lines.
 * There is always at least one unchanged line in between the diffs.
 * Otherwise it would have been included in the diff above or below it.
 * df_lnum[] + df_count[] is the lnum below the change.  When in one buffer
 * lines have been inserted, in the other buffer df_lnum[] is the line below
 * the insertion and df_count[] is zero.  When appending lines at the end of
 * the buffer, df_lnum[] is one beyond the end!
 * This is using a linked list, because the number of differences is expected
 * to be reasonable small.  The list is sorted on lnum.
 */
typedef struct diffblock_S diff_T;
struct diffblock_S {
  diff_T      *df_next;
  linenr_T df_lnum[DB_COUNT];           /* line number in buffer */
  linenr_T df_count[DB_COUNT];          /* nr of inserted/changed lines */
};

#define SNAP_HELP_IDX   0
# define SNAP_AUCMD_IDX 1
# define SNAP_COUNT     2

/*
 * Tab pages point to the top frame of each tab page.
 * Note: Most values are NOT valid for the current tab page!  Use "curwin",
 * "firstwin", etc. for that.  "tp_topframe" is always valid and can be
 * compared against "topframe" to find the current tab page.
 */
typedef struct tabpage_S tabpage_T;
struct tabpage_S {
  tabpage_T       *tp_next;         /* next tabpage or NULL */
  frame_T         *tp_topframe;     /* topframe for the windows */
  win_T           *tp_curwin;       /* current window in this Tab page */
  win_T           *tp_prevwin;      /* previous window in this Tab page */
  win_T           *tp_firstwin;     /* first window in this Tab page */
  win_T           *tp_lastwin;      /* last window in this Tab page */
  long tp_old_Rows;                 /* Rows when Tab page was left */
  long tp_old_Columns;              /* Columns when Tab page was left */
  long tp_ch_used;                  /* value of 'cmdheight' when frame size
                                       was set */
  diff_T          *tp_first_diff;
  buf_T           *(tp_diffbuf[DB_COUNT]);
  int tp_diff_invalid;                  /* list of diffs is outdated */
  frame_T         *(tp_snapshot[SNAP_COUNT]);    /* window layout snapshots */
  dictitem_T tp_winvar;             /* variable for "t:" Dictionary */
  dict_T          *tp_vars;         /* internal variables, local to tab page */


};

/*
 * Structure to cache info for displayed lines in w_lines[].
 * Each logical line has one entry.
 * The entry tells how the logical line is currently displayed in the window.
 * This is updated when displaying the window.
 * When the display is changed (e.g., when clearing the screen) w_lines_valid
 * is changed to exclude invalid entries.
 * When making changes to the buffer, wl_valid is reset to indicate wl_size
 * may not reflect what is actually in the buffer.  When wl_valid is FALSE,
 * the entries can only be used to count the number of displayed lines used.
 * wl_lnum and wl_lastlnum are invalid too.
 */
typedef struct w_line {
  linenr_T wl_lnum;             /* buffer line number for logical line */
  short_u wl_size;              /* height in screen lines */
  char wl_valid;                /* TRUE values are valid for text in buffer */
  char wl_folded;               /* TRUE when this is a range of folded lines */
  linenr_T wl_lastlnum;         /* last buffer line number for logical line */
} wline_T;

/*
 * Windows are kept in a tree of frames.  Each frame has a column (FR_COL)
 * or row (FR_ROW) layout or is a leaf, which has a window.
 */
struct frame_S {
  char fr_layout;               /* FR_LEAF, FR_COL or FR_ROW */
  int fr_width;
  int fr_newwidth;              /* new width used in win_equal_rec() */
  int fr_height;
  int fr_newheight;             /* new height used in win_equal_rec() */
  frame_T     *fr_parent;       /* containing frame or NULL */
  frame_T     *fr_next;         /* frame right or below in same parent, NULL
                                   for first */
  frame_T     *fr_prev;         /* frame left or above in same parent, NULL
                                   for last */
  /* fr_child and fr_win are mutually exclusive */
  frame_T     *fr_child;        /* first contained frame */
  win_T       *fr_win;          /* window that fills this frame */
};

#define FR_LEAF 0       /* frame is a leaf */
#define FR_ROW  1       /* frame with a row of windows */
#define FR_COL  2       /* frame with a column of windows */

/*
 * Struct used for highlighting 'hlsearch' matches, matches defined by
 * ":match" and matches defined by match functions.
 * For 'hlsearch' there is one pattern for all windows.  For ":match" and the
 * match functions there is a different pattern for each window.
 */
typedef struct {
  regmmatch_T rm;       /* points to the regexp program; contains last found
                           match (may continue in next line) */
  buf_T       *buf;     /* the buffer to search for a match */
  linenr_T lnum;        /* the line to search for a match */
  int attr;             /* attributes to be used for a match */
  int attr_cur;           /* attributes currently active in win_line() */
  linenr_T first_lnum;          /* first lnum to search for multi-line pat */
  colnr_T startcol;       /* in win_line() points to char where HL starts */
  colnr_T endcol;        /* in win_line() points to char where HL ends */
  proftime_T tm;        /* for a time limit */
} match_T;

/*
 * matchitem_T provides a linked list for storing match items for ":match" and
 * the match functions.
 */
typedef struct matchitem matchitem_T;
struct matchitem {
  matchitem_T *next;
  int id;                   /* match ID */
  int priority;             /* match priority */
  char_u      *pattern;     /* pattern to highlight */
  int hlg_id;               /* highlight group ID */
  regmmatch_T match;        /* regexp program for pattern */
  match_T hl;               /* struct for doing the actual highlighting */
};

/*
 * Structure which contains all information that belongs to a window
 *
 * All row numbers are relative to the start of the window, except w_winrow.
 */
struct window_S {
  buf_T       *w_buffer;            /* buffer we are a window into (used
                                       often, keep it the first item!) */

  synblock_T  *w_s;                 /* for :ownsyntax */

  win_T       *w_prev;              /* link to previous window */
  win_T       *w_next;              /* link to next window */
  int w_closing;                    /* window is being closed, don't let
                                       autocommands close it too. */

  frame_T     *w_frame;             /* frame containing this window */

  pos_T w_cursor;                   /* cursor position in buffer */

  colnr_T w_curswant;               /* The column we'd like to be at.  This is
                                       used to try to stay in the same column
                                       for up/down cursor motions. */

  int w_set_curswant;               /* If set, then update w_curswant the next
                                       time through cursupdate() to the
                                       current virtual column */

  /*
   * the next six are used to update the visual part
   */
  char w_old_visual_mode;           /* last known VIsual_mode */
  linenr_T w_old_cursor_lnum;       /* last known end of visual part */
  colnr_T w_old_cursor_fcol;        /* first column for block visual part */
  colnr_T w_old_cursor_lcol;        /* last column for block visual part */
  linenr_T w_old_visual_lnum;       /* last known start of visual part */
  colnr_T w_old_visual_col;         /* last known start of visual part */
  colnr_T w_old_curswant;           /* last known value of Curswant */

  /*
   * "w_topline", "w_leftcol" and "w_skipcol" specify the offsets for
   * displaying the buffer.
   */
  linenr_T w_topline;               /* buffer line number of the line at the
                                       top of the window */
  char w_topline_was_set;           /* flag set to TRUE when topline is set,
                                       e.g. by winrestview() */
  int w_topfill;                    /* number of filler lines above w_topline */
  int w_old_topfill;                /* w_topfill at last redraw */
  int w_botfill;                    /* TRUE when filler lines are actually
                                       below w_topline (at end of file) */
  int w_old_botfill;                /* w_botfill at last redraw */
  colnr_T w_leftcol;                /* window column number of the left most
                                       character in the window; used when
                                       'wrap' is off */
  colnr_T w_skipcol;                /* starting column when a single line
                                       doesn't fit in the window */

  /*
   * Layout of the window in the screen.
   * May need to add "msg_scrolled" to "w_winrow" in rare situations.
   */
  int w_winrow;                     /* first row of window in screen */
  int w_height;                     /* number of rows in window, excluding
                                       status/command line(s) */
  int w_status_height;              /* number of status lines (0 or 1) */
  int w_wincol;                     /* Leftmost column of window in screen.
                                       use W_WINCOL() */
  int w_width;                      /* Width of window, excluding separation.
                                       use W_WIDTH() */
  int w_vsep_width;                 /* Number of separator columns (0 or 1).
                                       use W_VSEP_WIDTH() */

  /*
   * === start of cached values ====
   */
  /*
   * Recomputing is minimized by storing the result of computations.
   * Use functions in screen.c to check if they are valid and to update.
   * w_valid is a bitfield of flags, which indicate if specific values are
   * valid or need to be recomputed.	See screen.c for values.
   */
  int w_valid;
  pos_T w_valid_cursor;             /* last known position of w_cursor, used
                                       to adjust w_valid */
  colnr_T w_valid_leftcol;          /* last known w_leftcol */

  /*
   * w_cline_height is the number of physical lines taken by the buffer line
   * that the cursor is on.  We use this to avoid extra calls to plines().
   */
  int w_cline_height;               /* current size of cursor line */
  int w_cline_folded;               /* cursor line is folded */

  int w_cline_row;                  /* starting row of the cursor line */

  colnr_T w_virtcol;                /* column number of the cursor in the
                                       buffer line, as opposed to the column
                                       number we're at on the screen.  This
                                       makes a difference on lines which span
                                       more than one screen line or when
                                       w_leftcol is non-zero */

  /*
   * w_wrow and w_wcol specify the cursor position in the window.
   * This is related to positions in the window, not in the display or
   * buffer, thus w_wrow is relative to w_winrow.
   */
  int w_wrow, w_wcol;               /* cursor position in window */

  linenr_T w_botline;               /* number of the line below the bottom of
                                       the screen */
  int w_empty_rows;                 /* number of ~ rows in window */
  int w_filler_rows;                /* number of filler rows at the end of the
                                       window */

  /*
   * Info about the lines currently in the window is remembered to avoid
   * recomputing it every time.  The allocated size of w_lines[] is Rows.
   * Only the w_lines_valid entries are actually valid.
   * When the display is up-to-date w_lines[0].wl_lnum is equal to w_topline
   * and w_lines[w_lines_valid - 1].wl_lnum is equal to w_botline.
   * Between changing text and updating the display w_lines[] represents
   * what is currently displayed.  wl_valid is reset to indicated this.
   * This is used for efficient redrawing.
   */
  int w_lines_valid;                /* number of valid entries */
  wline_T     *w_lines;

  garray_T w_folds;                 /* array of nested folds */
  char w_fold_manual;               /* when TRUE: some folds are opened/closed
                                       manually */
  char w_foldinvalid;               /* when TRUE: folding needs to be
                                       recomputed */
  int w_nrwidth;                    /* width of 'number' and 'relativenumber'
                                       column being used */

  /*
   * === end of cached values ===
   */

  int w_redr_type;                  /* type of redraw to be performed on win */
  int w_upd_rows;                   /* number of window lines to update when
                                       w_redr_type is REDRAW_TOP */
  linenr_T w_redraw_top;            /* when != 0: first line needing redraw */
  linenr_T w_redraw_bot;            /* when != 0: last line needing redraw */
  int w_redr_status;                /* if TRUE status line must be redrawn */

  /* remember what is shown in the ruler for this window (if 'ruler' set) */
  pos_T w_ru_cursor;                /* cursor position shown in ruler */
  colnr_T w_ru_virtcol;             /* virtcol shown in ruler */
  linenr_T w_ru_topline;            /* topline shown in ruler */
  linenr_T w_ru_line_count;         /* line count used for ruler */
  int w_ru_topfill;                 /* topfill shown in ruler */
  char w_ru_empty;                  /* TRUE if ruler shows 0-1 (empty line) */

  int w_alt_fnum;                   /* alternate file (for # and CTRL-^) */

  alist_T     *w_alist;             /* pointer to arglist for this window */
  int w_arg_idx;                    /* current index in argument list (can be
                                       out of range!) */
  int w_arg_idx_invalid;            /* editing another file than w_arg_idx */

  char_u      *w_localdir;          /* absolute path of local directory or
                                       NULL */
  /*
   * Options local to a window.
   * They are local because they influence the layout of the window or
   * depend on the window layout.
   * There are two values: w_onebuf_opt is local to the buffer currently in
   * this window, w_allbuf_opt is for all buffers in this window.
   */
  winopt_T w_onebuf_opt;
  winopt_T w_allbuf_opt;

  /* A few options have local flags for P_INSECURE. */
  long_u w_p_stl_flags;             /* flags for 'statusline' */
  long_u w_p_fde_flags;             /* flags for 'foldexpr' */
  long_u w_p_fdt_flags;             /* flags for 'foldtext' */
  int         *w_p_cc_cols;         /* array of columns to highlight or NULL */

  /* transform a pointer to a "onebuf" option into a "allbuf" option */
#define GLOBAL_WO(p)    ((char *)p + sizeof(winopt_T))

  long w_scbind_pos;

  dictitem_T w_winvar;          /* variable for "w:" Dictionary */
  dict_T      *w_vars;          /* internal variables, local to window */

  int w_farsi;                  /* for the window dependent Farsi functions */

  /*
   * The w_prev_pcmark field is used to check whether we really did jump to
   * a new line after setting the w_pcmark.  If not, then we revert to
   * using the previous w_pcmark.
   */
  pos_T w_pcmark;               /* previous context mark */
  pos_T w_prev_pcmark;          /* previous w_pcmark */

  /*
   * the jumplist contains old cursor positions
   */
  xfmark_T w_jumplist[JUMPLISTSIZE];
  int w_jumplistlen;                    /* number of active entries */
  int w_jumplistidx;                    /* current position */

  int w_changelistidx;                  /* current position in b_changelist */

  matchitem_T *w_match_head;            /* head of match list */
  int w_next_match_id;                  /* next match ID */

  /*
   * the tagstack grows from 0 upwards:
   * entry 0: older
   * entry 1: newer
   * entry 2: newest
   */
  taggy_T w_tagstack[TAGSTACKSIZE];             /* the tag stack */
  int w_tagstackidx;                    /* idx just below active entry */
  int w_tagstacklen;                    /* number of tags on stack */

  /*
   * w_fraction is the fractional row of the cursor within the window, from
   * 0 at the top row to FRACTION_MULT at the last row.
   * w_prev_fraction_row was the actual cursor row when w_fraction was last
   * calculated.
   */
  int w_fraction;
  int w_prev_fraction_row;

  linenr_T w_nrwidth_line_count;        /* line count when ml_nrwidth_width
                                         * was computed. */
  int w_nrwidth_width;                  /* nr of chars to print line count. */

  qf_info_T   *w_llist;                 /* Location list for this window */
  /*
   * Location list reference used in the location list window.
   * In a non-location list window, w_llist_ref is NULL.
   */
  qf_info_T   *w_llist_ref;







};

/*
 * Arguments for operators.
 */
typedef struct oparg_S {
  int op_type;                  /* current pending operator type */
  int regname;                  /* register to use for the operator */
  int motion_type;              /* type of the current cursor motion */
  int motion_force;             /* force motion type: 'v', 'V' or CTRL-V */
  int use_reg_one;              /* TRUE if delete uses reg 1 even when not
                                   linewise */
  int inclusive;                /* TRUE if char motion is inclusive (only
                                   valid when motion_type is MCHAR */
  int end_adjusted;             /* backuped b_op_end one char (only used by
                                   do_format()) */
  pos_T start;                  /* start of the operator */
  pos_T end;                    /* end of the operator */
  pos_T cursor_start;           /* cursor position before motion for "gw" */

  long line_count;              /* number of lines from op_start to op_end
                                   (inclusive) */
  int empty;                    /* op_start and op_end the same (only used by
                                   do_change()) */
  int is_VIsual;                /* operator on Visual area */
  int block_mode;               /* current operator is Visual block mode */
  colnr_T start_vcol;           /* start col for block mode operator */
  colnr_T end_vcol;             /* end col for block mode operator */
  long prev_opcount;            /* ca.opcount saved for K_CURSORHOLD */
  long prev_count0;             /* ca.count0 saved for K_CURSORHOLD */
} oparg_T;

/*
 * Arguments for Normal mode commands.
 */
typedef struct cmdarg_S {
  oparg_T     *oap;             /* Operator arguments */
  int prechar;                  /* prefix character (optional, always 'g') */
  int cmdchar;                  /* command character */
  int nchar;                    /* next command character (optional) */
  int ncharC1;                  /* first composing character (optional) */
  int ncharC2;                  /* second composing character (optional) */
  int extra_char;               /* yet another character (optional) */
  long opcount;                 /* count before an operator */
  long count0;                  /* count before command, default 0 */
  long count1;                  /* count before command, default 1 */
  int arg;                      /* extra argument from nv_cmds[] */
  int retval;                   /* return: CA_* values */
  char_u      *searchbuf;       /* return: pointer to search pattern or NULL */
} cmdarg_T;

/* values for retval: */
#define CA_COMMAND_BUSY     1   /* skip restarting edit() once */
#define CA_NO_ADJ_OP_END    2   /* don't adjust operator end */

#ifdef CURSOR_SHAPE
/*
 * struct to store values from 'guicursor' and 'mouseshape'
 */
/* Indexes in shape_table[] */
#define SHAPE_IDX_N     0       /* Normal mode */
#define SHAPE_IDX_V     1       /* Visual mode */
#define SHAPE_IDX_I     2       /* Insert mode */
#define SHAPE_IDX_R     3       /* Replace mode */
#define SHAPE_IDX_C     4       /* Command line Normal mode */
#define SHAPE_IDX_CI    5       /* Command line Insert mode */
#define SHAPE_IDX_CR    6       /* Command line Replace mode */
#define SHAPE_IDX_O     7       /* Operator-pending mode */
#define SHAPE_IDX_VE    8       /* Visual mode with 'selection' exclusive */
#define SHAPE_IDX_CLINE 9       /* On command line */
#define SHAPE_IDX_STATUS 10     /* A status line */
#define SHAPE_IDX_SDRAG 11      /* dragging a status line */
#define SHAPE_IDX_VSEP  12      /* A vertical separator line */
#define SHAPE_IDX_VDRAG 13      /* dragging a vertical separator line */
#define SHAPE_IDX_MORE  14      /* Hit-return or More */
#define SHAPE_IDX_MOREL 15      /* Hit-return or More in last line */
#define SHAPE_IDX_SM    16      /* showing matching paren */
#define SHAPE_IDX_COUNT 17

#define SHAPE_BLOCK     0       /* block cursor */
#define SHAPE_HOR       1       /* horizontal bar cursor */
#define SHAPE_VER       2       /* vertical bar cursor */

#define MSHAPE_NUMBERED 1000    /* offset for shapes identified by number */
#define MSHAPE_HIDE     1       /* hide mouse pointer */

#define SHAPE_MOUSE     1       /* used for mouse pointer shape */
#define SHAPE_CURSOR    2       /* used for text cursor shape */

typedef struct cursor_entry {
  int shape;                    /* one of the SHAPE_ defines */
  int mshape;                   /* one of the MSHAPE defines */
  int percentage;               /* percentage of cell for bar */
  long blinkwait;               /* blinking, wait time before blinking starts */
  long blinkon;                 /* blinking, on time */
  long blinkoff;                /* blinking, off time */
  int id;                       /* highlight group ID */
  int id_lm;                    /* highlight group ID for :lmap mode */
  char        *name;            /* mode name (fixed) */
  char used_for;                /* SHAPE_MOUSE and/or SHAPE_CURSOR */
} cursorentry_T;
#endif /* CURSOR_SHAPE */


/* Indices into vimmenu_T->strings[] and vimmenu_T->noremap[] for each mode */
#define MENU_INDEX_INVALID      -1
#define MENU_INDEX_NORMAL       0
#define MENU_INDEX_VISUAL       1
#define MENU_INDEX_SELECT       2
#define MENU_INDEX_OP_PENDING   3
#define MENU_INDEX_INSERT       4
#define MENU_INDEX_CMDLINE      5
#define MENU_INDEX_TIP          6
#define MENU_MODES              7

/* Menu modes */
#define MENU_NORMAL_MODE        (1 << MENU_INDEX_NORMAL)
#define MENU_VISUAL_MODE        (1 << MENU_INDEX_VISUAL)
#define MENU_SELECT_MODE        (1 << MENU_INDEX_SELECT)
#define MENU_OP_PENDING_MODE    (1 << MENU_INDEX_OP_PENDING)
#define MENU_INSERT_MODE        (1 << MENU_INDEX_INSERT)
#define MENU_CMDLINE_MODE       (1 << MENU_INDEX_CMDLINE)
#define MENU_TIP_MODE           (1 << MENU_INDEX_TIP)
#define MENU_ALL_MODES          ((1 << MENU_INDEX_TIP) - 1)
/*note MENU_INDEX_TIP is not a 'real' mode*/

/* Start a menu name with this to not include it on the main menu bar */
#define MNU_HIDDEN_CHAR         ']'

typedef struct VimMenu vimmenu_T;

struct VimMenu {
  int modes;                        /* Which modes is this menu visible for? */
  int enabled;                      /* for which modes the menu is enabled */
  char_u      *name;                /* Name of menu, possibly translated */
  char_u      *dname;               /* Displayed Name ("name" without '&') */
  char_u      *en_name;             /* "name" untranslated, NULL when "name"
                                     * was not translated */
  char_u      *en_dname;            /* "dname" untranslated, NULL when "dname"
                                     * was not translated */
  int mnemonic;                     /* mnemonic key (after '&') */
  char_u      *actext;              /* accelerator text (after TAB) */
  int priority;                     /* Menu order priority */
  char_u      *strings[MENU_MODES];   /* Mapped string for each mode */
  int noremap[MENU_MODES];           /* A REMAP_ flag for each mode */
  char silent[MENU_MODES];          /* A silent flag for each mode */
  vimmenu_T   *children;            /* Children of sub-menu */
  vimmenu_T   *parent;              /* Parent of menu */
  vimmenu_T   *next;                /* Next item in menu */
};

/*
 * Struct to save values in before executing autocommands for a buffer that is
 * not the current buffer.  Without FEAT_AUTOCMD only "curbuf" is remembered.
 */
typedef struct {
  buf_T       *save_curbuf;     /* saved curbuf */
  int use_aucmd_win;            /* using aucmd_win */
  win_T       *save_curwin;     /* saved curwin */
  win_T       *new_curwin;      /* new curwin */
  buf_T       *new_curbuf;      /* new curbuf */
  char_u      *globaldir;       /* saved value of globaldir */
} aco_save_T;

/*
 * Generic option table item, only used for printer at the moment.
 */
typedef struct {
  const char  *name;
  int hasnum;
  long number;
  char_u      *string;          /* points into option string */
  int strlen;
  int present;
} option_table_T;

/*
 * Structure to hold printing color and font attributes.
 */
typedef struct {
  long_u fg_color;
  long_u bg_color;
  int bold;
  int italic;
  int underline;
  int undercurl;
} prt_text_attr_T;

/*
 * Structure passed back to the generic printer code.
 */
typedef struct {
  int n_collated_copies;
  int n_uncollated_copies;
  int duplex;
  int chars_per_line;
  int lines_per_page;
  int has_color;
  prt_text_attr_T number;
  int modec;
  int do_syntax;
  int user_abort;
  char_u      *jobname;
  char_u      *outfile;
  char_u      *arguments;
} prt_settings_T;

#define PRINT_NUMBER_WIDTH 8

/*
 * Used for popup menu items.
 */
typedef struct {
  char_u      *pum_text;        /* main menu text */
  char_u      *pum_kind;        /* extra kind text (may be truncated) */
  char_u      *pum_extra;       /* extra menu text (may be truncated) */
  char_u      *pum_info;        /* extra info */
} pumitem_T;

/*
 * Structure used for get_tagfname().
 */
typedef struct {
  char_u      *tn_tags;         /* value of 'tags' when starting */
  char_u      *tn_np;           /* current position in tn_tags */
  int tn_did_filefind_init;
  int tn_hf_idx;
  void        *tn_search_ctx;
} tagname_T;

/*
 * Array indexes used for cptext argument of ins_compl_add().
 */
#define CPT_ABBR    0   /* "abbr" */
#define CPT_MENU    1   /* "menu" */
#define CPT_KIND    2   /* "kind" */
#define CPT_INFO    3   /* "info" */
#define CPT_COUNT   4   /* Number of entries */

typedef struct {
  UINT32_T total[2];
  UINT32_T state[8];
  char_u buffer[64];
} context_sha256_T;
