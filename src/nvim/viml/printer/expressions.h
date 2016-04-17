#ifndef NVIM_VIML_PRINTER_EXPRESSIONS_H
#define NVIM_VIML_PRINTER_EXPRESSIONS_H

#include "nvim/viml/parser/expressions.h"
#include "nvim/viml/printer/printer.h"
#include "nvim/viml/dumpers/dumpers.h"

/// Options passed to expressions dumper
typedef struct {
  const ExprStyleOptions style;  ///< Options that define style.
  const char *string;            ///< Saved version of expression string.
} ExprPrinterOptions;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/printer/expressions.h.generated.h"
#endif
#endif  // NVIM_VIML_PRINTER_EXPRESSIONS_H
