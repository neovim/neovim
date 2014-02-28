#ifndef NEOVIM_GARRAY_H
#define NEOVIM_GARRAY_H

void ga_clear __ARGS((garray_T *gap));
void ga_clear_strings __ARGS((garray_T *gap));
void ga_init __ARGS((garray_T *gap));
void ga_init2 __ARGS((garray_T *gap, int itemsize, int growsize));
int ga_grow __ARGS((garray_T *gap, int n));
char_u *ga_concat_strings __ARGS((garray_T const *const gap));
void ga_concat __ARGS((garray_T *gap, char_u const *const s));
void ga_append __ARGS((garray_T *gap, int c));
void append_ga_line __ARGS((garray_T *gap));

#endif /* NEOVIM_GARRAY_H */
