#ifndef NVIM_API_TABPAGE_H
#define NVIM_API_TABPAGE_H

#include <stdint.h>
#include <stdbool.h>

#include "nvim/api/defs.h"

/// Gets the number of windows in a tabpage
///
/// @param tabpage The tabpage
/// @param[out] err Details of an error that may have occurred
/// @return The number of windows in `tabpage`
Integer tabpage_get_window_count(Tabpage tabpage, Error *err);

/// Gets a tabpage variable
///
/// @param tabpage The tab page handle
/// @param name The variable name
/// @param[out] err Details of an error that may have occurred
/// @return The variable value
Object tabpage_get_var(Tabpage tabpage, String name, Error *err);

/// Sets a tabpage variable. Passing 'nil' as value deletes the variable.
///
/// @param tabpage handle
/// @param name The variable name
/// @param value The variable value
/// @param[out] err Details of an error that may have occurred
/// @return The tab page handle
Object tabpage_set_var(Tabpage tabpage, String name, Object value, Error *err);

/// Gets the current window in a tab page
///
/// @param tabpage The tab page handle
/// @param[out] err Details of an error that may have occurred
/// @return The Window handle
Window tabpage_get_window(Tabpage tabpage, Error *err);

/// Checks if a tab page is valid
///
/// @param tabpage The tab page handle
/// @return true if the tab page is valid, false otherwise
Boolean tabpage_is_valid(Tabpage tabpage);

#endif  // NVIM_API_TABPAGE_H

