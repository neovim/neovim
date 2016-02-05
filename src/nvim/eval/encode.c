/// @file encode.c
///
/// File containing functions for encoding and decoding VimL values.
///
/// Split out from eval.c.

#include <msgpack.h>
#include <inttypes.h>
#include <assert.h>

#include "nvim/eval/encode.h"
#include "nvim/buffer_defs.h"  // vimconv_T
#include "nvim/eval.h"
#include "nvim/eval_defs.h"
#include "nvim/garray.h"
#include "nvim/mbyte.h"
#include "nvim/message.h"
#include "nvim/charset.h"  // vim_isprintc()
#include "nvim/macros.h"
#include "nvim/ascii.h"
#include "nvim/vim.h"  // For _()
#include "nvim/lib/kvec.h"

#define ga_concat(a, b) ga_concat(a, (char_u *)b)
#define utf_ptr2char(b) utf_ptr2char((char_u *)b)
#define utf_ptr2len(b) ((size_t)utf_ptr2len((char_u *)b))
#define utf_char2len(b) ((size_t)utf_char2len(b))
#define string_convert(a, b, c) \
      ((char *)string_convert((vimconv_T *)a, (char_u *)b, c))
#define convert_setup(vcp, from, to) \
    (convert_setup(vcp, (char_u *)from, (char_u *)to))

/// Structure representing current VimL to messagepack conversion state
typedef struct {
  enum {
    kMPConvDict,   ///< Convert dict_T *dictionary.
    kMPConvList,   ///< Convert list_T *list.
    kMPConvPairs,  ///< Convert mapping represented as a list_T* of pairs.
  } type;
  union {
    struct {
      dict_T *dict;    ///< Currently converted dictionary.
      hashitem_T *hi;  ///< Currently converted dictionary item.
      size_t todo;     ///< Amount of items left to process.
    } d;  ///< State of dictionary conversion.
    struct {
      list_T *list;    ///< Currently converted list.
      listitem_T *li;  ///< Currently converted list item.
    } l;  ///< State of list or generic mapping conversion.
  } data;  ///< Data to convert.
} MPConvStackVal;

/// Stack used to convert VimL values to messagepack.
typedef kvec_t(MPConvStackVal) MPConvStack;

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
  if (list->lv_last == NULL) {
    list_append_string(list, NULL, 0);
  }
  listitem_T *li = list->lv_last;
  do {
    const char *line_start = line_end;
    line_end = xmemscan(line_start, NL, (size_t) (end - line_start));
    if (line_end == line_start) {
      list_append_allocated_string(list, NULL);
    } else {
      const size_t line_length = (size_t) (line_end - line_start);
      char *str;
      if (li == NULL) {
        str = xmemdupz(line_start, line_length);
      } else {
        const size_t li_len = (li->li_tv.vval.v_string == NULL
                               ? 0
                               : STRLEN(li->li_tv.vval.v_string));
        li->li_tv.vval.v_string = xrealloc(li->li_tv.vval.v_string,
                                           li_len + line_length + 1);
        str = (char *) li->li_tv.vval.v_string + li_len;
        memmove(str, line_start, line_length);
        str[line_length] = 0;
      }
      for (size_t i = 0; i < line_length; i++) {
        if (str[i] == NUL) {
          str[i] = NL;
        }
      }
      if (li == NULL) {
        list_append_allocated_string(list, str);
      } else {
        li = NULL;
      }
      if (line_end == end - 1) {
        list_append_allocated_string(list, NULL);
      }
    }
    line_end++;
  } while (line_end < end);
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
      *p++ = (ch == NL ? NUL : ch);
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

/// Code for checking whether container references itself
///
/// @param[in,out]  val  Container to check.
/// @param  copyID_attr  Name of the container attribute that holds copyID.
///                      After checking whether value of this attribute is
///                      copyID (variable) it is set to copyID.
#define CHECK_SELF_REFERENCE(val, copyID_attr, conv_type) \
    do { \
      if ((val)->copyID_attr == copyID) { \
        CONV_RECURSE((val), conv_type); \
      } \
      (val)->copyID_attr = copyID; \
    } while (0)

