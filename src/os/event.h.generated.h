void event_process(void);
void event_push(Event event);
void event_init(void);
bool event_poll(int32_t ms);
bool event_is_pending(void);
