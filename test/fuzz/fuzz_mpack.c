/*
 * Fuzz mpack tokenizer -- standalone, zero neovim dependencies.
 *
 * We compile mpack.c directly so this target does NOT link against
 * libnvim and has no external dependencies at all.
 *
 * Build: cmake --build build --target fuzz_mpack
 * Run:   ./build/bin/fuzz_mpack -dict=test/fuzz/mpack.dict corpus_mpack/
 */

#include <stddef.h>
#include <stdint.h>
#include <string.h>

/* mpack_core.c is compiled separately. */
#include "mpack_core.h"

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size == 0 || size > 65536)
    return 0;

  mpack_tokbuf_t tokbuf;
  mpack_tokbuf_init(&tokbuf);

  const char *buf = (const char *)data;
  size_t buflen = size;

  while (buflen > 0) {
    mpack_token_t tok;
    int rc = mpack_read(&tokbuf, &buf, &buflen, &tok);
    if (rc == MPACK_EOF || (rc != MPACK_OK && rc != MPACK_EOF))
      break;
  }

  return 0;
}
