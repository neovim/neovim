#ifndef NEOVIM_EX_EVAL_H
#define NEOVIM_EX_EVAL_H

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

/* ex_eval.c */
int aborting(void);
void update_force_abort(void);
int should_abort(int retcode);
int aborted_in_try(void);
int cause_errthrow(char_u *mesg, int severe, int *ignore);
void free_global_msglist(void);
void do_errthrow(struct condstack *cstack, char_u *cmdname);
int do_intthrow(struct condstack *cstack);
char_u *get_exception_string(void *value, int type, char_u *cmdname,
                             int *should_free);
void discard_current_exception(void);
void report_make_pending(int pending, void *value);
void report_resume_pending(int pending, void *value);
void report_discard_pending(int pending, void *value);
void ex_if(exarg_T *eap);
void ex_endif(exarg_T *eap);
void ex_else(exarg_T *eap);
void ex_while(exarg_T *eap);
void ex_continue(exarg_T *eap);
void ex_break(exarg_T *eap);
void ex_endwhile(exarg_T *eap);
void ex_throw(exarg_T *eap);
void do_throw(struct condstack *cstack);
void ex_try(exarg_T *eap);
void ex_catch(exarg_T *eap);
void ex_finally(exarg_T *eap);
void ex_endtry(exarg_T *eap);
void enter_cleanup(cleanup_T *csp);
void leave_cleanup(cleanup_T *csp);
int cleanup_conditionals(struct condstack *cstack, int searched_cond,
                         int inclusive);
void rewind_conditionals(struct condstack *cstack, int idx,
                         int cond_type,
                         int *cond_level);
void ex_endfunction(exarg_T *eap);
int has_loop_cmd(char_u *p);
/* vim: set ft=c : */
#endif /* NEOVIM_EX_EVAL_H */
