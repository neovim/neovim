
#include <ctype.h>
#include <limits.h>
#include <string.h>


#include "lua.h"
#include "lauxlib.h"

#include "lptypes.h"
#include "lpcap.h"
#include "lpcode.h"
#include "lpprint.h"
#include "lptree.h"
#include "lpcset.h"


/* number of siblings for each tree */
const byte numsiblings[] = {
  0, 0, 0,	/* char, set, any */
  0, 0, 0,	/* true, false, utf-range */
  1,		/* acc */
  2, 2,		/* seq, choice */
  1, 1,		/* not, and */
  0, 0, 2, 1, 1,  /* call, opencall, rule, prerule, grammar */
  1,  /* behind */
  1, 1  /* capture, runtime capture */
};


static TTree *newgrammar (lua_State *L, int arg);


/*
** returns a reasonable name for value at index 'idx' on the stack
*/
static const char *val2str (lua_State *L, int idx) {
  const char *k = lua_tostring(L, idx);
  if (k != NULL)
    return lua_pushfstring(L, "%s", k);
  else
    return lua_pushfstring(L, "(a %s)", luaL_typename(L, idx));
}


/*
** Fix a TOpenCall into a TCall node, using table 'postable' to
** translate a key to its rule address in the tree. Raises an
** error if key does not exist.
*/
static void fixonecall (lua_State *L, int postable, TTree *g, TTree *t) {
  int n;
  lua_rawgeti(L, -1, t->key);  /* get rule's name */
  lua_gettable(L, postable);  /* query name in position table */
  n = lua_tonumber(L, -1);  /* get (absolute) position */
  lua_pop(L, 1);  /* remove position */
  if (n == 0) {  /* no position? */
    lua_rawgeti(L, -1, t->key);  /* get rule's name again */
    luaL_error(L, "rule '%s' undefined in given grammar", val2str(L, -1));
  }
  t->tag = TCall;
  t->u.ps = n - (t - g);  /* position relative to node */
  assert(sib2(t)->tag == TRule);
  sib2(t)->key = t->key;  /* fix rule's key */
}


/*
** Transform left associative constructions into right
** associative ones, for sequence and choice; that is:
** (t11 + t12) + t2  =>  t11 + (t12 + t2)
** (t11 * t12) * t2  =>  t11 * (t12 * t2)
** (that is, Op (Op t11 t12) t2 => Op t11 (Op t12 t2))
*/
static void correctassociativity (TTree *tree) {
  TTree *t1 = sib1(tree);
  assert(tree->tag == TChoice || tree->tag == TSeq);
  while (t1->tag == tree->tag) {
    int n1size = tree->u.ps - 1;  /* t1 == Op t11 t12 */
    int n11size = t1->u.ps - 1;
    int n12size = n1size - n11size - 1;
    memmove(sib1(tree), sib1(t1), n11size * sizeof(TTree)); /* move t11 */
    tree->u.ps = n11size + 1;
    sib2(tree)->tag = tree->tag;
    sib2(tree)->u.ps = n12size + 1;
  }
}


/*
** Make final adjustments in a tree. Fix open calls in tree 't',
** making them refer to their respective rules or raising appropriate
** errors (if not inside a grammar). Correct associativity of associative
** constructions (making them right associative). Assume that tree's
** ktable is at the top of the stack (for error messages).
*/
static void finalfix (lua_State *L, int postable, TTree *g, TTree *t) {
 tailcall:
  switch (t->tag) {
    case TGrammar:  /* subgrammars were already fixed */
      return;
    case TOpenCall: {
      if (g != NULL)  /* inside a grammar? */
        fixonecall(L, postable, g, t);
      else {  /* open call outside grammar */
        lua_rawgeti(L, -1, t->key);
        luaL_error(L, "rule '%s' used outside a grammar", val2str(L, -1));
      }
      break;
    }
    case TSeq: case TChoice:
      correctassociativity(t);
      break;
  }
  switch (numsiblings[t->tag]) {
    case 1: /* finalfix(L, postable, g, sib1(t)); */
      t = sib1(t); goto tailcall;
    case 2:
      finalfix(L, postable, g, sib1(t));
      t = sib2(t); goto tailcall;  /* finalfix(L, postable, g, sib2(t)); */
    default: assert(numsiblings[t->tag] == 0); break;
  }
}



/*
** {===================================================================
** KTable manipulation
**
** - The ktable of a pattern 'p' can be shared by other patterns that
** contain 'p' and no other constants. Because of this sharing, we
** should not add elements to a 'ktable' unless it was freshly created
** for the new pattern.
**
** - The maximum index in a ktable is USHRT_MAX, because trees and
** patterns use unsigned shorts to store those indices.
** ====================================================================
*/

/*
** Create a new 'ktable' to the pattern at the top of the stack.
*/
static void newktable (lua_State *L, int n) {
  lua_createtable(L, n, 0);  /* create a fresh table */
  lua_setuservalue(L, -2);  /* set it as 'ktable' for pattern */
}


/*
** Add element 'idx' to 'ktable' of pattern at the top of the stack;
** Return index of new element.
** If new element is nil, does not add it to table (as it would be
** useless) and returns 0, as ktable[0] is always nil.
*/
static int addtoktable (lua_State *L, int idx) {
  if (lua_isnil(L, idx))  /* nil value? */
    return 0;
  else {
    int n;
    lua_getuservalue(L, -1);  /* get ktable from pattern */
    n = lua_rawlen(L, -1);
    if (n >= USHRT_MAX)
      luaL_error(L, "too many Lua values in pattern");
    lua_pushvalue(L, idx);  /* element to be added */
    lua_rawseti(L, -2, ++n);
    lua_pop(L, 1);  /* remove 'ktable' */
    return n;
  }
}


