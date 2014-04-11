#ifndef NEOVIM_API_H
#define NEOVIM_API_H

#include <stdint.h>

/// Send keys to vim input buffer, simulating user input.
///
/// @param str The keys to send
void api_push_keys(char *str);

/// Executes an ex-mode command str
///
/// @param str The command str
void api_command(char *str);

/// Evaluates the expression str using the vim internal expression
/// evaluator (see |expression|).  Returns the expression result as:
/// - a string if the Vim expression evaluates to a string or number
/// - a list if the Vim expression evaluates to a Vim list
/// - a dictionary if the Vim expression evaluates to a Vim dictionary
/// Dictionaries and lists are recursively expanded.
///
/// @param str The expression str
void api_eval(char *str);

/// Like eval, but returns special object ids that can be used to interact
/// with the real objects remotely.
//
/// @param str The expression str
uint32_t api_bind_eval(char *str);

/// Returns a list of paths contained in 'runtimepath'
/// 
/// @return The list of paths
char **api_list_runtime_paths(void);

/// Return a list of buffers
///
/// @return the list of buffers
char **api_list_buffers(void);

/// Return a list of windows
///
/// @return the list of windows
char **api_list_windows(void);

/// Return a list of tabpages
///
/// @return the list of tabpages
char **api_list_tabpages(void);

/// Return the current line
///
/// @return The current line
char *api_get_current_line(void);

/// Return the current buffer
///
/// @return The current buffer
uint32_t api_get_current_buffer(void);

/// Return the current window
///
/// @return The current window
uint32_t api_get_current_window(void);

/// Return the current tabpage
///
/// @return The current tabpage
uint32_t api_get_current_tabpage(void);

/// Sets the current line
///
/// @param line The line contents
void api_set_current_line(char *line);

/// Sets the current buffer
///
/// @param id The buffer id
void api_set_current_buffer(uint32_t id);

/// Sets the current window
///
/// @param id The window id
void api_set_current_window(uint32_t id);

/// Sets the current tabpage
///
/// @param id The tabpage id
void api_set_current_tabpage(uint32_t id);

/// Get an option value string
///
/// @param name The option name
char *api_get_option(char *name);

/// Get an option value string
///
/// @param name The option name
/// @param value The new option value
void api_set_option(char *name, char *value);

/// Write a message to vim output buffer
///
/// @param str The message
void api_out_write(char *str);

/// Write a message to vim error buffer
///
/// @param str The message
void api_err_write(char *str);

#endif // NEOVIM_API_H

