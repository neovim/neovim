#ifndef NVIM_API_TABPAGE_H
#define NVIM_API_TABPAGE_H

#include <stdint.h>
#include <stdbool.h>

#include "nvim/api/private/defs.h"

Object tabpage_get_var(Tabpage tabpage, String name, Error *err);

Object tabpage_set_var(Tabpage tabpage, String name, Object value, Error *err);

Window tabpage_get_window(Tabpage tabpage, Error *err);

Boolean tabpage_is_valid(Tabpage tabpage);

#endif  // NVIM_API_TABPAGE_H

