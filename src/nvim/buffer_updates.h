#ifndef NVIM_BUFFER_UPDATES_H
#define NVIM_BUFFER_UPDATES_H

#include "nvim/buffer_defs.h"

bool buf_updates_register(buf_T *buf, uint64_t channel_id, bool send_buffer);
void buf_updates_unregister(buf_T *buf, uint64_t channel_id);
void buf_updates_unregister_all(buf_T *buf);
void buf_updates_send_changes(buf_T *buf,
                              linenr_T firstline,
                              int64_t num_added,
                              int64_t num_removed,
                              bool send_tick);
void buf_updates_changedtick(buf_T *buf);

#endif  // NVIM_BUFFER_UPDATES_H