/*
** Return the number of elements in the ktable at 'idx'.
** In Lua 5.2/5.3, default "environment" for patterns is nil, not
** a table. Treat it as an empty table. In Lua 5.1, assumes that
** the environment has no numeric indices (len == 0)
*/
static int ktablelen (lua_State *L, int idx) {
  if (!lua_istable(L, idx)) return 0;
  else return lua_rawlen(L, idx);
}


/*
** Concatentate the contents of table 'idx1' into table 'idx2'.
** (Assume that both indices are negative.)
** Return the original length of table 'idx2' (or 0, if no
** element was added, as there is no need to correct any index).
*/
static int concattable (lua_State *L, int idx1, int idx2) {
  int i;
  int n1 = ktablelen(L, idx1);
  int n2 = ktablelen(L, idx2);
  if (n1 + n2 > USHRT_MAX)
    luaL_error(L, "too many Lua values in pattern");
  if (n1 == 0) return 0;  /* nothing to correct */
  for (i = 1; i <= n1; i++) {
    lua_rawgeti(L, idx1, i);
    lua_rawseti(L, idx2 - 1, n2 + i);  /* correct 'idx2' */
  }
  return n2;
}


/*
** When joining 'ktables', constants from one of the subpatterns must
** be renumbered; 'correctkeys' corrects their indices (adding 'n'
** to each of them)
*/
static void correctkeys (TTree *tree, int n) {
  if (n == 0) return;  /* no correction? */
 tailcall:
  switch (tree->tag) {
    case TOpenCall: case TCall: case TRunTime: case TRule: {
      if (tree->key > 0)
        tree->key += n;
      break;
    }
    case TCapture: {
      if (tree->key > 0 && tree->cap != Carg && tree->cap != Cnum)
        tree->key += n;
      break;
    }
    default: break;
  }
  switch (numsiblings[tree->tag]) {
    case 1:  /* correctkeys(sib1(tree), n); */
      tree = sib1(tree); goto tailcall;
    case 2:
      correctkeys(sib1(tree), n);
      tree = sib2(tree); goto tailcall;  /* correctkeys(sib2(tree), n); */
    default: assert(numsiblings[tree->tag] == 0); break;
  }
}


/*
** Join the ktables from p1 and p2 the ktable for the new pattern at the
** top of the stack, reusing them when possible.
*/
static void joinktables (lua_State *L, int p1, TTree *t2, int p2) {
  int n1, n2;
  lua_getuservalue(L, p1);  /* get ktables */
  lua_getuservalue(L, p2);
  n1 = ktablelen(L, -2);
  n2 = ktablelen(L, -1);
  if (n1 == 0 && n2 == 0)  /* are both tables empty? */
    lua_pop(L, 2);  /* nothing to be done; pop tables */
  else if (n2 == 0 || lp_equal(L, -2, -1)) {  /* 2nd table empty or equal? */
    lua_pop(L, 1);  /* pop 2nd table */
    lua_setuservalue(L, -2);  /* set 1st ktable into new pattern */
  }
  else if (n1 == 0) {  /* first table is empty? */
    lua_setuservalue(L, -3);  /* set 2nd table into new pattern */
    lua_pop(L, 1);  /* pop 1st table */
  }
  else {
    lua_createtable(L, n1 + n2, 0);  /* create ktable for new pattern */
    /* stack: new p; ktable p1; ktable p2; new ktable */
    concattable(L, -3, -1);  /* from p1 into new ktable */
    concattable(L, -2, -1);  /* from p2 into new ktable */
    lua_setuservalue(L, -4);  /* new ktable becomes 'p' environment */
    lua_pop(L, 2);  /* pop other ktables */
    correctkeys(t2, n1);  /* correction for indices from p2 */
  }
}


/*
** copy 'ktable' of element 'idx' to new tree (on top of stack)
*/
static void copyktable (lua_State *L, int idx) {
  lua_getuservalue(L, idx);
  lua_setuservalue(L, -2);
}


/*
** merge 'ktable' from 'stree' at stack index 'idx' into 'ktable'
** from tree at the top of the stack, and correct corresponding
** tree.
*/
static void mergektable (lua_State *L, int idx, TTree *stree) {
  int n;
  lua_getuservalue(L, -1);  /* get ktables */
  lua_getuservalue(L, idx);
  n = concattable(L, -1, -2);
  lua_pop(L, 2);  /* remove both ktables */
  correctkeys(stree, n);
}


/*
** Create a new 'ktable' to the pattern at the top of the stack, adding
** all elements from pattern 'p' (if not 0) plus element 'idx' to it.
** Return index of new element.
*/
static int addtonewktable (lua_State *L, int p, int idx) {
  newktable(L, 1);
  if (p)
    mergektable(L, p, NULL);
  return addtoktable(L, idx);
}

/* }====================================================== */


/*
** {======================================================
** Tree generation
** =======================================================
*/

/*
** In 5.2, could use 'luaL_testudata'...
*/
static int testpattern (lua_State *L, int idx) {
  if (lua_touserdata(L, idx)) {  /* value is a userdata? */
    if (lua_getmetatable(L, idx)) {  /* does it have a metatable? */
      luaL_getmetatable(L, PATTERN_T);
      if (lua_rawequal(L, -1, -2)) {  /* does it have the correct mt? */
        lua_pop(L, 2);  /* remove both metatables */
        return 1;
      }
    }
  }
  return 0;
}


static Pattern *getpattern (lua_State *L, int idx) {
  return (Pattern *)luaL_checkudata(L, idx, PATTERN_T);
}


static int getsize (lua_State *L, int idx) {
  return (lua_rawlen(L, idx) - offsetof(Pattern, tree)) / sizeof(TTree);
}


static TTree *gettree (lua_State *L, int idx, int *len) {
  Pattern *p = getpattern(L, idx);
  if (len)
    *len = getsize(L, idx);
  return p->tree;
}


