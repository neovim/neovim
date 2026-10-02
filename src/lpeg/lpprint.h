
#if !defined(lpprint_h)
#define lpprint_h


#include "lptree.h"
#include "lpvm.h"


#if defined(LPEG_DEBUG)

void printpatt (Instruction *p);
void printtree (TTree *tree, int ident);
void printktable (lua_State *L, int idx);
void printcharset (const byte *st);
void printcaplist (Capture *cap);
void printinst (const Instruction *op, const Instruction *p);

#else

#define printktable(L,idx)  \
	luaL_error(L, "function only implemented in debug mode")
#define printtree(tree,i)  \
	luaL_error(L, "function only implemented in debug mode")
#define printpatt(p)  \
	luaL_error(L, "function only implemented in debug mode")

#endif


#endif

