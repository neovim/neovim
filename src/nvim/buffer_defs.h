#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "nvim/arglist_defs.h"
#include "nvim/grid_defs.h"
#include "nvim/mapping_defs.h"
#include "nvim/marktree_defs.h"
#include "nvim/memline_defs.h"
#include "nvim/option_defs.h"
#include "nvim/os/fs_defs.h"
#include "nvim/statusline_defs.h"
#include "nvim/undo_defs.h"

/// Reference to a buffer that stores the value of buf_free_count.
/// bufref_valid() only needs to check "buf" when the count differs.
typedef struct {
  buf_T *br_buf;
  int br_fnum;
  int br_buf_free_count;
} bufref_T;

#define GETFILE_SUCCESS(x)    ((x) <= 0)
#define MODIFIABLE(buf) (buf->b_p_ma)

// Flags for w_valid.
// These are set when something in a window structure becomes invalid, except
// when the cursor is moved.  Call check_cursor_moved() before testing one of
// the flags.
// These are reset when that thing has been updated and is valid again.
//
// Every function that invalidates one of these must call one of the
// invalidate_* functions.
//
// w_valid is supposed to be used only in screen.c.  From other files, use the
// functions that set or reset the flags.
//
// VALID_BOTLINE    VALID_BOTLINE_AP
//     on       on      w_botline valid
//     off      on      w_botline approximated
//     off      off     w_botline not valid
//     on       off     not possible
#define VALID_WROW      0x01    // w_wrow (window row) is valid
#define VALID_WCOL      0x02    // w_wcol (window col) is valid
#define VALID_VIRTCOL   0x04    // w_virtcol (file col) is valid
#define VALID_CHEIGHT   0x08    // w_cline_height and w_cline_folded valid
#define VALID_CROW      0x10    // w_cline_row is valid
#define VALID_BOTLINE   0x20    // w_botline and w_empty_rows are valid
#define VALID_BOTLINE_AP 0x40   // w_botline is approximated
#define VALID_TOPLINE   0x80    // w_topline is valid (for cursor position)

// flags for b_flags
#define BF_RECOVERED    0x01    // buffer has been recovered
#define BF_CHECK_RO     0x02    // need to check readonly when loading file
                                // into buffer (set by ":e", may be reset by
                                // ":buf")
#define BF_NEVERLOADED  0x04    // file has never been loaded into buffer,
                                // many variables still need to be set
#define BF_NOTEDITED    0x08    // Set when file name is changed after
                                // starting to edit, reset when file is
                                // written out.
#define BF_NEW          0x10    // file didn't exist when editing started
#define BF_NEW_W        0x20    // Warned for BF_NEW and file created
#define BF_READERR      0x40    // got errors while reading the file
#define BF_DUMMY        0x80    // dummy buffer, only used internally
#define BF_SYN_SET      0x200   // 'syntax' option was set

// Mask to check for flags that prevent normal writing
#define BF_WRITE_MASK   (BF_NOTEDITED + BF_NEW + BF_READERR)

typedef struct wininfo_S wininfo_T;
typedef struct frame_S frame_T;
typedef uint64_t disptick_T;  // display tick type

// The taggy struct is used to store the information about a :tag command.
typedef struct {
  char *tagname;                // tag name
  fmark_T fmark;                // cursor position BEFORE ":tag"
  int cur_match;                // match number
  int cur_fnum;                 // buffer number used for cur_match
  char *user_data;              // used with tagfunc
} taggy_T;

// Structure that contains all options that are local to a window.
// Used twice in a window: for the current buffer and for all buffers.
// Also used in wininfo_T.
typedef struct {
  int wo_arab;
#define w_p_arab w_onebuf_opt.wo_arab  // 'arabic'
  int wo_bri;
#define w_p_bri w_onebuf_opt.wo_bri    // 'breakindent'
  char *wo_briopt;
#define w_p_briopt w_onebuf_opt.wo_briopt  // 'breakindentopt'
  int wo_diff;
#define w_p_diff w_onebuf_opt.wo_diff  // 'diff'
  char *wo_fdc;
#define w_p_fdc w_onebuf_opt.wo_fdc    // 'foldcolumn'
  char *wo_fdc_save;
#define w_p_fdc_save w_onebuf_opt.wo_fdc_save  // 'fdc' saved for diff mode
  int wo_fen;
#define w_p_fen w_onebuf_opt.wo_fen    // 'foldenable'
  int wo_fen_save;
  // 'foldenable' saved for diff mode
#define w_p_fen_save w_onebuf_opt.wo_fen_save
  char *wo_fdi;
#define w_p_fdi w_onebuf_opt.wo_fdi    // 'foldignore'
  OptInt wo_fdl;
#define w_p_fdl w_onebuf_opt.wo_fdl    // 'foldlevel'
  OptInt wo_fdl_save;
  // 'foldlevel' state saved for diff mode
#define w_p_fdl_save w_onebuf_opt.wo_fdl_save
  char *wo_fdm;
#define w_p_fdm w_onebuf_opt.wo_fdm    // 'foldmethod'
  char *wo_fdm_save;
#define w_p_fdm_save w_onebuf_opt.wo_fdm_save  // 'fdm' saved for diff mode
  OptInt wo_fml;
#define w_p_fml w_onebuf_opt.wo_fml    // 'foldminlines'
  OptInt wo_fdn;
#define w_p_fdn w_onebuf_opt.wo_fdn    // 'foldnestmax'
  char *wo_fde;
#define w_p_fde w_onebuf_opt.wo_fde    // 'foldexpr'
  char *wo_fdt;
#define w_p_fdt w_onebuf_opt.wo_fdt   // 'foldtext'
  char *wo_fmr;
#define w_p_fmr w_onebuf_opt.wo_fmr    // 'foldmarker'
  int wo_lbr;
#define w_p_lbr w_onebuf_opt.wo_lbr    // 'linebreak'
  int wo_list;
#define w_p_list w_onebuf_opt.wo_list   // 'list'
  int wo_nu;
#define w_p_nu w_onebuf_opt.wo_nu       // 'number'
  int wo_rnu;
#define w_p_rnu w_onebuf_opt.wo_rnu     // 'relativenumber'
  char *wo_ve;
#define w_p_ve w_onebuf_opt.wo_ve       // 'virtualedit'
  unsigned wo_ve_flags;
#define w_ve_flags w_onebuf_opt.wo_ve_flags  // flags for 'virtualedit'
  OptInt wo_nuw;
#define w_p_nuw w_onebuf_opt.wo_nuw    // 'numberwidth'
  int wo_wfb;
#define w_p_wfb w_onebuf_opt.wo_wfb    // 'winfixbuf'
  int wo_wfh;
#define w_p_wfh w_onebuf_opt.wo_wfh    // 'winfixheight'
  int wo_wfw;
#define w_p_wfw w_onebuf_opt.wo_wfw    // 'winfixwidth'
  int wo_pvw;
#define w_p_pvw w_onebuf_opt.wo_pvw    // 'previewwindow'
  int wo_rl;
#define w_p_rl w_onebuf_opt.wo_rl      // 'rightleft'
  char *wo_rlc;
#define w_p_rlc w_onebuf_opt.wo_rlc    // 'rightleftcmd'
  OptInt wo_scr;
#define w_p_scr w_onebuf_opt.wo_scr     // 'scroll'
  int wo_sms;
#define w_p_sms w_onebuf_opt.wo_sms     // 'smoothscroll'
  int wo_spell;
#define w_p_spell w_onebuf_opt.wo_spell  // 'spell'
  int wo_cuc;
#define w_p_cuc w_onebuf_opt.wo_cuc    // 'cursorcolumn'
  int wo_cul;
#define w_p_cul w_onebuf_opt.wo_cul    // 'cursorline'
  char *wo_culopt;
#define w_p_culopt w_onebuf_opt.wo_culopt  // 'cursorlineopt'
  char *wo_cc;
#define w_p_cc w_onebuf_opt.wo_cc      // 'colorcolumn'
  char *wo_sbr;
#define w_p_sbr w_onebuf_opt.wo_sbr    // 'showbreak'
  char *wo_stc;
#define w_p_stc w_onebuf_opt.wo_stc     // 'statuscolumn'
  char *wo_stl;
#define w_p_stl w_onebuf_opt.wo_stl     // 'statusline'
  char *wo_wbr;
#define w_p_wbr w_onebuf_opt.wo_wbr   // 'winbar'
  int wo_scb;
#define w_p_scb w_onebuf_opt.wo_scb    // 'scrollbind'
  int wo_diff_saved;           // options were saved for starting diff mode
#define w_p_diff_saved w_onebuf_opt.wo_diff_saved
  int wo_scb_save;              // 'scrollbind' saved for diff mode
#define w_p_scb_save w_onebuf_opt.wo_scb_save
  int wo_wrap;
#define w_p_wrap w_onebuf_opt.wo_wrap   // 'wrap'
  int wo_wrap_save;             // 'wrap' state saved for diff mode
#define w_p_wrap_save w_onebuf_opt.wo_wrap_save
  char *wo_cocu;                 // 'concealcursor'
#define w_p_cocu w_onebuf_opt.wo_cocu
  OptInt wo_cole;                         // 'conceallevel'
#define w_p_cole w_onebuf_opt.wo_cole
  int wo_crb;
#define w_p_crb w_onebuf_opt.wo_crb    // 'cursorbind'
  int wo_crb_save;              // 'cursorbind' state saved for diff mode
#define w_p_crb_save w_onebuf_opt.wo_crb_save
  char *wo_scl;
#define w_p_scl w_onebuf_opt.wo_scl    // 'signcolumn'
  OptInt wo_siso;
#define w_p_siso w_onebuf_opt.wo_siso  // 'sidescrolloff' local value
  OptInt wo_so;
#define w_p_so w_onebuf_opt.wo_so      // 'scrolloff' local value
  char *wo_winhl;
#define w_p_winhl w_onebuf_opt.wo_winhl    // 'winhighlight'
  char *wo_lcs;
#define w_p_lcs w_onebuf_opt.wo_lcs    // 'listchars'
  char *wo_fcs;
#define w_p_fcs w_onebuf_opt.wo_fcs    // 'fillchars'
  OptInt wo_winbl;
#define w_p_winbl w_onebuf_opt.wo_winbl  // 'winblend'

  LastSet wo_script_ctx[WV_COUNT];        // SCTXs for window-local options
#define w_p_script_ctx w_onebuf_opt.wo_script_ctx
} winopt_T;

