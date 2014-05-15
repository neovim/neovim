#ifndef NVIM_MAP_DEFS_H
#define NVIM_MAP_DEFS_H

typedef struct map Map;

/// Callback for iterating through each key/value pair in a map
///
/// @param map The `Map` instance
/// @param key A key string
/// @param value A value
typedef void (*key_value_cb)(Map *map, const char *key, void *value);

#endif /* NVIM_MAP_DEFS_H */

