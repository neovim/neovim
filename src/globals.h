/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

#ifndef NEOVIM_GLOBALS_H
#define NEOVIM_GLOBALS_H

#include "mbyte.h"

/*
 * definition of global variables
 */

/*
 * Number of Rows and Columns in the screen.
 * Must be long to be able to use them as options in option.c.
 * Note: Use screen_Rows and screen_Columns to access items in ScreenLines[].
 * They may have different values when the screen wasn't (re)allocated yet
 * after setting Rows or Columns (e.g., when starting up).
 */
EXTERN long Rows                        /* nr of rows in the screen */
#ifdef DO_INIT
  = 24L
#endif
;
EXTERN long Columns INIT(= 80);         /* nr of columns in the screen */

/*
 * The characters that are currently on the screen are kept in ScreenLines[].
 * It is a single block of characters, the size of the screen plus one line.
 * The attributes for those characters are kept in ScreenAttrs[].
 *
 * "LineOffset[n]" is the offset from ScreenLines[] for the start of line 'n'.
 * The same value is used for ScreenLinesUC[] and ScreenAttrs[].
 *
 * Note: before the screen is initialized and when out of memory these can be
 * NULL.
 */
EXTERN schar_T  *ScreenLines INIT(= NULL);
EXTERN sattr_T  *ScreenAttrs INIT(= NULL);
EXTERN unsigned *LineOffset INIT(= NULL);
EXTERN char_u   *LineWraps INIT(= NULL);        /* line wraps to next line */

/*
 * When using Unicode characters (in UTF-8 encoding) the character in
 * ScreenLinesUC[] contains the Unicode for the character at this position, or
 * NUL when the character in ScreenLines[] is to be used (ASCII char).
 * The composing characters are to be drawn on top of the original character.
 * ScreenLinesC[0][off] is only to be used when ScreenLinesUC[off] != 0.
 * Note: These three are only allocated when enc_utf8 is set!
 */
EXTERN u8char_T *ScreenLinesUC INIT(= NULL);    /* decoded UTF-8 characters */
EXTERN u8char_T *ScreenLinesC[MAX_MCO];         /* composing characters */
EXTERN int Screen_mco INIT(= 0);                /* value of p_mco used when
                                                   allocating ScreenLinesC[] */

/* Only used for euc-jp: Second byte of a character that starts with 0x8e.
 * These are single-width. */
EXTERN schar_T  *ScreenLines2 INIT(= NULL);

/*
 * Indexes for tab page line:
 *	N > 0 for label of tab page N
 *	N == 0 for no label
 *	N < 0 for closing tab page -N
 *	N == -999 for closing current tab page
 */
EXTERN short    *TabPageIdxs INIT(= NULL);

EXTERN int screen_Rows INIT(= 0);           /* actual size of ScreenLines[] */
EXTERN int screen_Columns INIT(= 0);        /* actual size of ScreenLines[] */

/*
 * When vgetc() is called, it sets mod_mask to the set of modifiers that are
 * held down based on the MOD_MASK_* symbols that are read first.
 */
EXTERN int mod_mask INIT(= 0x0);                /* current key modifiers */

/*
 * Cmdline_row is the row where the command line starts, just below the
 * last window.
 * When the cmdline gets longer than the available space the screen gets
 * scrolled up. After a CTRL-D (show matches), after hitting ':' after
 * "hit return", and for the :global command, the command line is
 * temporarily moved.  The old position is restored with the next call to
 * update_screen().
 */
EXTERN int cmdline_row;

EXTERN int redraw_cmdline INIT(= FALSE);        /* cmdline must be redrawn */
EXTERN int clear_cmdline INIT(= FALSE);         /* cmdline must be cleared */
EXTERN int mode_displayed INIT(= FALSE);        /* mode is being displayed */
EXTERN int cmdline_star INIT(= FALSE);          /* cmdline is crypted */

EXTERN int exec_from_reg INIT(= FALSE);         /* executing register */

EXTERN int screen_cleared INIT(= FALSE);        /* screen has been cleared */

EXTERN int use_crypt_method INIT(= 0);

/*
 * When '$' is included in 'cpoptions' option set:
 * When a change command is given that deletes only part of a line, a dollar
 * is put at the end of the changed text. dollar_vcol is set to the virtual
 * column of this '$'.  -1 is used to indicate no $ is being displayed.
 */
EXTERN colnr_T dollar_vcol INIT(= -1);

/*
 * Variables for Insert mode completion.
 */

/* Length in bytes of the text being completed (this is deleted to be replaced
 * by the match.) */
EXTERN int compl_length INIT(= 0);

/* Set when character typed while looking for matches and it means we should
 * stop looking for matches. */
EXTERN int compl_interrupted INIT(= FALSE);

/* List of flags for method of completion. */
EXTERN int compl_cont_status INIT(= 0);
# define CONT_ADDING    1       /* "normal" or "adding" expansion */
# define CONT_INTRPT    (2 + 4) /* a ^X interrupted the current expansion */
                                /* it's set only iff N_ADDS is set */
# define CONT_N_ADDS    4       /* next ^X<> will add-new or expand-current */
# define CONT_S_IPOS    8       /* next ^X<> will set initial_pos?
                                 * if so, word-wise-expansion will set SOL */
# define CONT_SOL       16      /* pattern includes start of line, just for
                                 * word-wise expansion, not set for ^X^L */
# define CONT_LOCAL     32      /* for ctrl_x_mode 0, ^X^P/^X^N do a local
                                 * expansion, (eg use complete=.) */

/*
 * Functions for putting characters in the command line,
 * while keeping ScreenLines[] updated.
 */
EXTERN int cmdmsg_rl INIT(= FALSE);         /* cmdline is drawn right to left */
EXTERN int msg_col;
EXTERN int msg_row;
EXTERN int msg_scrolled;        /* Number of screen lines that windows have
                                * scrolled because of printing messages. */
EXTERN int msg_scrolled_ign INIT(= FALSE);
/* when TRUE don't set need_wait_return in
   msg_puts_attr() when msg_scrolled is
   non-zero */

EXTERN char_u   *keep_msg INIT(= NULL);     /* msg to be shown after redraw */
EXTERN int keep_msg_attr INIT(= 0);         /* highlight attr for keep_msg */
EXTERN int keep_msg_more INIT(= FALSE);      /* keep_msg was set by msgmore() */
EXTERN int need_fileinfo INIT(= FALSE);     /* do fileinfo() after redraw */
EXTERN int msg_scroll INIT(= FALSE);        /* msg_start() will scroll */
EXTERN int msg_didout INIT(= FALSE);        /* msg_outstr() was used in line */
EXTERN int msg_didany INIT(= FALSE);        /* msg_outstr() was used at all */
EXTERN int msg_nowait INIT(= FALSE);        /* don't wait for this msg */
EXTERN int emsg_off INIT(= 0);              /* don't display errors for now,
                                               unless 'debug' is set. */
EXTERN int info_message INIT(= FALSE);      /* printing informative message */
EXTERN int msg_hist_off INIT(= FALSE);      /* don't add messages to history */
EXTERN int need_clr_eos INIT(= FALSE);      /* need to clear text before
                                               displaying a message. */
