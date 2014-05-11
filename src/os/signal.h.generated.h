#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
void signal_init();
void signal_stop();
void signal_reject_deadly();
void signal_accept_deadly();
void signal_handle(Event event);
#include "func_attr.h"
