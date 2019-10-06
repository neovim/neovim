#ifndef NVIM_PATH_H
#define NVIM_PATH_H

#include "nvim/func_attr.h"
#include "nvim/types.h"
#include "nvim/garray.h"

/* Flags for expand_wildcards() */
#define EW_DIR          0x01    /* include directory names */
#define EW_FILE         0x02    /* include file names */
#define EW_NOTFOUND     0x04    /* include not found names */
#define EW_ADDSLASH     0x08    /* append slash to directory name */
#define EW_KEEPALL      0x10    /* keep all matches */
#define EW_SILENT       0x20    /* don't print "1 returned" from shell */
#define EW_EXEC         0x40    /* executable files */
#define EW_PATH         0x80    /* search in 'path' too */
#define EW_ICASE        0x100   /* ignore case */
#define EW_NOERROR      0x200   /* no error for bad regexp */
#define EW_NOTWILD      0x400   /* add match with literal name if exists */
#define EW_KEEPDOLLAR   0x800   /* do not escape $, $var is expanded */
/* Note: mostly EW_NOTFOUND and EW_SILENT are mutually exclusive: EW_NOTFOUND
* is used when executing commands and EW_SILENT for interactive expanding. */
#define EW_ALLLINKS     0x1000   // also links not pointing to existing file
#define EW_SHELLCMD     0x2000   // called from expand_shellcmd(), don't check
                                 //  if executable is in $PATH
#define EW_DODOT        0x4000   // also files starting with a dot
#define EW_EMPTYOK      0x8000   // no matches is not an error
#define EW_NOTENV       0x10000  // do not expand environment variables

/// Return value for the comparison of two files. Also @see path_full_compare.
typedef enum file_comparison {
  kEqualFiles = 1,        ///< Both exist and are the same file.
  kDifferentFiles = 2,    ///< Both exist and are different files.
  kBothFilesMissing = 4,  ///< Both don't exist.
  kOneFileMissing = 6,    ///< One of them doesn't exist.
  kEqualFileNames = 7     ///< Both don't exist and file names are same.
} FileComparison;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "path.h.generated.h"
#endif
#endif