// Window info stored with a buffer.
//
// Two types of info are kept for a buffer which are associated with a
// specific window:
// 1. Each window can have a different line number associated with a buffer.
// 2. The window-local options for a buffer work in a similar way.
// The window-info is kept in a list at b_wininfo.  It is kept in
// most-recently-used order.
struct wininfo_S {
  wininfo_T *wi_next;         // next entry or NULL for last entry
  wininfo_T *wi_prev;         // previous entry or NULL for first entry
  win_T *wi_win;          // pointer to window that did set wi_mark
  fmark_T wi_mark;                // last cursor mark in the file
  bool wi_optset;               // true when wi_opt has useful values
  winopt_T wi_opt;              // local window options
  bool wi_fold_manual;          // copy of w_fold_manual
  garray_T wi_folds;            // clone of w_folds
  int wi_changelistidx;         // copy of w_changelistidx
};

#define ALIST(win)      (win)->w_alist
#define GARGLIST        ((aentry_T *)global_alist.al_ga.ga_data)
#define ARGLIST         ((aentry_T *)ALIST(curwin)->al_ga.ga_data)
#define WARGLIST(wp)    ((aentry_T *)ALIST(wp)->al_ga.ga_data)
#define AARGLIST(al)    ((aentry_T *)((al)->al_ga.ga_data))
#define GARGCOUNT       (global_alist.al_ga.ga_len)
#define ARGCOUNT        (ALIST(curwin)->al_ga.ga_len)
#define WARGCOUNT(wp)   (ALIST(wp)->al_ga.ga_len)

// values for b_syn_spell: what to do with toplevel text
#define SYNSPL_DEFAULT  0       // spell check if @Spell not defined
#define SYNSPL_TOP      1       // spell check toplevel text
#define SYNSPL_NOTOP    2       // don't spell check toplevel text

// values for b_syn_foldlevel: how to compute foldlevel on a line
#define SYNFLD_START    0       // use level of item at start of line
#define SYNFLD_MINIMUM  1       // use lowest local minimum level on line

typedef struct qf_info_S qf_info_T;

// Used for :syntime: timing of executing a syntax pattern.
typedef struct {
  proftime_T total;             // total time used
  proftime_T slowest;           // time of slowest call
  int count;                    // nr of times used
  int match;                    // nr of times matched
} syn_time_T;

