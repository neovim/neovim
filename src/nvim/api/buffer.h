#ifndef NVIM_API_BUFFER_H
#define NVIM_API_BUFFER_H

#include <stdint.h>
#include <stdbool.h>

#include "nvim/api/private/defs.h"

Integer buffer_get_length(Buffer buffer, Error *err);

String buffer_get_line(Buffer buffer, Integer index, Error *err);

void buffer_set_line(Buffer buffer, Integer index, String line, Error *err);

void buffer_del_line(Buffer buffer, Integer index, Error *err);

StringArray buffer_get_slice(Buffer buffer,
                             Integer start,
                             Integer end,
                             Boolean include_start,
                             Boolean include_end,
                             Error *err);

void buffer_set_slice(Buffer buffer,
                      Integer start,
                      Integer end,
                      Boolean include_start,
                      Boolean include_end,
                      StringArray replacement,
                      Error *err);

Object buffer_get_var(Buffer buffer, String name, Error *err);

Object buffer_set_var(Buffer buffer, String name, Object value, Error *err);

Object buffer_get_option(Buffer buffer, String name, Error *err);

void buffer_set_option(Buffer buffer, String name, Object value, Error *err);

Integer buffer_get_number(Buffer buffer, Error *err);

String buffer_get_name(Buffer buffer, Error *err);

void buffer_set_name(Buffer buffer, String name, Error *err);

Boolean buffer_is_valid(Buffer buffer);

void buffer_insert(Buffer buffer, Integer lnum, StringArray lines, Error *err);

Position buffer_get_mark(Buffer buffer, String name, Error *err);

#endif  // NVIM_API_BUFFER_H