EXTERN int emsg_skip INIT(= 0);             /* don't display errors for
                                               expression that is skipped */
EXTERN int emsg_severe INIT(= FALSE);        /* use message of next of several
                                                emsg() calls for throw */
EXTERN int did_endif INIT(= FALSE);         /* just had ":endif" */
EXTERN dict_T vimvardict;                   /* Dictionary with v: variables */
EXTERN dict_T globvardict;                  /* Dictionary with g: variables */
EXTERN int did_emsg;                        /* set by emsg() when the message
                                               is displayed or thrown */
EXTERN int did_emsg_syntax;                 /* did_emsg set because of a
                                               syntax error */
EXTERN int called_emsg;                     /* always set by emsg() */
EXTERN int ex_exitval INIT(= 0);            /* exit value for ex mode */
EXTERN int emsg_on_display INIT(= FALSE);       /* there is an error message */
EXTERN int rc_did_emsg INIT(= FALSE);       /* vim_regcomp() called emsg() */

EXTERN int no_wait_return INIT(= 0);        /* don't wait for return for now */
EXTERN int need_wait_return INIT(= 0);      /* need to wait for return later */
EXTERN int did_wait_return INIT(= FALSE);       /* wait_return() was used and
                                                   nothing written since then */
EXTERN int need_maketitle INIT(= TRUE);      /* call maketitle() soon */

EXTERN int quit_more INIT(= FALSE);         /* 'q' hit at "--more--" msg */
#if defined(UNIX) || defined(__EMX__) || defined(VMS) || defined(MACOS_X)
EXTERN int newline_on_exit INIT(= FALSE);       /* did msg in altern. screen */
EXTERN int intr_char INIT(= 0);             /* extra interrupt character */
#endif
EXTERN int ex_keep_indent INIT(= FALSE);      /* getexmodeline(): keep indent */
EXTERN int vgetc_busy INIT(= 0);            /* when inside vgetc() then > 0 */

EXTERN int didset_vim INIT(= FALSE);        /* did set $VIM ourselves */
EXTERN int didset_vimruntime INIT(= FALSE);        /* idem for $VIMRUNTIME */

/*
 * Lines left before a "more" message.	Ex mode needs to be able to reset this
 * after you type something.
 */
EXTERN int lines_left INIT(= -1);           /* lines left for listing */
EXTERN int msg_no_more INIT(= FALSE);       /* don't use more prompt, truncate
                                               messages */

EXTERN char_u   *sourcing_name INIT( = NULL); /* name of error message source */
EXTERN linenr_T sourcing_lnum INIT(= 0);    /* line number of the source file */

EXTERN int ex_nesting_level INIT(= 0);          /* nesting level */
EXTERN int debug_break_level INIT(= -1);        /* break below this level */
EXTERN int debug_did_msg INIT(= FALSE);         /* did "debug mode" message */
EXTERN int debug_tick INIT(= 0);                /* breakpoint change count */
EXTERN int do_profiling INIT(= PROF_NONE);      /* PROF_ values */

/*
 * The exception currently being thrown.  Used to pass an exception to
 * a different cstack.  Also used for discarding an exception before it is
 * caught or made pending.  Only valid when did_throw is TRUE.
 */
EXTERN except_T *current_exception;

/*
 * did_throw: An exception is being thrown.  Reset when the exception is caught
 * or as long as it is pending in a finally clause.
 */
EXTERN int did_throw INIT(= FALSE);

/*
 * need_rethrow: set to TRUE when a throw that cannot be handled in do_cmdline()
 * must be propagated to the cstack of the previously called do_cmdline().
 */
EXTERN int need_rethrow INIT(= FALSE);

/*
 * check_cstack: set to TRUE when a ":finish" or ":return" that cannot be
 * handled in do_cmdline() must be propagated to the cstack of the previously
 * called do_cmdline().
 */
EXTERN int check_cstack INIT(= FALSE);

/*
 * Number of nested try conditionals (across function calls and ":source"
 * commands).
 */
EXTERN int trylevel INIT(= 0);

/*
 * When "force_abort" is TRUE, always skip commands after an error message,
 * even after the outermost ":endif", ":endwhile" or ":endfor" or for a
 * function without the "abort" flag.  It is set to TRUE when "trylevel" is
 * non-zero (and ":silent!" was not used) or an exception is being thrown at
 * the time an error is detected.  It is set to FALSE when "trylevel" gets
 * zero again and there was no error or interrupt or throw.
 */
EXTERN int force_abort INIT(= FALSE);

/*
 * "msg_list" points to a variable in the stack of do_cmdline() which keeps
 * the list of arguments of several emsg() calls, one of which is to be
 * converted to an error exception immediately after the failing command
 * returns.  The message to be used for the exception value is pointed to by
 * the "throw_msg" field of the first element in the list.  It is usually the
 * same as the "msg" field of that element, but can be identical to the "msg"
 * field of a later list element, when the "emsg_severe" flag was set when the
 * emsg() call was made.
 */
EXTERN struct msglist **msg_list INIT(= NULL);

/*
 * suppress_errthrow: When TRUE, don't convert an error to an exception.  Used
 * when displaying the interrupt message or reporting an exception that is still
 * uncaught at the top level (which has already been discarded then).  Also used
 * for the error message when no exception can be thrown.
 */
EXTERN int suppress_errthrow INIT(= FALSE);

/*
 * The stack of all caught and not finished exceptions.  The exception on the
 * top of the stack is the one got by evaluation of v:exception.  The complete
 * stack of all caught and pending exceptions is embedded in the various
 * cstacks; the pending exceptions, however, are not on the caught stack.
 */
EXTERN except_T *caught_stack INIT(= NULL);


/*
 * Garbage collection can only take place when we are sure there are no Lists
 * or Dictionaries being used internally.  This is flagged with
 * "may_garbage_collect" when we are at the toplevel.
 * "want_garbage_collect" is set by the garbagecollect() function, which means
 * we do garbage collection before waiting for a char at the toplevel.
 * "garbage_collect_at_exit" indicates garbagecollect(1) was called.
 */
EXTERN int may_garbage_collect INIT(= FALSE);
EXTERN int want_garbage_collect INIT(= FALSE);
EXTERN int garbage_collect_at_exit INIT(= FALSE);

/* ID of script being sourced or was sourced to define the current function. */
EXTERN scid_T current_SID INIT(= 0);

/* Magic number used for hashitem "hi_key" value indicating a deleted item.
 * Only the address is used. */
EXTERN char_u hash_removed;


EXTERN int scroll_region INIT(= FALSE);      /* term supports scroll region */
EXTERN int t_colors INIT(= 0);              /* int value of T_CCO */

/*
 * When highlight_match is TRUE, highlight a match, starting at the cursor
 * position.  Search_match_lines is the number of lines after the match (0 for
 * a match within one line), search_match_endcol the column number of the
 * character just after the match in the last line.
 */
EXTERN int highlight_match INIT(= FALSE);       /* show search match pos */
EXTERN linenr_T search_match_lines;             /* lines of of matched string */
EXTERN colnr_T search_match_endcol;             /* col nr of match end */

