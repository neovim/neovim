#pragma once

#include "auto/config.h"
#include "nvim/log_defs.h"  // IWYU pragma: export
#include "nvim/macros_defs.h"

// USDT probes. Example invocation:
//     NVIM_PROBE(nvim_foo_bar, 1, string.data);
#if defined(HAVE_SYS_SDT_H)
# include <sys/sdt.h>  // IWYU pragma: keep

# define NVIM_PROBE(name, n, ...) STAP_PROBE##n(neovim, name, __VA_ARGS__)
#else
# define NVIM_PROBE(name, n, ...)
#endif

// uncrustify:off
#if NVIM_HAS_INCLUDE(<sanitizer/asan_interface.h>)
# include <sanitizer/asan_interface.h>  // IWYU pragma: keep
#endif
// uncrustify:on

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "log.h.generated.h"
#endif
