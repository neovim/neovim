#ifndef NVIM_MAP_H
#define NVIM_MAP_H

#include <stdbool.h>

#include "nvim/map_defs.h"

#define MAP_DECLS(T, U)                                                       \
  KHASH_DECLARE(T##_##U##_map, T, U)                                          \
                                                                              \
  typedef struct {                                                            \
    khash_t(T##_##U##_map) *table;                                            \
  } Map(T, U);                                                                \
                                                                              \
  Map(T, U) *map_##T##_##U##_new(void);                                       \
  void map_##T##_##U##_free(Map(T, U) *map);                                  \
  U map_##T##_##U##_get(Map(T, U) *map, T key);                               \
  bool map_##T##_##U##_has(Map(T, U) *map, T key);                            \
  U map_##T##_##U##_put(Map(T, U) *map, T key, U value);                      \
  U map_##T##_##U##_del(Map(T, U) *map, T key);

MAP_DECLS(cstr_t, uint64_t)
MAP_DECLS(cstr_t, ptr_t)
MAP_DECLS(ptr_t, ptr_t)
MAP_DECLS(uint64_t, ptr_t)

#define map_new(T, U) map_##T##_##U##_new
#define map_free(T, U) map_##T##_##U##_free
#define map_get(T, U) map_##T##_##U##_get
#define map_has(T, U) map_##T##_##U##_has
#define map_put(T, U) map_##T##_##U##_put
#define map_del(T, U) map_##T##_##U##_del

#define pmap_new(T) map_new(T, ptr_t)
#define pmap_free(T) map_free(T, ptr_t)
#define pmap_get(T) map_get(T, ptr_t)
#define pmap_has(T) map_has(T, ptr_t)
#define pmap_put(T) map_put(T, ptr_t)
#define pmap_del(T) map_del(T, ptr_t)

#define map_foreach(map, key, value, block) \
  kh_foreach(map->table, key, value, block)

#define map_foreach_value(map, value, block) \
  kh_foreach_value(map->table, value, block)

#endif  // NVIM_MAP_H
