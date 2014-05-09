#ifndef NVIM_OS_UV_HELPERS_H
#define NVIM_OS_UV_HELPERS_H

#include <uv.h>

#include "nvim/os/wstream_defs.h"
#include "nvim/os/rstream_defs.h"
#include "nvim/os/job_defs.h"

RStream *handle_get_rstream(uv_handle_t *handle);

void handle_set_rstream(uv_handle_t *handle, RStream *rstream);

WStream *handle_get_wstream(uv_handle_t *handle);

void handle_set_wstream(uv_handle_t *handle, WStream *wstream);

Job *handle_get_job(uv_handle_t *handle);

void handle_set_job(uv_handle_t *handle, Job *job);

#endif  // NVIM_OS_UV_HELPERS_H

