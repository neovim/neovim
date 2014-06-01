#ifndef NVIM_EX_CMDS_DEFS_H
#define NVIM_EX_CMDS_DEFS_H

/*
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 */

#include <stdbool.h>

#include "nvim/normal.h"
#include "nvim/types.h"
#include "nvim/vim.h"

/*
 * This file defines the Ex commands.
 *
 * When adding an Ex command:
 * 1. Add an entry in enum CMD_index below. Keep it sorted on the shortest
 *    version of the command name that works. If it doesn't start with a
 *    lower case letter, add it at the end.
 * 2. Add corresponding entry in cmdnames table in ex_docmd.c.
 * 2. Add a "case: CMD_xxx" in the big switch in ex_docmd.c.
 * 3. Add an entry in the index for Ex commands at ":help ex-cmd-index".
 * 4. Add documentation in ../doc/xxx.txt. Add a tag for both the short and
 *    long name of the command.
 */

#define RANGE           0x001   /* allow a linespecs */
#define BANG            0x002   /* allow a ! after the command name */
#define EXTRA           0x004   /* allow extra args after command name */
#define XFILE           0x008   /* expand wildcards in extra part */
#define NOSPC           0x010   /* no spaces allowed in the extra part */
#define DFLALL          0x020   /* default file range is 1,$ */
#define WHOLEFOLD       0x040   /* extend range to include whole fold also
                                   when less than two numbers given */
#define NEEDARG         0x080   /* argument required */
#define TRLBAR          0x100   /* check for trailing vertical bar */
#define REGSTR          0x200   /* allow "x for register designation */
#define COUNT           0x400   /* allow count in argument, after command */
#define NOTRLCOM        0x800   /* no trailing comment allowed */
#define ZEROR          0x1000   /* zero line number allowed */
#define USECTRLV       0x2000   /* do not remove CTRL-V from argument */
#define NOTADR         0x4000   /* number before command is not an address */
#define EDITCMD        0x8000   /* allow "+command" argument */
#define BUFNAME       0x10000L  /* accepts buffer name */
#define BUFUNL        0x20000L  /* accepts unlisted buffer too */
#define ARGOPT        0x40000L  /* allow "++opt=val" argument */
#define SBOXOK        0x80000L  /* allowed in the sandbox */
#define CMDWIN       0x100000L  /* allowed in cmdline window */
#define MODIFY       0x200000L  /* forbidden in non-'modifiable' buffer */
#define EXFLAGS      0x400000L  /* allow flags after count in argument */
#define FILES   (XFILE | EXTRA) /* multiple extra files allowed */
#define WORD1   (EXTRA | NOSPC) /* one extra word allowed */
#define FILE1   (FILES | NOSPC) /* 1 file allowed, defaults to current file */

