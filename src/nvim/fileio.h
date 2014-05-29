#ifndef NVIM_FILEIO_H
#define NVIM_FILEIO_H

#include "nvim/buffer_defs.h"
#include "nvim/os/os.h"

/* Values for readfile() flags */
#define READ_NEW        0x01    /* read a file into a new buffer */
#define READ_FILTER     0x02    /* read filter output */
#define READ_STDIN      0x04    /* read from stdin */
#define READ_BUFFER     0x08    /* read from curbuf (converting stdin) */
#define READ_DUMMY      0x10    /* reading into a dummy buffer */
#define READ_KEEP_UNDO  0x20    /* keep undo info*/

/*
 * Events for autocommands.
 */
enum auto_event {
  EVENT_BUFADD = 0,             /* after adding a buffer to the buffer list */
  EVENT_BUFNEW,                 /* after creating any buffer */
  EVENT_BUFDELETE,              /* deleting a buffer from the buffer list */
  EVENT_BUFWIPEOUT,             /* just before really deleting a buffer */
  EVENT_BUFENTER,               /* after entering a buffer */
  EVENT_BUFFILEPOST,            /* after renaming a buffer */
  EVENT_BUFFILEPRE,             /* before renaming a buffer */
  EVENT_BUFLEAVE,               /* before leaving a buffer */
  EVENT_BUFNEWFILE,             /* when creating a buffer for a new file */
  EVENT_BUFREADPOST,            /* after reading a buffer */
  EVENT_BUFREADPRE,             /* before reading a buffer */
  EVENT_BUFREADCMD,             /* read buffer using command */
  EVENT_BUFUNLOAD,              /* just before unloading a buffer */
  EVENT_BUFHIDDEN,              /* just after buffer becomes hidden */
  EVENT_BUFWINENTER,            /* after showing a buffer in a window */
  EVENT_BUFWINLEAVE,            /* just after buffer removed from window */
  EVENT_BUFWRITEPOST,           /* after writing a buffer */
  EVENT_BUFWRITEPRE,            /* before writing a buffer */
  EVENT_BUFWRITECMD,            /* write buffer using command */
  EVENT_CMDWINENTER,            /* after entering the cmdline window */
  EVENT_CMDWINLEAVE,            /* before leaving the cmdline window */
  EVENT_COLORSCHEME,            /* after loading a colorscheme */
  EVENT_COMPLETEDONE,           /* after finishing insert complete */
  EVENT_FILEAPPENDPOST,         /* after appending to a file */
  EVENT_FILEAPPENDPRE,          /* before appending to a file */
  EVENT_FILEAPPENDCMD,          /* append to a file using command */
  EVENT_FILECHANGEDSHELL,       /* after shell command that changed file */
  EVENT_FILECHANGEDSHELLPOST,   /* after (not) reloading changed file */
  EVENT_FILECHANGEDRO,          /* before first change to read-only file */
  EVENT_FILEREADPOST,           /* after reading a file */
  EVENT_FILEREADPRE,            /* before reading a file */
  EVENT_FILEREADCMD,            /* read from a file using command */
  EVENT_FILETYPE,               /* new file type detected (user defined) */
  EVENT_FILEWRITEPOST,          /* after writing a file */
  EVENT_FILEWRITEPRE,           /* before writing a file */
  EVENT_FILEWRITECMD,           /* write to a file using command */
  EVENT_FILTERREADPOST,         /* after reading from a filter */
  EVENT_FILTERREADPRE,          /* before reading from a filter */
  EVENT_FILTERWRITEPOST,        /* after writing to a filter */
  EVENT_FILTERWRITEPRE,         /* before writing to a filter */
  EVENT_FOCUSGAINED,            /* got the focus */
  EVENT_FOCUSLOST,              /* lost the focus to another app */
  EVENT_GUIENTER,               /* after starting the GUI */
  EVENT_GUIFAILED,              /* after starting the GUI failed */
  EVENT_INSERTCHANGE,           /* when changing Insert/Replace mode */
  EVENT_INSERTENTER,            /* when entering Insert mode */
  EVENT_INSERTLEAVE,            /* when leaving Insert mode */
  EVENT_JOBACTIVITY,            /* when job sent some data */
  EVENT_MENUPOPUP,              /* just before popup menu is displayed */
  EVENT_QUICKFIXCMDPOST,        /* after :make, :grep etc. */
  EVENT_QUICKFIXCMDPRE,         /* before :make, :grep etc. */
  EVENT_QUITPRE,                /* before :quit */
  EVENT_SESSIONLOADPOST,        /* after loading a session file */
  EVENT_STDINREADPOST,          /* after reading from stdin */
  EVENT_STDINREADPRE,           /* before reading from stdin */
  EVENT_SYNTAX,                 /* syntax selected */
  EVENT_TERMCHANGED,            /* after changing 'term' */
  EVENT_TERMRESPONSE,           /* after setting "v:termresponse" */
  EVENT_USER,                   /* user defined autocommand */
  EVENT_VIMENTER,               /* after starting Vim */
  EVENT_VIMLEAVE,               /* before exiting Vim */
  EVENT_VIMLEAVEPRE,            /* before exiting Vim and writing .viminfo */
  EVENT_VIMRESIZED,             /* after Vim window was resized */
  EVENT_WINENTER,               /* after entering a window */
  EVENT_WINLEAVE,               /* before leaving a window */
  EVENT_ENCODINGCHANGED,        /* after changing the 'encoding' option */
  EVENT_INSERTCHARPRE,          /* before inserting a char */
  EVENT_CURSORHOLD,             /* cursor in same position for a while */
  EVENT_CURSORHOLDI,            /* idem, in Insert mode */
  EVENT_FUNCUNDEFINED,          /* if calling a function which doesn't exist */
  EVENT_REMOTEREPLY,            /* upon string reception from a remote vim */
  EVENT_SWAPEXISTS,             /* found existing swap file */
  EVENT_SOURCEPRE,              /* before sourcing a Vim script */
  EVENT_SOURCECMD,              /* sourcing a Vim script using command */
  EVENT_SPELLFILEMISSING,       /* spell file missing */
  EVENT_CURSORMOVED,            /* cursor was moved */
  EVENT_CURSORMOVEDI,           /* cursor was moved in Insert mode */
  EVENT_TABLEAVE,               /* before leaving a tab page */
  EVENT_TABENTER,               /* after entering a tab page */
  EVENT_SHELLCMDPOST,           /* after ":!cmd" */
  EVENT_SHELLFILTERPOST,        /* after ":1,2!cmd", ":w !cmd", ":r !cmd". */
  EVENT_TEXTCHANGED,            /* text was modified */
  EVENT_TEXTCHANGEDI,           /* text was modified in Insert mode*/
  NUM_EVENTS                    /* MUST be the last one */
};

