/// @file encode.c
///
/// File containing functions for encoding and decoding VimL values.
///
/// Split out from eval.c.

#include <msgpack.h>
#include <inttypes.h>
#include <stddef.h>
#include <assert.h>
#include <math.h>

#include "nvim/eval/encode.h"
#include "nvim/buffer_defs.h"  // vimconv_T
#include "nvim/eval.h"
#include "nvim/eval_defs.h"
#include "nvim/garray.h"
#include "nvim/mbyte.h"
#include "nvim/message.h"
#include "nvim/memory.h"
#include "nvim/charset.h"  // vim_isprintc()
#include "nvim/macros.h"
#include "nvim/ascii.h"
#include "nvim/vim.h"  // For _()
#include "nvim/lib/kvec.h"
#include "nvim/eval/typval_encode.h"

#define ga_concat(a, b) ga_concat(a, (char_u *)b)
#define utf_ptr2char(b) utf_ptr2char((char_u *)b)
#define utf_ptr2len(b) ((size_t)utf_ptr2len((char_u *)b))
#define utf_char2len(b) ((size_t)utf_char2len(b))
#define string_convert(a, b, c) \
      ((char *)string_convert((vimconv_T *)a, (char_u *)b, c))
#define convert_setup(vcp, from, to) \
    (convert_setup(vcp, (char_u *)from, (char_u *)to))

const char *const encode_special_var_names[] = {
  [kSpecialVarNull] = "null",
  [kSpecialVarTrue] = "true",
  [kSpecialVarFalse] = "false",
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/encode.c.generated.h"
#endif

/// Msgpack callback for writing to readfile()-style list
int encode_list_write(void *data, const char *buf, size_t len)
{
  if (len == 0) {
    return 0;
  }
  list_T *const list = (list_T *) data;
  const char *const end = buf + len;
  const char *line_end = buf;
  listitem_T *li = list->lv_last;

  // Continue the last list element
  if (li != NULL) {
    line_end = xmemscan(buf, NL, len);
    if (line_end != buf) {
      const size_t line_length = (size_t)(line_end - buf);
      char *str = (char *)li->li_tv.vval.v_string;
      const size_t li_len = (str == NULL ? 0 : strlen(str));
      li->li_tv.vval.v_string = xrealloc(str, li_len + line_length + 1);
      str = (char *)li->li_tv.vval.v_string + li_len;
      memcpy(str, buf, line_length);
      str[line_length] = 0;
      memchrsub(str, NUL, NL, line_length);
    }
    line_end++;
  }

  while (line_end < end) {
    const char *line_start = line_end;
    line_end = xmemscan(line_start, NL, (size_t) (end - line_start));
    char *str = NULL;
    if (line_end != line_start) {
      const size_t line_length = (size_t)(line_end - line_start);
      str = xmemdupz(line_start, line_length);
      memchrsub(str, NUL, NL, line_length);
    }
    list_append_allocated_string(list, str);
    line_end++;
  }
  if (line_end == end) {
    list_append_allocated_string(list, NULL);
  }
  return 0;
}

/// Abort conversion to string after a recursion error.
static bool did_echo_string_emsg = false;

/// Show a error message when converting to msgpack value
///
/// @param[in]  msg  Error message to dump. Must contain exactly two %s that
///                  will be replaced with what was being dumped: first with
///                  something like “F” or “function argument”, second with path
///                  to the failed value.
/// @param[in]  mpstack  Path to the failed value.
/// @param[in]  objname  Dumped object name.
///
/// @return FAIL.
static int conv_error(const char *const msg, const MPConvStack *const mpstack,
                      const char *const objname)
  FUNC_ATTR_NONNULL_ALL
{
  garray_T msg_ga;
  ga_init(&msg_ga, (int)sizeof(char), 80);
  char *const key_msg = _("key %s");
  char *const key_pair_msg = _("key %s at index %i from special map");
  char *const idx_msg = _("index %i");
  for (size_t i = 0; i < kv_size(*mpstack); i++) {
    if (i != 0) {
      ga_concat(&msg_ga, ", ");
    }
    MPConvStackVal v = kv_A(*mpstack, i);
    switch (v.type) {
      case kMPConvDict: {
        typval_T key_tv = {
            .v_type = VAR_STRING,
            .vval = { .v_string = (v.data.d.hi == NULL
                                   ? v.data.d.dict->dv_hashtab.ht_array
                                   : (v.data.d.hi - 1))->hi_key },
        };
        char *const key = encode_tv2string(&key_tv, NULL);
        vim_snprintf((char *) IObuff, IOSIZE, key_msg, key);
        xfree(key);
        ga_concat(&msg_ga, IObuff);
        break;
      }
      case kMPConvPairs:
      case kMPConvList: {
        int idx = 0;
        const listitem_T *li;
        for (li = v.data.l.list->lv_first;
             li != NULL && li->li_next != v.data.l.li;
             li = li->li_next) {
          idx++;
        }
        if (v.type == kMPConvList
            || li == NULL
            || (li->li_tv.v_type != VAR_LIST
                && li->li_tv.vval.v_list->lv_len <= 0)) {
          vim_snprintf((char *) IObuff, IOSIZE, idx_msg, idx);
          ga_concat(&msg_ga, IObuff);
        } else {
          typval_T key_tv = li->li_tv.vval.v_list->lv_first->li_tv;
          char *const key = encode_tv2echo(&key_tv, NULL);
          vim_snprintf((char *) IObuff, IOSIZE, key_pair_msg, key, idx);
          xfree(key);
          ga_concat(&msg_ga, IObuff);
        }
        break;
      }
    }
  }
  EMSG3(msg, objname, (kv_size(*mpstack) == 0
                       ? _("itself")
                       : (char *) msg_ga.ga_data));
  ga_clear(&msg_ga);
  return FAIL;
}

/// Convert readfile()-style list to a char * buffer with length
///
/// @param[in]  list  Converted list.
/// @param[out]  ret_len  Resulting buffer length.
/// @param[out]  ret_buf  Allocated buffer with the result or NULL if ret_len is
///                       zero.
///
/// @return true in case of success, false in case of failure.
bool encode_vim_list_to_buf(const list_T *const list, size_t *const ret_len,
                            char **const ret_buf)
  FUNC_ATTR_NONNULL_ARG(2, 3) FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t len = 0;
  if (list != NULL) {
    for (const listitem_T *li = list->lv_first;
         li != NULL;
         li = li->li_next) {
      if (li->li_tv.v_type != VAR_STRING) {
        return false;
      }
      len++;
      if (li->li_tv.vval.v_string != 0) {
        len += STRLEN(li->li_tv.vval.v_string);
      }
    }
    if (len) {
      len--;
    }
  }
  *ret_len = len;
  if (len == 0) {
    *ret_buf = NULL;
    return true;
  }
  ListReaderState lrstate = encode_init_lrstate(list);
  char *const buf = xmalloc(len);
  size_t read_bytes;
  if (encode_read_from_list(&lrstate, buf, len, &read_bytes) != OK) {
    assert(false);
  }
  assert(len == read_bytes);
  *ret_buf = buf;
  return true;
}

