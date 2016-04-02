# Set ${ARCHITECTURE} to the target arch
# either X86 or X86_64
include(CheckSymbolExists)

set(ARCHITECTURE NOTFOUND)

# X86
check_symbol_exists("_M_IX86" "" T_M_IX86)
check_symbol_exists("__i386__" "" T_I386)
if(T_M_IX86 OR T_I386)
  set(ARCHITECTURE "X86")
  return()
endif()


# X86_64
check_symbol_exists("_M_AMD64" "" T_M_AMD64)
check_symbol_exists("__x86_64__" "" T_X86_64)
check_symbol_exists("__amd64__" "" T_AMD64)

if(T_M_AMD64 OR T_X86_64 OR T_AMD64)
  set(ARCHITECTURE "X86_64")
  return()
endif()
