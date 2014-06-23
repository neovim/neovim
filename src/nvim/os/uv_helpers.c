#include <assert.h>
#include <uv.h>

#include "nvim/os/uv_helpers.h"
#include "nvim/vim.h"
#include "nvim/memory.h"

/// Common structure that will always be assigned to the `data` field of
/// libuv handles. It has fields for many types of pointers, and allow a single
/// handle to contain data from many sources
typedef struct {
  WStream *wstream;
  RStream *rstream;
  Job *job;
} HandleData;


#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/uv_helpers.c.generated.h"
#endif

/// Gets the RStream instance associated with a libuv handle
///
/// @param handle libuv handle
/// @return the RStream pointer
RStream *handle_get_rstream(uv_handle_t *handle)
{
  RStream *rv = init(handle)->rstream;
  assert(rv != NULL);
  return rv;
}

/// Associates a RStream instance with a libuv handle
///
/// @param handle libuv handle
/// @param rstream the RStream pointer
void handle_set_rstream(uv_handle_t *handle, RStream *rstream)
{
  init(handle)->rstream = rstream;
}

/// Gets the WStream instance associated with a libuv handle
///
/// @param handle libuv handle
/// @return the WStream pointer
WStream *handle_get_wstream(uv_handle_t *handle)
{
  WStream *rv = init(handle)->wstream;
  assert(rv != NULL);
  return rv;
}

/// Associates a WStream instance with a libuv handle
///
/// @param handle libuv handle
/// @param wstream the WStream pointer
void handle_set_wstream(uv_handle_t *handle, WStream *wstream)
{
  HandleData *data = init(handle);
  data->wstream = wstream;
}

/// Gets the Job instance associated with a libuv handle
///
/// @param handle libuv handle
/// @return the Job pointer
Job *handle_get_job(uv_handle_t *handle)
{
  Job *rv = init(handle)->job;
  assert(rv != NULL);
  return rv;
}

/// Associates a Job instance with a libuv handle
///
/// @param handle libuv handle
/// @param job the Job pointer
void handle_set_job(uv_handle_t *handle, Job *job)
{
  init(handle)->job = job;
}

static HandleData *init(uv_handle_t *handle)
{
  HandleData *rv;

  if (handle->data == NULL) {
    rv = xmalloc(sizeof(HandleData));
    rv->rstream = NULL;
    rv->wstream = NULL;
    rv->job = NULL;
    handle->data = rv;
  } else {
    rv = handle->data;
  }

  return rv;
}