/// Define functions which convert VimL value to something else
///
/// Creates function `vim_to_{name}(firstargtype firstargname, typval_T *const
/// tv)` which returns OK or FAIL and helper functions.
///
/// @param  firstargtype  Type of the first argument. It will be used to return
///                       the results.
/// @param  firstargname  Name of the first argument.
/// @param  name  Name of the target converter.
#define DEFINE_VIML_CONV_FUNCTIONS(scope, name, firstargtype, firstargname) \
static int name##_convert_one_value(firstargtype firstargname, \
                                    MPConvStack *const mpstack, \
                                    typval_T *const tv, \
                                    const int copyID, \
                                    const char *const objname) \
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT \
{ \
  switch (tv->v_type) { \
    case VAR_STRING: { \
      CONV_STRING(tv->vval.v_string, STRLEN(tv->vval.v_string)); \
      break; \
    } \
    case VAR_NUMBER: { \
      CONV_NUMBER(tv->vval.v_number); \
      break; \
    } \
    case VAR_FLOAT: { \
      CONV_FLOAT(tv->vval.v_float); \
      break; \
    } \
    case VAR_FUNC: { \
      CONV_FUNC(tv->vval.v_string); \
      break; \
    } \
    case VAR_LIST: { \
      if (tv->vval.v_list == NULL || tv->vval.v_list->lv_len == 0) { \
        CONV_EMPTY_LIST(); \
        break; \
      } \
      CHECK_SELF_REFERENCE(tv->vval.v_list, lv_copyID, kMPConvList); \
      CONV_LIST_START(tv->vval.v_list); \
      kv_push(MPConvStackVal, *mpstack, ((MPConvStackVal) { \
        .type = kMPConvList, \
        .data = { \
          .l = { \
            .list = tv->vval.v_list, \
            .li = tv->vval.v_list->lv_first, \
          }, \
        }, \
      })); \
      break; \
    } \
    case VAR_SPECIAL: { \
      switch (tv->vval.v_special) { \
        case kSpecialVarNull: { \
          CONV_NIL(); \
          break; \
        } \
        case kSpecialVarTrue: \
        case kSpecialVarFalse: { \
          CONV_BOOL(tv->vval.v_special == kSpecialVarTrue); \
          break; \
        } \
      } \
      break; \
    } \
    case VAR_DICT: { \
      if (tv->vval.v_dict == NULL \
          || tv->vval.v_dict->dv_hashtab.ht_used == 0) { \
        CONV_EMPTY_DICT(); \
        break; \
      } \
      const dictitem_T *type_di; \
      const dictitem_T *val_di; \
      if (CONV_ALLOW_SPECIAL \
          && tv->vval.v_dict->dv_hashtab.ht_used == 2 \
          && (type_di = dict_find((dict_T *) tv->vval.v_dict, \
                                  (char_u *) "_TYPE", -1)) != NULL \
          && type_di->di_tv.v_type == VAR_LIST \
          && (val_di = dict_find((dict_T *) tv->vval.v_dict, \
                                 (char_u *) "_VAL", -1)) != NULL) { \
        size_t i; \
        for (i = 0; i < ARRAY_SIZE(eval_msgpack_type_lists); i++) { \
          if (type_di->di_tv.vval.v_list == eval_msgpack_type_lists[i]) { \
            break; \
          } \
        } \
        if (i == ARRAY_SIZE(eval_msgpack_type_lists)) { \
          goto name##_convert_one_value_regular_dict; \
        } \
        switch ((MessagePackType) i) { \
          case kMPNil: { \
            CONV_NIL(); \
            break; \
          } \
          case kMPBoolean: { \
            if (val_di->di_tv.v_type != VAR_NUMBER) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            CONV_BOOL(val_di->di_tv.vval.v_number); \
            break; \
          } \
          case kMPInteger: { \
            const list_T *val_list; \
            varnumber_T sign; \
            varnumber_T highest_bits; \
            varnumber_T high_bits; \
            varnumber_T low_bits; \
            /* List of 4 integers; first is signed (should be 1 or -1, but */ \
            /* this is not checked), second is unsigned and have at most */ \
            /* one (sign is -1) or two (sign is 1) non-zero bits (number of */ \
            /* bits is not checked), other unsigned and have at most 31 */ \
            /* non-zero bits (number of bits is not checked).*/ \
            if (val_di->di_tv.v_type != VAR_LIST \
                || (val_list = val_di->di_tv.vval.v_list) == NULL \
                || val_list->lv_len != 4 \
                || val_list->lv_first->li_tv.v_type != VAR_NUMBER \
                || (sign = val_list->lv_first->li_tv.vval.v_number) == 0 \
                || val_list->lv_first->li_next->li_tv.v_type != VAR_NUMBER \
                || (highest_bits = \
                    val_list->lv_first->li_next->li_tv.vval.v_number) < 0 \
                || val_list->lv_last->li_prev->li_tv.v_type != VAR_NUMBER \
                || (high_bits = \
                    val_list->lv_last->li_prev->li_tv.vval.v_number) < 0 \
                || val_list->lv_last->li_tv.v_type != VAR_NUMBER \
                || (low_bits = val_list->lv_last->li_tv.vval.v_number) < 0) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            uint64_t number = ((uint64_t) (((uint64_t) highest_bits) << 62) \
                               | (uint64_t) (((uint64_t) high_bits) << 31) \
                               | (uint64_t) low_bits); \
            if (sign > 0) { \
              CONV_UNSIGNED_NUMBER(number); \
            } else { \
              CONV_NUMBER(-number); \
            } \
            break; \
          } \
          case kMPFloat: { \
            if (val_di->di_tv.v_type != VAR_FLOAT) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            CONV_FLOAT(val_di->di_tv.vval.v_float); \
            break; \
          } \
          case kMPString: \
          case kMPBinary: { \
            const bool is_string = ((MessagePackType) i == kMPString); \
            if (val_di->di_tv.v_type != VAR_LIST) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            size_t len; \
            char *buf; \
            if (!encode_vim_list_to_buf(val_di->di_tv.vval.v_list, &len, \
                                        &buf)) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            if (is_string) { \
              CONV_STR_STRING(buf, len); \
            } else { \
              CONV_STRING(buf, len); \
            } \
            xfree(buf); \
            break; \
          } \
          case kMPArray: { \
            if (val_di->di_tv.v_type != VAR_LIST) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            CHECK_SELF_REFERENCE(val_di->di_tv.vval.v_list, lv_copyID, \
                                 kMPConvList); \
            CONV_LIST_START(val_di->di_tv.vval.v_list); \
            kv_push(MPConvStackVal, *mpstack, ((MPConvStackVal) { \
              .type = kMPConvList, \
              .data = { \
                .l = { \
                  .list = val_di->di_tv.vval.v_list, \
                  .li = val_di->di_tv.vval.v_list->lv_first, \
                }, \
              }, \
            })); \
            break; \
          } \
          case kMPMap: { \
            if (val_di->di_tv.v_type != VAR_LIST) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            list_T *const val_list = val_di->di_tv.vval.v_list; \
            if (val_list == NULL || val_list->lv_len == 0) { \
              CONV_EMPTY_DICT(); \
              break; \
            } \
            for (const listitem_T *li = val_list->lv_first; li != NULL; \
                 li = li->li_next) { \
              if (li->li_tv.v_type != VAR_LIST \
                  || li->li_tv.vval.v_list->lv_len != 2) { \
                goto name##_convert_one_value_regular_dict; \
              } \
            } \
            CHECK_SELF_REFERENCE(val_list, lv_copyID, kMPConvPairs); \
            CONV_DICT_START(val_list->lv_len); \
            kv_push(MPConvStackVal, *mpstack, ((MPConvStackVal) { \
              .type = kMPConvPairs, \
              .data = { \
                .l = { \
                  .list = val_list, \
                  .li = val_list->lv_first, \
                }, \
              }, \
            })); \
            break; \
          } \
          case kMPExt: { \
            const list_T *val_list; \
            varnumber_T type; \
            if (val_di->di_tv.v_type != VAR_LIST \
                || (val_list = val_di->di_tv.vval.v_list) == NULL \
                || val_list->lv_len != 2 \
                || (val_list->lv_first->li_tv.v_type != VAR_NUMBER) \
                || (type = val_list->lv_first->li_tv.vval.v_number) > INT8_MAX \
                || type < INT8_MIN \
                || (val_list->lv_last->li_tv.v_type != VAR_LIST)) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            size_t len; \
            char *buf; \
            if (!encode_vim_list_to_buf(val_list->lv_last->li_tv.vval.v_list, \
                                        &len, &buf)) { \
              goto name##_convert_one_value_regular_dict; \
            } \
            CONV_EXT_STRING(buf, len, type); \
            xfree(buf); \
            break; \
          } \
        } \
        break; \
      } \
name##_convert_one_value_regular_dict: \
      CHECK_SELF_REFERENCE(tv->vval.v_dict, dv_copyID, kMPConvDict); \
      CONV_DICT_START(tv->vval.v_dict->dv_hashtab.ht_used); \
      kv_push(MPConvStackVal, *mpstack, ((MPConvStackVal) { \
        .type = kMPConvDict, \
        .data = { \
          .d = { \
            .dict = tv->vval.v_dict, \
            .hi = tv->vval.v_dict->dv_hashtab.ht_array, \
            .todo = tv->vval.v_dict->dv_hashtab.ht_used, \
          }, \
        }, \
      })); \
      break; \
    } \
    case VAR_UNKNOWN: { \
      EMSG2(_(e_intern2), #name "_convert_one_value()"); \
      return FAIL; \
    } \
  } \
  return OK; \
} \
\
scope int encode_vim_to_##name(firstargtype firstargname, typval_T *const tv, \
                               const char *const objname) \
  FUNC_ATTR_WARN_UNUSED_RESULT \
{ \
  const int copyID = get_copyID(); \
  MPConvStack mpstack; \
  kv_init(mpstack); \
  if (name##_convert_one_value(firstargname, &mpstack, tv, copyID, objname) \
      == FAIL) { \
    goto encode_vim_to_##name##_error_ret; \
  } \
  while (kv_size(mpstack)) { \
    MPConvStackVal *cur_mpsv = &kv_A(mpstack, kv_size(mpstack) - 1); \
    typval_T *cur_tv = NULL; \
    switch (cur_mpsv->type) { \
      case kMPConvDict: { \
        if (!cur_mpsv->data.d.todo) { \
          (void) kv_pop(mpstack); \
          cur_mpsv->data.d.dict->dv_copyID = copyID - 1; \
          CONV_DICT_END(); \
          continue; \
        } else if (cur_mpsv->data.d.todo \
                   != cur_mpsv->data.d.dict->dv_hashtab.ht_used) { \
          CONV_DICT_BETWEEN_ITEMS(); \
        } \
        while (HASHITEM_EMPTY(cur_mpsv->data.d.hi)) { \
          cur_mpsv->data.d.hi++; \
        } \
        dictitem_T *const di = HI2DI(cur_mpsv->data.d.hi); \
        cur_mpsv->data.d.todo--; \
        cur_mpsv->data.d.hi++; \
        CONV_STR_STRING(&di->di_key[0], STRLEN(&di->di_key[0])); \
        CONV_DICT_AFTER_KEY(); \
        cur_tv = &di->di_tv; \
        break; \
      } \
      case kMPConvList: { \
        if (cur_mpsv->data.l.li == NULL) { \
          (void) kv_pop(mpstack); \
          cur_mpsv->data.l.list->lv_copyID = copyID - 1; \
          CONV_LIST_END(cur_mpsv->data.l.list); \
          continue; \
        } else if (cur_mpsv->data.l.li != cur_mpsv->data.l.list->lv_first) { \
          CONV_LIST_BETWEEN_ITEMS(); \
        } \
        cur_tv = &cur_mpsv->data.l.li->li_tv; \
        cur_mpsv->data.l.li = cur_mpsv->data.l.li->li_next; \
        break; \
      } \
      case kMPConvPairs: { \
        if (cur_mpsv->data.l.li == NULL) { \
          (void) kv_pop(mpstack); \
          cur_mpsv->data.l.list->lv_copyID = copyID - 1; \
          CONV_DICT_END(); \
          continue; \
        } else if (cur_mpsv->data.l.li != cur_mpsv->data.l.list->lv_first) { \
          CONV_DICT_BETWEEN_ITEMS(); \
        } \
        const list_T *const kv_pair = cur_mpsv->data.l.li->li_tv.vval.v_list; \
        CONV_SPECIAL_DICT_KEY_CHECK(kv_pair); \
        if (name##_convert_one_value(firstargname, &mpstack, \
                                     &kv_pair->lv_first->li_tv, copyID, \
                                     objname) == FAIL) { \
          goto encode_vim_to_##name##_error_ret; \
        } \
        CONV_DICT_AFTER_KEY(); \
        cur_tv = &kv_pair->lv_last->li_tv; \
        cur_mpsv->data.l.li = cur_mpsv->data.l.li->li_next; \
        break; \
      } \
    } \
    assert(cur_tv != NULL); \
    if (name##_convert_one_value(firstargname, &mpstack, cur_tv, copyID, \
                                 objname) == FAIL) { \
      goto encode_vim_to_##name##_error_ret; \
    } \
  } \
  kv_destroy(mpstack); \
  return OK; \
