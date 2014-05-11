#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static int tokenize(char_u *str, char **argv);
static int word_length(char_u *str);
static void write_selection(uv_write_t *req);
static void alloc_cb(uv_handle_t *handle, size_t suggested, uv_buf_t *buf);
static void read_cb(uv_stream_t *stream, ssize_t cnt, const uv_buf_t *buf);
static void write_cb(uv_write_t *req, int status);
static int proc_cleanup_exit(ProcessData *proc_data, uv_process_options_t *proc_opts, int shellopts);
static void exit_cb(uv_process_t *proc, int64_t status, int term_signal);
#include "func_attr.h"
