#ifndef NVIM_MAP_H
#define NVIM_MAP_H

#include <stdbool.h>

#include "nvim/map_defs.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/bufhl_defs.h"
#include "nvim/highlight_defs.h"

#if defined(__NetBSD__)
# undef uint64_t
# define uint64_t uint64_t
#endif

#define MAP_DECLS(T, U) \
  KHASH_DECLARE(T##_##U##_map, T, U) \
  \
  typedef struct { \
    khash_t(T##_##U##_map) *table; \
  } Map(T, U); \
  \
  Map(T, U) *map_##T##_##U##_new(void); \
  void map_##T##_##U##_free(Map(T, U) *map); \
  U map_##T##_##U##_get(Map(T, U) *map, T key); \
  bool map_##T##_##U##_has(Map(T, U) *map, T key); \
  T map_##T##_##U##_key(Map(T, U) *map, T key); \
  U map_##T##_##U##_put(Map(T, U) *map, T key, U value); \
  U *map_##T##_##U##_ref(Map(T, U) *map, T key, bool put); \
  U map_##T##_##U##_del(Map(T, U) *map, T key); \
  void map_##T##_##U##_clear(Map(T, U) *map);

//
// NOTE: Keys AND values must be allocated! khash.h does not make a copy.
//
MAP_DECLS(int, int)
MAP_DECLS(cstr_t, ptr_t)
MAP_DECLS(ptr_t, ptr_t)
MAP_DECLS(uint64_t, ptr_t)
MAP_DECLS(handle_T, ptr_t)
MAP_DECLS(String, MsgpackRpcRequestHandler)
MAP_DECLS(HlEntry, int)
MAP_DECLS(String, handle_T)

#define map_new(T, U) map_##T##_##U##_new
#define map_free(T, U) map_##T##_##U##_free
#define map_get(T, U) map_##T##_##U##_get
#define map_has(T, U) map_##T##_##U##_has
#define map_key(T, U) map_##T##_##U##_key
#define map_put(T, U) map_##T##_##U##_put
#define map_ref(T, U) map_##T##_##U##_ref
#define map_del(T, U) map_##T##_##U##_del
#define map_clear(T, U) map_##T##_##U##_clear

#define pmap_new(T) map_new(T, ptr_t)
#define pmap_free(T) map_free(T, ptr_t)
#define pmap_get(T) map_get(T, ptr_t)
#define pmap_has(T) map_has(T, ptr_t)
#define pmap_key(T) map_key(T, ptr_t)
#define pmap_put(T) map_put(T, ptr_t)
/// @see pmap_del2
#define pmap_del(T) map_del(T, ptr_t)
#define pmap_clear(T) map_clear(T, ptr_t)

#define map_foreach(map, key, value, block) \
  kh_foreach(map->table, key, value, block)

#define map_foreach_value(map, value, block) \
  kh_foreach_value(map->table, value, block)

void pmap_del2(PMap(cstr_t) *map, const char *key);

#endif  // NVIM_MAP_H
