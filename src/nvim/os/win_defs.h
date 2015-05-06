#ifndef NVIM_OS_WIN_DEFS_H
#define NVIM_OS_WIN_DEFS_H

#include <windows.h>

#define TEMP_DIR_NAMES {"$TMP", "$TEMP", "$USERPROFILE", ""}
#define TEMP_FILE_PATH_MAXLEN _MAX_PATH

// Defines needed to fix the build on Windows:
// - USR_EXRC_FILE
// - USR_VIMRC_FILE
// - VIMINFO_FILE
// - DFLT_DIR
// - DFLT_BDIR
// - DFLT_VDIR
// - DFLT_RUNTIMEPATH
// - EXRC_FILE
// - VIMRC_FILE
// - SYNTAX_FNAME
// - DFLT_HELPFILE
// - SYS_VIMRC_FILE
// - SPECIAL_WILDCHAR

#endif  // NVIM_OS_WIN_DEFS_H