/*
** create a pattern followed by a tree with 'len' nodes. Set its
** uservalue (the 'ktable') equal to its metatable. (It could be any
** empty sequence; the metatable is at hand here, so we use it.)
*/
static TTree *newtree (lua_State *L, int len) {
  size_t size = offsetof(Pattern, tree) + len * sizeof(TTree);
  Pattern *p = (Pattern *)lua_newuserdata(L, size);
  luaL_getmetatable(L, PATTERN_T);
  lua_pushvalue(L, -1);
  lua_setuservalue(L, -3);
  lua_setmetatable(L, -2);
  p->code = NULL;
  return p->tree;
}


static TTree *newleaf (lua_State *L, int tag) {
  TTree *tree = newtree(L, 1);
  tree->tag = tag;
  return tree;
}


/*
** Create a tree for a charset, optimizing for special cases: empty set,
** full set, and singleton set.
*/
static TTree *newcharset (lua_State *L, byte *cs) {
  charsetinfo info;
  Opcode op = charsettype(cs, &info);
  switch (op) {
    case IFail: return newleaf(L, TFalse);  /* empty set */
    case IAny: return newleaf(L, TAny);  /* full set */
    case IChar: {  /* singleton set */
      TTree *tree =newleaf(L, TChar);
      tree->u.n = info.offset;
      return tree;
    }
    default: {  /* regular set */
      int i;
      int bsize =  /* tree size in bytes */
                  (int)offsetof(TTree, u.set.bitmap) + info.size;
      TTree *tree = newtree(L, bytes2slots(bsize));
      assert(op == ISet);
      tree->tag = TSet;
      tree->u.set.offset = info.offset;
      tree->u.set.size = info.size;
      tree->u.set.deflt = info.deflt;
      for (i = 0; i < info.size; i++) {
        assert(&treebuffer(tree)[i] < (byte*)tree + bsize);
        treebuffer(tree)[i] = cs[info.offset + i];
      }
      return tree;
    }
  }
}


/*
** Add to tree a sequence where first sibling is 'sib' (with size
** 'sibsize'); return position for second sibling.
*/
static TTree *seqaux (TTree *tree, TTree *sib, int sibsize) {
  tree->tag = TSeq; tree->u.ps = sibsize + 1;
  memcpy(sib1(tree), sib, sibsize * sizeof(TTree));
  return sib2(tree);
}


/*
** Build a sequence of 'n' nodes, each with tag 'tag' and 'u.n' got
** from the array 's' (or 0 if array is NULL). (TSeq is binary, so it
** must build a sequence of sequence of sequence...)
*/
static void fillseq (TTree *tree, int tag, int n, const char *s) {
  int i;
  for (i = 0; i < n - 1; i++) {  /* initial n-1 copies of Seq tag; Seq ... */
    tree->tag = TSeq; tree->u.ps = 2;
    sib1(tree)->tag = tag;
    sib1(tree)->u.n = s ? (byte)s[i] : 0;
    tree = sib2(tree);
  }
  tree->tag = tag;  /* last one does not need TSeq */
  tree->u.n = s ? (byte)s[i] : 0;
}


/*
** Numbers as patterns:
** 0 == true (always match); n == TAny repeated 'n' times;
** -n == not (TAny repeated 'n' times)
*/
static TTree *numtree (lua_State *L, int n) {
  if (n == 0)
    return newleaf(L, TTrue);
  else {
    TTree *tree, *nd;
    if (n > 0)
      tree = nd = newtree(L, 2 * n - 1);
    else {  /* negative: code it as !(-n) */
      n = -n;
      tree = newtree(L, 2 * n);
      tree->tag = TNot;
      nd = sib1(tree);
    }
    fillseq(nd, TAny, n, NULL);  /* sequence of 'n' any's */
    return tree;
  }
}


/*
** Convert value at index 'idx' to a pattern
*/
static TTree *getpatt (lua_State *L, int idx, int *len) {
  TTree *tree;
  switch (lua_type(L, idx)) {
    case LUA_TSTRING: {
      size_t slen;
      const char *s = lua_tolstring(L, idx, &slen);  /* get string */
      if (slen == 0)  /* empty? */
        tree = newleaf(L, TTrue);  /* always match */
      else {
        tree = newtree(L, 2 * (slen - 1) + 1);
        fillseq(tree, TChar, slen, s);  /* sequence of 'slen' chars */
      }
      break;
    }
    case LUA_TNUMBER: {
      int n = lua_tointeger(L, idx);
      tree = numtree(L, n);
      break;
    }
    case LUA_TBOOLEAN: {
      tree = (lua_toboolean(L, idx) ? newleaf(L, TTrue) : newleaf(L, TFalse));
      break;
    }
    case LUA_TTABLE: {
      tree = newgrammar(L, idx);
      break;
    }
    case LUA_TFUNCTION: {
      tree = newtree(L, 2);
      tree->tag = TRunTime;
      tree->key = addtonewktable(L, 0, idx);
      sib1(tree)->tag = TTrue;
      break;
    }
    default: {
      return gettree(L, idx, len);
    }
  }
  lua_replace(L, idx);  /* put new tree into 'idx' slot */
  if (len)
    *len = getsize(L, idx);
  return tree;
}


/*
** create a new tree, whith a new root and one sibling.
** Sibling must be on the Lua stack, at index 1.
*/
static TTree *newroot1sib (lua_State *L, int tag) {
  int s1;
  TTree *tree1 = getpatt(L, 1, &s1);
  TTree *tree = newtree(L, 1 + s1);  /* create new tree */
  tree->tag = tag;
  memcpy(sib1(tree), tree1, s1 * sizeof(TTree));
  copyktable(L, 1);
  return tree;
}


/*
** create a new tree, whith a new root and 2 siblings.
** Siblings must be on the Lua stack, first one at index 1.
*/
static TTree *newroot2sib (lua_State *L, int tag) {
  int s1, s2;
  TTree *tree1 = getpatt(L, 1, &s1);
  TTree *tree2 = getpatt(L, 2, &s2);
  TTree *tree = newtree(L, 1 + s1 + s2);  /* create new tree */
  tree->tag = tag;
  tree->u.ps =  1 + s1;
  memcpy(sib1(tree), tree1, s1 * sizeof(TTree));
  memcpy(sib2(tree), tree2, s2 * sizeof(TTree));
  joinktables(L, 1, sib2(tree), 2);
  return tree;
}


