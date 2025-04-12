/* strbuf - String buffer routines
 *
 * Copyright (c) 2010-2012  Mark Pulford <mark@kyne.com.au>
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

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <stdint.h>

#include "strbuf.h"

static void die(const char *fmt, ...)
{
    va_list arg;

    va_start(arg, fmt);
    vfprintf(stderr, fmt, arg);
    va_end(arg);
    fprintf(stderr, "\n");

    exit(-1);
}

void strbuf_init(strbuf_t *s, size_t len)
{
    size_t size;

    if (!len)
        size = STRBUF_DEFAULT_SIZE;
    else
        size = len + 1;         /* \0 terminator */
    if (size < len)
        die("Overflow, len %zu", len);
    s->buf = NULL;
    s->size = size;
    s->length = 0;
    s->dynamic = 0;
    s->reallocs = 0;
    s->debug = 0;

    s->buf = (char *)malloc(size);
    if (!s->buf)
        die("Out of memory");

    strbuf_ensure_null(s);
}

strbuf_t *strbuf_new(size_t len)
{
    strbuf_t *s;

    s = (strbuf_t*)malloc(sizeof(strbuf_t));
    if (!s)
        die("Out of memory");

    strbuf_init(s, len);

    /* Dynamic strbuf allocation / deallocation */
    s->dynamic = 1;

    return s;
}

static inline void debug_stats(strbuf_t *s)
{
    if (s->debug) {
        fprintf(stderr, "strbuf(%lx) reallocs: %d, length: %zd, size: %zd\n",
                (long)s, s->reallocs, s->length, s->size);
    }
}

/* If strbuf_t has not been dynamically allocated, strbuf_free() can
 * be called any number of times strbuf_init() */
void strbuf_free(strbuf_t *s)
{
    debug_stats(s);

    if (s->buf) {
        free(s->buf);
        s->buf = NULL;
    }
    if (s->dynamic)
        free(s);
}

char *strbuf_free_to_string(strbuf_t *s, size_t *len)
{
    char *buf;

    debug_stats(s);

    strbuf_ensure_null(s);

    buf = s->buf;
    if (len)
        *len = s->length;

    if (s->dynamic)
        free(s);

    return buf;
}

static size_t calculate_new_size(strbuf_t *s, size_t len)
{
    size_t reqsize, newsize;

    if (len <= 0)
        die("BUG: Invalid strbuf length requested");

    /* Ensure there is room for optional NULL termination */
    reqsize = len + 1;
    if (reqsize < len)
        die("Overflow, len %zu", len);

    /* If the user has requested to shrink the buffer, do it exactly */
    if (s->size > reqsize)
        return reqsize;

    newsize = s->size;
    if (reqsize >= SIZE_MAX / 2) {
        newsize = reqsize;
    } else {
        /* Exponential sizing */
        while (newsize < reqsize)
            newsize *= 2;
    }

    if (newsize < reqsize)
        die("BUG: strbuf length would overflow, len: %zu", len);


    return newsize;
}


/* Ensure strbuf can handle a string length bytes long (ignoring NULL
 * optional termination). */
void strbuf_resize(strbuf_t *s, size_t len)
{
    size_t newsize;

    newsize = calculate_new_size(s, len);

    if (s->debug > 1) {
        fprintf(stderr, "strbuf(%lx) resize: %zd => %zd\n",
                (long)s, s->size, newsize);
    }

    s->size = newsize;
    s->buf = (char *)realloc(s->buf, s->size);
    if (!s->buf)
        die("Out of memory, len: %zu", len);
    s->reallocs++;
}

void strbuf_append_string(strbuf_t *s, const char *str)
{
    int i;
    size_t space;

    space = strbuf_empty_length(s);

    for (i = 0; str[i]; i++) {
        if (space < 1) {
            strbuf_resize(s, s->length + 1);
            space = strbuf_empty_length(s);
        }

        s->buf[s->length] = str[i];
        s->length++;
        space--;
    }
}

/* vi:ai et sw=4 ts=4:
 */
