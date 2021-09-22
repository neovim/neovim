// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// Tree data structure for storing marks at (row, col) positions and updating
// them to arbitrary text changes. Derivative work of kbtree in klib, whose
// copyright notice is reproduced below. Also inspired by the design of the
// marker tree data structure of the Atom editor, regarding efficient updates
// to text changes.
//
// Marks are inserted using marktree_put. Text changes are processed using
// marktree_splice. All read and delete operations use the iterator.
// use marktree_itr_get to put an iterator at a given position or
// marktree_lookup to lookup a mark by its id (iterator optional in this case).
// Use marktree_itr_current and marktree_itr_next/prev to read marks in a loop.
// marktree_del_itr deletes the current mark of the iterator and implicitly
// moves the iterator to the next mark.
//
// Work is ongoing to fully support ranges (mark pairs).

// Copyright notice for kbtree (included in heavily modified form):
//
// Copyright 1997-1999, 2001, John-Mark Gurney.
//           2008-2009, Attractive Chaos <attractor@live.co.uk>
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
// OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
// LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
// OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
// SUCH DAMAGE.
//
// Changes done by by the neovim project follow the Apache v2 license available
// at the repo root.

#include <assert.h>

#include "nvim/garray.h"
#include "nvim/lib/kvec.h"
#include "nvim/marktree.h"

#define T MT_BRANCH_FACTOR
#define ILEN (sizeof(mtnode_t)+(2 * T) * sizeof(void *))

#define RIGHT_GRAVITY (((uint64_t)1) << 63)
#define ANTIGRAVITY(id) ((id)&(RIGHT_GRAVITY-1))
#define IS_RIGHT(id) ((id)&RIGHT_GRAVITY)

#define PAIRED MARKTREE_PAIRED_FLAG
#define END_FLAG MARKTREE_END_FLAG
#define ID_INCR (((uint64_t)1) << 2)

#define rawkey(itr) (itr->node->key[itr->i])

static bool pos_leq(mtpos_t a, mtpos_t b)
{
  return a.row < b.row || (a.row == b.row && a.col <= b.col);
}

static void relative(mtpos_t base, mtpos_t *val)
{
  assert(pos_leq(base, *val));
  if (val->row == base.row) {
    val->row = 0;
    val->col -= base.col;
  } else {
    val->row -= base.row;
  }
}

static void unrelative(mtpos_t base, mtpos_t *val)
{
  if (val->row == 0) {
    val->row = base.row;
    val->col += base.col;
  } else {
    val->row += base.row;
  }
}

static void compose(mtpos_t *base, mtpos_t val)
{
  if (val.row == 0) {
    base->col += val.col;
  } else {
    base->row += val.row;
    base->col = val.col;
  }
}

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "marktree.c.generated.h"
#endif

#define mt_generic_cmp(a, b) (((b) < (a)) - ((a) < (b)))
static int key_cmp(mtkey_t a, mtkey_t b)
{
  int cmp = mt_generic_cmp(a.pos.row, b.pos.row);
  if (cmp != 0) {
    return cmp;
  }
  cmp = mt_generic_cmp(a.pos.col, b.pos.col);
  if (cmp != 0) {
    return cmp;
  }
  // NB: keeping the events at the same pos sorted by id is actually not
  // necessary only make sure that START is before END etc.
  return mt_generic_cmp(a.id, b.id);
}

static inline int marktree_getp_aux(const mtnode_t *x, mtkey_t k, int *r)
{
  int tr, *rr, begin = 0, end = x->n;
  if (x->n == 0) {
    return -1;
  }
  rr = r? r : &tr;
  while (begin < end) {
    int mid = (begin + end) >> 1;
    if (key_cmp(x->key[mid], k) < 0) {
      begin = mid + 1;
    } else {
      end = mid;
    }
  }
  if (begin == x->n) {
    *rr = 1; return x->n - 1;
  }
  if ((*rr = key_cmp(k, x->key[begin])) < 0) {
    begin--;
  }
  return begin;
}

static inline void refkey(MarkTree *b, mtnode_t *x, int i)
{
  pmap_put(uint64_t)(b->id2node, ANTIGRAVITY(x->key[i].id), x);
}

// put functions

