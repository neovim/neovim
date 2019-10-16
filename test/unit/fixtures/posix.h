#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

enum {
  kPOSIXErrnoEINTR = EINTR,
  kPOSIXErrnoECHILD = ECHILD,
  kPOSIXWaitWUNTRACED = WUNTRACED,
};
