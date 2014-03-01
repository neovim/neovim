/* vi:set ts=8 sts=4 sw=4:
 *
 * VIM - Vi IMproved	by Bram Moolenaar
 *
 * Do ":help uganda"  in Vim to read copying and usage conditions.
 * Do ":help credits" in Vim to see a list of people who contributed.
 * See README.txt for an overview of the Vim source code.
 *
 * FIPS-180-2 compliant SHA-256 implementation
 * GPL by Christophe Devine, applies to older version.
 * Modified for md5deep, in public domain.
 * Modified For Vim, Mohsin Ahmed, http://www.cs.albany.edu/~mosh
 * Mohsin Ahmed states this work is distributed under the VIM License or GPL,
 * at your choice.
 *
 * Vim specific notes:
 * Functions exported by this file:
 *  1. sha256_key() hashes the password to 64 bytes char string.
 *  2. sha2_seed() generates a random header.
 *  sha256_self_test() is implicitly called once.
 */

#include "vim.h"
#include "sha256.h"

static void sha256_process(context_sha256_T *ctx, char_u data[64]);

#define GET_UINT32(n, b, i)                 \
  {                                           \
    (n) = ( (UINT32_T)(b)[(i)    ] << 24)   \
          | ( (UINT32_T)(b)[(i) + 1] << 16)   \
          | ( (UINT32_T)(b)[(i) + 2] <<  8)   \
          | ( (UINT32_T)(b)[(i) + 3]      );  \
  }

#define PUT_UINT32(n,b,i)                 \
  {                                         \
    (b)[(i)    ] = (char_u)((n) >> 24);   \
    (b)[(i) + 1] = (char_u)((n) >> 16);   \
    (b)[(i) + 2] = (char_u)((n) >>  8);   \
    (b)[(i) + 3] = (char_u)((n)      );   \
  }

void sha256_start(context_sha256_T *ctx)
{
  ctx->total[0] = 0;
  ctx->total[1] = 0;

  ctx->state[0] = 0x6A09E667;
  ctx->state[1] = 0xBB67AE85;
  ctx->state[2] = 0x3C6EF372;
  ctx->state[3] = 0xA54FF53A;
  ctx->state[4] = 0x510E527F;
  ctx->state[5] = 0x9B05688C;
  ctx->state[6] = 0x1F83D9AB;
  ctx->state[7] = 0x5BE0CD19;
}

