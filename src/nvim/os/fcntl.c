#define _GNU_SOURCE
#include "nvim/os/fcntl.h"

#ifndef O_NOFOLLOW
# define O_NOFOLLOW 0
#endif
const int kO_NOFOLLOW = O_NOFOLLOW;
