#ifndef NVIM_OS_WIN_DEFS_H
#define NVIM_OS_WIN_DEFS_H

// winsock2.h must be before windows.h - or so says Mingw
#include <winsock2.h>
#include <windows.h>
#include <uv.h>

#include <stdio.h>
#include <time.h>

#define TEMP_DIR_NAMES {"$TMP", "$TEMP", "$USERPROFILE", ""}
#define TEMP_FILE_PATH_MAXLEN _MAX_PATH

#define BASENAMELEN    _MAX_PATH
#define TEMPNAMELEN    _MAX_PATH

typedef uv_uid_t uid_t;

#endif  // NVIM_OS_WIN_DEFS_H