/// Read bytes from list
///
/// @param[in,out]  state  Structure describing position in list from which
///                        reading should start. Is updated to reflect position
///                        at which reading ended.
/// @param[out]  buf  Buffer to write to.
/// @param[in]  nbuf  Buffer length.
/// @param[out]  read_bytes  Is set to amount of bytes read.
///
/// @return OK when reading was finished, FAIL in case of error (i.e. list item
///         was not a string), NOTDONE if reading was successfull, but there are
///         more bytes to read.
int encode_read_from_list(ListReaderState *const state, char *const buf,
                          const size_t nbuf, size_t *const read_bytes)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  char *const buf_end = buf + nbuf;
  char *p = buf;
  while (p < buf_end) {
    for (size_t i = state->offset; i < state->li_length && p < buf_end; i++) {
      const char ch = (char) state->li->li_tv.vval.v_string[state->offset++];
      *p++ = (char) ((char) ch == (char) NL ? (char) NUL : (char) ch);
    }
    if (p < buf_end) {
      state->li = state->li->li_next;
      if (state->li == NULL) {
        *read_bytes = (size_t) (p - buf);
        return OK;
      }
      *p++ = NL;
      if (state->li->li_tv.v_type != VAR_STRING) {
        *read_bytes = (size_t) (p - buf);
        return FAIL;
      }
      state->offset = 0;
      state->li_length = (state->li->li_tv.vval.v_string == NULL
                          ? 0
                          : STRLEN(state->li->li_tv.vval.v_string));
    }
  }
  *read_bytes = nbuf;
  return (state->offset < state->li_length || state->li->li_next != NULL
          ? NOTDONE
          : OK);
}