typedef enum CMD_index
{
  CMD_append,
  CMD_abbreviate,
  CMD_abclear,
  CMD_aboveleft,
  CMD_all,
  CMD_amenu,
  CMD_anoremenu,
  CMD_args,
  CMD_argadd,
  CMD_argdelete,
  CMD_argdo,
  CMD_argedit,
  CMD_argglobal,
  CMD_arglocal,
  CMD_argument,
  CMD_ascii,
  CMD_autocmd,
  CMD_augroup,
  CMD_aunmenu,
  CMD_buffer,
  CMD_bNext,
  CMD_ball,
  CMD_badd,
  CMD_bdelete,
  CMD_behave,
  CMD_belowright,
  CMD_bfirst,
  CMD_blast,
  CMD_bmodified,
  CMD_bnext,
  CMD_botright,
  CMD_bprevious,
  CMD_brewind,
  CMD_break,
  CMD_breakadd,
  CMD_breakdel,
  CMD_breaklist,
  CMD_browse,
  CMD_buffers,
  CMD_bufdo,
  CMD_bunload,
  CMD_bwipeout,
  CMD_change,
  CMD_cNext,
  CMD_cNfile,
  CMD_cabbrev,
  CMD_cabclear,
  CMD_caddbuffer,
  CMD_caddexpr,
  CMD_caddfile,
  CMD_call,
  CMD_catch,
  CMD_cbuffer,
  CMD_cc,
  CMD_cclose,
  CMD_cd,
  CMD_center,
  CMD_cexpr,
  CMD_cfile,
  CMD_cfirst,
  CMD_cgetfile,
  CMD_cgetbuffer,
  CMD_cgetexpr,
  CMD_chdir,
  CMD_changes,
  CMD_checkpath,
  CMD_checktime,
  CMD_clist,
  CMD_clast,
  CMD_close,
  CMD_cmap,
  CMD_cmapclear,
  CMD_cmenu,
  CMD_cnext,
  CMD_cnewer,
  CMD_cnfile,
  CMD_cnoremap,
  CMD_cnoreabbrev,
  CMD_cnoremenu,
  CMD_copy,
  CMD_colder,
  CMD_colorscheme,
  CMD_command,
  CMD_comclear,
  CMD_compiler,
  CMD_continue,
  CMD_confirm,
  CMD_copen,
  CMD_cprevious,
  CMD_cpfile,
  CMD_cquit,
  CMD_crewind,
  CMD_cscope,
  CMD_cstag,
  CMD_cunmap,
  CMD_cunabbrev,
  CMD_cunmenu,
  CMD_cwindow,
  CMD_delete,
  CMD_delmarks,
  CMD_debug,
  CMD_debuggreedy,
  CMD_delcommand,
  CMD_delfunction,
  CMD_display,
  CMD_diffupdate,
  CMD_diffget,
  CMD_diffoff,
  CMD_diffpatch,
  CMD_diffput,
  CMD_diffsplit,
  CMD_diffthis,
  CMD_digraphs,
  CMD_djump,
  CMD_dlist,
  CMD_doautocmd,
  CMD_doautoall,
  CMD_drop,
  CMD_dsearch,
  CMD_dsplit,
  CMD_edit,
  CMD_earlier,
  CMD_echo,
  CMD_echoerr,
  CMD_echohl,
  CMD_echomsg,
  CMD_echon,
  CMD_else,
  CMD_elseif,
  CMD_emenu,
  CMD_endif,
  CMD_endfunction,
  CMD_endfor,
  CMD_endtry,
  CMD_endwhile,
  CMD_enew,
  CMD_ex,
  CMD_execute,
  CMD_exit,
  CMD_exusage,
  CMD_file,
  CMD_files,
  CMD_filetype,
  CMD_find,
  CMD_finally,
  CMD_finish,
  CMD_first,
  CMD_fixdel,
  CMD_fold,
  CMD_foldclose,
  CMD_folddoopen,
  CMD_folddoclosed,
  CMD_foldopen,
  CMD_for,
  CMD_function,
  CMD_global,
  CMD_goto,
  CMD_grep,
  CMD_grepadd,
  CMD_gui,
  CMD_gvim,
  CMD_help,
  CMD_helpfind,
  CMD_helpgrep,
  CMD_helptags,
  CMD_hardcopy,
  CMD_highlight,
  CMD_hide,
  CMD_history,
  CMD_insert,
  CMD_iabbrev,
  CMD_iabclear,
  CMD_if,
  CMD_ijump,
  CMD_ilist,
  CMD_imap,
  CMD_imapclear,
  CMD_imenu,
  CMD_inoremap,
  CMD_inoreabbrev,
  CMD_inoremenu,
  CMD_intro,
  CMD_isearch,
  CMD_isplit,
  CMD_iunmap,
  CMD_iunabbrev,
  CMD_iunmenu,
  CMD_join,
  CMD_jumps,
  CMD_k,
  CMD_keepmarks,
  CMD_keepjumps,
  CMD_keeppatterns,
  CMD_keepalt,
  CMD_list,
  CMD_lNext,
  CMD_lNfile,
  CMD_last,
  CMD_language,
  CMD_laddexpr,
  CMD_laddbuffer,
  CMD_laddfile,
  CMD_later,
  CMD_lbuffer,
  CMD_lcd,
  CMD_lchdir,
  CMD_lclose,
  CMD_lcscope,
  CMD_left,
  CMD_leftabove,
  CMD_let,
  CMD_lexpr,
  CMD_lfile,
  CMD_lfirst,
  CMD_lgetfile,
  CMD_lgetbuffer,
  CMD_lgetexpr,
  CMD_lgrep,
  CMD_lgrepadd,
  CMD_lhelpgrep,
  CMD_ll,
  CMD_llast,
  CMD_llist,
  CMD_lmap,
  CMD_lmapclear,
  CMD_lmake,
  CMD_lnoremap,
  CMD_lnext,
  CMD_lnewer,
  CMD_lnfile,
  CMD_loadview,
  CMD_loadkeymap,
  CMD_lockmarks,
  CMD_lockvar,
  CMD_lolder,
  CMD_lopen,
  CMD_lprevious,
  CMD_lpfile,
  CMD_lrewind,
  CMD_ltag,
  CMD_lunmap,
  CMD_lvimgrep,
  CMD_lvimgrepadd,
  CMD_lwindow,
  CMD_ls,
  CMD_move,
  CMD_mark,
  CMD_make,
  CMD_map,
  CMD_mapclear,
  CMD_marks,
  CMD_match,
  CMD_menu,
  CMD_menutranslate,
  CMD_messages,
  CMD_mkexrc,
  CMD_mksession,
  CMD_mkspell,
  CMD_mkvimrc,
  CMD_mkview,
  CMD_mode,
  CMD_next,
  CMD_nbkey,
  CMD_nbclose,
  CMD_nbstart,
  CMD_new,
  CMD_nmap,
  CMD_nmapclear,
  CMD_nmenu,
  CMD_nnoremap,
  CMD_nnoremenu,
  CMD_noremap,
  CMD_noautocmd,
  CMD_nohlsearch,
  CMD_noreabbrev,
  CMD_noremenu,
  CMD_noswapfile,
  CMD_normal,
  CMD_number,
  CMD_nunmap,
  CMD_nunmenu,
  CMD_open,
  CMD_oldfiles,
  CMD_omap,
  CMD_omapclear,
  CMD_omenu,
  CMD_only,
  CMD_onoremap,
  CMD_onoremenu,
  CMD_options,
  CMD_ounmap,
  CMD_ounmenu,
  CMD_ownsyntax,
  CMD_print,
  CMD_pclose,
  CMD_pedit,
  CMD_pop,
  CMD_popup,
  CMD_ppop,
  CMD_preserve,
  CMD_previous,
  CMD_promptfind,
  CMD_promptrepl,
  CMD_profile,
  CMD_profdel,
  CMD_psearch,
  CMD_ptag,
  CMD_ptNext,
  CMD_ptfirst,
  CMD_ptjump,
  CMD_ptlast,
  CMD_ptnext,
  CMD_ptprevious,
  CMD_ptrewind,
  CMD_ptselect,
  CMD_put,
  CMD_pwd,
  CMD_quit,
  CMD_quitall,
  CMD_qall,
  CMD_read,
  CMD_recover,
  CMD_redo,
  CMD_redir,
  CMD_redraw,
  CMD_redrawstatus,
  CMD_registers,
  CMD_resize,
  CMD_retab,
  CMD_return,
  CMD_rewind,
  CMD_right,
  CMD_rightbelow,
  CMD_runtime,
  CMD_rundo,
  CMD_rviminfo,
  CMD_substitute,
  CMD_sNext,
  CMD_sargument,
  CMD_sall,
  CMD_sandbox,
  CMD_saveas,
  CMD_sbuffer,
  CMD_sbNext,
  CMD_sball,
  CMD_sbfirst,
  CMD_sblast,
  CMD_sbmodified,
  CMD_sbnext,
  CMD_sbprevious,
  CMD_sbrewind,
  CMD_scriptnames,
  CMD_scriptencoding,
  CMD_scscope,
  CMD_set,
  CMD_setfiletype,
  CMD_setglobal,
  CMD_setlocal,
  CMD_sfind,
  CMD_sfirst,
  CMD_simalt,
  CMD_sign,
  CMD_silent,
  CMD_sleep,
  CMD_slast,
  CMD_smagic,
  CMD_smap,
  CMD_smapclear,
  CMD_smenu,
  CMD_snext,
  CMD_snomagic,
  CMD_snoremap,
  CMD_snoremenu,
  CMD_source,
  CMD_sort,
  CMD_split,
  CMD_spellgood,
  CMD_spelldump,
  CMD_spellinfo,
  CMD_spellrepall,
  CMD_spellundo,
  CMD_spellwrong,
  CMD_sprevious,
  CMD_srewind,
  CMD_stop,
  CMD_stag,
  CMD_startinsert,
  CMD_startgreplace,
  CMD_startreplace,
  CMD_stopinsert,
  CMD_stjump,
  CMD_stselect,
  CMD_sunhide,
  CMD_sunmap,
  CMD_sunmenu,
  CMD_suspend,
  CMD_sview,
  CMD_swapname,
  CMD_syntax,
  CMD_syntime,
  CMD_syncbind,
  CMD_t,
  CMD_tNext,
  CMD_tag,
  CMD_tags,
  CMD_tab,
  CMD_tabclose,
  CMD_tabdo,
  CMD_tabedit,
  CMD_tabfind,
  CMD_tabfirst,
  CMD_tabmove,
  CMD_tablast,
  CMD_tabnext,
  CMD_tabnew,
  CMD_tabonly,
  CMD_tabprevious,
  CMD_tabNext,
  CMD_tabrewind,
  CMD_tabs,
  CMD_tearoff,
  CMD_tfirst,
  CMD_throw,
  CMD_tjump,
  CMD_tlast,
  CMD_tmenu,
  CMD_tnext,
  CMD_topleft,
  CMD_tprevious,
  CMD_trewind,
  CMD_try,
  CMD_tselect,
  CMD_tunmenu,
  CMD_undo,
  CMD_undojoin,
  CMD_undolist,
  CMD_unabbreviate,
  CMD_unhide,
  CMD_unlet,
  CMD_unlockvar,
  CMD_unmap,
  CMD_unmenu,
  CMD_unsilent,
  CMD_update,
  CMD_vglobal,
  CMD_version,
  CMD_verbose,
  CMD_vertical,
  CMD_visual,
  CMD_view,
  CMD_vimgrep,
  CMD_vimgrepadd,
  CMD_viusage,
  CMD_vmap,
  CMD_vmapclear,
  CMD_vmenu,
  CMD_vnoremap,
  CMD_vnew,
  CMD_vnoremenu,
  CMD_vsplit,
  CMD_vunmap,
  CMD_vunmenu,
  CMD_write,
  CMD_wNext,
  CMD_wall,
  CMD_while,
  CMD_winsize,
  CMD_wincmd,
  CMD_windo,
  CMD_winpos,
  CMD_wnext,
  CMD_wprevious,
  CMD_wq,
  CMD_wqall,
  CMD_wsverb,
  CMD_wundo,
  CMD_wviminfo,
  CMD_xit,
  CMD_xall,
  CMD_xmap,
  CMD_xmapclear,
  CMD_xmenu,
  CMD_xnoremap,
  CMD_xnoremenu,
  CMD_xunmap,
  CMD_xunmenu,
  CMD_yank,
  CMD_z,

  /* commands that don't start with a lowercase letter */
  CMD_bang,
  CMD_pound,
  CMD_and,
  CMD_star,
  CMD_lshift,
  CMD_equal,
  CMD_rshift,
  CMD_at,
  CMD_Next,
  CMD_Print,
  CMD_tilde,

  CMD_SIZE,             /* MUST be after all real commands! */
  CMD_USER = -1,        /* User-defined command */
  CMD_USER_BUF = -2     /* User-defined command local to buffer */
} cmdidx_T;