static int lp_P (lua_State *L) {
  luaL_checkany(L, 1);
  getpatt(L, 1, NULL);
  lua_settop(L, 1);
  return 1;
}


/*
** sequence operator; optimizations:
** false x => false, x true => x, true x => x
** (cannot do x . false => false because x may have runtime captures)
*/
static int lp_seq (lua_State *L) {
  TTree *tree1 = getpatt(L, 1, NULL);
  TTree *tree2 = getpatt(L, 2, NULL);
  if (tree1->tag == TFalse || tree2->tag == TTrue)
    lua_pushvalue(L, 1);  /* false . x == false, x . true = x */
  else if (tree1->tag == TTrue)
    lua_pushvalue(L, 2);  /* true . x = x */
  else
    newroot2sib(L, TSeq);
  return 1;
}


/*
** choice operator; optimizations:
** charset / charset => charset
** true / x => true, x / false => x, false / x => x
** (x / true is not equivalent to true)
*/
static int lp_choice (lua_State *L) {
  Charset st1, st2;
  TTree *t1 = getpatt(L, 1, NULL);
  TTree *t2 = getpatt(L, 2, NULL);
  if (tocharset(t1, &st1) && tocharset(t2, &st2)) {
    loopset(i, st1.cs[i] |= st2.cs[i]);
    newcharset(L, st1.cs);
  }
  else if (nofail(t1) || t2->tag == TFalse)
    lua_pushvalue(L, 1);  /* true / x => true, x / false => x */
  else if (t1->tag == TFalse)
    lua_pushvalue(L, 2);  /* false / x => x */
  else
    newroot2sib(L, TChoice);
  return 1;
}


/*
** p^n
*/
static int lp_star (lua_State *L) {
  int size1;
  int n = (int)luaL_checkinteger(L, 2);
  TTree *tree1 = getpatt(L, 1, &size1);
  if (n >= 0) {  /* seq tree1 (seq tree1 ... (seq tree1 (rep tree1))) */
    TTree *tree = newtree(L, (n + 1) * (size1 + 1));
    if (nullable(tree1))
      luaL_error(L, "loop body may accept empty string");
    while (n--)  /* repeat 'n' times */
      tree = seqaux(tree, tree1, size1);
    tree->tag = TRep;
    memcpy(sib1(tree), tree1, size1 * sizeof(TTree));
  }
  else {  /* choice (seq tree1 ... choice tree1 true ...) true */
    TTree *tree;
    n = -n;
    /* size = (choice + seq + tree1 + true) * n, but the last has no seq */
    tree = newtree(L, n * (size1 + 3) - 1);
    for (; n > 1; n--) {  /* repeat (n - 1) times */
      tree->tag = TChoice; tree->u.ps = n * (size1 + 3) - 2;
      sib2(tree)->tag = TTrue;
      tree = sib1(tree);
      tree = seqaux(tree, tree1, size1);
    }
    tree->tag = TChoice; tree->u.ps = size1 + 1;
    sib2(tree)->tag = TTrue;
    memcpy(sib1(tree), tree1, size1 * sizeof(TTree));
  }
  copyktable(L, 1);
  return 1;
}


/*
** #p == &p
*/
static int lp_and (lua_State *L) {
  newroot1sib(L, TAnd);
  return 1;
}


/*
** -p == !p
*/
static int lp_not (lua_State *L) {
  newroot1sib(L, TNot);
  return 1;
}


/*
** [t1 - t2] == Seq (Not t2) t1
** If t1 and t2 are charsets, make their difference.
*/
static int lp_sub (lua_State *L) {
  Charset st1, st2;
  int s1, s2;
  TTree *t1 = getpatt(L, 1, &s1);
  TTree *t2 = getpatt(L, 2, &s2);
  if (tocharset(t1, &st1) && tocharset(t2, &st2)) {
    loopset(i, st1.cs[i] &= ~st2.cs[i]);
    newcharset(L, st1.cs);
  }
  else {
    TTree *tree = newtree(L, 2 + s1 + s2);
    tree->tag = TSeq;  /* sequence of... */
    tree->u.ps =  2 + s2;
    sib1(tree)->tag = TNot;  /* ...not... */
    memcpy(sib1(sib1(tree)), t2, s2 * sizeof(TTree));  /* ...t2 */
    memcpy(sib2(tree), t1, s1 * sizeof(TTree));  /* ... and t1 */
    joinktables(L, 1, sib1(tree), 2);
  }
  return 1;
}


static int lp_set (lua_State *L) {
  size_t l;
  const char *s = luaL_checklstring(L, 1, &l);
  byte buff[CHARSETSIZE];
  clearset(buff);
  while (l--) {
    setchar(buff, (byte)(*s));
    s++;
  }
  newcharset(L, buff);
  return 1;
}


static int lp_range (lua_State *L) {
  int arg;
  int top = lua_gettop(L);
  byte buff[CHARSETSIZE];
  clearset(buff);
  for (arg = 1; arg <= top; arg++) {
    int c;
    size_t l;
    const char *r = luaL_checklstring(L, arg, &l);
    luaL_argcheck(L, l == 2, arg, "range must have two characters");
    for (c = (byte)r[0]; c <= (byte)r[1]; c++)
      setchar(buff, c);
  }
  newcharset(L, buff);
  return 1;
}


