#include <string.h>

#include <uv.h>
#include <msgpack.h>

#include "nvim/api/private/helpers.h"
#include "nvim/os/channel.h"
#include "nvim/os/rstream.h"
#include "nvim/os/rstream_defs.h"
#include "nvim/os/wstream.h"
#include "nvim/os/wstream_defs.h"
#include "nvim/os/job.h"
#include "nvim/os/job_defs.h"
#include "nvim/os/msgpack_rpc.h"
#include "nvim/vim.h"
#include "nvim/memory.h"
#include "nvim/map.h"

typedef struct {
  uint64_t id;
  bool is_job;
  msgpack_unpacker *unpacker;
  msgpack_sbuffer *sbuffer;
  union {
    int job_id;
    struct {
      RStream *read;
      WStream *write;
      uv_stream_t *uv;
    } streams;
  } data;
} Channel;

static uint64_t next_id = 1;
static Map(uint64_t) *channels = NULL;
static msgpack_sbuffer msgpack_event_buffer;

static void on_job_stdout(RStream *rstream, void *data, bool eof);
static void on_job_stderr(RStream *rstream, void *data, bool eof);
static void parse_msgpack(RStream *rstream, void *data, bool eof);
static void close_channel(Channel *channel);
static void close_cb(uv_handle_t *handle);

void channel_init()
{
  channels = map_new(uint64_t)();
  msgpack_sbuffer_init(&msgpack_event_buffer);
}

void channel_teardown()
{
  if (!channels) {
    return;
  }

  Channel *channel;

  map_foreach_value(channels, channel, {
    close_channel(channel);
  });
}

void channel_from_job(char **argv)
{
  Channel *channel = xmalloc(sizeof(Channel));
  rstream_cb rcb = on_job_stdout;
  channel->unpacker = msgpack_unpacker_new(MSGPACK_UNPACKER_INIT_BUFFER_SIZE);
  channel->sbuffer = msgpack_sbuffer_new();

  channel->id = next_id++;
  channel->is_job = true;
  channel->data.job_id = job_start(argv, channel, rcb, on_job_stderr, NULL);
  map_put(uint64_t)(channels, channel->id, channel);
}

void channel_from_stream(uv_stream_t *stream)
{
  Channel *channel = xmalloc(sizeof(Channel));
  rstream_cb rcb = parse_msgpack;
  channel->unpacker = msgpack_unpacker_new(MSGPACK_UNPACKER_INIT_BUFFER_SIZE);
  channel->sbuffer = msgpack_sbuffer_new();

  stream->data = NULL;
  channel->id = next_id++;
  channel->is_job = false;
  // read stream
  channel->data.streams.read = rstream_new(rcb, 1024, channel, true);
  rstream_set_stream(channel->data.streams.read, stream);
  rstream_start(channel->data.streams.read);
  // write stream
  channel->data.streams.write = wstream_new(1024 * 1024);
  wstream_set_stream(channel->data.streams.write, stream);
  channel->data.streams.uv = stream;
  map_put(uint64_t)(channels, channel->id, channel);
}

bool channel_send_event(uint64_t id, char *type, typval_T *data)
{
  Channel *channel = map_get(uint64_t)(channels, id);

  if (!channel) {
    return false;
  }

  String event_type = {.size = strnlen(type, 1024), .data = type};
  Object event_data = vim_to_object(data);
  msgpack_packer packer;
  msgpack_packer_init(&packer, &msgpack_event_buffer, msgpack_sbuffer_write);
  msgpack_rpc_notification(event_type, event_data, &packer);
  char *bytes = xmemdup(msgpack_event_buffer.data, msgpack_event_buffer.size);

  wstream_write(channel->data.streams.write,
                bytes,
                msgpack_event_buffer.size,
                true);

  msgpack_rpc_free_object(event_data);
  msgpack_sbuffer_clear(&msgpack_event_buffer);

  return true;
}

static void on_job_stdout(RStream *rstream, void *data, bool eof)
{
  Job *job = data;
  parse_msgpack(rstream, job_data(job), eof);
}

static void on_job_stderr(RStream *rstream, void *data, bool eof)
{
  // TODO(tarruda): plugin error messages should be sent to the error buffer
}

static void parse_msgpack(RStream *rstream, void *data, bool eof)
{
  Channel *channel = data;

  if (eof) {
    close_channel(channel);
    return;
  }

  uint32_t count = rstream_available(rstream);

  // Feed the unpacker with data
  msgpack_unpacker_reserve_buffer(channel->unpacker, count);
  rstream_read(rstream, msgpack_unpacker_buffer(channel->unpacker), count);
  msgpack_unpacker_buffer_consumed(channel->unpacker, count);

  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);

  // Deserialize everything we can.
  while (msgpack_unpacker_next(channel->unpacker, &unpacked)) {
    // Each object is a new msgpack-rpc request and requires an empty response
    msgpack_packer response;
    msgpack_packer_init(&response, channel->sbuffer, msgpack_sbuffer_write);
    // Perform the call
    msgpack_rpc_call(channel->id, &unpacked.data, &response);
    wstream_write(channel->data.streams.write,
                  xmemdup(channel->sbuffer->data, channel->sbuffer->size),
                  channel->sbuffer->size,
                  true);

    // Clear the buffer for future calls
    msgpack_sbuffer_clear(channel->sbuffer);
  }
}

static void close_channel(Channel *channel)
{
  map_del(uint64_t)(channels, channel->id);
  msgpack_sbuffer_free(channel->sbuffer);
  msgpack_unpacker_free(channel->unpacker);

  if (channel->is_job) {
    job_stop(channel->data.job_id);
  } else {
    rstream_free(channel->data.streams.read);
    wstream_free(channel->data.streams.write);
    uv_close((uv_handle_t *)channel->data.streams.uv, close_cb);
  }

  free(channel);
}

static void close_cb(uv_handle_t *handle)
{
  free(handle->data);
  free(handle);
}

