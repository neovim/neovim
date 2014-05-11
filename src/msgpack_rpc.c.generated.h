#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
static inline void *msgpack_zone_malloc(msgpack_zone *zone, size_t size);
static inline void msgpack_zone_swap(msgpack_zone *a, msgpack_zone *b);
static inline _Bool msgpack_unpacker_reserve_buffer(msgpack_unpacker *mpac, size_t size);
static inline char *msgpack_unpacker_buffer(msgpack_unpacker *mpac);
static inline size_t msgpack_unpacker_buffer_capacity(const msgpack_unpacker *mpac);
static inline void msgpack_unpacker_buffer_consumed(msgpack_unpacker *mpac, size_t size);
static inline size_t msgpack_unpacker_message_size(const msgpack_unpacker *mpac);
static inline size_t msgpack_unpacker_parsed_size(const msgpack_unpacker *mpac);
static inline void msgpack_unpacked_init(msgpack_unpacked *result);
static inline void msgpack_unpacked_destroy(msgpack_unpacked *result);
static inline msgpack_zone *msgpack_unpacked_release_zone(msgpack_unpacked *result);
static inline void msgpack_sbuffer_init(msgpack_sbuffer *sbuf);
static inline void msgpack_sbuffer_destroy(msgpack_sbuffer *sbuf);
static inline msgpack_sbuffer *msgpack_sbuffer_new(void);
static inline void msgpack_sbuffer_free(msgpack_sbuffer *sbuf);
static inline int msgpack_sbuffer_write(void *data, const char *buf, unsigned int len);
static inline char *msgpack_sbuffer_release(msgpack_sbuffer *sbuf);
static inline void msgpack_sbuffer_clear(msgpack_sbuffer *sbuf);
static inline msgpack_vrefbuffer *msgpack_vrefbuffer_new(size_t ref_size, size_t chunk_size);
static inline void msgpack_vrefbuffer_free(msgpack_vrefbuffer *vbuf);
static inline int msgpack_vrefbuffer_write(void *data, const char *buf, size_t len);
static inline const struct iovec *msgpack_vrefbuffer_vec(const msgpack_vrefbuffer *vref);
static inline size_t msgpack_vrefbuffer_veclen(const msgpack_vrefbuffer *vref);
#include "func_attr.h"
