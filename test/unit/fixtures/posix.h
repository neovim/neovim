#include <unistd.h>
#include <string.h>
#include <errno.h>
#include <sys/wait.h>
#include <stdlib.h>

enum {
  kPOSIXErrnoEINTR = EINTR,
  kPOSIXErrnoECHILD = ECHILD,
  kPOSIXWaitWUNTRACED = WUNTRACED,
};
