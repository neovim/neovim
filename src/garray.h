#ifndef NEOVIM_GARRAY_H
#define NEOVIM_GARRAY_H

/*
 * Structure used for growing arrays.
 * This is used to store information that only grows, is deleted all at
 * once, and needs to be accessed by index.  See ga_clear() and ga_grow().
 */
typedef struct growarray {
  int ga_len;                       /* current number of items used */
  int ga_maxlen;                    /* maximum number of items possible */
  int ga_itemsize;                  /* sizeof(item) */
  int ga_growsize;                  /* number of items to grow each time */
  void    *ga_data;                 /* pointer to the first item */
} garray_T;

#define GA_EMPTY    {0, 0, 0, 0, NULL}

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
