#include "nvim/event/queue.h"

void ut_queue_put(Queue *queue, const char *str);
const char *ut_queue_get(Queue *queue);
