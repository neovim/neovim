/* fpconv - Floating point conversion routines
 *
 * Copyright (c) 2011-2012  Mark Pulford <mark@kyne.com.au>
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

/* JSON uses a '.' decimal separator. strtod() / sprintf() under C libraries
 * with locale support will break when the decimal separator is a comma.
 *
 * fpconv_* will around these issues with a translation buffer if required.
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>

#include "fpconv.h"

/* Workaround for MSVC */
#ifdef _MSC_VER
#define inline __inline
#define snprintf sprintf_s
#endif

/* Lua CJSON assumes the locale is the same for all threads within a
 * process and doesn't change after initialisation.
 *
 * This avoids the need for per thread storage or expensive checks
 * for call. */
static char locale_decimal_point = '.';

/* In theory multibyte decimal_points are possible, but
 * Lua CJSON only supports UTF-8 and known locales only have
 * single byte decimal points ([.,]).
 *
 * localconv() may not be thread safe (=>crash), and nl_langinfo() is
 * not supported on some platforms. Use sprintf() instead - if the
 * locale does change, at least Lua CJSON won't crash. */
static void fpconv_update_locale()
{
    char buf[8];

    snprintf(buf, sizeof(buf), "%g", 0.5);

    /* Failing this test might imply the platform has a buggy dtoa
     * implementation or wide characters */
    if (buf[0] != '0' || buf[2] != '5' || buf[3] != 0) {
        fprintf(stderr, "Error: wide characters found or printf() bug.");
        abort();
    }

    locale_decimal_point = buf[1];
}

/* Check for a valid number character: [-+0-9a-yA-Y.]
 * Eg: -0.6e+5, infinity, 0xF0.F0pF0
 *
 * Used to find the probable end of a number. It doesn't matter if
 * invalid characters are counted - strtod() will find the valid
 * number if it exists.  The risk is that slightly more memory might
 * be allocated before a parse error occurs. */
static inline int valid_number_character(char ch)
{
    char lower_ch;

    if ('0' <= ch && ch <= '9')
        return 1;
    if (ch == '-' || ch == '+' || ch == '.')
        return 1;

    /* Hex digits, exponent (e), base (p), "infinity",.. */
    lower_ch = ch | 0x20;
    if ('a' <= lower_ch && lower_ch <= 'y')
        return 1;

    return 0;
}

/* Calculate the size of the buffer required for a strtod locale
 * conversion. */
static int strtod_buffer_size(const char *s)
{
    const char *p = s;

    while (valid_number_character(*p))
        p++;

    return p - s;
}

/* Similar to strtod(), but must be passed the current locale's decimal point
 * character. Guaranteed to be called at the start of any valid number in a string */
double fpconv_strtod(const char *nptr, char **endptr)
{
    char localbuf[FPCONV_G_FMT_BUFSIZE];
    char *buf, *endbuf, *dp;
    int buflen;
    double value;

    /* System strtod() is fine when decimal point is '.' */
    if (locale_decimal_point == '.')
        return strtod(nptr, endptr);

    buflen = strtod_buffer_size(nptr);
    if (!buflen) {
        /* No valid characters found, standard strtod() return */
        *endptr = (char *)nptr;
        return 0;
    }

    /* Duplicate number into buffer */
    if (buflen >= FPCONV_G_FMT_BUFSIZE) {
        /* Handle unusually large numbers */
        buf = malloc(buflen + 1);
        if (!buf) {
            fprintf(stderr, "Out of memory");
            abort();
        }
    } else {
        /* This is the common case.. */
        buf = localbuf;
    }
    memcpy(buf, nptr, buflen);
    buf[buflen] = 0;

    /* Update decimal point character if found */
    dp = strchr(buf, '.');
    if (dp)
        *dp = locale_decimal_point;

    value = strtod(buf, &endbuf);
    *endptr = (char *)&nptr[endbuf - buf];
    if (buflen >= FPCONV_G_FMT_BUFSIZE)
        free(buf);

    return value;
}

/* "fmt" must point to a buffer of at least 6 characters */
static void set_number_format(char *fmt, int precision)
{
    int d1, d2, i;

    assert(1 <= precision && precision <= 16);

    /* Create printf format (%.14g) from precision */
    d1 = precision / 10;
    d2 = precision % 10;
    fmt[0] = '%';
    fmt[1] = '.';
    i = 2;
    if (d1) {
        fmt[i++] = '0' + d1;
    }
    fmt[i++] = '0' + d2;
    fmt[i++] = 'g';
    fmt[i] = 0;
}

/* Assumes there is always at least 32 characters available in the target buffer */
int fpconv_g_fmt(char *str, double num, int precision)
{
    char buf[FPCONV_G_FMT_BUFSIZE];
    char fmt[6];
    int len;
    char *b;

    set_number_format(fmt, precision);

    /* Pass through when decimal point character is dot. */
    if (locale_decimal_point == '.')
        return snprintf(str, FPCONV_G_FMT_BUFSIZE, fmt, num);

    /* snprintf() to a buffer then translate for other decimal point characters */
    len = snprintf(buf, FPCONV_G_FMT_BUFSIZE, fmt, num);

    /* Copy into target location. Translate decimal point if required */
    b = buf;
    do {
        *str++ = (*b == locale_decimal_point ? '.' : *b);
    } while(*b++);

    return len;
}

void fpconv_init()
{
    fpconv_update_locale();
}

/* vi:ai et sw=4 ts=4:
 */
