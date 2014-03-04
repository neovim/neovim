#ifndef NEOVIM_GETCHAR_H
#define NEOVIM_GETCHAR_H
/* getchar.c */
void free_buff(struct buffheader *buf);
char_u *get_recorded(void);
char_u *get_inserted(void);
int stuff_empty(void);
void typeahead_noflush(int c);
void flush_buffers(int flush_typeahead);
void ResetRedobuff(void);
void CancelRedo(void);
void saveRedobuff(void);
void restoreRedobuff(void);
void AppendToRedobuff(char_u *s);
void AppendToRedobuffLit(char_u *str, int len);
void AppendCharToRedobuff(int c);
void AppendNumberToRedobuff(long n);
void stuffReadbuff(char_u *s);
void stuffReadbuffLen(char_u *s, long len);
void stuffReadbuffSpec(char_u *s);
void stuffcharReadbuff(int c);
void stuffnumReadbuff(long n);
int start_redo(long count, int old_redo);
int start_redo_ins(void);
void stop_redo_ins(void);
int ins_typebuf(char_u *str, int noremap, int offset, int nottyped,
                int silent);
void ins_char_typebuf(int c);
int typebuf_changed(int tb_change_cnt);
int typebuf_typed(void);
int typebuf_maplen(void);
void del_typebuf(int len, int offset);
int alloc_typebuf(void);
void free_typebuf(void);
int save_typebuf(void);
void save_typeahead(tasave_T *tp);
void restore_typeahead(tasave_T *tp);
void openscript(char_u *name, int directly);
void close_all_scripts(void);
int using_script(void);
void before_blocking(void);
void updatescript(int c);
int vgetc(void);
int safe_vgetc(void);
int plain_vgetc(void);
int vpeekc(void);
int vpeekc_nomap(void);
int vpeekc_any(void);
int char_avail(void);
void vungetc(int c);
int inchar(char_u *buf, int maxlen, long wait_time, int tb_change_cnt);
int fix_input_buffer(char_u *buf, int len, int script);
int input_available(void);
int do_map(int maptype, char_u *arg, int mode, int abbrev);
int get_map_mode(char_u **cmdp, int forceit);
void map_clear(char_u *cmdp, char_u *arg, int forceit, int abbr);
void map_clear_int(buf_T *buf, int mode, int local, int abbr);
char_u *map_mode_to_chars(int mode);
int map_to_exists(char_u *str, char_u *modechars, int abbr);
int map_to_exists_mode(char_u *rhs, int mode, int abbr);
char_u *set_context_in_map_cmd(expand_T *xp, char_u *cmd, char_u *arg,
                               int forceit, int isabbrev, int isunmap,
                               cmdidx_T cmdidx);
int ExpandMappings(regmatch_T *regmatch, int *num_file, char_u ***file);
int check_abbr(int c, char_u *ptr, int col, int mincol);
char_u *vim_strsave_escape_csi(char_u *p);
void vim_unescape_csi(char_u *p);
int makemap(FILE *fd, buf_T *buf);
int put_escstr(FILE *fd, char_u *strstart, int what);
void check_map_keycodes(void);
char_u *check_map(char_u *keys, int mode, int exact, int ign_mod,
                  int abbr, mapblock_T **mp_ptr,
                  int *local_ptr);
void init_mappings(void);
void add_map(char_u *map, int mode);
/* vim: set ft=c : */
#endif /* NEOVIM_GETCHAR_H */
