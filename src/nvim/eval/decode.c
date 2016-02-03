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
  size_t stack_index;  ///< Index of current container in stack.
  typval_T container;  ///< Container. Either VAR_LIST, VAR_DICT or VAR_LIST
                       ///< which is _VAL from special dictionary.
} ContainerStackItem;

typedef kvec_t(typval_T) ValuesStack;
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
  type_di->di_tv.v_lock = 0;
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

/// Helper function used for working with stack vectors used by JSON decoder
///
/// @param[in]  obj  New object.
/// @param[out]  stack  Object stack.
/// @param[out]  container_stack  Container objects stack.
/// @param[in]  p  Position in string which is currently being parsed.
///
/// @return OK in case of success, FAIL in case of error.
static inline int json_decoder_pop(typval_T obj, ValuesStack *const stack,
                                   ContainerStack *const container_stack,
                                   const char *const p)
  FUNC_ATTR_NONNULL_ALL
{
  if (kv_size(*container_stack) == 0) {
    kv_push(typval_T, *stack, obj);
    return OK;
  }
  ContainerStackItem last_container = kv_last(*container_stack);
  if (obj.v_type == last_container.container.v_type
      // vval.v_list and vval.v_dict should have the same size and offset
      && ((void *) obj.vval.v_list
          == (void *) last_container.container.vval.v_list)) {
    kv_pop(*container_stack);
    last_container = kv_last(*container_stack);
  }
  if (last_container.container.v_type == VAR_LIST) {
    listitem_T *obj_li = listitem_alloc();
    obj_li->li_tv = obj;
    list_append(last_container.container.vval.v_list, obj_li);
  } else if (last_container.stack_index == kv_size(*stack) - 2) {
    typval_T key = kv_pop(*stack);
    if (key.v_type != VAR_STRING) {
      assert(false);
    } else if (key.vval.v_string == NULL || *key.vval.v_string == NUL) {
      // TODO: fall back to special dict in case of empty key
      EMSG(_("E474: Empty key"));
      clear_tv(&obj);
      return FAIL;
    }
    dictitem_T *obj_di = dictitem_alloc(key.vval.v_string);
    clear_tv(&key);
    if (dict_add(last_container.container.vval.v_dict, obj_di)
        == FAIL) {
      // TODO: fall back to special dict in case of duplicate keys
      EMSG(_("E474: Duplicate key"));
      dictitem_free(obj_di);
      clear_tv(&obj);
      return FAIL;
    }
    obj_di->di_tv = obj;
  } else {
    // Object with key only
    if (obj.v_type != VAR_STRING) {
      EMSG2(_("E474: Expected string key: %s"), p);
      clear_tv(&obj);
      return FAIL;
    }
    kv_push(typval_T, *stack, obj);
  }
  return OK;
}

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
  vimconv_T conv;
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
#define POP(obj) \
  do { \
    if (json_decoder_pop(obj, &stack, &container_stack, p) == FAIL) { \
      goto json_decode_string_fail; \
    } \
  } while (0)
  const char *p = buf;
  for (; p < e; p++) {
    switch (*p) {
      case '}':
      case ']': {
        if (kv_size(container_stack) == 0) {
          EMSG2(_("E474: No container to close: %s"), p);
          goto json_decode_string_fail;
        }
        ContainerStackItem last_container = kv_last(container_stack);
        if (*p == '}' && last_container.container.v_type != VAR_DICT) {
          EMSG2(_("E474: Closing list with figure brace: %s"), p);
          goto json_decode_string_fail;
        } else if (*p == ']' && last_container.container.v_type != VAR_LIST) {
          EMSG2(_("E474: Closing dictionary with bracket: %s"), p);
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
          kv_pop(container_stack);
          goto json_decode_string_after_cycle;
        } else {
          typval_T obj = kv_pop(stack);
          POP(obj);
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
        } if (last_container.container.v_type == VAR_DICT
            && last_container.stack_index != kv_size(stack) - 1) {
          EMSG2(_("E474: Using comma in place of colon: %s"), p);
          goto json_decode_string_fail;
        } else if ((last_container.container.v_type == VAR_DICT
                    && (last_container.container.vval.v_dict->dv_hashtab.ht_used
                        == 0))
                   || (last_container.container.v_type == VAR_LIST
                       && last_container.container.vval.v_list->lv_len == 0)) {
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
        POP(get_vim_var_tv(VV_NULL));
        break;
      }
      case 't': {
        if (strncmp(p + 1, "rue", 3) != 0) {
          EMSG2(_("E474: Expected true: %s"), p);
          goto json_decode_string_fail;
        }
        p += 3;
        POP(get_vim_var_tv(VV_TRUE));
        break;
      }
      case 'f': {
        if (strncmp(p + 1, "alse", 4) != 0) {
          EMSG2(_("E474: Expected false: %s"), p);
          goto json_decode_string_fail;
        }
        p += 4;
        POP(get_vim_var_tv(VV_FALSE));
        break;
      }
      case '"': {
        size_t len = 0;
        const char *s;
        for (s = ++p; p < e && *p != '"'; p++) {
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
                // One UTF-8 character below U+10000 can take up to 3 bytes
                len += 3;
                p += 4;
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
                break;
              }
              default: {
                EMSG2(_("E474: Unknown escape sequence: %s"), p - 1);
                goto json_decode_string_fail;
              }
            }
          } else {
            len++;
          }
        }
        if (*p != '"') {
          EMSG2(_("E474: Expected string end: %s"), buf);
          goto json_decode_string_fail;
        }
        char *str = xmalloc(len + 1);
        uint16_t fst_in_pair = 0;
        char *str_end = str;
        for (const char *t = s; t < p; t++) {
          if (t[0] != '\\' || t[1] != 'u') {
            if (fst_in_pair != 0) {
              str_end += utf_char2bytes((int) fst_in_pair, (char_u *) str_end);
              fst_in_pair = 0;
            }
          }
          if (*t == '\\') {
            t++;
            switch (*t) {
              case 'u': {
                char ubuf[] = { t[1], t[2], t[3], t[4], 0 };
                t += 4;
                unsigned long ch;
                vim_str2nr((char_u *) ubuf, NULL, NULL, 0, 0, 2, NULL, &ch);
                if (0xD800UL <= ch && ch <= 0xDB7FUL) {
                  fst_in_pair = (uint16_t) ch;
                } else if (0xDC00ULL <= ch && ch <= 0xDB7FUL) {
                  if (fst_in_pair != 0) {
                    int full_char = (
                        (int) (ch - 0xDC00UL)
                        + (((int) (fst_in_pair - 0xD800)) << 10)
                    );
                    str_end += utf_char2bytes(full_char, (char_u *) str_end);
                  }
                } else {
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
        if (fst_in_pair != 0) {
          str_end += utf_char2bytes((int) fst_in_pair, (char_u *) str_end);
        }
        if (conv.vc_type != CONV_NONE) {
          size_t len = (size_t) (str_end - str);
          char *const new_str = (char *) string_convert(&conv, (char_u *) str,
                                                        &len);
          if (new_str == NULL) {
            EMSG2(_("E474: Failed to convert string \"%s\" from UTF-8"), str);
            xfree(str);
            goto json_decode_string_fail;
          }
          xfree(str);
          str = new_str;
          str_end = new_str + len;
        }
        *str_end = NUL;
        // TODO: return special string in case of NUL bytes
        POP(((typval_T) {
          .v_type = VAR_STRING,
          .vval = { .v_string = (char_u *) str, },
        }));
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
          vim_str2nr((char_u *) s, NULL, NULL, 0, 0, 0, &nr, NULL);
          tv.vval.v_number = (varnumber_T) nr;
        }
        POP(tv);
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
          .container = tv,
        }));
        kv_push(typval_T, stack, tv);
        break;
      }
      case '{': {
        dict_T *dict = dict_alloc();
        dict->dv_refcount++;
        typval_T tv = {
          .v_type = VAR_DICT,
          .v_lock = VAR_UNLOCKED,
          .vval = { .v_dict = dict },
        };
        kv_push(ContainerStackItem, container_stack, ((ContainerStackItem) {
          .stack_index = kv_size(stack),
          .container = tv,
        }));
        kv_push(typval_T, stack, tv);
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
#undef POP
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
    clear_tv(&kv_pop(stack));
  }
json_decode_string_ret:
  if (ret != FAIL) {
    assert(kv_size(stack) == 1);
    *rettv = kv_pop(stack);
  }
  kv_destroy(stack);
  kv_destroy(container_stack);
  return ret;
}

