
#if !defined(lpvm_h)
#define lpvm_h

#include "lpcap.h"


/*
** About Character sets in instructions: a set is a bit map with an
** initial offset, in bits, and a size, in number of instructions.
** aux1 has the default value for the bits outsize that range.
*/


/* Virtual Machine's instructions */
typedef enum Opcode {
  IAny, /* if no char, fail */
  IChar,  /* if char != aux1, fail */
  ISet,  /* if char not in set, fail */
  ITestAny,  /* in no char, jump to 'offset' */
  ITestChar,  /* if char != aux1, jump to 'offset' */
  ITestSet,  /* if char not in set, jump to 'offset' */
  ISpan,  /* read a span of chars in set */
  IUTFR,  /* if codepoint not in range [offset, utf_to], fail */
  IBehind,  /* walk back 'aux1' characters (fail if not possible) */
  IRet,  /* return from a rule */
  IEnd,  /* end of pattern */
  IChoice,  /* stack a choice; next fail will jump to 'offset' */
  IJmp,  /* jump to 'offset' */
  ICall,  /* call rule at 'offset' */
  IOpenCall,  /* call rule number 'key' (must be closed to a ICall) */
  ICommit,  /* pop choice and jump to 'offset' */
  IPartialCommit,  /* update top choice to current position and jump */
  IBackCommit,  /* backtrack like "fail" but jump to its own 'offset' */
  IFailTwice,  /* pop one choice and then fail */
  IFail,  /* go back to saved state on choice and jump to saved offset */
  IGiveup,  /* internal use */
  IFullCapture,  /* complete capture of last 'off' chars */
  IOpenCapture,  /* start a capture */
  ICloseCapture,
  ICloseRunTime,
  IEmpty  /* to fill empty slots left by optimizations */
} Opcode;


/*
** All array of instructions has a 'codesize' as its first element
** and is referred by a pointer to its second element, which is the
** first actual opcode.
*/
typedef union Instruction {
  struct Inst {
    byte code;
    byte aux1;
    union {
      short key;
      struct {
        byte offset;
        byte size;
      } set;
    } aux2;
  } i;
  int offset;
  uint codesize;
  byte buff[1];
} Instruction;


/* extract 24-bit value from an instruction */
#define utf_to(inst)	(((inst)->i.aux2.key << 8) | (inst)->i.aux1)


int charinset (const Instruction *i, const byte *buff, uint c);
const char *match (lua_State *L, const char *o, const char *s, const char *e,
                   Instruction *op, Capture *capture, int ptop);


#endif

