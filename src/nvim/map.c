#include <stdlib.h>
#include <stdbool.h>

#include "nvim/map.h"
#include "nvim/map_defs.h"
#include "nvim/vim.h"
#include "nvim/memory.h"

#include "nvim/lib/khash.h"

#define cstr_t_hash kh_str_hash_func
#define cstr_t_eq kh_str_hash_equal
#define uint64_t_hash kh_int64_hash_func
#define uint64_t_eq kh_int64_hash_equal
#define uint32_t_hash kh_int_hash_func
#define uint32_t_eq kh_int_hash_equal

#if defined(ARCH_64)
#define ptr_t_hash(key) uint64_t_hash((uint64_t)key)
#define ptr_t_eq(a, b) uint64_t_eq((uint64_t)a, (uint64_t)b)
#elif defined(ARCH_32)
#define ptr_t_hash(key) uint32_t_hash((uint32_t)key)
#define ptr_t_eq(a, b) uint32_t_eq((uint32_t)a, (uint32_t)b)
#endif


#define MAP_IMPL(T)                                                          \
  __KHASH_IMPL(T##_map,, T, void *, 1, T##_hash, T##_eq)                     \
                                                                             \
  Map(T) *map_##T##_new()                                                    \
  {                                                                          \
    Map(T) *rv = xmalloc(sizeof(Map(T)));                                    \
    rv->table = kh_init(T##_map);                                            \
    return rv;                                                               \
  }                                                                          \
                                                                             \
  void map_##T##_free(Map(T) *map)                                           \
  {                                                                          \
    kh_destroy(T##_map, map->table);                                         \
    free(map);                                                               \
  }                                                                          \
                                                                             \
  void *map_##T##_get(Map(T) *map, T key)                                    \
  {                                                                          \
    khiter_t k;                                                              \
                                                                             \
    if ((k = kh_get(T##_map, map->table, key)) == kh_end(map->table)) {      \
      return NULL;                                                           \
    }                                                                        \
                                                                             \
    return kh_val(map->table, k);                                            \
  }                                                                          \
                                                                             \
  bool map_##T##_has(Map(T) *map, T key)                                     \
  {                                                                          \
    return kh_get(T##_map, map->table, key) != kh_end(map->table);           \
  }                                                                          \
                                                                             \
  void *map_##T##_put(Map(T) *map, T key, void *value)                       \
  {                                                                          \
    int ret;                                                                 \
    void *rv = NULL;                                                         \
    khiter_t k = kh_put(T##_map, map->table, key, &ret);                     \
                                                                             \
    if (!ret) {                                                              \
      rv = kh_val(map->table, k);                                            \
    }                                                                        \
                                                                             \
    kh_val(map->table, k) = value;                                           \
    return rv;                                                               \
  }                                                                          \
                                                                             \
  void *map_##T##_del(Map(T) *map, T key)                                    \
  {                                                                          \
    void *rv = NULL;                                                         \
    khiter_t k;                                                              \
                                                                             \
    if ((k = kh_get(T##_map, map->table, key)) != kh_end(map->table)) {      \
      rv = kh_val(map->table, k);                                            \
      kh_del(T##_map, map->table, k);                                        \
    }                                                                        \
                                                                             \
    return rv;                                                               \
  }

MAP_IMPL(cstr_t)
MAP_IMPL(ptr_t)
