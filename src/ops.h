#ifndef NEOVIM_OPS_H
#define NEOVIM_OPS_H
/* ops.c */
int get_op_type __ARGS((int char1, int char2));
int op_on_lines __ARGS((int op));
int get_op_char __ARGS((int optype));
int get_extra_op_char __ARGS((int optype));
void op_shift __ARGS((oparg_T *oap, int curs_top, int amount));
void shift_line __ARGS((int left, int round, int amount, int call_changed_bytes));
void op_reindent __ARGS((oparg_T *oap, int (*how)(void)));
int get_expr_register __ARGS((void));
void set_expr_line __ARGS((char_u *new_line));
char_u *get_expr_line __ARGS((void));
char_u *get_expr_line_src __ARGS((void));
int valid_yank_reg __ARGS((int regname, int writing));
void get_yank_register __ARGS((int regname, int writing));
int may_get_selection __ARGS((int regname));
void *get_register __ARGS((int name, int copy));
void put_register __ARGS((int name, void *reg));
void free_register __ARGS((void *reg));
int yank_register_mline __ARGS((int regname));
int do_record __ARGS((int c));
int do_execreg __ARGS((int regname, int colon, int addcr, int silent));
int insert_reg __ARGS((int regname, int literally));
int get_spec_reg __ARGS((int regname, char_u **argp, int *allocated, int errmsg));
int cmdline_paste_reg __ARGS((int regname, int literally, int remcr));
void adjust_clip_reg __ARGS((int *rp));
int op_delete __ARGS((oparg_T *oap));
int op_replace __ARGS((oparg_T *oap, int c));
void op_tilde __ARGS((oparg_T *oap));
int swapchar __ARGS((int op_type, pos_T *pos));
void op_insert __ARGS((oparg_T *oap, long count1));
int op_change __ARGS((oparg_T *oap));
void init_yank __ARGS((void));
void clear_registers __ARGS((void));
int op_yank __ARGS((oparg_T *oap, int deleting, int mess));
void do_put __ARGS((int regname, int dir, long count, int flags));
void adjust_cursor_eol __ARGS((void));
int preprocs_left __ARGS((void));
int get_register_name __ARGS((int num));
void ex_display __ARGS((exarg_T *eap));
int do_join __ARGS((long count, int insert_space, int save_undo,
                    int use_formatoptions));
void op_format __ARGS((oparg_T *oap, int keep_cursor));
void op_formatexpr __ARGS((oparg_T *oap));
int fex_format __ARGS((linenr_T lnum, long count, int c));
void format_lines __ARGS((linenr_T line_count, int avoid_fex));
int paragraph_start __ARGS((linenr_T lnum));
int do_addsub __ARGS((int command, linenr_T Prenum1));
int read_viminfo_register __ARGS((vir_T *virp, int force));
void write_viminfo_registers __ARGS((FILE *fp));
void x11_export_final_selection __ARGS((void));
void clip_free_selection __ARGS((VimClipboard *cbd));
void clip_get_selection __ARGS((VimClipboard *cbd));
void clip_yank_selection __ARGS((int type, char_u *str, long len,
                                 VimClipboard *cbd));
int clip_convert_selection __ARGS((char_u **str, long_u *len, VimClipboard *cbd));
void dnd_yank_drag_data __ARGS((char_u *str, long len));
char_u get_reg_type __ARGS((int regname, long *reglen));
char_u *get_reg_contents __ARGS((int regname, int allowexpr, int expr_src));
void write_reg_contents __ARGS((int name, char_u *str, int maxlen,
                                int must_append));
void write_reg_contents_ex __ARGS((int name, char_u *str, int maxlen,
                                   int must_append, int yank_type,
                                   long block_len));
void clear_oparg __ARGS((oparg_T *oap));
void cursor_pos_info __ARGS((void));
/* vim: set ft=c : */
#endif /* NEOVIM_OPS_H */
