#include <stddef.h>
#include <assert.h>

#include "nvim/vim.h"
#include "nvim/viml/translator/translator.h"
#include "nvim/viml/dumpers/dumpers.h"

#include "nvim/viml/translator/translator.c.h"

/// Get amount of memory needed for translated VimL script
///
/// @param[in]  pres  Parsing result.
/// @param[in]  o     Context in which command will be translated.
///
/// @return Amount of memory that is greater then or equal to the minimum amount
///         of memory needed to translate given script.
size_t stranslate_len(TranslationSource o, const ParserResult *const pres)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t (*stranslate_len_impl)(TranslationContext, const ParserResult *const);
  switch (o) {
    case kTransUser: {
      stranslate_len_impl = &stranslate_input_len;
      break;
    }
    case kTransScript: {
      stranslate_len_impl = &stranslate_script_len;
      break;
    }
    case kTransFunc: {
      // This context can only be used from other contexts
      assert(false);
    }
  }
  TranslationContext tc = {
    .tsrc = o
  };
  return stranslate_len_impl(tc, pres);
}

/// Translate VimL script to given location
///
/// @param[in]   pres  Parsing result.
/// @param[in]   o     Context in which command will be translated.
/// @param[out]  pp    Pointer to the memory where script should be translated
///                    to.
void stranslate(TranslationSource o, const ParserResult *const pres, char **pp)
  FUNC_ATTR_NONNULL_ALL
{
  void (*stranslate_impl)(TranslationContext, const ParserResult *const,
                          char **);
  switch (o) {
    case kTransUser: {
      stranslate_impl = &stranslate_input;
      break;
    }
    case kTransScript: {
      stranslate_impl = &stranslate_script;
      break;
    }
    case kTransFunc: {
      // This context can only be used from other contexts
      assert(false);
    }
  }
  TranslationContext tc = {
    .tsrc = o
  };
  stranslate_impl(tc, pres, pp);
}

/// Translate VimL script using given write
///
/// @param[in]  pres    Parsing result.
/// @param[in]  o       Context in which command will be translated.
/// @param[in]  write   Function used to write the result.
/// @param[in]  cookie  Last argument to that function.
///
/// @return OK in case of success, FAIL otherwise.
int translate(TranslationSource o, const ParserResult *const pres,
              Writer write, void *cookie)
  FUNC_ATTR_NONNULL_ALL
{
  int (*translate_impl)(TranslationContext, const ParserResult *const,
                        Writer, void *);
  switch (o) {
    case kTransUser: {
      translate_impl = &translate_input;
      break;
    }
    case kTransScript: {
      translate_impl = &translate_script;
      break;
    }
    case kTransFunc: {
      // This context can only be used from other contexts
      assert(false);
    }
  }
  TranslationContext tc = {
    .tsrc = o
  };
  return translate_impl(tc, pres, write, cookie);
}
