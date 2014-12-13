#include "nvim/api/msgpack.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"

#ifdef MAKE_LIB

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/msgpack.c.generated.h"
#endif

void vim_array_add_buffer(Buffer val, Array *arr)
{
  Object o = OBJECT_INIT;
  o.type = kObjectTypeBuffer;
  o.data.buffer = val;
  ADD(*arr, o);
}

void vim_array_add_window(Window val, Array *arr)
{
  Object o = OBJECT_INIT;
  o.type = kObjectTypeWindow;
  o.data.window = val;
  ADD(*arr, o);
}

void vim_array_add_tabpage(Tabpage val, Array *arr)
{
  Object o = OBJECT_INIT;
  o.type = kObjectTypeTabpage;
  o.data.tabpage = val;
  ADD(*arr, o);
}

void vim_array_add_nil(Array *arr)
{
  Object o = OBJECT_INIT;
  o.type = kObjectTypeNil;
  ADD(*arr, o);
}

void vim_array_add_boolean(Boolean val, Array *arr)
{
  Object o = OBJECT_INIT;
  o.type = kObjectTypeBoolean;
  o.data.boolean = val;
  ADD(*arr, o);
}

void vim_array_add_integer(Integer val, Array *arr)
{
  Object o = OBJECT_INIT;
  o.type = kObjectTypeInteger;
  o.data.integer = val;
  ADD(*arr, o);
}

void vim_array_add_float(Float val, Array *arr)
{
  Object o = OBJECT_INIT;
  o.type = kObjectTypeFloat;
  o.data.floating = val;
  ADD(*arr, o);
}

void vim_array_add_string(String val, Array *arr)
{
  Object o = OBJECT_INIT;
  o.type = kObjectTypeString;
  o.data.string = val;
  ADD(*arr, o);
}

void vim_array_add_array(Array val, Array *arr)
{
  Object o = OBJECT_INIT;
  o.type = kObjectTypeArray;
  o.data.array = val;
  ADD(*arr, o);
}

void vim_array_add_dictionary(Dictionary val, Array *arr)
{
  Object o = OBJECT_INIT;
  o.type = kObjectTypeDictionary;
  o.data.dictionary = val;
  ADD(*arr, o);
}

msgpack_sbuffer *vim_msgpack_new(void)
{
  return msgpack_sbuffer_new();
}

void vim_msgpack_free(msgpack_sbuffer *buf)
{
  msgpack_sbuffer_free(buf);
}

void vim_msgpack_parse(String message, Array *arr)
{
  msgpack_unpacker *unpacker = msgpack_unpacker_new(message.size);
  msgpack_unpacker_reserve_buffer(unpacker, message.size);
  char *buf = msgpack_unpacker_buffer(unpacker);
  memcpy(buf, message.data, message.size);
  msgpack_unpacker_buffer_consumed(unpacker, message.size);

  msgpack_unpacked unpacked;
  msgpack_unpacked_init(&unpacked);
  msgpack_unpack_return result;

  if ((result = msgpack_unpacker_next(unpacker, &unpacked)) ==
      MSGPACK_UNPACK_SUCCESS)
  {
    msgpack_rpc_to_array(&unpacked.data, arr);
  }

  msgpack_unpacked_destroy(&unpacked);
  msgpack_unpacker_free(unpacker);
}

void vim_serialize_request(uint64_t request_id,
                           String method,
                           Array args,
                           msgpack_sbuffer *buf)
{
  msgpack_packer pac;
  msgpack_packer_init(&pac, buf, msgpack_sbuffer_write);
  msgpack_rpc_serialize_request(request_id, method, args, &pac);
}

#endif  // MAKE_LIB
