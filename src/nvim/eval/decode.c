#include <stddef.h>

#include <msgpack.h>

#include "nvim/eval_defs.h"
#include "nvim/eval.h"
#include "nvim/eval/encode.h"
#include "nvim/ascii.h"
#include "nvim/message.h"
#include "nvim/charset.h"  // vim_str2nr
#include "nvim/lib/kvec.h"
#include "nvim/vim.h"  // OK, FAIL

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
static inline void create_special_dict(typval_T *const rettv,
                                       const MessagePackType type,
                                       typval_T val)
  FUNC_ATTR_NONNULL_ALL
{
  dict_T *const dict = dict_alloc();
  dictitem_T *const type_di = dictitem_alloc((char_u *) "_TYPE");
  type_di->di_tv.v_type = VAR_LIST;
  type_di->di_tv.v_lock = VAR_UNLOCKED;
  type_di->di_tv.vval.v_list = (list_T *) eval_msgpack_type_lists[type];
  type_di->di_tv.vval.v_list->lv_refcount++;
  dict_add(dict, type_di);
  dictitem_T *const val_di = dictitem_alloc((char_u *) "_VAL");
  val_di->di_tv = val;
  dict_add(dict, val_di);
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
/// @param[out]  next_map_special  Is set to true when dictionary is converted
///                                to a special map, otherwise not touched.
/// @param[out]  didcomma  True if previous token was comma. Is set to recorded
///                        value when decoder is restarted, otherwise unused.
/// @param[out]  didcolon  True if previous token was colon. Is set to recorded
///                        value when decoder is restarted, otherwise unused.
///
/// @return OK in case of success, FAIL in case of error.
static inline int json_decoder_pop(ValuesStackItem obj,
                                   ValuesStack *const stack,
                                   ContainerStack *const container_stack,
                                   const char **const pp,
                                   bool *const next_map_special,
                                   bool *const didcomma,
                                   bool *const didcolon)
  FUNC_ATTR_NONNULL_ALL
{
  if (kv_size(*container_stack) == 0) {
    kv_push(ValuesStackItem, *stack, obj);
    return OK;
  }
  ContainerStackItem last_container = kv_last(*container_stack);
  const char *val_location = *pp;
  if (obj.val.v_type == last_container.container.v_type
      // vval.v_list and vval.v_dict should have the same size and offset
      && ((void *) obj.val.vval.v_list
          == (void *) last_container.container.vval.v_list)) {
    (void) kv_pop(*container_stack);
    val_location = last_container.s;
    last_container = kv_last(*container_stack);
  }
  if (last_container.container.v_type == VAR_LIST) {
    if (last_container.container.vval.v_list->lv_len != 0
        && !obj.didcomma) {
      EMSG2(_("E474: Expected comma before list item: %s"), val_location);
      clear_tv(&obj.val);
      return FAIL;
    }
    assert(last_container.special_val == NULL);
    listitem_T *obj_li = listitem_alloc();
    obj_li->li_tv = obj.val;
    list_append(last_container.container.vval.v_list, obj_li);
  } else if (last_container.stack_index == kv_size(*stack) - 2) {
    if (!obj.didcolon) {
      EMSG2(_("E474: Expected colon before dictionary value: %s"),
            val_location);
      clear_tv(&obj.val);
      return FAIL;
    }
    ValuesStackItem key = kv_pop(*stack);
    if (last_container.special_val == NULL) {
      // These cases should have already been handled.
      assert(!(key.is_special_string
               || key.val.vval.v_string == NULL
               || *key.val.vval.v_string == NUL));
      dictitem_T *obj_di = dictitem_alloc(key.val.vval.v_string);
      clear_tv(&key.val);
      if (dict_add(last_container.container.vval.v_dict, obj_di)
          == FAIL) {
        assert(false);
      }
      obj_di->di_tv = obj.val;
    } else {
      list_T *const kv_pair = list_alloc();
      list_append_list(last_container.special_val, kv_pair);
      listitem_T *const key_li = listitem_alloc();
      key_li->li_tv = key.val;
      list_append(kv_pair, key_li);
      listitem_T *const val_li = listitem_alloc();
      val_li->li_tv = obj.val;
      list_append(kv_pair, val_li);
    }
  } else {
    // Object with key only
    if (!obj.is_special_string && obj.val.v_type != VAR_STRING) {
      EMSG2(_("E474: Expected string key: %s"), *pp);
      clear_tv(&obj.val);
      return FAIL;
    } else if (!obj.didcomma
               && (last_container.special_val == NULL
                   && (DICT_LEN(last_container.container.vval.v_dict) != 0))) {
      EMSG2(_("E474: Expected comma before dictionary key: %s"), val_location);
      clear_tv(&obj.val);
      return FAIL;
    }
    // Handle empty key and key represented as special dictionary
    if (last_container.special_val == NULL
        && (obj.is_special_string
            || obj.val.vval.v_string == NULL
            || *obj.val.vval.v_string == NUL
            || dict_find(last_container.container.vval.v_dict,
                         obj.val.vval.v_string, -1))) {
      clear_tv(&obj.val);

      // Restart
      (void) kv_pop(*container_stack);
      ValuesStackItem last_container_val =
          kv_A(*stack, last_container.stack_index);
      while (kv_size(*stack) > last_container.stack_index) {
        clear_tv(&(kv_pop(*stack).val));
      }
      *pp = last_container.s;
      *didcomma = last_container_val.didcomma;
      *didcolon = last_container_val.didcolon;
      *next_map_special = true;
      return OK;
    }
    kv_push(ValuesStackItem, *stack, obj);
  }
  return OK;
}

#define OBJ(obj_tv, is_sp_string) \
  ((ValuesStackItem) { \
    .is_special_string = (is_sp_string), \
    .val = (obj_tv), \
    .didcomma = didcomma, \
    .didcolon = didcolon, \
  })
#define POP(obj_tv, is_sp_string) \
  do { \
    if (json_decoder_pop(OBJ(obj_tv, is_sp_string), &stack, &container_stack, \
                         &p, &next_map_special, &didcomma, &didcolon) \
        == FAIL) { \
      goto json_decode_string_fail; \
    } \
    if (next_map_special) { \
      goto json_decode_string_cycle_start; \
    } \
  } while (0)

/// Convert JSON string into VimL object
///
/// @param[in]  buf  String to convert. UTF-8 encoding is assumed.
/// @param[in]  len  Length of the string.
/// @param[out]  rettv  Location where to save results.
///
/// @return OK in case of success, FAIL otherwise.
int json_decode_string(const char *const buf, const size_t len,
                       typval_T *const rettv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  vimconv_T conv = { .vc_type = CONV_NONE };
  convert_setup(&conv, (char_u *) "utf-8", p_enc);
  conv.vc_fail = true;
  int ret = OK;
  ValuesStack stack;
  kv_init(stack);
  ContainerStack container_stack;
  kv_init(container_stack);
  rettv->v_type = VAR_UNKNOWN;
  const char *const e = buf + len;
  bool didcomma = false;
  bool didcolon = false;
  bool next_map_special = false;
  const char *p = buf;
  for (; p < e; p++) {
json_decode_string_cycle_start:
    assert(*p == '{' || next_map_special == false);
    switch (*p) {
      case '}':
      case ']': {
        if (kv_size(container_stack) == 0) {
          EMSG2(_("E474: No container to close: %s"), p);
          goto json_decode_string_fail;
        }
        ContainerStackItem last_container = kv_last(container_stack);
        if (*p == '}' && last_container.container.v_type != VAR_DICT) {
          EMSG2(_("E474: Closing list with curly bracket: %s"), p);
          goto json_decode_string_fail;
        } else if (*p == ']' && last_container.container.v_type != VAR_LIST) {
          EMSG2(_("E474: Closing dictionary with square bracket: %s"), p);
          goto json_decode_string_fail;
        } else if (didcomma) {
          EMSG2(_("E474: Trailing comma: %s"), p);
          goto json_decode_string_fail;
        } else if (didcolon) {
          EMSG2(_("E474: Expected value after colon: %s"), p);
          goto json_decode_string_fail;
        } else if (last_container.stack_index != kv_size(stack) - 1) {
          assert(last_container.stack_index < kv_size(stack) - 1);
          EMSG2(_("E474: Expected value: %s"), p);
          goto json_decode_string_fail;
        }
        if (kv_size(stack) == 1) {
          p++;
          (void) kv_pop(container_stack);
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
          EMSG2(_("E474: Comma not inside container: %s"), p);
          goto json_decode_string_fail;
        }
        ContainerStackItem last_container = kv_last(container_stack);
        if (didcomma) {
          EMSG2(_("E474: Duplicate comma: %s"), p);
          goto json_decode_string_fail;
        } else if (didcolon) {
          EMSG2(_("E474: Comma after colon: %s"), p);
          goto json_decode_string_fail;
        } else if (last_container.container.v_type == VAR_DICT
                   && last_container.stack_index != kv_size(stack) - 1) {
          EMSG2(_("E474: Using comma in place of colon: %s"), p);
          goto json_decode_string_fail;
        } else if (last_container.special_val == NULL
                   ? (last_container.container.v_type == VAR_DICT
                      ? (DICT_LEN(last_container.container.vval.v_dict) == 0)
                      : (last_container.container.vval.v_list->lv_len == 0))
                   : (last_container.special_val->lv_len == 0)) {
          EMSG2(_("E474: Leading comma: %s"), p);
          goto json_decode_string_fail;
        }
        didcomma = true;
        continue;
      }
      case ':': {
        if (kv_size(container_stack) == 0) {
          EMSG2(_("E474: Colon not inside container: %s"), p);
          goto json_decode_string_fail;
        }
        ContainerStackItem last_container = kv_last(container_stack);
        if (last_container.container.v_type != VAR_DICT) {
          EMSG2(_("E474: Using colon not in dictionary: %s"), p);
          goto json_decode_string_fail;
        } else if (last_container.stack_index != kv_size(stack) - 2) {
          EMSG2(_("E474: Unexpected colon: %s"), p);
          goto json_decode_string_fail;
        } else if (didcomma) {
          EMSG2(_("E474: Colon after comma: %s"), p);
          goto json_decode_string_fail;
        } else if (didcolon) {
          EMSG2(_("E474: Duplicate colon: %s"), p);
          goto json_decode_string_fail;
        }
        didcolon = true;
        continue;
      }
      case ' ':
      case TAB:
      case NL: {
        continue;
      }
      case 'n': {
        if (strncmp(p + 1, "ull", 3) != 0) {
          EMSG2(_("E474: Expected null: %s"), p);
          goto json_decode_string_fail;
        }
        p += 3;
        POP(((typval_T) {
          .v_type = VAR_SPECIAL,
          .v_lock = VAR_UNLOCKED,
          .vval = { .v_special = kSpecialVarNull },
        }), false);
        break;
      }
      case 't': {
        if (strncmp(p + 1, "rue", 3) != 0) {
          EMSG2(_("E474: Expected true: %s"), p);
          goto json_decode_string_fail;
        }
        p += 3;
        POP(((typval_T) {
          .v_type = VAR_SPECIAL,
          .v_lock = VAR_UNLOCKED,
          .vval = { .v_special = kSpecialVarTrue },
        }), false);
        break;
      }
      case 'f': {
        if (strncmp(p + 1, "alse", 4) != 0) {
          EMSG2(_("E474: Expected false: %s"), p);
          goto json_decode_string_fail;
        }
        p += 4;
        POP(((typval_T) {
          .v_type = VAR_SPECIAL,
          .v_lock = VAR_UNLOCKED,
          .vval = { .v_special = kSpecialVarFalse },
        }), false);
        break;
      }
      case '"': {
        size_t len = 0;
        const char *const s = ++p;
        while (p < e && *p != '"') {
          if (*p == '\\') {
            p++;
            if (p == e) {
              EMSG2(_("E474: Unfinished escape sequence: %s"), buf);
              goto json_decode_string_fail;
            }
            switch (*p) {
              case 'u': {
                if (p + 4 >= e) {
                  EMSG2(_("E474: Unfinished unicode escape sequence: %s"), buf);
                  goto json_decode_string_fail;
                } else if (!ascii_isxdigit(p[1])
                           || !ascii_isxdigit(p[2])
                           || !ascii_isxdigit(p[3])
                           || !ascii_isxdigit(p[4])) {
                  EMSG2(_("E474: Expected four hex digits after \\u: %s"),
                        p - 1);
                  goto json_decode_string_fail;
                }
                // One UTF-8 character below U+10000 can take up to 3 bytes,
                // above up to 6, but they are encoded using two \u escapes.
                len += 3;
                p += 5;
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
                len++;
                p++;
                break;
              }
              default: {
                EMSG2(_("E474: Unknown escape sequence: %s"), p - 1);
                goto json_decode_string_fail;
              }
            }
          } else {
            uint8_t p_byte = (uint8_t) *p;
            // unescaped = %x20-21 / %x23-5B / %x5D-10FFFF
            if (p_byte < 0x20) {
              EMSG2(_("E474: ASCII control characters cannot be present "
                      "inside string: %s"), p);
              goto json_decode_string_fail;
            }
            const int ch = utf_ptr2char((char_u *) p);
            // All characters above U+007F are encoded using two or more bytes
            // and thus cannot possibly be equal to *p. But utf_ptr2char({0xFF,
            // 0}) will return 0xFF, even though 0xFF cannot start any UTF-8
            // code point at all.
            if (ch >= 0x80 && p_byte == ch) {
              EMSG2(_("E474: Only UTF-8 strings allowed: %s"), p);
              goto json_decode_string_fail;
            } else if (ch > 0x10FFFF) {
              EMSG2(_("E474: Only UTF-8 code points up to U+10FFFF "
                      "are allowed to appear unescaped: %s"), p);
              goto json_decode_string_fail;
            }
            const size_t ch_len = (size_t) utf_char2len(ch);
            assert(ch_len == (size_t) (ch ? utf_ptr2len((char_u *) p) : 1));
            len += ch_len;
            p += ch_len;
          }
        }
        if (*p != '"') {
          EMSG2(_("E474: Expected string end: %s"), buf);
          goto json_decode_string_fail;
        }
        if (len == 0) {
          POP(((typval_T) {
            .v_type = VAR_STRING,
            .vval = { .v_string = NULL },
          }), false);
          break;
        }
        char *str = xmalloc(len + 1);
        int fst_in_pair = 0;
        char *str_end = str;
        bool hasnul = false;
#define PUT_FST_IN_PAIR(fst_in_pair, str_end) \
        do { \
          if (fst_in_pair != 0) { \
            str_end += utf_char2bytes(fst_in_pair, (char_u *) str_end); \
            fst_in_pair = 0; \
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
                unsigned long ch;
                vim_str2nr((char_u *) ubuf, NULL, NULL,
                           STR2NR_HEX | STR2NR_FORCE, NULL, &ch, 4);
                if (ch == 0) {
                  hasnul = true;
                }
                if (SURROGATE_HI_START <= ch && ch <= SURROGATE_HI_END) {
                  fst_in_pair = (int) ch;
                } else if (SURROGATE_LO_START <= ch && ch <= SURROGATE_LO_END
                           && fst_in_pair != 0) {
                  const int full_char = (
                      (int) (ch - SURROGATE_LO_START)
                      + ((fst_in_pair - SURROGATE_HI_START) << 10)
                      + SURROGATE_FIRST_CHAR);
                  str_end += utf_char2bytes(full_char, (char_u *) str_end);
                  fst_in_pair = 0;
                } else {
                  PUT_FST_IN_PAIR(fst_in_pair, str_end);
                  str_end += utf_char2bytes((int) ch, (char_u *) str_end);
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
                *str_end++ = escapes[(int) *t];
                break;
              }
              default: {
                assert(false);
              }
            }
          } else {
            *str_end++ = *t;
          }
        }
        PUT_FST_IN_PAIR(fst_in_pair, str_end);
#undef PUT_FST_IN_PAIR
        if (conv.vc_type != CONV_NONE) {
          size_t str_len = (size_t) (str_end - str);
          char *const new_str = (char *) string_convert(&conv, (char_u *) str,
                                                        &str_len);
          if (new_str == NULL) {
            EMSG2(_("E474: Failed to convert string \"%s\" from UTF-8"), str);
            xfree(str);
            goto json_decode_string_fail;
          }
          xfree(str);
          str = new_str;
          str_end = new_str + str_len;
        }
        if (hasnul) {
          typval_T obj;
          list_T *const list = list_alloc();
          list->lv_refcount++;
          create_special_dict(&obj, kMPString, ((typval_T) {
            .v_type = VAR_LIST,
            .v_lock = VAR_UNLOCKED,
            .vval = { .v_list = list },
          }));
          if (encode_list_write((void *) list, str, (size_t) (str_end - str))
              == -1) {
            clear_tv(&obj);
            goto json_decode_string_fail;
          }
          xfree(str);
          POP(obj, true);
        } else {
          *str_end = NUL;
          POP(((typval_T) {
            .v_type = VAR_STRING,
            .vval = { .v_string = (char_u *) str },
          }), false);
        }
        break;
      }
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
      case '9': {
        // a.bE[+-]exp
        const char *const s = p;
        const char *ints = NULL;
        const char *fracs = NULL;
        const char *exps = NULL;
        if (*p == '-') {
          p++;
        }
        ints = p;
        while (p < e && ascii_isdigit(*p)) {
          p++;
        }
        if (p < e && *p == '.') {
          p++;
          fracs = p;
          while (p < e && ascii_isdigit(*p)) {
            p++;
          }
          if (p < e && (*p == 'e' || *p == 'E')) {
            p++;
            if (p < e && (*p == '-' || *p == '+')) {
              p++;
            }
            exps = p;
            while (p < e && ascii_isdigit(*p)) {
              p++;
            }
          }
        }
        if (p == ints) {
          EMSG2(_("E474: Missing number after minus sign: %s"), s);
          goto json_decode_string_fail;
        } else if (p == fracs) {
          EMSG2(_("E474: Missing number after decimal dot: %s"), s);
          goto json_decode_string_fail;
        } else if (p == exps) {
          EMSG2(_("E474: Missing exponent: %s"), s);
          goto json_decode_string_fail;
        }
        typval_T tv = {
          .v_type = VAR_NUMBER,
          .v_lock = VAR_UNLOCKED,
        };
        if (fracs) {
          // Convert floating-point number
          (void) string2float(s, &tv.vval.v_float);
          tv.v_type = VAR_FLOAT;
        } else {
          // Convert integer
          long nr;
          vim_str2nr((char_u *) s, NULL, NULL, 0, &nr, NULL, (int) (p - s));
          tv.vval.v_number = (varnumber_T) nr;
        }
        POP(tv, false);
        p--;
        break;
      }
      case '[': {
        list_T *list = list_alloc();
        list->lv_refcount++;
        typval_T tv = {
          .v_type = VAR_LIST,
          .v_lock = VAR_UNLOCKED,
          .vval = { .v_list = list },
        };
        kv_push(ContainerStackItem, container_stack, ((ContainerStackItem) {
          .stack_index = kv_size(stack),
          .s = p,
          .container = tv,
          .special_val = NULL,
        }));
        kv_push(ValuesStackItem, stack, OBJ(tv, false));
        break;
      }
      case '{': {
        typval_T tv;
        list_T *val_list = NULL;
        if (next_map_special) {
          next_map_special = false;
          val_list = list_alloc();
          val_list->lv_refcount++;
          create_special_dict(&tv, kMPMap, ((typval_T) {
            .v_type = VAR_LIST,
            .v_lock = VAR_UNLOCKED,
            .vval = { .v_list = val_list },
          }));
        } else {
          dict_T *dict = dict_alloc();
          dict->dv_refcount++;
          tv = (typval_T) {
            .v_type = VAR_DICT,
            .v_lock = VAR_UNLOCKED,
            .vval = { .v_dict = dict },
          };
        }
        kv_push(ContainerStackItem, container_stack, ((ContainerStackItem) {
          .stack_index = kv_size(stack),
          .s = p,
          .container = tv,
          .special_val = val_list,
        }));
        kv_push(ValuesStackItem, stack, OBJ(tv, false));
        break;
      }
      default: {
        EMSG2(_("E474: Unidentified byte: %s"), p);
        goto json_decode_string_fail;
      }
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
      case TAB: {
        break;
      }
      default: {
        EMSG2(_("E474: Trailing characters: %s"), p);
        goto json_decode_string_fail;
      }
    }
  }
  if (kv_size(stack) > 1 || kv_size(container_stack)) {
    EMSG2(_("E474: Unexpected end of input: %s"), buf);
    goto json_decode_string_fail;
  }
  goto json_decode_string_ret;
json_decode_string_fail:
  ret = FAIL;
  while (kv_size(stack)) {
    clear_tv(&(kv_pop(stack).val));
  }
json_decode_string_ret:
  if (ret != FAIL) {
    assert(kv_size(stack) == 1);
    *rettv = kv_pop(stack).val;
  }
  kv_destroy(stack);
  kv_destroy(container_stack);
  return ret;
}

