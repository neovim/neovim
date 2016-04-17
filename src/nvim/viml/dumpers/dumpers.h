#ifndef NVIM_VIML_DUMPERS_DUMPERS_H
#define NVIM_VIML_DUMPERS_DUMPERS_H

/// Type of the fwrite-like function
typedef size_t (*Writer)(const void *ptr, size_t size, size_t nmemb,
                         void *cookie);

/// Cookie argument to write_escaped_string_len
typedef struct {
  const char *echars;  ///< Characters that need to be escaped.
  Writer write;        ///< Original write function.
  void *cookie;        ///< Original cookie argument.
} EscapedCookie;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "viml/dumpers/dumpers.h.generated.h"
#endif
#endif  // NVIM_VIML_DUMPERS_DUMPERS_H
