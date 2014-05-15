#ifndef NVIM_OS_UV_HELPERS_H
#define NVIM_OS_UV_HELPERS_H

#include <uv.h>

#include "nvim/os/wstream_defs.h"
#include "nvim/os/rstream_defs.h"
#include "nvim/os/job_defs.h"

/// Gets the RStream instance associated with a libuv handle
///
/// @param handle libuv handle
/// @return the RStream pointer
RStream *handle_get_rstream(uv_handle_t *handle);

/// Associates a RStream instance with a libuv handle
///
/// @param handle libuv handle
/// @param rstream the RStream pointer
void handle_set_rstream(uv_handle_t *handle, RStream *rstream);

/// Gets the WStream instance associated with a libuv handle
///
/// @param handle libuv handle
/// @return the WStream pointer
WStream *handle_get_wstream(uv_handle_t *handle);

/// Associates a WStream instance with a libuv handle
///
/// @param handle libuv handle
/// @param wstream the WStream pointer
void handle_set_wstream(uv_handle_t *handle, WStream *wstream);

/// Gets the Job instance associated with a libuv handle
///
/// @param handle libuv handle
/// @return the Job pointer
Job *handle_get_job(uv_handle_t *handle);

/// Associates a Job instance with a libuv handle
///
/// @param handle libuv handle
/// @param job the Job pointer
void handle_set_job(uv_handle_t *handle, Job *job);

#endif  // NVIM_OS_UV_HELPERS_H

