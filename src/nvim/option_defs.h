#ifndef NVIM_OPTION_DEFS_H
#define NVIM_OPTION_DEFS_H

#include "nvim/api/private/defs.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/types.h"

/// Option value type
typedef enum {
  kOptValTypeNil = 0,
  kOptValTypeBoolean,
  kOptValTypeNumber,
  kOptValTypeString,
} OptValType;

/// Option value
typedef struct {
  OptValType type;

  union {
    // boolean options are actually tri-states because they have a third "None" value.
    TriState boolean;
    OptInt number;
    String string;
  } data;
} OptVal;

/// Argument for the callback function (opt_did_set_cb_T) invoked after an
/// option value is modified.
typedef struct {
  /// Pointer to the option variable.  The variable can be an OptInt (numeric
  /// option), an int (boolean option) or a char pointer (string option).
  void *os_varp;
  int os_idx;
  int os_flags;

  /// old value of the option (can be a string, number or a boolean)
  union {
    const OptInt number;
    const bool boolean;
    const char *string;
  } os_oldval;

  /// new value of the option (can be a string, number or a boolean)
  union {
    const OptInt number;
    const bool boolean;
    const char *string;
  } os_newval;

  /// When set by the called function: Stop processing the option further.
  /// Currently only used for boolean options.
  bool os_doskip;

  /// Option value was checked to be safe, no need to set P_INSECURE
  /// Used for the 'keymap', 'filetype' and 'syntax' options.
  bool os_value_checked;
  /// Option value changed.  Used for the 'filetype' and 'syntax' options.
  bool os_value_changed;

  /// Used by the 'isident', 'iskeyword', 'isprint' and 'isfname' options.
  /// Set to true if the character table is modified when processing the
  /// option and need to be restored because of a failure.
  bool os_restore_chartab;

  /// If the value specified for an option is not valid and the error message
  /// is parameterized, then the "os_errbuf" buffer is used to store the error
  /// message (when it is not NULL).
  char *os_errbuf;
  size_t os_errbuflen;

  void *os_win;
  void *os_buf;
} optset_T;

/// Type for the callback function that is invoked after an option value is
/// changed to validate and apply the new value.
///
/// Returns NULL if the option value is valid and successfully applied.
/// Otherwise returns an error message.
typedef const char *(*opt_did_set_cb_T)(optset_T *args);

#endif  // NVIM_OPTION_DEFS_H
