#ifndef NVIM_MARK_H
#define NVIM_MARK_H

#include "nvim/buffer_defs.h"
#include "nvim/mark_defs.h"
#include "nvim/pos.h"
#include "nvim/os/time.h"

/// Free and set fmark using given value
#define RESET_FMARK(fmarkp_, mark_, fnum_) \
    do { \
      fmark_T *const fmarkp__ = fmarkp_; \
      free_fmark(*fmarkp__); \
      fmarkp__->mark = mark_; \
      fmarkp__->fnum = fnum_; \
      fmarkp__->timestamp = os_time(); \
      fmarkp__->additional_data = NULL; \
    } while (0)

/// Clear given fmark
#define CLEAR_FMARK(fmarkp_) \
    RESET_FMARK(fmarkp_, ((pos_T) {0, 0, 0}), 0)

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mark.h.generated.h"
#endif
#endif  // NVIM_MARK_H
