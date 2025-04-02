#pragma once

// Some defines from the old feature.h
#define SESSION_FILE "Session.vim"
#define SYS_OPTWIN_FILE "$VIMRUNTIME/optwin.vim"
#define RUNTIME_DIRNAME "runtime"

enum {
  /// length of a buffer to store a number in ASCII (64 bits binary + NUL)
  NUMBUFLEN = 65,
};

#define MAX_TYPENR 65535

/// Directions.
typedef enum {
  kDirectionNotSet = 0,
  FORWARD = 1,
  BACKWARD = -1,
  FORWARD_FILE = 3,
  BACKWARD_FILE = -3,
} Direction;

/// Used to track the status of external functions.
/// Currently only used for iconv().
typedef enum {
  kUnknown,
  kWorking,
  kBroken,
} WorkingStatus;

/// The scope of a working-directory command like `:cd`.
///
/// Scopes are enumerated from lowest to highest. When adding a scope make sure
/// to update all functions using scopes as well, such as the implementation of
/// `getcwd()`.
typedef enum {
  kCdScopeInvalid = -1,
  kCdScopeWindow,   ///< Affects one window.
  kCdScopeBuffer,   ///< Affects one buffer.
  kCdScopeTabpage,  ///< Affects one tab page.
  kCdScopeGlobal,   ///< Affects the entire Nvim instance.
} CdScope;

/// What caused the current directory to change.
typedef enum {
  kCdCauseOther = -1,
  kCdCauseManual,  ///< Using `:cd`, `:bcd`, `:tcd`, `:lcd` or `chdir()`.
  kCdCauseWindow,  ///< Switching to another window.
  kCdCauseBuffer,  ///< Switching to another buffer.
  kCdCauseAuto,    ///< On 'autochdir'.
} CdCause;

// return values for functions
#if !(defined(OK) && (OK == 1))
// OK already defined to 1 in MacOS X curses, skip this
# define OK                     1
#endif
#define FAIL                    0
#define NOTDONE                 2   // not OK or FAIL but skipped
