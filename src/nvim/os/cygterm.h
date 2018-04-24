#ifndef NVIM_OS_CYGTERM_H
#define NVIM_OS_CYGTERM_H

typedef enum {
  kMinttyNone,
  kMinttyCygwin,
  kMinttyMsys
} MinttyType;

typedef enum {
  kMinttyType,
  kPtyNo
} MinttyQueryType;

struct CygTerm;
typedef struct CygTerm CygTerm;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/cygterm.h.generated.h"
#endif
#endif  // NVIM_OS_CYGTERM_H
