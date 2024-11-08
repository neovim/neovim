#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "mpack/object.h"
#include "nvim/ascii_defs.h"
#include "nvim/charset.h"
#include "nvim/eval.h"
#include "nvim/eval/decode.h"
#include "nvim/eval/encode.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval_defs.h"
#include "nvim/garray.h"
#include "nvim/gettext_defs.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"

/// Helper structure for container_struct
typedef struct {
  size_t stack_index;   ///< Index of current container in stack.
  list_T *special_val;  ///< _VAL key contents for special maps.
                        ///< When container is not a special dictionary it is
                        ///< NULL.
  const char *s;        ///< Location where container starts.
  typval_T container;   ///< Container. Either VAR_LIST, VAR_DICT or VAR_LIST
                        ///< which is _VAL from special dictionary.
} ContainerStackItem;

/// Helper structure for values struct
typedef struct {
  bool is_special_string;  ///< Indicates that current value is a special
                           ///< dictionary with string.
  bool didcomma;           ///< True if previous token was comma.
  bool didcolon;           ///< True if previous token was colon.
  typval_T val;            ///< Actual value.
} ValuesStackItem;

/// Vector containing values not yet saved in any container
typedef kvec_t(ValuesStackItem) ValuesStack;

/// Vector containing containers, each next container is located inside previous
typedef kvec_t(ContainerStackItem) ContainerStack;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/decode.c.generated.h"
#endif

/// Create special dictionary
///
/// @param[out]  rettv  Location where created dictionary will be saved.
/// @param[in]  type  Type of the dictionary.
/// @param[in]  val  Value associated with the _VAL key.
static inline void create_special_dict(typval_T *const rettv, const MessagePackType type,
                                       typval_T val)
  FUNC_ATTR_NONNULL_ALL
{
  dict_T *const dict = tv_dict_alloc();
  dictitem_T *const type_di = tv_dict_item_alloc_len(S_LEN("_TYPE"));
  type_di->di_tv.v_type = VAR_LIST;
  type_di->di_tv.v_lock = VAR_UNLOCKED;
  type_di->di_tv.vval.v_list = (list_T *)eval_msgpack_type_lists[type];
  tv_list_ref(type_di->di_tv.vval.v_list);
  tv_dict_add(dict, type_di);
  dictitem_T *const val_di = tv_dict_item_alloc_len(S_LEN("_VAL"));
  val_di->di_tv = val;
  tv_dict_add(dict, val_di);
  dict->dv_refcount++;
  *rettv = (typval_T) {
    .v_type = VAR_DICT,
    .v_lock = VAR_UNLOCKED,
    .vval = { .v_dict = dict },
  };
}

#define DICT_LEN(dict) (dict)->dv_hashtab.ht_used

