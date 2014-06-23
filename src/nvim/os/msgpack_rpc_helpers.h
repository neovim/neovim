#ifndef NVIM_OS_MSGPACK_RPC_HELPERS_H
#define NVIM_OS_MSGPACK_RPC_HELPERS_H

#include <stdint.h>
#include <stdbool.h>

#include <msgpack.h>

#include "nvim/func_attr.h"
#include "nvim/api/private/defs.h"

/// Functions for validating and converting from msgpack types to C types.
/// These are used by `msgpack_rpc_dispatch` to validate and convert each
/// argument.
///
/// @param obj The object to convert
/// @param[out] arg A pointer to the avalue
/// @return true if the conversion succeeded, false otherwise
bool msgpack_rpc_to_boolean(msgpack_object *obj, Boolean *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_integer(msgpack_object *obj, Integer *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_float(msgpack_object *obj, Float *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_position(msgpack_object *obj, Position *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_string(msgpack_object *obj, String *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_buffer(msgpack_object *obj, Buffer *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_window(msgpack_object *obj, Window *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_tabpage(msgpack_object *obj, Tabpage *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_object(msgpack_object *obj, Object *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_stringarray(msgpack_object *obj, StringArray *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_bufferarray(msgpack_object *obj, BufferArray *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_windowarray(msgpack_object *obj, WindowArray *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_tabpagearray(msgpack_object *obj, TabpageArray *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_array(msgpack_object *obj, Array *arg)
  FUNC_ATTR_NONNULL_ALL;
bool msgpack_rpc_to_dictionary(msgpack_object *obj, Dictionary *arg)
  FUNC_ATTR_NONNULL_ALL;

/// Functions for converting from C types to msgpack types.
/// These are used by `msgpack_rpc_dispatch` to convert return values
/// from the API
///
/// @param result A pointer to the result
/// @param res A packer that contains the response
void msgpack_rpc_from_boolean(Boolean result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_integer(Integer result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_float(Float result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_position(Position result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_string(String result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_buffer(Buffer result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_window(Window result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_tabpage(Tabpage result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_object(Object result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_stringarray(StringArray result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_bufferarray(BufferArray result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_windowarray(WindowArray result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_tabpagearray(TabpageArray result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_array(Array result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);
void msgpack_rpc_from_dictionary(Dictionary result, msgpack_packer *res)
  FUNC_ATTR_NONNULL_ARG(2);

/// Helpers for initializing types that may be freed later
#define msgpack_rpc_init_boolean
#define msgpack_rpc_init_integer
#define msgpack_rpc_init_float
#define msgpack_rpc_init_position
#define msgpack_rpc_init_string = STRING_INIT
#define msgpack_rpc_init_buffer
#define msgpack_rpc_init_window
#define msgpack_rpc_init_tabpage
#define msgpack_rpc_init_object = {.type = kObjectTypeNil}
#define msgpack_rpc_init_stringarray = ARRAY_DICT_INIT
#define msgpack_rpc_init_bufferarray = ARRAY_DICT_INIT
#define msgpack_rpc_init_windowarray = ARRAY_DICT_INIT
#define msgpack_rpc_init_tabpagearray = ARRAY_DICT_INIT
#define msgpack_rpc_init_array = ARRAY_DICT_INIT
#define msgpack_rpc_init_dictionary = ARRAY_DICT_INIT

/// Helpers for freeing arguments/return value
///
/// @param value The value to be freed
#define msgpack_rpc_free_boolean(value)
#define msgpack_rpc_free_integer(value)
#define msgpack_rpc_free_float(value)
#define msgpack_rpc_free_position(value)
void msgpack_rpc_free_string(String value);
#define msgpack_rpc_free_buffer(value)
#define msgpack_rpc_free_window(value)
#define msgpack_rpc_free_tabpage(value)
void msgpack_rpc_free_object(Object value);
void msgpack_rpc_free_stringarray(StringArray value);
void msgpack_rpc_free_bufferarray(BufferArray value);
void msgpack_rpc_free_windowarray(WindowArray value);
void msgpack_rpc_free_tabpagearray(TabpageArray value);
void msgpack_rpc_free_array(Array value);
void msgpack_rpc_free_dictionary(Dictionary value);

#endif  // NVIM_OS_MSGPACK_RPC_HELPERS_H