EXTERN int no_smartcase INIT(= FALSE);          /* don't use 'smartcase' once */

EXTERN int need_check_timestamps INIT(= FALSE);      /* need to check file
                                                        timestamps asap */
EXTERN int did_check_timestamps INIT(= FALSE);      /* did check timestamps
                                                       recently */
EXTERN int no_check_timestamps INIT(= 0);       /* Don't check timestamps */

EXTERN int highlight_attr[HLF_COUNT];       /* Highl. attr for each context. */
# define USER_HIGHLIGHT
#ifdef USER_HIGHLIGHT
EXTERN int highlight_user[9];                   /* User[1-9] attributes */
EXTERN int highlight_stlnc[9];                  /* On top of user */
#endif
EXTERN int cterm_normal_fg_color INIT(= 0);
EXTERN int cterm_normal_fg_bold INIT(= 0);
EXTERN int cterm_normal_bg_color INIT(= 0);

EXTERN int autocmd_busy INIT(= FALSE);          /* Is apply_autocmds() busy? */
EXTERN int autocmd_no_enter INIT(= FALSE);      /* *Enter autocmds disabled */
EXTERN int autocmd_no_leave INIT(= FALSE);      /* *Leave autocmds disabled */
EXTERN int modified_was_set;                    /* did ":set modified" */
EXTERN int did_filetype INIT(= FALSE);          /* FileType event found */
EXTERN int keep_filetype INIT(= FALSE);         /* value for did_filetype when
                                                   starting to execute
                                                   autocommands */

/* When deleting the current buffer, another one must be loaded.  If we know
 * which one is preferred, au_new_curbuf is set to it */
EXTERN buf_T    *au_new_curbuf INIT(= NULL);

/*
 * Mouse coordinates, set by check_termcode()
 */
EXTERN int mouse_row;
EXTERN int mouse_col;
EXTERN int mouse_past_bottom INIT(= FALSE);     /* mouse below last line */
EXTERN int mouse_past_eol INIT(= FALSE);        /* mouse right of line */
EXTERN int mouse_dragging INIT(= 0);            /* extending Visual area with
                                                   mouse dragging */
/*
 * When the DEC mouse has been pressed but not yet released we enable
 * automatic querys for the mouse position.
 */
EXTERN int WantQueryMouse INIT(= FALSE);




/* Value set from 'diffopt'. */
EXTERN int diff_context INIT(= 6);              /* context for folds */
EXTERN int diff_foldcolumn INIT(= 2);           /* 'foldcolumn' for diff mode */
EXTERN int diff_need_scrollbind INIT(= FALSE);

/* The root of the menu hierarchy. */
EXTERN vimmenu_T        *root_menu INIT(= NULL);
/*
 * While defining the system menu, sys_menu is TRUE.  This avoids
 * overruling of menus that the user already defined.
 */
EXTERN int sys_menu INIT(= FALSE);

/* While redrawing the screen this flag is set.  It means the screen size
 * ('lines' and 'rows') must not be changed. */
EXTERN int updating_screen INIT(= FALSE);



/*
 * All windows are linked in a list. firstwin points to the first entry,
 * lastwin to the last entry (can be the same as firstwin) and curwin to the
 * currently active window.
 * Without the FEAT_WINDOWS they are all equal.
 */
EXTERN win_T    *firstwin;              /* first window */
EXTERN win_T    *lastwin;               /* last window */
EXTERN win_T    *prevwin INIT(= NULL);  /* previous window */
# define W_NEXT(wp) ((wp)->w_next)
# define FOR_ALL_WINDOWS(wp) for (wp = firstwin; wp != NULL; wp = wp->w_next)
/*
 * When using this macro "break" only breaks out of the inner loop. Use "goto"
 * to break out of the tabpage loop.
 */
# define FOR_ALL_TAB_WINDOWS(tp, wp) \
  for ((tp) = first_tabpage; (tp) != NULL; (tp) = (tp)->tp_next) \
    for ((wp) = ((tp) == curtab) \
                ? firstwin : (tp)->tp_firstwin; (wp); (wp) = (wp)->w_next)

EXTERN win_T    *curwin;        /* currently active window */

EXTERN win_T    *aucmd_win;     /* window used in aucmd_prepbuf() */
EXTERN int aucmd_win_used INIT(= FALSE);        /* aucmd_win is being used */

/*
 * The window layout is kept in a tree of frames.  topframe points to the top
 * of the tree.
 */
EXTERN frame_T  *topframe;      /* top of the window frame tree */

/*
 * Tab pages are alternative topframes.  "first_tabpage" points to the first
 * one in the list, "curtab" is the current one.
 */
EXTERN tabpage_T    *first_tabpage;
EXTERN tabpage_T    *curtab;
EXTERN int redraw_tabline INIT(= FALSE);           /* need to redraw tabline */

/*
 * All buffers are linked in a list. 'firstbuf' points to the first entry,
 * 'lastbuf' to the last entry and 'curbuf' to the currently active buffer.
 */
EXTERN buf_T    *firstbuf INIT(= NULL); /* first buffer */
EXTERN buf_T    *lastbuf INIT(= NULL);  /* last buffer */
EXTERN buf_T    *curbuf INIT(= NULL);   /* currently active buffer */

/* Flag that is set when switching off 'swapfile'.  It means that all blocks
 * are to be loaded into memory.  Shouldn't be global... */
EXTERN int mf_dont_release INIT(= FALSE);       /* don't release blocks */

/*
 * List of files being edited (global argument list).  curwin->w_alist points
 * to this when the window is using the global argument list.
 */
EXTERN alist_T global_alist;    /* global argument list */
EXTERN int arg_had_last INIT(= FALSE);      /* accessed last file in
                                               global_alist */

EXTERN int ru_col;              /* column for ruler */
EXTERN int ru_wid;              /* 'rulerfmt' width of ruler when non-zero */
EXTERN int sc_col;              /* column for shown command */

#ifdef TEMPDIRNAMES
EXTERN char_u   *vim_tempdir INIT(= NULL); /* Name of Vim's own temp dir.
                                              Ends in a slash. */
#endif

/*
 * When starting or exiting some things are done differently (e.g. screen
 * updating).
 */
EXTERN int starting INIT(= NO_SCREEN);
/* first NO_SCREEN, then NO_BUFFERS and then
 * set to 0 when starting up finished */
EXTERN int exiting INIT(= FALSE);
/* TRUE when planning to exit Vim.  Might
 * still keep on running if there is a changed
 * buffer. */
EXTERN int really_exiting INIT(= FALSE);
/* TRUE when we are sure to exit, e.g., after
 * a deadly signal */
/* volatile because it is used in signal handler deathtrap(). */
EXTERN volatile int full_screen INIT(= FALSE);
/* TRUE when doing full-screen output
 * otherwise only writing some messages */

EXTERN int restricted INIT(= FALSE);
/* TRUE when started as "rvim" */
EXTERN int secure INIT(= FALSE);
/* non-zero when only "safe" commands are
 * allowed, e.g. when sourcing .exrc or .vimrc
 * in current directory */