static void sha256_process(context_sha256_T *ctx, char_u data[64])
{
  UINT32_T temp1, temp2, W[64];
  UINT32_T A, B, C, D, E, F, G, H;

  GET_UINT32(W[0],  data,  0);
  GET_UINT32(W[1],  data,  4);
  GET_UINT32(W[2],  data,  8);
  GET_UINT32(W[3],  data, 12);
  GET_UINT32(W[4],  data, 16);
  GET_UINT32(W[5],  data, 20);
  GET_UINT32(W[6],  data, 24);
  GET_UINT32(W[7],  data, 28);
  GET_UINT32(W[8],  data, 32);
  GET_UINT32(W[9],  data, 36);
  GET_UINT32(W[10], data, 40);
  GET_UINT32(W[11], data, 44);
  GET_UINT32(W[12], data, 48);
  GET_UINT32(W[13], data, 52);
  GET_UINT32(W[14], data, 56);
  GET_UINT32(W[15], data, 60);

#define  SHR(x, n) ((x & 0xFFFFFFFF) >> n)
#define ROTR(x, n) (SHR(x, n) | (x << (32 - n)))

#define S0(x) (ROTR(x, 7) ^ ROTR(x, 18) ^  SHR(x, 3))
#define S1(x) (ROTR(x, 17) ^ ROTR(x, 19) ^  SHR(x, 10))

#define S2(x) (ROTR(x, 2) ^ ROTR(x, 13) ^ ROTR(x, 22))
#define S3(x) (ROTR(x, 6) ^ ROTR(x, 11) ^ ROTR(x, 25))

#define F0(x, y, z) ((x & y) | (z & (x | y)))
#define F1(x, y, z) (z ^ (x & (y ^ z)))

#define R(t)                            \
  (                                       \
    W[t] = S1(W[t -  2]) + W[t -  7] +  \
           S0(W[t - 15]) + W[t - 16]    \
  )

#define P(a,b,c,d,e,f,g,h,x,K)               \
  {                                            \
    temp1 = h + S3(e) + F1(e, f, g) + K + x; \
    temp2 = S2(a) + F0(a, b, c);             \
    d += temp1; h = temp1 + temp2;           \
  }

  A = ctx->state[0];
  B = ctx->state[1];
  C = ctx->state[2];
  D = ctx->state[3];
  E = ctx->state[4];
  F = ctx->state[5];
  G = ctx->state[6];
  H = ctx->state[7];

  P( A, B, C, D, E, F, G, H, W[ 0], 0x428A2F98);
  P( H, A, B, C, D, E, F, G, W[ 1], 0x71374491);
  P( G, H, A, B, C, D, E, F, W[ 2], 0xB5C0FBCF);
  P( F, G, H, A, B, C, D, E, W[ 3], 0xE9B5DBA5);
  P( E, F, G, H, A, B, C, D, W[ 4], 0x3956C25B);
  P( D, E, F, G, H, A, B, C, W[ 5], 0x59F111F1);
  P( C, D, E, F, G, H, A, B, W[ 6], 0x923F82A4);
  P( B, C, D, E, F, G, H, A, W[ 7], 0xAB1C5ED5);
  P( A, B, C, D, E, F, G, H, W[ 8], 0xD807AA98);
  P( H, A, B, C, D, E, F, G, W[ 9], 0x12835B01);
  P( G, H, A, B, C, D, E, F, W[10], 0x243185BE);
  P( F, G, H, A, B, C, D, E, W[11], 0x550C7DC3);
  P( E, F, G, H, A, B, C, D, W[12], 0x72BE5D74);
  P( D, E, F, G, H, A, B, C, W[13], 0x80DEB1FE);
  P( C, D, E, F, G, H, A, B, W[14], 0x9BDC06A7);
  P( B, C, D, E, F, G, H, A, W[15], 0xC19BF174);
  P( A, B, C, D, E, F, G, H, R(16), 0xE49B69C1);
  P( H, A, B, C, D, E, F, G, R(17), 0xEFBE4786);
  P( G, H, A, B, C, D, E, F, R(18), 0x0FC19DC6);
  P( F, G, H, A, B, C, D, E, R(19), 0x240CA1CC);
  P( E, F, G, H, A, B, C, D, R(20), 0x2DE92C6F);
  P( D, E, F, G, H, A, B, C, R(21), 0x4A7484AA);
  P( C, D, E, F, G, H, A, B, R(22), 0x5CB0A9DC);
  P( B, C, D, E, F, G, H, A, R(23), 0x76F988DA);
  P( A, B, C, D, E, F, G, H, R(24), 0x983E5152);
  P( H, A, B, C, D, E, F, G, R(25), 0xA831C66D);
  P( G, H, A, B, C, D, E, F, R(26), 0xB00327C8);
  P( F, G, H, A, B, C, D, E, R(27), 0xBF597FC7);
  P( E, F, G, H, A, B, C, D, R(28), 0xC6E00BF3);
  P( D, E, F, G, H, A, B, C, R(29), 0xD5A79147);
  P( C, D, E, F, G, H, A, B, R(30), 0x06CA6351);
  P( B, C, D, E, F, G, H, A, R(31), 0x14292967);
  P( A, B, C, D, E, F, G, H, R(32), 0x27B70A85);
  P( H, A, B, C, D, E, F, G, R(33), 0x2E1B2138);
  P( G, H, A, B, C, D, E, F, R(34), 0x4D2C6DFC);
  P( F, G, H, A, B, C, D, E, R(35), 0x53380D13);
  P( E, F, G, H, A, B, C, D, R(36), 0x650A7354);
  P( D, E, F, G, H, A, B, C, R(37), 0x766A0ABB);
  P( C, D, E, F, G, H, A, B, R(38), 0x81C2C92E);
  P( B, C, D, E, F, G, H, A, R(39), 0x92722C85);
  P( A, B, C, D, E, F, G, H, R(40), 0xA2BFE8A1);
  P( H, A, B, C, D, E, F, G, R(41), 0xA81A664B);
  P( G, H, A, B, C, D, E, F, R(42), 0xC24B8B70);
  P( F, G, H, A, B, C, D, E, R(43), 0xC76C51A3);
  P( E, F, G, H, A, B, C, D, R(44), 0xD192E819);
  P( D, E, F, G, H, A, B, C, R(45), 0xD6990624);
  P( C, D, E, F, G, H, A, B, R(46), 0xF40E3585);
  P( B, C, D, E, F, G, H, A, R(47), 0x106AA070);
  P( A, B, C, D, E, F, G, H, R(48), 0x19A4C116);
  P( H, A, B, C, D, E, F, G, R(49), 0x1E376C08);
  P( G, H, A, B, C, D, E, F, R(50), 0x2748774C);
  P( F, G, H, A, B, C, D, E, R(51), 0x34B0BCB5);
  P( E, F, G, H, A, B, C, D, R(52), 0x391C0CB3);
  P( D, E, F, G, H, A, B, C, R(53), 0x4ED8AA4A);
  P( C, D, E, F, G, H, A, B, R(54), 0x5B9CCA4F);
  P( B, C, D, E, F, G, H, A, R(55), 0x682E6FF3);
  P( A, B, C, D, E, F, G, H, R(56), 0x748F82EE);
  P( H, A, B, C, D, E, F, G, R(57), 0x78A5636F);
  P( G, H, A, B, C, D, E, F, R(58), 0x84C87814);
  P( F, G, H, A, B, C, D, E, R(59), 0x8CC70208);
  P( E, F, G, H, A, B, C, D, R(60), 0x90BEFFFA);
  P( D, E, F, G, H, A, B, C, R(61), 0xA4506CEB);
  P( C, D, E, F, G, H, A, B, R(62), 0xBEF9A3F7);
  P( B, C, D, E, F, G, H, A, R(63), 0xC67178F2);

  ctx->state[0] += A;
  ctx->state[1] += B;
  ctx->state[2] += C;
  ctx->state[3] += D;
  ctx->state[4] += E;
  ctx->state[5] += F;
  ctx->state[6] += G;
  ctx->state[7] += H;
}