/*
** Fills a tree node with basic information about the UTF-8 code point
** 'cpu': its value in 'n', its length in 'cap', and its first byte in
** 'key'
*/
static void codeutftree (lua_State *L, TTree *t, lua_Unsigned cpu, int arg) {
  int len, fb, cp;
  cp = (int)cpu;
  if (cp <= 0x7f) {  /* one byte? */
    len = 1;
    fb = cp;
  } else if (cp <= 0x7ff) {
    len = 2;
    fb = 0xC0 | (cp >> 6);
  } else if (cp <= 0xffff) {
    len = 3;
    fb = 0xE0 | (cp >> 12);
  }
  else {
    luaL_argcheck(L, cpu <= 0x10ffffu, arg, "invalid code point");
    len = 4;
    fb = 0xF0 | (cp >> 18);
  }
  t->u.n = cp;
  t->cap = len;
  t->key = fb;
}


static int lp_utfr (lua_State *L) {
  lua_Unsigned from = (lua_Unsigned)luaL_checkinteger(L, 1);
  lua_Unsigned to = (lua_Unsigned)luaL_checkinteger(L, 2);
  luaL_argcheck(L, from <= to, 2, "empty range");
  if (to <= 0x7f) {  /* ascii range? */
    uint f;
    byte buff[CHARSETSIZE];  /* code it as a regular charset */
    clearset(buff);
    for (f = (int)from; f <= to; f++)
      setchar(buff, f);
    newcharset(L, buff);
  }
  else {  /* multi-byte utf-8 range */
    TTree *tree = newtree(L, 2);
    tree->tag = TUTFR;
    codeutftree(L, tree, from, 1);
    sib1(tree)->tag = TXInfo;
    codeutftree(L, sib1(tree), to, 2);
  }
  return 1;
}


/*
** Look-behind predicate
*/
static int lp_behind (lua_State *L) {
  TTree *tree;
  TTree *tree1 = getpatt(L, 1, NULL);
  int n = fixedlen(tree1);
  luaL_argcheck(L, n >= 0, 1, "pattern may not have fixed length");
  luaL_argcheck(L, !hascaptures(tree1), 1, "pattern have captures");
  luaL_argcheck(L, n <= MAXBEHIND, 1, "pattern too long to look behind");
  tree = newroot1sib(L, TBehind);
  tree->u.n = n;
  return 1;
}


/*
** Create a non-terminal
*/
static int lp_V (lua_State *L) {
  TTree *tree = newleaf(L, TOpenCall);
  luaL_argcheck(L, !lua_isnoneornil(L, 1), 1, "non-nil value expected");
  tree->key = addtonewktable(L, 0, 1);
  return 1;
}


/*
** Create a tree for a non-empty capture, with a body and
** optionally with an associated Lua value (at index 'labelidx' in the
** stack)
*/
static int capture_aux (lua_State *L, int cap, int labelidx) {
  TTree *tree = newroot1sib(L, TCapture);
  tree->cap = cap;
  tree->key = (labelidx == 0) ? 0 : addtonewktable(L, 1, labelidx);
  return 1;
}


/*
** Fill a tree with an empty capture, using an empty (TTrue) sibling.
** (The 'key' field must be filled by the caller to finish the tree.)
*/
static TTree *auxemptycap (TTree *tree, int cap) {
  tree->tag = TCapture;
  tree->cap = cap;
  sib1(tree)->tag = TTrue;
  return tree;
}


/*
** Create a tree for an empty capture.
*/
static TTree *newemptycap (lua_State *L, int cap, int key) {
  TTree *tree = auxemptycap(newtree(L, 2), cap);
  tree->key = key;
  return tree;
}


/*
** Create a tree for an empty capture with an associated Lua value.
*/
static TTree *newemptycapkey (lua_State *L, int cap, int idx) {
  TTree *tree = auxemptycap(newtree(L, 2), cap);
  tree->key = addtonewktable(L, 0, idx);
  return tree;
}


/*
** Captures with syntax p / v
** (function capture, query capture, string capture, or number capture)
*/
static int lp_divcapture (lua_State *L) {
  switch (lua_type(L, 2)) {
    case LUA_TFUNCTION: return capture_aux(L, Cfunction, 2);
    case LUA_TTABLE: return capture_aux(L, Cquery, 2);
    case LUA_TSTRING: return capture_aux(L, Cstring, 2);
    case LUA_TNUMBER: {
      int n = lua_tointeger(L, 2);
      TTree *tree = newroot1sib(L, TCapture);
      luaL_argcheck(L, 0 <= n && n <= SHRT_MAX, 1, "invalid number");
      tree->cap = Cnum;
      tree->key = n;
      return 1;
    }
    default:
      return luaL_error(L, "unexpected %s as 2nd operand to LPeg '/'",
                           luaL_typename(L, 2));
  }
}


static int lp_acccapture (lua_State *L) {
  return capture_aux(L, Cacc, 2);
}


static int lp_substcapture (lua_State *L) {
  return capture_aux(L, Csubst, 0);
}


static int lp_tablecapture (lua_State *L) {
  return capture_aux(L, Ctable, 0);
}


static int lp_groupcapture (lua_State *L) {
  if (lua_isnoneornil(L, 2))
    return capture_aux(L, Cgroup, 0);
  else
    return capture_aux(L, Cgroup, 2);
}


static int lp_foldcapture (lua_State *L) {
  luaL_checktype(L, 2, LUA_TFUNCTION);
  return capture_aux(L, Cfold, 2);
}


static int lp_simplecapture (lua_State *L) {
  return capture_aux(L, Csimple, 0);
}


static int lp_poscapture (lua_State *L) {
  newemptycap(L, Cposition, 0);
  return 1;
}


static int lp_argcapture (lua_State *L) {
  int n = (int)luaL_checkinteger(L, 1);
  luaL_argcheck(L, 0 < n && n <= SHRT_MAX, 1, "invalid argument index");
  newemptycap(L, Carg, n);
  return 1;
}


static int lp_backref (lua_State *L) {
  luaL_checkany(L, 1);
  newemptycapkey(L, Cbackref, 1);
  return 1;
}


