#ifndef NVIM_LIVEUPDATE_H
#define NVIM_LIVEUPDATE_H

#include "nvim/buffer_defs.h"

bool liveupdate_register(buf_T *buf, uint64_t channel_id);
void liveupdate_unregister(buf_T *buf, uint64_t channel_id);
void liveupdate_unregister_all(buf_T *buf);
void liveupdate_send_changes(buf_T *buf, linenr_T firstline, int64_t num_added,
                             int64_t num_removed);
void liveupdate_send_tick(buf_T *buf);

#endif  // NVIM_LIVEUPDATE_H