/// Convert msgpack object to a VimL one
int msgpack_to_vim(const msgpack_object mobj, typval_T *const rettv)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  switch (mobj.type) {
    case MSGPACK_OBJECT_NIL: {
      *rettv = get_vim_var_tv(VV_NULL);
      break;
    }
    case MSGPACK_OBJECT_BOOLEAN: {
      *rettv = get_vim_var_tv(mobj.via.boolean ? VV_TRUE : VV_FALSE);
      break;
    }
    case MSGPACK_OBJECT_POSITIVE_INTEGER: {
      if (mobj.via.u64 <= VARNUMBER_MAX) {
        *rettv = (typval_T) {
          .v_type = VAR_NUMBER,
          .v_lock = 0,
          .vval = { .v_number = (varnumber_T) mobj.via.u64 },
        };
      } else {
        list_T *const list = list_alloc();
        list->lv_refcount++;
        create_special_dict(rettv, kMPInteger, ((typval_T) {
          .v_type = VAR_LIST,
          .v_lock = 0,
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
          .v_lock = 0,
          .vval = { .v_number = (varnumber_T) mobj.via.i64 },
        };
      } else {
        list_T *const list = list_alloc();
        list->lv_refcount++;
        create_special_dict(rettv, kMPInteger, ((typval_T) {
          .v_type = VAR_LIST,
          .v_lock = 0,
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
        .v_lock = 0,
        .vval = { .v_float = mobj.via.f64 },
      };
      break;
    }
    case MSGPACK_OBJECT_STR: {
      list_T *const list = list_alloc();
      list->lv_refcount++;
      create_special_dict(rettv, kMPString, ((typval_T) {
        .v_type = VAR_LIST,
        .v_lock = 0,
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
          .v_lock = 0,
          .vval = { .v_string = xmemdupz(mobj.via.bin.ptr, mobj.via.bin.size) },
        };
        break;
      }
      list_T *const list = list_alloc();
      list->lv_refcount++;
      create_special_dict(rettv, kMPBinary, ((typval_T) {
        .v_type = VAR_LIST,
        .v_lock = 0,
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
        .v_lock = 0,
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
        .v_lock = 0,
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
        .v_lock = 0,
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
        .v_lock = 0,
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