#define TYPVAL_ENCODE_CONV_STRING(buf, len) \
    do { \
      const char *const buf_ = (const char *) buf; \
      if (buf == NULL) { \
        ga_concat(gap, "''"); \
      } else { \
        const size_t len_ = (len); \
        ga_grow(gap, (int) (2 + len_ + memcnt(buf_, '\'', len_))); \
        ga_append(gap, '\''); \
        for (size_t i = 0; i < len_; i++) { \
          if (buf_[i] == '\'') { \
            ga_append(gap, '\''); \
          } \
          ga_append(gap, buf_[i]); \
        } \
        ga_append(gap, '\''); \
      } \
    } while (0)

#define TYPVAL_ENCODE_CONV_STR_STRING(buf, len) \
    TYPVAL_ENCODE_CONV_STRING(buf, len)

#define TYPVAL_ENCODE_CONV_EXT_STRING(buf, len, type)

#define TYPVAL_ENCODE_CONV_NUMBER(num) \
    do { \
      char numbuf[NUMBUFLEN]; \
      vim_snprintf(numbuf, ARRAY_SIZE(numbuf), "%" PRId64, (int64_t) (num)); \
      ga_concat(gap, numbuf); \
    } while (0)

#define TYPVAL_ENCODE_CONV_FLOAT(flt) \
    do { \
      const float_T flt_ = (flt); \
      switch (fpclassify(flt_)) { \
        case FP_NAN: { \
          ga_concat(gap, (char_u *) "str2float('nan')"); \
          break; \
        } \
        case FP_INFINITE: { \
          if (flt_ < 0) { \
            ga_append(gap, '-'); \
          } \
          ga_concat(gap, (char_u *) "str2float('inf')"); \
          break; \
        } \
        default: { \
          char numbuf[NUMBUFLEN]; \
          vim_snprintf(numbuf, ARRAY_SIZE(numbuf), "%g", flt_); \
          ga_concat(gap, (char_u *) numbuf); \
        } \
      } \
    } while (0)

#define TYPVAL_ENCODE_CONV_FUNC(fun) \
    do { \
      ga_concat(gap, "function("); \
      TYPVAL_ENCODE_CONV_STRING(fun, STRLEN(fun)); \
      ga_append(gap, ')'); \
    } while (0)

#define TYPVAL_ENCODE_CONV_EMPTY_LIST() \
    ga_concat(gap, "[]")

#define TYPVAL_ENCODE_CONV_LIST_START(len) \
    ga_append(gap, '[')

#define TYPVAL_ENCODE_CONV_EMPTY_DICT() \
    ga_concat(gap, "{}")

#define TYPVAL_ENCODE_CONV_NIL() \
    ga_concat(gap, "v:null")

#define TYPVAL_ENCODE_CONV_BOOL(num) \
    ga_concat(gap, ((num)? "v:true": "v:false"))

#define TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER(num)

#define TYPVAL_ENCODE_CONV_DICT_START(len) \
    ga_append(gap, '{')

#define TYPVAL_ENCODE_CONV_DICT_END() \
    ga_append(gap, '}')

#define TYPVAL_ENCODE_CONV_DICT_AFTER_KEY() \
    ga_concat(gap, ": ")

#define TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS() \
    ga_concat(gap, ", ")

#define TYPVAL_ENCODE_CONV_SPECIAL_DICT_KEY_CHECK(label, kv_pair)

#define TYPVAL_ENCODE_CONV_LIST_END() \
    ga_append(gap, ']')

#define TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS() \
    TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS()

#define TYPVAL_ENCODE_CONV_RECURSE(val, conv_type) \
    do { \
      if (!did_echo_string_emsg) { \
        /* Only give this message once for a recursive call to avoid */ \
        /* flooding the user with errors. */ \
        did_echo_string_emsg = true; \
        EMSG(_("E724: unable to correctly dump variable " \
               "with self-referencing container")); \
      } \
      char ebuf[NUMBUFLEN + 7]; \
      size_t backref = 0; \
      for (; backref < kv_size(*mpstack); backref++) { \
        const MPConvStackVal mpval = kv_A(*mpstack, backref); \
        if (mpval.type == conv_type) { \
          if (conv_type == kMPConvDict) { \
            if ((void *) mpval.data.d.dict == (void *) (val)) { \
              break; \
            } \
          } else if (conv_type == kMPConvList) { \
            if ((void *) mpval.data.l.list == (void *) (val)) { \
              break; \
            } \
          } \
        } \
      } \
      vim_snprintf(ebuf, ARRAY_SIZE(ebuf), "{E724@%zu}", backref); \
      ga_concat(gap, &ebuf[0]); \
      return OK; \
    } while (0)

