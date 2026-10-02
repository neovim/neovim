
#include <limits.h>
#include <string.h>


#include "lua.h"
#include "lauxlib.h"

#include "lpcap.h"
#include "lptypes.h"
#include "lpvm.h"
#include "lpprint.h"


/* initial size for call/backtrack stack */
#if !defined(INITBACK)
#define INITBACK	MAXBACK
#endif


#define getoffset(p)	(((p) + 1)->offset)

static const Instruction giveup = {{IGiveup, 0, {0}}};


int charinset (const Instruction *i, const byte *buff, uint c) {
  c -= i->i.aux2.set.offset;
  if (c >= ((uint)i->i.aux2.set.size  /* size in instructions... */
           * (uint)sizeof(Instruction)  /* in bytes... */
           * 8u))  /* in bits */
    return i->i.aux1;  /* out of range; return default value */
  return testchar(buff, c);
}


/*
** Decode one UTF-8 sequence, returning NULL if byte sequence is invalid.
*/
static const char *utf8_decode (const char *o, int *val) {
  static const uint limits[] = {0xFF, 0x7F, 0x7FF, 0xFFFFu};
  const unsigned char *s = (const unsigned char *)o;
  uint c = s[0];  /* first byte */
  uint res = 0;  /* final result */
  if (c < 0x80)  /* ascii? */
    res = c;
  else {
    int count = 0;  /* to count number of continuation bytes */
    while (c & 0x40) {  /* still have continuation bytes? */
      int cc = s[++count];  /* read next byte */
      if ((cc & 0xC0) != 0x80)  /* not a continuation byte? */
        return NULL;  /* invalid byte sequence */
      res = (res << 6) | (cc & 0x3F);  /* add lower 6 bits from cont. byte */
      c <<= 1;  /* to test next bit */
    }
    res |= (c & 0x7F) << (count * 5);  /* add first byte */
    if (count > 3 || res > 0x10FFFFu || res <= limits[count])
      return NULL;  /* invalid byte sequence */
    s += count;  /* skip continuation bytes read */
  }
  *val = res;
  return (const char *)s + 1;  /* +1 to include first byte */
}


/*
** {======================================================
** Virtual Machine
** =======================================================
*/


typedef struct Stack {
  const char *s;  /* saved position (or NULL for calls) */
  const Instruction *p;  /* next instruction */
  int caplevel;
} Stack;


#define getstackbase(L, ptop)	((Stack *)lua_touserdata(L, stackidx(ptop)))


/*
** Ensures the size of array 'capture' (with size '*capsize' and
** 'captop' elements being used) is enough to accomodate 'n' extra
** elements plus one.  (Because several opcodes add stuff to the capture
** array, it is simpler to ensure the array always has at least one free
** slot upfront and check its size later.)
*/

/* new size in number of elements cannot overflow integers, and new
   size in bytes cannot overflow size_t. */
#define MAXNEWSIZE  \
    (((size_t)INT_MAX) <= (~(size_t)0 / sizeof(Capture)) ?  \
     ((size_t)INT_MAX) : (~(size_t)0 / sizeof(Capture)))

static Capture *growcap (lua_State *L, Capture *capture, int *capsize,
                                       int captop, int n, int ptop) {
  if (*capsize - captop > n)
    return capture;  /* no need to grow array */
  else {  /* must grow */
    Capture *newc;
    uint newsize = captop + n + 1;  /* minimum size needed */
    if (newsize < (MAXNEWSIZE / 3) * 2)
      newsize += newsize / 2;  /* 1.5 that size, if not too big */
    else if (newsize < (MAXNEWSIZE / 9) * 8)
      newsize += newsize / 8;  /* else, try 9/8 that size */
    else
      luaL_error(L, "too many captures");
    newc = (Capture *)lua_newuserdata(L, newsize * sizeof(Capture));
    memcpy(newc, capture, captop * sizeof(Capture));
    *capsize = newsize;
    lua_replace(L, caplistidx(ptop));
    return newc;
  }
}


