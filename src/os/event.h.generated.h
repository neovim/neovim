#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
void event_init();
_Bool event_poll(int32_t ms);
_Bool event_is_pending();
void event_push(Event event);
void event_process();
#include "func_attr.h"
