#include "conv.h"

static int mpack_fits_single(double v);
static mpack_value_t mpack_pack_ieee754(double v, unsigned m, unsigned e);
static int mpack_is_be(void) FPURE;
static double mpack_fmod_pow2_32(double a);


#define POW2(n) \
  ((double)(1 << (n / 2)) * (double)(1 << (n / 2)) * (double)(1 << (n % 2)))

#define MPACK_SWAP_VALUE(val)                                  \
  do {                                                         \
    mpack_uint32_t lo = val.lo;                                \
    val.lo = val.hi;                                           \
    val.hi = lo;                                               \
  } while (0)

MPACK_API mpack_token_t mpack_pack_nil(void)
{
  mpack_token_t rv;
  rv.type = MPACK_TOKEN_NIL;
  return rv;
}

MPACK_API mpack_token_t mpack_pack_boolean(unsigned v)
{
  mpack_token_t rv;
  rv.type = MPACK_TOKEN_BOOLEAN;
  rv.data.value.lo = v ? 1 : 0;
  rv.data.value.hi = 0;
  return rv;
}

MPACK_API mpack_token_t mpack_pack_uint(mpack_uintmax_t v)
{
  mpack_token_t rv;
  rv.data.value.lo = v & 0xffffffff;
  rv.data.value.hi = (mpack_uint32_t)((v >> 31) >> 1);
  rv.type = MPACK_TOKEN_UINT;
  return rv;
}

MPACK_API mpack_token_t mpack_pack_sint(mpack_sintmax_t v)
{
  if (v < 0) {
    mpack_token_t rv;
    mpack_uintmax_t tc = -((mpack_uintmax_t)(v + 1)) + 1;
    tc = ~tc + 1;
    rv = mpack_pack_uint(tc);
    rv.type = MPACK_TOKEN_SINT;
    return rv;
  }

  return mpack_pack_uint((mpack_uintmax_t)v);
}

MPACK_API mpack_token_t mpack_pack_float_compat(double v)
{
  /* ieee754 single-precision limits to determine if "v" can be fully
   * represented in 4 bytes */
  mpack_token_t rv;

  if (mpack_fits_single(v)) {
    rv.length = 4;
    rv.data.value = mpack_pack_ieee754(v, 23, 8);
  } else {
    rv.length = 8;
    rv.data.value = mpack_pack_ieee754(v, 52, 11);
  }

  rv.type = MPACK_TOKEN_FLOAT;
  return rv;
}

MPACK_API mpack_token_t mpack_pack_float_fast(double v)
{
  /* ieee754 single-precision limits to determine if "v" can be fully
   * represented in 4 bytes */
  mpack_token_t rv;

  if (mpack_fits_single(v)) {
    union {
      float f;
      mpack_uint32_t m;
    } conv;
    conv.f = (float)v;
    rv.length = 4;
    rv.data.value.lo = conv.m;
    rv.data.value.hi = 0;
  } else {
    union {
      double d;
      mpack_value_t m;
    } conv;
    conv.d = v;
    rv.length = 8;
    rv.data.value = conv.m;
    if (mpack_is_be()) {
      MPACK_SWAP_VALUE(rv.data.value);
    }
  }

  rv.type = MPACK_TOKEN_FLOAT;
  return rv;
}

MPACK_API mpack_token_t mpack_pack_number(double v)
{
  mpack_token_t tok;
  double vabs;
  vabs = v < 0 ? -v : v;
  assert(v <= 9007199254740991. && v >= -9007199254740991.);
  tok.data.value.hi = (mpack_uint32_t)(vabs / POW2(32));
  tok.data.value.lo = (mpack_uint32_t)mpack_fmod_pow2_32(vabs);

  if (v < 0) {
    /* Compute the two's complement */
    tok.type = MPACK_TOKEN_SINT;
    tok.data.value.hi = ~tok.data.value.hi;
    tok.data.value.lo = ~tok.data.value.lo + 1;
    if (!tok.data.value.lo) tok.data.value.hi++;
    if (tok.data.value.lo == 0 && tok.data.value.hi == 0) tok.length = 1;
    else if (tok.data.value.lo < 0x80000000) tok.length = 8;
    else if (tok.data.value.lo < 0xffff8000) tok.length = 4;
    else if (tok.data.value.lo < 0xffffff80) tok.length = 2;
    else tok.length = 1;
  } else {
    tok.type = MPACK_TOKEN_UINT;
    if (tok.data.value.hi) tok.length = 8;
    else if (tok.data.value.lo > 0xffff) tok.length = 4;
    else if (tok.data.value.lo > 0xff) tok.length = 2;
    else tok.length = 1;
  }

  if (mpack_unpack_number(tok) != v) {
    return mpack_pack_float(v);
  }

  return tok;
}

