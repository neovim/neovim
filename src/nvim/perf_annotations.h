#ifndef PERF_ANNOTATIONS_H
#define PERF_ANNOTATIONS_H 1

#ifdef USE_NVTX
#  include "nvtx3/nvToolsExt.h"
#endif

#ifdef USE_TRACY
#  include "TracyC.h"
#  include <string.h>
#endif

#if USE_TRACY
void perf_range_push_tracy(const char* name);
void perf_range_pop_tracy(void);
#endif

static inline void perf_range_push(const char* name)
{
#if USE_NVTX
  nvtxRangePushA(name);
#endif
#if USE_TRACY
  perf_range_push_tracy(name);
#endif
#if !(USE_NVTX || USE_TRACY)
  (void)name;
#endif
}

static inline void perf_range_pop(void)
{
#ifdef USE_NVTX
  nvtxRangePop();
#endif
#if USE_TRACY
  perf_range_pop_tracy();
#endif
}

static inline void perf_event(const char* name)
{
#ifdef USE_NVTX
  nvtxMarkA(name);
#endif
#ifdef USE_TRACY
  TracyCMessage(name, strlen(name));
#endif
#if !(USE_NVTX || USE_TRACY)
  (void)name;
#endif
}
#endif
