#include <string.h>
#include <stdlib.h>
#include "nvim/event/queue.h"
#include "queue.h"


void ut_queue_put(Queue *queue, const char *str)
{
  queue_put(queue, NULL, 1, str);
}

const char *ut_queue_get(Queue *queue)
{
  Event event = queue_get(queue);
  return event.argv[0];
}