typedef enum auto_event event_T;




/*
 * Struct to save values in before executing autocommands for a buffer that is
 * not the current buffer.
 */
typedef struct {
  buf_T       *save_curbuf;     /* saved curbuf */
  int use_aucmd_win;            /* using aucmd_win */
  win_T       *save_curwin;     /* saved curwin */
  win_T       *new_curwin;      /* new curwin */
  buf_T       *new_curbuf;      /* new curbuf */
  char_u      *globaldir;       /* saved value of globaldir */
} aco_save_T;

/* fileio.c */
void filemess(buf_T *buf, char_u *name, char_u *s, int attr);
int readfile(char_u *fname, char_u *sfname, linenr_T from,
             linenr_T lines_to_skip, linenr_T lines_to_read, exarg_T *eap,
             int flags);
void prep_exarg(exarg_T *eap, buf_T *buf);
void set_file_options(int set_options, exarg_T *eap);
void set_forced_fenc(exarg_T *eap);
int buf_write(buf_T *buf, char_u *fname, char_u *sfname, linenr_T start,
              linenr_T end, exarg_T *eap, int append, int forceit,
              int reset_changed,
              int filtering);
void msg_add_fname(buf_T *buf, char_u *fname);
void msg_add_lines(int insert_space, long lnum, off_t nchars);
void shorten_fnames(int force);
char_u *modname(char_u *fname, char_u *ext, int prepend_dot);
int vim_fgets(char_u *buf, int size, FILE *fp);
int tag_fgets(char_u *buf, int size, FILE *fp);
int vim_rename(char_u *from, char_u *to);
int check_timestamps(int focus);
int buf_check_timestamp(buf_T *buf, int focus);
void buf_reload(buf_T *buf, int orig_mode);
void buf_store_file_info(buf_T *buf, FileInfo *file_info);
void write_lnum_adjust(linenr_T offset);
void vim_deltempdir(void);
char_u *vim_tempname(int extra_char);
void forward_slash(char_u *fname);
void aubuflocal_remove(buf_T *buf);
int au_has_group(char_u *name);
void do_augroup(char_u *arg, int del_group);
void free_all_autocmds(void);
int check_ei(void);
char_u *au_event_disable(char *what);
void au_event_restore(char_u *old_ei);
void do_autocmd(char_u *arg, int forceit);
int do_doautocmd(char_u *arg, int do_msg);
void ex_doautoall(exarg_T *eap);
int check_nomodeline(char_u **argp);
void aucmd_prepbuf(aco_save_T *aco, buf_T *buf);
void aucmd_restbuf(aco_save_T *aco);
int apply_autocmds(event_T event, char_u *fname, char_u *fname_io,
                   int force,
                   buf_T *buf);
int apply_autocmds_retval(event_T event, char_u *fname, char_u *fname_io,
                          int force, buf_T *buf,
                          int *retval);
int has_cursorhold(void);
int trigger_cursorhold(void);
int has_cursormoved(void);
int has_cursormovedI(void);
int has_textchanged(void);
int has_textchangedI(void);
int has_insertcharpre(void);
void block_autocmds(void);
void unblock_autocmds(void);
char_u *getnextac(int c, void *cookie, int indent);
int has_autocmd(event_T event, char_u *sfname, buf_T *buf);
char_u *get_augroup_name(expand_T *xp, int idx);
char_u *set_context_in_autocmd(expand_T *xp, char_u *arg, int doautocmd);
char_u *get_event_name(expand_T *xp, int idx);
int autocmd_supported(char_u *name);
int au_exists(char_u *arg);
int match_file_pat(char_u *pattern, regprog_T *prog, char_u *fname,
                   char_u *sfname, char_u *tail,
                   int allow_dirs);
int match_file_list(char_u *list, char_u *sfname, char_u *ffname);
char_u *file_pat_to_reg_pat(char_u *pat, char_u *pat_end,
                            char *allow_dirs,
                            int no_bslash);
long read_eintr(int fd, void *buf, size_t bufsize);
long write_eintr(int fd, void *buf, size_t bufsize);

#endif /* NVIM_FILEIO_H */