// x must be an internal node, which is not full
// x->ptr[i] should be a full node, i e x->ptr[i]->n == 2*T-1
static inline void split_node(MarkTree *b, mtnode_t *x, const int i)
{
  mtnode_t *y = x->ptr[i];
  mtnode_t *z;
  z = (mtnode_t *)xcalloc(1, y->level ? ILEN : sizeof(mtnode_t));
  b->n_nodes++;
  z->level = y->level;
  z->n = T - 1;
  memcpy(z->key, &y->key[T], sizeof(mtkey_t) * (T - 1));
  for (int j = 0; j < T-1; j++) {
    refkey(b, z, j);
  }
  if (y->level) {
    memcpy(z->ptr, &y->ptr[T], sizeof(mtnode_t *) * T);
    for (int j = 0; j < T; j++) {
      z->ptr[j]->parent = z;
    }
  }
  y->n = T - 1;
  memmove(&x->ptr[i + 2], &x->ptr[i + 1],
          sizeof(mtnode_t *) * (size_t)(x->n - i));
  x->ptr[i + 1] = z;
  z->parent = x;  // == y->parent
  memmove(&x->key[i + 1], &x->key[i], sizeof(mtkey_t) * (size_t)(x->n - i));

  // move key to internal layer:
  x->key[i] = y->key[T - 1];
  refkey(b, x, i);
  x->n++;

  for (int j = 0; j < T-1; j++) {
    relative(x->key[i].pos, &z->key[j].pos);
  }
  if (i > 0) {
    unrelative(x->key[i-1].pos, &x->key[i].pos);
  }
}

// x must not be a full node (even if there might be internal space)
static inline void marktree_putp_aux(MarkTree *b, mtnode_t *x, mtkey_t k)
{
  int i;
  if (x->level == 0) {
    i = marktree_getp_aux(x, k, 0);
    if (i != x->n - 1) {
      memmove(&x->key[i + 2], &x->key[i + 1],
              (size_t)(x->n - i - 1) * sizeof(mtkey_t));
    }
    x->key[i + 1] = k;
    refkey(b, x, i+1);
    x->n++;
  } else {
    i = marktree_getp_aux(x, k, 0) + 1;
    if (x->ptr[i]->n == 2 * T - 1) {
      split_node(b, x, i);
      if (key_cmp(k, x->key[i]) > 0) {
        i++;
      }
    }
    if (i > 0) {
      relative(x->key[i-1].pos, &k.pos);
    }
    marktree_putp_aux(b, x->ptr[i], k);
  }
}

uint64_t marktree_put(MarkTree *b, int row, int col, bool right_gravity)
{
  uint64_t id = (b->next_id+=ID_INCR);
  uint64_t keyid = id;
  if (right_gravity) {
    // order all right gravity keys after the left ones, for effortless
    // insertion (but not deletion!)
    keyid |= RIGHT_GRAVITY;
  }
  marktree_put_key(b, row, col, keyid);
  return id;
}

uint64_t marktree_put_pair(MarkTree *b, int start_row, int start_col, bool start_right, int end_row,
                           int end_col, bool end_right)
{
  uint64_t id = (b->next_id+=ID_INCR)|PAIRED;
  uint64_t start_id = id|(start_right?RIGHT_GRAVITY:0);
  uint64_t end_id = id|END_FLAG|(end_right?RIGHT_GRAVITY:0);
  marktree_put_key(b, start_row, start_col, start_id);
  marktree_put_key(b, end_row, end_col, end_id);
  return id;
}

void marktree_put_key(MarkTree *b, int row, int col, uint64_t id)
{
  mtkey_t k = { .pos = { .row = row, .col = col }, .id = id };

  if (!b->root) {
    b->root = (mtnode_t *)xcalloc(1, ILEN);
    b->n_nodes++;
  }
  mtnode_t *r, *s;
  b->n_keys++;
  r = b->root;
  if (r->n == 2 * T - 1) {
    b->n_nodes++;
    s = (mtnode_t *)xcalloc(1, ILEN);
    b->root = s; s->level = r->level+1; s->n = 0;
    s->ptr[0] = r;
    r->parent = s;
    split_node(b, s, 0);
    r = s;
  }
  marktree_putp_aux(b, r, k);
}

