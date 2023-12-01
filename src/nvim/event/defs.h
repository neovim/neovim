#pragma once

#include <assert.h>
#include <stdarg.h>

enum { EVENT_HANDLER_MAX_ARGC = 10, };

typedef void (*argv_callback)(void **argv);
typedef struct {
  argv_callback handler;
  void *argv[EVENT_HANDLER_MAX_ARGC];
} Event;

#define event_create(cb, ...) ((Event){ .handler = cb, .argv = { __VA_ARGS__ } })
