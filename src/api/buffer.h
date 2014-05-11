#ifndef NEOVIM_API_BUFFER_H
#define NEOVIM_API_BUFFER_H

#include <stdint.h>
#include <stdbool.h>

#include "api/defs.h"

/// Gets the buffer line count
///
/// @param buffer The buffer handle
/// @param[out] err Details of an error that may have occurred
/// @return The line count
int64_t buffer_get_length(Buffer buffer, Error *err);

/// Gets a buffer line
///
/// @param buffer The buffer handle
/// @param index The line index
/// @param[out] err Details of an error that may have occurred
/// @return The line string
String buffer_get_line(Buffer buffer, int64_t index, Error *err);

/// Sets a buffer line
///
/// @param buffer The buffer handle
/// @param index The line index
/// @param line The new line.
/// @param[out] err Details of an error that may have occurred
void buffer_set_line(Buffer buffer, int64_t index, String line, Error *err);

/// Retrieves a line range from the buffer
///
/// @param buffer The buffer handle
/// @param start The first line index
/// @param end The last line index
/// @param include_start True if the slice includes the `start` parameter
/// @param include_end True if the slice includes the `end` parameter
/// @param[out] err Details of an error that may have occurred
/// @return An array of lines
StringArray buffer_get_slice(Buffer buffer,
                             int64_t start,
                             int64_t end,
                             bool include_start,
                             bool include_end,
                             Error *err);

/// Replaces a line range on the buffer
///
/// @param buffer The buffer handle
/// @param start The first line index
/// @param end The last line index
/// @param include_start True if the slice includes the `start` parameter
/// @param include_end True if the slice includes the `end` parameter
/// @param lines An array of lines to use as replacement(A 0-length array
///        will simply delete the line range)
/// @param[out] err Details of an error that may have occurred
void buffer_set_slice(Buffer buffer,
                      int64_t start,
                      int64_t end,
                      bool include_start,
                      bool include_end,
                      StringArray replacement,
                      Error *err);

/// Gets a buffer variable
///
/// @param buffer The buffer handle
/// @param name The variable name
/// @param[out] err Details of an error that may have occurred
/// @return The variable value
Object buffer_get_var(Buffer buffer, String name, Error *err);

/// Sets a buffer variable
///
/// @param buffer The buffer handle
/// @param name The variable name
/// @param value The variable value
/// @param[out] err Details of an error that may have occurred
void buffer_set_var(Buffer buffer, String name, Object value, Error *err);

/// Gets a buffer option value
///
/// @param buffer The buffer handle
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
/// @return The option value
String buffer_get_option(Buffer buffer, String name, Error *err);

/// Sets a buffer option value
///
/// @param buffer The buffer handle
/// @param name The option name
/// @param value The option value
/// @param[out] err Details of an error that may have occurred
void buffer_set_option(Buffer buffer, String name, String value, Error *err);

/// Deletes a buffer option(falls back to the global value if available)
///
/// @param buffer The buffer handle
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
void buffer_del_option(Buffer buffer, String name, Error *err);

/// Gets the full file name for the buffer
///
/// @param buffer The buffer handle
/// @param[out] err Details of an error that may have occurred
/// @return The buffer name
String buffer_get_name(Buffer buffer, Error *err);

/// Sets the full file name for a buffer
///
/// @param buffer The buffer handle
/// @param name The buffer name
/// @param[out] err Details of an error that may have occurred
void buffer_set_name(Buffer buffer, String name, Error *err);

/// Checks if a buffer is valid
///
/// @param buffer The buffer handle
/// @return true if the buffer is valid, false otherwise
bool buffer_is_valid(Buffer buffer);

/// Inserts a sequence of lines to a buffer at a certain index
///
/// @param buffer The buffer handle
/// @param lines An array of lines
/// @param lnum Insert the lines before `lnum`. If negative, it will append
///        to the end of the buffer.
/// @param[out] err Details of an error that may have occurred
void buffer_insert(Buffer buffer, StringArray lines, int64_t lnum, Error *err);

/// Creates a mark in the buffer and returns a tuple(row, col) representing 
/// the position of the named mark
///
/// @param buffer The buffer handle
/// @param name The mark's name
/// @param[out] err Details of an error that may have occurred
/// @return The (row, col) tuple
Position buffer_mark(Buffer buffer, String name, Error *err);

#endif // NEOVIM_API_BUFFER_H

