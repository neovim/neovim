// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <uv.h>  // for HANDLE (win32)
#ifdef WIN32
# include <tlhelp32.h>  // for CreateToolhelp32Snapshot
#endif

#include "nvim/log.h"
#include "nvim/os/process.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/process.c.generated.h"
#endif

#ifdef WIN32
/// Kills process `pid` and its descendants recursively.
bool os_proc_tree_kill_rec(HANDLE process, int sig)
{
  if (process == NULL) {
    return false;
  }
  PROCESSENTRY32 pe;
  DWORD pid = GetProcessId(process);

  if (pid != 0) {
    HANDLE h = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (h != INVALID_HANDLE_VALUE) {
      pe.dwSize = sizeof(PROCESSENTRY32);
      if (!Process32First(h, &pe)) {
        goto theend;
      }

      do {
        if (pe.th32ParentProcessID == pid) {
          HANDLE ph = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pe.th32ProcessID);
          if (ph != NULL) {
            os_proc_tree_kill_rec(ph, sig);
            CloseHandle(ph);
          }
        }
      } while (Process32Next(h, &pe));

      CloseHandle(h);
    }
  }

theend:
  return (bool)TerminateProcess(process, (unsigned int)sig);
}
bool os_proc_tree_kill(int pid, int sig)
{
  assert(sig >= 0);
  assert(sig == SIGTERM || sig == SIGKILL);
  if (pid > 0) {
    ILOG("terminating process tree: %d", pid);
    HANDLE h = OpenProcess(PROCESS_ALL_ACCESS, FALSE, (DWORD)pid);
    return os_proc_tree_kill_rec(h, sig);
  } else {
    ELOG("invalid pid: %d", pid);
  }
  return false;
}
#else
/// Kills process group where `pid` is the process group leader.
bool os_proc_tree_kill(int pid, int sig)
{
  assert(sig == SIGTERM || sig == SIGKILL);
  int pgid = getpgid(pid);
  if (pgid > 0) {  // Ignore error. Never kill self (pid=0).
    if (pgid == pid) {
      ILOG("sending %s to process group: -%d",
           sig == SIGTERM ? "SIGTERM" : "SIGKILL", pgid);
      int rv = uv_kill(-pgid, sig);
      return rv == 0;
    } else {
      // Should never happen, because process_spawn() did setsid() in the child.
      ELOG("pgid %d != pid %d", pgid, pid);
    }
  } else {
    ELOG("getpgid(%d) returned %d", pid, pgid);
  }
  return false;
}
#endif