MPACK_API mpack_token_t mpack_pack_chunk(const char *p, mpack_uint32_t l)
{
  mpack_token_t rv;
  rv.type = MPACK_TOKEN_CHUNK;
  rv.data.chunk_ptr = p;
  rv.length = l;
  return rv;
}

MPACK_API mpack_token_t mpack_pack_str(mpack_uint32_t l)
{
  mpack_token_t rv;
  rv.type = MPACK_TOKEN_STR;
  rv.length = l;
  return rv;
}

MPACK_API mpack_token_t mpack_pack_bin(mpack_uint32_t l)
{
  mpack_token_t rv;
  rv.type = MPACK_TOKEN_BIN;
  rv.length = l;
  return rv;
}

MPACK_API mpack_token_t mpack_pack_ext(int t, mpack_uint32_t l)
{
  mpack_token_t rv;
  rv.type = MPACK_TOKEN_EXT;
  rv.length = l;
  rv.data.ext_type = t;
  return rv;
}

MPACK_API mpack_token_t mpack_pack_array(mpack_uint32_t l)
{
  mpack_token_t rv;
  rv.type = MPACK_TOKEN_ARRAY;
  rv.length = l;
  return rv;
}

MPACK_API mpack_token_t mpack_pack_map(mpack_uint32_t l)
{
  mpack_token_t rv;
  rv.type = MPACK_TOKEN_MAP;
  rv.length = l;
  return rv;
}

MPACK_API bool mpack_unpack_boolean(mpack_token_t t)
{
  return t.data.value.lo || t.data.value.hi;
}

MPACK_API mpack_uintmax_t mpack_unpack_uint(mpack_token_t t)
{
  return (((mpack_uintmax_t)t.data.value.hi << 31) << 1) | t.data.value.lo;
}

/* unpack signed integer without relying on two's complement as internal
 * representation */
MPACK_API mpack_sintmax_t mpack_unpack_sint(mpack_token_t t)
{
  mpack_uint32_t hi = t.data.value.hi;
  mpack_uint32_t lo = t.data.value.lo;
  mpack_uintmax_t rv = lo;
  assert(t.length <= sizeof(mpack_sintmax_t));

  if (t.length == 8) {
    rv |= (((mpack_uintmax_t)hi) << 31) << 1;
  }
  /* reverse the two's complement so that lo/hi contain the absolute value.
   * note that we have to mask ~rv so that it reflects the two's complement
   * of the appropriate byte length */
  rv = (~rv & (((mpack_uintmax_t)1 << ((t.length * 8) - 1)) - 1)) + 1;
  /* negate and return the absolute value, making sure mpack_sintmax_t can
   * represent the positive cast. */
  return -((mpack_sintmax_t)(rv - 1)) - 1;
}

MPACK_API double mpack_unpack_float_compat(mpack_token_t t)
{
  mpack_uint32_t sign;
  mpack_sint32_t exponent, bias;
  unsigned mantbits;
  unsigned expbits;
  double mant;

  if (t.data.value.lo == 0 && t.data.value.hi == 0)
    /* nothing to do */
    return 0;

  if (t.length == 4) mantbits = 23, expbits = 8;
  else mantbits = 52, expbits = 11;
  bias = (1 << (expbits - 1)) - 1;

  /* restore sign/exponent/mantissa */
  if (mantbits == 52) {
    sign = t.data.value.hi >> 31;
    exponent = (t.data.value.hi >> 20) & ((1 << 11) - 1);
    mant = (t.data.value.hi & ((1 << 20) - 1)) * POW2(32);
    mant += t.data.value.lo;
  } else {
    sign = t.data.value.lo >> 31;
    exponent = (t.data.value.lo >> 23) & ((1 << 8) - 1);
    mant = t.data.value.lo & ((1 << 23) - 1);
  }

  mant /= POW2(mantbits);
  if (exponent) mant += 1.0; /* restore leading 1 */
  else exponent = 1; /* subnormal */
  exponent -= bias;

  /* restore original value */
  while (exponent > 0) mant *= 2.0, exponent--;
  while (exponent < 0) mant /= 2.0, exponent++;
  return mant * (sign ? -1 : 1);
}