/*
** Double the size of the stack
*/
static Stack *doublestack (lua_State *L, Stack **stacklimit, int ptop) {
  Stack *stack = getstackbase(L, ptop);
  Stack *newstack;
  int n = *stacklimit - stack;  /* current stack size */
  int max, newn;
  lua_getfield(L, LUA_REGISTRYINDEX, MAXSTACKIDX);
  max = lua_tointeger(L, -1);  /* maximum allowed size */
  lua_pop(L, 1);
  if (n >= max)  /* already at maximum size? */
    luaL_error(L, "backtrack stack overflow (current limit is %d)", max);
  newn = 2 * n;  /* new size */
  if (newn > max) newn = max;
  newstack = (Stack *)lua_newuserdata(L, newn * sizeof(Stack));
  memcpy(newstack, stack, n * sizeof(Stack));
  lua_replace(L, stackidx(ptop));
  *stacklimit = newstack + newn;
  return newstack + n;  /* return next position */
}


/*
** Interpret the result of a dynamic capture: false -> fail;
** true -> keep current position; number -> next position.
** Return new subject position. 'fr' is stack index where
** is the result; 'curr' is current subject position; 'limit'
** is subject's size.
*/
static int resdyncaptures (lua_State *L, int fr, int curr, int limit) {
  lua_Integer res;
  if (!lua_toboolean(L, fr)) {  /* false value? */
    lua_settop(L, fr - 1);  /* remove results */
    return -1;  /* and fail */
  }
  else if (lua_isboolean(L, fr))  /* true? */
    res = curr;  /* keep current position */
  else {
    res = lua_tointeger(L, fr) - 1;  /* new position */
    if (res < curr || res > limit)
      luaL_error(L, "invalid position returned by match-time capture");
  }
  lua_remove(L, fr);  /* remove first result (offset) */
  return res;
}


/*
** Add capture values returned by a dynamic capture to the list
** 'capture', nested inside a group. 'fd' indexes the first capture
** value, 'n' is the number of values (at least 1). The open group
** capture is already in 'capture', before the place for the new entries.
*/
static void adddyncaptures (Index_t index, Capture *capture, int n, int fd) {
  int i;
  assert(capture[-1].kind == Cgroup && capture[-1].siz == 0);
  capture[-1].idx = 0;  /* make group capture an anonymous group */
  for (i = 0; i < n; i++) {  /* add runtime captures */
    capture[i].kind = Cruntime;
    capture[i].siz = 1;  /* mark it as closed */
    capture[i].idx = fd + i;  /* stack index of capture value */
    capture[i].index = index;
  }
  capture[n].kind = Cclose;  /* close group */
  capture[n].siz = 1;
  capture[n].index = index;
}


/*
** Remove dynamic captures from the Lua stack (called in case of failure)
*/
static int removedyncap (lua_State *L, Capture *capture,
                         int level, int last) {
  int id = finddyncap(capture + level, capture + last);  /* index of 1st cap. */
  int top = lua_gettop(L);
  if (id == 0) return 0;  /* no dynamic captures? */
  lua_settop(L, id - 1);  /* remove captures */
  return top - id + 1;  /* number of values removed */
}


/*
** Find the corresponding 'open' capture before 'cap', when that capture
** can become a full capture. If a full capture c1 is followed by an
** empty capture c2, there is no way to know whether c2 is inside
** c1. So, full captures can enclose only captures that start *before*
** its end.
*/
static Capture *findopen (Capture *cap, Index_t currindex) {
  int i;
  cap--;  /* check last capture */
  /* Must it be inside current one, but starts where current one ends? */
  if (!isopencap(cap) && cap->index == currindex)
    return NULL;  /* current one cannot be a full capture */
  /* else, look for an 'open' capture */
  for (i = 0; i < MAXLOP; i++, cap--) {
    if (currindex - cap->index >= UCHAR_MAX)
      return NULL;  /* capture too long for a full capture */
    else if (isopencap(cap))  /* open capture? */
      return cap;  /* that's the one to be closed */
    else if (cap->kind == Cclose)
      return NULL;  /* a full capture should not nest a non-full one */
  }
  return NULL;  /* not found within allowed search limit */
}