void sha256_update(context_sha256_T *ctx, char_u *input, UINT32_T length)
{
  UINT32_T left, fill;

  if (length == 0)
    return;

  left = ctx->total[0] & 0x3F;
  fill = 64 - left;

  ctx->total[0] += length;
  ctx->total[0] &= 0xFFFFFFFF;

  if (ctx->total[0] < length)
    ctx->total[1]++;

  if (left && length >= fill) {
    memcpy((void *)(ctx->buffer + left), (void *)input, fill);
    sha256_process(ctx, ctx->buffer);
    length -= fill;
    input  += fill;
    left = 0;
  }

  while (length >= 64) {
    sha256_process(ctx, input);
    length -= 64;
    input  += 64;
  }

  if (length)
    memcpy((void *)(ctx->buffer + left), (void *)input, length);
}

static char_u sha256_padding[64] = {
  0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
};

void sha256_finish(context_sha256_T *ctx, char_u digest[32])
{
  UINT32_T last, padn;
  UINT32_T high, low;
  char_u msglen[8];

  high = (ctx->total[0] >> 29) | (ctx->total[1] <<  3);
  low  = (ctx->total[0] <<  3);

  PUT_UINT32(high, msglen, 0);
  PUT_UINT32(low,  msglen, 4);

  last = ctx->total[0] & 0x3F;
  padn = (last < 56) ? (56 - last) : (120 - last);

  sha256_update(ctx, sha256_padding, padn);
  sha256_update(ctx, msglen, 8);

  PUT_UINT32(ctx->state[0], digest,  0);
  PUT_UINT32(ctx->state[1], digest,  4);
  PUT_UINT32(ctx->state[2], digest,  8);
  PUT_UINT32(ctx->state[3], digest, 12);
  PUT_UINT32(ctx->state[4], digest, 16);
  PUT_UINT32(ctx->state[5], digest, 20);
  PUT_UINT32(ctx->state[6], digest, 24);
  PUT_UINT32(ctx->state[7], digest, 28);
}

static unsigned int get_some_time(void);

/*
 * Returns hex digest of "buf[buf_len]" in a static array.
 * if "salt" is not NULL also do "salt[salt_len]".
 */
