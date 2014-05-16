#ifndef NVIM_API_BUFFER_H
#define NVIM_API_BUFFER_H

#include <stdint.h>
#include <stdbool.h>

#include "nvim/api/defs.h"

/// Gets the buffer line count
///
/// @param buffer The buffer handle
/// @param[out] err Details of an error that may have occurred
/// @return The line count
Integer buffer_get_length(Buffer buffer, Error *err);

/// Gets a buffer line
///
/// @param buffer The buffer handle
/// @param index The line index
/// @param[out] err Details of an error that may have occurred
/// @return The line string
String buffer_get_line(Buffer buffer, Integer index, Error *err);

/// Sets a buffer line
///
/// @param buffer The buffer handle
/// @param index The line index
/// @param line The new line.
/// @param[out] err Details of an error that may have occurred
void buffer_set_line(Buffer buffer, Integer index, String line, Error *err);

/// Deletes a buffer line
///
/// @param buffer The buffer handle
/// @param index The line index
/// @param[out] err Details of an error that may have occurred
void buffer_del_line(Buffer buffer, Integer index, Error *err);

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
                             Integer start,
                             Integer end,
                             Boolean include_start,
                             Boolean include_end,
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
                      Integer start,
                      Integer end,
                      Boolean include_start,
                      Boolean include_end,
                      StringArray replacement,
                      Error *err);

/// Gets a buffer variable
///
/// @param buffer The buffer handle
/// @param name The variable name
/// @param[out] err Details of an error that may have occurred
/// @return The variable value
Object buffer_get_var(Buffer buffer, String name, Error *err);

/// Sets a buffer variable. Passing 'nil' as value deletes the variable.
///
/// @param buffer The buffer handle
/// @param name The variable name
/// @param value The variable value
/// @param[out] err Details of an error that may have occurred
/// @return The old value
Object buffer_set_var(Buffer buffer, String name, Object value, Error *err);

/// Gets a buffer option value
///
/// @param buffer The buffer handle
/// @param name The option name
/// @param[out] err Details of an error that may have occurred
/// @return The option value
Object buffer_get_option(Buffer buffer, String name, Error *err);

/// Sets a buffer option value. Passing 'nil' as value deletes the option(only
/// works if there's a global fallback)
///
/// @param buffer The buffer handle
/// @param name The option name
/// @param value The option value
/// @param[out] err Details of an error that may have occurred
void buffer_set_option(Buffer buffer, String name, Object value, Error *err);

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
Boolean buffer_is_valid(Buffer buffer);

/// Inserts a sequence of lines to a buffer at a certain index
///
/// @param buffer The buffer handle
/// @param lnum Insert the lines after `lnum`. If negative, it will append
///        to the end of the buffer.
/// @param lines An array of lines
/// @param[out] err Details of an error that may have occurred
void buffer_insert(Buffer buffer, Integer lnum, StringArray lines, Error *err);

/// Return a tuple (row,col) representing the position of the named mark
///
/// @param buffer The buffer handle
/// @param name The mark's name
/// @param[out] err Details of an error that may have occurred
/// @return The (row, col) tuple
Position buffer_get_mark(Buffer buffer, String name, Error *err);

#endif  // NVIM_API_BUFFER_H

