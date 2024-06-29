#pragma once

#include <locale.h>

#include "nvim/ascii_defs.h"
#include "nvim/ex_cmds_defs.h"  // IWYU pragma: keep
#include "nvim/extmark_defs.h"  // IWYU pragma: keep
#include "nvim/macros_defs.h"
#include "nvim/mark_defs.h"  // IWYU pragma: keep
#include "nvim/os/time.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "mark.h.generated.h"
# include "mark.h.inline.generated.h"
#endif

/// Convert mark name to the offset
static inline int mark_global_index(const char name)
  FUNC_ATTR_CONST
{
  return (ASCII_ISUPPER(name)
          ? (name - 'A')
          : (ascii_isdigit(name)
             ? (NMARKS + (name - '0'))
             : -1));
}

/// Convert local mark name to the offset
static inline int mark_local_index(const char name)
  FUNC_ATTR_CONST
{
  return (ASCII_ISLOWER(name)
          ? (name - 'a')
          : (name == '"'
             ? NMARKS
             : (name == '^'
                ? NMARKS + 1
                : (name == '.'
                   ? NMARKS + 2
                   : -1))));
}

/// Global marks (marks with file number or name)
EXTERN xfmark_T namedfm[NGLOBALMARKS] INIT( = { 0 });

#define SET_FMARK(fmarkp_, mark_, fnum_, view_) \
  do { \
    fmark_T *const fmarkp__ = fmarkp_; \
    fmarkp__->mark = mark_; \
    fmarkp__->fnum = fnum_; \
    fmarkp__->timestamp = os_time(); \
    fmarkp__->view = view_; \
    fmarkp__->additional_data = NULL; \
  } while (0)

/// Free and set fmark using given value
#define RESET_FMARK(fmarkp_, mark_, fnum_, view_) \
  do { \
    fmark_T *const fmarkp___ = fmarkp_; \
    free_fmark(*fmarkp___); \
    SET_FMARK(fmarkp___, mark_, fnum_, view_); \
  } while (0)

/// Set given extended mark (regular mark + file name)
#define SET_XFMARK(xfmarkp_, mark_, fnum_, view_, fname_) \
  do { \
    xfmark_T *const xfmarkp__ = xfmarkp_; \
    xfmarkp__->fname = fname_; \
    SET_FMARK(&(xfmarkp__->fmark), mark_, fnum_, view_); \
  } while (0)

/// Free and set given extended mark (regular mark + file name)
#define RESET_XFMARK(xfmarkp_, mark_, fnum_, view_, fname_) \
  do { \
    xfmark_T *const xfmarkp__ = xfmarkp_; \
    free_xfmark(*xfmarkp__); \
    xfmarkp__->fname = fname_; \
    SET_FMARK(&(xfmarkp__->fmark), mark_, fnum_, view_); \
  } while (0)
