void copy_viminfo_marks(vir_T *virp, FILE *fp_out, int count, int eof,
                        int flags);
int write_viminfo_marks(FILE *fp_out);
int removable(char_u *name);
void write_viminfo_filemarks(FILE *fp);
int read_viminfo_filemark(vir_T *virp, int force);
void set_last_cursor(win_T *win);
void free_jumplist(win_T *wp);
void copy_jumplist(win_T *from, win_T *to);
void mark_col_adjust(linenr_T lnum, colnr_T mincol, long lnum_amount,
                     long col_amount);
void mark_adjust(linenr_T line1, linenr_T line2, long amount,
                 long amount_after);
void ex_changes(exarg_T *eap);
void ex_jumps(exarg_T *eap);
void ex_delmarks(exarg_T *eap);
void do_marks(exarg_T *eap);
char_u *fm_getname(fmark_T *fmark, int lead_len);
void clrallmarks(buf_T *buf);
int check_mark(pos_T *pos);
void fmarks_check_names(buf_T *buf);
pos_T *getnextmark(pos_T *startpos, int dir, int begin_line);
pos_T *getmark_buf_fnum(buf_T *buf, int c, int changefile, int *fnum);
pos_T *getmark(int c, int changefile);
pos_T *getmark_buf(buf_T *buf, int c, int changefile);
pos_T *movechangelist(int count);
pos_T *movemark(int count);
void checkpcmark(void);
void setpcmark(void);
int setmark_pos(int c, pos_T *pos, int fnum);
int setmark(int c);
void free_all_marks(void);
