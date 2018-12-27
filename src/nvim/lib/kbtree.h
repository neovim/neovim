/*-
 * Copyright 1997-1999, 2001, John-Mark Gurney.
 *           2008-2009, Attractive Chaos <attractor@live.co.uk>
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#ifndef NVIM_LIB_KBTREE_H
#define NVIM_LIB_KBTREE_H

#define	__KB_KEY(type, x)	(x->key)
#define __KB_PTR(btr, x)	(x->ptr)

#define kbtree_t(name) kbtree_t_##name
#define kbitr_t(name) kbitr_t_##name
#define kb_init(b) ((b)->n_keys = (b)->n_nodes = 0, (b)->root = 0)
#define kb_destroy(name, b) kb_destroy_##name(b)
#define kb_get(name, b, k) kb_get_##name(b, k)
#define kb_put(name, b, k) kb_put_##name(b, k)
#define kb_del(name, b, k) kb_del_##name(b, k)
#define kb_interval(name, b, k, l, u) kb_interval_##name(b, k, l, u)
#define kb_getp(name, b, k) kb_getp_##name(b, k)
#define kb_putp(name, b, k) kb_putp_##name(b, k)
#define kb_delp(name, b, k) kb_delp_##name(b, k)
#define kb_intervalp(name, b, k, l, u) kb_intervalp_##name(b, k, l, u)

#define kb_itr_first(name, b, i) kb_itr_first_##name(b, i)
#define kb_itr_get(name, b, k, i) kb_itr_get_##name(b, k, i)
#define kb_itr_getp(name, b, k, i) kb_itr_getp_##name(b, k, i)
#define kb_itr_next(name, b, i) kb_itr_next_##name(b, i)
#define kb_itr_prev(name, b, i) kb_itr_prev_##name(b, i)
#define kb_del_itr(name, b, i) kb_del_itr_##name(b, i)
#define kb_itr_key(itr) __KB_KEY(dummy, (itr)->p->x)[(itr)->p->i]
#define kb_itr_valid(itr) ((itr)->p >= (itr)->stack)

#define kb_size(b) ((b)->n_keys)

#define kb_generic_cmp(a, b) (((b) < (a)) - ((a) < (b)))
#define kb_str_cmp(a, b) strcmp(a, b)

#endif  // NVIM_LIB_KBTREE_H
