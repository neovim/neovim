#ifndef NVIM_MAP_H
#define NVIM_MAP_H

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

#include "klib/khash.h"
#include "nvim/api/private/defs.h"
#include "nvim/assert.h"
#include "nvim/highlight_defs.h"
#include "nvim/types.h"

#if defined(__NetBSD__)
# undef uint64_t
# define uint64_t uint64_t
#endif

typedef const char *cstr_t;
typedef void *ptr_t;

#define Map(T, U) Map_##T##_##U
#define PMap(T) Map(T, ptr_t)

#define KEY_DECLS(T) \
  KHASH_DECLARE(T) \
  static inline bool set_put_##T(Set(T) *set, T key, T **key_alloc) { \
    int kh_ret; \
    khiter_t k = kh_put(T, set, key, &kh_ret, 0); \
    if (key_alloc) { \
      *key_alloc = &kh_key(set, k); \
    } \
    return kh_ret; \
  } \
  static inline void set_del_##T(Set(T) *set, T key) \
  { \
    khiter_t k; \
    if ((k = kh_get(T, set, key)) != kh_end(set)) { \
      kh_del(T, set, k); \
    } \
  } \
  static inline bool set_has_##T(Set(T) *set, T key) { \
    return (kh_get(T, set, key) != kh_end(set)); \
  } \

#define MAP_DECLS(T, U) \
  typedef struct { \
    khash_t(T) table; \
  } Map(T, U); \
  U map_##T##_##U##_get(Map(T, U) *map, T key); \
  static inline bool map_##T##_##U##_has(Map(T, U) *map, T key) \
  { \
    return kh_get(T, &map->table, key) != kh_end(&map->table); \
  } \
  U map_##T##_##U##_put(Map(T, U) *map, T key, U value); \
  U *map_##T##_##U##_ref(Map(T, U) *map, T key, T **key_alloc); \
  U *map_##T##_##U##_put_ref(Map(T, U) *map, T key, T **key_alloc, bool *new_item); \
  U map_##T##_##U##_del(Map(T, U) *map, T key, T *key_alloc); \

// NOTE: Keys AND values must be allocated! khash.h does not make a copy.

#define Set(type) khash_t(type)

KEY_DECLS(int)
KEY_DECLS(cstr_t)
KEY_DECLS(ptr_t)
KEY_DECLS(uint64_t)
KEY_DECLS(uint32_t)
KEY_DECLS(String)
KEY_DECLS(HlEntry)
KEY_DECLS(ColorKey)

MAP_DECLS(int, int)
MAP_DECLS(int, ptr_t)
MAP_DECLS(int, cstr_t)
MAP_DECLS(cstr_t, ptr_t)
MAP_DECLS(cstr_t, int)
MAP_DECLS(ptr_t, ptr_t)
MAP_DECLS(uint32_t, ptr_t)
MAP_DECLS(uint64_t, ptr_t)
MAP_DECLS(uint64_t, ssize_t)
MAP_DECLS(uint64_t, uint64_t)
MAP_DECLS(uint32_t, uint32_t)
MAP_DECLS(HlEntry, int)
MAP_DECLS(String, handle_T)
MAP_DECLS(String, int)
MAP_DECLS(int, String)
MAP_DECLS(ColorKey, ColorItem)

#define SET_INIT { 0, 0, 0, 0, NULL, NULL, NULL }
#define MAP_INIT { SET_INIT }

#define map_get(T, U) map_##T##_##U##_get
#define map_has(T, U) map_##T##_##U##_has
#define map_put(T, U) map_##T##_##U##_put
#define map_ref(T, U) map_##T##_##U##_ref
#define map_put_ref(T, U) map_##T##_##U##_put_ref
#define map_del(T, U) map_##T##_##U##_del
#define map_destroy(T, map) kh_dealloc(T, &(map)->table)
#define map_clear(T, map) kh_clear(T, &(map)->table)

#define map_size(map) ((map)->table.size)

#define pmap_get(T) map_get(T, ptr_t)
#define pmap_has(T) map_has(T, ptr_t)
#define pmap_put(T) map_put(T, ptr_t)
#define pmap_ref(T) map_ref(T, ptr_t)
#define pmap_put_ref(T) map_put_ref(T, ptr_t)
/// @see pmap_del2
#define pmap_del(T) map_del(T, ptr_t)

#define map_foreach(U, map, key, value, block) kh_foreach(U, &(map)->table, key, value, block)

#define map_foreach_value(U, map, value, block) kh_foreach_value(U, &(map)->table, value, block)
#define map_foreach_key(map, key, block) kh_foreach_key(&(map)->table, key, block)
#define set_foreach(set, key, block) kh_foreach_key(set, key, block)

#define pmap_foreach_value(map, value, block) map_foreach_value(ptr_t, map, value, block)
#define pmap_foreach(map, key, value, block) map_foreach(ptr_t, map, key, value, block)

void pmap_del2(PMap(cstr_t) *map, const char *key);

#define set_has(T, set, key) set_has_##T(set, key)
#define set_put(T, set, key) set_put_##T(set, key, NULL)
#define set_put_ref(T, set, key, key_alloc) set_put_##T(set, key, key_alloc)
#define set_del(T, set, key) set_del_##T(set, key)
#define set_destroy(T, set) kh_dealloc(T, set)
#define set_clear(T, set) kh_clear(T, set)

#endif  // NVIM_MAP_H
