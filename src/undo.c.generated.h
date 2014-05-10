static char_u *u_save_line(linenr_T);
static void put_header_ptr(FILE *fp, u_header_T *uhp);
static void unserialize_visualinfo(visualinfo_T *info, FILE *fp);
static void serialize_visualinfo(visualinfo_T *info, FILE *fp);
static void unserialize_pos(pos_T *pos, FILE *fp);
static void serialize_pos(pos_T pos, FILE *fp);
static u_entry_T *unserialize_uep(FILE *fp, int *error,
                                  char_u *file_name);
static int serialize_uep(FILE *fp, buf_T *buf, u_entry_T *uep);
static u_header_T *unserialize_uhp(FILE *fp, char_u *file_name);
static int serialize_uhp(FILE *fp, buf_T *buf, u_header_T *uhp);
static int serialize_header(FILE *fp, buf_T *buf, char_u *hash);
static char_u *read_string_decrypt(buf_T *buf, FILE *fd, int len);
static void u_free_uhp(u_header_T *uhp);
static void corruption_error(char *mesg, char_u *file_name);
static void u_freeentry(u_entry_T *, long);
static void u_freeentries(buf_T *buf, u_header_T *uhp,
                          u_header_T **uhpp);
static void u_freebranch(buf_T *buf, u_header_T *uhp, u_header_T **uhpp);
static void u_freeheader(buf_T *buf, u_header_T *uhp, u_header_T **uhpp);
static void u_undo_end(int did_undo, int absolute);
static void u_undoredo(int undo);
static void u_doit(int count);
static void u_getbot(void);
static u_entry_T *u_get_headentry(void);
static void u_unch_branch(u_header_T *uhp);
static long get_undolevel(void);
static size_t fwrite_crypt(buf_T *buf, char_u *ptr, size_t len,
                           FILE *fp);
static void u_add_time(char_u *buf, size_t buflen, time_t tt);
