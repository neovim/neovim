// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

//
// map.c: khash.h wrapper
//
// NOTE: Callers must manage memory (allocate) for keys and values.
//       khash.h does not make its own copy of the key or value.
//

#include <lauxlib.h>
#include <lua.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "nvim/api/private/dispatch.h"
#include "nvim/lib/khash.h"
#include "nvim/map.h"
#include "nvim/map_defs.h"
#include "nvim/memory.h"
#include "nvim/vim.h"

#define cstr_t_hash kh_str_hash_func
#define cstr_t_eq kh_str_hash_equal
#define uint64_t_hash kh_int64_hash_func
#define uint64_t_eq kh_int64_hash_equal
#define uint32_t_hash kh_int_hash_func
#define uint32_t_eq kh_int_hash_equal
#define int_hash kh_int_hash_func
#define int_eq kh_int_hash_equal
#define handle_T_hash kh_int_hash_func
#define handle_T_eq kh_int_hash_equal
#define scid_T_hash kh_int_hash_func
#define scid_T_eq kh_int_hash_equal


#if defined(ARCH_64)
# define ptr_t_hash(key) uint64_t_hash((uint64_t)key)
# define ptr_t_eq(a, b) uint64_t_eq((uint64_t)a, (uint64_t)b)
#elif defined(ARCH_32)
# define ptr_t_hash(key) uint32_t_hash((uint32_t)key)
# define ptr_t_eq(a, b) uint32_t_eq((uint32_t)a, (uint32_t)b)
#endif

#define INITIALIZER(T, U) T##_##U##_initializer
#define INITIALIZER_DECLARE(T, U, ...) const U INITIALIZER(T, U) = __VA_ARGS__
#define DEFAULT_INITIALIZER { 0 }
#define SSIZE_INITIALIZER { -1 }