/// INITIATING DELETION PROTOCOL:
///
/// 1. Construct a valid iterator to the node to delete (argument)
/// 2. If an "internal" key. Iterate one step to the left or right,
///     which gives an internal key "auxiliary key".
/// 3. Now delete this internal key (intended or auxiliary).
///    The leaf node X might become undersized.
/// 4. If step two was done: now replace the key that _should_ be
///    deleted with the auxiliary key. Adjust relative
/// 5. Now "repair" the tree as needed. We always start at a leaf node X.
///     - if the node is big enough, terminate
///     - if we can steal from the left, steal
///     - if we can steal from the right, steal
///     - otherwise merge this node with a neighbour. This might make our
///       parent undersized. So repeat 5 for the parent.
/// 6. If 4 went all the way to the root node. The root node
///    might have ended up with size 0. Delete it then.
///
/// NB: ideally keeps the iterator valid. Like point to the key after this
/// if present.
///
/// @param rev should be true if we plan to iterate _backwards_ and delete
///            stuff before this key. Most of the time this is false (the
///            recommended strategy is to always iterate forward)
void marktree_del_itr(MarkTree *b, MarkTreeIter *itr, bool rev)
{
  int adjustment = 0;

  mtnode_t *cur = itr->node;
  int curi = itr->i;
  uint64_t id = cur->key[curi].id;
  // fprintf(stderr, "\nDELET %lu\n", id);

  if (itr->node->level) {
    if (rev) {
      abort();
    } else {
      // fprintf(stderr, "INTERNAL %d\n", cur->level);
      // steal previous node
      marktree_itr_prev(b, itr);
      adjustment = -1;
    }
  }

  // 3.
  mtnode_t *x = itr->node;
  assert(x->level == 0);
  mtkey_t intkey = x->key[itr->i];
  if (x->n > itr->i+1) {
    memmove(&x->key[itr->i], &x->key[itr->i+1],
            sizeof(mtkey_t) * (size_t)(x->n - itr->i-1));
  }
  x->n--;

  // 4.
  // if (adjustment == 1) {
  //   abort();
  // }
  if (adjustment == -1) {
    int ilvl = itr->lvl-1;
    const mtnode_t *lnode = x;
    do {
      const mtnode_t *const p = lnode->parent;
      if (ilvl < 0) {
        abort();
      }
      const int i = itr->s[ilvl].i;
      assert(p->ptr[i] == lnode);
      if (i > 0) {
        unrelative(p->key[i-1].pos, &intkey.pos);
      }
      lnode = p;
      ilvl--;
    } while (lnode != cur);

    mtkey_t deleted = cur->key[curi];
    cur->key[curi] = intkey;
    refkey(b, cur, curi);
    relative(intkey.pos, &deleted.pos);
    mtnode_t *y = cur->ptr[curi+1];
    if (deleted.pos.row || deleted.pos.col) {
      while (y) {
        for (int k = 0; k < y->n; k++) {
          unrelative(deleted.pos, &y->key[k].pos);
        }
        y = y->level ? y->ptr[0] : NULL;
      }
    }
    itr->i--;
  }

  b->n_keys--;
  pmap_del(uint64_t)(b->id2node, ANTIGRAVITY(id));

  // 5.
  bool itr_dirty = false;
  int rlvl = itr->lvl-1;
  int *lasti = &itr->i;
  while (x != b->root) {
    assert(rlvl >= 0);
    mtnode_t *p = x->parent;
    if (x->n >= T-1) {
      // we are done, if this node is fine the rest of the tree will be
      break;
    }
    int pi = itr->s[rlvl].i;
    assert(p->ptr[pi] == x);
    if (pi > 0 && p->ptr[pi-1]->n > T-1) {
      *lasti += 1;
      itr_dirty = true;
      // steal one key from the left neighbour
      pivot_right(b, p, pi-1);
      break;
    } else if (pi < p->n && p->ptr[pi+1]->n > T-1) {
      // steal one key from right neighbour
      pivot_left(b, p, pi);
      break;
    } else if (pi > 0) {
      // fprintf(stderr, "LEFT ");
      assert(p->ptr[pi-1]->n == T-1);
      // merge with left neighbour
      *lasti += T;
      x = merge_node(b, p, pi-1);
      if (lasti == &itr->i) {
        // TRICKY: we merged the node the iterator was on
        itr->node = x;
      }
      itr->s[rlvl].i--;
      itr_dirty = true;
    } else {
      // fprintf(stderr, "RIGHT ");
      assert(pi < p->n && p->ptr[pi+1]->n == T-1);
      merge_node(b, p, pi);
      // no iter adjustment needed
    }
    lasti = &itr->s[rlvl].i;
    rlvl--;
    x = p;
  }

  // 6.
  if (b->root->n == 0) {
    if (itr->lvl > 0) {
      memmove(itr->s, itr->s+1, (size_t)(itr->lvl-1) * sizeof(*itr->s));
      itr->lvl--;
    }
    if (b->root->level) {
      mtnode_t *oldroot = b->root;
      b->root = b->root->ptr[0];
      b->root->parent = NULL;
      xfree(oldroot);
    } else {
      // no items, nothing for iterator to point to
      // not strictly needed, should handle delete right-most mark anyway
      itr->node = NULL;
    }
  }

  if (itr->node && itr_dirty) {
    marktree_itr_fix_pos(b, itr);
  }

  // BONUS STEP: fix the iterator, so that it points to the key afterwards
  // TODO(bfredl): with "rev" should point before
  // if (adjustment == 1) {
  //   abort();
  // }
  if (adjustment == -1) {
    // tricky: we stand at the deleted space in the previous leaf node.
    // But the inner key is now the previous key we stole, so we need
    // to skip that one as well.
    marktree_itr_next(b, itr);
    marktree_itr_next(b, itr);
  } else {
    if (itr->node && itr->i >= itr->node->n) {
      // we deleted the last key of a leaf node
      // go to the inner key after that.
      assert(itr->node->level == 0);
      marktree_itr_next(b, itr);
    }
  }
}

