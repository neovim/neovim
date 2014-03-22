#ifndef NEOVIM_ARABIC_H
#define NEOVIM_ARABIC_H

int arabic_char(int c);
int arabic_shape(int c, int *ccp, int *c1p, int prev_c, int prev_c1,
                 int next_c);
int arabic_combine(int one, int two);
int arabic_maycombine(int two);

#endif  // NEOVIM_ARABIC_H