#define TYPVAL_ENCODE_ALLOW_SPECIALS false

TYPVAL_ENCODE_DEFINE_CONV_FUNCTIONS(static, string, garray_T *const, gap)

#undef TYPVAL_ENCODE_CONV_RECURSE
#define TYPVAL_ENCODE_CONV_RECURSE(val, conv_type) \
    do { \
      char ebuf[NUMBUFLEN + 7]; \
      size_t backref = 0; \
      for (; backref < kv_size(*mpstack); backref++) { \
        const MPConvStackVal mpval = kv_A(*mpstack, backref); \
        if (mpval.type == conv_type) { \
          if (conv_type == kMPConvDict) { \
            if ((void *) mpval.data.d.dict == (void *) val) { \
              break; \
            } \
          } else if (conv_type == kMPConvList) { \
            if ((void *) mpval.data.l.list == (void *) val) { \
              break; \
            } \
          } \
        } \
      } \
      if (conv_type == kMPConvDict) { \
        vim_snprintf(ebuf, ARRAY_SIZE(ebuf), "{...@%zu}", backref); \
      } else { \
        vim_snprintf(ebuf, ARRAY_SIZE(ebuf), "[...@%zu]", backref); \
      } \
      ga_concat(gap, &ebuf[0]); \
      return OK; \
    } while (0)

TYPVAL_ENCODE_DEFINE_CONV_FUNCTIONS(, echo, garray_T *const, gap)

#undef TYPVAL_ENCODE_CONV_RECURSE
#define TYPVAL_ENCODE_CONV_RECURSE(val, conv_type) \
    do { \
      if (!did_echo_string_emsg) { \
        /* Only give this message once for a recursive call to avoid */ \
        /* flooding the user with errors. */ \
        did_echo_string_emsg = true; \
        EMSG(_("E724: unable to correctly dump variable " \
               "with self-referencing container")); \
      } \
      return OK; \
    } while (0)

#undef TYPVAL_ENCODE_ALLOW_SPECIALS
#define TYPVAL_ENCODE_ALLOW_SPECIALS true

#undef TYPVAL_ENCODE_CONV_NIL
#define TYPVAL_ENCODE_CONV_NIL() \
      ga_concat(gap, "null")

#undef TYPVAL_ENCODE_CONV_BOOL
#define TYPVAL_ENCODE_CONV_BOOL(num) \
      ga_concat(gap, ((num)? "true": "false"))

#undef TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER
#define TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER(num) \
      do { \
        char numbuf[NUMBUFLEN]; \
        vim_snprintf(numbuf, ARRAY_SIZE(numbuf), "%" PRIu64, (num)); \
        ga_concat(gap, numbuf); \
      } while (0)

#undef TYPVAL_ENCODE_CONV_FLOAT
#define TYPVAL_ENCODE_CONV_FLOAT(flt) \
    do { \
      const float_T flt_ = (flt); \
      switch (fpclassify(flt_)) { \
        case FP_NAN: { \
          EMSG(_("E474: Unable to represent NaN value in JSON")); \
          return FAIL; \
        } \
        case FP_INFINITE: { \
          EMSG(_("E474: Unable to represent infinity in JSON")); \
          return FAIL; \
        } \
        default: { \
          char numbuf[NUMBUFLEN]; \
          vim_snprintf(numbuf, ARRAY_SIZE(numbuf), "%g", flt_); \
          ga_concat(gap, (char_u *) numbuf); \
          break; \
        } \
      } \
    } while (0)

/// Last used p_enc value
///
/// Generic pointer: it is not used as a string, only pointer comparisons are
/// performed. Must not be freed.
static const void *last_p_enc = NULL;

/// Conversion setup for converting from last_p_enc to UTF-8
static vimconv_T p_enc_conv = {
  .vc_type = CONV_NONE,
};