EXTERN int textlock INIT(= 0);
/* non-zero when changing text and jumping to
 * another window or buffer is not allowed */

EXTERN int curbuf_lock INIT(= 0);
/* non-zero when the current buffer can't be
 * changed.  Used for FileChangedRO. */
EXTERN int allbuf_lock INIT(= 0);
/* non-zero when no buffer name can be
 * changed, no buffer can be deleted and
 * current directory can't be changed.
 * Used for SwapExists et al. */
# define HAVE_SANDBOX
EXTERN int sandbox INIT(= 0);
/* Non-zero when evaluating an expression in a
 * "sandbox".  Several things are not allowed
 * then. */

EXTERN int silent_mode INIT(= FALSE);
/* set to TRUE when "-s" commandline argument
 * used for ex */

EXTERN pos_T VIsual;            /* start position of active Visual selection */
EXTERN int VIsual_active INIT(= FALSE);
/* whether Visual mode is active */
EXTERN int VIsual_select INIT(= FALSE);
/* whether Select mode is active */
EXTERN int VIsual_reselect;
/* whether to restart the selection after a
 * Select mode mapping or menu */

EXTERN int VIsual_mode INIT(= 'v');
/* type of Visual mode */

EXTERN int redo_VIsual_busy INIT(= FALSE);
/* TRUE when redoing Visual */

/*
 * When pasting text with the middle mouse button in visual mode with
 * restart_edit set, remember where it started so we can set Insstart.
 */
EXTERN pos_T where_paste_started;

/*
 * This flag is used to make auto-indent work right on lines where only a
 * <RETURN> or <ESC> is typed. It is set when an auto-indent is done, and
 * reset when any other editing is done on the line. If an <ESC> or <RETURN>
 * is received, and did_ai is TRUE, the line is truncated.
 */
EXTERN int did_ai INIT(= FALSE);

/*
 * Column of first char after autoindent.  0 when no autoindent done.  Used
 * when 'backspace' is 0, to avoid backspacing over autoindent.
 */
EXTERN colnr_T ai_col INIT(= 0);

/*
 * This is a character which will end a start-middle-end comment when typed as
 * the first character on a new line.  It is taken from the last character of
 * the "end" comment leader when the COM_AUTO_END flag is given for that
 * comment end in 'comments'.  It is only valid when did_ai is TRUE.
 */
EXTERN int end_comment_pending INIT(= NUL);

/*
 * This flag is set after a ":syncbind" to let the check_scrollbind() function
 * know that it should not attempt to perform scrollbinding due to the scroll
 * that was a result of the ":syncbind." (Otherwise, check_scrollbind() will
 * undo some of the work done by ":syncbind.")  -ralston
 */
EXTERN int did_syncbind INIT(= FALSE);

/*
 * This flag is set when a smart indent has been performed. When the next typed
 * character is a '{' the inserted tab will be deleted again.
 */
EXTERN int did_si INIT(= FALSE);

/*
 * This flag is set after an auto indent. If the next typed character is a '}'
 * one indent will be removed.
 */
EXTERN int can_si INIT(= FALSE);

/*
 * This flag is set after an "O" command. If the next typed character is a '{'
 * one indent will be removed.
 */
EXTERN int can_si_back INIT(= FALSE);

EXTERN pos_T saved_cursor               /* w_cursor before formatting text. */
#ifdef DO_INIT
  = INIT_POS_T(0, 0, 0)
#endif
;

/*
 * Stuff for insert mode.
 */
EXTERN pos_T Insstart;                  /* This is where the latest
                                         * insert/append mode started. */
/*
 * Stuff for VREPLACE mode.
 */
EXTERN int orig_line_count INIT(= 0);       /* Line count when "gR" started */
EXTERN int vr_lines_changed INIT(= 0);      /* #Lines changed by "gR" so far */


#if defined(HAVE_SETJMP_H)
/*
 * Stuff for setjmp() and longjmp().
 * Used to protect areas where we could crash.
 */
EXTERN JMP_BUF lc_jump_env;     /* argument to SETJMP() */
# ifdef SIGHASARG
/* volatile because it is used in signal handlers. */
EXTERN volatile int lc_signal;  /* caught signal number, 0 when no was signal
                                   caught; used for mch_libcall() */
# endif
/* volatile because it is used in signal handler deathtrap(). */
EXTERN volatile int lc_active INIT(= FALSE); /* TRUE when lc_jump_env is valid. */
#endif

/*
 * These flags are set based upon 'fileencoding'.
 * Note that "enc_utf8" is also set for "unicode", because the characters are
 * internally stored as UTF-8 (to avoid trouble with NUL bytes).
 */
# define DBCS_JPN       932     /* japan */
# define DBCS_JPNU      9932    /* euc-jp */
# define DBCS_KOR       949     /* korea */
# define DBCS_KORU      9949    /* euc-kr */
# define DBCS_CHS       936     /* chinese */
# define DBCS_CHSU      9936    /* euc-cn */
# define DBCS_CHT       950     /* taiwan */
# define DBCS_CHTU      9950    /* euc-tw */
# define DBCS_2BYTE     1       /* 2byte- */
# define DBCS_DEBUG     -1

EXTERN int enc_dbcs INIT(= 0);                  /* One of DBCS_xxx values if
                                                   DBCS encoding */
EXTERN int enc_unicode INIT(= 0);       /* 2: UCS-2 or UTF-16, 4: UCS-4 */
EXTERN int enc_utf8 INIT(= FALSE);              /* UTF-8 encoded Unicode */
EXTERN int enc_latin1like INIT(= TRUE);         /* 'encoding' is latin1 comp. */
EXTERN int has_mbyte INIT(= 0);                 /* any multi-byte encoding */


/*
 * To speed up BYTELEN() we fill a table with the byte lengths whenever
 * enc_utf8 or enc_dbcs changes.
 */
EXTERN char mb_bytelen_tab[256];

/* Variables that tell what conversion is used for keyboard input and display
 * output. */
EXTERN vimconv_T input_conv;                    /* type of input conversion */
EXTERN vimconv_T output_conv;                   /* type of output conversion */

/*
 * Function pointers, used to quickly get to the right function.  Each has
 * three possible values: latin_ (8-bit), utfc_ or utf_ (utf-8) and dbcs_
 * (DBCS).
 * The value is set in mb_init();
 */
/* length of char in bytes, including following composing chars */
EXTERN int (*mb_ptr2len)(char_u *p) INIT(= latin_ptr2len);
/* idem, with limit on string length */
EXTERN int (*mb_ptr2len_len)(char_u *p, int size) INIT(= latin_ptr2len_len);
/* byte length of char */
EXTERN int (*mb_char2len)(int c) INIT(= latin_char2len);
/* convert char to bytes, return the length */
EXTERN int (*mb_char2bytes)(int c, char_u *buf) INIT(= latin_char2bytes);
EXTERN int (*mb_ptr2cells)(char_u *p) INIT(= latin_ptr2cells);
EXTERN int (*mb_ptr2cells_len)(char_u *p, int size) INIT(
      = latin_ptr2cells_len);
