/*
 *  LibXDiff by Davide Libenzi ( File Differential Library )
 *  Copyright (C) 2003  Davide Libenzi
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, see
 *  <http://www.gnu.org/licenses/>.
 *
 *  Davide Libenzi <davidel@xmailserver.org>
 *
 */

#if !defined(XMACROS_H)
#define XMACROS_H




#define XDL_MIN(a, b) ((a) < (b) ? (a): (b))
#define XDL_MAX(a, b) ((a) > (b) ? (a): (b))
#define XDL_ABS(v) ((v) >= 0 ? (v): -(v))
#define XDL_ISDIGIT(c) ((c) >= '0' && (c) <= '9')
#define XDL_ISSPACE(c) (isspace((unsigned char)(c)))
#define XDL_ADDBITS(v,b)	((v) + ((v) >> (b)))
#define XDL_MASKBITS(b)		((1UL << (b)) - 1)
#define XDL_HASHLONG(v,b)	(XDL_ADDBITS((unsigned long)(v), b) & XDL_MASKBITS(b))
#define XDL_PTRFREE(p) do { if (p) { xdl_free(p); (p) = NULL; } } while (0)
#define XDL_LE32_PUT(p, v) \
do { \
	unsigned char *__p = (unsigned char *) (p); \
	*__p++ = (unsigned char) (v); \
	*__p++ = (unsigned char) ((v) >> 8); \
	*__p++ = (unsigned char) ((v) >> 16); \
	*__p = (unsigned char) ((v) >> 24); \
} while (0)
#define XDL_LE32_GET(p, v) \
do { \
	unsigned char const *__p = (unsigned char const *) (p); \
	(v) = (unsigned long) __p[0] | ((unsigned long) __p[1]) << 8 | \
		((unsigned long) __p[2]) << 16 | ((unsigned long) __p[3]) << 24; \
} while (0)


#endif /* #if !defined(XMACROS_H) */
