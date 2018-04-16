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

// These definetion came from header file of Cygwin
#define VMIN           9
#define VTIME          16

#define NCCS           18

typedef unsigned char    cc_t;
typedef unsigned int     tcflag_t;
typedef unsigned int     speed_t;
typedef uint16_t         otcflag_t;
typedef unsigned char    ospeed_t;

// struct __oldtermios
struct termios
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

// struct termios
// {
//   tcflag_t      c_iflag;
//   tcflag_t      c_oflag;
//   tcflag_t      c_cflag;
//   tcflag_t      c_lflag;
//   char          c_line;
//   cc_t          c_cc[NCCS];
//   speed_t       c_ispeed;
//   speed_t       c_ospeed;
// };

typedef int (*tcgetattr_fn) (int, struct termios *);
typedef int (*tcsetattr_fn) (int, int, const struct termios *);
typedef int (*ioctl_fn) (int, int, ...);
typedef int (*open_fn) (const char *, int);
typedef int (*close_fn) (int);
typedef int *(*errno_fn) (void);
typedef char *(*strerror_fn) (int);

typedef struct {
  HMODULE hmodule;
  tcgetattr_fn tcgetattr;
  tcsetattr_fn tcsetattr;
  ioctl_fn ioctl;
  open_fn open;
  close_fn close;
  errno_fn __errno;
  strerror_fn strerror;
} CygwinDll;

typedef struct {
  CygwinDll *cygwindll;
  int fd;
  struct termios restore_termios;
  bool restore_termios_valid;
} CygTerm;

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/cygterm.h.generated.h"
#endif
#endif  // NVIM_OS_CYGTERM_H
