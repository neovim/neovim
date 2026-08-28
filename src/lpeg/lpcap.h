
#if !defined(lpcap_h)
#define lpcap_h


#include "lptypes.h"


/* kinds of captures */
typedef enum CapKind {
  Cclose,  /* not used in trees */
  Cposition,
  Cconst,  /* ktable[key] is Lua constant */
  Cbackref,  /* ktable[key] is "name" of group to get capture */
  Carg,  /* 'key' is arg's number */
  Csimple,  /* next node is pattern */
  Ctable,  /* next node is pattern */
  Cfunction,  /* ktable[key] is function; next node is pattern */
  Cacc,  /* ktable[key] is function; next node is pattern */
  Cquery,  /* ktable[key] is table; next node is pattern */
  Cstring,  /* ktable[key] is string; next node is pattern */
  Cnum,  /* numbered capture; 'key' is number of value to return */
  Csubst,  /* substitution capture; next node is pattern */
  Cfold,  /* ktable[key] is function; next node is pattern */
  Cruntime,  /* not used in trees (is uses another type for tree) */
  Cgroup  /* ktable[key] is group's "name" */
} CapKind;


/*
** An unsigned integer large enough to index any subject entirely.
** It can be size_t, but that will double the size of the array
** of captures in a 64-bit machine.
*/
#if !defined(Index_t)
typedef uint Index_t;
#endif

#define MAXINDT		(~(Index_t)0)


typedef struct Capture {
  Index_t index;  /* subject position */
  unsigned short idx;  /* extra info (group name, arg index, etc.) */
  byte kind;  /* kind of capture */
  byte siz;  /* size of full capture + 1 (0 = not a full capture) */
} Capture;


typedef struct CapState {
  Capture *cap;  /* current capture */
  Capture *ocap;  /* (original) capture list */
  lua_State *L;
  int ptop;  /* stack index of last argument to 'match' */
  int firstcap;  /* stack index of first capture pushed in the stack */
  const char *s;  /* original string */
  int valuecached;  /* value stored in cache slot */
  int reclevel;  /* recursion level */
} CapState;


#define captype(cap)    ((cap)->kind)

#define isclosecap(cap) (captype(cap) == Cclose)
#define isopencap(cap)  ((cap)->siz == 0)

/* true if c2 is (any number of levels) inside c1 */
#define capinside(c1,c2)  \
	(isopencap(c1) ? !isclosecap(c2) \
                       : (c2)->index < (c1)->index + (c1)->siz - 1)


/**
** Maximum number of captures to visit when looking for an 'open'.
*/
#define MAXLOP		20



int runtimecap (CapState *cs, Capture *close, const char *s, int *rem);
int getcaptures (lua_State *L, const char *s, const char *r, int ptop);
int finddyncap (Capture *cap, Capture *last);

#endif


