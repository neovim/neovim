
#if !defined(lptree_h)
#define lptree_h


#include "lptypes.h"


/*
** types of trees
*/
typedef enum TTag {
  TChar = 0,  /* 'n' = char */
  TSet,  /* the set is encoded in 'u.set' and the next 'u.set.size' bytes */
  TAny,
  TTrue,
  TFalse,
  TUTFR,  /* range of UTF-8 codepoints; 'n' has initial codepoint;
             'cap' has length; 'key' has first byte;
             extra info is similar for end codepoint */
  TRep,  /* 'sib1'* */
  TSeq,  /* 'sib1' 'sib2' */
  TChoice,  /* 'sib1' / 'sib2' */
  TNot,  /* !'sib1' */
  TAnd,  /* &'sib1' */
  TCall,  /* ktable[key] is rule's key; 'sib2' is rule being called */
  TOpenCall,  /* ktable[key] is rule's key */
  TRule,  /* ktable[key] is rule's key (but key == 0 for unused rules);
             'sib1' is rule's pattern pre-rule; 'sib2' is next rule;
             extra info 'n' is rule's sequential number */
  TXInfo,  /* extra info */
  TGrammar,  /* 'sib1' is initial (and first) rule */
  TBehind,  /* 'sib1' is pattern, 'n' is how much to go back */
  TCapture,  /* captures: 'cap' is kind of capture (enum 'CapKind');
                ktable[key] is Lua value associated with capture;
                'sib1' is capture body */
  TRunTime  /* run-time capture: 'key' is Lua function;
               'sib1' is capture body */
} TTag;


/*
** Tree trees
** The first child of a tree (if there is one) is immediately after
** the tree.  A reference to a second child (ps) is its position
** relative to the position of the tree itself.
*/
typedef struct TTree {
  byte tag;
  byte cap;  /* kind of capture (if it is a capture) */
  unsigned short key;  /* key in ktable for Lua data (0 if no key) */
  union {
    int ps;  /* occasional second child */
    int n;  /* occasional counter */
    struct {
      byte offset;  /* compact set offset (in bytes) */
      byte size;  /* compact set size (in bytes) */
      byte deflt;  /* default value */
      byte bitmap[1];  /* bitmap (open array) */
    } set;  /* for compact sets */
  } u;
} TTree;


/* access to charset */
#define treebuffer(t)      ((t)->u.set.bitmap)


/*
** A complete pattern has its tree plus, if already compiled,
** its corresponding code
*/
typedef struct Pattern {
  union Instruction *code;
  TTree tree[1];
} Pattern;


/* number of children for each tree */
extern const byte numsiblings[];

/* access to children */
#define sib1(t)         ((t) + 1)
#define sib2(t)         ((t) + (t)->u.ps)






#endif

