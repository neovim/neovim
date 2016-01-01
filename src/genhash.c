// Program used to generate static hashes
//
// Uses hashes from khash.h macros library.

#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

#define USE_LIBC_ALLOCATOR
#include "nvim/lib/khash.h"

KHASH_MAP_INIT_STR(hash, char *)

#define CHECK_FAIL(cond, ...) \
    do { \
      if (cond) { \
        fprintf(stderr, __VA_ARGS__); \
        putc('\n', stderr); \
        return 1; \
      } \
    } while (0)

int main(int argc, char **argv)
{
  if (argc == 2 && strcmp(argv[1], "--help") == 0) {
    puts("Usage:");
    puts("  genhash SOURCE TARGET TYPE NAME VALTYPE NULLVAL");
    puts("Transforms keys and values in a form \"key\\nval\\n\" into a hash");
    puts("literal.");
    puts("");
    puts("SOURCE is the file name to read keys and values from.");
    puts("TARGET is the file name to write to.");
    puts("TYPE is the name of the hash type (khash_t argument).");
    puts("NAME is the name of the generated hash.");
    puts("VALTYPE is the name of the value type.");
    puts("NULLVAL is the value used when no value is available.");
    return 0;
  }

  CHECK_FAIL(argc != 7, "Expecting six arguments, got %i.", argc);

  const char *const source = argv[1];
  const char *const target = argv[2];
  const char *const type = argv[3];
  const char *const name = argv[4];
  const char *const valtype = argv[5];
  const char *const nullval = argv[6];

  FILE *fin = fopen(source, "r");
  CHECK_FAIL(!fin, "Failed to open source: %s.", strerror(errno));

  char keybuf[80];
  char valbuf[4096];
  khash_t(hash) hash = KHASH_EMPTY_TABLE(hash);
  while (fgets(keybuf, sizeof(keybuf), fin) != NULL) {
    CHECK_FAIL(ferror(fin), "Failed to read key %i from source: %s",
               (int) kh_size(&hash), strerror(ferror(fin)));
    keybuf[strlen(keybuf) - 1] = 0;
    CHECK_FAIL(!fgets(valbuf, sizeof(valbuf), fin),
               "Failed to read value for key %i (%s): %s",
               (int) kh_size(&hash), keybuf, (ferror(fin)
                                              ? strerror(ferror(fin))
                                              : "EOF found"));
    valbuf[strlen(valbuf) - 1] = 0;
    char *const key_copy = strdup(keybuf);
    CHECK_FAIL(!key_copy, "Failed to allocate memory for a key");
    int put_ret;
    const khiter_t k = kh_put(hash, &hash, key_copy, &put_ret);
    CHECK_FAIL(put_ret != 1, "Expecting unused non-empty bucket for key %s",
               key_copy);
    kh_value(&hash, k) = strdup(valbuf);
    CHECK_FAIL(!kh_value(&hash, k), "Failed to allocate memory for a value");
  }
  CHECK_FAIL(fclose(fin), "Failed to close source: %s", strerror(errno));

  FILE *f = fopen(target, "w");
  CHECK_FAIL(!f, strerror(errno));
  fprintf(f,     "static const khash_t(%s) %s = {", type, name);
  fprintf(f,     "  .n_buckets = %i,\n", (int) hash.n_buckets);
  fprintf(f,     "  .size = %i,\n", (int) hash.size);
  fprintf(f,     "  .n_occupied = %i,\n", (int) hash.n_occupied);
  fprintf(f,     "  .upper_bound = %i,\n", (int) hash.upper_bound);
  fprintf(f,     "  .flags = (khint32_t[]) {\n");
  for (khint_t i = 0; i < kh_end(&hash); i++) {
    fprintf(f,   "    %i,\n", (int) hash.flags[i]);
  }
  fprintf(f,     "  },\n");
  fprintf(f,     "  .keys = (const char*[]) {\n");
  for (khint_t i = 0; i < kh_end(&hash); i++) {
    if (kh_exist(&hash, i)) {
      fprintf(f, "    \"%s\",\n", hash.keys[i]);
    } else {
      fprintf(f, "    NULL,\n");
    }
  }
  fprintf(f,     "  },\n");
  fprintf(f,     "  .vals = (%s[]) {\n", valtype);
  for (khint_t i = 0; i < kh_end(&hash); i++) {
    fprintf(f,   "    %s,\n", (kh_exist(&hash, i) ? hash.vals[i] : nullval));
  }
  fprintf(f,     "  },\n");
  fprintf(f,     "};\n");
  fclose(f);
  return 0;
}
