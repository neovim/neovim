#ifndef NVIM_VIML_PRINTER_EX_COMMANDS_H
#define NVIM_VIML_PRINTER_EX_COMMANDS_H

#include "nvim/viml/parser/ex_commands.h"
#include "nvim/viml/printer/printer.h"
#include "nvim/viml/dumpers/dumpers.h"

typedef void (*VoidFuncRef)(void);

/// Structure describing a single highlight property which will be dumped
typedef struct {
  VoidFuncRef prop_dump;  ///< Pointer to the dumper function.
  const char *prop_name;  ///< Property name.
  const int prop_idx;     ///< Property index in node->args array.
} PropertyDef;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/printer/ex_commands.h.generated.h"
#endif
#endif  // NVIM_VIML_PRINTER_EX_COMMANDS_H
