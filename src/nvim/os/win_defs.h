#ifndef NVIM_OS_WIN_DEFS_H
#define NVIM_OS_WIN_DEFS_H

#include <windows.h>

#define TEMP_DIR_NAMES {"$TMP", "$TEMP", "$USERPROFILE", ""}
#define TEMP_FILE_PATH_MAXLEN _MAX_PATH

// Defines needed to fix the build on Windows:
// - DFLT_DIR
// - DFLT_BDIR
// - DFLT_VDIR
// - EXRC_FILE
// - VIMRC_FILE
// - SYNTAX_FNAME
// - DFLT_HELPFILE
// - SYS_VIMRC_FILE
// - SPECIAL_WILDCHAR

#define USE_CRNL

#ifdef _MSC_VER
# ifndef inline
#  define inline __inline
# endif
# ifndef restrict
#  define restrict __restrict
# endif
#endif

typedef SSIZE_T ssize_t;

#ifndef SSIZE_MAX
# ifdef _WIN64
#  define SSIZE_MAX _I64_MAX
# else
#  define SSIZE_MAX LONG_MAX
# endif
#endif

#endif  // NVIM_OS_WIN_DEFS_H
