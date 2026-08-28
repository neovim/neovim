/*
** LPeg - PEG pattern matching for Lua
** Copyright 2007-2023, Lua.org & PUC-Rio  (see 'lpeg.html' for license)
** written by Roberto Ierusalimschy
*/

#if !defined(lptypes_h)
#define lptypes_h


#include <assert.h>
#include <limits.h>
#include <string.h>

#include "lua.h"


#define VERSION         "1.1.0"


#define PATTERN_T	"lpeg-pattern"
#define MAXSTACKIDX	"lpeg-maxstack"


/*
** compatibility with Lua 5.1
*/
#if (LUA_VERSION_NUM == 501)

#define lp_equal	lua_equal

#define lua_getuservalue	lua_getfenv
#define lua_setuservalue	lua_setfenv

#define lua_rawlen		lua_objlen

#define luaL_setfuncs(L,f,n)	luaL_register(L,NULL,f)
// #define luaL_newlib(L,f)	luaL_register(L,"lpeg",f) // Nvim: conflicts with LuaJIT

typedef size_t lua_Unsigned;

#endif


#if !defined(lp_equal)
#define lp_equal(L,idx1,idx2)  lua_compare(L,(idx1),(idx2),LUA_OPEQ)
#endif


/* default maximum size for call/backtrack stack */
#if !defined(MAXBACK)
#define MAXBACK         400
#endif


/* maximum number of rules in a grammar (limited by 'unsigned short') */
#if !defined(MAXRULES)
#define MAXRULES        1000
#endif



/* initial size for capture's list */
#define INITCAPSIZE	32


/* index, on Lua stack, for subject */
#define SUBJIDX		2

/* number of fixed arguments to 'match' (before capture arguments) */
#define FIXEDARGS	3

/* index, on Lua stack, for capture list */
#define caplistidx(ptop)	((ptop) + 2)

/* index, on Lua stack, for pattern's ktable */
#define ktableidx(ptop)		((ptop) + 3)

/* index, on Lua stack, for backtracking stack */
#define stackidx(ptop)	((ptop) + 4)



typedef unsigned char byte;

typedef unsigned int uint;


#define BITSPERCHAR		8

#define CHARSETSIZE		((UCHAR_MAX/BITSPERCHAR) + 1)



typedef struct Charset {
  byte cs[CHARSETSIZE];
} Charset;



#define loopset(v,b)    { int v; for (v = 0; v < CHARSETSIZE; v++) {b;} }

#define fillset(s,c)	memset(s,c,CHARSETSIZE)
#define clearset(s)	fillset(s,0)

/* number of slots needed for 'n' bytes */
#define bytes2slots(n)  (((n) - 1u) / (uint)sizeof(TTree) + 1u)

/* set 'b' bit in charset 'cs' */
#define setchar(cs,b)   ((cs)[(b) >> 3] |= (1 << ((b) & 7)))


/*
** in capture instructions, 'kind' of capture and its offset are
** packed in field 'aux', 4 bits for each
*/
#define getkind(op)		((op)->i.aux1 & 0xF)
#define getoff(op)		(((op)->i.aux1 >> 4) & 0xF)
#define joinkindoff(k,o)	((k) | ((o) << 4))

#define MAXOFF		0xF
#define MAXAUX		0xFF


/* maximum number of bytes to look behind */
#define MAXBEHIND	MAXAUX


/* maximum size (in elements) for a pattern */
#define MAXPATTSIZE	(SHRT_MAX - 10)


/* size (in instructions) for l bytes (l > 0) */
#define instsize(l) ((int)(((l) + (uint)sizeof(Instruction) - 1u) \
			/ (uint)sizeof(Instruction)))


/* size (in elements) for a ISet instruction */
#define CHARSETINSTSIZE		(1 + instsize(CHARSETSIZE))

/* size (in elements) for a IFunc instruction */
#define funcinstsize(p)		((p)->i.aux + 2)



#define testchar(st,c)	((((uint)(st)[((c) >> 3)]) >> ((c) & 7)) & 1)


#endif