EXTERN int (*mb_char2cells)(int c) INIT(= latin_char2cells);
EXTERN int (*mb_off2cells)(unsigned off, unsigned max_off) INIT(
      = latin_off2cells);
EXTERN int (*mb_ptr2char)(char_u *p) INIT(= latin_ptr2char);
EXTERN int (*mb_head_off)(char_u *base, char_u *p) INIT(= latin_head_off);

# if defined(USE_ICONV) && defined(DYNAMIC_ICONV)
/* Pointers to functions and variables to be loaded at runtime */
EXTERN size_t (*iconv)(iconv_t cd, const char **inbuf, size_t *inbytesleft,
                       char **outbuf, size_t *outbytesleft);
EXTERN iconv_t (*iconv_open)(const char *tocode, const char *fromcode);
EXTERN int (*iconv_close)(iconv_t cd);
EXTERN int (*iconvctl)(iconv_t cd, int request, void *argument);
EXTERN int* (*iconv_errno)(void);
# endif



EXTERN int composing_hangul INIT(= 0);
EXTERN char_u composing_hangul_buffer[5];

/*
 * "State" is the main state of Vim.
 * There are other variables that modify the state:
 * "Visual_mode"    When State is NORMAL or INSERT.
 * "finish_op"	    When State is NORMAL, after typing the operator and before
 *		    typing the motion command.
 */
EXTERN int State INIT(= NORMAL);        /* This is the current state of the
                                         * command interpreter. */

EXTERN int finish_op INIT(= FALSE);     /* TRUE while an operator is pending */
EXTERN int opcount INIT(= 0);           /* count for pending operator */

/*
 * ex mode (Q) state
 */
EXTERN int exmode_active INIT(= 0);     /* zero, EXMODE_NORMAL or EXMODE_VIM */
EXTERN int ex_no_reprint INIT(= FALSE); /* no need to print after z or p */

EXTERN int Recording INIT(= FALSE);     /* TRUE when recording into a reg. */
EXTERN int Exec_reg INIT(= FALSE);      /* TRUE when executing a register */

EXTERN int no_mapping INIT(= FALSE);    /* currently no mapping allowed */
EXTERN int no_zero_mapping INIT(= 0);   /* mapping zero not allowed */
EXTERN int allow_keys INIT(= FALSE);    /* allow key codes when no_mapping
                                         * is set */
EXTERN int no_u_sync INIT(= 0);         /* Don't call u_sync() */
EXTERN int u_sync_once INIT(= 0);       /* Call u_sync() once when evaluating
                                           an expression. */

EXTERN int restart_edit INIT(= 0);      /* call edit when next cmd finished */
EXTERN int arrow_used;                  /* Normally FALSE, set to TRUE after
                                         * hitting cursor key in insert mode.
                                         * Used by vgetorpeek() to decide when
                                         * to call u_sync() */
EXTERN int ins_at_eol INIT(= FALSE);      /* put cursor after eol when
                                             restarting edit after CTRL-O */
EXTERN char_u   *edit_submode INIT(= NULL); /* msg for CTRL-X submode */
EXTERN char_u   *edit_submode_pre INIT(= NULL); /* prepended to edit_submode */
EXTERN char_u   *edit_submode_extra INIT(= NULL); /* appended to edit_submode */
EXTERN hlf_T edit_submode_highl;        /* highl. method for extra info */
EXTERN int ctrl_x_mode INIT(= 0);       /* Which Ctrl-X mode are we in? */

EXTERN int no_abbr INIT(= TRUE);        /* TRUE when no abbreviations loaded */

#ifdef USE_EXE_NAME
EXTERN char_u   *exe_name;              /* the name of the executable */
#endif

#ifdef USE_ON_FLY_SCROLL
EXTERN int dont_scroll INIT(= FALSE);     /* don't use scrollbars when TRUE */
#endif
EXTERN int mapped_ctrl_c INIT(= FALSE);      /* CTRL-C is mapped */
EXTERN int ctrl_c_interrupts INIT(= TRUE);      /* CTRL-C sets got_int */

EXTERN cmdmod_T cmdmod;                 /* Ex command modifiers */

EXTERN int msg_silent INIT(= 0);        /* don't print messages */
EXTERN int emsg_silent INIT(= 0);       /* don't print error messages */
EXTERN int cmd_silent INIT(= FALSE);      /* don't echo the command line */

#define HAS_SWAP_EXISTS_ACTION
EXTERN int swap_exists_action INIT(= SEA_NONE);
/* For dialog when swap file already
 * exists. */
EXTERN int swap_exists_did_quit INIT(= FALSE);
/* Selected "quit" at the dialog. */

EXTERN char_u   *IObuff;                /* sprintf's are done in this buffer,
                                           size is IOSIZE */
EXTERN char_u   *NameBuff;              /* file names are expanded in this
                                         * buffer, size is MAXPATHL */
EXTERN char_u msg_buf[MSG_BUF_LEN];     /* small buffer for messages */

/* When non-zero, postpone redrawing. */
EXTERN int RedrawingDisabled INIT(= 0);

EXTERN int readonlymode INIT(= FALSE);      /* Set to TRUE for "view" */
EXTERN int recoverymode INIT(= FALSE);      /* Set to TRUE for "-r" option */

EXTERN struct buffheader stuffbuff      /* stuff buffer */
#ifdef DO_INIT
  = {{NULL, {NUL}}, NULL, 0, 0}
#endif
;
EXTERN typebuf_T typebuf                /* typeahead buffer */
#ifdef DO_INIT
  = {NULL, NULL, 0, 0, 0, 0, 0, 0, 0}
#endif
;
EXTERN int ex_normal_busy INIT(= 0);      /* recursiveness of ex_normal() */
EXTERN int ex_normal_lock INIT(= 0);      /* forbid use of ex_normal() */
EXTERN int ignore_script INIT(= FALSE);       /* ignore script input */
EXTERN int stop_insert_mode;            /* for ":stopinsert" and 'insertmode' */

EXTERN int KeyTyped;                    /* TRUE if user typed current char */
EXTERN int KeyStuffed;                  /* TRUE if current char from stuffbuf */
#ifdef USE_IM_CONTROL
EXTERN int vgetc_im_active;             /* Input Method was active for last
                                           character obtained from vgetc() */
#endif
EXTERN int maptick INIT(= 0);           /* tick for each non-mapped char */

EXTERN char_u chartab[256];             /* table used in charset.c; See
                                           init_chartab() for explanation */

EXTERN int must_redraw INIT(= 0);           /* type of redraw necessary */
EXTERN int skip_redraw INIT(= FALSE);       /* skip redraw once */
EXTERN int do_redraw INIT(= FALSE);         /* extra redraw once */

EXTERN int need_highlight_changed INIT(= TRUE);
EXTERN char_u   *use_viminfo INIT(= NULL);  /* name of viminfo file to use */

#define NSCRIPT 15
EXTERN FILE     *scriptin[NSCRIPT];         /* streams to read script from */
EXTERN int curscript INIT(= 0);             /* index in scriptin[] */
EXTERN FILE     *scriptout INIT(= NULL);    /* stream to write script to */
EXTERN int read_cmd_fd INIT(= 0);           /* fd to read commands from */

