#pragma once

#include <inttypes.h>
#include <stdbool.h>
#include <string.h>

#include "klib/kvec.h"
#include "mpack/mpack_core.h"
#include "mpack/object.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/grid_defs.h"
#include "nvim/memory_defs.h"
#include "nvim/msgpack_rpc/channel_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"
#include "nvim/ui_defs.h"

struct Unpacker {
  mpack_parser_t parser;
  mpack_tokbuf_t reader;

  const char *read_ptr;
  size_t read_size;

#define MAX_EXT_LEN 9  // byte + 8-byte integer
  char ext_buf[MAX_EXT_LEN];

  int state;
  MessageType type;
  uint32_t request_id;
  size_t method_name_len;
  MsgpackRpcRequestHandler handler;
  Object error;  // error return
  Object result;  // arg list or result
  Error unpack_error;

  Arena arena;

  int nevents;
  int ncalls;
  UIClientHandler ui_handler;
  GridLineEvent grid_line_event;
  bool has_grid_line_event;
};

typedef kvec_t(char) AdditionalDataBuilder;

// unrecovareble error. unpack_error should be set!
#define unpacker_closed(p) ((p)->state < 0)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "msgpack_rpc/unpacker.h.generated.h"
#endif
