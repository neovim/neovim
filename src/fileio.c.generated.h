#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static linenr_T readfile_linenr(linenr_T linecnt, char_u *p, char_u *endp);
static char_u *next_fenc(char_u **pp);
static char_u *readfile_charconvert(char_u *fname, char_u *fenc, int *fdp);
static void check_marks_read(void);
static int crypt_method_from_magic(char *ptr, int len);
static char_u *check_for_cryptkey(char_u *cryptkey, char_u *ptr, long *sizep, off_t *filesizep, int newfile, char_u *fname, int *did_ask);
static void set_file_time(char_u *fname, time_t atime, time_t mtime);
static int set_rw_fname(char_u *fname, char_u *sfname);
static int msg_add_fileformat(int eol_type);
static void msg_add_eol(void);
static int check_mtime(buf_T *buf, struct stat *st);
static int time_differs(long t1, long t2);
static int buf_write_bytes(struct bw_info *ip);
static int ucs2bytes(unsigned c, char_u **pp, int flags);
static int need_conversion(char_u *fenc);
static int get_fio_flags(char_u *ptr);
static char_u *check_for_bom(char_u *p, long size, int *lenp, int flags);
static int make_bom(char_u *buf, char_u *name);
static int move_lines(buf_T *frombuf, buf_T *tobuf);
static void vim_settempdir(char_u *tempdir);
static void show_autocmd(AutoPat *ap, event_T event);
static void au_remove_pat(AutoPat *ap);
static void au_remove_cmds(AutoPat *ap);
static void au_cleanup(void);
static int au_new_group(char_u *name);
static void au_del_group(char_u *name);
static int au_find_group(char_u *name);
static event_T event_name2nr(char_u *start, char_u **end);
static char_u *event_nr2name(event_T event);
static char_u *find_end_event(char_u *arg, int have_group);
static int event_ignored(event_T event);
static int au_get_grouparg(char_u **argp);
static int do_autocmd_event(event_T event, char_u *pat, int nested, char_u *cmd, int forceit, int group);
static int apply_autocmds_exarg(event_T event, char_u *fname, char_u *fname_io, int force, buf_T *buf, exarg_T *eap);
static int apply_autocmds_group(event_T event, char_u *fname, char_u *fname_io, int force, int group, buf_T *buf, exarg_T *eap);
static void auto_next_pat(AutoPatCmd *apc, int stop_at_last);
#include "func_attr.h"
