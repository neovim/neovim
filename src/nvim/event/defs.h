#ifndef NVIM_EVENT_DEFS_H
#define NVIM_EVENT_DEFS_H

#include <assert.h>
#include <stdarg.h>

#define EVENT_HANDLER_MAX_ARGC 9

typedef void (*argv_callback)(void **argv);
typedef struct message {
  argv_callback handler;
  void *argv[EVENT_HANDLER_MAX_ARGC];
} Event;
typedef void(*event_scheduler)(Event event, void *data);

#define VA_EVENT_INIT(event, h, a) \
  do { \
    assert(a <= EVENT_HANDLER_MAX_ARGC); \
    (event)->handler = h; \
    if (a) { \
      va_list args; \
      va_start(args, a); \
      for (int i = 0; i < a; i++) { \
        (event)->argv[i] = va_arg(args, void *); \
      } \
      va_end(args); \
    } \
  } while (0)

static inline Event event_create(argv_callback cb, int argc, ...)
{
  assert(argc <= EVENT_HANDLER_MAX_ARGC);
  Event event;
  VA_EVENT_INIT(&event, cb, argc);
  return event;
}

#endif  // NVIM_EVENT_DEFS_H
