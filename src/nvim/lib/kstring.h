/* The MIT License

   Copyright (c) by Attractive Chaos <attractor@live.co.uk>

   Permission is hereby granted, free of charge, to any person obtaining
   a copy of this software and associated documentation files (the
   "Software"), to deal in the Software without restriction, including
   without limitation the rights to use, copy, modify, merge, publish,
   distribute, sublicense, and/or sell copies of the Software, and to
   permit persons to whom the Software is furnished to do so, subject to
   the following conditions:

   The above copyright notice and this permission notice shall be
   included in all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
   EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
   NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
   BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
   ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
   CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE.
*/

#ifndef KSTRING_H
#define KSTRING_H

#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>

#ifndef kroundup32
#define kroundup32(x) (--(x), (x)|=(x)>>1, (x)|=(x)>>2, (x)|=(x)>>4, (x)|=(x)>>8, (x)|=(x)>>16, ++(x))
#endif

#if __GNUC__ > 2 || (__GNUC__ == 2 && __GNUC_MINOR__ > 4)
#define KS_ATTR_PRINTF(fmt, arg) __attribute__((__format__ (__printf__, fmt, arg)))
#else
#define KS_ATTR_PRINTF(fmt, arg)
#endif


/* kstring_t is a simple non-opaque type whose fields are likely to be
 * used directly by user code (but see also ks_str() and ks_len() below).
 * A kstring_t object is initialised by either of
 *       kstring_t str = { 0, 0, NULL };
 *       kstring_t str; ...; str.l = str.m = 0; str.s = NULL;
 * and either ownership of the underlying buffer should be given away before
 * the object disappears (i.e., the str.s pointer copied and something else
 * responsible for freeing it), or the kstring_t should be destroyed with
 *       free(str.s);  */
#ifndef KSTRING_T
#define KSTRING_T kstring_t
typedef struct __kstring_t {
	size_t l, m;
	char *s;
} kstring_t;
#endif

typedef struct {
	uint64_t tab[4];
	int sep, finished;
	const char *p; // end of the current token
} ks_tokaux_t;

#ifdef __cplusplus
extern "C" {
#endif

	int kvsprintf(kstring_t *s, const char *fmt, va_list ap) KS_ATTR_PRINTF(2,0);
	int ksprintf(kstring_t *s, const char *fmt, ...) KS_ATTR_PRINTF(2,3);
	int ksplit_core(char *s, int delimiter, int *_max, int **_offsets);
	char *kstrstr(const char *str, const char *pat, int **_prep);
	char *kstrnstr(const char *str, const char *pat, int n, int **_prep);
	void *kmemmem(const void *_str, int n, const void *_pat, int m, int **_prep);

	/* kstrtok() is similar to strtok_r() except that str is not
	 * modified and both str and sep can be NULL. For efficiency, it is
	 * actually recommended to set both to NULL in the subsequent calls
	 * if sep is not changed. */
	char *kstrtok(const char *str, const char *sep, ks_tokaux_t *aux);

#ifdef __cplusplus
}
#endif

static inline int ks_resize(kstring_t *s, size_t size)
{
	if (s->m < size) {
		char *tmp;
		s->m = size;
		kroundup32(s->m);
		if ((tmp = (char*)realloc(s->s, s->m)))
			s->s = tmp;
		else
			return -1;
	}
	return 0;
}

static inline char *ks_str(kstring_t *s)
{
	return s->s;
}

static inline size_t ks_len(kstring_t *s)
{
	return s->l;
}

static inline int kputsn(const char *p, int l, kstring_t *s)
{
	if (s->l + l + 1 >= s->m) {
		char *tmp;
		s->m = s->l + l + 2;
		kroundup32(s->m);
		if ((tmp = (char*)realloc(s->s, s->m)))
			s->s = tmp;
		else
			return EOF;
	}
	memcpy(s->s + s->l, p, l);
	s->l += l;
	s->s[s->l] = 0;
	return l;
}

static inline int kputs(const char *p, kstring_t *s)
{
	return kputsn(p, strlen(p), s);
}

static inline int kputc(int c, kstring_t *s)
{
	if (s->l + 1 >= s->m) {
		char *tmp;
		s->m = s->l + 2;
		kroundup32(s->m);
		if ((tmp = (char*)realloc(s->s, s->m)))
			s->s = tmp;
		else
			return EOF;
	}
	s->s[s->l++] = c;
	s->s[s->l] = 0;
	return c;
}

static inline int kputc_(int c, kstring_t *s)
{
	if (s->l + 1 > s->m) {
		char *tmp;
		s->m = s->l + 1;
		kroundup32(s->m);
		if ((tmp = (char*)realloc(s->s, s->m)))
			s->s = tmp;
		else
			return EOF;
	}
	s->s[s->l++] = c;
	return 1;
}

static inline int kputsn_(const void *p, int l, kstring_t *s)
{
	if (s->l + l > s->m) {
		char *tmp;
		s->m = s->l + l;
		kroundup32(s->m);
		if ((tmp = (char*)realloc(s->s, s->m)))
			s->s = tmp;
		else
			return EOF;
	}
	memcpy(s->s + s->l, p, l);
	s->l += l;
	return l;
}

static inline int kputw(int c, kstring_t *s)
{
	char buf[16];
	int i, l = 0;
	unsigned int x = c;
	if (c < 0) x = -x;
	do { buf[l++] = x%10 + '0'; x /= 10; } while (x > 0);
	if (c < 0) buf[l++] = '-';
	if (s->l + l + 1 >= s->m) {
		char *tmp;
		s->m = s->l + l + 2;
		kroundup32(s->m);
		if ((tmp = (char*)realloc(s->s, s->m)))
			s->s = tmp;
		else
			return EOF;
	}
	for (i = l - 1; i >= 0; --i) s->s[s->l++] = buf[i];
	s->s[s->l] = 0;
	return 0;
}

static inline int kputuw(unsigned c, kstring_t *s)
{
	char buf[16];
	int l, i;
	unsigned x;
	if (c == 0) return kputc('0', s);
	for (l = 0, x = c; x > 0; x /= 10) buf[l++] = x%10 + '0';
	if (s->l + l + 1 >= s->m) {
		char *tmp;
		s->m = s->l + l + 2;
		kroundup32(s->m);
		if ((tmp = (char*)realloc(s->s, s->m)))
			s->s = tmp;
		else
			return EOF;
	}
	for (i = l - 1; i >= 0; --i) s->s[s->l++] = buf[i];
	s->s[s->l] = 0;
	return 0;
}

static inline int kputl(long c, kstring_t *s)
{
	char buf[32];
	int i, l = 0;
	unsigned long x = c;
	if (c < 0) x = -x;
	do { buf[l++] = x%10 + '0'; x /= 10; } while (x > 0);
	if (c < 0) buf[l++] = '-';
	if (s->l + l + 1 >= s->m) {
		char *tmp;
		s->m = s->l + l + 2;
		kroundup32(s->m);
		if ((tmp = (char*)realloc(s->s, s->m)))
			s->s = tmp;
		else
			return EOF;
	}
	for (i = l - 1; i >= 0; --i) s->s[s->l++] = buf[i];
	s->s[s->l] = 0;
	return 0;
}

/*
 * Returns 's' split by delimiter, with *n being the number of components;
 *         NULL on failue.
 */
static inline int *ksplit(kstring_t *s, int delimiter, int *n)
{
	int max = 0, *offsets = 0;
	*n = ksplit_core(s->s, delimiter, &max, &offsets);
	return offsets;
}

#endif
