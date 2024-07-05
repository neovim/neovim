#include <stddef.h>
#include <stdint.h>

#include "nvim/os/fs.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/random.h"
#include "nvim/vim_defs.h"

#ifdef MSWIN
/// Fill the buffer "buf" with "len" random bytes.
/// Returns FAIL if the OS PRNG is not available or something went wrong.
int os_get_random(uint8_t *buf, size_t len)
{
  static int initialized = NOTDONE;
  static HINSTANCE hInstLib;
  static BOOL(WINAPI *pProcessPrng)(PBYTE, SIZE_T);

  if (initialized == NOTDONE) {
    hInstLib = LoadLibrary("bcryptprimitives.dll");
    if (hInstLib != NULL) {
      pProcessPrng = (void *)GetProcAddress(hInstLib, "ProcessPrng");
    }
    if (hInstLib == NULL || pProcessPrng == NULL) {
      FreeLibrary(hInstLib);
      initialized = FAIL;
    } else {
      initialized = OK;
    }
  }

  if (initialized == FAIL) {
    return FAIL;
  }

  // According to the documentation this call cannot fail.
  pProcessPrng(buf, len);

  return OK;
}
#else
/// Fill the buffer "buf" with "len" random bytes.
/// Returns FAIL if the OS PRNG is not available or something went wrong.
int os_get_random(uint8_t *buf, size_t len)
{
  static int dev_urandom_state = NOTDONE;  // FAIL or OK once tried

  if (dev_urandom_state == FAIL) {
    return FAIL;
  }

  const int fd = os_open("/dev/urandom", O_RDONLY, 0);

  // Attempt reading /dev/urandom.
  if (fd < 0) {
    dev_urandom_state = FAIL;
  } else if (read(fd, buf, len) == (ssize_t)len) {
    dev_urandom_state = OK;
    os_close(fd);
  } else {
    dev_urandom_state = FAIL;
    os_close(fd);
  }

  return dev_urandom_state;
}
#endif
