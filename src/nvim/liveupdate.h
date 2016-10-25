#include "nvim/buffer_defs.h"

bool liveupdate_register(buf_T *buf, uint64_t channel_id);
void liveupdate_unregister(buf_T *buf, uint64_t channel_id);
void liveupdate_unregister_all(buf_T *buf);
