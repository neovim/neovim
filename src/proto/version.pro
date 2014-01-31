/* version.c */
void make_version __ARGS((void));
int highest_patch __ARGS((void));
int has_patch __ARGS((int n));
void ex_version __ARGS((exarg_T *eap));
void list_version __ARGS((void));
void maybe_intro_message __ARGS((void));
void intro_message __ARGS((int colon));
void ex_intro __ARGS((exarg_T *eap));
/* vim: set ft=c : */
