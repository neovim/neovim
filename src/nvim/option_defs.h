#pragma once

#include <stdbool.h>
#include <stddef.h>

#include "nvim/api/private/defs.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/regexp_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "options_enum.generated.h"
#endif

/// Option value type.
/// These types are also used as type flags by using the type value as an index for the type_flags
/// bit field (@see option_has_type()).
typedef enum {
  kOptValTypeNil = -1,  // Make sure Nil can't be bitshifted and used as an option type flag.
  kOptValTypeBoolean,
  kOptValTypeNumber,
  kOptValTypeString,
} OptValType;

/// Always update this whenever a new option type is added.
#define kOptValTypeSize (kOptValTypeString + 1)

typedef uint32_t OptTypeFlags;

typedef union {
  // boolean options are actually tri-states because they have a third "None" value.
  TriState boolean;
  OptInt number;
  String string;
} OptValData;

/// Option value
typedef struct {
  OptValType type;
  OptValData data;
} OptVal;

/// :set operator types
typedef enum {
  OP_NONE = 0,
  OP_ADDING,      ///< "opt+=arg"
  OP_PREPENDING,  ///< "opt^=arg"
  OP_REMOVING,    ///< "opt-=arg"
} set_op_T;

/// Argument for the callback function (opt_did_set_cb_T) invoked after an
/// option value is modified.
typedef struct {
  /// Pointer to the option variable.  The variable can be an OptInt (numeric
  /// option), an int (boolean option) or a char pointer (string option).
  void *os_varp;
  OptIndex os_idx;
  int os_flags;

  /// Old value of the option.
  /// TODO(famiu): Convert `os_oldval` and `os_newval` to `OptVal` to accommodate multitype options.
  OptValData os_oldval;
  /// New value of the option.
  OptValData os_newval;

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
  /// length of the error buffer
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

/// Argument for the callback function (opt_expand_cb_T) invoked after a string
/// option value is expanded for cmdline completion.
typedef struct {
  /// Pointer to the option variable. It's always a string.
  char *oe_varp;
  /// The original option value, escaped.
  char *oe_opt_value;

  /// true if using set+= instead of set=
  bool oe_append;
  /// true if we would like to add the original option value as the first choice.
  bool oe_include_orig_val;

  /// Regex from the cmdline, for matching potential options against.
  regmatch_T *oe_regmatch;
  /// The expansion context.
  expand_T *oe_xp;

  /// The full argument passed to :set. For example, if the user inputs
  /// ":set dip=icase,algorithm:my<Tab>", oe_xp->xp_pattern will only have
  /// "my", but oe_set_arg will contain the whole "icase,algorithm:my".
  char *oe_set_arg;
} optexpand_T;

/// Type for the callback function that is invoked when expanding possible
/// string option values during cmdline completion.
///
/// Strings in returned matches will be managed and freed by caller.
///
/// Returns OK if the expansion succeeded (numMatches and matches have to be
/// set). Otherwise returns FAIL.
///
/// Note: If returned FAIL or *numMatches is 0, *matches will NOT be freed by
/// caller.
typedef int (*opt_expand_cb_T)(optexpand_T *args, int *numMatches, char ***matches);

/// Requested option scopes for various functions in option.c
typedef enum {
  kOptReqGlobal = 0,  ///< Request global option value
  kOptReqWin    = 1,  ///< Request window-local option value
  kOptReqBuf    = 2,  ///< Request buffer-local option value
} OptReqScope;