MPACK_API double mpack_unpack_float_fast(mpack_token_t t)
{
  if (t.length == 4) {
    union {
      float f;
      mpack_uint32_t m;
    } conv;
    conv.m = t.data.value.lo;
    return conv.f;
  } else {
    union {
      double d;
      mpack_value_t m;
    } conv;
    conv.m = t.data.value;
    
    if (mpack_is_be()) {
      MPACK_SWAP_VALUE(conv.m);
    }

    return conv.d;
  }
}

MPACK_API double mpack_unpack_number(mpack_token_t t)
{
  double rv;
  mpack_uint32_t hi, lo;
  if (t.type == MPACK_TOKEN_FLOAT) return mpack_unpack_float(t);
  assert(t.type == MPACK_TOKEN_UINT || t.type == MPACK_TOKEN_SINT);
  hi = t.data.value.hi;
  lo = t.data.value.lo;
  if (t.type == MPACK_TOKEN_SINT) {
    /* same idea as mpack_unpack_sint, except here we shouldn't rely on
     * mpack_uintmax_t having 64-bits, operating on the 32-bit words separately.
     */
    if (!hi) {
      assert(t.length <= 4);
      lo = (~lo & (((mpack_uint32_t)1 << ((t.length * 8) - 1)) - 1));
    } else {
      hi = ~hi;
      lo = ~lo;
    }
    lo++;
    if (!lo) hi++;
  }
  rv = (double)lo + POW2(32) * hi;
  return t.type == MPACK_TOKEN_SINT ? -rv : rv;
}

static int mpack_fits_single(double v)
{
  return (float)v == v;
}

static mpack_value_t mpack_pack_ieee754(double v, unsigned mantbits,
    unsigned expbits)
{
  mpack_value_t rv = {0, 0};
  mpack_sint32_t exponent, bias = (1 << (expbits - 1)) - 1;
  mpack_uint32_t sign;
  double mant;

  if (v == 0) {
    rv.lo = 0;
    rv.hi = 0;
    goto end;
  }

  if (v < 0) sign = 1, mant = -v;
  else sign = 0, mant = v;

  exponent = 0;
  while (mant >= 2.0) mant /= 2.0, exponent++;
  while (mant < 1.0 && exponent > -(bias - 1)) mant *= 2.0, exponent--;

  if (mant < 1.0) exponent = -bias; /* subnormal value */
  else mant = mant - 1.0; /* remove leading 1 */
  exponent += bias;
  mant *= POW2(mantbits);

  if (mantbits == 52) {
    rv.hi = (mpack_uint32_t)(mant / POW2(32));
    rv.lo = (mpack_uint32_t)(mant - rv.hi * POW2(32));
    rv.hi |= ((mpack_uint32_t)exponent << 20) | (sign << 31);
  } else if (mantbits == 23) {
    rv.hi = 0;
    rv.lo = (mpack_uint32_t)mant;
    rv.lo |= ((mpack_uint32_t)exponent << 23) | (sign << 31);
  }

end:
  return rv;
}

static int mpack_is_be(void)
{
  union {
    mpack_uint32_t i;
    char c[sizeof(mpack_uint32_t)];
  } test;

  test.i = 1;
  return test.c[0] == 0;
}

/* this simplified version of `fmod` that returns the remainder of double
 * division by 0xffffffff, which is enough for our purposes */
static double mpack_fmod_pow2_32(double a)
{
  return a - ((double)(mpack_uint32_t)(a / POW2(32)) * POW2(32));
}
