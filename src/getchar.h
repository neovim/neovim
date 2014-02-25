#ifndef NEOVIM_GETCHAR_H
#define NEOVIM_GETCHAR_H
/* getchar.c */
void free_buff __ARGS((struct buffheader *buf));
char_u *get_recorded __ARGS((void));
char_u *get_inserted __ARGS((void));
int stuff_empty __ARGS((void));
void typeahead_noflush __ARGS((int c));
void flush_buffers __ARGS((int flush_typeahead));
void ResetRedobuff __ARGS((void));
void CancelRedo __ARGS((void));
void saveRedobuff __ARGS((void));
void restoreRedobuff __ARGS((void));
void AppendToRedobuff __ARGS((char_u *s));
void AppendToRedobuffLit __ARGS((char_u *str, int len));
void AppendCharToRedobuff __ARGS((int c));
void AppendNumberToRedobuff __ARGS((long n));
void stuffReadbuff __ARGS((char_u *s));
void stuffReadbuffLen __ARGS((char_u *s, long len));
void stuffReadbuffSpec __ARGS((char_u *s));
void stuffcharReadbuff __ARGS((int c));
void stuffnumReadbuff __ARGS((long n));
int start_redo __ARGS((long count, int old_redo));
int start_redo_ins __ARGS((void));
void stop_redo_ins __ARGS((void));
int ins_typebuf __ARGS((char_u *str, int noremap, int offset, int nottyped,
                        int silent));
void ins_char_typebuf __ARGS((int c));
int typebuf_changed __ARGS((int tb_change_cnt));
int typebuf_typed __ARGS((void));
int typebuf_maplen __ARGS((void));
void del_typebuf __ARGS((int len, int offset));
int alloc_typebuf __ARGS((void));
void free_typebuf __ARGS((void));
int save_typebuf __ARGS((void));
void save_typeahead __ARGS((tasave_T *tp));
void restore_typeahead __ARGS((tasave_T *tp));
void openscript __ARGS((char_u *name, int directly));
void close_all_scripts __ARGS((void));
int using_script __ARGS((void));
void before_blocking __ARGS((void));
void updatescript __ARGS((int c));
int vgetc __ARGS((void));
int safe_vgetc __ARGS((void));
int plain_vgetc __ARGS((void));
int vpeekc __ARGS((void));
int vpeekc_nomap __ARGS((void));
int vpeekc_any __ARGS((void));
int char_avail __ARGS((void));
void vungetc __ARGS((int c));
int inchar __ARGS((char_u *buf, int maxlen, long wait_time, int tb_change_cnt));
int fix_input_buffer __ARGS((char_u *buf, int len, int script));
int input_available __ARGS((void));
int do_map __ARGS((int maptype, char_u *arg, int mode, int abbrev));
int get_map_mode __ARGS((char_u **cmdp, int forceit));
void map_clear __ARGS((char_u *cmdp, char_u *arg, int forceit, int abbr));
void map_clear_int __ARGS((buf_T *buf, int mode, int local, int abbr));
char_u *map_mode_to_chars __ARGS((int mode));
int map_to_exists __ARGS((char_u *str, char_u *modechars, int abbr));
int map_to_exists_mode __ARGS((char_u *rhs, int mode, int abbr));
char_u *set_context_in_map_cmd __ARGS((expand_T *xp, char_u *cmd, char_u *arg,
                                       int forceit, int isabbrev, int isunmap,
                                       cmdidx_T cmdidx));
int ExpandMappings __ARGS((regmatch_T *regmatch, int *num_file, char_u ***file));
int check_abbr __ARGS((int c, char_u *ptr, int col, int mincol));
char_u *vim_strsave_escape_csi __ARGS((char_u *p));
void vim_unescape_csi __ARGS((char_u *p));
int makemap __ARGS((FILE *fd, buf_T *buf));
int put_escstr __ARGS((FILE *fd, char_u *strstart, int what));
void check_map_keycodes __ARGS((void));
char_u *check_map __ARGS((char_u *keys, int mode, int exact, int ign_mod,
                          int abbr, mapblock_T **mp_ptr,
                          int *local_ptr));
void init_mappings __ARGS((void));
void add_map __ARGS((char_u *map, int mode));
/* vim: set ft=c : */
#endif /* NEOVIM_GETCHAR_H */