// These are items normally related to a buffer.  But when using ":ownsyntax"
// a window may have its own instance.
typedef struct {
  hashtab_T b_keywtab;                  // syntax keywords hash table
  hashtab_T b_keywtab_ic;               // idem, ignore case
  bool b_syn_error;                     // true when error occurred in HL
  bool b_syn_slow;                      // true when 'redrawtime' reached
  int b_syn_ic;                         // ignore case for :syn cmds
  int b_syn_foldlevel;                  // how to compute foldlevel on a line
  int b_syn_spell;                      // SYNSPL_ values
  garray_T b_syn_patterns;              // table for syntax patterns
  garray_T b_syn_clusters;              // table for syntax clusters
  int b_spell_cluster_id;               // @Spell cluster ID or 0
  int b_nospell_cluster_id;             // @NoSpell cluster ID or 0
  int b_syn_containedin;                // true when there is an item with a
                                        // "containedin" argument
  int b_syn_sync_flags;                 // flags about how to sync
  int16_t b_syn_sync_id;                // group to sync on
  linenr_T b_syn_sync_minlines;         // minimal sync lines offset
  linenr_T b_syn_sync_maxlines;         // maximal sync lines offset
  linenr_T b_syn_sync_linebreaks;       // offset for multi-line pattern
  char *b_syn_linecont_pat;             // line continuation pattern
  regprog_T *b_syn_linecont_prog;       // line continuation program
  syn_time_T b_syn_linecont_time;
  int b_syn_linecont_ic;                // ignore-case flag for above
  int b_syn_topgrp;                     // for ":syntax include"
  int b_syn_conceal;                    // auto-conceal for :syn cmds
  int b_syn_folditems;                  // number of patterns with the HL_FOLD
                                        // flag set
  // b_sst_array[] contains the state stack for a number of lines, for the
  // start of that line (col == 0).  This avoids having to recompute the
  // syntax state too often.
  // b_sst_array[] is allocated to hold the state for all displayed lines,
  // and states for 1 out of about 20 other lines.
  // b_sst_array        pointer to an array of synstate_T
  // b_sst_len          number of entries in b_sst_array[]
  // b_sst_first        pointer to first used entry in b_sst_array[] or NULL
  // b_sst_firstfree    pointer to first free entry in b_sst_array[] or NULL
  // b_sst_freecount    number of free entries in b_sst_array[]
  // b_sst_check_lnum   entries after this lnum need to be checked for
  //                    validity (MAXLNUM means no check needed)
  synstate_T *b_sst_array;
  int b_sst_len;
  synstate_T *b_sst_first;
  synstate_T *b_sst_firstfree;
  int b_sst_freecount;
  linenr_T b_sst_check_lnum;
  disptick_T b_sst_lasttick;    // last display tick

  // for spell checking
  garray_T b_langp;           // list of pointers to slang_T, see spell.c
  bool b_spell_ismw[256];     // flags: is midword char
  char *b_spell_ismw_mb;      // multi-byte midword chars
  char *b_p_spc;              // 'spellcapcheck'
  regprog_T *b_cap_prog;      // program for 'spellcapcheck'
  char *b_p_spf;              // 'spellfile'
  char *b_p_spl;              // 'spelllang'
  char *b_p_spo;              // 'spelloptions'
#define SPO_CAMEL  0x1
#define SPO_NPBUFFER 0x2
  unsigned b_p_spo_flags;      // 'spelloptions' flags
  int b_cjk;                  // all CJK letters as OK
  uint8_t b_syn_chartab[32];  // syntax iskeyword option
  char *b_syn_isk;            // iskeyword option
} synblock_T;

/// Type used for changedtick_di member in buf_T
///
/// Primary exists so that literals of relevant type can be made.
typedef TV_DICTITEM_STRUCT(sizeof("changedtick")) ChangedtickDictItem;

typedef struct {
  LuaRef on_lines;
  LuaRef on_bytes;
  LuaRef on_changedtick;
  LuaRef on_detach;
  LuaRef on_reload;
  bool utf_sizes;
  bool preview;
} BufUpdateCallbacks;
#define BUF_UPDATE_CALLBACKS_INIT { LUA_NOREF, LUA_NOREF, LUA_NOREF, \
                                    LUA_NOREF, LUA_NOREF, false, false }

#define BUF_HAS_QF_ENTRY 1
#define BUF_HAS_LL_ENTRY 2

// Maximum number of maphash blocks we will have
#define MAX_MAPHASH 256

// buffer: structure that holds information about one file
//
// Several windows can share a single Buffer
// A buffer is unallocated if there is no memfile for it.
// A buffer is new if the associated file has never been loaded yet.

struct file_buffer {
  handle_T handle;              // unique id for the buffer (buffer number)
#define b_fnum handle

  memline_T b_ml;               // associated memline (also contains line count

  buf_T *b_next;          // links in list of buffers
  buf_T *b_prev;

  int b_nwindows;               // nr of windows open on this buffer

  int b_flags;                  // various BF_ flags
  int b_locked;                 // Buffer is being closed or referenced, don't
                                // let autocommands wipe it out.
  int b_locked_split;           // Buffer is being closed, don't allow opening
                                // a new window with it.
  int b_ro_locked;              // Non-zero when the buffer can't be changed.
                                // Used for FileChangedRO

  // b_ffname   has the full path of the file (NULL for no name).
  // b_sfname   is the name as the user typed it (or NULL).
  // b_fname    is the same as b_sfname, unless ":cd" has been done,
  //            then it is the same as b_ffname (NULL for no name).
  char *b_ffname;          // full path file name, allocated
  char *b_sfname;          // short file name, allocated, may be equal to
                           // b_ffname
  char *b_fname;           // current file name, points to b_ffname or
                           // b_sfname

  bool file_id_valid;
  FileID file_id;

  int b_changed;                // 'modified': Set to true if something in the
                                // file has been changed and not written out.
  bool b_changed_invalid;       // Set if BufModified autocmd has not been
                                // triggered since the last time b_changed was
                                // modified.

  /// Change-identifier incremented for each change, including undo.
  ///
  /// This is a dict item used to store b:changedtick.
  ChangedtickDictItem changedtick_di;

  varnumber_T b_last_changedtick;       // b:changedtick when TextChanged was
                                        // last triggered.
  varnumber_T b_last_changedtick_i;     // b:changedtick for TextChangedI
  varnumber_T b_last_changedtick_pum;   // b:changedtick for TextChangedP

  bool b_saving;                // Set to true if we are in the middle of
                                // saving the buffer.

  // Changes to a buffer require updating of the display.  To minimize the
  // work, remember changes made and update everything at once.
  bool b_mod_set;               // true when there are changes since the last
                                // time the display was updated
  linenr_T b_mod_top;           // topmost lnum that was changed
  linenr_T b_mod_bot;           // lnum below last changed line, AFTER the
                                // change
  linenr_T b_mod_xlines;        // number of extra buffer lines inserted;
                                // negative when lines were deleted
  wininfo_T *b_wininfo;         // list of last used info for each window
  disptick_T b_mod_tick_syn;    // last display tick syntax was updated
  disptick_T b_mod_tick_decor;  // last display tick decoration providers
                                // where invoked

  int64_t b_mtime;              // last change time of original file
  int64_t b_mtime_ns;           // nanoseconds of last change time
  int64_t b_mtime_read;         // last change time when reading
  int64_t b_mtime_read_ns;      // nanoseconds of last read time
  uint64_t b_orig_size;         // size of original file in bytes
  int b_orig_mode;              // mode of original file
  time_t b_last_used;           // time when the buffer was last used; used
                                // for viminfo

  fmark_T b_namedm[NMARKS];     // current named marks (mark.c)

  // These variables are set when VIsual_active becomes false
  visualinfo_T b_visual;
  int b_visual_mode_eval;            // b_visual.vi_mode for visualmode()

  fmark_T b_last_cursor;        // cursor position when last unloading this
                                // buffer
  fmark_T b_last_insert;        // where Insert mode was left
  fmark_T b_last_change;        // position of last change: '. mark

  // the changelist contains old change positions
  fmark_T b_changelist[JUMPLISTSIZE];
  int b_changelistlen;                  // number of active entries
  bool b_new_change;                    // set by u_savecommon()

  // Character table, only used in charset.c for 'iskeyword'
  // bitset with 4*64=256 bits: 1 bit per character 0-255.
  uint64_t b_chartab[4];

  // Table used for mappings local to a buffer.
  mapblock_T *(b_maphash[MAX_MAPHASH]);

  // First abbreviation local to a buffer.
  mapblock_T *b_first_abbr;
  // User commands local to the buffer.
  garray_T b_ucmds;
  // start and end of an operator, also used for '[ and ']
  pos_T b_op_start;
  pos_T b_op_start_orig;  // used for Insstart_orig
  pos_T b_op_end;

  bool b_marks_read;            // Have we read ShaDa marks yet?

  bool b_modified_was_set;  ///< did ":set modified"
  bool b_did_filetype;      ///< FileType event found
  bool b_keep_filetype;     ///< value for did_filetype when starting
                            ///< to execute autocommands

