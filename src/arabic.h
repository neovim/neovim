#ifndef NEOVIM_ARABIC_H
#define NEOVIM_ARABIC_H

/// Whether c belongs to the range of Arabic characters that might be shaped.
static inline int arabic_char(int c)
{
    // return c >= a_HAMZA && c <= a_MINI_ALEF;
    return c >= 0x0621 && c <= 0x0670;
}

int arabic_shape(int c, int *ccp, int *c1p, int prev_c, int prev_c1,
                 int next_c);
int arabic_combine(int one, int two);
int arabic_maycombine(int two);

#endif  // NEOVIM_ARABIC_H
