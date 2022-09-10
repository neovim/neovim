#ifndef HUNSPELL_WRAPPER_H
#define HUNSPELL_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif // __cplusplus

#include <hunspell/hunspell.h>
#include <stdbool.h>
#include <stdlib.h>

#define HSPELL_COMPOUND (1 << 0)
#define HSPELL_FORBIDDEN (1 << 1)
#define HSPELL_ALLCAP (1 << 2)
#define HSPELL_NOCAP (1 << 3)
#define HSPELL_INITCAP (1 << 4)
#define HSPELL_ORIGCAP (1 << 5)
#define HSPELL_WARN (1 << 6)

typedef struct hunspell_S hunspell_T;

hunspell_T * hunspell_create(const char *affpath, const char *dicpath);

void hunspell_destroy(hunspell_T *pHunspell);

void hunspell_add_dic(hunspell_T *pHunspell, const char *dicpath);

bool hunspell_is_wordchar(hunspell_T *handle, const char *p);

bool hunspell_spell_flags(hunspell_T *handle, const char *word, size_t len, int *flags);

size_t hunspell_suggest(hunspell_T *handle, const char *word, size_t len, char ***ret);

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // HUNSPELL_WRAPPER_H