  /// Set by the apply_autocmds_group function if the given event is equal to
  /// EVENT_FILETYPE. Used by the readfile function in order to determine if
  /// EVENT_BUFREADPOST triggered the EVENT_FILETYPE.
  ///
  /// Relying on this value requires one to reset it prior calling
  /// apply_autocmds_group().
  bool b_au_did_filetype;

  // The following only used in undo.c.
  u_header_T *b_u_oldhead;     // pointer to oldest header
  u_header_T *b_u_newhead;     // pointer to newest header; may not be valid
                               // if b_u_curhead is not NULL
  u_header_T *b_u_curhead;     // pointer to current header
  int b_u_numhead;             // current number of headers
  bool b_u_synced;             // entry lists are synced
  int b_u_seq_last;            // last used undo sequence number
  int b_u_save_nr_last;        // counter for last file write
  int b_u_seq_cur;             // uh_seq of header below which we are now
  time_t b_u_time_cur;         // uh_time of header below which we are now
  int b_u_save_nr_cur;         // file write nr after which we are now

  // variables for "U" command in undo.c
  char *b_u_line_ptr;           // saved line for "U" command
  linenr_T b_u_line_lnum;       // line number of line in u_line
  colnr_T b_u_line_colnr;       // optional column number

  bool b_scanned;               // ^N/^P have scanned this buffer

  // flags for use of ":lmap" and IM control
  OptInt b_p_iminsert;          // input mode for insert
  OptInt b_p_imsearch;          // input mode for search
#define B_IMODE_USE_INSERT (-1)  //  Use b_p_iminsert value for search
#define B_IMODE_NONE 0          //  Input via none
#define B_IMODE_LMAP 1          //  Input via langmap
#define B_IMODE_LAST 1

  int16_t b_kmap_state;         // using "lmap" mappings
#define KEYMAP_INIT    1       // 'keymap' was set, call keymap_init()
#define KEYMAP_LOADED  2       // 'keymap' mappings have been loaded
  garray_T b_kmap_ga;           // the keymap table

  // Options local to a buffer.
  // They are here because their value depends on the type of file
  // or contents of the file being edited.
  bool b_p_initialized;                 // set when options initialized

  LastSet b_p_script_ctx[BV_COUNT];     // SCTXs for buffer-local options

  int b_p_ai;                   ///< 'autoindent'
  int b_p_ai_nopaste;           ///< b_p_ai saved for paste mode
  char *b_p_bkc;                ///< 'backupco
  unsigned b_bkc_flags;     ///< flags for 'backupco
  int b_p_ci;                   ///< 'copyindent'
  int b_p_bin;                  ///< 'binary'
  int b_p_bomb;                 ///< 'bomb'
  char *b_p_bh;                 ///< 'bufhidden'
  char *b_p_bt;                 ///< 'buftype'
  int b_has_qf_entry;           ///< quickfix exists for buffer
  int b_p_bl;                   ///< 'buflisted'
  OptInt b_p_channel;           ///< 'channel'
  int b_p_cin;                  ///< 'cindent'
  char *b_p_cino;               ///< 'cinoptions'
  char *b_p_cink;               ///< 'cinkeys'
  char *b_p_cinw;               ///< 'cinwords'
  char *b_p_cinsd;              ///< 'cinscopedecls'
  char *b_p_com;                ///< 'comments'
  char *b_p_cms;                ///< 'commentstring'
  char *b_p_cot;                ///< 'completeopt' local value
  unsigned b_cot_flags;         ///< flags for 'completeopt'
  char *b_p_cpt;                ///< 'complete'
#ifdef BACKSLASH_IN_FILENAME
  char *b_p_csl;                ///< 'completeslash'
#endif
  char *b_p_cfu;                ///< 'completefunc'
  Callback b_cfu_cb;            ///< 'completefunc' callback
  char *b_p_ofu;                ///< 'omnifunc'
  Callback b_ofu_cb;            ///< 'omnifunc' callback
  char *b_p_tfu;                ///< 'tagfunc'
  Callback b_tfu_cb;            ///< 'tagfunc' callback
  int b_p_eof;                  ///< 'endoffile'
  int b_p_eol;                  ///< 'endofline'
  int b_p_fixeol;               ///< 'fixendofline'
  int b_p_et;                   ///< 'expandtab'
  int b_p_et_nobin;             ///< b_p_et saved for binary mode
  int b_p_et_nopaste;           ///< b_p_et saved for paste mode
  char *b_p_fenc;               ///< 'fileencoding'
  char *b_p_ff;                 ///< 'fileformat'
  char *b_p_ft;                 ///< 'filetype'
  char *b_p_fo;                 ///< 'formatoptions'
  char *b_p_flp;                ///< 'formatlistpat'
  int b_p_inf;                  ///< 'infercase'
  char *b_p_isk;                ///< 'iskeyword'
  char *b_p_def;                ///< 'define' local value
  char *b_p_inc;                ///< 'include'
  char *b_p_inex;               ///< 'includeexpr'
  uint32_t b_p_inex_flags;      ///< flags for 'includeexpr'
  char *b_p_inde;               ///< 'indentexpr'
  uint32_t b_p_inde_flags;      ///< flags for 'indentexpr'
  char *b_p_indk;               ///< 'indentkeys'
  char *b_p_fp;                 ///< 'formatprg'
  char *b_p_fex;                ///< 'formatexpr'
  uint32_t b_p_fex_flags;       ///< flags for 'formatexpr'
  char *b_p_kp;                 ///< 'keywordprg'
  int b_p_lisp;                 ///< 'lisp'
  char *b_p_lop;                ///< 'lispoptions'
  char *b_p_menc;               ///< 'makeencoding'
  char *b_p_mps;                ///< 'matchpairs'
  int b_p_ml;                   ///< 'modeline'
  int b_p_ml_nobin;             ///< b_p_ml saved for binary mode
  int b_p_ma;                   ///< 'modifiable'
  char *b_p_nf;                 ///< 'nrformats'
  int b_p_pi;                   ///< 'preserveindent'
  char *b_p_qe;                 ///< 'quoteescape'
  int b_p_ro;                   ///< 'readonly'
  OptInt b_p_sw;                ///< 'shiftwidth'
  OptInt b_p_scbk;              ///< 'scrollback'
  int b_p_si;                   ///< 'smartindent'
  OptInt b_p_sts;               ///< 'softtabstop'
  OptInt b_p_sts_nopaste;       ///< b_p_sts saved for paste mode
  char *b_p_sua;                ///< 'suffixesadd'
  int b_p_swf;                  ///< 'swapfile'
  OptInt b_p_smc;               ///< 'synmaxcol'
  char *b_p_syn;                ///< 'syntax'
  OptInt b_p_ts;                ///< 'tabstop'
  OptInt b_p_tw;                ///< 'textwidth'
  OptInt b_p_tw_nobin;          ///< b_p_tw saved for binary mode
  OptInt b_p_tw_nopaste;        ///< b_p_tw saved for paste mode
  OptInt b_p_wm;                ///< 'wrapmargin'
  OptInt b_p_wm_nobin;          ///< b_p_wm saved for binary mode
  OptInt b_p_wm_nopaste;        ///< b_p_wm saved for paste mode
  char *b_p_vsts;               ///< 'varsofttabstop'
  colnr_T *b_p_vsts_array;      ///< 'varsofttabstop' in internal format
  char *b_p_vsts_nopaste;       ///< b_p_vsts saved for paste mode
  char *b_p_vts;                ///< 'vartabstop'
  colnr_T *b_p_vts_array;       ///< 'vartabstop' in internal format
  char *b_p_keymap;             ///< 'keymap'