/// Helper function used for working with stack vectors used by JSON decoder
///
/// @param[in,out]  obj  New object. Will either be put into the stack (and,
///                      probably, also inside container) or freed.
/// @param[out]  stack  Object stack.
/// @param[out]  container_stack  Container objects stack.
/// @param[in,out]  pp  Position in string which is currently being parsed. Used
///                     for error reporting and is also set when decoding is
///                     restarted due to the necessity of converting regular
///                     dictionary to a special map.
/// @param[out]  next_map_special  Is set to true when dictionary needs to be
///                                converted to a special map, otherwise not
///                                touched. Indicates that decoding has been
///                                restarted.
/// @param[out]  didcomma  True if previous token was comma. Is set to recorded
///                        value when decoder is restarted, otherwise unused.
/// @param[out]  didcolon  True if previous token was colon. Is set to recorded
///                        value when decoder is restarted, otherwise unused.
///
/// @return OK in case of success, FAIL in case of error.
static inline int json_decoder_pop(ValuesStackItem obj, ValuesStack *const stack,
                                   ContainerStack *const container_stack, const char **const pp,
                                   bool *const next_map_special, bool *const didcomma,
                                   bool *const didcolon)
  FUNC_ATTR_NONNULL_ALL
{
  if (kv_size(*container_stack) == 0) {
    kv_push(*stack, obj);
    return OK;
  }
  ContainerStackItem last_container = kv_last(*container_stack);
  const char *val_location = *pp;
  if (obj.val.v_type == last_container.container.v_type
      // vval.v_list and vval.v_dict should have the same size and offset
      && ((void *)obj.val.vval.v_list
          == (void *)last_container.container.vval.v_list)) {
    (void)kv_pop(*container_stack);
    val_location = last_container.s;
    last_container = kv_last(*container_stack);
  }
  if (last_container.container.v_type == VAR_LIST) {
    if (tv_list_len(last_container.container.vval.v_list) != 0
        && !obj.didcomma) {
      semsg(_("E474: Expected comma before list item: %s"), val_location);
      tv_clear(&obj.val);
      return FAIL;
    }
    assert(last_container.special_val == NULL);
    tv_list_append_owned_tv(last_container.container.vval.v_list, obj.val);
  } else if (last_container.stack_index == kv_size(*stack) - 2) {
    if (!obj.didcolon) {
      semsg(_("E474: Expected colon before dictionary value: %s"),
            val_location);
      tv_clear(&obj.val);
      return FAIL;
    }
    ValuesStackItem key = kv_pop(*stack);
    if (last_container.special_val == NULL) {
      // These cases should have already been handled.
      assert(!(key.is_special_string || key.val.vval.v_string == NULL));
      dictitem_T *const obj_di = tv_dict_item_alloc(key.val.vval.v_string);
      tv_clear(&key.val);
      if (tv_dict_add(last_container.container.vval.v_dict, obj_di)
          == FAIL) {
        abort();
      }
      obj_di->di_tv = obj.val;
    } else {
      list_T *const kv_pair = tv_list_alloc(2);
      tv_list_append_list(last_container.special_val, kv_pair);
      tv_list_append_owned_tv(kv_pair, key.val);
      tv_list_append_owned_tv(kv_pair, obj.val);
    }
  } else {
    // Object with key only
    if (!obj.is_special_string && obj.val.v_type != VAR_STRING) {
      semsg(_("E474: Expected string key: %s"), *pp);
      tv_clear(&obj.val);
      return FAIL;
    } else if (!obj.didcomma
               && (last_container.special_val == NULL
                   && (DICT_LEN(last_container.container.vval.v_dict) != 0))) {
      semsg(_("E474: Expected comma before dictionary key: %s"), val_location);
      tv_clear(&obj.val);
      return FAIL;
    }
    // Handle special dictionaries
    if (last_container.special_val == NULL
        && (obj.is_special_string
            || obj.val.vval.v_string == NULL
            || tv_dict_find(last_container.container.vval.v_dict, obj.val.vval.v_string, -1))) {
      tv_clear(&obj.val);

      // Restart
      (void)kv_pop(*container_stack);
      ValuesStackItem last_container_val =
        kv_A(*stack, last_container.stack_index);
      while (kv_size(*stack) > last_container.stack_index) {
        tv_clear(&(kv_pop(*stack).val));
      }
      *pp = last_container.s;
      *didcomma = last_container_val.didcomma;
      *didcolon = last_container_val.didcolon;
      *next_map_special = true;
      return OK;
    }
    kv_push(*stack, obj);
  }
  return OK;
}

#define LENP(p, e) \
  ((int)((e) - (p))), (p)
#define OBJ(obj_tv, is_sp_string, didcomma_, didcolon_) \
  ((ValuesStackItem) { \
    .is_special_string = (is_sp_string), \
    .val = (obj_tv), \
    .didcomma = (didcomma_), \
    .didcolon = (didcolon_), \
  })

#define POP(obj_tv, is_sp_string) \
  do { \
    if (json_decoder_pop(OBJ(obj_tv, is_sp_string, *didcomma, *didcolon), \
                         stack, container_stack, \
                         &p, next_map_special, didcomma, didcolon) \
        == FAIL) { \
      goto parse_json_string_fail; \
    } \
    if (*next_map_special) { \
      goto parse_json_string_ret; \
    } \
  } while (0)

/// Create a new special dictionary that ought to represent a MAP
///
/// @param[out]  ret_tv  Address where new special dictionary is saved.
/// @param[in]  len  Expected number of items to be populated before list
///                  becomes accessible from Vimscript. It is still valid to
///                  underpopulate a list, value only controls how many elements
///                  will be allocated in advance. @see ListLenSpecials.
///
/// @return [allocated] list which should contain key-value pairs. Return value
///                     may be safely ignored.
list_T *decode_create_map_special_dict(typval_T *const ret_tv, const ptrdiff_t len)
  FUNC_ATTR_NONNULL_ALL
{
  list_T *const list = tv_list_alloc(len);
  tv_list_ref(list);
  create_special_dict(ret_tv, kMPMap, ((typval_T) {
    .v_type = VAR_LIST,
    .v_lock = VAR_UNLOCKED,
    .vval = { .v_list = list },
  }));
  return list;
}

/// Convert char* string to typval_T
///
/// Depending on whether string has (no) NUL bytes, it may use a special
/// dictionary, VAR_BLOB, or decode string to VAR_STRING.
///
/// @param[in]  s  String to decode.
/// @param[in]  len  String length.
/// @param[in]  force_blob  whether string always should be decoded as a blob,
///                         or only when embedded NUL bytes were present
/// @param[in]  s_allocated  If true, then `s` was allocated and can be saved in
///                          a returned structure. If it is not saved there, it
///                          will be freed.
///
/// @return Decoded string.
typval_T decode_string(const char *const s, const size_t len, bool force_blob,
                       const bool s_allocated)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  assert(s != NULL || len == 0);
  const bool use_blob = force_blob || ((s != NULL) && (memchr(s, NUL, len) != NULL));
  if (use_blob) {
    typval_T tv;
    tv.v_lock = VAR_UNLOCKED;
    blob_T *b = tv_blob_alloc_ret(&tv);
    if (s_allocated) {
      b->bv_ga.ga_data = (void *)s;
      b->bv_ga.ga_len = (int)len;
      b->bv_ga.ga_maxlen = (int)len;
    } else {
      ga_concat_len(&b->bv_ga, s, len);
    }
    return tv;
  }
  return (typval_T) {
    .v_type = VAR_STRING,
    .v_lock = VAR_UNLOCKED,
    .vval = { .v_string = ((s == NULL || s_allocated) ? (char *)s : xmemdupz(s, len)) },
  };
}

