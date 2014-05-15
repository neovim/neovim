#include <string.h>

#include <uv.h>
#include <msgpack.h>

#include "nvim/lib/klist.h"
#include "nvim/os/channel.h"
#include "nvim/os/channel_defs.h"
#include "nvim/os/rstream.h"
#include "nvim/os/rstream_defs.h"
#include "nvim/os/wstream.h"
#include "nvim/os/wstream_defs.h"
#include "nvim/os/job.h"
#include "nvim/os/job_defs.h"
#include "nvim/os/msgpack_rpc.h"
#include "nvim/vim.h"
#include "nvim/memory.h"

typedef struct {
  ChannelProtocol protocol;
  bool is_job;
  union {
    struct {
      msgpack_unpacker *unpacker;
      msgpack_sbuffer *sbuffer;
    } msgpack;
  } proto;
  union {
    int job_id;
    struct {
      RStream *read;
      WStream *write;
    } streams;
  } data;
} Channel;

#define _destroy_channel(x)

KLIST_INIT(Channel, Channel *, _destroy_channel)

static klist_t(Channel) *channels = NULL;
static void on_job_stdout(RStream *rstream, void *data, bool eof);
static void on_job_stderr(RStream *rstream, void *data, bool eof);
static void parse_msgpack(RStream *rstream, void *data, bool eof);

void channel_init()
{
  channels = kl_init(Channel);
}

void channel_teardown()
{
  if (!channels) {
    return;
  }

  Channel *channel;

  while (kl_shift(Channel, channels, &channel) == 0) {

    switch (channel->protocol) {
      case kChannelProtocolMsgpack:
        msgpack_sbuffer_free(channel->proto.msgpack.sbuffer);
        msgpack_unpacker_free(channel->proto.msgpack.unpacker);
        break;
      default:
        abort();
    }

    if (channel->is_job) {
      job_stop(channel->data.job_id);
    } else {
      rstream_free(channel->data.streams.read);
      wstream_free(channel->data.streams.write);
    }
  }
}

void channel_from_job(char **argv, ChannelProtocol prot)
{
  Channel *channel = xmalloc(sizeof(Channel));
  rstream_cb rcb = NULL;

  switch (prot) {
    case kChannelProtocolMsgpack:
      rcb = on_job_stdout;
      channel->proto.msgpack.unpacker =
        msgpack_unpacker_new(MSGPACK_UNPACKER_INIT_BUFFER_SIZE);
      channel->proto.msgpack.sbuffer = msgpack_sbuffer_new();
      break;
    default:
      abort();
  }

  channel->protocol = prot;
  channel->is_job = true;
  channel->data.job_id = job_start(argv, channel, rcb, on_job_stderr, NULL);
  *kl_pushp(Channel, channels) = channel;
}

void channel_from_stream(uv_stream_t *stream, ChannelProtocol prot)
{
  Channel *channel = xmalloc(sizeof(Channel));
  rstream_cb rcb = NULL;

  switch (prot) {
    case kChannelProtocolMsgpack:
      rcb = parse_msgpack;
      channel->proto.msgpack.unpacker =
        msgpack_unpacker_new(MSGPACK_UNPACKER_INIT_BUFFER_SIZE);
      channel->proto.msgpack.sbuffer = msgpack_sbuffer_new();
      break;
    default:
      abort();
  }

  stream->data = NULL;
  channel->protocol = prot;
  channel->is_job = false;
  // read stream
  channel->data.streams.read = rstream_new(rcb, 1024, channel, true);
  rstream_set_stream(channel->data.streams.read, stream);
  rstream_start(channel->data.streams.read);
  // write stream
  channel->data.streams.write = wstream_new(1024 * 1024);
  wstream_set_stream(channel->data.streams.write, stream);
  // push to channel list
  *kl_pushp(Channel, channels) = channel;
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
  msgpack_unpacked unpacked;
  Channel *channel = data;
  uint32_t count = rstream_available(rstream);

  // Feed the unpacker with data
  msgpack_unpacker_reserve_buffer(channel->proto.msgpack.unpacker, count);
  rstream_read(rstream,
               msgpack_unpacker_buffer(channel->proto.msgpack.unpacker),
               count);
  msgpack_unpacker_buffer_consumed(channel->proto.msgpack.unpacker, count);

  msgpack_unpacked_init(&unpacked);

  // Deserialize everything we can. 
  while (msgpack_unpacker_next(channel->proto.msgpack.unpacker, &unpacked)) {
    // Each object is a new msgpack-rpc request and requires an empty response 
    msgpack_packer response;
    msgpack_packer_init(&response,
                        channel->proto.msgpack.sbuffer,
                        msgpack_sbuffer_write);
    // Perform the call
    msgpack_rpc_call(&unpacked.data, &response);
    wstream_write(channel->data.streams.write,
                  xmemdup(channel->proto.msgpack.sbuffer->data,
                          channel->proto.msgpack.sbuffer->size),
                  channel->proto.msgpack.sbuffer->size,
                  true);

    // Clear the buffer for future calls
    msgpack_sbuffer_clear(channel->proto.msgpack.sbuffer);
  }
}