/*
** Constant capture
*/
static int lp_constcapture (lua_State *L) {
  int i;
  int n = lua_gettop(L);  /* number of values */
  if (n == 0)  /* no values? */
    newleaf(L, TTrue);  /* no capture */
  else if (n == 1)
    newemptycapkey(L, Cconst, 1);  /* single constant capture */
  else {  /* create a group capture with all values */
    TTree *tree = newtree(L, 1 + 3 * (n - 1) + 2);
    newktable(L, n);  /* create a 'ktable' for new tree */
    tree->tag = TCapture;
    tree->cap = Cgroup;
    tree->key = 0;
    tree = sib1(tree);
    for (i = 1; i <= n - 1; i++) {
      tree->tag = TSeq;
      tree->u.ps = 3;  /* skip TCapture and its sibling */
      auxemptycap(sib1(tree), Cconst);
      sib1(tree)->key = addtoktable(L, i);
      tree = sib2(tree);
    }
    auxemptycap(tree, Cconst);
    tree->key = addtoktable(L, i);
  }
  return 1;
}


static int lp_matchtime (lua_State *L) {
  TTree *tree;
  luaL_checktype(L, 2, LUA_TFUNCTION);
  tree = newroot1sib(L, TRunTime);
  tree->key = addtonewktable(L, 1, 2);
  return 1;
}

/* }====================================================== */


/*
** {======================================================
** Grammar - Tree generation
** =======================================================
*/

/*
** push on the stack the index and the pattern for the
** initial rule of grammar at index 'arg' in the stack;
** also add that index into position table.
*/
static void getfirstrule (lua_State *L, int arg, int postab) {
  lua_rawgeti(L, arg, 1);  /* access first element */
  if (lua_isstring(L, -1)) {  /* is it the name of initial rule? */
    lua_pushvalue(L, -1);  /* duplicate it to use as key */
    lua_gettable(L, arg);  /* get associated rule */
  }
  else {
    lua_pushinteger(L, 1);  /* key for initial rule */
    lua_insert(L, -2);  /* put it before rule */
  }
  if (!testpattern(L, -1)) {  /* initial rule not a pattern? */
    if (lua_isnil(L, -1))
      luaL_error(L, "grammar has no initial rule");
    else
      luaL_error(L, "initial rule '%s' is not a pattern", lua_tostring(L, -2));
  }
  lua_pushvalue(L, -2);  /* push key */
  lua_pushinteger(L, 1);  /* push rule position (after TGrammar) */
  lua_settable(L, postab);  /* insert pair at position table */
}

/*
** traverse grammar at index 'arg', pushing all its keys and patterns
** into the stack. Create a new table (before all pairs key-pattern) to
** collect all keys and their associated positions in the final tree
** (the "position table").
** Return the number of rules and (in 'totalsize') the total size
** for the new tree.
*/
static int collectrules (lua_State *L, int arg, int *totalsize) {
  int n = 1;  /* to count number of rules */
  int postab = lua_gettop(L) + 1;  /* index of position table */
  int size;  /* accumulator for total size */
  lua_newtable(L);  /* create position table */
  getfirstrule(L, arg, postab);
  size = 3 + getsize(L, postab + 2);  /* TGrammar + TRule + TXInfo + rule */
  lua_pushnil(L);  /* prepare to traverse grammar table */
  while (lua_next(L, arg) != 0) {
    if (lua_tonumber(L, -2) == 1 ||
        lp_equal(L, -2, postab + 1)) {  /* initial rule? */
      lua_pop(L, 1);  /* remove value (keep key for lua_next) */
      continue;
    }
    if (!testpattern(L, -1))  /* value is not a pattern? */
      luaL_error(L, "rule '%s' is not a pattern", val2str(L, -2));
    luaL_checkstack(L, LUA_MINSTACK, "grammar has too many rules");
    lua_pushvalue(L, -2);  /* push key (to insert into position table) */
    lua_pushinteger(L, size);
    lua_settable(L, postab);
    size += 2 + getsize(L, -1);  /* add 'TRule + TXInfo + rule' to size */
    lua_pushvalue(L, -2);  /* push key (for next lua_next) */
    n++;
  }
  *totalsize = size + 1;  /* space for 'TTrue' finishing list of rules */
  return n;
}


static void buildgrammar (lua_State *L, TTree *grammar, int frule, int n) {
  int i;
  TTree *nd = sib1(grammar);  /* auxiliary pointer to traverse the tree */
  for (i = 0; i < n; i++) {  /* add each rule into new tree */
    int ridx = frule + 2*i + 1;  /* index of i-th rule */
    int rulesize;
    TTree *rn = gettree(L, ridx, &rulesize);
    TTree *pr = sib1(nd);  /* points to rule's prerule */
    nd->tag = TRule;
    nd->key = 0;  /* will be fixed when rule is used */
    pr->tag = TXInfo;
    pr->u.n = i;  /* rule number */
    nd->u.ps = rulesize + 2;  /* point to next rule */
    memcpy(sib1(pr), rn, rulesize * sizeof(TTree));  /* copy rule */
    mergektable(L, ridx, sib1(nd));  /* merge its ktable into new one */
    nd = sib2(nd);  /* move to next rule */
  }
  nd->tag = TTrue;  /* finish list of rules */
}


/*
** Check whether a tree has potential infinite loops
*/
static int checkloops (TTree *tree) {
 tailcall:
  if (tree->tag == TRep && nullable(sib1(tree)))
    return 1;
  else if (tree->tag == TGrammar)
    return 0;  /* sub-grammars already checked */
  else {
    switch (numsiblings[tree->tag]) {
      case 1:  /* return checkloops(sib1(tree)); */
        tree = sib1(tree); goto tailcall;
      case 2:
        if (checkloops(sib1(tree))) return 1;
        /* else return checkloops(sib2(tree)); */
        tree = sib2(tree); goto tailcall;
      default: assert(numsiblings[tree->tag] == 0); return 0;
    }
  }
}


