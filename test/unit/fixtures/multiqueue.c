// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <string.h>
#include <stdlib.h>
#include "nvim/event/multiqueue.h"
#include "multiqueue.h"


void ut_multiqueue_put(MultiQueue *this, const char *str)
{
  multiqueue_put(this, NULL, 1, str);
}

const char *ut_multiqueue_get(MultiQueue *this)
{
  Event event = multiqueue_get(this);
  return event.argv[0];
}
