// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include "nvim/rbuffer.h"
#include "rbuffer.h"


void ut_rbuffer_each_read_chunk(RBuffer *buf, each_ptr_cb cb)
{
  RBUFFER_UNTIL_EMPTY(buf, rptr, rcnt) {
    cb(rptr, rcnt);
    rbuffer_consumed(buf, rcnt);
  }
}

void ut_rbuffer_each_write_chunk(RBuffer *buf, each_ptr_cb cb)
{
  RBUFFER_UNTIL_FULL(buf, wptr, wcnt) {
    cb(wptr, wcnt);
    rbuffer_produced(buf, wcnt);
  }
}
void ut_rbuffer_each(RBuffer *buf, each_cb cb)
{
  RBUFFER_EACH(buf, c, i) cb(c, i);
}

void ut_rbuffer_each_reverse(RBuffer *buf, each_cb cb)
{
  RBUFFER_EACH_REVERSE(buf, c, i) cb(c, i);
}
