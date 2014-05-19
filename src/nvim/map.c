#include <stdlib.h>
#include <stdbool.h>

#include "nvim/map.h"
#include "nvim/map_defs.h"
#include "nvim/vim.h"
#include "nvim/memory.h"

#include "nvim/lib/khash.h"

__KHASH_IMPL(Map,, kh_cstr_t, void *, 1, kh_str_hash_func, kh_str_hash_equal)

Map *map_new()
{
  Map *rv = xmalloc(sizeof(Map));
  rv->table = kh_init(Map);
  return rv;
}

void map_free(Map *map)
{
  kh_clear(Map, map->table);
  kh_destroy(Map, map->table);
  free(map);
}

void *map_get(Map *map, const char *key)
{
  khiter_t k;

  if ((k = kh_get(Map, map->table, key)) == kh_end(map->table)) {
    return NULL;
  }

  return kh_val(map->table, k);
}

bool map_has(Map *map, const char *key)
{
  return kh_get(Map, map->table, key) != kh_end(map->table);
}

void *map_put(Map *map, const char *key, void *value)
{
  int ret;
  void *rv = NULL;
  khiter_t k = kh_put(Map, map->table, key, &ret);

  if (!ret) {
    // key present, return the current value
    rv = kh_val(map->table, k);
    kh_del(Map, map->table, k);
  }

  kh_val(map->table, k) = value;

  return rv;
}

void *map_del(Map *map, const char *key)
{
  void *rv = NULL;
  khiter_t k;

  if ((k = kh_get(Map, map->table, key)) != kh_end(map->table)) {
    rv = kh_val(map->table, k);
    kh_del(Map, map->table, k);
  }

  return rv;
}

