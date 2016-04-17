#ifndef NVIM_VIML_TESTHELPERS_OBJECT_C_H
#include <stdint.h>

#include "nvim/api/private/defs.h"
#include "nvim/viml/dumpers/dumpers.h"

#if !defined(CH_MACROS_DEFINE_LENGTH) && !defined(CH_MACROS_DEFINE_FWRITE)
# define CH_MACROS_DEFINE_LENGTH
# include "nvim/viml/testhelpers/object.c.h"
# undef CH_MACROS_DEFINE_LENGTH
#elif !defined(CH_MACROS_DEFINE_FWRITE)
# undef CH_MACROS_DEFINE_LENGTH
# define CH_MACROS_DEFINE_FWRITE
# include "nvim/viml/testhelpers/object.c.h"  // NOLINT
# undef CH_MACROS_DEFINE_FWRITE
# define CH_MACROS_DEFINE_LENGTH
#endif
#define NVIM_VIML_TESTHELPERS_OBJECT_C_H

#if !defined(NVIM_VIML_DUMPERS_CH_MACROS)
# define CH_MACROS_OPTIONS_TYPE const int
# define CH_MACROS_INDENT_STR "  "
#endif
#include "nvim/viml/dumpers/ch_macros.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/testhelpers/object.c.h.generated.h"
#endif

static FDEC(dump_obj, const Object obj, size_t indent)
{
  FUNCTION_START;
  WINDENT(indent);
  switch (obj.type) {
    case kObjectTypeNil: {
      WS("nil");
      break;
    }
    case kObjectTypeBoolean: {
      if (obj.data.boolean) {
        WS("true");
      } else {
        WS("false");
      }
      break;
    }
    case kObjectTypeInteger: {
      WS("number: ");
      F_NOOPT(dump_number, (intmax_t) obj.data.integer);
      break;
    }
    case kObjectTypeFloat: {
      char buf[10];
      WS("float: ");
      snprintf(&(buf[0]), sizeof(buf), "%+.2e", obj.data.floating);
      W_LEN(buf, 9);
      break;
    }
    case kObjectTypeString: {
      WS("string: ");
      F_NOOPT(dump_unumber, (uintmax_t) obj.data.string.size);
      WS(": ");
      W_LEN(obj.data.string.data, obj.data.string.size);
      break;
    }
#define DUMP_ID_TYPE(type, member) \
    case type: { \
      WS(#member ": "); \
      F_NOOPT(dump_unumber, (uintmax_t) obj.data.member); \
      break; \
    }
    DUMP_ID_TYPE(kObjectTypeBuffer, buffer)
    DUMP_ID_TYPE(kObjectTypeWindow, window)
    DUMP_ID_TYPE(kObjectTypeTabpage, tabpage)
#undef DUMP_ID_TYPE
    case kObjectTypeArray: {
      WS("array: {{{\n");
      for (size_t i = 0; i < obj.data.array.size; i++) {
        F(dump_obj, obj.data.array.items[i], indent + 1);
      }
      WINDENT(indent);
      WS("}}}");
      break;
    }
    case kObjectTypeDictionary: {
      WS("dictionary: {{{\n");
      for (size_t i = 0; i < obj.data.dictionary.size; i++) {
        KeyValuePair item = obj.data.dictionary.items[i];
        WINDENT(indent + 1);
        F_NOOPT(dump_unumber, (uintmax_t) item.key.size);
        WS(": ");
        W_LEN(item.key.data, item.key.size);
        WS(":\n");
        F(dump_obj, obj.data.dictionary.items[i].value, indent + 2);
      }
      WINDENT(indent);
      WS("}}}");
      break;
    }
  }
  WS("\n");
  FUNCTION_END;
}
#endif  // NVIM_VIML_TESTHELPERS_OBJECT_C_H