#undef POP
#undef OBJ

#undef DICT_LEN

/// Convert msgpack object to a VimL one
int msgpack_to_vim(const msgpack_object mobj, typval_T *const rettv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (mobj.type) {
    case MSGPACK_OBJECT_NIL: {
      *rettv = (typval_T) {
        .v_type = VAR_SPECIAL,
        .v_lock = VAR_UNLOCKED,
        .vval = { .v_special = kSpecialVarNull },
      };
      break;
    }
    case MSGPACK_OBJECT_BOOLEAN: {
      *rettv = (typval_T) {
        .v_type = VAR_SPECIAL,
        .v_lock = VAR_UNLOCKED,
        .vval = {
          .v_special = mobj.via.boolean ? kSpecialVarTrue : kSpecialVarFalse
        },
      };
      break;
    }
    case MSGPACK_OBJECT_POSITIVE_INTEGER: {
      if (mobj.via.u64 <= VARNUMBER_MAX) {
        *rettv = (typval_T) {
          .v_type = VAR_NUMBER,
          .v_lock = VAR_UNLOCKED,
          .vval = { .v_number = (varnumber_T) mobj.via.u64 },
        };
      } else {
        list_T *const list = list_alloc();
        list->lv_refcount++;
        create_special_dict(rettv, kMPInteger, ((typval_T) {
          .v_type = VAR_LIST,
          .v_lock = VAR_UNLOCKED,
          .vval = { .v_list = list },
        }));
        uint64_t n = mobj.via.u64;
        list_append_number(list, 1);
        list_append_number(list, (varnumber_T) ((n >> 62) & 0x3));
        list_append_number(list, (varnumber_T) ((n >> 31) & 0x7FFFFFFF));
        list_append_number(list, (varnumber_T) (n & 0x7FFFFFFF));
      }
      break;
    }
    case MSGPACK_OBJECT_NEGATIVE_INTEGER: {
      if (mobj.via.i64 >= VARNUMBER_MIN) {
        *rettv = (typval_T) {
          .v_type = VAR_NUMBER,
          .v_lock = VAR_UNLOCKED,
          .vval = { .v_number = (varnumber_T) mobj.via.i64 },
        };
      } else {
        list_T *const list = list_alloc();
        list->lv_refcount++;
        create_special_dict(rettv, kMPInteger, ((typval_T) {
          .v_type = VAR_LIST,
          .v_lock = VAR_UNLOCKED,
          .vval = { .v_list = list },
        }));
        uint64_t n = -((uint64_t) mobj.via.i64);
        list_append_number(list, -1);
        list_append_number(list, (varnumber_T) ((n >> 62) & 0x3));
        list_append_number(list, (varnumber_T) ((n >> 31) & 0x7FFFFFFF));
        list_append_number(list, (varnumber_T) (n & 0x7FFFFFFF));
      }
      break;
    }
    case MSGPACK_OBJECT_FLOAT: {
      *rettv = (typval_T) {
        .v_type = VAR_FLOAT,
        .v_lock = VAR_UNLOCKED,
        .vval = { .v_float = mobj.via.f64 },
      };
      break;
    }
    case MSGPACK_OBJECT_STR: {
      list_T *const list = list_alloc();
      list->lv_refcount++;
      create_special_dict(rettv, kMPString, ((typval_T) {
        .v_type = VAR_LIST,
        .v_lock = VAR_UNLOCKED,
        .vval = { .v_list = list },
      }));
      if (encode_list_write((void *) list, mobj.via.str.ptr, mobj.via.str.size)
          == -1) {
        return FAIL;
      }
      break;
    }
    case MSGPACK_OBJECT_BIN: {
      if (memchr(mobj.via.bin.ptr, NUL, mobj.via.bin.size) == NULL) {
        *rettv = (typval_T) {
          .v_type = VAR_STRING,
          .v_lock = VAR_UNLOCKED,
          .vval = { .v_string = xmemdupz(mobj.via.bin.ptr, mobj.via.bin.size) },
        };
        break;
      }
      list_T *const list = list_alloc();
      list->lv_refcount++;
      create_special_dict(rettv, kMPBinary, ((typval_T) {
        .v_type = VAR_LIST,
        .v_lock = VAR_UNLOCKED,
        .vval = { .v_list = list },
      }));
      if (encode_list_write((void *) list, mobj.via.bin.ptr, mobj.via.bin.size)
          == -1) {
        return FAIL;
      }
      break;
    }
    case MSGPACK_OBJECT_ARRAY: {
      list_T *const list = list_alloc();
      list->lv_refcount++;
      *rettv = (typval_T) {
        .v_type = VAR_LIST,
        .v_lock = VAR_UNLOCKED,
        .vval = { .v_list = list },
      };
      for (size_t i = 0; i < mobj.via.array.size; i++) {
        listitem_T *const li = listitem_alloc();
        li->li_tv.v_type = VAR_UNKNOWN;
        list_append(list, li);
        if (msgpack_to_vim(mobj.via.array.ptr[i], &li->li_tv) == FAIL) {
          return FAIL;
        }
      }
      break;
    }
    case MSGPACK_OBJECT_MAP: {
      for (size_t i = 0; i < mobj.via.map.size; i++) {
        if (mobj.via.map.ptr[i].key.type != MSGPACK_OBJECT_STR
            || mobj.via.map.ptr[i].key.via.str.size == 0
            || memchr(mobj.via.map.ptr[i].key.via.str.ptr, NUL,
                      mobj.via.map.ptr[i].key.via.str.size) != NULL) {
          goto msgpack_to_vim_generic_map;
        }
      }
      dict_T *const dict = dict_alloc();
      dict->dv_refcount++;
      *rettv = (typval_T) {
        .v_type = VAR_DICT,
        .v_lock = VAR_UNLOCKED,
        .vval = { .v_dict = dict },
      };
      for (size_t i = 0; i < mobj.via.map.size; i++) {
        dictitem_T *const di = xmallocz(offsetof(dictitem_T, di_key)
                                        + mobj.via.map.ptr[i].key.via.str.size);
        memcpy(&di->di_key[0], mobj.via.map.ptr[i].key.via.str.ptr,
               mobj.via.map.ptr[i].key.via.str.size);
        di->di_tv.v_type = VAR_UNKNOWN;
        if (dict_add(dict, di) == FAIL) {
          // Duplicate key: fallback to generic map
          clear_tv(rettv);
          xfree(di);
          goto msgpack_to_vim_generic_map;
        }
        if (msgpack_to_vim(mobj.via.map.ptr[i].val, &di->di_tv) == FAIL) {
          return FAIL;
        }
      }
      break;
msgpack_to_vim_generic_map: {}
      list_T *const list = list_alloc();
      list->lv_refcount++;
      create_special_dict(rettv, kMPMap, ((typval_T) {
        .v_type = VAR_LIST,
        .v_lock = VAR_UNLOCKED,
        .vval = { .v_list = list },
      }));
      for (size_t i = 0; i < mobj.via.map.size; i++) {
        list_T *const kv_pair = list_alloc();
        list_append_list(list, kv_pair);
        listitem_T *const key_li = listitem_alloc();
        key_li->li_tv.v_type = VAR_UNKNOWN;
        list_append(kv_pair, key_li);
        listitem_T *const val_li = listitem_alloc();
        val_li->li_tv.v_type = VAR_UNKNOWN;
        list_append(kv_pair, val_li);
        if (msgpack_to_vim(mobj.via.map.ptr[i].key, &key_li->li_tv) == FAIL) {
          return FAIL;
        }
        if (msgpack_to_vim(mobj.via.map.ptr[i].val, &val_li->li_tv) == FAIL) {
          return FAIL;
        }
      }
      break;
    }
    case MSGPACK_OBJECT_EXT: {
      list_T *const list = list_alloc();
      list->lv_refcount++;
      list_append_number(list, mobj.via.ext.type);
      list_T *const ext_val_list = list_alloc();
      list_append_list(list, ext_val_list);
      create_special_dict(rettv, kMPExt, ((typval_T) {
        .v_type = VAR_LIST,
        .v_lock = VAR_UNLOCKED,
        .vval = { .v_list = list },
      }));
      if (encode_list_write((void *) ext_val_list, mobj.via.ext.ptr,
                            mobj.via.ext.size) == -1) {
        return FAIL;
      }
      break;
    }
  }
  return OK;
}
