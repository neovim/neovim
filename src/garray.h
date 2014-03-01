#ifndef NEOVIM_GARRAY_H
#define NEOVIM_GARRAY_H

void ga_clear(garray_T *gap);
void ga_clear_strings(garray_T *gap);
void ga_init(garray_T *gap);
void ga_init2(garray_T *gap, int itemsize, int growsize);
int ga_grow(garray_T *gap, int n);
char_u *ga_concat_strings(garray_T *gap);
void ga_concat(garray_T *gap, char_u *s);
void ga_append(garray_T *gap, int c);
void append_ga_line(garray_T *gap);

#endif /* NEOVIM_GARRAY_H */