/// Escape sequences used in JSON
static const char escapes[][3] = {
  [BS] = "\\b",
  [TAB] = "\\t",
  [NL] = "\\n",
  [CAR] = "\\r",
  ['"'] = "\\\"",
  ['\\'] = "\\\\",
  [FF] = "\\f",
};

static const char xdigits[] = "0123456789ABCDEF";

/// Convert given string to JSON string
///
/// @param[out]  gap  Garray where result will be saved.
/// @param[in]  buf  Converted string.
/// @param[in]  len  Converted string length.
///
/// @return OK in case of success, FAIL otherwise.
static inline int convert_to_json_string(garray_T *const gap,
                                         const char *const buf,
                                         const size_t len)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_ALWAYS_INLINE
{
  const char *utf_buf = buf;
  if (utf_buf == NULL) {
    ga_concat(gap, "\"\"");
  } else {
    size_t utf_len = len;
    char *tofree = NULL;
    if (last_p_enc != (const void *) p_enc) {
      p_enc_conv.vc_type = CONV_NONE;
      convert_setup(&p_enc_conv, p_enc, "utf-8");
      p_enc_conv.vc_fail = true;
      last_p_enc = p_enc;
    }
    if (p_enc_conv.vc_type != CONV_NONE) {
      tofree = string_convert(&p_enc_conv, buf, &utf_len);
      if (tofree == NULL) {
        emsgf(_("E474: Failed to convert string \"%.*s\" to UTF-8"),
              utf_len, utf_buf);
        return FAIL;
      }
      utf_buf = tofree;
    }
    size_t str_len = 0;
    // Encode character as \u0000 if
    // 1. It is an ASCII control character (0x0 .. 0x1F, 0x7F).
    // 2. &encoding is not UTF-8 and code point is above 0x7F.
    // 3. &encoding is UTF-8 and code point is not printable according to
    //    utf_printable().
    // This is done to make it possible to :echo values when &encoding is not
    // UTF-8.
#define ENCODE_RAW(p_enc_conv, ch) \
    (ch >= 0x20 && (p_enc_conv.vc_type == CONV_NONE \
                    ? utf_printable(ch) \
                    : ch < 0x7F))
    for (size_t i = 0; i < utf_len;) {
      const int ch = utf_ptr2char(utf_buf + i);
      const size_t shift = (ch == 0? 1: utf_ptr2len(utf_buf + i));
      assert(shift > 0);
      i += shift;
      switch (ch) {
        case BS:
        case TAB:
        case NL:
        case FF:
        case CAR:
        case '"':
        case '\\': {
          str_len += 2;
          break;
        }
        default: {
          if (ch > 0x7F && shift == 1) {
            emsgf(_("E474: String \"%.*s\" contains byte that does not start "
                    "any UTF-8 character"),
                  utf_len - (i - shift), utf_buf + i - shift);
            xfree(tofree);
            return FAIL;
          } else if ((SURROGATE_HI_START <= ch && ch <= SURROGATE_HI_END)
                     || (SURROGATE_LO_START <= ch && ch <= SURROGATE_LO_END)) {
            emsgf(_("E474: UTF-8 string contains code point which belongs "
                    "to a surrogate pair: %.*s"),
                  utf_len - (i - shift), utf_buf + i - shift);
            xfree(tofree);
            return FAIL;
          } else if (ENCODE_RAW(p_enc_conv, ch)) {
            str_len += shift;
          } else {
            str_len += ((sizeof("\\u1234") - 1)
                        * (size_t) (1 + (ch >= SURROGATE_FIRST_CHAR)));
          }
          break;
        }
      }
    }
    ga_append(gap, '"');
    ga_grow(gap, (int) str_len);
    for (size_t i = 0; i < utf_len;) {
      const int ch = utf_ptr2char(utf_buf + i);
      const size_t shift = (ch == 0? 1: utf_char2len(ch));
      assert(shift > 0);
      // Is false on invalid unicode, but this should already be handled.
      assert(ch == 0 || shift == utf_ptr2len(utf_buf + i));
      switch (ch) {
        case BS:
        case TAB:
        case NL:
        case FF:
        case CAR:
        case '"':
        case '\\': {
          ga_concat_len(gap, escapes[ch], 2);
          break;
        }
        default: {
          if (ENCODE_RAW(p_enc_conv, ch)) {
            ga_concat_len(gap, utf_buf + i, shift);
          } else if (ch < SURROGATE_FIRST_CHAR) {
            ga_concat_len(gap, ((const char[]) {
                '\\', 'u',
                xdigits[(ch >> (4 * 3)) & 0xF],
                xdigits[(ch >> (4 * 2)) & 0xF],
                xdigits[(ch >> (4 * 1)) & 0xF],
                xdigits[(ch >> (4 * 0)) & 0xF],
            }), sizeof("\\u1234") - 1);
          } else {
            const int tmp = ch - SURROGATE_FIRST_CHAR;
            const int hi = SURROGATE_HI_START + ((tmp >> 10) & ((1 << 10) - 1));
            const int lo = SURROGATE_LO_END + ((tmp >>  0) & ((1 << 10) - 1));
            ga_concat_len(gap, ((const char[]) {
                '\\', 'u',
                xdigits[(hi >> (4 * 3)) & 0xF],
                xdigits[(hi >> (4 * 2)) & 0xF],
                xdigits[(hi >> (4 * 1)) & 0xF],
                xdigits[(hi >> (4 * 0)) & 0xF],
                '\\', 'u',
                xdigits[(lo >> (4 * 3)) & 0xF],
                xdigits[(lo >> (4 * 2)) & 0xF],
                xdigits[(lo >> (4 * 1)) & 0xF],
                xdigits[(lo >> (4 * 0)) & 0xF],
            }), (sizeof("\\u1234") - 1) * 2);
          }
          break;
        }
      }
      i += shift;
    }
    ga_append(gap, '"');
    xfree(tofree);
  }
  return OK;
}

