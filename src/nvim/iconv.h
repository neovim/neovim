#ifndef NVIM_ICONV_H
#define NVIM_ICONV_H

// iconv can be linked at compile-time as well as loaded at runtime. In the
// latter case, some function pointers need to be initialized after loading
// the library (see `iconv_enabled()` in mbyte.c). These function pointers
// are stored in globals.h. Since globals.h includes iconv.h to get the
// definition of USE_ICONV, we can't include it from iconv.h. One way to
// solve this conundrum would be perhaps to let cmake decide the value of
// USE_ICONV, or to put the USE_ICONV definition in config.h.in directly. As
// it stands, globals.h needs to be included alongside iconv.h.

#include "auto/config.h"

// Use iconv() when it's available, either by linking to the library at
// compile time or by loading it at runtime.
#if (defined(HAVE_ICONV_H) && defined(HAVE_ICONV)) || defined(DYNAMIC_ICONV)
# define USE_ICONV
#endif

// If we don't have the actual iconv header files present but USE_ICONV was
// defined, we provide a type shim (pull in errno.h and define iconv_t).
// This enables us to still load and use iconv dynamically at runtime.
#ifdef USE_ICONV
#  include <errno.h>
#  ifdef HAVE_ICONV_H
#    include <iconv.h>
#  else
typedef void *iconv_t;
#  endif
#endif

// define some missing constants if necessary
# ifdef USE_ICONV
#  ifndef EILSEQ
#   define EILSEQ 123
#  endif
#  ifdef DYNAMIC_ICONV
// on win32 iconv.dll is dynamically loaded
#   define ICONV_ERRNO (*iconv_errno())
#   define ICONV_E2BIG  7
#   define ICONV_EINVAL 22
#   define ICONV_EILSEQ 42
#  else
#   define ICONV_ERRNO errno
#   define ICONV_E2BIG  E2BIG
#   define ICONV_EINVAL EINVAL
#   define ICONV_EILSEQ EILSEQ
#  endif
# endif

#endif  // NVIM_ICONV_H