static mtnode_t *merge_node(MarkTree *b, mtnode_t *p, int i)
{
  mtnode_t *x = p->ptr[i], *y = p->ptr[i+1];

  x->key[x->n] = p->key[i];
  refkey(b, x, x->n);
  if (i > 0) {
    relative(p->key[i-1].pos, &x->key[x->n].pos);
  }

  memmove(&x->key[x->n+1], y->key, (size_t)y->n * sizeof(mtkey_t));
  for (int k = 0; k < y->n; k++) {
    refkey(b, x, x->n+1+k);
    unrelative(x->key[x->n].pos, &x->key[x->n+1+k].pos);
  }
  if (x->level) {
    memmove(&x->ptr[x->n+1], y->ptr, (size_t)(y->n + 1) * sizeof(mtnode_t *));
    for (int k = 0; k < y->n+1; k++) {
      x->ptr[x->n+k+1]->parent = x;
    }
  }
  x->n += y->n+1;
  memmove(&p->key[i], &p->key[i + 1], (size_t)(p->n - i - 1) * sizeof(mtkey_t));
  memmove(&p->ptr[i + 1], &p->ptr[i + 2],
          (size_t)(p->n - i - 1) * sizeof(mtkey_t *));
  p->n--;
  xfree(y);
  b->n_nodes--;
  return x;
}

// TODO(bfredl): as a potential "micro" optimization, pivoting should balance
// the two nodes instead of stealing just one key
static void pivot_right(MarkTree *b, mtnode_t *p, int i)
{
  mtnode_t *x = p->ptr[i], *y = p->ptr[i+1];
  memmove(&y->key[1], y->key, (size_t)y->n * sizeof(mtkey_t));
  if (y->level) {
    memmove(&y->ptr[1], y->ptr, (size_t)(y->n + 1) * sizeof(mtnode_t *));
  }
  y->key[0] = p->key[i];
  refkey(b, y, 0);
  p->key[i] = x->key[x->n - 1];
  refkey(b, p, i);
  if (x->level) {
    y->ptr[0] = x->ptr[x->n];
    y->ptr[0]->parent = y;
  }
  x->n--;
  y->n++;
  if (i > 0) {
    unrelative(p->key[i-1].pos, &p->key[i].pos);
  }
  relative(p->key[i].pos, &y->key[0].pos);
  for (int k = 1; k < y->n; k++) {
    unrelative(y->key[0].pos, &y->key[k].pos);
  }
}

static void pivot_left(MarkTree *b, mtnode_t *p, int i)
{
  mtnode_t *x = p->ptr[i], *y = p->ptr[i+1];

  // reverse from how we "always" do it. but pivot_left
  // is just the inverse of pivot_right, so reverse it literally.
  for (int k = 1; k < y->n; k++) {
    relative(y->key[0].pos, &y->key[k].pos);
  }
  unrelative(p->key[i].pos, &y->key[0].pos);
  if (i > 0) {
    relative(p->key[i-1].pos, &p->key[i].pos);
  }

  x->key[x->n] = p->key[i];
  refkey(b, x, x->n);
  p->key[i] = y->key[0];
  refkey(b, p, i);
  if (x->level) {
    x->ptr[x->n+1] = y->ptr[0];
    x->ptr[x->n+1]->parent = x;
  }
  memmove(y->key, &y->key[1], (size_t)(y->n-1) * sizeof(mtkey_t));
  if (y->level) {
    memmove(y->ptr, &y->ptr[1], (size_t)y->n * sizeof(mtnode_t *));
  }
  x->n++;
  y->n--;
}

/// frees all mem, resets tree to valid empty state
void marktree_clear(MarkTree *b)
{
  if (b->root) {
    marktree_free_node(b->root);
    b->root = NULL;
  }
  if (b->id2node->table.keys) {
    pmap_destroy(uint64_t)(b->id2node);
    pmap_init(uint64_t, b->id2node);
  }
  b->n_keys = 0;
  b->n_nodes = 0;
}

void marktree_free_node(mtnode_t *x)
{
  if (x->level) {
    for (int i = 0; i < x->n+1; i++) {
      marktree_free_node(x->ptr[i]);
    }
  }
  xfree(x);
}

/// NB: caller must check not pair!
uint64_t marktree_revise(MarkTree *b, MarkTreeIter *itr)
{
  uint64_t old_id = rawkey(itr).id;
  pmap_del(uint64_t)(b->id2node, ANTIGRAVITY(old_id));
  uint64_t new_id = (b->next_id += ID_INCR);
  rawkey(itr).id = new_id + (RIGHT_GRAVITY&old_id);
  refkey(b, itr->node, itr->i);
  return new_id;
}

void marktree_move(MarkTree *b, MarkTreeIter *itr, int row, int col)
{
  uint64_t old_id = rawkey(itr).id;
  // TODO(bfredl): optimize when moving a mark within a leaf without moving it
  // across neighbours!
  marktree_del_itr(b, itr, false);
  marktree_put_key(b, row, col, old_id);
  itr->node = NULL;  // itr might become invalid by put
}