#undef TYPVAL_ENCODE_CONV_STRING
#define TYPVAL_ENCODE_CONV_STRING(buf, len) \
    do { \
      if (convert_to_json_string(gap, (const char *) (buf), (len)) != OK) { \
        return FAIL; \
      } \
    } while (0)

#undef TYPVAL_ENCODE_CONV_EXT_STRING
#define TYPVAL_ENCODE_CONV_EXT_STRING(buf, len, type) \
    do { \
      xfree(buf); \
      EMSG(_("E474: Unable to convert EXT string to JSON")); \
      return FAIL; \
    } while (0)

#undef TYPVAL_ENCODE_CONV_FUNC
#define TYPVAL_ENCODE_CONV_FUNC(fun) \
    return conv_error(_("E474: Error while dumping %s, %s: " \
                        "attempt to dump function reference"), \
                      mpstack, objname)

/// Check whether given key can be used in json_encode()
///
/// @param[in]  tv  Key to check.
static inline bool check_json_key(const typval_T *const tv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_PURE
  FUNC_ATTR_ALWAYS_INLINE
{
  if (tv->v_type == VAR_STRING) {
    return true;
  }
  if (tv->v_type != VAR_DICT) {
    return false;
  }
  const dict_T *const spdict = tv->vval.v_dict;
  if (spdict->dv_hashtab.ht_used != 2) {
    return false;
  }
  const dictitem_T *type_di;
  const dictitem_T *val_di;
  if ((type_di = dict_find((dict_T *) spdict, (char_u *) "_TYPE", -1)) == NULL
      || type_di->di_tv.v_type != VAR_LIST
      || (type_di->di_tv.vval.v_list != eval_msgpack_type_lists[kMPString]
          && type_di->di_tv.vval.v_list != eval_msgpack_type_lists[kMPBinary])
      || (val_di = dict_find((dict_T *) spdict, (char_u *) "_VAL", -1)) == NULL
      || val_di->di_tv.v_type != VAR_LIST) {
    return false;
  }
  if (val_di->di_tv.vval.v_list == NULL) {
    return true;
  }
  for (const listitem_T *li = val_di->di_tv.vval.v_list->lv_first;
       li != NULL; li = li->li_next) {
    if (li->li_tv.v_type != VAR_STRING) {
      return false;
    }
  }
  return true;
}

#undef TYPVAL_ENCODE_CONV_SPECIAL_DICT_KEY_CHECK
#define TYPVAL_ENCODE_CONV_SPECIAL_DICT_KEY_CHECK(label, kv_pair) \
    do { \
      if (!check_json_key(&kv_pair->lv_first->li_tv)) { \
        EMSG(_("E474: Invalid key in special dictionary")); \
        goto label; \
      } \
    } while (0)

TYPVAL_ENCODE_DEFINE_CONV_FUNCTIONS(static, json, garray_T *const, gap)

#undef TYPVAL_ENCODE_CONV_STRING
#undef TYPVAL_ENCODE_CONV_STR_STRING
#undef TYPVAL_ENCODE_CONV_EXT_STRING
#undef TYPVAL_ENCODE_CONV_NUMBER
#undef TYPVAL_ENCODE_CONV_FLOAT
#undef TYPVAL_ENCODE_CONV_FUNC
#undef TYPVAL_ENCODE_CONV_EMPTY_LIST
#undef TYPVAL_ENCODE_CONV_LIST_START
#undef TYPVAL_ENCODE_CONV_EMPTY_DICT
#undef TYPVAL_ENCODE_CONV_NIL
#undef TYPVAL_ENCODE_CONV_BOOL
#undef TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER
#undef TYPVAL_ENCODE_CONV_DICT_START
#undef TYPVAL_ENCODE_CONV_DICT_END
#undef TYPVAL_ENCODE_CONV_DICT_AFTER_KEY
#undef TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_CONV_SPECIAL_DICT_KEY_CHECK
#undef TYPVAL_ENCODE_CONV_LIST_END
#undef TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_CONV_RECURSE
#undef TYPVAL_ENCODE_ALLOW_SPECIALS

/// Return a string with the string representation of a variable.
/// Puts quotes around strings, so that they can be parsed back by eval().
///
/// @param[in]  tv  typval_T to convert.
/// @param[out]  len  Location where length of the result will be saved.
///
/// @return String representation of the variable or NULL.
char *encode_tv2string(typval_T *tv, size_t *len)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_MALLOC
{
  garray_T ga;
  ga_init(&ga, (int)sizeof(char), 80);
  encode_vim_to_string(&ga, tv, "encode_tv2string() argument");
  did_echo_string_emsg = false;
  if (len != NULL) {
    *len = (size_t) ga.ga_len;
  }
  ga_append(&ga, '\0');
  return (char *) ga.ga_data;
}

/// Return a string with the string representation of a variable.
/// Does not put quotes around strings, as ":echo" displays values.
///
/// @param[in]  tv  typval_T to convert.
/// @param[out]  len  Location where length of the result will be saved.
///
/// @return String representation of the variable or NULL.
char *encode_tv2echo(typval_T *tv, size_t *len)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_MALLOC
{
  garray_T ga;
  ga_init(&ga, (int)sizeof(char), 80);
  if (tv->v_type == VAR_STRING || tv->v_type == VAR_FUNC) {
    if (tv->vval.v_string != NULL) {
      ga_concat(&ga, tv->vval.v_string);
    }
  } else {
    encode_vim_to_echo(&ga, tv, ":echo argument");
  }
  if (len != NULL) {
    *len = (size_t) ga.ga_len;
  }
  ga_append(&ga, '\0');
  return (char *) ga.ga_data;
}

/// Return a string with the string representation of a variable.
/// Puts quotes around strings, so that they can be parsed back by eval().
///
/// @param[in]  tv  typval_T to convert.
/// @param[out]  len  Location where length of the result will be saved.
///
/// @return String representation of the variable or NULL.
char *encode_tv2json(typval_T *tv, size_t *len)
  FUNC_ATTR_NONNULL_ARG(1) FUNC_ATTR_MALLOC
{
  garray_T ga;
  ga_init(&ga, (int)sizeof(char), 80);
  encode_vim_to_json(&ga, tv, "encode_tv2json() argument");
  did_echo_string_emsg = false;
  if (len != NULL) {
    *len = (size_t) ga.ga_len;
  }
  ga_append(&ga, '\0');
  return (char *) ga.ga_data;
}

#define TYPVAL_ENCODE_CONV_STRING(buf, len) \
    do { \
      if (buf == NULL) { \
        msgpack_pack_bin(packer, 0); \
      } else { \
        const size_t len_ = (len); \
        msgpack_pack_bin(packer, len_); \
        msgpack_pack_bin_body(packer, buf, len_); \
      } \
    } while (0)

#define TYPVAL_ENCODE_CONV_STR_STRING(buf, len) \
    do { \
      if (buf == NULL) { \
        msgpack_pack_str(packer, 0); \
      } else { \
        const size_t len_ = (len); \
        msgpack_pack_str(packer, len_); \
        msgpack_pack_str_body(packer, buf, len_); \
      } \
    } while (0)

#define TYPVAL_ENCODE_CONV_EXT_STRING(buf, len, type) \
    do { \
      if (buf == NULL) { \
        msgpack_pack_ext(packer, 0, (int8_t) type); \
      } else { \
        const size_t len_ = (len); \
        msgpack_pack_ext(packer, len_, (int8_t) type); \
        msgpack_pack_ext_body(packer, buf, len_); \
      } \
    } while (0)

#define TYPVAL_ENCODE_CONV_NUMBER(num) \
    msgpack_pack_int64(packer, (int64_t) (num))

#define TYPVAL_ENCODE_CONV_FLOAT(flt) \
    msgpack_pack_double(packer, (double) (flt))

#define TYPVAL_ENCODE_CONV_FUNC(fun) \
    return conv_error(_("E951: Error while dumping %s, %s: " \
                        "attempt to dump function reference"), \
                      mpstack, objname)

#define TYPVAL_ENCODE_CONV_EMPTY_LIST() \
    msgpack_pack_array(packer, 0)

#define TYPVAL_ENCODE_CONV_LIST_START(len) \
    msgpack_pack_array(packer, (size_t) (len))

#define TYPVAL_ENCODE_CONV_EMPTY_DICT() \
    msgpack_pack_map(packer, 0)

#define TYPVAL_ENCODE_CONV_NIL() \
    msgpack_pack_nil(packer)

#define TYPVAL_ENCODE_CONV_BOOL(num) \
    do { \
      if ((num)) { \
        msgpack_pack_true(packer); \
      } else { \
        msgpack_pack_false(packer); \
      } \
    } while (0)

#define TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER(num) \
    msgpack_pack_uint64(packer, (num))

#define TYPVAL_ENCODE_CONV_DICT_START(len) \
    msgpack_pack_map(packer, (size_t) (len))

#define TYPVAL_ENCODE_CONV_DICT_END()

#define TYPVAL_ENCODE_CONV_DICT_AFTER_KEY()

#define TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS()

#define TYPVAL_ENCODE_CONV_SPECIAL_DICT_KEY_CHECK(label, kv_pair)

#define TYPVAL_ENCODE_CONV_LIST_END()

#define TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS()

#define TYPVAL_ENCODE_CONV_RECURSE(val, conv_type) \
    return conv_error(_("E952: Unable to dump %s: " \
                        "container references itself in %s"), \
                      mpstack, objname)

#define TYPVAL_ENCODE_ALLOW_SPECIALS true

TYPVAL_ENCODE_DEFINE_CONV_FUNCTIONS(, msgpack, msgpack_packer *const, packer)

#undef TYPVAL_ENCODE_CONV_STRING
#undef TYPVAL_ENCODE_CONV_STR_STRING
#undef TYPVAL_ENCODE_CONV_EXT_STRING
#undef TYPVAL_ENCODE_CONV_NUMBER
#undef TYPVAL_ENCODE_CONV_FLOAT
#undef TYPVAL_ENCODE_CONV_FUNC
#undef TYPVAL_ENCODE_CONV_EMPTY_LIST
#undef TYPVAL_ENCODE_CONV_LIST_START
#undef TYPVAL_ENCODE_CONV_EMPTY_DICT
#undef TYPVAL_ENCODE_CONV_NIL
#undef TYPVAL_ENCODE_CONV_BOOL
#undef TYPVAL_ENCODE_CONV_UNSIGNED_NUMBER
#undef TYPVAL_ENCODE_CONV_DICT_START
#undef TYPVAL_ENCODE_CONV_DICT_END
#undef TYPVAL_ENCODE_CONV_DICT_AFTER_KEY
#undef TYPVAL_ENCODE_CONV_DICT_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_CONV_SPECIAL_DICT_KEY_CHECK
#undef TYPVAL_ENCODE_CONV_LIST_END
#undef TYPVAL_ENCODE_CONV_LIST_BETWEEN_ITEMS
#undef TYPVAL_ENCODE_CONV_RECURSE
#undef TYPVAL_ENCODE_ALLOW_SPECIALS
