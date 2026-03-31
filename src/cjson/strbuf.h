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

#include <stdlib.h>
#include <stdarg.h>

/* Workaround for MSVC */
#ifdef _MSC_VER
#define inline __inline
#endif

/* Size: Total bytes allocated to *buf
 * Length: String length, excluding optional NULL terminator.
 * Dynamic: True if created via strbuf_new()
 */

typedef struct {
    char *buf;
    size_t size;
    size_t length;
    int dynamic;
    int reallocs;
    int debug;
} strbuf_t;

#ifndef STRBUF_DEFAULT_SIZE
#define STRBUF_DEFAULT_SIZE 1023
#endif

/* Initialise */
extern strbuf_t *strbuf_new(size_t len);
extern void strbuf_init(strbuf_t *s, size_t len);

/* Release */
extern void strbuf_free(strbuf_t *s);
extern char *strbuf_free_to_string(strbuf_t *s, size_t *len);

/* Management */
extern void strbuf_resize(strbuf_t *s, size_t len);
static size_t strbuf_empty_length(strbuf_t *s);
static size_t strbuf_length(strbuf_t *s);
static char *strbuf_string(strbuf_t *s, size_t *len);
static void strbuf_ensure_empty_length(strbuf_t *s, size_t len);
static char *strbuf_empty_ptr(strbuf_t *s);
static void strbuf_extend_length(strbuf_t *s, size_t len);
static void strbuf_set_length(strbuf_t *s, int len);

/* Update */
static void strbuf_append_mem(strbuf_t *s, const char *c, size_t len);
extern void strbuf_append_string(strbuf_t *s, const char *str);
static void strbuf_append_char(strbuf_t *s, const char c);
static void strbuf_ensure_null(strbuf_t *s);

/* Reset string for before use */
static inline void strbuf_reset(strbuf_t *s)
{
    s->length = 0;
}

static inline int strbuf_allocated(strbuf_t *s)
{
    return s->buf != NULL;
}

/* Return bytes remaining in the string buffer
 * Ensure there is space for a NULL terminator. */
static inline size_t strbuf_empty_length(strbuf_t *s)
{
    return s->size - s->length - 1;
}

static inline void strbuf_ensure_empty_length(strbuf_t *s, size_t len)
{
    if (len > strbuf_empty_length(s))
        strbuf_resize(s, s->length + len);
}

static inline char *strbuf_empty_ptr(strbuf_t *s)
{
    return s->buf + s->length;
}

static inline void strbuf_set_length(strbuf_t *s, int len)
{
    s->length = len;
}

static inline void strbuf_extend_length(strbuf_t *s, size_t len)
{
    s->length += len;
}

static inline size_t strbuf_length(strbuf_t *s)
{
    return s->length;
}

static inline void strbuf_append_char(strbuf_t *s, const char c)
{
    strbuf_ensure_empty_length(s, 1);
    s->buf[s->length++] = c;
}

static inline void strbuf_append_char_unsafe(strbuf_t *s, const char c)
{
    s->buf[s->length++] = c;
}

static inline void strbuf_append_mem(strbuf_t *s, const char *c, size_t len)
{
    strbuf_ensure_empty_length(s, len);
    memcpy(s->buf + s->length, c, len);
    s->length += len;
}

static inline void strbuf_append_mem_unsafe(strbuf_t *s, const char *c, size_t len)
{
    memcpy(s->buf + s->length, c, len);
    s->length += len;
}

static inline void strbuf_ensure_null(strbuf_t *s)
{
    s->buf[s->length] = 0;
}

static inline char *strbuf_string(strbuf_t *s, size_t *len)
{
    if (len)
        *len = s->length;

    return s->buf;
}

/* vi:ai et sw=4 ts=4:
 */
