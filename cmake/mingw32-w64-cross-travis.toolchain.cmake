#
# Mingw-w64 cross compiler toolchain
#
# - The usual CMAKE variables will point to the cross compiler
# - HOST_EXE_LINKER, HOST_C_COMPILER, HOST_EXE_LINKER_FLAGS,
#   HOST_C_FLAGS point to a host compiler
#

set(MINGW_TRIPLET i686-w64-mingw32)
# For x86_64 use
#set(MINGW_TRIPLET x86_64-w64-mingw32)

# The location of your toolchain sys-root
set(MINGW_PREFIX_PATH /opt/mingw32/${MINGW_TRIPLET}/)
# or sometimes like this
#set(MINGW_PREFIX_PATH /usr/${MINGW_TRIPLET}/sys-root)

# the name of the target operating system
set(CMAKE_SYSTEM_NAME Windows)

# which compilers to use for C and C++
set(CMAKE_C_COMPILER ${MINGW_TRIPLET}-gcc)
set(CMAKE_CXX_COMPILER ${MINGW_TRIPLET}-g++)
set(CMAKE_RC_COMPILER ${MINGW_TRIPLET}-windres)
set(CMAKE_C_COMPILER ${MINGW_TRIPLET}-gcc)
set(CMAKE_CXX_COMPILER ${MINGW_TRIPLET}-g++)
set(CMAKE_RC_COMPILER ${MINGW_TRIPLET}-windres)

# Where is the target environment located
set(CMAKE_FIND_ROOT_PATH "${MINGW_PREFIX_PATH}/mingw")

# adjust the default behaviour of the FIND_XXX() commands:
# search headers and libraries in the target environment, search
# programs in the host environment
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

set(CROSS_TARGET ${MINGW_TRIPLET})

# We need a host compiler too - assuming mildly sane Unix
# defaults here
set(HOST_C_COMPILER cc)
set(HOST_EXE_LINKER ld)

if (MINGW_TRIPLET MATCHES "^x86_64")
  set(HOST_C_FLAGS)
  set(HOST_EXE_LINKER_FLAGS)
else()
  # In 32 bits systems have the HOST compiler generate 32 bits binaries
  set(HOST_C_FLAGS -m32)
  set(HOST_EXE_LINKER_FLAGS -m32)
endif()
