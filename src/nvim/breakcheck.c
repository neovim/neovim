#include "nvim/breakcheck.h"
#include "nvim/os/input.h"

// Functions to reduce os_breakcheck() calls

static const int kBreakCheckSkip = 32;
static int skip_count = 0;

// Checks for CTRL-C pressed, but only once in a while.
// Should be used instead of os_breakcheck() for functions that check for
// each line in the file.  Calling os_breakcheck() each time takes too much
// time, because it can be a system call.
void line_breakcheck(void)
{
  if (++skip_count >= kBreakCheckSkip) {
    skip_count = 0;
    os_breakcheck();
  }
}

// Like line_breakcheck() but checks 10 times less often.
void fast_breakcheck(void)
{
  if (++skip_count >= kBreakCheckSkip * 10) {
    skip_count = 0;
    os_breakcheck();
  }
}
