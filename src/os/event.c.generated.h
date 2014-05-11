#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static void timer_cb(uv_timer_t *handle);
static void timer_prepare_cb(uv_prepare_t *handle);
#include "func_attr.h"
