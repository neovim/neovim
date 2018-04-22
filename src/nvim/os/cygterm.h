#ifndef NVIM_OS_CYGTERM_H
#define NVIM_OS_CYGTERM_H

typedef enum {
  kNoneMintty,
  kMinttyCygwin,
  kMinttyMsys
} MinttyType;

typedef enum {
  kMinttyType,
  kPtyNo
} MinttyQueryType;

struct Cygwindll;
typedef struct Cygwindll CygwinDll;
// These definetion came from header file of Cygwin
#define VMIN           9
#define VTIME          16

#define NCCS           18

typedef unsigned char    cc_t;
typedef unsigned int     tcflag_t;
typedef unsigned int     speed_t;
typedef uint16_t         otcflag_t;
typedef unsigned char    ospeed_t;

struct __oldtermios
{
  otcflag_t     c_iflag;
  otcflag_t     c_oflag;
  otcflag_t     c_cflag;
  otcflag_t     c_lflag;
  char          c_line;
  cc_t          c_cc[NCCS];
  ospeed_t      c_ispeed;
  ospeed_t      c_ospeed;
};

struct termios
{
  tcflag_t      c_iflag;
  tcflag_t      c_oflag;
  tcflag_t      c_cflag;
  tcflag_t      c_lflag;
  char          c_line;
  cc_t          c_cc[NCCS];
  speed_t       c_ispeed;
  speed_t       c_ospeed;
};

typedef struct {
  CygwinDll *cygwindll;
  int width;
  int height;
  int fd;
  struct termios restore_termios;
  bool restore_termios_valid;
} CygTerm;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/cygterm.h.generated.h"
#endif
#endif  // NVIM_OS_CYGTERM_H