#define USER_CMDIDX(idx) ((int)(idx) < 0)

/*
 * Arguments used for Ex commands.
 */
typedef struct exarg {
  char_u      *arg;             /* argument of the command */
  char_u      *nextcmd;         /* next command (NULL if none) */
  char_u      *cmd;             /* the name of the command (except for :make) */
  char_u      **cmdlinep;       /* pointer to pointer of allocated cmdline */
  cmdidx_T cmdidx;              /* the index for the command */
  long argt;                    /* flags for the command */
  int skip;                     /* don't execute the command, only parse it */
  int forceit;                  /* TRUE if ! present */
  int addr_count;               /* the number of addresses given */
  linenr_T line1;               /* the first line number */
  linenr_T line2;               /* the second line number or count */
  int flags;                    /* extra flags after count: EXFLAG_ */
  char_u      *do_ecmd_cmd;     /* +command arg to be used in edited file */
  linenr_T do_ecmd_lnum;        /* the line number in an edited file */
  int append;                   /* TRUE with ":w >>file" command */
  int usefilter;                /* TRUE with ":w !command" and ":r!command" */
  int amount;                   /* number of '>' or '<' for shift command */
  int regname;                  /* register name (NUL if none) */
  int force_bin;                /* 0, FORCE_BIN or FORCE_NOBIN */
  int read_edit;                /* ++edit argument */
  int force_ff;                 /* ++ff= argument (index in cmd[]) */
  int force_enc;                /* ++enc= argument (index in cmd[]) */
  int bad_char;                 /* BAD_KEEP, BAD_DROP or replacement byte */
  int useridx;                  /* user command index */
  char_u      *errmsg;          /* returned error message */
  char_u      *(*getline)(int, void *, int);
  void        *cookie;          /* argument for getline() */
  struct condstack *cstack;     /* condition stack for ":if" etc. */
} exarg_T;

typedef void (*ex_func_T)(exarg_T *eap);

#define FORCE_BIN 1             /* ":edit ++bin file" */
#define FORCE_NOBIN 2           /* ":edit ++nobin file" */

/* Values for "flags" */
#define EXFLAG_LIST     0x01    /* 'l': list */
#define EXFLAG_NR       0x02    /* '#': number */
#define EXFLAG_PRINT    0x04    /* 'p': print */

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
  bool noswapfile;                      /* true when ":noswapfile" was used */
  char_u      *save_ei;                 /* saved value of 'eventignore' */
} cmdmod_T;

#endif
