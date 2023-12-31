// fpconv.h
#ifndef FPCONV_H
#define FPCONV_H

/* Buffer required to store the largest string representation of a double.
 *
 * Longest double printed with %.14g is 21 characters long:
 * -1.7976931348623e+308 */
#define FPCONV_G_FMT_BUFSIZE   32

#ifdef USE_INTERNAL_FPCONV
static inline void fpconv_init(void) {
    /* Do nothing - not required */
}
#else
extern void fpconv_init(void);
#endif

extern int fpconv_g_fmt(char *str, double num, int precision);
extern double fpconv_strtod(const char *nptr, char **endptr);

extern char locale_decimal_point;

#endif // FPCONV_H
