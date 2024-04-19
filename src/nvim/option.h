#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>  // IWYU pragma: keep

#include "nvim/api/private/defs.h"  // IWYU pragma: keep
#include "nvim/api/private/helpers.h"
#include "nvim/cmdexpand_defs.h"  // IWYU pragma: keep
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/option_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// The options that are local to a window or buffer have "indir" set to one of
/// these values.  Special values:
/// PV_NONE: global option.
/// PV_WIN is added: window-local option
/// PV_BUF is added: buffer-local option
/// PV_BOTH is added: global option which also has a local value.
enum {
  PV_BOTH = 0x1000,
  PV_WIN  = 0x2000,
  PV_BUF  = 0x4000,
  PV_MASK = 0x0fff,
};
#define OPT_WIN(x)  (idopt_T)(PV_WIN + (int)(x))
#define OPT_BUF(x)  (idopt_T)(PV_BUF + (int)(x))
#define OPT_BOTH(x) (idopt_T)(PV_BOTH + (int)(x))

/// WV_ and BV_ values get typecasted to this for the "indir" field
typedef enum {
  PV_NONE = 0,
  PV_MAXVAL = 0xffff,  ///< to avoid warnings for value out of range
} idopt_T;

// Options local to a window have a value local to a buffer and global to all
// buffers.  Indicate this by setting "var" to VAR_WIN.
#define VAR_WIN ((char *)-1)

typedef struct {
  char *fullname;           ///< full option name
  char *shortname;          ///< permissible abbreviation
  uint32_t flags;           ///< see above
  OptTypeFlags type_flags;  ///< option type flags, see OptValType
  void *var;                ///< global option: pointer to variable;
                            ///< window-local option: VAR_WIN;
                            ///< buffer-local option: global value
  idopt_T indir;            ///< global option: PV_NONE;
                            ///< local option: indirect option index
  bool immutable;           ///< option is immutable, trying to set its value will give an error.

  /// callback function to invoke after an option is modified to validate and
  /// apply the new value.
  opt_did_set_cb_T opt_did_set_cb;

  /// callback function to invoke when expanding possible values on the
  /// cmdline. Only useful for string options.
  opt_expand_cb_T opt_expand_cb;

  OptVal def_val;    ///< default value
  LastSet last_set;  ///< script in which the option was last set
} vimoption_T;

/// flags for buf_copy_options()
enum {
  BCO_ENTER  = 1,  ///< going to enter the buffer
  BCO_ALWAYS = 2,  ///< always copy the options
  BCO_NOHELP = 4,  ///< don't touch the help related options
};

/// Flags for option-setting functions
///
/// When OPT_GLOBAL and OPT_LOCAL are both missing, set both local and global
/// values, get local value.
typedef enum {
  OPT_GLOBAL    = 0x01,  ///< Use global value.
  OPT_LOCAL     = 0x02,  ///< Use local value.
  OPT_MODELINE  = 0x04,  ///< Option in modeline.
  OPT_WINONLY   = 0x08,  ///< Only set window-local options.
  OPT_NOWIN     = 0x10,  ///< Don’t set window-local options.
  OPT_ONECOLUMN = 0x20,  ///< list options one per line
  OPT_NO_REDRAW = 0x40,  ///< ignore redraw flags on option
  OPT_SKIPRTP   = 0x80,  ///< "skiprtp" in 'sessionoptions'
} OptionSetFlags;

/// Return value from get_option_attrs().
enum {
  SOPT_GLOBAL = 0x01,  ///< Option has global value
  SOPT_WIN    = 0x02,  ///< Option has window-local value
  SOPT_BUF    = 0x04,  ///< Option has buffer-local value
};

/// Get name of OptValType as a string.
static inline const char *optval_type_get_name(const OptValType type)
{
  switch (type) {
  case kOptValTypeNil:
    return "nil";
  case kOptValTypeBoolean:
    return "boolean";
  case kOptValTypeNumber:
    return "number";
  case kOptValTypeString:
    return "string";
  }
  UNREACHABLE;
}

// OptVal helper macros.
#define NIL_OPTVAL ((OptVal) { .type = kOptValTypeNil })
#define BOOLEAN_OPTVAL(b) ((OptVal) { .type = kOptValTypeBoolean, .data.boolean = b })
#define NUMBER_OPTVAL(n) ((OptVal) { .type = kOptValTypeNumber, .data.number = n })
#define STRING_OPTVAL(s) ((OptVal) { .type = kOptValTypeString, .data.string = s })

#define CSTR_AS_OPTVAL(s) STRING_OPTVAL(cstr_as_string(s))
#define CSTR_TO_OPTVAL(s) STRING_OPTVAL(cstr_to_string(s))
#define STATIC_CSTR_AS_OPTVAL(s) STRING_OPTVAL(STATIC_CSTR_AS_STRING(s))
#define STATIC_CSTR_TO_OPTVAL(s) STRING_OPTVAL(STATIC_CSTR_TO_STRING(s))

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "option.h.generated.h"
#endif
