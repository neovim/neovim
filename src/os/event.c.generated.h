static void timer_prepare_cb(uv_prepare_t *);
static void timer_cb(uv_timer_t *handle);
KLIST_INIT(Event, Event, _destroy_event)
