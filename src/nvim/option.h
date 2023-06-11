#ifndef NVIM_OPTION_H
#define NVIM_OPTION_H

#include "nvim/api/private/helpers.h"
#include "nvim/ex_cmds_defs.h"

// flags for buf_copy_options()
#define BCO_ENTER       1       // going to enter the buffer
#define BCO_ALWAYS      2       // always copy the options
#define BCO_NOHELP      4       // don't touch the help related options

#define MAX_NUMBERWIDTH 20      // used for 'numberwidth' and 'statuscolumn'

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
#endif  // NVIM_OPTION_H
