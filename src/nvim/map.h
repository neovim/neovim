#ifndef NVIM_MAP_H
#define NVIM_MAP_H

#include <stdbool.h>

#include "nvim/map_defs.h"
#include "nvim/extmark_defs.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/highlight_defs.h"

#if defined(__NetBSD__)
# undef uint64_t
# define uint64_t uint64_t
#endif

#define MAP_DECLS(T, U) \
  KHASH_DECLARE(T##_##U##_map, T, U) \
  \
  typedef struct { \
    khash_t(T##_##U##_map) table; \
  } Map(T, U); \
  \
  Map(T, U) *map_##T##_##U##_new(void); \
  void map_##T##_##U##_free(Map(T, U) *map); \
  void map_##T##_##U##_destroy(Map(T, U) *map); \
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
MAP_DECLS(cstr_t, int)
MAP_DECLS(ptr_t, ptr_t)
MAP_DECLS(uint64_t, ptr_t)
MAP_DECLS(uint64_t, ssize_t)
MAP_DECLS(uint64_t, uint64_t)

// NB: this is the only way to define a struct both containing and contained
// in a map...
typedef struct ExtmarkNs {  // For namespacing extmarks
  Map(uint64_t, uint64_t) map[1];  // For fast lookup
  uint64_t free_id;         // For automatically assigning id's
} ExtmarkNs;

MAP_DECLS(uint64_t, ExtmarkNs)
MAP_DECLS(uint64_t, ExtmarkItem)
MAP_DECLS(handle_T, ptr_t)
MAP_DECLS(String, MsgpackRpcRequestHandler)
MAP_DECLS(HlEntry, int)
MAP_DECLS(String, handle_T)

MAP_DECLS(ColorKey, ColorItem)

#define MAP_INIT { { 0, 0, 0, 0, NULL, NULL, NULL } }
#define map_init(k, v, map) do { *(map) = (Map(k, v))MAP_INIT; } while (false)

#define map_destroy(T, U) map_##T##_##U##_destroy
#define map_get(T, U) map_##T##_##U##_get
#define map_has(T, U) map_##T##_##U##_has
#define map_key(T, U) map_##T##_##U##_key
#define map_put(T, U) map_##T##_##U##_put
#define map_ref(T, U) map_##T##_##U##_ref
#define map_del(T, U) map_##T##_##U##_del
#define map_clear(T, U) map_##T##_##U##_clear

#define map_size(map) ((map)->table.size)

#define pmap_destroy(T) map_destroy(T, ptr_t)
#define pmap_get(T) map_get(T, ptr_t)
#define pmap_has(T) map_has(T, ptr_t)
#define pmap_key(T) map_key(T, ptr_t)
#define pmap_put(T) map_put(T, ptr_t)
#define pmap_ref(T) map_ref(T, ptr_t)
/// @see pmap_del2
#define pmap_del(T) map_del(T, ptr_t)
#define pmap_clear(T) map_clear(T, ptr_t)
#define pmap_init(k, map) map_init(k, ptr_t, map)

#define map_foreach(map, key, value, block) \
  kh_foreach(&(map)->table, key, value, block)

#define map_foreach_value(map, value, block) \
  kh_foreach_value(&(map)->table, value, block)

void pmap_del2(PMap(cstr_t) *map, const char *key);

#endif  // NVIM_MAP_H