/*
** Give appropriate error message for 'verifyrule'. If a rule appears
** twice in 'passed', there is path from it back to itself without
** advancing the subject.
*/
static int verifyerror (lua_State *L, unsigned short *passed, int npassed) {
  int i, j;
  for (i = npassed - 1; i >= 0; i--) {  /* search for a repetition */
    for (j = i - 1; j >= 0; j--) {
      if (passed[i] == passed[j]) {
        lua_rawgeti(L, -1, passed[i]);  /* get rule's key */
        return luaL_error(L, "rule '%s' may be left recursive", val2str(L, -1));
      }
    }
  }
  return luaL_error(L, "too many left calls in grammar");
}


/*
** Check whether a rule can be left recursive; raise an error in that
** case; otherwise return 1 iff pattern is nullable.
** The return value is used to check sequences, where the second pattern
** is only relevant if the first is nullable.
** Parameter 'nb' works as an accumulator, to allow tail calls in
** choices. ('nb' true makes function returns true.)
** Parameter 'passed' is a list of already visited rules, 'npassed'
** counts the elements in 'passed'.
** Assume ktable at the top of the stack.
*/
static int verifyrule (lua_State *L, TTree *tree, unsigned short *passed,
                                     int npassed, int nb) {
 tailcall:
  switch (tree->tag) {
    case TChar: case TSet: case TAny:
    case TFalse: case TUTFR:
      return nb;  /* cannot pass from here */
    case TTrue:
    case TBehind:  /* look-behind cannot have calls */
      return 1;
    case TNot: case TAnd: case TRep:
      /* return verifyrule(L, sib1(tree), passed, npassed, 1); */
      tree = sib1(tree); nb = 1; goto tailcall;
    case TCapture: case TRunTime: case TXInfo:
      /* return verifyrule(L, sib1(tree), passed, npassed, nb); */
      tree = sib1(tree); goto tailcall;
    case TCall:
      /* return verifyrule(L, sib2(tree), passed, npassed, nb); */
      tree = sib2(tree); goto tailcall;
    case TSeq:  /* only check 2nd child if first is nb */
      if (!verifyrule(L, sib1(tree), passed, npassed, 0))
        return nb;
      /* else return verifyrule(L, sib2(tree), passed, npassed, nb); */
      tree = sib2(tree); goto tailcall;
    case TChoice:  /* must check both children */
      nb = verifyrule(L, sib1(tree), passed, npassed, nb);
      /* return verifyrule(L, sib2(tree), passed, npassed, nb); */
      tree = sib2(tree); goto tailcall;
    case TRule:
      if (npassed >= MAXRULES)  /* too many steps? */
        return verifyerror(L, passed, npassed);  /* error */
      else {
        passed[npassed++] = tree->key;  /* add rule to path */
        /* return verifyrule(L, sib1(tree), passed, npassed); */
        tree = sib1(tree); goto tailcall;
      }
    case TGrammar:
      return nullable(tree);  /* sub-grammar cannot be left recursive */
    default: assert(0); return 0;
  }
}


static void verifygrammar (lua_State *L, TTree *grammar) {
  unsigned short passed[MAXRULES];
  TTree *rule;
  /* check left-recursive rules */
  for (rule = sib1(grammar); rule->tag == TRule; rule = sib2(rule)) {
    if (rule->key == 0) continue;  /* unused rule */
    verifyrule(L, sib1(rule), passed, 0, 0);
  }
  assert(rule->tag == TTrue);
  /* check infinite loops inside rules */
  for (rule = sib1(grammar); rule->tag == TRule; rule = sib2(rule)) {
    if (rule->key == 0) continue;  /* unused rule */
    if (checkloops(sib1(rule))) {
      lua_rawgeti(L, -1, rule->key);  /* get rule's key */
      luaL_error(L, "empty loop in rule '%s'", val2str(L, -1));
    }
  }
  assert(rule->tag == TTrue);
}


/*
** Give a name for the initial rule if it is not referenced
*/
static void initialrulename (lua_State *L, TTree *grammar, int frule) {
  if (sib1(grammar)->key == 0) {  /* initial rule is not referenced? */
    int n = lua_rawlen(L, -1) + 1;  /* index for name */
    lua_pushvalue(L, frule);  /* rule's name */
    lua_rawseti(L, -2, n);  /* ktable was on the top of the stack */
    sib1(grammar)->key = n;
  }
}


static TTree *newgrammar (lua_State *L, int arg) {
  int treesize;
  int frule = lua_gettop(L) + 2;  /* position of first rule's key */
  int n = collectrules(L, arg, &treesize);
  TTree *g = newtree(L, treesize);
  luaL_argcheck(L, n <= MAXRULES, arg, "grammar has too many rules");
  g->tag = TGrammar;  g->u.n = n;
  lua_newtable(L);  /* create 'ktable' */
  lua_setuservalue(L, -2);
  buildgrammar(L, g, frule, n);
  lua_getuservalue(L, -1);  /* get 'ktable' for new tree */
  finalfix(L, frule - 1, g, sib1(g));
  initialrulename(L, g, frule);
  verifygrammar(L, g);
  lua_pop(L, 1);  /* remove 'ktable' */
  lua_insert(L, -(n * 2 + 2));  /* move new table to proper position */
  lua_pop(L, n * 2 + 1);  /* remove position table + rule pairs */
  return g;  /* new table at the top of the stack */
}

/* }====================================================== */


static Instruction *prepcompile (lua_State *L, Pattern *p, int idx) {
  lua_getuservalue(L, idx);  /* push 'ktable' (may be used by 'finalfix') */
  finalfix(L, 0, NULL, p->tree);
  lua_pop(L, 1);  /* remove 'ktable' */
  return compile(L, p, getsize(L, idx));
}


static int lp_printtree (lua_State *L) {
  TTree *tree = getpatt(L, 1, NULL);
  int c = lua_toboolean(L, 2);
  if (c) {
    lua_getuservalue(L, 1);  /* push 'ktable' (may be used by 'finalfix') */
    finalfix(L, 0, NULL, tree);
    lua_pop(L, 1);  /* remove 'ktable' */
  }
  printktable(L, 1);
  printtree(tree, 0);
  return 0;
}


