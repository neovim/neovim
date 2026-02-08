/*
 * Fuzz the neovim bundled libvterm terminal escape sequence parser.
 *
 * vterm_input_write() is the main entry point for all terminal input data.
 * It parses CSI, OSC, DCS, ESC sequences, UTF-8 text, and C0/C1 controls.
 * This is the code path that processes untrusted terminal output from
 * programs running inside neovim's :terminal.
 *
 * Build: cmake --build build --target fuzz_vterm
 * Run:   ./build/bin/fuzz_vterm -dict=test/fuzz/vterm.dict corpus_vterm/
 */

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Stub implementations of neovim's memory functions.
 * Linked before libnvim.a so our stubs take priority via
 * --allow-multiple-definition. */
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

/* Forward declarations for vterm API */
typedef struct VTerm VTerm;
typedef struct VTermScreen VTermScreen;

VTerm *vterm_new(int rows, int cols);
void vterm_free(VTerm *vt);
void vterm_set_utf8(VTerm *vt, int is_utf8);
size_t vterm_input_write(VTerm *vt, const char *bytes, size_t len);
VTermScreen *vterm_obtain_screen(VTerm *vt);
void vterm_screen_reset(VTermScreen *screen, int hard);

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
  if (size < 1 || size > 8192)
    return 0;

  int rows = (data[0] & 0x1f) + 1;
  int cols = ((data[0] >> 5) & 0x07) * 20 + 20;
  int utf8 = (data[0] & 0x80) ? 1 : 0;

  VTerm *vt = vterm_new(rows, cols);
  if (!vt)
    return 0;

  vterm_set_utf8(vt, utf8);

  VTermScreen *screen = vterm_obtain_screen(vt);
  vterm_screen_reset(screen, 1);

  vterm_input_write(vt, (const char *)(data + 1), size - 1);

  vterm_free(vt);
  return 0;
}