/* volatile because it is used in signal handler catch_sigint(). */
EXTERN volatile int got_int INIT(= FALSE);    /* set to TRUE when interrupt
                                                 signal occurred */
#ifdef USE_TERM_CONSOLE
EXTERN int term_console INIT(= FALSE);      /* set to TRUE when console used */
#endif
EXTERN int termcap_active INIT(= FALSE);        /* set by starttermcap() */
EXTERN int cur_tmode INIT(= TMODE_COOK);        /* input terminal mode */
EXTERN int bangredo INIT(= FALSE);          /* set to TRUE with ! command */
EXTERN int searchcmdlen;                    /* length of previous search cmd */
EXTERN int reg_do_extmatch INIT(= 0);       /* Used when compiling regexp:
                                             * REX_SET to allow \z\(...\),
                                             * REX_USE to allow \z\1 et al. */
EXTERN reg_extmatch_T *re_extmatch_in INIT(= NULL); /* Used by vim_regexec():
                                                     * strings for \z\1...\z\9 */
EXTERN reg_extmatch_T *re_extmatch_out INIT(= NULL); /* Set by vim_regexec()
                                                      * to store \z\(...\) matches */

EXTERN int did_outofmem_msg INIT(= FALSE);
/* set after out of memory msg */
EXTERN int did_swapwrite_msg INIT(= FALSE);
/* set after swap write error msg */
EXTERN int undo_off INIT(= FALSE);          /* undo switched off for now */
EXTERN int global_busy INIT(= 0);           /* set when :global is executing */
EXTERN int listcmd_busy INIT(= FALSE);      /* set when :argdo, :windo or
                                               :bufdo is executing */
EXTERN int need_start_insertmode INIT(= FALSE);
/* start insert mode soon */
EXTERN char_u   *last_cmdline INIT(= NULL); /* last command line (for ":) */
EXTERN char_u   *repeat_cmdline INIT(= NULL); /* command line for "." */
EXTERN char_u   *new_last_cmdline INIT(= NULL); /* new value for last_cmdline */
EXTERN char_u   *autocmd_fname INIT(= NULL); /* fname for <afile> on cmdline */
EXTERN int autocmd_fname_full;               /* autocmd_fname is full path */
EXTERN int autocmd_bufnr INIT(= 0);          /* fnum for <abuf> on cmdline */
EXTERN char_u   *autocmd_match INIT(= NULL); /* name for <amatch> on cmdline */
EXTERN int did_cursorhold INIT(= FALSE);      /* set when CursorHold t'gerd */
EXTERN pos_T last_cursormoved                 /* for CursorMoved event */
# ifdef DO_INIT
  = INIT_POS_T(0, 0, 0)
# endif
;
EXTERN int last_changedtick INIT(= 0);        /* for TextChanged event */
EXTERN buf_T    *last_changedtick_buf INIT(= NULL);

EXTERN int postponed_split INIT(= 0);       /* for CTRL-W CTRL-] command */
EXTERN int postponed_split_flags INIT(= 0);       /* args for win_split() */
EXTERN int postponed_split_tab INIT(= 0);       /* cmdmod.tab */
EXTERN int g_do_tagpreview INIT(= 0);       /* for tag preview commands:
                                               height of preview window */
EXTERN int replace_offset INIT(= 0);        /* offset for replace_push() */

EXTERN char_u   *escape_chars INIT(= (char_u *)" \t\\\"|");
/* need backslash in cmd line */

EXTERN int keep_help_flag INIT(= FALSE);      /* doing :ta from help file */

/*
 * When a string option is NULL (which only happens in out-of-memory
 * situations), it is set to empty_option, to avoid having to check for NULL
 * everywhere.
 */
EXTERN char_u   *empty_option INIT(= (char_u *)"");

EXTERN int redir_off INIT(= FALSE);     /* no redirection for a moment */
EXTERN FILE *redir_fd INIT(= NULL);     /* message redirection file */
EXTERN int redir_reg INIT(= 0);         /* message redirection register */
EXTERN int redir_vname INIT(= 0);       /* message redirection variable */

EXTERN char_u langmap_mapchar[256];     /* mapping for language keys */

EXTERN int save_p_ls INIT(= -1);        /* Save 'laststatus' setting */
EXTERN int save_p_wmh INIT(= -1);       /* Save 'winminheight' setting */
EXTERN int wild_menu_showing INIT(= 0);
# define WM_SHOWN       1               /* wildmenu showing */
# define WM_SCROLLED    2               /* wildmenu showing with scroll */


EXTERN char breakat_flags[256];         /* which characters are in 'breakat' */

/* these are in version.c */
extern char *Version;
extern char *longVersion;

/*
 * Some file names are stored in pathdef.c, which is generated from the
 * Makefile to make their value depend on the Makefile.
 */
#ifdef HAVE_PATHDEF
extern char_u *default_vim_dir;
extern char_u *default_vimruntime_dir;
extern char_u *all_cflags;
extern char_u *all_lflags;
extern char_u *compiled_user;
extern char_u *compiled_sys;
#endif

/* When a window has a local directory, the absolute path of the global
 * current directory is stored here (in allocated memory).  If the current
 * directory is not a local directory, globaldir is NULL. */
EXTERN char_u   *globaldir INIT(= NULL);

/* Characters from 'listchars' option */
EXTERN int lcs_eol INIT(= '$');
EXTERN int lcs_ext INIT(= NUL);
EXTERN int lcs_prec INIT(= NUL);
EXTERN int lcs_nbsp INIT(= NUL);
EXTERN int lcs_tab1 INIT(= NUL);
EXTERN int lcs_tab2 INIT(= NUL);
EXTERN int lcs_trail INIT(= NUL);
EXTERN int lcs_conceal INIT(= '-');

/* Characters from 'fillchars' option */
EXTERN int fill_stl INIT(= ' ');
EXTERN int fill_stlnc INIT(= ' ');
EXTERN int fill_vert INIT(= ' ');
EXTERN int fill_fold INIT(= '-');
EXTERN int fill_diff INIT(= '-');

/* Whether 'keymodel' contains "stopsel" and "startsel". */
EXTERN int km_stopsel INIT(= FALSE);
EXTERN int km_startsel INIT(= FALSE);

EXTERN int cedit_key INIT(= -1);        /* key value of 'cedit' option */
EXTERN int cmdwin_type INIT(= 0);       /* type of cmdline window or 0 */
EXTERN int cmdwin_result INIT(= 0);      /* result of cmdline window or 0 */

EXTERN char_u no_lines_msg[] INIT(= N_("--No lines in buffer--"));

/*
 * When ":global" is used to number of substitutions and changed lines is
 * accumulated until it's finished.
 * Also used for ":spellrepall".
 */
EXTERN long sub_nsubs;          /* total number of substitutions */
EXTERN linenr_T sub_nlines;     /* total number of lines changed */

/* table to store parsed 'wildmode' */
EXTERN char_u wim_flags[4];

/* whether titlestring and iconstring contains statusline syntax */
# define STL_IN_ICON    1
# define STL_IN_TITLE   2
EXTERN int stl_syntax INIT(= 0);

