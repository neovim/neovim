static int push_event_key(uint8_t *buf, int maxlen);
static void stderr_switch(void);
static InbufPollResult inbuf_poll(int32_t ms);
static void read_cb(RStream *rstream, void *data, bool eof);
