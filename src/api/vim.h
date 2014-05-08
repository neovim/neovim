#ifndef NEOVIM_API_VIM_H
#define NEOVIM_API_VIM_H

#include <stdint.h>
#include <stdbool.h>

#include "api/defs.h"

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
/// @return The number of cells
int64_t vim_strwidth(String str);

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

/// Sets the current line
///
/// @param line The line contents
/// @param[out] err Details of an error that may have occurred
void vim_set_current_line(Object line, Error *err);

/// Gets a global or special variable
///
/// @param special If it's a special(:v) variable
/// @param name The variable name
/// @param[out] err Details of an error that may have occurred
/// @return The variable value
Object vim_get_var(bool special, String name, bool pop, Error *err);

/// Sets a global variable
///
/// @param name The variable name
/// @param value The variable value
/// @param[out] err Details of an error that may have occurred
/// @return the old value if any
Object vim_set_var(String name, Object value, Error *err);

/// Get an option value string
///
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
/// @return The option value
String vim_get_option(String name, Error *err);

/// Sets an option value
///
/// @param name The option name
/// @param value The new option value
/// @param[out] err Details of an error that may have occurred
void vim_set_option(String name, String value, Error *err);

/// Deletes an option, falling back to the default value
///
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
void vim_del_option(String name, Error *err);

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
int64_t vim_get_buffer_count(void);

/// Gets a buffer by index
///
/// @param num The buffer number
/// @param[out] err Details of an error that may have occurred
/// @return The buffer handle
Buffer vim_get_buffer(int64_t num, Error *err);

/// Return the current buffer
///
/// @reqturn The buffer handle
Buffer vim_get_current_buffer(void);

/// Sets the current buffer
///
/// @param id The buffer handle
void vim_set_current_buffer(Buffer buffer);

/// Gets the number of windows
///
/// @return The number of windows
int64_t vim_get_window_count(void);

/// Gets a window by index
///
/// @param num The window number
/// @param[out] err Details of an error that may have occurred
/// @return The window handle
Window vim_get_window(int64_t num, Error *err);

/// Return the current window
///
/// @return The window handle
Window vim_get_current_window(void);

/// Sets the current window
///
/// @param handle The window handle
void vim_set_current_window(Window window);

/// Gets the number of tab pages
///
/// @return The number of tab pages
int64_t vim_get_tabpage_count(void);

/// Gets a tab page by index
///
/// @param num The tabpage number
/// @param[out] err Details of an error that may have occurred
/// @return The tab page handle
Tabpage vim_get_tabpage(int64_t num, Error *err);

/// Return the current tab page
///
/// @return The tab page handle
Tabpage vim_get_current_tabpage(void);

/// Sets the current tab page
///
/// @param handle The tab page handle
void vim_set_current_tabpage(Tabpage tabpage);

#endif // NEOVIM_API_VIM_H