static int lp_printcode (lua_State *L) {
  Pattern *p = getpattern(L, 1);
  printktable(L, 1);
  if (p->code == NULL)  /* not compiled yet? */
    prepcompile(L, p, 1);
  printpatt(p->code);
  return 0;
}


/*
** Get the initial position for the match, interpreting negative
** values from the end of the subject
*/
static size_t initposition (lua_State *L, size_t len) {
  lua_Integer ii = luaL_optinteger(L, 3, 1);
  if (ii > 0) {  /* positive index? */
    if ((size_t)ii <= len)  /* inside the string? */
      return (size_t)ii - 1;  /* return it (corrected to 0-base) */
    else return len;  /* crop at the end */
  }
  else {  /* negative index */
    if ((size_t)(-ii) <= len)  /* inside the string? */
      return len - ((size_t)(-ii));  /* return position from the end */
    else return 0;  /* crop at the beginning */
  }
}


/*
** Main match function
*/
static int lp_match (lua_State *L) {
  Capture capture[INITCAPSIZE];
  const char *r;
  size_t l;
  Pattern *p = (getpatt(L, 1, NULL), getpattern(L, 1));
  Instruction *code = (p->code != NULL) ? p->code : prepcompile(L, p, 1);
  const char *s = luaL_checklstring(L, SUBJIDX, &l);
  size_t i = initposition(L, l);
  int ptop = lua_gettop(L);
  luaL_argcheck(L, l < MAXINDT, SUBJIDX, "subject too long");
  lua_pushnil(L);  /* initialize subscache */
  lua_pushlightuserdata(L, capture);  /* initialize caplistidx */
  lua_getuservalue(L, 1);  /* initialize ktableidx */
  r = match(L, s, s + i, s + l, code, capture, ptop);
  if (r == NULL) {
    lua_pushnil(L);
    return 1;
  }
  return getcaptures(L, s, r, ptop);
}



/*
** {======================================================
** Library creation and functions not related to matching
** =======================================================
*/

/* maximum limit for stack size */
#define MAXLIM		(INT_MAX / 100)

static int lp_setmax (lua_State *L) {
  lua_Integer lim = luaL_checkinteger(L, 1);
  luaL_argcheck(L, 0 < lim && lim <= MAXLIM, 1, "out of range");
  lua_settop(L, 1);
  lua_setfield(L, LUA_REGISTRYINDEX, MAXSTACKIDX);
  return 0;
}


static int lp_type (lua_State *L) {
  if (testpattern(L, 1))
    lua_pushliteral(L, "pattern");
  else
    lua_pushnil(L);
  return 1;
}


int lp_gc (lua_State *L) {
  Pattern *p = getpattern(L, 1);
  freecode(L, p);  /* delete code block */
  return 0;
}


/*
** Create a charset representing a category of characters, given by
** the predicate 'catf'.
*/
static void createcat (lua_State *L, const char *catname, int (catf) (int)) {
  int c;
  byte buff[CHARSETSIZE];
  clearset(buff);
  for (c = 0; c <= UCHAR_MAX; c++)
    if (catf(c)) setchar(buff, c);
  newcharset(L, buff);
  lua_setfield(L, -2, catname);
}


static int lp_locale (lua_State *L) {
  if (lua_isnoneornil(L, 1)) {
    lua_settop(L, 0);
    lua_createtable(L, 0, 12);
  }
  else {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_settop(L, 1);
  }
  createcat(L, "alnum", isalnum);
  createcat(L, "alpha", isalpha);
  createcat(L, "cntrl", iscntrl);
  createcat(L, "digit", isdigit);
  createcat(L, "graph", isgraph);
  createcat(L, "lower", islower);
  createcat(L, "print", isprint);
  createcat(L, "punct", ispunct);
  createcat(L, "space", isspace);
  createcat(L, "upper", isupper);
  createcat(L, "xdigit", isxdigit);
  return 1;
}


static struct luaL_Reg pattreg[] = {
  {"ptree", lp_printtree},
  {"pcode", lp_printcode},
  {"match", lp_match},
  {"B", lp_behind},
  {"V", lp_V},
  {"C", lp_simplecapture},
  {"Cc", lp_constcapture},
  {"Cmt", lp_matchtime},
  {"Cb", lp_backref},
  {"Carg", lp_argcapture},
  {"Cp", lp_poscapture},
  {"Cs", lp_substcapture},
  {"Ct", lp_tablecapture},
  {"Cf", lp_foldcapture},
  {"Cg", lp_groupcapture},
  {"P", lp_P},
  {"S", lp_set},
  {"R", lp_range},
  {"utfR", lp_utfr},
  {"locale", lp_locale},
  {"version", NULL},
  {"setmaxstack", lp_setmax},
  {"type", lp_type},
  {NULL, NULL}
};


static struct luaL_Reg metareg[] = {
  {"__mul", lp_seq},
  {"__add", lp_choice},
  {"__pow", lp_star},
  {"__gc", lp_gc},
  {"__len", lp_and},
  {"__div", lp_divcapture},
  {"__mod", lp_acccapture},
  {"__unm", lp_not},
  {"__sub", lp_sub},
  {NULL, NULL}
};


int luaopen_lpeg (lua_State *L);
int luaopen_lpeg (lua_State *L) {
  luaL_newmetatable(L, PATTERN_T);
  lua_pushnumber(L, MAXBACK);  /* initialize maximum backtracking */
  lua_setfield(L, LUA_REGISTRYINDEX, MAXSTACKIDX);
  luaL_setfuncs(L, metareg, 0);
  luaL_register(L, "lpeg", pattreg); // Nvim: inline conflicting luaL_newlib macro
  lua_pushvalue(L, -1);
  lua_setfield(L, -3, "__index");
  lua_pushliteral(L, "LPeg " VERSION);
  lua_setfield(L, -2, "version");
  return 1;
}

/* }====================================================== */
