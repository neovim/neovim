#ifndef NVIM_OS_CLIPBOARD_H
#define NVIM_OS_CLIPBOARD_H

#include <stddef.h>

#include "nvim/normal.h"
#include "nvim/types.h"

#ifdef __APPLE__
#define CLIPBOARD_NATIVE
#endif

/// Return value of clipboard_get
typedef struct {
  char_u *text;       ///< UTF-8 encoded text
  size_t length;      ///< Length of text in bytes
  MotionType regtype; ///< The register type
} ClipboardData;

/// clipboard_init - Intialize the clipboard subsystem.
void clipboard_init(void);

/// clipboard_get - Get the system clipboard.
///
/// @param[out] data Out data parameter. Contains the clipboard data on success.
///                  Untouched if an error occurrs. Note: Text is allocated on
///                  the heap. The caller takes ownership of this pointer and
///                  should free it when done.
///
/// @returns true on success, false if an error occurred.
bool clipboard_get(ClipboardData *data);

/// clipboard_set - Set the system clipboard.
///
/// @param regname The register name ('*' or '+')
/// @param regtype The register type
/// @param lines Pointer to an array of line pointers
/// @param numlines The number of lines in lines array
void clipboard_set(char regname, MotionType regtype,
                   char_u **lines, size_t numlines);

#endif // NVIM_OS_CLIPBOARD_H
