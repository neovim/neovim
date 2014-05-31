#ifndef DEFINE_FUNC_ATTRIBUTES
# define DEFINE_FUNC_ATTRIBUTES
#endif
#include "func_attr.h"
#undef DEFINE_FUNC_ATTRIBUTES
void sha256_start(context_sha256_T *ctx);
void sha256_update(context_sha256_T *ctx, char_u *input, uint32_t length);
void sha256_finish(context_sha256_T *ctx, char_u digest[32]);
char_u *sha256_bytes(char_u *buf, int buf_len, char_u *salt, int salt_len);
char_u *sha256_key(char_u *buf, char_u *salt, int salt_len);
int sha256_self_test(void);
void sha2_seed(char_u *header, int header_len, char_u *salt, int salt_len);
#include "func_attr.h"
