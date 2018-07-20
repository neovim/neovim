// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <assert.h>
#include <string.h>
#include <stdio.h>

#include <uv.h>

#include "nvim/api/private/helpers.h"
#include "nvim/api/private/defs.h"
#include "nvim/lua/executor.h"
#include "nvim/os/keyboard.h"
#include "nvim/vim.h"
#include "nvim/version.h"

#if defined(__linux__)
# define XLIB_NAME "libX11.so.6"

typedef void *_XDisplay;

/// Holds the data of the present state of Keyboard
typedef struct {
  char data[18];
} _XkbStateRec;
typedef int _XStatus;

/// The offset of the keyboard lock modes for X11
enum { kLockedModsOffset = 9 };
enum { _XkbUseCoreKbd = 0x0100 };

/// Masks used in libX11 for different Lock states
typedef enum {
    kXNumLock = 0x10,  ///< Mask for NumLock
    kXCapsLock = 0x02,  ///< Mask for CapsLock
    kXScrollLock = 0x80,  ///< Mask for ScrollLock
} XlibKbdLocks;
#elif defined(WIN32)
# include <Winuser.h>
#elif defined(__APPLE__)
# define Boolean Boolean_I_Dont_Care
# include <IOKit/IOKitLib.h>
# include <IOKit/IOReturn.h>
# include <IOKit/hidsystem/IOHIDLib.h>
# include <IOKit/hidsystem/IOHIDParameter.h>
# include <CoreFoundation/CoreFoundation.h>
# undef Boolean
#endif

/// Masks for the specific keyboard lock status
typedef enum {
  kNumLock = 0x01,  ///< Mask used to check if the NumLock is active
  kCapsLock = 0x02,  ///< Mask used to check if the CapsLock is active
  kScrollLock = 0x04,  ///< Mask used to check if the ScrollLock is active
} KbdLocks;

/// Used as a bitmask for the status of the different Lock Status
typedef int ModMask;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/keyboard.c.generated.h"
#endif

#if defined(__linux__)
static bool xlib_opened = false;
static uv_lib_t xlib;
static _XDisplay *(*_XOpenDisplay)(void *);
static int (*_XCloseDisplay)(_XDisplay *);
static _XStatus (*_XkbGetState)(_XDisplay *, unsigned, _XkbStateRec *);

/// Load symbol from previously opened X11 library
///
/// Requires os_xlib_init() to successfully load library before calling this
///
/// @param[in]  name  Symbol to obtain. Assumes it being a function name.
/// @param[out]  fun  Location where to put load results.
/// @param[out]  err  Location where to save error.
///
/// @return true if symbol was obtained successfully, false otherwise.
static bool os_xlib_dlsym(const char *name, void **fun, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  const int ret = uv_dlsym(&xlib, name, fun);
  if (ret != 0) {
    api_set_error(err, kErrorTypeException,
                  "Unable to obtain %s function from X11",
                  name);
    return false;
  }
  return true;
}

/// Initialize global variables, loading X11 library and required functions
///
/// @param[out]  err  Location where error is saved.
///
/// @return true if everything was loaded successfully, false otherwise.
static bool os_xlib_init(Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  if (xlib_opened) {
    return true;
  }
  const int udl_ret = uv_dlopen(XLIB_NAME, &xlib);
  if (udl_ret != 0) {
    api_set_error(err, kErrorTypeException,
                  "Unable to load " XLIB_NAME ": %s",
                  uv_dlerror(&xlib));
    return false;
  } else {
    xlib_opened = true;
  }

  if (!os_xlib_dlsym("XOpenDisplay", (void **)&_XOpenDisplay, err)
      || !os_xlib_dlsym("XCloseDisplay", (void **)&_XCloseDisplay, err)
      || !os_xlib_dlsym("XkbGetState", (void **)&_XkbGetState, err)) {
    return false;
  }
  return xlib_opened;
}

/// Get information about Num/Caps/Scroll Lock state in Linux
///
/// To be used in os_mods_status() function.
///
/// @param[out]  mods  Holds the information about the status of various locks
///                    in form of a pointer to integer bitmask.
/// @param[out]  err  Location where error message is to be saved.
///
/// @return -1 in case of error and a mask specifying which values
///         in mods are valid otherwise.
static ModMask os_get_locks_status(ModMask *const mods, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (!os_xlib_init(err)) {
    return -1;
  }

  _XDisplay *const display = _XOpenDisplay(NULL);
  if (display == NULL) {
    api_set_error(err, kErrorTypeException,
                  "Unable to open the display");
    return -1;
  }

  _XkbStateRec xkb_state;
  const _XStatus status = _XkbGetState(display, _XkbUseCoreKbd, &xkb_state);
  if (status) {
    api_set_error(err, kErrorTypeException,
                  "Unable to get keyboard state of the display");

    _XCloseDisplay(display);
  }

  int state = xkb_state.data[kLockedModsOffset];
  if (state & kXNumLock) {
    *mods |= kNumLock;
  }

  if (state & kXCapsLock) {
    *mods |= kCapsLock;
  }

  if (state & kXScrollLock) {
    *mods |= kScrollLock;
  }

  _XCloseDisplay(display);
  return kCapsLock | kNumLock | kScrollLock;
}