// itr functions

// TODO(bfredl): static inline?
bool marktree_itr_get(MarkTree *b, int row, int col, MarkTreeIter *itr)
{
  return marktree_itr_get_ext(b, (mtpos_t){ row, col },
                              itr, false, false, NULL);
}

bool marktree_itr_get_ext(MarkTree *b, mtpos_t p, MarkTreeIter *itr, bool last, bool gravity,
                          mtpos_t *oldbase)
{
  mtkey_t k = { .pos = p, .id = gravity ? RIGHT_GRAVITY : 0 };
  if (last && !gravity) {
    k.id = UINT64_MAX;
  }
  if (b->n_keys == 0) {
    itr->node = NULL;
    return false;
  }
  itr->pos = (mtpos_t){ 0, 0 };
  itr->node = b->root;
  itr->lvl = 0;
  if (oldbase) {
    oldbase[itr->lvl] = itr->pos;
  }
  while (true) {
    itr->i = marktree_getp_aux(itr->node, k, 0)+1;

    if (itr->node->level == 0) {
      break;
    }

    itr->s[itr->lvl].i = itr->i;
    itr->s[itr->lvl].oldcol = itr->pos.col;

    if (itr->i > 0) {
      compose(&itr->pos, itr->node->key[itr->i-1].pos);
      relative(itr->node->key[itr->i-1].pos, &k.pos);
    }
    itr->node = itr->node->ptr[itr->i];
    itr->lvl++;
    if (oldbase) {
      oldbase[itr->lvl] = itr->pos;
    }
  }

  if (last) {
    return marktree_itr_prev(b, itr);
  } else if (itr->i >= itr->node->n) {
    return marktree_itr_next(b, itr);
  }
  return true;
}

bool marktree_itr_first(MarkTree *b, MarkTreeIter *itr)
{
  itr->node = b->root;
  if (b->n_keys == 0) {
    return false;
  }

  itr->i = 0;
  itr->lvl = 0;
  itr->pos = (mtpos_t){ 0, 0 };
  while (itr->node->level > 0) {
    itr->s[itr->lvl].i = 0;
    itr->s[itr->lvl].oldcol = 0;
    itr->lvl++;
    itr->node = itr->node->ptr[0];
  }
  return true;
}

// gives the first key that is greater or equal to p
int marktree_itr_last(MarkTree *b, MarkTreeIter *itr)
{
  if (b->n_keys == 0) {
    itr->node = NULL;
    return false;
  }
  itr->pos = (mtpos_t){ 0, 0 };
  itr->node = b->root;
  itr->lvl = 0;
  while (true) {
    itr->i = itr->node->n;

    if (itr->node->level == 0) {
      break;
    }

    itr->s[itr->lvl].i = itr->i;
    itr->s[itr->lvl].oldcol = itr->pos.col;

    assert(itr->i > 0);
    compose(&itr->pos, itr->node->key[itr->i-1].pos);

    itr->node = itr->node->ptr[itr->i];
    itr->lvl++;
  }
  itr->i--;
  return true;
}

// TODO(bfredl): static inline
bool marktree_itr_next(MarkTree *b, MarkTreeIter *itr)
{
  return marktree_itr_next_skip(b, itr, false, NULL);
}

static bool marktree_itr_next_skip(MarkTree *b, MarkTreeIter *itr, bool skip, mtpos_t oldbase[])
{
  if (!itr->node) {
    return false;
  }
  itr->i++;
  if (itr->node->level == 0 || skip) {
    if (itr->i < itr->node->n) {
      // TODO(bfredl): this is the common case,
      // and could be handled by inline wrapper
      return true;
    }
    // we ran out of non-internal keys. Go up until we find an internal key
    while (itr->i >= itr->node->n) {
      itr->node = itr->node->parent;
      if (itr->node == NULL) {
        return false;
      }
      itr->lvl--;
      itr->i = itr->s[itr->lvl].i;
      if (itr->i > 0) {
        itr->pos.row -= itr->node->key[itr->i-1].pos.row;
        itr->pos.col = itr->s[itr->lvl].oldcol;
      }
    }
  } else {
    // we stood at an "internal" key. Go down to the first non-internal
    // key after it.
    while (itr->node->level > 0) {
      // internal key, there is always a child after
      if (itr->i > 0) {
        itr->s[itr->lvl].oldcol = itr->pos.col;
        compose(&itr->pos, itr->node->key[itr->i-1].pos);
      }
      if (oldbase && itr->i == 0) {
        oldbase[itr->lvl+1] = oldbase[itr->lvl];
      }
      itr->s[itr->lvl].i = itr->i;
      assert(itr->node->ptr[itr->i]->parent == itr->node);
      itr->node = itr->node->ptr[itr->i];
      itr->i = 0;
      itr->lvl++;
    }
  }
  return true;
}

