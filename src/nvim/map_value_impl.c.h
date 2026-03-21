#include "nvim/assert_defs.h"
#include "nvim/map_defs.h"

#if !defined(KEY_NAME) || !defined(VAL_NAME)
// Don't error out. it is nice to type-check the file in isolation, in clangd or otherwise
# define KEY_NAME(x) x##int
# define VAL_NAME(x) quasiquote(x, ptr_t)
#endif

#define after_underscore(x) quasiquote(x, _)
#define MAP_NAME(x) VAL_NAME(after_underscore(KEY_NAME(x)))
#define MAP_TYPE MAP_NAME(Map_)
#define KEY_TYPE KEY_NAME()
#define VALUE_TYPE VAL_NAME()
#define INITIALIZER VAL_NAME(value_init_)

VALUE_TYPE *MAP_NAME(map_ref_)(MAP_TYPE *map, KEY_TYPE key, KEY_TYPE **key_alloc)
{
  uint32_t k = KEY_NAME(mh_get_)(&map->set, key);
  if (k == MH_TOMBSTONE) {
    return NULL;
  }
  if (key_alloc) {
    *key_alloc = &map->set.keys[k];
  }
  return &map->values[k];
}

VALUE_TYPE *MAP_NAME(map_put_ref_)(MAP_TYPE *map, KEY_TYPE key, KEY_TYPE **key_alloc,
                                   bool *new_item)
{
  MHPutStatus status;
  uint32_t k = KEY_NAME(mh_put_)(&map->set, key, &status);
  if (status != kMHExisting) {
    if (status == kMHNewKeyRealloc) {
      map->values = xrealloc(map->values, map->set.h.keys_capacity * sizeof(VALUE_TYPE));
    }
    map->values[k] = INITIALIZER;
  }
  if (new_item) {
    *new_item = (status != kMHExisting);
  }
  if (key_alloc) {
    *key_alloc = &map->set.keys[k];
  }
  return &map->values[k];
}

VALUE_TYPE MAP_NAME(map_del_)(MAP_TYPE *map, KEY_TYPE key, KEY_TYPE *key_alloc)
{
  VALUE_TYPE rv = INITIALIZER;
  uint32_t k = KEY_NAME(mh_delete_)(&map->set, &key);
  if (k == MH_TOMBSTONE) {
    return rv;
  }

  if (key_alloc) {
    *key_alloc = key;
  }
  rv = map->values[k];
  if (k != map->set.h.n_keys) {
    map->values[k] = map->values[map->set.h.n_keys];
  }
  return rv;
}
