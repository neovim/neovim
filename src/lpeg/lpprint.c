
#include <ctype.h>
#include <limits.h>
#include <stdio.h>


#include "lptypes.h"
#include "lpprint.h"
#include "lpcode.h"


#if defined(LPEG_DEBUG)

/*
** {======================================================
** Printing patterns (for debugging)
** =======================================================
*/


void printcharset (const byte *st) {
  int i;
  printf("[");
  for (i = 0; i <= UCHAR_MAX; i++) {
    int first = i;
    while (i <= UCHAR_MAX && testchar(st, i)) i++;
    if (i - 1 == first)  /* unary range? */
      printf("(%02x)", first);
    else if (i - 1 > first)  /* non-empty range? */
      printf("(%02x-%02x)", first, i - 1);
  }
  printf("]");
}


static void printIcharset (const Instruction *inst, const byte *buff) {
  byte cs[CHARSETSIZE];
  int i;
  printf("(%02x-%d) ", inst->i.aux2.set.offset, inst->i.aux2.set.size);
  clearset(cs);
  for (i = 0; i < CHARSETSIZE * 8; i++) {
    if (charinset(inst, buff, i))
      setchar(cs, i);
  }
  printcharset(cs);
}


static void printTcharset (TTree *tree) {
  byte cs[CHARSETSIZE];
  int i;
  printf("(%02x-%d) ", tree->u.set.offset, tree->u.set.size);
  fillset(cs, tree->u.set.deflt);
  for (i = 0; i < tree->u.set.size; i++)
    cs[tree->u.set.offset + i] = treebuffer(tree)[i];
  printcharset(cs);
}


static const char *capkind (int kind) {
  const char *const modes[] = {
    "close", "position", "constant", "backref",
    "argument", "simple", "table", "function", "accumulator",
    "query", "string", "num", "substitution", "fold",
    "runtime", "group"};
  return modes[kind];
}


static void printjmp (const Instruction *op, const Instruction *p) {
  printf("-> %d", (int)(p + (p + 1)->offset - op));
}


void printinst (const Instruction *op, const Instruction *p) {
  const char *const names[] = {
    "any", "char", "set",
    "testany", "testchar", "testset",
    "span", "utf-range", "behind",
    "ret", "end",
    "choice", "jmp", "call", "open_call",
    "commit", "partial_commit", "back_commit", "failtwice", "fail", "giveup",
     "fullcapture", "opencapture", "closecapture", "closeruntime",
     "--"
  };
  printf("%02ld: %s ", (long)(p - op), names[p->i.code]);
  switch ((Opcode)p->i.code) {
    case IChar: {
      printf("'%c' (%02x)", p->i.aux1, p->i.aux1);
      break;
    }
    case ITestChar: {
      printf("'%c' (%02x)", p->i.aux1, p->i.aux1); printjmp(op, p);
      break;
    }
    case IUTFR: {
      printf("%d - %d", p[1].offset, utf_to(p));
      break;
    }
    case IFullCapture: {
      printf("%s (size = %d)  (idx = %d)",
             capkind(getkind(p)), getoff(p), p->i.aux2.key);
      break;
    }
    case IOpenCapture: {
      printf("%s (idx = %d)", capkind(getkind(p)), p->i.aux2.key);
      break;
    }
    case ISet: {
      printIcharset(p, (p+1)->buff);
      break;
    }
    case ITestSet: {
      printIcharset(p, (p+2)->buff); printjmp(op, p);
      break;
    }
    case ISpan: {
      printIcharset(p, (p+1)->buff);
      break;
    }
    case IOpenCall: {
      printf("-> %d", (p + 1)->offset);
      break;
    }
    case IBehind: {
      printf("%d", p->i.aux1);
      break;
    }
    case IJmp: case ICall: case ICommit: case IChoice:
    case IPartialCommit: case IBackCommit: case ITestAny: {
      printjmp(op, p);
      break;
    }
    default: break;
  }
  printf("\n");
}


void printpatt (Instruction *p) {
  Instruction *op = p;
  uint n = op[-1].codesize - 1;
  while (p < op + n) {
    printinst(op, p);
    p += sizei(p);
  }
}