  // local values for options which are normally global
  char *b_p_gp;                 ///< 'grepprg' local value
  char *b_p_mp;                 ///< 'makeprg' local value
  char *b_p_efm;                ///< 'errorformat' local value
  char *b_p_ep;                 ///< 'equalprg' local value
  char *b_p_path;               ///< 'path' local value
  int b_p_ar;                   ///< 'autoread' local value
  char *b_p_tags;               ///< 'tags' local value
  char *b_p_tc;                 ///< 'tagcase' local value
  unsigned b_tc_flags;          ///< flags for 'tagcase'
  char *b_p_dict;               ///< 'dictionary' local value
  char *b_p_tsr;                ///< 'thesaurus' local value
  char *b_p_tsrfu;              ///< 'thesaurusfunc' local value
  Callback b_tsrfu_cb;          ///< 'thesaurusfunc' callback
  OptInt b_p_ul;                ///< 'undolevels' local value
  int b_p_udf;                  ///< 'undofile'
  char *b_p_lw;                 ///< 'lispwords' local value

  // end of buffer options

  // values set from b_p_cino
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
  int b_ind_cpp_extern_c;
  int b_ind_pragma;

  linenr_T b_no_eol_lnum;       // non-zero lnum when last line of next binary
                                // write should not have an end-of-line

  int b_start_eof;              // last line had eof (CTRL-Z) when it was read
  int b_start_eol;              // last line had eol when it was read
  int b_start_ffc;              // first char of 'ff' when edit started
  char *b_start_fenc;           // 'fileencoding' when edit started or NULL
  int b_bad_char;               // "++bad=" argument when edit started or 0
  int b_start_bomb;             // 'bomb' when it was read

  ScopeDictDictItem b_bufvar;  ///< Variable for "b:" Dict.
  dict_T *b_vars;  ///< b: scope Dict.

  // When a buffer is created, it starts without a swap file.  b_may_swap is
  // then set to indicate that a swap file may be opened later.  It is reset
  // if a swap file could not be opened.
  bool b_may_swap;
  bool b_did_warn;              // Set to true if user has been warned on first
                                // change of a read-only file

  // Two special kinds of buffers:
  // help buffer  - used for help files, won't use a swap file.
  // spell buffer - used for spell info, never displayed and doesn't have a
  //                file name.
  bool b_help;                  // true for help file buffer (when set b_p_bt
                                // is "help")
  bool b_spell;                 // True for a spell file buffer, most fields
                                // are not used!

  char *b_prompt_text;          // set by prompt_setprompt()
  Callback b_prompt_callback;   // set by prompt_setcallback()
  Callback b_prompt_interrupt;  // set by prompt_setinterrupt()
  int b_prompt_insert;          // value for restart_edit when entering
                                // a prompt buffer window.

  synblock_T b_s;               // Info related to syntax highlighting.  w_s
                                // normally points to this, but some windows
                                // may use a different synblock_T.

  struct {
    int max;                    // maximum number of signs on a single line
    int count[SIGN_SHOW_MAX];   // number of lines with number of signs
    bool resized;               // whether max changed at start of redraw
    bool autom;                 // whether 'signcolumn' is displayed in "auto:n>1"
                                // configured window. "b_signcols" calculation
                                // is skipped if false.
  } b_signcols;

  Terminal *terminal;           // Terminal instance associated with the buffer

  AdditionalData *additional_data;      // Additional data from shada file if any.

  int b_mapped_ctrl_c;          // modes where CTRL-C is mapped

  MarkTree b_marktree[1];
  Map(uint32_t, uint32_t) b_extmark_ns[1];         // extmark namespaces

  // array of channel_id:s which have asked to receive updates for this
  // buffer.
  kvec_t(uint64_t) update_channels;
  // array of lua callbacks for buffer updates.
  kvec_t(BufUpdateCallbacks) update_callbacks;

  // whether an update callback has requested codepoint size of deleted regions.
  bool update_need_codepoints;

  // Measurements of the deleted or replaced region since the last update
  // event. Some consumers of buffer changes need to know the byte size (like
  // treesitter) or the corresponding UTF-32/UTF-16 size (like LSP) of the
  // deleted text.
  size_t deleted_bytes;
  size_t deleted_bytes2;
  size_t deleted_codepoints;
  size_t deleted_codeunits;

  // The number for times the current line has been flushed in the memline.
  int flush_count;
};

// Stuff for diff mode.
#define DB_COUNT 8     // up to four buffers can be diff'ed

// Each diffblock defines where a block of lines starts in each of the buffers
// and how many lines it occupies in that buffer.  When the lines are missing
// in the buffer the df_count[] is zero.  This is all counted in
// buffer lines.
// There is always at least one unchanged line in between the diffs.
// Otherwise it would have been included in the diff above or below it.
// df_lnum[] + df_count[] is the lnum below the change.  When in one buffer
// lines have been inserted, in the other buffer df_lnum[] is the line below
// the insertion and df_count[] is zero.  When appending lines at the end of
// the buffer, df_lnum[] is one beyond the end!
// This is using a linked list, because the number of differences is expected
// to be reasonable small.  The list is sorted on lnum.
typedef struct diffblock_S diff_T;
struct diffblock_S {
  diff_T *df_next;
  linenr_T df_lnum[DB_COUNT];           // line number in buffer
  linenr_T df_count[DB_COUNT];          // nr of inserted/changed lines
  bool is_linematched;  // has the linematch algorithm ran on this diff hunk to divide it into
                        // smaller diff hunks?
};

#define SNAP_HELP_IDX   0
#define SNAP_AUCMD_IDX 1
#define SNAP_COUNT     2

/// Tab pages point to the top frame of each tab page.
/// Note: Most values are NOT valid for the current tab page!  Use "curwin",
/// "firstwin", etc. for that.  "tp_topframe" is always valid and can be
/// compared against "topframe" to find the current tab page.
typedef struct tabpage_S tabpage_T;
struct tabpage_S {
  handle_T handle;
  tabpage_T *tp_next;         ///< next tabpage or NULL
  frame_T *tp_topframe;       ///< topframe for the windows
  win_T *tp_curwin;           ///< current window in this Tab page
  win_T *tp_prevwin;          ///< previous window in this Tab page
  win_T *tp_firstwin;         ///< first window in this Tab page
  win_T *tp_lastwin;          ///< last window in this Tab page
  int64_t tp_old_Rows_avail;  ///< ROWS_AVAIL when Tab page was left
  int64_t tp_old_Columns;        ///< Columns when Tab page was left, -1 when
                                 ///< calling win_new_screen_cols() postponed
  OptInt tp_ch_used;          ///< value of 'cmdheight' when frame size was set