char_u *sha256_bytes(char_u *buf, int buf_len, char_u *salt, int salt_len)
{
  char_u sha256sum[32];
  static char_u hexit[65];
  int j;
  context_sha256_T ctx;

  sha256_self_test();

  sha256_start(&ctx);
  sha256_update(&ctx, buf, buf_len);
  if (salt != NULL)
    sha256_update(&ctx, salt, salt_len);
  sha256_finish(&ctx, sha256sum);
  for (j = 0; j < 32; j++)
    sprintf((char *)hexit + j * 2, "%02x", sha256sum[j]);
  hexit[sizeof(hexit) - 1] = '\0';
  return hexit;
}

/*
 * Returns sha256(buf) as 64 hex chars in static array.
 */
char_u *sha256_key(char_u *buf, char_u *salt, int salt_len)
{
  /* No passwd means don't encrypt */
  if (buf == NULL || *buf == NUL)
    return (char_u *)"";

  return sha256_bytes(buf, (int)STRLEN(buf), salt, salt_len);
}

/*
 * These are the standard FIPS-180-2 test vectors
 */

static char *sha_self_test_msg[] = {
  "abc",
  "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
  NULL
};

static char *sha_self_test_vector[] = {
  "ba7816bf8f01cfea414140de5dae2223" \
  "b00361a396177a9cb410ff61f20015ad",
  "248d6a61d20638b8e5c026930c3e6039" \
  "a33ce45964ff2167f6ecedd419db06c1",
  "cdc76e5c9914fb9281a1c7e284d73e67" \
  "f1809a48a497200e046d39ccc7112cd0"
};

/*
 * Perform a test on the SHA256 algorithm.
 * Return FAIL or OK.
 */
int sha256_self_test(void)         {
  int i, j;
  char output[65];
  context_sha256_T ctx;
  char_u buf[1000];
  char_u sha256sum[32];
  static int failures = 0;
  char_u           *hexit;
  static int sha256_self_tested = 0;

  if (sha256_self_tested > 0)
    return failures > 0 ? FAIL : OK;
  sha256_self_tested = 1;

  for (i = 0; i < 3; i++) {
    if (i < 2) {
      hexit = sha256_bytes((char_u *)sha_self_test_msg[i],
          (int)STRLEN(sha_self_test_msg[i]),
          NULL, 0);
      STRCPY(output, hexit);
    } else   {
      sha256_start(&ctx);
      vim_memset(buf, 'a', 1000);
      for (j = 0; j < 1000; j++)
        sha256_update(&ctx, (char_u *)buf, 1000);
      sha256_finish(&ctx, sha256sum);
      for (j = 0; j < 32; j++)
        sprintf(output + j * 2, "%02x", sha256sum[j]);
    }
    if (memcmp(output, sha_self_test_vector[i], 64)) {
      failures++;
      output[sizeof(output) - 1] = '\0';
      /* printf("sha256_self_test %d failed %s\n", i, output); */
    }
  }
  return failures > 0 ? FAIL : OK;
}

static unsigned int get_some_time(void)                         {
# ifdef HAVE_GETTIMEOFDAY
  struct timeval tv;

  /* Using usec makes it less predictable. */
  gettimeofday(&tv, NULL);
  return (unsigned int)(tv.tv_sec + tv.tv_usec);
# else
  return (unsigned int)time(NULL);
# endif
}

/*
 * Fill "header[header_len]" with random_data.
 * Also "salt[salt_len]" when "salt" is not NULL.
 */
void sha2_seed(char_u *header, int header_len, char_u *salt, int salt_len)
{
  int i;
  static char_u random_data[1000];
  char_u sha256sum[32];
  context_sha256_T ctx;

  srand(get_some_time());

  for (i = 0; i < (int)sizeof(random_data) - 1; i++)
    random_data[i] = (char_u)((get_some_time() ^ rand()) & 0xff);
  sha256_start(&ctx);
  sha256_update(&ctx, (char_u *)random_data, sizeof(random_data));
  sha256_finish(&ctx, sha256sum);

  /* put first block into header. */
  for (i = 0; i < header_len; i++)
    header[i] = sha256sum[i % sizeof(sha256sum)];

  /* put remaining block into salt. */
  if (salt != NULL)
    for (i = 0; i < salt_len; i++)
      salt[i] = sha256sum[(i + header_len) % sizeof(sha256sum)];
}