#define MAP_IMPL(T, U, ...) \
  INITIALIZER_DECLARE(T, U, __VA_ARGS__); \
  __KHASH_IMPL(T##_##U##_map, , T, U, 1, T##_hash, T##_eq) \
  void map_##T##_##U##_destroy(Map(T, U) *map) \
  { \
    kh_dealloc(T##_##U##_map, &map->table); \
  } \
  U map_##T##_##U##_get(Map(T, U) *map, T key) \
  { \
    khiter_t k; \
    if ((k = kh_get(T##_##U##_map, &map->table, key)) == kh_end(&map->table)) { \
      return INITIALIZER(T, U); \
    } \
    return kh_val(&map->table, k); \
  } \
  bool map_##T##_##U##_has(Map(T, U) *map, T key) \
  { \
    return kh_get(T##_##U##_map, &map->table, key) != kh_end(&map->table); \
  } \
  T map_##T##_##U##_key(Map(T, U) *map, T key) \
  { \
    khiter_t k; \
    if ((k = kh_get(T##_##U##_map, &map->table, key)) == kh_end(&map->table)) { \
      abort();  /* Caller must check map_has(). */ \
    } \
    return kh_key(&map->table, k); \
  } \
  U map_##T##_##U##_put(Map(T, U) *map, T key, U value) \
  { \
    int ret; \
    U rv = INITIALIZER(T, U); \
    khiter_t k = kh_put(T##_##U##_map, &map->table, key, &ret); \
    if (!ret) { \
      rv = kh_val(&map->table, k); \
    } \
    kh_val(&map->table, k) = value; \
    return rv; \
  } \
  U *map_##T##_##U##_ref(Map(T, U) *map, T key, bool put) \
  { \
    int ret; \
    khiter_t k; \
    if (put) { \
      k = kh_put(T##_##U##_map, &map->table, key, &ret); \
      if (ret) { \
        kh_val(&map->table, k) = INITIALIZER(T, U); \
      } \
    } else { \
      k = kh_get(T##_##U##_map, &map->table, key); \
      if (k == kh_end(&map->table)) { \
        return NULL; \
      } \
    } \
    return &kh_val(&map->table, k); \
  } \
  U map_##T##_##U##_del(Map(T, U) *map, T key) \
  { \
    U rv = INITIALIZER(T, U); \
    khiter_t k; \
    if ((k = kh_get(T##_##U##_map, &map->table, key)) != kh_end(&map->table)) { \
      rv = kh_val(&map->table, k); \
      kh_del(T##_##U##_map, &map->table, k); \
    } \
    return rv; \
  } \
  void map_##T##_##U##_clear(Map(T, U) *map) \
  { \
    kh_clear(T##_##U##_map, &map->table); \
  }

static inline khint_t String_hash(String s)
{
  khint_t h = 0;
  for (size_t i = 0; i < s.size && s.data[i]; i++) {
    h = (h << 5) - h + (uint8_t)s.data[i];
  }
  return h;
}

static inline bool String_eq(String a, String b)
{
  if (a.size != b.size) {
    return false;
  }
  return memcmp(a.data, b.data, a.size) == 0;
}

static inline khint_t HlEntry_hash(HlEntry ae)
{
  const uint8_t *data = (const uint8_t *)&ae;
  khint_t h = 0;
  for (size_t i = 0; i < sizeof(ae); i++) {
    h = (h << 5) - h + data[i];
  }
  return h;
}

static inline bool HlEntry_eq(HlEntry ae1, HlEntry ae2)
{
  return memcmp(&ae1, &ae2, sizeof(ae1)) == 0;
}

static inline khint_t ColorKey_hash(ColorKey ae)
{
  const uint8_t *data = (const uint8_t *)&ae;
  khint_t h = 0;
  for (size_t i = 0; i < sizeof(ae); i++) {
    h = (h << 5) - h + data[i];
  }
  return h;
}

static inline bool ColorKey_eq(ColorKey ae1, ColorKey ae2)
{
  return memcmp(&ae1, &ae2, sizeof(ae1)) == 0;
}


MAP_IMPL(int, int, DEFAULT_INITIALIZER)
MAP_IMPL(cstr_t, ptr_t, DEFAULT_INITIALIZER)
MAP_IMPL(cstr_t, int, DEFAULT_INITIALIZER)
MAP_IMPL(ptr_t, ptr_t, DEFAULT_INITIALIZER)
MAP_IMPL(uint64_t, ptr_t, DEFAULT_INITIALIZER)
MAP_IMPL(uint64_t, ssize_t, SSIZE_INITIALIZER)
MAP_IMPL(uint64_t, uint64_t, DEFAULT_INITIALIZER)
MAP_IMPL(uint32_t, uint32_t, DEFAULT_INITIALIZER)
MAP_IMPL(handle_T, ptr_t, DEFAULT_INITIALIZER)
MAP_IMPL(handle_T, scid_T, DEFAULT_INITIALIZER)
MAP_IMPL(scid_T, ptr_t, DEFAULT_INITIALIZER)
#define MSGPACK_HANDLER_INITIALIZER { .fn = NULL, .fast = false }
MAP_IMPL(String, MsgpackRpcRequestHandler, MSGPACK_HANDLER_INITIALIZER)
MAP_IMPL(HlEntry, int, DEFAULT_INITIALIZER)
MAP_IMPL(String, handle_T, 0)
MAP_IMPL(String, int, DEFAULT_INITIALIZER)
MAP_IMPL(int, String, DEFAULT_INITIALIZER)
MAP_IMPL(String, UIClientHandler, NULL)

MAP_IMPL(ColorKey, ColorItem, COLOR_ITEM_INITIALIZER)

/// Deletes a key:value pair from a string:pointer map, and frees the
/// storage of both key and value.
///
void pmap_del2(PMap(cstr_t) *map, const char *key)
{
  if (pmap_has(cstr_t)(map, key)) {
    void *k = (void *)pmap_key(cstr_t)(map, key);
    void *v = pmap_get(cstr_t)(map, key);
    pmap_del(cstr_t)(map, key);
    xfree(k);
    xfree(v);
  }
}