/// Parse JSON double-quoted string
///
/// @param[in]  buf  Buffer being converted.
/// @param[in]  buf_len  Length of the buffer.
/// @param[in,out]  pp  Pointer to the start of the string. Must point to '"'.
///                     Is advanced to the closing '"'. Also see
///                     json_decoder_pop(), it may set pp to another location
///                     and alter next_map_special, didcomma and didcolon.
/// @param[out]  stack  Object stack.
/// @param[out]  container_stack  Container objects stack.
/// @param[out]  next_map_special  Is set to true when dictionary is converted
///                                to a special map, otherwise not touched.
/// @param[out]  didcomma  True if previous token was comma. Is set to recorded
///                        value when decoder is restarted, otherwise unused.
/// @param[out]  didcolon  True if previous token was colon. Is set to recorded
///                        value when decoder is restarted, otherwise unused.
///
/// @return OK in case of success, FAIL in case of error.
static inline int parse_json_string(const char *const buf, const size_t buf_len,
                                    const char **const pp, ValuesStack *const stack,
                                    ContainerStack *const container_stack,
                                    bool *const next_map_special, bool *const didcomma,
                                    bool *const didcolon)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALWAYS_INLINE
{
  const char *const e = buf + buf_len;
  const char *p = *pp;
  size_t len = 0;
  const char *const s = ++p;
  int ret = OK;
  while (p < e && *p != '"') {
    if (*p == '\\') {
      p++;
      if (p == e) {
        semsg(_("E474: Unfinished escape sequence: %.*s"),
              (int)buf_len, buf);
        goto parse_json_string_fail;
      }
      switch (*p) {
      case 'u':
        if (p + 4 >= e) {
          semsg(_("E474: Unfinished unicode escape sequence: %.*s"),
                (int)buf_len, buf);
          goto parse_json_string_fail;
        } else if (!ascii_isxdigit(p[1])
                   || !ascii_isxdigit(p[2])
                   || !ascii_isxdigit(p[3])
                   || !ascii_isxdigit(p[4])) {
          semsg(_("E474: Expected four hex digits after \\u: %.*s"),
                LENP(p - 1, e));
          goto parse_json_string_fail;
        }
        // One UTF-8 character below U+10000 can take up to 3 bytes,
        // above up to 6, but they are encoded using two \u escapes.
        len += 3;
        p += 5;
        break;
      case '\\':
      case '/':
      case '"':
      case 't':
      case 'b':
      case 'n':
      case 'r':
      case 'f':
        len++;
        p++;
        break;
      default:
        semsg(_("E474: Unknown escape sequence: %.*s"), LENP(p - 1, e));
        goto parse_json_string_fail;
      }
    } else {
      uint8_t p_byte = (uint8_t)(*p);
      // unescaped = %x20-21 / %x23-5B / %x5D-10FFFF
      if (p_byte < 0x20) {
        semsg(_("E474: ASCII control characters cannot be present "
                "inside string: %.*s"), LENP(p, e));
        goto parse_json_string_fail;
      }
      const int ch = utf_ptr2char(p);
      // All characters above U+007F are encoded using two or more bytes
      // and thus cannot possibly be equal to *p. But utf_ptr2char({0xFF,
      // 0}) will return 0xFF, even though 0xFF cannot start any UTF-8
      // code point at all.
      //
      // The only exception is U+00C3 which is represented as 0xC3 0x83.
      if (ch >= 0x80 && p_byte == ch
          && !(ch == 0xC3 && p + 1 < e && (uint8_t)p[1] == 0x83)) {
        semsg(_("E474: Only UTF-8 strings allowed: %.*s"), LENP(p, e));
        goto parse_json_string_fail;
      } else if (ch > 0x10FFFF) {
        semsg(_("E474: Only UTF-8 code points up to U+10FFFF "
                "are allowed to appear unescaped: %.*s"), LENP(p, e));
        goto parse_json_string_fail;
      }
      const size_t ch_len = (size_t)utf_char2len(ch);
      assert(ch_len == (size_t)(ch ? utf_ptr2len(p) : 1));
      len += ch_len;
      p += ch_len;
    }
  }
  if (p == e || *p != '"') {
    semsg(_("E474: Expected string end: %.*s"), (int)buf_len, buf);
    goto parse_json_string_fail;
  }
  char *str = xmalloc(len + 1);
  int fst_in_pair = 0;
  char *str_end = str;
#define PUT_FST_IN_PAIR(fst_in_pair, str_end) \
  do { \
    if ((fst_in_pair) != 0) { \
      (str_end) += utf_char2bytes(fst_in_pair, (str_end)); \
      (fst_in_pair) = 0; \
    } \
  } while (0)
  for (const char *t = s; t < p; t++) {
    if (t[0] != '\\' || t[1] != 'u') {
      PUT_FST_IN_PAIR(fst_in_pair, str_end);
    }
    if (*t == '\\') {
      t++;
      switch (*t) {
      case 'u': {
        const char ubuf[] = { t[1], t[2], t[3], t[4] };
        t += 4;
        uvarnumber_T ch;
        vim_str2nr(ubuf, NULL, NULL,
                   STR2NR_HEX | STR2NR_FORCE, NULL, &ch, 4, true, NULL);
        if (SURROGATE_HI_START <= ch && ch <= SURROGATE_HI_END) {
          PUT_FST_IN_PAIR(fst_in_pair, str_end);
          fst_in_pair = (int)ch;
        } else if (SURROGATE_LO_START <= ch && ch <= SURROGATE_LO_END
                   && fst_in_pair != 0) {
          const int full_char = ((int)(ch - SURROGATE_LO_START)
                                 + ((fst_in_pair - SURROGATE_HI_START) << 10)
                                 + SURROGATE_FIRST_CHAR);
          str_end += utf_char2bytes(full_char, str_end);
          fst_in_pair = 0;
        } else {
          PUT_FST_IN_PAIR(fst_in_pair, str_end);
          str_end += utf_char2bytes((int)ch, str_end);
        }
        break;
      }
      case '\\':
      case '/':
      case '"':
      case 't':
      case 'b':
      case 'n':
      case 'r':
      case 'f': {
        static const char escapes[] = {
          ['\\'] = '\\',
          ['/'] = '/',
          ['"'] = '"',
          ['t'] = TAB,
          ['b'] = BS,
          ['n'] = NL,
          ['r'] = CAR,
          ['f'] = FF,
        };
        *str_end++ = escapes[(int)(*t)];
        break;
      }
      default:
        abort();
      }
    } else {
      *str_end++ = *t;
    }
  }
  PUT_FST_IN_PAIR(fst_in_pair, str_end);
#undef PUT_FST_IN_PAIR
  *str_end = NUL;
  typval_T obj = decode_string(str, (size_t)(str_end - str), false, true);
  POP(obj, obj.v_type != VAR_STRING);
  goto parse_json_string_ret;
parse_json_string_fail:
  ret = FAIL;
parse_json_string_ret:
  *pp = p;
  return ret;
}

