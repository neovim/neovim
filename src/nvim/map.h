#ifndef NVIM_MAP_H
#define NVIM_MAP_H

#include <stdbool.h>

#include "nvim/map_defs.h"

#define MAP_DECLS(T)                                                          \
  KHASH_DECLARE(T##_map, T, void *)                                           \
                                                                              \
  typedef struct {                                                            \
    khash_t(T##_map) *table;                                                  \
  } Map(T);                                                                   \
                                                                              \
  Map(T) *map_##T##_new(void);                                                \
  void map_##T##_free(Map(T) *map);                                           \
  void *map_##T##_get(Map(T) *map, T key);                                    \
  bool map_##T##_has(Map(T) *map, T key);                                     \
  void* map_##T##_put(Map(T) *map, T key, void *value);                       \
  void* map_##T##_del(Map(T) *map, T key);

MAP_DECLS(cstr_t)
MAP_DECLS(ptr_t)

#define map_new(T) map_##T##_new
#define map_free(T) map_##T##_free
#define map_get(T) map_##T##_get
#define map_has(T) map_##T##_has
#define map_put(T) map_##T##_put
#define map_del(T) map_##T##_del

#define map_foreach(map, key, value, block) \
  kh_foreach(map->table, key, value, block)

#define map_foreach_value(map, value, block) \
  kh_foreach_value(map->table, value, block)

#endif  // NVIM_MAP_H

