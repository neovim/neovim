#pragma once

#include <stddef.h>  // IWYU pragma: keep

#include "nvim/garray_defs.h"  // IWYU pragma: keep
#include "nvim/types_defs.h"  // IWYU pragma: keep

/// Flags for expand_wildcards()
enum {
  EW_DIR        = 0x01,     ///< include directory names
  EW_FILE       = 0x02,     ///< include file names
  EW_NOTFOUND   = 0x04,     ///< include not found names
  EW_ADDSLASH   = 0x08,     ///< append slash to directory name
  EW_KEEPALL    = 0x10,     ///< keep all matches
  EW_SILENT     = 0x20,     ///< don't print "1 returned" from shell
  EW_EXEC       = 0x40,     ///< executable files
  EW_PATH       = 0x80,     ///< search in 'path' too
  EW_ICASE      = 0x100,    ///< ignore case
  EW_NOERROR    = 0x200,    ///< no error for bad regexp
  EW_NOTWILD    = 0x400,    ///< add match with literal name if exists
  EW_KEEPDOLLAR = 0x800,    ///< do not escape $, $var is expanded
  EW_ALLLINKS   = 0x1000,   ///< also links not pointing to existing file
  EW_SHELLCMD   = 0x2000,   ///< called from expand_shellcmd(), don't check
                            ///< if executable is in $PATH
  EW_DODOT      = 0x4000,   ///< also files starting with a dot
  EW_EMPTYOK    = 0x8000,   ///< no matches is not an error
  EW_NOTENV     = 0x10000,  ///< do not expand environment variables
  EW_CDPATH     = 0x20000,  ///< search in 'cdpath' too
  EW_NOBREAK    = 0x40000,  ///< do not invoke breakcheck
};
// Note: mostly EW_NOTFOUND and EW_SILENT are mutually exclusive: EW_NOTFOUND
// is used when executing commands and EW_SILENT for interactive expanding.

/// Return value for the comparison of two files. Also @see path_full_compare.
typedef enum file_comparison {
  kEqualFiles = 1,        ///< Both exist and are the same file.
  kDifferentFiles = 2,    ///< Both exist and are different files.
  kBothFilesMissing = 4,  ///< Both don't exist.
  kOneFileMissing = 6,    ///< One of them doesn't exist.
  kEqualFileNames = 7,  ///< Both don't exist and file names are same.
} FileComparison;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "path.h.generated.h"
#endif