  diff_T *tp_first_diff;
  buf_T *(tp_diffbuf[DB_COUNT]);
  int tp_diff_invalid;              ///< list of diffs is outdated
  int tp_diff_update;               ///< update diffs before redrawing
  frame_T *(tp_snapshot[SNAP_COUNT]);    ///< window layout snapshots
  ScopeDictDictItem tp_winvar;      ///< Variable for "t:" Dict.
  dict_T *tp_vars;         ///< Internal variables, local to tab page.
  char *tp_localdir;       ///< Absolute path of local cwd or NULL.
  char *tp_prevdir;        ///< Previous directory.
};

// Structure to cache info for displayed lines in w_lines[].
// Each logical line has one entry.
// The entry tells how the logical line is currently displayed in the window.
// This is updated when displaying the window.
// When the display is changed (e.g., when clearing the screen) w_lines_valid
// is changed to exclude invalid entries.
// When making changes to the buffer, wl_valid is reset to indicate wl_size
// may not reflect what is actually in the buffer.  When wl_valid is false,
// the entries can only be used to count the number of displayed lines used.
// wl_lnum and wl_lastlnum are invalid too.
typedef struct {
  linenr_T wl_lnum;             // buffer line number for logical line
  uint16_t wl_size;             // height in screen lines
  char wl_valid;                // true values are valid for text in buffer
  char wl_folded;               // true when this is a range of folded lines
  linenr_T wl_lastlnum;         // last buffer line number for logical line
} wline_T;

// Windows are kept in a tree of frames.  Each frame has a column (FR_COL)
// or row (FR_ROW) layout or is a leaf, which has a window.
struct frame_S {
  char fr_layout;               // FR_LEAF, FR_COL or FR_ROW
  int fr_width;
  int fr_newwidth;              // new width used in win_equal_rec()
  int fr_height;
  int fr_newheight;             // new height used in win_equal_rec()
  frame_T *fr_parent;       // containing frame or NULL
  frame_T *fr_next;         // frame right or below in same parent, NULL
                            // for last
  frame_T *fr_prev;         // frame left or above in same parent, NULL
                            // for first
  // fr_child and fr_win are mutually exclusive
  frame_T *fr_child;        // first contained frame
  win_T *fr_win;        // window that fills this frame; for a snapshot
                        // set to the current window
};

#define FR_LEAF 0       // frame is a leaf
#define FR_ROW  1       // frame with a row of windows
#define FR_COL  2       // frame with a column of windows

// Struct used for highlighting 'hlsearch' matches, matches defined by
// ":match" and matches defined by match functions.
// For 'hlsearch' there is one pattern for all windows.  For ":match" and the
// match functions there is a different pattern for each window.
typedef struct {
  regmmatch_T rm;       // points to the regexp program; contains last found
                        // match (may continue in next line)
  buf_T *buf;     // the buffer to search for a match
  linenr_T lnum;        // the line to search for a match
  int attr;             // attributes to be used for a match
  int attr_cur;         // attributes currently active in win_line()
  linenr_T first_lnum;  // first lnum to search for multi-line pat
  colnr_T startcol;     // in win_line() points to char where HL starts
  colnr_T endcol;       // in win_line() points to char where HL ends
  bool is_addpos;       // position specified directly by matchaddpos()
  bool has_cursor;      // true if the cursor is inside the match, used for CurSearch
  proftime_T tm;        // for a time limit
} match_T;

/// Same as lpos_T, but with additional field len.
typedef struct {
  linenr_T lnum;   ///< line number
  colnr_T col;    ///< column number
  int len;    ///< length: 0 - to the end of line
} llpos_T;

/// matchitem_T provides a linked list for storing match items for ":match",
/// matchadd() and matchaddpos().
typedef struct matchitem matchitem_T;
struct matchitem {
  matchitem_T *mit_next;
  int mit_id;              ///< match ID
  int mit_priority;        ///< match priority

  // Either a pattern is defined (mit_pattern is not NUL) or a list of
  // positions is given (mit_pos is not NULL and mit_pos_count > 0).
  char *mit_pattern;       ///< pattern to highlight
  regmmatch_T mit_match;   ///< regexp program for pattern

  llpos_T *mit_pos_array;  ///< array of positions
  int mit_pos_count;       ///< nr of entries in mit_pos
  int mit_pos_cur;         ///< internal position counter
  linenr_T mit_toplnum;    ///< top buffer line
  linenr_T mit_botlnum;    ///< bottom buffer line

  match_T mit_hl;          ///< struct for doing the actual highlighting
  int mit_hlg_id;          ///< highlight group ID
  int mit_conceal_char;    ///< cchar for Conceal highlighting
};

typedef int FloatAnchor;

enum {
  kFloatAnchorEast  = 1,
  kFloatAnchorSouth = 2,
};

/// Keep in sync with float_relative_str[] in nvim_win_get_config()
typedef enum {
  kFloatRelativeEditor = 0,
  kFloatRelativeWindow = 1,
  kFloatRelativeCursor = 2,
  kFloatRelativeMouse = 3,
} FloatRelative;

/// Keep in sync with win_split_str[] in nvim_win_get_config() (api/win_config.c)
typedef enum {
  kWinSplitLeft = 0,
  kWinSplitRight = 1,
  kWinSplitAbove = 2,
  kWinSplitBelow = 3,
} WinSplit;

typedef enum {
  kWinStyleUnused = 0,
  kWinStyleMinimal,  /// Minimal UI: no number column, eob markers, etc
} WinStyle;

typedef enum {
  kAlignLeft   = 0,
  kAlignCenter = 1,
  kAlignRight  = 2,
} AlignTextPos;

typedef enum {
  kBorderTextTitle = 0,
  kBorderTextFooter = 1,
} BorderTextType;

/// See ":help nvim_open_win()" for documentation.
typedef struct {
  Window window;
  lpos_T bufpos;
  int height, width;
  double row, col;
  FloatAnchor anchor;
  FloatRelative relative;
  bool external;
  bool focusable;
  bool mouse;
  WinSplit split;
  int zindex;
  WinStyle style;
  bool border;
  bool shadow;
  char border_chars[8][MAX_SCHAR_SIZE];
  int border_hl_ids[8];
  int border_attr[8];
  bool title;
  AlignTextPos title_pos;
  VirtText title_chunks;
  int title_width;
  bool footer;
  AlignTextPos footer_pos;
  VirtText footer_chunks;
  int footer_width;
  bool noautocmd;
  bool fixed;
  bool hide;
} WinConfig;

#define WIN_CONFIG_INIT ((WinConfig){ .height = 0, .width = 0, \
                                      .bufpos = { -1, 0 }, \
                                      .row = 0, .col = 0, .anchor = 0, \
                                      .relative = 0, .external = false, \
                                      .focusable = true, \
                                      .mouse = true, \
                                      .split = 0, \
                                      .zindex = kZIndexFloatDefault, \
                                      .style = kWinStyleUnused, \
                                      .noautocmd = false, \
                                      .hide = false, \
                                      .fixed = false })

// Structure to store last cursor position and topline.  Used by check_lnums()
// and reset_lnums().
typedef struct {
  int w_topline_save;   // original topline value
  int w_topline_corr;   // corrected topline value
  pos_T w_cursor_save;  // original cursor position
  pos_T w_cursor_corr;  // corrected cursor position
} pos_save_T;

