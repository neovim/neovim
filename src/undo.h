#ifndef NEOVIM_UNDO_H
#define NEOVIM_UNDO_H
/* undo.c */
int u_save_cursor(void);
int u_save(linenr_T top, linenr_T bot);
int u_savesub(linenr_T lnum);
int u_inssub(linenr_T lnum);
int u_savedel(linenr_T lnum, long nlines);
int undo_allowed(void);
int u_savecommon(linenr_T top, linenr_T bot, linenr_T newbot,
                 int reload);
void u_compute_hash(char_u *hash);
char_u *u_get_undo_file_name(char_u *buf_ffname, int reading);
void u_write_undo(char_u *name, int forceit, buf_T *buf, char_u *hash);
void u_read_undo(char_u *name, char_u *hash, char_u *orig_name);
void u_undo(int count);
void u_redo(int count);
void undo_time(long step, int sec, int file, int absolute);
void u_sync(int force);
void ex_undolist(exarg_T *eap);
void ex_undojoin(exarg_T *eap);
void u_unchanged(buf_T *buf);
void u_find_first_changed(void);
void u_update_save_nr(buf_T *buf);
void u_clearall(buf_T *buf);
void u_saveline(linenr_T lnum);
void u_clearline(void);
void u_undoline(void);
void u_blockfree(buf_T *buf);
int bufIsChanged(buf_T *buf);
int curbufIsChanged(void);
void u_eval_tree(u_header_T *first_uhp, list_T *list);
/* vim: set ft=c : */
#endif /* NEOVIM_UNDO_H */
