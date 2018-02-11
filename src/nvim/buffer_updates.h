#ifndef BUFFER_UPDATES_H
#define BUFFER_UPDATES_H

#include "nvim/buffer_defs.h"

bool buffer_updates_register(buf_T *buf, uint64_t channel_id, bool send_buffer);
void buffer_updates_unregister(buf_T *buf, uint64_t channel_id);
void buffer_updates_unregister_all(buf_T *buf);
void buffer_updates_send_changes(buf_T *buf, linenr_T firstline, int64_t num_added,
                             int64_t num_removed, bool send_tick);
void buffer_updates_send_tick(buf_T *buf);

#endif  // NVIM_BUFFER_UPDATES_H