encode_vim_to_##name##_error_ret: \
  kv_destroy(mpstack); \
  return FAIL; \
}

#define CONV_STRING(buf, len) \
    do { \
      const char *const buf_ = (const char *) buf; \
      if (buf == NULL) { \
        ga_concat(gap, "''"); \
      } else { \
        const size_t len_ = (len); \
        size_t num_quotes = 0; \
        for (size_t i = 0; i < len_; i++) { \
          if (buf_[i] == '\'') { \
            num_quotes++; \
          } \
        } \
        ga_grow(gap, (int) (2 + len_ + num_quotes)); \
        ga_append(gap, '\''); \
        for (size_t i = 0; i < len_; i++) { \
          if (buf_[i] == '\'') { \
            num_quotes++; \
            ga_append(gap, '\''); \
          } \
          ga_append(gap, buf_[i]); \
        } \
        ga_append(gap, '\''); \
      } \
    } while (0)

#define CONV_STR_STRING(buf, len) \
    CONV_STRING(buf, len)

#define CONV_EXT_STRING(buf, len, type)

#define CONV_NUMBER(num) \
    do { \
      char numbuf[NUMBUFLEN]; \
      vim_snprintf(numbuf, NUMBUFLEN - 1, "%" PRId64, (int64_t) (num)); \
      ga_concat(gap, numbuf); \
    } while (0)