#elif defined(WIN32)
/// Get information about Num/Caps/Scroll Lock state in Windows.
///
/// To be used in os_mods_status() function.
///
/// @param[out]  mods  Holds the information about the status of various locks
///                    in form of a pointer to integer bitmask.
/// @param[out]  err  Location where error message is to be saved.
///
/// @return -1 in case of error and a mask specifying which values
///         in mods are valid otherwise.
static ModMask os_get_locks_status(ModMask *const mods, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  *mods = 0;
  if (GetKeyState(VK_CAPITAL) & 0x0001) {
    *mods |= kCapsLock;
  }
  if (GetKeyState(VK_NUMLOCK) & 0x0001) {
    *mods |= kNumLock;
  }
  if (GetKeyState(VK_SCROLL) & 0x0001) {
    *mods |= kScrollLock;
  }
  return kCapsLock | kNumLock | kScrollLock;
}

#elif defined(__APPLE__)
/// Get information about Num/Caps Lock state in MacOS
///
/// To be used in os_mods_status() function.
///
/// @param[out]  mods  Holds the information about the status of various locks
///                    in form of a pointer to integer bitmask.
/// @param[out]  err  Location where error message is to be saved.
///
/// @return -1 in case of error and a mask specifying which values
///         in mods are valid otherwise.
static ModMask os_get_locks_status(ModMask *const mods, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  const CFMutableDictionaryRef mdict = IOServiceMatching(kIOHIDSystemClass);
  const io_service_t ios = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                       (CFDictionaryRef)mdict);
  if (!ios) {
    if (mdict) {
      CFRelease(mdict);
    }
    api_set_error(err, kErrorTypeException,
                  "Unable to get service for default master port");
    return -1;
  }

  io_connect_t ioc;
  if (IOServiceOpen(ios, mach_task_self(), kIOHIDParamConnectType,
                    &ioc) != kIOReturnSuccess) {
    IOObjectRelease(ios);
    api_set_error(err, kErrorTypeException,
                  "Unable to get service for HID system class");
    return -1;
  }
  IOObjectRelease(ios);

  bool stateCaps;
  if (IOHIDGetModifierLockState(ioc, kIOHIDCapsLockState,
                                &stateCaps) != kIOReturnSuccess) {
    IOServiceClose(ioc);
    api_set_error(err, kErrorTypeException,
                  "Unable to query CapsLock state");
    return -1;
  }

  bool stateNums;
  if (IOHIDGetModifierLockState(ioc, kIOHIDNumLockState,
                                &stateNums) != kIOReturnSuccess) {
    IOServiceClose(ioc);
    api_set_error(err, kErrorTypeException,
                  "Unable to query NumLock state");
    return -1;
  }
  if (stateCaps) {
    *mods |= kCapsLock;
  }
  if (stateNums) {
    *mods |= kNumLock;
  }
  IOServiceClose(ioc);
  return kCapsLock | kNumLock;
}
#else
/// Dummy function used in case of no known platform detected.
///
/// @param[out]  mods  Holds the information about the status of various locks
///                    in form of a pointer to integer bitmask.
/// @param[out]  err  Location where error message is to be saved.
///
/// @return 0 as a mask denoting no possible keyboard mod is available.
static ModMask os_get_locks_status(ModMask *const mods, Error *err)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  *mods = 0;
  return 0;
}
#endif

/// Get information about Num/Caps/Scroll Lock state.
///
/// To be used in nvim_get_keyboard_mods() function.
///
/// @param[out]  dict  Pointer to dictionary where information about modifiers
///                    is to be dumped.
/// @param[out]  err  Location where error message is to be saved.
///
/// @return true in case of no error, false otherwise.
bool os_mods_status(Dictionary *const dict, Error *err)
  FUNC_ATTR_NONNULL_ALL
{
  ModMask mods = 0;
  const ModMask os_mod = os_get_locks_status(&mods, err);
  if (os_mod == -1) {
    return false;
  }
  if (os_mod & kCapsLock) {
    PUT(*dict, "CapsLock", BOOLEAN_OBJ(mods & kCapsLock));
  }
  if (os_mod & kNumLock) {
    PUT(*dict, "NumLock", BOOLEAN_OBJ(mods & kNumLock));
  }
  if (os_mod & kScrollLock) {
    PUT(*dict, "ScrollLock", BOOLEAN_OBJ(mods & kScrollLock));
  }
  return true;
}
