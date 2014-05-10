static void report_pending(int action, int pending, void *value);
static void discard_exception(except_T *excp, int was_finished);
static void finish_exception(except_T *excp);
static void catch_exception(except_T *excp);
static char_u   *get_end_emsg(struct condstack *cstack);
static int throw_exception(void *, int, char_u *);
static void free_msglist(struct msglist *l);