#define CONV_FLOAT(flt) \
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
          vim_snprintf(numbuf, NUMBUFLEN - 1, "%g", flt_); \
          ga_concat(gap, (char_u *) numbuf); \
        } \
      } \
    } while (0)

#define CONV_FUNC(fun) \
    do { \
      ga_concat(gap, "function("); \
      CONV_STRING(fun, STRLEN(fun)); \
      ga_append(gap, ')'); \
    } while (0)

#define CONV_EMPTY_LIST() \
    ga_concat(gap, "[]")

#define CONV_LIST_START(lst) \
    ga_append(gap, '[')

#define CONV_EMPTY_DICT() \
    ga_concat(gap, "{}")

#define CONV_NIL() \
    ga_concat(gap, "v:null")

#define CONV_BOOL(num) \
    ga_concat(gap, ((num)? "v:true": "v:false"))

#define CONV_UNSIGNED_NUMBER(num)

#define CONV_DICT_START(len) \
    ga_append(gap, '{')

#define CONV_DICT_END() \
    ga_append(gap, '}')

#define CONV_DICT_AFTER_KEY() \
    ga_concat(gap, ": ")

#define CONV_DICT_BETWEEN_ITEMS() \
    ga_concat(gap, ", ")

#define CONV_SPECIAL_DICT_KEY_CHECK(kv_pair)

