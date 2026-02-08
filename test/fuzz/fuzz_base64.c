/*
 * Fuzz neovim's base64 encode/decode implementation (src/nvim/base64.c).
 *
 * Tests both decoding arbitrary (potentially malformed) input and
 * round-tripping through encode->decode.
 *
 * Build: cmake --build build --target fuzz_base64
 * Run:   ./build/bin/fuzz_base64 -dict=test/fuzz/base64.dict corpus_base64/
 */

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Stub implementations of neovim's memory functions. */
void *xmalloc(size_t size) {
  void *p = malloc(size ? size : 1);
  if (!p) abort();
  return p;
}

void xfree(void *p) { free(p); }

void *xcalloc(size_t count, size_t size) {
  void *p = calloc(count ? count : 1, size ? size : 1);
  if (!p) abort();
  return p;
}

void *xrealloc(void *p, size_t size) {
  void *r = realloc(p, size ? size : 1);
  if (!r) abort();
  return r;
}

void *xmallocz(size_t size) {
  void *p = xmalloc(size + 1);
  ((char *)p)[size] = '\0';
  return p;
}

void *xmemdupz(const void *data, size_t len) {
  void *p = xmallocz(len);
  memcpy(p, data, len);
  return p;
}

void preserve_exit(const char *errmsg) {
  (void)errmsg;
  abort();
}

/* Forward declarations from nvim/base64.h */
char *base64_encode(const char *src, size_t src_len);
char *base64_decode(const char *src, size_t src_len, size_t *out_lenp);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size < 1 || size > 4096)
    return 0;

  int mode = data[0] & 1;
  const char *input = (const char *)(data + 1);
  size_t input_len = size - 1;

  if (mode == 0) {
    size_t out_len = 0;
    char *decoded = base64_decode(input, input_len, &out_len);
    if (decoded)
      xfree(decoded);
  } else {
    char *encoded = base64_encode(input, input_len);
    if (encoded) {
      size_t decoded_len = 0;
      char *decoded = base64_decode(encoded, strlen(encoded), &decoded_len);
      if (decoded) {
        if (decoded_len != input_len ||
            memcmp(decoded, input, input_len) != 0) {
          abort(); /* Round-trip failure is a bug */
        }
        xfree(decoded);
      }
      xfree(encoded);
    }
  }

  return 0;
}
