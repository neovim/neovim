// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

//
// map.c: khash.h wrapper
//
// NOTE: Callers must manage memory (allocate) for keys and values.
//       khash.h does not make its own copy of the key or value.
//

#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include "auto/config.h"
#include "klib/khash.h"
#include "nvim/gettext.h"
#include "nvim/map.h"
#include "nvim/memory.h"

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

#if defined(ARCH_64)
# define ptr_t_hash(key) uint64_t_hash((uint64_t)(key))
# define ptr_t_eq(a, b) uint64_t_eq((uint64_t)(a), (uint64_t)(b))
#elif defined(ARCH_32)
# define ptr_t_hash(key) uint32_t_hash((uint32_t)(key))
# define ptr_t_eq(a, b) uint32_t_eq((uint32_t)(a), (uint32_t)(b))
#endif

#define INITIALIZER(T, U) T##_##U##_initializer
#define INITIALIZER_DECLARE(T, U, ...) const U INITIALIZER(T, U) = __VA_ARGS__
#define DEFAULT_INITIALIZER { 0 }
#define SSIZE_INITIALIZER { -1 }

#define KEY_IMPL(T) \
  __KHASH_IMPL(T, , T, T##_hash, T##_eq) \

#define MAP_IMPL(T, U, ...) \
  INITIALIZER_DECLARE(T, U, __VA_ARGS__); \
  U map_##T##_##U##_get(Map(T, U) *map, T key) \
  { \
    khiter_t k; \
    if ((k = kh_get(T, &map->table, key)) == kh_end(&map->table)) { \
      return INITIALIZER(T, U); \
    } \
    return kh_val(U, &map->table, k); \
  } \
  U map_##T##_##U##_put(Map(T, U) *map, T key, U value) \
  { \
    STATIC_ASSERT(sizeof(U) <= KHASH_MAX_VAL_SIZE, "increase KHASH_MAX_VAL_SIZE"); \
    int ret; \
    U rv = INITIALIZER(T, U); \
    khiter_t k = kh_put(T, &map->table, key, &ret, sizeof(U)); \
    if (!ret) { \
      rv = kh_val(U, &map->table, k); \
    } \
    kh_val(U, &map->table, k) = value; \
    return rv; \
  } \
  U *map_##T##_##U##_ref(Map(T, U) *map, T key, T **key_alloc) \
  { \
    khiter_t k = kh_get(T, &map->table, key); \
    if (k == kh_end(&map->table)) { \
      return NULL; \
    } \
    if (key_alloc) { \
      *key_alloc = &kh_key(&map->table, k); \
    } \
    return &kh_val(U, &map->table, k); \
  } \
  U *map_##T##_##U##_put_ref(Map(T, U) *map, T key, T **key_alloc, bool *new_item) \
  { \
    int ret; \
    khiter_t k = kh_put(T, &map->table, key, &ret, sizeof(U)); \
    if (ret) { \
      kh_val(U, &map->table, k) = INITIALIZER(T, U); \
    } \
    if (new_item) { \
      *new_item = (bool)ret; \
    } \
    if (key_alloc) { \
      *key_alloc = &kh_key(&map->table, k); \
    } \
    return &kh_val(U, &map->table, k); \
  } \
  U map_##T##_##U##_del(Map(T, U) *map, T key, T *key_alloc) \
  { \
    U rv = INITIALIZER(T, U); \
    khiter_t k; \
    if ((k = kh_get(T, &map->table, key)) != kh_end(&map->table)) { \
      rv = kh_val(U, &map->table, k); \
      if (key_alloc) { \
        *key_alloc = kh_key(&map->table, k); \
      } \
      kh_del(T, &map->table, k); \
    } \
    return rv; \
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

KEY_IMPL(int)
KEY_IMPL(cstr_t)
KEY_IMPL(ptr_t)
KEY_IMPL(uint64_t)
KEY_IMPL(uint32_t)
KEY_IMPL(String)
KEY_IMPL(HlEntry)
KEY_IMPL(ColorKey)

MAP_IMPL(int, int, DEFAULT_INITIALIZER)
MAP_IMPL(int, ptr_t, DEFAULT_INITIALIZER)
MAP_IMPL(int, cstr_t, DEFAULT_INITIALIZER)
MAP_IMPL(cstr_t, ptr_t, DEFAULT_INITIALIZER)
MAP_IMPL(cstr_t, int, DEFAULT_INITIALIZER)
MAP_IMPL(ptr_t, ptr_t, DEFAULT_INITIALIZER)
MAP_IMPL(uint32_t, ptr_t, DEFAULT_INITIALIZER)
MAP_IMPL(uint64_t, ptr_t, DEFAULT_INITIALIZER)
MAP_IMPL(uint64_t, ssize_t, SSIZE_INITIALIZER)
MAP_IMPL(uint64_t, uint64_t, DEFAULT_INITIALIZER)
MAP_IMPL(uint32_t, uint32_t, DEFAULT_INITIALIZER)
MAP_IMPL(HlEntry, int, DEFAULT_INITIALIZER)
MAP_IMPL(String, handle_T, 0)
MAP_IMPL(String, int, DEFAULT_INITIALIZER)
MAP_IMPL(int, String, DEFAULT_INITIALIZER)
MAP_IMPL(ColorKey, ColorItem, COLOR_ITEM_INITIALIZER)

/// Deletes a key:value pair from a string:pointer map, and frees the
/// storage of both key and value.
///
void pmap_del2(PMap(cstr_t) *map, const char *key)
{
  cstr_t key_alloc = NULL;
  ptr_t val = pmap_del(cstr_t)(map, key, &key_alloc);
  xfree((void *)key_alloc);
  xfree(val);
}
