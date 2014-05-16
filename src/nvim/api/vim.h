#ifndef NVIM_API_VIM_H
#define NVIM_API_VIM_H

#include <stdint.h>
#include <stdbool.h>

#include "nvim/api/defs.h"

/// Send keys to vim input buffer, simulating user input.
///
/// @param str The keys to send
void vim_push_keys(String str);

/// Executes an ex-mode command str
///
/// @param str The command str
/// @param[out] err Details of an error that may have occurred
void vim_command(String str, Error *err);

/// Evaluates the expression str using the vim internal expression
/// evaluator (see |expression|).
/// Dictionaries and lists are recursively expanded.
///
/// @param str The expression str
/// @param[out] err Details of an error that may have occurred
/// @return The expanded object
Object vim_eval(String str, Error *err);

/// Calculates the number of display cells `str` occupies, tab is counted as
/// one cell.
///
/// @param str Some text
/// @param[out] err Details of an error that may have occurred
/// @return The number of cells
Integer vim_strwidth(String str, Error *err);

/// Returns a list of paths contained in 'runtimepath'
///
/// @return The list of paths
StringArray vim_list_runtime_paths(void);

/// Changes vim working directory
///
/// @param dir The new working directory
/// @param[out] err Details of an error that may have occurred
void vim_change_directory(String dir, Error *err);

/// Return the current line
///
/// @param[out] err Details of an error that may have occurred
/// @return The current line string
String vim_get_current_line(Error *err);

/// Delete the current line
///
/// @param[out] err Details of an error that may have occurred
void vim_del_current_line(Error *err);

/// Sets the current line
///
/// @param line The line contents
/// @param[out] err Details of an error that may have occurred
void vim_set_current_line(String line, Error *err);

/// Gets a global variable
///
/// @param name The variable name
/// @param[out] err Details of an error that may have occurred
/// @return The variable value
Object vim_get_var(String name, Error *err);

/// Sets a global variable. Passing 'nil' as value deletes the variable.
///
/// @param name The variable name
/// @param value The variable value
/// @param[out] err Details of an error that may have occurred
/// @return the old value if any
Object vim_set_var(String name, Object value, Error *err);

/// Gets a vim variable
///
/// @param name The variable name
/// @param[out] err Details of an error that may have occurred
/// @return The variable value
Object vim_get_vvar(String name, Error *err);

/// Get an option value string
///
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
/// @return The option value
Object vim_get_option(String name, Error *err);

/// Sets an option value
///
/// @param name The option name
/// @param value The new option value
/// @param[out] err Details of an error that may have occurred
void vim_set_option(String name, Object value, Error *err);

/// Write a message to vim output buffer
///
/// @param str The message
void vim_out_write(String str);

/// Write a message to vim error buffer
///
/// @param str The message
void vim_err_write(String str);

/// Gets the number of buffers
///
/// @return The number of buffers
Integer vim_get_buffer_count(void);

/// Return the current buffer
///
/// @reqturn The buffer handle
Buffer vim_get_current_buffer(void);

/// Sets the current buffer
///
/// @param id The buffer handle
/// @param[out] err Details of an error that may have occurred
void vim_set_current_buffer(Buffer buffer, Error *err);

/// Gets the number of windows
///
/// @return The number of windows
Integer vim_get_window_count(void);

/// Return the current window
///
/// @return The window handle
Window vim_get_current_window(void);

/// Sets the current window
///
/// @param handle The window handle
void vim_set_current_window(Window window, Error *err);

/// Gets the number of tab pages
///
/// @return The number of tab pages
Integer vim_get_tabpage_count(void);

/// Return the current tab page
///
/// @return The tab page handle
Tabpage vim_get_current_tabpage(void);

/// Sets the current tab page
///
/// @param handle The tab page handle
/// @param[out] err Details of an error that may have occurred
void vim_set_current_tabpage(Tabpage tabpage, Error *err);

#endif  // NVIM_API_VIM_H