/* don't use 'hlsearch' temporarily */
EXTERN int no_hlsearch INIT(= FALSE);


#ifdef CURSOR_SHAPE
/* the table is in misc2.c, because of initializations */
extern cursorentry_T shape_table[SHAPE_IDX_COUNT];
#endif

/*
 * Printer stuff shared between hardcopy.c and machine-specific printing code.
 */
# define OPT_PRINT_TOP          0
# define OPT_PRINT_BOT          1
# define OPT_PRINT_LEFT         2
# define OPT_PRINT_RIGHT        3
# define OPT_PRINT_HEADERHEIGHT 4
# define OPT_PRINT_SYNTAX       5
# define OPT_PRINT_NUMBER       6
# define OPT_PRINT_WRAP         7
# define OPT_PRINT_DUPLEX       8
# define OPT_PRINT_PORTRAIT     9
# define OPT_PRINT_PAPER        10
# define OPT_PRINT_COLLATE      11
# define OPT_PRINT_JOBSPLIT     12
# define OPT_PRINT_FORMFEED     13

# define OPT_PRINT_NUM_OPTIONS  14

EXTERN option_table_T printer_opts[OPT_PRINT_NUM_OPTIONS]
# ifdef DO_INIT
  =
  {
  {"top",     TRUE, 0, NULL, 0, FALSE},
  {"bottom",  TRUE, 0, NULL, 0, FALSE},
  {"left",    TRUE, 0, NULL, 0, FALSE},
  {"right",   TRUE, 0, NULL, 0, FALSE},
  {"header",  TRUE, 0, NULL, 0, FALSE},
  {"syntax",  FALSE, 0, NULL, 0, FALSE},
  {"number",  FALSE, 0, NULL, 0, FALSE},
  {"wrap",    FALSE, 0, NULL, 0, FALSE},
  {"duplex",  FALSE, 0, NULL, 0, FALSE},
  {"portrait", FALSE, 0, NULL, 0, FALSE},
  {"paper",   FALSE, 0, NULL, 0, FALSE},
  {"collate", FALSE, 0, NULL, 0, FALSE},
  {"jobsplit", FALSE, 0, NULL, 0, FALSE},
  {"formfeed", FALSE, 0, NULL, 0, FALSE},
  }

# endif
;

/* For prt_get_unit(). */
# define PRT_UNIT_NONE  -1
# define PRT_UNIT_PERC  0
# define PRT_UNIT_INCH  1
# define PRT_UNIT_MM    2
# define PRT_UNIT_POINT 3
# define PRT_UNIT_NAMES {"pc", "in", "mm", "pt"}

/* Page number used for %N in 'pageheader' and 'guitablabel'. */
EXTERN linenr_T printer_page_num;


EXTERN int typebuf_was_filled INIT(= FALSE);      /* received text from client
                                                     or from feedkeys() */


#if defined(UNIX) || defined(VMS)
EXTERN int term_is_xterm INIT(= FALSE);         /* xterm-like 'term' */
#endif

#ifdef BACKSLASH_IN_FILENAME
EXTERN char psepc INIT(= '\\');         /* normal path separator character */
EXTERN char psepcN INIT(= '/');         /* abnormal path separator character */
EXTERN char pseps[2]                    /* normal path separator string */
# ifdef DO_INIT
  = {'\\', 0}
# endif
;
#endif

/* Set to TRUE when an operator is being executed with virtual editing, MAYBE
 * when no operator is being executed, FALSE otherwise. */
EXTERN int virtual_op INIT(= MAYBE);

/* Display tick, incremented for each call to update_screen() */
EXTERN disptick_T display_tick INIT(= 0);

/* Line in which spell checking wasn't highlighted because it touched the
 * cursor position in Insert mode. */
EXTERN linenr_T spell_redraw_lnum INIT(= 0);

/* Set when the cursor line needs to be redrawn. */
EXTERN int need_cursor_line_redraw INIT(= FALSE);


#ifdef USE_MCH_ERRMSG
/* Grow array to collect error messages in until they can be displayed. */
EXTERN garray_T error_ga
# ifdef DO_INIT
  = {0, 0, 0, 0, NULL}
# endif
;
#endif


/*
 * The error messages that can be shared are included here.
 * Excluded are errors that are only used once and debugging messages.
 */
EXTERN char_u e_abort[] INIT(= N_("E470: Command aborted"));
EXTERN char_u e_argreq[] INIT(= N_("E471: Argument required"));
EXTERN char_u e_backslash[] INIT(= N_("E10: \\ should be followed by /, ? or &"));
EXTERN char_u e_cmdwin[] INIT(= N_(
        "E11: Invalid in command-line window; <CR> executes, CTRL-C quits"));
EXTERN char_u e_curdir[] INIT(= N_(
        "E12: Command not allowed from exrc/vimrc in current dir or tag search"));
EXTERN char_u e_endif[] INIT(= N_("E171: Missing :endif"));
EXTERN char_u e_endtry[] INIT(= N_("E600: Missing :endtry"));
EXTERN char_u e_endwhile[] INIT(= N_("E170: Missing :endwhile"));
EXTERN char_u e_endfor[] INIT(= N_("E170: Missing :endfor"));
EXTERN char_u e_while[] INIT(= N_("E588: :endwhile without :while"));
EXTERN char_u e_for[] INIT(= N_("E588: :endfor without :for"));
EXTERN char_u e_exists[] INIT(= N_("E13: File exists (add ! to override)"));
EXTERN char_u e_failed[] INIT(= N_("E472: Command failed"));
EXTERN char_u e_internal[] INIT(= N_("E473: Internal error"));
EXTERN char_u e_interr[] INIT(= N_("Interrupted"));
EXTERN char_u e_invaddr[] INIT(= N_("E14: Invalid address"));
EXTERN char_u e_invarg[] INIT(= N_("E474: Invalid argument"));
EXTERN char_u e_invarg2[] INIT(= N_("E475: Invalid argument: %s"));
EXTERN char_u e_invexpr2[] INIT(= N_("E15: Invalid expression: %s"));
EXTERN char_u e_invrange[] INIT(= N_("E16: Invalid range"));
EXTERN char_u e_invcmd[] INIT(= N_("E476: Invalid command"));
EXTERN char_u e_isadir2[] INIT(= N_("E17: \"%s\" is a directory"));
#ifdef FEAT_LIBCALL
EXTERN char_u e_libcall[] INIT(= N_("E364: Library call failed for \"%s()\""));
#endif
EXTERN char_u e_markinval[] INIT(= N_("E19: Mark has invalid line number"));
EXTERN char_u e_marknotset[] INIT(= N_("E20: Mark not set"));
EXTERN char_u e_modifiable[] INIT(= N_(
        "E21: Cannot make changes, 'modifiable' is off"));
EXTERN char_u e_nesting[] INIT(= N_("E22: Scripts nested too deep"));
EXTERN char_u e_noalt[] INIT(= N_("E23: No alternate file"));
EXTERN char_u e_noabbr[] INIT(= N_("E24: No such abbreviation"));
EXTERN char_u e_nobang[] INIT(= N_("E477: No ! allowed"));
EXTERN char_u e_nogvim[] INIT(= N_(
        "E25: GUI cannot be used: Not enabled at compile time"));
