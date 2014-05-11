#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static _Bool is_alive(Job *job);
static Job *find_job(int id);
static void free_job(Job *job);
static void job_prepare_cb(uv_prepare_t *handle);
static void read_cb(RStream *rstream, void *data, _Bool eof);
static void exit_cb(uv_process_t *proc, int64_t status, int term_signal);
static void emit_exit_event(Job *job);
static void close_cb(uv_handle_t *handle);
#include "func_attr.h"