#undef POP

/// Parse JSON number: both floating-point and integer
///
/// Number format: `-?\d+(?:.\d+)?(?:[eE][+-]?\d+)?`.
///
/// @param[in]  buf  Buffer being converted.
/// @param[in]  buf_len  Length of the buffer.
/// @param[in,out]  pp  Pointer to the start of the number. Must point to
///                     a digit or a minus sign. Is advanced to the last
///                     character of the number. Also see json_decoder_pop(), it
///                     may set pp to another location and alter
///                     next_map_special, didcomma and didcolon.
/// @param[out]  stack  Object stack.
/// @param[out]  container_stack  Container objects stack.
/// @param[out]  next_map_special  Is set to true when dictionary is converted
///                                to a special map, otherwise not touched.
/// @param[out]  didcomma  True if previous token was comma. Is set to recorded
///                        value when decoder is restarted, otherwise unused.
/// @param[out]  didcolon  True if previous token was colon. Is set to recorded
///                        value when decoder is restarted, otherwise unused.
///
/// @return OK in case of success, FAIL in case of error.
static inline int parse_json_number(const char *const buf, const size_t buf_len,
                                    const char **const pp, ValuesStack *const stack,
                                    ContainerStack *const container_stack,
                                    bool *const next_map_special, bool *const didcomma,
                                    bool *const didcolon)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_ALWAYS_INLINE
{
  const char *const e = buf + buf_len;
  const char *p = *pp;
  int ret = OK;
  const char *const s = p;
  const char *ints = NULL;
  const char *fracs = NULL;
  const char *exps = NULL;
  const char *exps_s = NULL;
  if (*p == '-') {
    p++;
  }
  ints = p;
  if (p >= e) {
    goto parse_json_number_check;
  }
  while (p < e && ascii_isdigit(*p)) {
    p++;
  }
  if (p != ints + 1 && *ints == '0') {
    semsg(_("E474: Leading zeroes are not allowed: %.*s"), LENP(s, e));
    goto parse_json_number_fail;
  }
  if (p >= e || p == ints) {
    goto parse_json_number_check;
  }
  if (*p == '.') {
    p++;
    fracs = p;
    while (p < e && ascii_isdigit(*p)) {
      p++;
    }
    if (p >= e || p == fracs) {
      goto parse_json_number_check;
    }
  }
  if (*p == 'e' || *p == 'E') {
    p++;
    exps_s = p;
    if (p < e && (*p == '-' || *p == '+')) {
      p++;
    }
    exps = p;
    while (p < e && ascii_isdigit(*p)) {
      p++;
    }
  }
parse_json_number_check:
  if (p == ints) {
    semsg(_("E474: Missing number after minus sign: %.*s"), LENP(s, e));
    goto parse_json_number_fail;
  } else if (p == fracs || (fracs != NULL && exps_s == fracs + 1)) {
    semsg(_("E474: Missing number after decimal dot: %.*s"), LENP(s, e));
    goto parse_json_number_fail;
  } else if (p == exps) {
    semsg(_("E474: Missing exponent: %.*s"), LENP(s, e));
    goto parse_json_number_fail;
  }
  typval_T tv = {
    .v_type = VAR_NUMBER,
    .v_lock = VAR_UNLOCKED,
  };
  const size_t exp_num_len = (size_t)(p - s);
  if (fracs || exps) {
    // Convert floating-point number
    const size_t num_len = string2float(s, &tv.vval.v_float);
    if (exp_num_len != num_len) {
      semsg(_("E685: internal error: while converting number \"%.*s\" "
              "to float string2float consumed %zu bytes in place of %zu"),
            (int)exp_num_len, s, num_len, exp_num_len);
    }
    tv.v_type = VAR_FLOAT;
  } else {
    // Convert integer
    varnumber_T nr;
    int num_len;
    vim_str2nr(s, NULL, &num_len, 0, &nr, NULL, (int)(p - s), true, NULL);
    if ((int)exp_num_len != num_len) {
      semsg(_("E685: internal error: while converting number \"%.*s\" "
              "to integer vim_str2nr consumed %i bytes in place of %zu"),
            (int)exp_num_len, s, num_len, exp_num_len);
    }
    tv.vval.v_number = nr;
  }
  if (json_decoder_pop(OBJ(tv, false, *didcomma, *didcolon),
                       stack, container_stack,
                       &p, next_map_special, didcomma, didcolon) == FAIL) {
    goto parse_json_number_fail;
  }
  if (*next_map_special) {
    goto parse_json_number_ret;
  }
  p--;
  goto parse_json_number_ret;
parse_json_number_fail:
  ret = FAIL;
parse_json_number_ret:
  *pp = p;
  return ret;
}