EXTERN char_u e_nogroup[] INIT(= N_("E28: No such highlight group name: %s"));
EXTERN char_u e_noinstext[] INIT(= N_("E29: No inserted text yet"));
EXTERN char_u e_nolastcmd[] INIT(= N_("E30: No previous command line"));
EXTERN char_u e_nomap[] INIT(= N_("E31: No such mapping"));
EXTERN char_u e_nomatch[] INIT(= N_("E479: No match"));
EXTERN char_u e_nomatch2[] INIT(= N_("E480: No match: %s"));
EXTERN char_u e_noname[] INIT(= N_("E32: No file name"));
EXTERN char_u e_nopresub[] INIT(= N_(
        "E33: No previous substitute regular expression"));
EXTERN char_u e_noprev[] INIT(= N_("E34: No previous command"));
EXTERN char_u e_noprevre[] INIT(= N_("E35: No previous regular expression"));
EXTERN char_u e_norange[] INIT(= N_("E481: No range allowed"));
EXTERN char_u e_noroom[] INIT(= N_("E36: Not enough room"));
EXTERN char_u e_notcreate[] INIT(= N_("E482: Can't create file %s"));
EXTERN char_u e_notmp[] INIT(= N_("E483: Can't get temp file name"));
EXTERN char_u e_notopen[] INIT(= N_("E484: Can't open file %s"));
EXTERN char_u e_notread[] INIT(= N_("E485: Can't read file %s"));
EXTERN char_u e_nowrtmsg[] INIT(= N_(
        "E37: No write since last change (add ! to override)"));
EXTERN char_u e_nowrtmsg_nobang[] INIT(= N_("E37: No write since last change"));
EXTERN char_u e_null[] INIT(= N_("E38: Null argument"));
EXTERN char_u e_number_exp[] INIT(= N_("E39: Number expected"));
EXTERN char_u e_openerrf[] INIT(= N_("E40: Can't open errorfile %s"));
EXTERN char_u e_outofmem[] INIT(= N_("E41: Out of memory!"));
EXTERN char_u e_patnotf[] INIT(= N_("Pattern not found"));
EXTERN char_u e_patnotf2[] INIT(= N_("E486: Pattern not found: %s"));
EXTERN char_u e_positive[] INIT(= N_("E487: Argument must be positive"));
EXTERN char_u e_prev_dir[] INIT(= N_(
        "E459: Cannot go back to previous directory"));

EXTERN char_u e_quickfix[] INIT(= N_("E42: No Errors"));
EXTERN char_u e_loclist[] INIT(= N_("E776: No location list"));
EXTERN char_u e_re_damg[] INIT(= N_("E43: Damaged match string"));
EXTERN char_u e_re_corr[] INIT(= N_("E44: Corrupted regexp program"));
EXTERN char_u e_readonly[] INIT(= N_(
        "E45: 'readonly' option is set (add ! to override)"));
EXTERN char_u e_readonlyvar[] INIT(= N_(
        "E46: Cannot change read-only variable \"%s\""));
EXTERN char_u e_readonlysbx[] INIT(= N_(
        "E794: Cannot set variable in the sandbox: \"%s\""));
EXTERN char_u e_readerrf[] INIT(= N_("E47: Error while reading errorfile"));
#ifdef HAVE_SANDBOX
EXTERN char_u e_sandbox[] INIT(= N_("E48: Not allowed in sandbox"));
#endif
EXTERN char_u e_secure[] INIT(= N_("E523: Not allowed here"));
#if defined(AMIGA) || defined(MACOS) || defined(MSWIN)  \
  || defined(UNIX) || defined(VMS) || defined(OS2)
EXTERN char_u e_screenmode[] INIT(= N_(
        "E359: Screen mode setting not supported"));
#endif
EXTERN char_u e_scroll[] INIT(= N_("E49: Invalid scroll size"));
EXTERN char_u e_shellempty[] INIT(= N_("E91: 'shell' option is empty"));
EXTERN char_u e_swapclose[] INIT(= N_("E72: Close error on swap file"));
EXTERN char_u e_tagstack[] INIT(= N_("E73: tag stack empty"));
EXTERN char_u e_toocompl[] INIT(= N_("E74: Command too complex"));
EXTERN char_u e_longname[] INIT(= N_("E75: Name too long"));
EXTERN char_u e_toomsbra[] INIT(= N_("E76: Too many ["));
EXTERN char_u e_toomany[] INIT(= N_("E77: Too many file names"));
EXTERN char_u e_trailing[] INIT(= N_("E488: Trailing characters"));
EXTERN char_u e_umark[] INIT(= N_("E78: Unknown mark"));
EXTERN char_u e_wildexpand[] INIT(= N_("E79: Cannot expand wildcards"));
EXTERN char_u e_winheight[] INIT(= N_(
        "E591: 'winheight' cannot be smaller than 'winminheight'"));
EXTERN char_u e_winwidth[] INIT(= N_(
        "E592: 'winwidth' cannot be smaller than 'winminwidth'"));
EXTERN char_u e_write[] INIT(= N_("E80: Error while writing"));
EXTERN char_u e_zerocount[] INIT(= N_("Zero count"));
EXTERN char_u e_usingsid[] INIT(= N_("E81: Using <SID> not in a script context"));
EXTERN char_u e_intern2[] INIT(= N_("E685: Internal error: %s"));
EXTERN char_u e_maxmempat[] INIT(= N_(
        "E363: pattern uses more memory than 'maxmempattern'"));
EXTERN char_u e_emptybuf[] INIT(= N_("E749: empty buffer"));

EXTERN char_u e_invalpat[] INIT(= N_(
        "E682: Invalid search pattern or delimiter"));
EXTERN char_u e_bufloaded[] INIT(= N_("E139: File is loaded in another buffer"));
EXTERN char_u e_notset[] INIT(= N_("E764: Option '%s' is not set"));
EXTERN char_u e_invalidreg[] INIT(= N_("E850: Invalid register name"));


EXTERN char top_bot_msg[] INIT(= N_("search hit TOP, continuing at BOTTOM"));
EXTERN char bot_top_msg[] INIT(= N_("search hit BOTTOM, continuing at TOP"));

EXTERN char need_key_msg[] INIT(= N_("Need encryption key for \"%s\""));

/*
 * Comms. with the session manager (XSMP)
 */

/* For undo we need to know the lowest time possible. */
EXTERN time_t starttime;

#ifdef STARTUPTIME
EXTERN FILE *time_fd INIT(= NULL);  /* where to write startup timing */
#endif

/*
 * Some compilers warn for not using a return value, but in some situations we
 * can't do anything useful with the value.  Assign to this variable to avoid
 * the warning.
 */
EXTERN int ignored;
EXTERN char *ignoredp;

/*
 * Optional Farsi support.  Include it here, so EXTERN and INIT are defined.
 */
# include "farsi.h"

/*
 * Optional Arabic support. Include it here, so EXTERN and INIT are defined.
 */
# include "arabic.h"

#endif /* NEOVIM_GLOBALS_H */
