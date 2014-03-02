#ifndef NEOVIM_HANGULIN_H
#define NEOVIM_HANGULIN_H
/* hangulin.c */
int hangul_input_state_get(void);
void hangul_input_state_set(int state);
int im_get_status(void);
void hangul_input_state_toggle(void);
void hangul_keyboard_set(void);
int hangul_input_process(char_u *s, int len);
void hangul_input_clear(void);
/* vim: set ft=c : */
#endif /* NEOVIM_HANGULIN_H */
