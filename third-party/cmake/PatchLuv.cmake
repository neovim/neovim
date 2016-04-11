# replace luv default rockspec with the alternate one under the "rockspecs"
# directory
file(GLOB LUV_ROCKSPEC RELATIVE ${LUV_SRC_DIR} ${LUV_SRC_DIR}/*.rockspec)
file(RENAME ${LUV_SRC_DIR}/rockspecs/${LUV_ROCKSPEC} ${LUV_SRC_DIR}/${LUV_ROCKSPEC})

# Some versions of mingw are missing defines required by luv dns module, add
# them now
set(LUV_SRC_DNS_C_DEFS
"#ifndef AI_NUMERICSERV
# define AI_NUMERICSERV 0x0008
#endif
#ifndef AI_ALL
# define AI_ALL 0x00000100
#endif
#ifndef AI_ADDRCONFIG
# define AI_ADDRCONFIG 0x00000400
#endif
#ifndef AI_V4MAPPED
# define AI_V4MAPPED 0x00000800
#endif")

file(READ ${LUV_SRC_DIR}/src/dns.c LUV_SRC_DNS_C)
string(REPLACE
  "\n#include <netdb.h>"
  "\n#include <netdb.h>\n#else\n${LUV_SRC_DNS_C_DEFS}"
  LUV_SRC_DNS_C_PATCHED
  "${LUV_SRC_DNS_C}")
file(WRITE ${LUV_SRC_DIR}/src/dns.c "${LUV_SRC_DNS_C_PATCHED}")

