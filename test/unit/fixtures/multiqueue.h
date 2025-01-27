#include "nvim/event/multiqueue.h"

void ut_multiqueue_put(MultiQueue *self, const char *str);
const char *ut_multiqueue_get(MultiQueue *self);
