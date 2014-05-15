// General-purpose string->pointer associative array with a simple API
#ifndef NVIM_MAP_H
#define NVIM_MAP_H

#include <stdbool.h>

#include "nvim/map_defs.h"

/// Creates a new `Map` instance
///
/// @return a pointer to the new instance
Map *map_new(void);

/// Frees memory for a `Map` instance
///
/// @param map The `Map` instance
void map_free(Map *map);

/// Gets the value corresponding to a key in a `Map` instance
///
/// @param map The `Map` instance
/// @param key A key string
/// @return The value if the key exists in the map, or NULL if it doesn't
void *map_get(Map *map, const char *key);

/// Checks if a key exists in the map
///
/// @param map The `Map` instance
/// @param key A key string
/// @return true if the key exists, false otherwise
bool map_has(Map *map, const char *key);

/// Set the value corresponding to a key in a `Map` instance and returns
/// the old value.
///
/// @param map The `Map` instance
/// @param key A key string
/// @param value A value
/// @return The current value if exists or NULL otherwise
void *map_put(Map *map, const char *key, void *value);

/// Deletes the value corresponding to a key in a `Map` instance and returns
/// the old value.
///
/// @param map The `Map` instance
/// @param key A key string
/// @return The current value if exists or NULL otherwise
void *map_del(Map *map, const char *key);

/// Iterates through each key/value pair in the map
///
/// @param map The `Map` instance
/// @param cb A function that will be called for each key/value
void map_foreach(Map *map, key_value_cb cb);

#endif /* NVIM_MAP_H */

