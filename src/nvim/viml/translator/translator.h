#ifndef NVIM_VIML_TRANSLATOR_TRANSLATOR_H
#define NVIM_VIML_TRANSLATOR_TRANSLATOR_H

#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/parser/ex_commands.h"
#include "nvim/viml/dumpers/dumpers.h"

/// Lists possible sources of the translated strings
typedef enum {
  kTransUser = 0,  ///< Typed Ex command argument.
  kTransScript,    ///< .vim file.
  kTransFunc,      ///< :function definition.
} TranslationSource;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/translator/translator.h.generated.h"
#endif
#endif  // NVIM_VIML_TRANSLATOR_TRANSLATOR_H