/// Characters from the 'listchars' option.
typedef struct {
  schar_T eol;
  schar_T ext;
  schar_T prec;
  schar_T nbsp;
  schar_T space;
  schar_T tab1;  ///< first tab character
  schar_T tab2;  ///< second tab character
  schar_T tab3;  ///< third tab character
  schar_T lead;
  schar_T trail;
  schar_T *multispace;
  schar_T *leadmultispace;
  schar_T conceal;
} lcs_chars_T;

/// Characters from the 'fillchars' option.
typedef struct {
  schar_T stl;
  schar_T stlnc;
  schar_T wbr;
  schar_T horiz;
  schar_T horizup;
  schar_T horizdown;
  schar_T vert;
  schar_T vertleft;
  schar_T vertright;
  schar_T verthoriz;
  schar_T fold;
  schar_T foldopen;    ///< when fold is open
  schar_T foldclosed;  ///< when fold is closed
  schar_T foldsep;     ///< continuous fold marker
  schar_T diff;
  schar_T msgsep;
  schar_T eob;
  schar_T lastline;
} fcs_chars_T;

/// Structure which contains all information that belongs to a window.
///
/// All row numbers are relative to the start of the window, except w_winrow.
struct window_S {
  handle_T handle;                  ///< unique identifier for the window

  buf_T *w_buffer;            ///< buffer we are a window into (used
                              ///< often, keep it the first item!)

  synblock_T *w_s;                 ///< for :ownsyntax

  int w_ns_hl;
  int w_ns_hl_winhl;
  int w_ns_hl_active;
  int *w_ns_hl_attr;

  Set(uint32_t) w_ns_set;

  int w_hl_id_normal;               ///< 'winhighlight' normal id
  int w_hl_attr_normal;             ///< 'winhighlight' normal final attrs
  int w_hl_attr_normalnc;           ///< 'winhighlight' NormalNC final attrs

  int w_hl_needs_update;            ///< attrs need to be recalculated

  win_T *w_prev;              ///< link to previous window
  win_T *w_next;              ///< link to next window
  bool w_locked;                    ///< don't let autocommands close the window

  frame_T *w_frame;             ///< frame containing this window

  pos_T w_cursor;                   ///< cursor position in buffer

  colnr_T w_curswant;               ///< Column we want to be at.  This is
                                    ///< used to try to stay in the same column
                                    ///< for up/down cursor motions.

  int w_set_curswant;               // If set, then update w_curswant the next
                                    // time through cursupdate() to the
                                    // current virtual column

  linenr_T w_cursorline;            ///< Where 'cursorline' should be drawn,
                                    ///< can be different from w_cursor.lnum
                                    ///< for closed folds.
  linenr_T w_last_cursorline;       ///< where last 'cursorline' was drawn

  // the next seven are used to update the visual part
  char w_old_visual_mode;           ///< last known VIsual_mode
  linenr_T w_old_cursor_lnum;       ///< last known end of visual part
  colnr_T w_old_cursor_fcol;        ///< first column for block visual part
  colnr_T w_old_cursor_lcol;        ///< last column for block visual part
  linenr_T w_old_visual_lnum;       ///< last known start of visual part
  colnr_T w_old_visual_col;         ///< last known start of visual part
  colnr_T w_old_curswant;           ///< last known value of Curswant

  linenr_T w_last_cursor_lnum_rnu;  ///< cursor lnum when 'rnu' was last redrawn

  /// 'listchars' characters. Defaults set in set_chars_option().
  lcs_chars_T w_p_lcs_chars;

  /// 'fillchars' characters. Defaults set in set_chars_option().
  fcs_chars_T w_p_fcs_chars;

  // "w_topline", "w_leftcol" and "w_skipcol" specify the offsets for
  // displaying the buffer.
  linenr_T w_topline;               // buffer line number of the line at the
                                    // top of the window
  char w_topline_was_set;           // flag set to true when topline is set,
                                    // e.g. by winrestview()
  int w_topfill;                    // number of filler lines above w_topline
  int w_old_topfill;                // w_topfill at last redraw
  bool w_botfill;                   // true when filler lines are actually
                                    // below w_topline (at end of file)
  bool w_old_botfill;               // w_botfill at last redraw
  colnr_T w_leftcol;                // screen column number of the left most
                                    // character in the window; used when
                                    // 'wrap' is off
  colnr_T w_skipcol;                // starting screen column for the first
                                    // line in the window; used when 'wrap' is
                                    // on; does not include win_col_off()

  // six fields that are only used when there is a WinScrolled autocommand
  linenr_T w_last_topline;          ///< last known value for w_topline
  int w_last_topfill;               ///< last known value for w_topfill
  colnr_T w_last_leftcol;           ///< last known value for w_leftcol
  colnr_T w_last_skipcol;           ///< last known value for w_skipcol
  int w_last_width;                 ///< last known value for w_width
  int w_last_height;                ///< last known value for w_height

  //
  // Layout of the window in the screen.
  // May need to add "msg_scrolled" to "w_winrow" in rare situations.
  //
  int w_winrow;                     // first row of window in screen
  int w_height;                     // number of rows in window, excluding
                                    // status/command line(s)
  int w_prev_winrow;                // previous winrow used for 'splitkeep'
  int w_prev_height;                // previous height used for 'splitkeep'
  int w_status_height;              // number of status lines (0 or 1)
  int w_winbar_height;              // number of window bars (0 or 1)
  int w_wincol;                     // Leftmost column of window in screen.
  int w_width;                      // Width of window, excluding separation.
  int w_hsep_height;                // Number of horizontal separator rows (0 or 1)
  int w_vsep_width;                 // Number of vertical separator columns (0 or 1).
  pos_save_T w_save_cursor;         // backup of cursor pos and topline
  bool w_do_win_fix_cursor;         // if true cursor may be invalid

  int w_winrow_off;  ///< offset from winrow to the inner window area
  int w_wincol_off;  ///< offset from wincol to the inner window area
                     ///< this includes float border but excludes special columns
                     ///< implemented in win_line() (i.e. signs, folds, numbers)

  // inner size of window, which can be overridden by external UI
  int w_height_inner;
  int w_width_inner;
  // external UI request. If non-zero, the inner size will use this.
  int w_height_request;
  int w_width_request;

  int w_border_adj[4];  // top, right, bottom, left
  // outer size of window grid, including border
  int w_height_outer;
  int w_width_outer;

  // === start of cached values ====

  // Recomputing is minimized by storing the result of computations.
  // Use functions in screen.c to check if they are valid and to update.
  // w_valid is a bitfield of flags, which indicate if specific values are
  // valid or need to be recomputed.
  int w_valid;
  pos_T w_valid_cursor;             // last known position of w_cursor, used to adjust w_valid
  colnr_T w_valid_leftcol;          // last known w_leftcol
  colnr_T w_valid_skipcol;          // last known w_skipcol

  bool w_viewport_invalid;
  linenr_T w_viewport_last_topline;  // topline when the viewport was last updated
  linenr_T w_viewport_last_botline;  // botline when the viewport was last updated
  linenr_T w_viewport_last_topfill;  // topfill when the viewport was last updated
  linenr_T w_viewport_last_skipcol;  // skipcol when the viewport was last updated

  // w_cline_height is the number of physical lines taken by the buffer line
  // that the cursor is on.  We use this to avoid extra calls to plines_win().
  int w_cline_height;               // current size of cursor line
  bool w_cline_folded;              // cursor line is folded

  int w_cline_row;                  // starting row of the cursor line

