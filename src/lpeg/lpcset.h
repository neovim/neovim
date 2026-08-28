
#if !defined(lpset_h)
#define lpset_h

#include "lpcset.h"
#include "lpcode.h"
#include "lptree.h"


/*
** Extra information for the result of 'charsettype'.  When result is
** IChar, 'offset' is the character.  When result is ISet, 'cs' is the
** supporting bit array (with offset included), 'offset' is the offset
** (in bytes), 'size' is the size (in bytes), and 'delt' is the default
** value for bytes outside the set.
*/
typedef struct {
  const byte *cs;
  int offset;
  int size;
  int deflt;
} charsetinfo;


int tocharset (TTree *tree, Charset *cs);
Opcode charsettype (const byte *cs, charsetinfo *info);
byte getbytefromcharset (const charsetinfo *info, int index);
void tree2cset (TTree *tree, charsetinfo *info);

#endif