bool marktree_itr_prev(MarkTree *b, MarkTreeIter *itr)
{
  if (!itr->node) {
    return false;
  }
  if (itr->node->level == 0) {
    itr->i--;
    if (itr->i >= 0) {
      // TODO(bfredl): this is the common case,
      // and could be handled by inline wrapper
      return true;
    }
    // we ran out of non-internal keys. Go up until we find a non-internal key
    while (itr->i < 0) {
      itr->node = itr->node->parent;
      if (itr->node == NULL) {
        return false;
      }
      itr->lvl--;
      itr->i = itr->s[itr->lvl].i-1;
      if (itr->i >= 0) {
        itr->pos.row -= itr->node->key[itr->i].pos.row;
        itr->pos.col = itr->s[itr->lvl].oldcol;
      }
    }
  } else {
    // we stood at an "internal" key. Go down to the last non-internal
    // key before it.
    while (itr->node->level > 0) {
      // internal key, there is always a child before
      if (itr->i > 0) {
        itr->s[itr->lvl].oldcol = itr->pos.col;
        compose(&itr->pos, itr->node->key[itr->i-1].pos);
      }
      itr->s[itr->lvl].i = itr->i;
      assert(itr->node->ptr[itr->i]->parent == itr->node);
      itr->node = itr->node->ptr[itr->i];
      itr->i = itr->node->n;
      itr->lvl++;
    }
    itr->i--;
  }
  return true;
}

void marktree_itr_rewind(MarkTree *b, MarkTreeIter *itr)
{
  if (!itr->node) {
    return;
  }
  if (itr->node->level) {
    marktree_itr_prev(b, itr);
  }
  itr->i = 0;
}

bool marktree_itr_node_done(MarkTreeIter *itr)
{
  return !itr->node || itr->i == itr->node->n-1;
}


mtpos_t marktree_itr_pos(MarkTreeIter *itr)
{
  mtpos_t pos = rawkey(itr).pos;
  unrelative(itr->pos, &pos);
  return pos;
}

mtmark_t marktree_itr_current(MarkTreeIter *itr)
{
  if (itr->node) {
    uint64_t keyid = rawkey(itr).id;
    mtpos_t pos = marktree_itr_pos(itr);
    mtmark_t mark = { .row = pos.row,
                      .col = pos.col,
                      .id = ANTIGRAVITY(keyid),
                      .right_gravity = keyid & RIGHT_GRAVITY };
    return mark;
  }
  return (mtmark_t){ -1, -1, 0, false };
}

static void swap_id(uint64_t *id1, uint64_t *id2)
{
  uint64_t temp = *id1;
  *id1 = *id2;
  *id2 = temp;
}

