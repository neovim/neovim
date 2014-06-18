/* The MIT License

   Copyright (c) 2008, by Attractive Chaos <attractor@live.co.uk>

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

/*
  An example:

#include "kvec.h"
int main() {
	kvec_t(int) array;
	kv_init(array);
	kv_push(int, array, 10); // append
	kv_a(int, array, 20) = 5; // dynamic
	kv_A(array, 20) = 4; // static
	kv_destroy(array);
	return 0;
}
*/

/*
  2008-09-22 (0.1.0):

	* The initial version.

*/

#ifndef AC_KVEC_H
#define AC_KVEC_H

#include <stdlib.h>
#include "nvim/memory.h"

#define kv_roundup32(x) (--(x), (x)|=(x)>>1, (x)|=(x)>>2, (x)|=(x)>>4, (x)|=(x)>>8, (x)|=(x)>>16, ++(x))

#define kvec_t(type) struct { size_t size, capacity; type *items; }
#define kv_init(v) ((v).size = (v).capacity = 0, (v).items = 0)
#define kv_destroy(v) free((v).items)
#define kv_A(v, i) ((v).items[(i)])
#define kv_pop(v) ((v).items[--(v).size])
#define kv_size(v) ((v).size)
#define kv_max(v) ((v).capacity)

#define kv_resize(type, v, s)  ((v).capacity = (s), (v).items = (type*)xrealloc((v).items, sizeof(type) * (v).capacity))

#define kv_copy(type, v1, v0) do {							\
		if ((v1).capacity < (v0).size) kv_resize(type, v1, (v0).size);	\
		(v1).size = (v0).size;									\
		memcpy((v1).items, (v0).items, sizeof(type) * (v0).size);		\
	} while (0)												\

#define kv_push(type, v, x) do {									\
		if ((v).size == (v).capacity) {										\
			(v).capacity = (v).capacity? (v).capacity<<1 : 8;							\
			(v).items = (type*)xrealloc((v).items, sizeof(type) * (v).capacity);	\
		}															\
		(v).items[(v).size++] = (x);										\
	} while (0)

#define kv_pushp(type, v) (((v).size == (v).capacity)?							\
						   ((v).capacity = ((v).capacity? (v).capacity<<1 : 8),				\
							(v).items = (type*)xrealloc((v).items, sizeof(type) * (v).capacity), 0)	\
						   : 0), ((v).items + ((v).size++))

#define kv_a(type, v, i) (((v).capacity <= (size_t)(i)? \
						  ((v).capacity = (v).size = (i) + 1, kv_roundup32((v).capacity), \
						   (v).items = (type*)xrealloc((v).items, sizeof(type) * (v).capacity), 0) \
						  : (v).size <= (size_t)(i)? (v).size = (i) + 1 \
						  : 0), (v).items[(i)])

#endif