#define POP(obj_tv, is_sp_string) \
  do { \
    if (json_decoder_pop(OBJ(obj_tv, is_sp_string, didcomma, didcolon), \
                         &stack, &container_stack, \
                         &p, &next_map_special, &didcomma, &didcolon) \
        == FAIL) { \
      goto json_decode_string_fail; \
    } \
    if (next_map_special) { \
      goto json_decode_string_cycle_start; \
    } \
  } while (0)

/// Convert JSON string into Vimscript object
///
/// @param[in]  buf  String to convert. UTF-8 encoding is assumed.
/// @param[in]  buf_len  Length of the string.
/// @param[out]  rettv  Location where to save results.
///
/// @return OK in case of success, FAIL otherwise.
int json_decode_string(const char *const buf, const size_t buf_len, typval_T *const rettv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const char *p = buf;
  const char *const e = buf + buf_len;
  while (p < e && (*p == ' ' || *p == TAB || *p == NL || *p == CAR)) {
    p++;
  }
  if (p == e) {
    emsg(_("E474: Attempt to decode a blank string"));
    return FAIL;
  }
  int ret = OK;
  ValuesStack stack = KV_INITIAL_VALUE;
  ContainerStack container_stack = KV_INITIAL_VALUE;
  rettv->v_type = VAR_UNKNOWN;
  bool didcomma = false;
  bool didcolon = false;
  bool next_map_special = false;
  for (; p < e; p++) {
json_decode_string_cycle_start:
    assert(*p == '{' || next_map_special == false);
    switch (*p) {
    case '}':
    case ']': {
      if (kv_size(container_stack) == 0) {
        semsg(_("E474: No container to close: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      }
      ContainerStackItem last_container = kv_last(container_stack);
      if (*p == '}' && last_container.container.v_type != VAR_DICT) {
        semsg(_("E474: Closing list with curly bracket: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      } else if (*p == ']' && last_container.container.v_type != VAR_LIST) {
        semsg(_("E474: Closing dictionary with square bracket: %.*s"),
              LENP(p, e));
        goto json_decode_string_fail;
      } else if (didcomma) {
        semsg(_("E474: Trailing comma: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      } else if (didcolon) {
        semsg(_("E474: Expected value after colon: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      } else if (last_container.stack_index != kv_size(stack) - 1) {
        assert(last_container.stack_index < kv_size(stack) - 1);
        semsg(_("E474: Expected value: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      }
      if (kv_size(stack) == 1) {
        p++;
        (void)kv_pop(container_stack);
        goto json_decode_string_after_cycle;
      } else {
        if (json_decoder_pop(kv_pop(stack), &stack, &container_stack, &p,
                             &next_map_special, &didcomma, &didcolon)
            == FAIL) {
          goto json_decode_string_fail;
        }
        assert(!next_map_special);
        break;
      }
    }
    case ',': {
      if (kv_size(container_stack) == 0) {
        semsg(_("E474: Comma not inside container: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      }
      ContainerStackItem last_container = kv_last(container_stack);
      if (didcomma) {
        semsg(_("E474: Duplicate comma: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      } else if (didcolon) {
        semsg(_("E474: Comma after colon: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      } else if (last_container.container.v_type == VAR_DICT
                 && last_container.stack_index != kv_size(stack) - 1) {
        semsg(_("E474: Using comma in place of colon: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      } else if (last_container.special_val == NULL
                 ? (last_container.container.v_type == VAR_DICT
                    ? (DICT_LEN(last_container.container.vval.v_dict) == 0)
                    : (tv_list_len(last_container.container.vval.v_list)
                       == 0))
                 : (tv_list_len(last_container.special_val) == 0)) {
        semsg(_("E474: Leading comma: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      }
      didcomma = true;
      continue;
    }
    case ':': {
      if (kv_size(container_stack) == 0) {
        semsg(_("E474: Colon not inside container: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      }
      ContainerStackItem last_container = kv_last(container_stack);
      if (last_container.container.v_type != VAR_DICT) {
        semsg(_("E474: Using colon not in dictionary: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      } else if (last_container.stack_index != kv_size(stack) - 2) {
        semsg(_("E474: Unexpected colon: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      } else if (didcomma) {
        semsg(_("E474: Colon after comma: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      } else if (didcolon) {
        semsg(_("E474: Duplicate colon: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      }
      didcolon = true;
      continue;
    }
    case ' ':
    case TAB:
    case NL:
    case CAR:
      continue;
    case 'n':
      if ((p + 3) >= e || strncmp(p + 1, "ull", 3) != 0) {
        semsg(_("E474: Expected null: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      }
      p += 3;
      POP(((typval_T) {
        .v_type = VAR_SPECIAL,
        .v_lock = VAR_UNLOCKED,
        .vval = { .v_special = kSpecialVarNull },
      }), false);
      break;
    case 't':
      if ((p + 3) >= e || strncmp(p + 1, "rue", 3) != 0) {
        semsg(_("E474: Expected true: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      }
      p += 3;
      POP(((typval_T) {
        .v_type = VAR_BOOL,
        .v_lock = VAR_UNLOCKED,
        .vval = { .v_bool = kBoolVarTrue },
      }), false);
      break;
    case 'f':
      if ((p + 4) >= e || strncmp(p + 1, "alse", 4) != 0) {
        semsg(_("E474: Expected false: %.*s"), LENP(p, e));
        goto json_decode_string_fail;
      }
      p += 4;
      POP(((typval_T) {
        .v_type = VAR_BOOL,
        .v_lock = VAR_UNLOCKED,
        .vval = { .v_bool = kBoolVarFalse },
      }), false);
      break;
    case '"':
      if (parse_json_string(buf, buf_len, &p, &stack, &container_stack,
                            &next_map_special, &didcomma, &didcolon)
          == FAIL) {
        // Error message was already given
        goto json_decode_string_fail;
      }
      if (next_map_special) {
        goto json_decode_string_cycle_start;
      }
      break;
    case '-':
    case '0':
    case '1':
    case '2':
    case '3':
    case '4':
    case '5':
    case '6':
    case '7':
    case '8':
    case '9':
      if (parse_json_number(buf, buf_len, &p, &stack, &container_stack,
                            &next_map_special, &didcomma, &didcolon)
          == FAIL) {
        // Error message was already given
        goto json_decode_string_fail;
      }
      if (next_map_special) {
        goto json_decode_string_cycle_start;
      }
      break;
    case '[': {
      list_T *list = tv_list_alloc(kListLenMayKnow);
      tv_list_ref(list);
      typval_T tv = {
        .v_type = VAR_LIST,
        .v_lock = VAR_UNLOCKED,
        .vval = { .v_list = list },
      };
      kv_push(container_stack, ((ContainerStackItem) { .stack_index = kv_size(stack),
                                                       .s = p,
                                                       .container = tv,
                                                       .special_val = NULL }));
      kv_push(stack, OBJ(tv, false, didcomma, didcolon));
      break;
    }
    case '{': {
      typval_T tv;
      list_T *val_list = NULL;
      if (next_map_special) {
        next_map_special = false;
        val_list = decode_create_map_special_dict(&tv, kListLenMayKnow);
      } else {
        dict_T *dict = tv_dict_alloc();
        dict->dv_refcount++;
        tv = (typval_T) {
          .v_type = VAR_DICT,
          .v_lock = VAR_UNLOCKED,
          .vval = { .v_dict = dict },
        };
      }
      kv_push(container_stack, ((ContainerStackItem) { .stack_index = kv_size(stack),
                                                       .s = p,
                                                       .container = tv,
                                                       .special_val = val_list }));
      kv_push(stack, OBJ(tv, false, didcomma, didcolon));
      break;
    }
    default:
      semsg(_("E474: Unidentified byte: %.*s"), LENP(p, e));
      goto json_decode_string_fail;
    }
    didcomma = false;
    didcolon = false;
    if (kv_size(container_stack) == 0) {
      p++;
      break;
    }
  }
json_decode_string_after_cycle:
  for (; p < e; p++) {
    switch (*p) {
    case NL:
    case ' ':
    case TAB:
    case CAR:
      break;
    default:
      semsg(_("E474: Trailing characters: %.*s"), LENP(p, e));
      goto json_decode_string_fail;
    }
  }
  if (kv_size(stack) == 1 && kv_size(container_stack) == 0) {
    *rettv = kv_pop(stack).val;
    goto json_decode_string_ret;
  }
  semsg(_("E474: Unexpected end of input: %.*s"), (int)buf_len, buf);
json_decode_string_fail:
  ret = FAIL;
  while (kv_size(stack)) {
    tv_clear(&(kv_pop(stack).val));
  }
json_decode_string_ret:
  kv_destroy(stack);
  kv_destroy(container_stack);
  return ret;
}

#undef LENP
#undef POP

#undef OBJ

#undef DICT_LEN

static void positive_integer_to_special_typval(typval_T *rettv, uint64_t val)
{
  if (val <= VARNUMBER_MAX) {
    *rettv = (typval_T) {
      .v_type = VAR_NUMBER,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_number = (varnumber_T)val },
    };
  } else {
    list_T *const list = tv_list_alloc(4);
    tv_list_ref(list);
    create_special_dict(rettv, kMPInteger, ((typval_T) {
      .v_type = VAR_LIST,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_list = list },
    }));
    tv_list_append_number(list, 1);
    tv_list_append_number(list, (varnumber_T)((val >> 62) & 0x3));
    tv_list_append_number(list, (varnumber_T)((val >> 31) & 0x7FFFFFFF));
    tv_list_append_number(list, (varnumber_T)(val & 0x7FFFFFFF));
  }
}

static void typval_parse_enter(mpack_parser_t *parser, mpack_node_t *node)
{
  typval_T *result = NULL;

  mpack_node_t *parent = MPACK_PARENT_NODE(node);
  if (parent) {
    switch (parent->tok.type) {
    case MPACK_TOKEN_ARRAY: {
      list_T *list = parent->data[1].p;
      result = tv_list_append_owned_tv(list, (typval_T) { .v_type = VAR_UNKNOWN });
      break;
    }
    case MPACK_TOKEN_MAP: {
      typval_T(*items)[2] = parent->data[1].p;
      result = &items[parent->pos][parent->key_visited];
      break;
    }

    case MPACK_TOKEN_STR:
    case MPACK_TOKEN_BIN:
    case MPACK_TOKEN_EXT:
      assert(node->tok.type == MPACK_TOKEN_CHUNK);
      break;

    default:
      abort();
    }
  } else {
    result = parser->data.p;
  }

  // for types that are completed in typval_parse_exit
  node->data[0].p = result;
  node->data[1].p = NULL;  // free on error if non-NULL

  switch (node->tok.type) {
  case MPACK_TOKEN_NIL:
    *result = (typval_T) {
      .v_type = VAR_SPECIAL,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_special = kSpecialVarNull },
    };
    break;
  case MPACK_TOKEN_BOOLEAN:
    *result = (typval_T) {
      .v_type = VAR_BOOL,
      .v_lock = VAR_UNLOCKED,
      .vval = {
        .v_bool = mpack_unpack_boolean(node->tok) ? kBoolVarTrue : kBoolVarFalse
      },
    };
    break;
  case MPACK_TOKEN_SINT: {
    *result = (typval_T) {
      .v_type = VAR_NUMBER,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_number = mpack_unpack_sint(node->tok) },
    };
    break;
  }
  case MPACK_TOKEN_UINT:
    positive_integer_to_special_typval(result, mpack_unpack_uint(node->tok));
    break;
  case MPACK_TOKEN_FLOAT:
    *result = (typval_T) {
      .v_type = VAR_FLOAT,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_float = mpack_unpack_float(node->tok) },
    };
    break;

  case MPACK_TOKEN_BIN:
  case MPACK_TOKEN_STR:
  case MPACK_TOKEN_EXT:
    // actually converted in typval_parse_exit after the data chunks
    node->data[1].p = xmallocz(node->tok.length);
    break;
  case MPACK_TOKEN_CHUNK: {
    char *data = parent->data[1].p;
    memcpy(data + parent->pos,
           node->tok.data.chunk_ptr, node->tok.length);
    break;
  }

  case MPACK_TOKEN_ARRAY: {
    list_T *const list = tv_list_alloc((ptrdiff_t)node->tok.length);
    tv_list_ref(list);
    *result = (typval_T) {
      .v_type = VAR_LIST,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_list = list },
    };
    node->data[1].p = list;
    break;
  }
  case MPACK_TOKEN_MAP:
    // we don't know if this will be safe to convert to a typval dict yet
    node->data[1].p = xmallocz(node->tok.length * 2 * sizeof(typval_T));
    break;
  }
}

/// Free node which was entered but never exited, due to a nested error
///
/// Don't bother with typvals as these will be GC:d eventually
void typval_parser_error_free(mpack_parser_t *parser)
{
  for (uint32_t i = 0; i < parser->size; i++) {
    mpack_node_t *node = &parser->items[i];
    switch (node->tok.type) {
    case MPACK_TOKEN_BIN:
    case MPACK_TOKEN_STR:
    case MPACK_TOKEN_EXT:
    case MPACK_TOKEN_MAP:
      XFREE_CLEAR(node->data[1].p);
      break;
    default:
      break;
    }
  }
}

static void typval_parse_exit(mpack_parser_t *parser, mpack_node_t *node)
{
  typval_T *result = node->data[0].p;
  switch (node->tok.type) {
  case MPACK_TOKEN_BIN:
  case MPACK_TOKEN_STR:
    *result = decode_string(node->data[1].p, node->tok.length, false, true);
    node->data[1].p = NULL;
    break;

  case MPACK_TOKEN_EXT: {
    list_T *const list = tv_list_alloc(2);
    tv_list_ref(list);
    tv_list_append_number(list, node->tok.data.ext_type);
    list_T *const ext_val_list = tv_list_alloc(kListLenMayKnow);
    tv_list_append_list(list, ext_val_list);
    create_special_dict(result, kMPExt, ((typval_T) { .v_type = VAR_LIST,
                                                      .v_lock = VAR_UNLOCKED,
                                                      .vval = { .v_list = list } }));
    // TODO(bfredl): why not use BLOB?
    encode_list_write((void *)ext_val_list, node->data[1].p, node->tok.length);
    XFREE_CLEAR(node->data[1].p);
  }
  break;

  case MPACK_TOKEN_MAP: {
    typval_T(*items)[2] = node->data[1].p;
    for (size_t i = 0; i < node->tok.length; i++) {
      typval_T *key = &items[i][0];
      if (key->v_type != VAR_STRING
          || key->vval.v_string == NULL
          || key->vval.v_string[0] == NUL) {
        goto msgpack_to_vim_generic_map;
      }
    }
    dict_T *const dict = tv_dict_alloc();
    dict->dv_refcount++;
    *result = (typval_T) {
      .v_type = VAR_DICT,
      .v_lock = VAR_UNLOCKED,
      .vval = { .v_dict = dict },
    };
    for (size_t i = 0; i < node->tok.length; i++) {
      char *key = items[i][0].vval.v_string;
      size_t keylen = strlen(key);
      dictitem_T *const di = xmallocz(offsetof(dictitem_T, di_key) + keylen);
      memcpy(&di->di_key[0], key, keylen);
      di->di_tv.v_type = VAR_UNKNOWN;
      if (tv_dict_add(dict, di) == FAIL) {
        // Duplicate key: fallback to generic map
        TV_DICT_ITER(dict, d, {
            d->di_tv.v_type = VAR_SPECIAL;  // don't free values in tv_clear(), they will be reused
            d->di_tv.vval.v_special = kSpecialVarNull;
          });
        tv_clear(result);
        xfree(di);
        goto msgpack_to_vim_generic_map;
      }
      di->di_tv = items[i][1];
    }
    for (size_t i = 0; i < node->tok.length; i++) {
      xfree(items[i][0].vval.v_string);
    }
    XFREE_CLEAR(node->data[1].p);
    break;
msgpack_to_vim_generic_map: {}
    list_T *const list = decode_create_map_special_dict(result, node->tok.length);
    for (size_t i = 0; i < node->tok.length; i++) {
      list_T *const kv_pair = tv_list_alloc(2);
      tv_list_append_list(list, kv_pair);

      tv_list_append_owned_tv(kv_pair, items[i][0]);
      tv_list_append_owned_tv(kv_pair, items[i][1]);
    }
    XFREE_CLEAR(node->data[1].p);
    break;
  }

  default:
    // other kinds are handled completely in typval_parse_enter
    break;
  }
}

int mpack_parse_typval(mpack_parser_t *parser, const char **data, size_t *size)
{
  return mpack_parse(parser, data, size, typval_parse_enter, typval_parse_exit);
}

int unpack_typval(const char **data, size_t *size, typval_T *ret)
{
  ret->v_type = VAR_UNKNOWN;
  mpack_parser_t parser;
  mpack_parser_init(&parser, 0);
  parser.data.p = ret;
  int status = mpack_parse_typval(&parser, data, size);
  if (status != MPACK_OK) {
    typval_parser_error_free(&parser);
    tv_clear(ret);
  }
  return status;
}