bool marktree_splice(MarkTree *b, int start_line, int start_col, int old_extent_line,
                     int old_extent_col, int new_extent_line, int new_extent_col)
{
  mtpos_t start = { start_line, start_col };
  mtpos_t old_extent = { (int)old_extent_line, old_extent_col };
  mtpos_t new_extent = { (int)new_extent_line, new_extent_col };

  bool may_delete = (old_extent.row != 0 || old_extent.col != 0);
  bool same_line = old_extent.row == 0 && new_extent.row == 0;
  unrelative(start, &old_extent);
  unrelative(start, &new_extent);
  MarkTreeIter itr[1] = { 0 };
  MarkTreeIter enditr[1] = { 0 };

  mtpos_t oldbase[MT_MAX_DEPTH] = { 0 };

  marktree_itr_get_ext(b, start, itr, false, true, oldbase);
  if (!itr->node) {
    // den e FÄRDIG
    return false;
  }
  mtpos_t delta = { new_extent.row - old_extent.row,
                    new_extent.col-old_extent.col };

  if (may_delete) {
    mtpos_t ipos = marktree_itr_pos(itr);
    if (!pos_leq(old_extent, ipos)
        || (old_extent.row == ipos.row && old_extent.col == ipos.col
            && !IS_RIGHT(rawkey(itr).id))) {
      marktree_itr_get_ext(b, old_extent, enditr, true, true, NULL);
      assert(enditr->node);
      // "assert" (itr <= enditr)
    } else {
      may_delete = false;
    }
  }

  bool past_right = false;
  bool moved = false;

  // Follow the general strategy of messing things up and fix them later
  // "oldbase" carries the information needed to calculate old position of
  // children.
  if (may_delete) {
    while (itr->node && !past_right) {
      mtpos_t loc_start = start;
      mtpos_t loc_old = old_extent;
      relative(itr->pos, &loc_start);

      relative(oldbase[itr->lvl], &loc_old);

continue_same_node:
      // NB: strictly should be less than the right gravity of loc_old, but
      // the iter comparison below will already break on that.
      if (!pos_leq(rawkey(itr).pos, loc_old)) {
        break;
      }

      if (IS_RIGHT(rawkey(itr).id)) {
        while (rawkey(itr).id != rawkey(enditr).id
               && IS_RIGHT(rawkey(enditr).id)) {
          marktree_itr_prev(b, enditr);
        }
        if (!IS_RIGHT(rawkey(enditr).id)) {
          swap_id(&rawkey(itr).id, &rawkey(enditr).id);
          refkey(b, itr->node, itr->i);
          refkey(b, enditr->node, enditr->i);
        } else {
          past_right = true;  // NOLINT
          (void)past_right;
          break;
        }
      }

      if (rawkey(itr).id == rawkey(enditr).id) {
        // actually, will be past_right after this key
        past_right = true;
      }

      moved = true;
      if (itr->node->level) {
        oldbase[itr->lvl+1] = rawkey(itr).pos;
        unrelative(oldbase[itr->lvl], &oldbase[itr->lvl+1]);
        rawkey(itr).pos = loc_start;
        marktree_itr_next_skip(b, itr, false, oldbase);
      } else {
        rawkey(itr).pos = loc_start;
        if (itr->i < itr->node->n-1) {
          itr->i++;
          if (!past_right) {
            goto continue_same_node;
          }
        } else {
          marktree_itr_next(b, itr);
        }
      }
    }
    while (itr->node) {
      mtpos_t loc_new = new_extent;
      relative(itr->pos, &loc_new);
      mtpos_t limit = old_extent;

      relative(oldbase[itr->lvl], &limit);

past_continue_same_node:

      if (pos_leq(limit, rawkey(itr).pos)) {
        break;
      }

      mtpos_t oldpos = rawkey(itr).pos;
      rawkey(itr).pos = loc_new;
      moved = true;
      if (itr->node->level) {
        oldbase[itr->lvl+1] = oldpos;
        unrelative(oldbase[itr->lvl], &oldbase[itr->lvl+1]);

        marktree_itr_next_skip(b, itr, false, oldbase);
      } else {
        if (itr->i < itr->node->n-1) {
          itr->i++;
          goto past_continue_same_node;
        } else {
          marktree_itr_next(b, itr);
        }
      }
    }
  }


  while (itr->node) {
    unrelative(oldbase[itr->lvl], &rawkey(itr).pos);
    int realrow = rawkey(itr).pos.row;
    assert(realrow >= old_extent.row);
    bool done = false;
    if (realrow == old_extent.row) {
      if (delta.col) {
        rawkey(itr).pos.col += delta.col;
        moved = true;
      }
    } else {
      if (same_line) {
        // optimization: column only adjustment can skip remaining rows
        done = true;
      }
    }
    if (delta.row) {
      rawkey(itr).pos.row += delta.row;
      moved = true;
    }
    relative(itr->pos, &rawkey(itr).pos);
    if (done) {
      break;
    }
    marktree_itr_next_skip(b, itr, true, NULL);
  }
  return moved;
}

void marktree_move_region(MarkTree *b, int start_row, colnr_T start_col, int extent_row,
                          colnr_T extent_col, int new_row, colnr_T new_col)
{
  mtpos_t start = { start_row, start_col }, size = { extent_row, extent_col };
  mtpos_t end = size;
  unrelative(start, &end);
  MarkTreeIter itr[1] = { 0 };
  marktree_itr_get_ext(b, start, itr, false, true, NULL);
  kvec_t(mtkey_t) saved = KV_INITIAL_VALUE;
  while (itr->node) {
    mtpos_t pos = marktree_itr_pos(itr);
    if (!pos_leq(pos, end) || (pos.row == end.row && pos.col == end.col
                               && rawkey(itr).id & RIGHT_GRAVITY)) {
      break;
    }
    relative(start, &pos);
    kv_push(saved, ((mtkey_t){ .pos = pos, .id = rawkey(itr).id }));
    marktree_del_itr(b, itr, false);
  }

  marktree_splice(b, start.row, start.col, size.row, size.col, 0, 0);
  mtpos_t new = { new_row, new_col };
  marktree_splice(b, new.row, new.col,
                  0, 0, size.row, size.col);

  for (size_t i = 0; i < kv_size(saved); i++) {
    mtkey_t item = kv_A(saved, i);
    unrelative(new, &item.pos);
    marktree_put_key(b, item.pos.row, item.pos.col, item.id);
  }
  kv_destroy(saved);
}

