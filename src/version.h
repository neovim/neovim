#ifndef NEOVIM_VERSION_H
#define NEOVIM_VERSION_H

void make_version(void);
int highest_patch(void);
int has_patch(int n);
void ex_version(exarg_T *eap);
void list_version(void);
void maybe_intro_message(void);
void intro_message(int colon);
void ex_intro(exarg_T *eap);

#endif  // NEOVIM_VERSION_H