/*
** Opcode interpreter
*/
const char *match (lua_State *L, const char *o, const char *s, const char *e,
                   Instruction *op, Capture *capture, int ptop) {
  Stack stackbase[INITBACK];
  Stack *stacklimit = stackbase + INITBACK;
  Stack *stack = stackbase;  /* point to first empty slot in stack */
  int capsize = INITCAPSIZE;
  int captop = 0;  /* point to first empty slot in captures */
  int ndyncap = 0;  /* number of dynamic captures (in Lua stack) */
  const Instruction *p = op;  /* current instruction */
  stack->p = &giveup; stack->s = s; stack->caplevel = 0; stack++;
  lua_pushlightuserdata(L, stackbase);
  for (;;) {
#if defined(DEBUG)
      printf("-------------------------------------\n");
      printcaplist(capture, capture + captop);
      printf("s: |%s| stck:%d, dyncaps:%d, caps:%d  ",
             s, (int)(stack - getstackbase(L, ptop)), ndyncap, captop);
      printinst(op, p);
#endif
    assert(stackidx(ptop) + ndyncap == lua_gettop(L) && ndyncap <= captop);
    switch ((Opcode)p->i.code) {
      case IEnd: {
        assert(stack == getstackbase(L, ptop) + 1);
        capture[captop].kind = Cclose;
        capture[captop].index = MAXINDT;
        return s;
      }
      case IGiveup: {
        assert(stack == getstackbase(L, ptop));
        return NULL;
      }
      case IRet: {
        assert(stack > getstackbase(L, ptop) && (stack - 1)->s == NULL);
        p = (--stack)->p;
        continue;
      }
      case IAny: {
        if (s < e) { p++; s++; }
        else goto fail;
        continue;
      }
      case IUTFR: {
        int codepoint;
        if (s >= e)
          goto fail;
        s = utf8_decode (s, &codepoint);
        if (s && p[1].offset <= codepoint && codepoint <= utf_to(p))
          p += 2;
        else
          goto fail;
        continue;
      }
      case ITestAny: {
        if (s < e) p += 2;
        else p += getoffset(p);
        continue;
      }
      case IChar: {
        if ((byte)*s == p->i.aux1 && s < e) { p++; s++; }
        else goto fail;
        continue;
      }
      case ITestChar: {
        if ((byte)*s == p->i.aux1 && s < e) p += 2;
        else p += getoffset(p);
        continue;
      }
      case ISet: {
        uint c = (byte)*s;
        if (charinset(p, (p+1)->buff, c) && s < e)
          { p += 1 + p->i.aux2.set.size; s++; }
        else goto fail;
        continue;
      }
      case ITestSet: {
        uint c = (byte)*s;
        if (charinset(p, (p + 2)->buff, c) && s < e)
          p += 2 + p->i.aux2.set.size;
        else p += getoffset(p);
        continue;
      }
      case IBehind: {
        int n = p->i.aux1;
        if (n > s - o) goto fail;
        s -= n; p++;
        continue;
      }
      case ISpan: {
        for (; s < e; s++) {
          uint c = (byte)*s;
          if (!charinset(p, (p+1)->buff, c)) break;
        }
        p += 1 + p->i.aux2.set.size;
        continue;
      }
      case IJmp: {
        p += getoffset(p);
        continue;
      }
      case IChoice: {
        if (stack == stacklimit)
          stack = doublestack(L, &stacklimit, ptop);
        stack->p = p + getoffset(p);
        stack->s = s;
        stack->caplevel = captop;
        stack++;
        p += 2;
        continue;
      }
      case ICall: {
        if (stack == stacklimit)
          stack = doublestack(L, &stacklimit, ptop);
        stack->s = NULL;
        stack->p = p + 2;  /* save return address */
        stack++;
        p += getoffset(p);
        continue;
      }
      case ICommit: {
        assert(stack > getstackbase(L, ptop) && (stack - 1)->s != NULL);
        stack--;
        p += getoffset(p);
        continue;
      }
      case IPartialCommit: {
        assert(stack > getstackbase(L, ptop) && (stack - 1)->s != NULL);
        (stack - 1)->s = s;
        (stack - 1)->caplevel = captop;
        p += getoffset(p);
        continue;
      }
      case IBackCommit: {
        assert(stack > getstackbase(L, ptop) && (stack - 1)->s != NULL);
        s = (--stack)->s;
        if (ndyncap > 0)  /* are there matchtime captures? */
          ndyncap -= removedyncap(L, capture, stack->caplevel, captop);
        captop = stack->caplevel;
        p += getoffset(p);
        continue;
      }
      case IFailTwice:
        assert(stack > getstackbase(L, ptop));
        stack--;
        /* FALLTHROUGH */
      case IFail:
      fail: { /* pattern failed: try to backtrack */
        do {  /* remove pending calls */
          assert(stack > getstackbase(L, ptop));
          s = (--stack)->s;
        } while (s == NULL);
        if (ndyncap > 0)  /* is there matchtime captures? */
          ndyncap -= removedyncap(L, capture, stack->caplevel, captop);
        captop = stack->caplevel;
        p = stack->p;
#if defined(DEBUG)
        printf("**FAIL**\n");
#endif
        continue;
      }
      case ICloseRunTime: {
        CapState cs;
        int rem, res, n;
        int fr = lua_gettop(L) + 1;  /* stack index of first result */
        cs.reclevel = 0; cs.L = L;
        cs.s = o; cs.ocap = capture; cs.ptop = ptop;
        n = runtimecap(&cs, capture + captop, s, &rem);  /* call function */
        captop -= n;  /* remove nested captures */
        ndyncap -= rem;  /* update number of dynamic captures */
        fr -= rem;  /* 'rem' items were popped from Lua stack */
        res = resdyncaptures(L, fr, s - o, e - o);  /* get result */
        if (res == -1)  /* fail? */
          goto fail;
        s = o + res;  /* else update current position */
        n = lua_gettop(L) - fr + 1;  /* number of new captures */
        ndyncap += n;  /* update number of dynamic captures */
        if (n == 0)  /* no new captures? */
          captop--;  /* remove open group */
        else {  /* new captures; keep original open group */
          if (fr + n >= SHRT_MAX)
            luaL_error(L, "too many results in match-time capture");
          /* add new captures + close group to 'capture' list */
          capture = growcap(L, capture, &capsize, captop, n + 1, ptop);
          adddyncaptures(s - o, capture + captop, n, fr);
          captop += n + 1;  /* new captures + close group */
        }
        p++;
        continue;
      }
      case ICloseCapture: {
        Capture *open = findopen(capture + captop, s - o);
        assert(captop > 0);
        if (open) {  /* if possible, turn capture into a full capture */
          open->siz = (s - o) - open->index + 1;
          p++;
          continue;
        }
        else {  /* must create a close capture */
          capture[captop].siz = 1;  /* mark entry as closed */
          capture[captop].index = s - o;
          goto pushcapture;
        }
      }
      case IOpenCapture:
        capture[captop].siz = 0;  /* mark entry as open */
        capture[captop].index = s - o;
        goto pushcapture;
      case IFullCapture:
        capture[captop].siz = getoff(p) + 1;  /* save capture size */
        capture[captop].index = s - o - getoff(p);
        /* goto pushcapture; */
      pushcapture: {
        capture[captop].idx = p->i.aux2.key;
        capture[captop].kind = getkind(p);
        captop++;
        capture = growcap(L, capture, &capsize, captop, 0, ptop);
        p++;
        continue;
      }
      default: assert(0); return NULL;
    }
  }
}

/* }====================================================== */


