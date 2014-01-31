/* hangulin.c */
int hangul_input_state_get __ARGS((void));
void hangul_input_state_set __ARGS((int state));
int im_get_status __ARGS((void));
void hangul_input_state_toggle __ARGS((void));
void hangul_keyboard_set __ARGS((void));
int hangul_input_process __ARGS((char_u *s, int len));
void hangul_input_clear __ARGS((void));
/* vim: set ft=c : */