  colnr_T w_virtcol;                // column number of the cursor in the
                                    // buffer line, as opposed to the column
                                    // number we're at on the screen.  This
                                    // makes a difference on lines which span
                                    // more than one screen line or when
                                    // w_leftcol is non-zero

  // w_wrow and w_wcol specify the cursor position in the window.
  // This is related to positions in the window, not in the display or
  // buffer, thus w_wrow is relative to w_winrow.
  int w_wrow, w_wcol;               // cursor position in window

  linenr_T w_botline;               // number of the line below the bottom of
                                    // the window
  int w_empty_rows;                 // number of ~ rows in window
  int w_filler_rows;                // number of filler rows at the end of the
                                    // window

  // Info about the lines currently in the window is remembered to avoid
  // recomputing it every time.  The allocated size of w_lines[] is Rows.
  // Only the w_lines_valid entries are actually valid.
  // When the display is up-to-date w_lines[0].wl_lnum is equal to w_topline
  // and w_lines[w_lines_valid - 1].wl_lnum is equal to w_botline.
  // Between changing text and updating the display w_lines[] represents
  // what is currently displayed.  wl_valid is reset to indicated this.
  // This is used for efficient redrawing.
  int w_lines_valid;                // number of valid entries
  wline_T *w_lines;

  garray_T w_folds;                 // array of nested folds
  bool w_fold_manual;               // when true: some folds are opened/closed
                                    // manually
  bool w_foldinvalid;               // when true: folding needs to be
                                    // recomputed
  int w_nrwidth;                    // width of 'number' and 'relativenumber'
                                    // column being used
  int w_scwidth;                    // width of 'signcolumn'
  int w_minscwidth;                 // minimum width or SCL_NO/SCL_NUM
  int w_maxscwidth;                 // maximum width or SCL_NO/SCL_NUM

  // === end of cached values ===

  int w_redr_type;                  // type of redraw to be performed on win
  int w_upd_rows;                   // number of window lines to update when
                                    // w_redr_type is UPD_REDRAW_TOP
  linenr_T w_redraw_top;            // when != 0: first line needing redraw
  linenr_T w_redraw_bot;            // when != 0: last line needing redraw
  bool w_redr_status;               // if true statusline/winbar must be redrawn
  bool w_redr_border;               // if true border must be redrawn
  bool w_redr_statuscol;            // if true 'statuscolumn' must be redrawn

  // remember what is shown in the 'statusline'-format elements
  pos_T w_stl_cursor;                // cursor position when last redrawn
  colnr_T w_stl_virtcol;             // virtcol when last redrawn
  linenr_T w_stl_topline;            // topline when last redrawn
  linenr_T w_stl_line_count;         // line count when last redrawn
  int w_stl_topfill;                 // topfill when last redrawn
  char w_stl_empty;                  // true if elements show 0-1 (empty line)
  int w_stl_recording;               // reg_recording when last redrawn
  int w_stl_state;                   // get_real_state() when last redrawn
  int w_stl_visual_mode;             // VIsual_mode when last redrawn

  int w_alt_fnum;                   // alternate file (for # and CTRL-^)

  alist_T *w_alist;             // pointer to arglist for this window
  int w_arg_idx;                    // current index in argument list (can be
                                    // out of range!)
  int w_arg_idx_invalid;            // editing another file than w_arg_idx

  char *w_localdir;            // absolute path of local directory or NULL
  char *w_prevdir;             // previous directory
  // Options local to a window.
  // They are local because they influence the layout of the window or
  // depend on the window layout.
  // There are two values: w_onebuf_opt is local to the buffer currently in
  // this window, w_allbuf_opt is for all buffers in this window.
  winopt_T w_onebuf_opt;
  winopt_T w_allbuf_opt;
  // transform a pointer to a "onebuf" option into a "allbuf" option
#define GLOBAL_WO(p)    ((char *)(p) + sizeof(winopt_T))

  // A few options have local flags for P_INSECURE.
  uint32_t w_p_stl_flags;           // flags for 'statusline'
  uint32_t w_p_wbr_flags;           // flags for 'winbar'
  uint32_t w_p_fde_flags;           // flags for 'foldexpr'
  uint32_t w_p_fdt_flags;           // flags for 'foldtext'
  int *w_p_cc_cols;                 // array of columns to highlight or NULL
  uint8_t w_p_culopt_flags;         // flags for cursorline highlighting

  int w_briopt_min;                 // minimum width for breakindent
  int w_briopt_shift;               // additional shift for breakindent
  bool w_briopt_sbr;                // sbr in 'briopt'
  int w_briopt_list;                // additional indent for lists
  int w_briopt_vcol;                // indent for specific column

  int w_scbind_pos;

  ScopeDictDictItem w_winvar;       ///< Variable for "w:" dict.
  dict_T *w_vars;                   ///< Dict with w: variables.

  // The w_prev_pcmark field is used to check whether we really did jump to
  // a new line after setting the w_pcmark.  If not, then we revert to
  // using the previous w_pcmark.
  pos_T w_pcmark;               // previous context mark
  pos_T w_prev_pcmark;          // previous w_pcmark

  // the jumplist contains old cursor positions
  xfmark_T w_jumplist[JUMPLISTSIZE];
  int w_jumplistlen;                    // number of active entries
  int w_jumplistidx;                    // current position

  int w_changelistidx;                  // current position in b_changelist

  matchitem_T *w_match_head;            // head of match list
  int w_next_match_id;                  // next match ID

  // the tagstack grows from 0 upwards:
  // entry 0: older
  // entry 1: newer
  // entry 2: newest
  taggy_T w_tagstack[TAGSTACKSIZE];     // the tag stack
  int w_tagstackidx;                    // idx just below active entry
  int w_tagstacklen;                    // number of tags on stack

  ScreenGrid w_grid;                    // the grid specific to the window
  ScreenGrid w_grid_alloc;              // the grid specific to the window
  bool w_pos_changed;                   // true if window position changed
  bool w_floating;                      ///< whether the window is floating
  bool w_float_is_info;                 // the floating window is info float
  WinConfig w_config;

  // w_fraction is the fractional row of the cursor within the window, from
  // 0 at the top row to FRACTION_MULT at the last row.
  // w_prev_fraction_row was the actual cursor row when w_fraction was last
  // calculated.
  int w_fraction;
  int w_prev_fraction_row;

  linenr_T w_nrwidth_line_count;        // line count when ml_nrwidth_width was computed.
  linenr_T w_statuscol_line_count;      // line count when 'statuscolumn' width was computed.
  int w_nrwidth_width;                  // nr of chars to print line count.

  qf_info_T *w_llist;                 // Location list for this window
  // Location list reference used in the location list window.
  // In a non-location list window, w_llist_ref is NULL.
  qf_info_T *w_llist_ref;

  // Status line click definitions
  StlClickDefinition *w_status_click_defs;
  // Size of the w_status_click_defs array
  size_t w_status_click_defs_size;

  // Window bar click definitions
  StlClickDefinition *w_winbar_click_defs;
  // Size of the w_winbar_click_defs array
  size_t w_winbar_click_defs_size;

  // Status column click definitions
  StlClickDefinition *w_statuscol_click_defs;
  // Size of the w_statuscol_click_defs array
  size_t w_statuscol_click_defs_size;
};
