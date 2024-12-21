#include <stdlib.h>
#include <string.h>

#include "multiqueue.h"

#include "nvim/event/multiqueue.h"

void ut_multiqueue_put(MultiQueue *self, const char *str)
{
  multiqueue_put(self, NULL, (void *)str);
}

const char *ut_multiqueue_get(MultiQueue *self)
{
  Event event = multiqueue_get(self);
  return event.argv[0];
}