/// @param itr OPTIONAL. set itr to pos.
mtpos_t marktree_lookup(MarkTree *b, uint64_t id, MarkTreeIter *itr)
{
  mtnode_t *n = pmap_get(uint64_t)(b->id2node, id);
  if (n == NULL) {
    if (itr) {
      itr->node = NULL;
    }
    return (mtpos_t){ -1, -1 };
  }
  int i = 0;
  for (i = 0; i < n->n; i++) {
    if (ANTIGRAVITY(n->key[i].id) == id) {
      goto found;
    }
  }
  abort();
found: {}
  mtpos_t pos = n->key[i].pos;
  if (itr) {
    itr->i = i;
    itr->node = n;
    itr->lvl = b->root->level - n->level;
  }
  while (n->parent != NULL) {
    mtnode_t *p = n->parent;
    for (i = 0; i < p->n+1; i++) {
      if (p->ptr[i] == n) {
        goto found_node;
      }
    }
    abort();
found_node:
    if (itr) {
      itr->s[b->root->level-p->level].i = i;
    }
    if (i > 0) {
      unrelative(p->key[i-1].pos, &pos);
    }
    n = p;
  }
  if (itr) {
    marktree_itr_fix_pos(b, itr);
  }
  return pos;
}

static void marktree_itr_fix_pos(MarkTree *b, MarkTreeIter *itr)
{
  itr->pos = (mtpos_t){ 0, 0 };
  mtnode_t *x = b->root;
  for (int lvl = 0; lvl < itr->lvl; lvl++) {
    itr->s[lvl].oldcol = itr->pos.col;
    int i = itr->s[lvl].i;
    if (i > 0) {
      compose(&itr->pos, x->key[i-1].pos);
    }
    assert(x->level);
    x = x->ptr[i];
  }
  assert(x == itr->node);
}

void marktree_check(MarkTree *b)
{
#ifndef NDEBUG
  if (b->root == NULL) {
    assert(b->n_keys == 0);
    assert(b->n_nodes == 0);
    assert(b->id2node == NULL || map_size(b->id2node) == 0);
    return;
  }

  mtpos_t dummy;
  bool last_right = false;
  size_t nkeys = check_node(b, b->root, &dummy, &last_right);
  assert(b->n_keys == nkeys);
  assert(b->n_keys == map_size(b->id2node));
#else
  // Do nothing, as assertions are required
  (void)b;
#endif
}

#ifndef NDEBUG
static size_t check_node(MarkTree *b, mtnode_t *x, mtpos_t *last, bool *last_right)
{
  assert(x->n <= 2 * T - 1);
  // TODO(bfredl): too strict if checking "in repair" post-delete tree.
  assert(x->n >= (x != b->root ? T-1 : 0));
  size_t n_keys = (size_t)x->n;

  for (int i = 0; i < x->n; i++) {
    if (x->level) {
      n_keys += check_node(b, x->ptr[i], last, last_right);
    } else {
      *last = (mtpos_t) { 0, 0 };
    }
    if (i > 0) {
      unrelative(x->key[i-1].pos, last);
    }
    if (x->level) {
    }
    assert(pos_leq(*last, x->key[i].pos));
    if (last->row == x->key[i].pos.row && last->col == x->key[i].pos.col) {
      assert(!*last_right || IS_RIGHT(x->key[i].id));
    }
    *last_right = IS_RIGHT(x->key[i].id);
    assert(x->key[i].pos.col >= 0);
    assert(pmap_get(uint64_t)(b->id2node, ANTIGRAVITY(x->key[i].id)) == x);
  }

  if (x->level) {
    n_keys += check_node(b, x->ptr[x->n], last, last_right);
    unrelative(x->key[x->n-1].pos, last);

    for (int i = 0; i < x->n+1; i++) {
      assert(x->ptr[i]->parent == x);
      assert(x->ptr[i]->level == x->level-1);
      // PARANOIA: check no double node ref
      for (int j = 0; j < i; j++) {
        assert(x->ptr[i] != x->ptr[j]);
      }
    }
  } else {
    *last = x->key[x->n-1].pos;
  }
  return n_keys;
}
#endif

char *mt_inspect_rec(MarkTree *b)
{
  garray_T ga;
  ga_init(&ga, (int)sizeof(char), 80);
  mtpos_t p = { 0, 0 };
  mt_inspect_node(b, &ga, b->root, p);
  return ga.ga_data;
}

void mt_inspect_node(MarkTree *b, garray_T *ga, mtnode_t *n, mtpos_t off)
{
  static char buf[1024];
#define GA_PUT(x) ga_concat(ga, (char_u *)(x))
  GA_PUT("[");
  if (n->level) {
    mt_inspect_node(b, ga, n->ptr[0], off);
  }
  for (int i = 0; i < n->n; i++) {
    mtpos_t p = n->key[i].pos;
    unrelative(off, &p);
    snprintf((char *)buf, sizeof(buf), "%d/%d", p.row, p.col);
    GA_PUT(buf);
    if (n->level) {
      mt_inspect_node(b, ga, n->ptr[i+1], p);
    } else {
      GA_PUT(",");
    }
  }
  GA_PUT("]");
#undef GA_PUT
}