#define CONV_LIST_END(lst) \
    ga_append(gap, ']')

#define CONV_LIST_BETWEEN_ITEMS() \
    CONV_DICT_BETWEEN_ITEMS()

#define CONV_RECURSE(val, conv_type) \
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
        const MPConvStackVal mpval = kv_a(MPConvStackVal, *mpstack, backref); \
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
      vim_snprintf(ebuf, NUMBUFLEN + 6, "{E724@%zu}", backref); \
      ga_concat(gap, &ebuf[0]); \
      return OK; \
    } while (0)

#define CONV_ALLOW_SPECIAL false

DEFINE_VIML_CONV_FUNCTIONS(static, string, garray_T *const, gap)

#undef CONV_RECURSE
#define CONV_RECURSE(val, conv_type) \
    do { \
      char ebuf[NUMBUFLEN + 7]; \
      size_t backref = 0; \
      for (; backref < kv_size(*mpstack); backref++) { \
        const MPConvStackVal mpval = kv_a(MPConvStackVal, *mpstack, backref); \
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
        vim_snprintf(ebuf, NUMBUFLEN + 6, "{...@%zu}", backref); \
      } else { \
        vim_snprintf(ebuf, NUMBUFLEN + 6, "[...@%zu]", backref); \
      } \
      ga_concat(gap, &ebuf[0]); \
      return OK; \
    } while (0)

