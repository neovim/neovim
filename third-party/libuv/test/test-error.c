/* Copyright Joyent, Inc. and other Node contributors. All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

#include "uv.h"
#include "task.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>


/*
 * Synthetic errors (errors that originate from within libuv, not the system)
 * should produce sensible error messages when run through uv_strerror().
 *
 * See https://github.com/joyent/libuv/issues/210
 */
TEST_IMPL(error_message) {
  /* Cop out. Can't do proper checks on systems with
   * i18n-ized error messages...
   */
  if (strcmp(uv_strerror(0), "Success") != 0) {
    printf("i18n error messages detected, skipping test.\n");
    return 0;
  }

  ASSERT(strstr(uv_strerror(UV_EINVAL), "Success") == NULL);
  ASSERT(strcmp(uv_strerror(1337), "Unknown error") == 0);
  ASSERT(strcmp(uv_strerror(-1337), "Unknown error") == 0);

  return 0;
}
