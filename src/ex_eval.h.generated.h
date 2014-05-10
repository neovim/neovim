int has_loop_cmd(char_u *p);
void ex_endfunction(exarg_T *eap);
void rewind_conditionals(struct condstack *cstack, int idx,
                         int cond_type,
                         int *cond_level);
int cleanup_conditionals(struct condstack *cstack, int searched_cond,
                         int inclusive);
void leave_cleanup(cleanup_T *csp);
void enter_cleanup(cleanup_T *csp);
void ex_endtry(exarg_T *eap);
void ex_finally(exarg_T *eap);
void ex_catch(exarg_T *eap);
void ex_try(exarg_T *eap);
void do_throw(struct condstack *cstack);
void ex_throw(exarg_T *eap);
void ex_endwhile(exarg_T *eap);
void ex_break(exarg_T *eap);
void ex_continue(exarg_T *eap);
void ex_while(exarg_T *eap);
void ex_else(exarg_T *eap);
void ex_endif(exarg_T *eap);
void ex_if(exarg_T *eap);
void report_discard_pending(int pending, void *value);
void report_resume_pending(int pending, void *value);
void report_make_pending(int pending, void *value);
void discard_current_exception(void);
char_u *get_exception_string(void *value, int type, char_u *cmdname,
                             int *should_free);
int do_intthrow(struct condstack *cstack);
void do_errthrow(struct condstack *cstack, char_u *cmdname);
void free_global_msglist(void);
int cause_errthrow(char_u *mesg, int severe, int *ignore);
int aborted_in_try(void);
int should_abort(int retcode);
void update_force_abort(void);
int aborting(void);