DEFINE_VIML_CONV_FUNCTIONS(, echo, garray_T *const, gap)

#undef CONV_RECURSE
#define CONV_RECURSE(val, conv_type) \
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

#undef CONV_ALLOW_SPECIAL
#define CONV_ALLOW_SPECIAL true

#undef CONV_NIL
#define CONV_NIL() \
      ga_concat(gap, "null")

#undef CONV_BOOL
#define CONV_BOOL(num) \
      ga_concat(gap, ((num)? "true": "false"))

#undef CONV_UNSIGNED_NUMBER
#define CONV_UNSIGNED_NUMBER(num) \
      do { \
        char numbuf[NUMBUFLEN]; \
        vim_snprintf(numbuf, sizeof(numbuf), "%" PRIu64, (num)); \
        ga_concat(gap, numbuf); \
      } while (0)

#undef CONV_FLOAT
#define CONV_FLOAT(flt) \
    do { \
      char numbuf[NUMBUFLEN]; \
      vim_snprintf(numbuf, NUMBUFLEN - 1, "%g", (flt)); \
      ga_concat(gap, numbuf); \
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
  const char *buf_ = buf;
  if (buf_ == NULL) {
    ga_concat(gap, "\"\"");
  } else {
    size_t len_ = len;
    char *tofree = NULL;
    if (last_p_enc != (const void *) p_enc) {
      p_enc_conv.vc_type = CONV_NONE;
      convert_setup(&p_enc_conv, p_enc, "utf-8");
      p_enc_conv.vc_fail = true;
      last_p_enc = p_enc;
    }
    if (p_enc_conv.vc_type != CONV_NONE) {
      tofree = string_convert(&p_enc_conv, buf_, &len_);
      if (tofree == NULL) {
        EMSG2(_("E474: Failed to convert string \"%s\" to UTF-8"), buf_);
        return FAIL;
      }
      buf_ = tofree;
    }
    size_t str_len = 0;
    for (size_t i = 0; i < len_;) {
      const int ch = utf_ptr2char(buf + i);
      const size_t shift = (ch == 0? 1: utf_ptr2len(buf + i));
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
            EMSG2(_("E474: String \"%s\" contains byte that does not start any "
                    "UTF-8 character"), buf_);
            return FAIL;
          } else if ((0xD800 <= ch && ch <= 0xDB7F)
                     || (0xDC00 <= ch && ch <= 0xDFFF)) {
            EMSG2(_("E474: UTF-8 string contains code point which belongs "
                    "to surrogate pairs"), buf_);
            return FAIL;
          } else if (vim_isprintc(ch)) {
            str_len += shift;
          } else {
            str_len += ((sizeof("\\u1234") - 1) * (1 + (ch > 0xFFFF)));
          }
          break;
        }
      }
    }
    ga_append(gap, '"');
    ga_grow(gap, (int) str_len);
    for (size_t i = 0; i < len_;) {
      const int ch = utf_ptr2char(buf + i);
      const size_t shift = (ch == 0? 1: utf_char2len(ch));
      assert(shift > 0);
      // Is false on invalid unicode, but this should already be handled.
      assert(ch == 0 || shift == utf_ptr2len(buf + i));
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
          if (vim_isprintc(ch)) {
            ga_concat_len(gap, buf + i, shift);
          } else if (ch < SURROGATE_FIRST_CHAR) {
            ga_concat_len(gap, ((const char[]) {
                '\\', 'u',
                xdigits[(ch >> (4 * 3)) & 0xF],
                xdigits[(ch >> (4 * 2)) & 0xF],
                xdigits[(ch >> (4 * 1)) & 0xF],
                xdigits[(ch >> (4 * 0)) & 0xF],
            }), sizeof("\\u1234") - 1);
          } else {
            uint32_t tmp = (uint32_t) ch - SURROGATE_FIRST_CHAR;
            uint16_t hi = SURROGATE_HI_START + ((tmp >> 10) & ((1 << 10) - 1));
            uint16_t lo = SURROGATE_LO_END + ((tmp >>  0) & ((1 << 10) - 1));
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

#undef CONV_STRING
#define CONV_STRING(buf, len) \
    do { \
      if (convert_to_json_string(gap, (const char *) (buf), (len)) != OK) { \
        return FAIL; \
      } \
    } while (0)

#undef CONV_EXT_STRING
#define CONV_EXT_STRING(buf, len, type) \
    do { \
      xfree(buf); \
      EMSG(_("E474: Unable to convert EXT string to JSON")); \
      return FAIL; \
    } while (0)

#undef CONV_FUNC
#define CONV_FUNC(fun) \
    return conv_error(_("E474: Error while dumping %s, %s: " \
                        "attempt to dump function reference"), \
                      mpstack, objname)

/// Check whether given key can be used in jsonencode()
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

#undef CONV_SPECIAL_DICT_KEY_CHECK
#define CONV_SPECIAL_DICT_KEY_CHECK(kv_pair) \
    do { \
      if (!check_json_key(&kv_pair->lv_first->li_tv)) { \
        EMSG(_("E474: Invalid key in special dictionary")); \
        return FAIL; \
      } \
    } while (0)

DEFINE_VIML_CONV_FUNCTIONS(static, json, garray_T *const, gap)

#undef CONV_STRING
#undef CONV_STR_STRING
#undef CONV_EXT_STRING
#undef CONV_NUMBER
#undef CONV_FLOAT
#undef CONV_FUNC
#undef CONV_EMPTY_LIST
#undef CONV_LIST_START
#undef CONV_EMPTY_DICT
#undef CONV_NIL
#undef CONV_BOOL
#undef CONV_UNSIGNED_NUMBER
#undef CONV_DICT_START
#undef CONV_DICT_END
#undef CONV_DICT_AFTER_KEY
#undef CONV_DICT_BETWEEN_ITEMS
#undef CONV_SPECIAL_DICT_KEY_CHECK
#undef CONV_LIST_END
#undef CONV_LIST_BETWEEN_ITEMS
#undef CONV_RECURSE
#undef CONV_ALLOW_SPECIAL

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

#define CONV_STRING(buf, len) \
    do { \
      if (buf == NULL) { \
        msgpack_pack_bin(packer, 0); \
      } else { \
        const size_t len_ = (len); \
        msgpack_pack_bin(packer, len_); \
        msgpack_pack_bin_body(packer, buf, len_); \
      } \
    } while (0)

#define CONV_STR_STRING(buf, len) \
    do { \
      if (buf == NULL) { \
        msgpack_pack_str(packer, 0); \
      } else { \
        const size_t len_ = (len); \
        msgpack_pack_str(packer, len_); \
        msgpack_pack_str_body(packer, buf, len_); \
      } \
    } while (0)

#define CONV_EXT_STRING(buf, len, type) \
    do { \
      if (buf == NULL) { \
        msgpack_pack_ext(packer, 0, (int8_t) type); \
      } else { \
        const size_t len_ = (len); \
        msgpack_pack_ext(packer, len_, (int8_t) type); \
        msgpack_pack_ext_body(packer, buf, len_); \
      } \
    } while (0)

#define CONV_NUMBER(num) \
    msgpack_pack_int64(packer, (int64_t) (num))

#define CONV_FLOAT(flt) \
    msgpack_pack_double(packer, (double) (flt))

#define CONV_FUNC(fun) \
    return conv_error(_("E951: Error while dumping %s, %s: " \
                        "attempt to dump function reference"), \
                      mpstack, objname)

#define CONV_EMPTY_LIST() \
    msgpack_pack_array(packer, 0)

#define CONV_LIST_START(lst) \
    msgpack_pack_array(packer, (size_t) (lst)->lv_len)

#define CONV_EMPTY_DICT() \
    msgpack_pack_map(packer, 0)

#define CONV_NIL() \
    msgpack_pack_nil(packer)

#define CONV_BOOL(num) \
    do { \
      if ((num)) { \
        msgpack_pack_true(packer); \
      } else { \
        msgpack_pack_false(packer); \
      } \
    } while (0)

#define CONV_UNSIGNED_NUMBER(num) \
    msgpack_pack_uint64(packer, (num))

#define CONV_DICT_START(len) \
    msgpack_pack_map(packer, (size_t) (len))

#define CONV_DICT_END()

#define CONV_DICT_AFTER_KEY()

#define CONV_DICT_BETWEEN_ITEMS()

#define CONV_SPECIAL_DICT_KEY_CHECK(kv_pair)

#define CONV_LIST_END(lst)

#define CONV_LIST_BETWEEN_ITEMS()

#define CONV_RECURSE(val, conv_type) \
    return conv_error(_("E952: Unable to dump %s: " \
                        "container references itself in %s"), \
                      mpstack, objname)

#define CONV_ALLOW_SPECIAL true

DEFINE_VIML_CONV_FUNCTIONS(, msgpack, msgpack_packer *const, packer)

#undef CONV_STRING
#undef CONV_STR_STRING
#undef CONV_EXT_STRING
#undef CONV_NUMBER
#undef CONV_FLOAT
#undef CONV_FUNC
#undef CONV_EMPTY_LIST
#undef CONV_LIST_START
#undef CONV_EMPTY_DICT
#undef CONV_NIL
#undef CONV_BOOL
#undef CONV_UNSIGNED_NUMBER
#undef CONV_DICT_START
#undef CONV_DICT_END
#undef CONV_DICT_AFTER_KEY
#undef CONV_DICT_BETWEEN_ITEMS
#undef CONV_SPECIAL_DICT_KEY_CHECK
#undef CONV_LIST_END
#undef CONV_LIST_BETWEEN_ITEMS
#undef CONV_RECURSE
#undef CONV_ALLOW_SPECIAL
