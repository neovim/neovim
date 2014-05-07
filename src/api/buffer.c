#include <stdint.h>
#include <stdlib.h>

#include "api/buffer.h"
#include "api/defs.h"

int64_t buffer_get_length(Buffer buffer, Error *err)
{
  abort();
}

String buffer_get_line(Buffer buffer, int64_t index, Error *err)
{
  abort();
}

void buffer_set_line(Buffer buffer, int64_t index, String line, Error *err)
{
  abort();
}

StringArray buffer_get_slice(Buffer buffer,
                            int64_t start,
                            int64_t end,
                            Error *err)
{
  abort();
}

void buffer_set_slice(Buffer buffer,
                      int64_t start,
                      int64_t end,
                      StringArray lines,
                      Error *err)
{
  abort();
}

Object buffer_get_var(Buffer buffer, String name, Error *err)
{
  abort();
}

void buffer_set_var(Buffer buffer, String name, Object value, Error *err)
{
  abort();
}

String buffer_get_option(Buffer buffer, String name, Error *err)
{
  abort();
}

void buffer_set_option(Buffer buffer, String name, String value, Error *err)
{
  abort();
}

void buffer_del_option(Buffer buffer, String name, Error *err)
{
  abort();
}

String buffer_get_name(Buffer buffer, Error *err)
{
  abort();
}

void buffer_set_name(Buffer buffer, String name, Error *err)
{
  abort();
}

bool buffer_is_valid(Buffer buffer)
{
  abort();
}

void buffer_insert(Buffer buffer, StringArray lines, int64_t lnum, Error *err)
{
  abort();
}

Position buffer_mark(Buffer buffer, String name, Error *err)
{
  abort();
}
