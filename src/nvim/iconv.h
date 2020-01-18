#ifndef NVIM_ICONV_H
#define NVIM_ICONV_H

#include "auto/config.h"

#ifdef HAVE_ICONV
#  include <errno.h>
#  include <iconv.h>

// define some missing constants if necessary
#  ifndef EILSEQ
#   define EILSEQ 123
#  endif
#  define ICONV_ERRNO errno
#  define ICONV_E2BIG  E2BIG
#  define ICONV_EINVAL EINVAL
#  define ICONV_EILSEQ EILSEQ
#endif

#endif  // NVIM_ICONV_H
