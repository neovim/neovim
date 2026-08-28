
#include "lptypes.h"
#include "lpcset.h"


/*
** Add to 'c' the index of the (only) bit set in byte 'b'
*/
static int onlybit (int c, int b) {
  if ((b & 0xF0) != 0) { c += 4; b >>= 4; }
  if ((b & 0x0C) != 0) { c += 2; b >>= 2; }
  if ((b & 0x02) != 0) { c += 1; }
  return c;
}


/*
** Check whether a charset is empty (returns IFail), singleton (IChar),
** full (IAny), or none of those (ISet). When singleton, 'info.offset'
** returns which character it is. When generic set, 'info' returns
** information about its range.
*/
Opcode charsettype (const byte *cs, charsetinfo *info) {
  int low0, low1, high0, high1;
  for (low1 = 0; low1 < CHARSETSIZE && cs[low1] == 0; low1++)
    /* find lowest byte with a 1-bit */;
  if (low1 == CHARSETSIZE)
    return IFail;  /* no characters in set */
  for (high1 = CHARSETSIZE - 1; cs[high1] == 0; high1--)
    /* find highest byte with a 1-bit; low1 is a sentinel */;
  if (low1 == high1) {  /* only one byte with 1-bits? */
    int b = cs[low1];
    if ((b & (b - 1)) == 0) {  /* does byte has only one 1-bit? */
      info->offset = onlybit(low1 * BITSPERCHAR, b);  /* get that bit */
      return IChar;  /* single character */
    }
  }
  for (low0 = 0; low0 < CHARSETSIZE && cs[low0] == 0xFF; low0++)
    /* find lowest byte with a 0-bit */;
  if (low0 == CHARSETSIZE)
    return IAny;  /* set has all bits set */
  for (high0 = CHARSETSIZE - 1; cs[high0] == 0xFF; high0--)
    /* find highest byte with a 0-bit; low0 is a sentinel */;
  if (high1 - low1 <= high0 - low0) {  /* range of 1s smaller than of 0s? */
    info->offset = low1;
    info->size = high1 - low1 + 1;
    info->deflt = 0;  /* all discharged bits were 0 */
  }
  else {
    info->offset = low0;
    info->size = high0 - low0 + 1;
    info->deflt = 0xFF;  /* all discharged bits were 1 */
  }
  info->cs = cs + info->offset;
  return ISet;
}


/*
** Get a byte from a compact charset. If index is inside the charset
** range, get the byte from the supporting charset (correcting it
** by the offset). Otherwise, return the default for the set.
*/
byte getbytefromcharset (const charsetinfo *info, int index) {
  if (index < info->size)
    return info->cs[index];
  else return info->deflt;
}


/*
** If 'tree' is a 'char' pattern (TSet, TChar, TAny, TFalse), convert it
** into a charset and return 1; else return 0.
*/
int tocharset (TTree *tree, Charset *cs) {
  switch (tree->tag) {
    case TChar: {  /* only one char */
      assert(0 <= tree->u.n && tree->u.n <= UCHAR_MAX);
      clearset(cs->cs);  /* erase all chars */
      setchar(cs->cs, tree->u.n);  /* add that one */
      return 1;
    }
    case TAny: {
      fillset(cs->cs, 0xFF);  /* add all characters to the set */
      return 1;
    }
    case TFalse: {
      clearset(cs->cs);  /* empty set */
      return 1;
    }
    case TSet: {  /* fill set */
      int i;
      fillset(cs->cs, tree->u.set.deflt);
      for (i = 0; i < tree->u.set.size; i++)
        cs->cs[tree->u.set.offset + i] = treebuffer(tree)[i];
      return 1;
    }
    default: return 0;
  }
}


void tree2cset (TTree *tree, charsetinfo *info) {
  assert(tree->tag == TSet);
  info->offset = tree->u.set.offset;
  info->size = tree->u.set.size;
  info->deflt = tree->u.set.deflt;
  info->cs = treebuffer(tree);
}