static void printcap (Capture *cap, int ident) {
  while (ident--) printf(" ");
  printf("%s (idx: %d - size: %d) -> %lu  (%p)\n",
         capkind(cap->kind), cap->idx, cap->siz, (long)cap->index, (void*)cap);
}


/*
** Print a capture and its nested captures
*/
static Capture *printcap2close (Capture *cap, int ident) {
  Capture *head = cap++;
  printcap(head, ident);  /* print head capture */
  while (capinside(head, cap))
    cap = printcap2close(cap, ident + 2);  /* print nested captures */
  if (isopencap(head)) {
    assert(isclosecap(cap));
    printcap(cap++, ident);  /* print and skip close capture */
  }
  return cap;
}


void printcaplist (Capture *cap) {
  {  /* for debugging, print first a raw list of captures */
    Capture *c = cap;
    while (c->index != MAXINDT) { printcap(c, 0); c++; }
  }
  printf(">======\n");
  while (!isclosecap(cap))
    cap = printcap2close(cap, 0);
  printf("=======\n");
}

/* }====================================================== */


/*
** {======================================================
** Printing trees (for debugging)
** =======================================================
*/

static const char *tagnames[] = {
  "char", "set", "any",
  "true", "false", "utf8.range",
  "rep",
  "seq", "choice",
  "not", "and",
  "call", "opencall", "rule", "xinfo", "grammar",
  "behind",
  "capture", "run-time"
};


void printtree (TTree *tree, int ident) {
  int i;
  int sibs = numsiblings[tree->tag];
  for (i = 0; i < ident; i++) printf(" ");
  printf("%s", tagnames[tree->tag]);
  switch (tree->tag) {
    case TChar: {
      int c = tree->u.n;
      if (isprint(c))
        printf(" '%c'\n", c);
      else
        printf(" (%02X)\n", c);
      break;
    }
    case TSet: {
      printTcharset(tree);
      printf("\n");
      break;
    }
    case TUTFR: {
      assert(sib1(tree)->tag == TXInfo);
      printf(" %d (%02x %d) - %d (%02x %d) \n",
        tree->u.n, tree->key, tree->cap,
        sib1(tree)->u.n, sib1(tree)->key, sib1(tree)->cap);
      break;
    }
    case TOpenCall: case TCall: {
      assert(sib1(sib2(tree))->tag == TXInfo);
      printf(" key: %d  (rule: %d)\n", tree->key, sib1(sib2(tree))->u.n);
      break;
    }
    case TBehind: {
      printf(" %d\n", tree->u.n);
      break;
    }
    case TCapture: {
      printf(" kind: '%s'  key: %d\n", capkind(tree->cap), tree->key);
      break;
    }
    case TRule: {
      printf(" key: %d\n", tree->key);
      sibs = 1;  /* do not print 'sib2' (next rule) as a sibling */
      break;
    }
    case TXInfo: {
      printf(" n: %d\n", tree->u.n);
      break;
    }
    case TGrammar: {
      TTree *rule = sib1(tree);
      printf(" %d\n", tree->u.n);  /* number of rules */
      for (i = 0; i < tree->u.n; i++) {
        printtree(rule, ident + 2);
        rule = sib2(rule);
      }
      assert(rule->tag == TTrue);  /* sentinel */
      sibs = 0;  /* siblings already handled */
      break;
    }
    default:
      printf("\n");
      break;
  }
  if (sibs >= 1) {
    printtree(sib1(tree), ident + 2);
    if (sibs >= 2)
      printtree(sib2(tree), ident + 2);
  }
}


void printktable (lua_State *L, int idx) {
  int n, i;
  lua_getuservalue(L, idx);
  if (lua_isnil(L, -1))  /* no ktable? */
    return;
  n = lua_rawlen(L, -1);
  printf("[");
  for (i = 1; i <= n; i++) {
    printf("%d = ", i);
    lua_rawgeti(L, -1, i);
    if (lua_isstring(L, -1))
      printf("%s  ", lua_tostring(L, -1));
    else
      printf("%s  ", lua_typename(L, lua_type(L, -1)));
    lua_pop(L, 1);
  }
  printf("]\n");
  /* leave ktable at the stack */
}

/* }====================================================== */

#endif
