#include "nvim/rbuffer.h"

typedef void(*each_ptr_cb)(char *ptr, size_t cnt);
typedef void(*each_cb)(char c, size_t i);

void ut_rbuffer_each_read_chunk(RBuffer *buf, each_ptr_cb cb);
void ut_rbuffer_each_write_chunk(RBuffer *buf, each_ptr_cb cb);
void ut_rbuffer_each(RBuffer *buf, each_cb cb);
void ut_rbuffer_each_reverse(RBuffer *buf, each_cb cb);
