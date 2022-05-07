#  include "nvim/perf_annotations.h"

#if USE_TRACY
#  include <TracyC.h>
#  include <string.h>
#  define STACK_MAX 1024
static _Thread_local int counter = 0;
static _Thread_local TracyCZoneCtx ctx_stack[STACK_MAX];

void perf_range_push_tracy(const char* name) {
  if (counter < STACK_MAX) {
    TracyCZone(ctx, 1);
    ctx_stack[counter] = ctx;
    TracyCZoneName(ctx, name, strlen(name));
  }
  counter++;
}

void perf_range_pop_tracy(void) {
  counter--;
  if (counter < STACK_MAX) {
    TracyCZoneCtx ctx = ctx_stack[counter];
    TracyCZoneEnd(ctx);
  }
}
#endif
