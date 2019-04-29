// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

/// OS process functions
///
/// psutil is a good reference for cross-platform syscall voodoo:
/// https://github.com/giampaolo/psutil/tree/master/psutil/arch

#include <uv.h>  // for HANDLE (win32)

#ifdef WIN32
# include <tlhelp32.h>  // for CreateToolhelp32Snapshot
#endif

#if defined(__FreeBSD__)  // XXX: OpenBSD ?
# include <string.h>
# include <sys/types.h>
# include <sys/user.h>
#endif

#if defined(__NetBSD__) || defined(__OpenBSD__)
# include <sys/param.h>
#endif

#if defined(__APPLE__) || defined(BSD)
# include <sys/sysctl.h>
# include <pwd.h>
#endif

#include "nvim/globals.h"
#include "nvim/log.h"
#include "nvim/os/process.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/api/private/helpers.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "os/process.c.generated.h"
#endif

#ifdef WIN32
static bool os_proc_tree_kill_rec(HANDLE process, int sig)
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
          HANDLE ph = OpenProcess(PROCESS_ALL_ACCESS, false, pe.th32ProcessID);
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
/// Kills process `pid` and its descendants recursively.
bool os_proc_tree_kill(int pid, int sig)
{
  assert(sig >= 0);
  assert(sig == SIGTERM || sig == SIGKILL);
  if (pid > 0) {
    ILOG("terminating process tree: %d", pid);
    HANDLE h = OpenProcess(PROCESS_ALL_ACCESS, false, (DWORD)pid);
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

/// Gets the process ids of the immediate children of process `ppid`.
///
/// @param ppid Process to inspect.
/// @param[out,allocated] proc_list Child process ids.
/// @param[out] proc_count Number of child processes.
/// @return 0 on success, 1 if process not found, 2 on other error.
int os_proc_children(int ppid, int **proc_list, size_t *proc_count)
{
  if (ppid < 0) {
    return 2;
  }

  int *temp = NULL;
  *proc_list = NULL;
  *proc_count = 0;

#ifdef WIN32
  PROCESSENTRY32 pe;

  // Snapshot of all processes.
  HANDLE h = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (h == INVALID_HANDLE_VALUE) {
    return 2;
  }

  pe.dwSize = sizeof(PROCESSENTRY32);
  // Get root process.
  if (!Process32First(h, &pe)) {
    CloseHandle(h);
    return 2;
  }
  // Collect processes whose parent matches `ppid`.
  do {
    if (pe.th32ParentProcessID == (DWORD)ppid) {
      temp = xrealloc(temp, (*proc_count + 1) * sizeof(*temp));
      temp[*proc_count] = (int)pe.th32ProcessID;
      (*proc_count)++;
    }
  } while (Process32Next(h, &pe));
  CloseHandle(h);

#elif defined(__APPLE__) || defined(BSD)
# if defined(__APPLE__)
#  define KP_PID(o) o.kp_proc.p_pid
#  define KP_PPID(o) o.kp_eproc.e_ppid
# elif defined(__FreeBSD__)
#  define KP_PID(o) o.ki_pid
#  define KP_PPID(o) o.ki_ppid
# else
#  define KP_PID(o) o.p_pid
#  define KP_PPID(o) o.p_ppid
# endif
# ifdef __NetBSD__
  static int name[] = {
    CTL_KERN, KERN_PROC2, KERN_PROC_ALL, 0, (int)(sizeof(struct kinfo_proc2)), 0
  };
# else
  static int name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
# endif

  // Get total process count.
  size_t len = 0;
  int rv = sysctl(name, ARRAY_SIZE(name) - 1, NULL, &len, NULL, 0);
  if (rv) {
    return 2;
  }

  // Get ALL processes.
# ifdef __NetBSD__
  struct kinfo_proc2 *p_list = xmalloc(len);
# else
  struct kinfo_proc *p_list = xmalloc(len);
# endif
  rv = sysctl(name, ARRAY_SIZE(name) - 1, p_list, &len, NULL, 0);
  if (rv) {
    xfree(p_list);
    return 2;
  }

  // Collect processes whose parent matches `ppid`.
  bool exists = false;
  size_t p_count = len / sizeof(*p_list);
  for (size_t i = 0; i < p_count; i++) {
    exists = exists || KP_PID(p_list[i]) == ppid;
    if (KP_PPID(p_list[i]) == ppid) {
      temp = xrealloc(temp, (*proc_count + 1) * sizeof(*temp));
      temp[*proc_count] = KP_PID(p_list[i]);
      (*proc_count)++;
    }
  }
  xfree(p_list);
  if (!exists) {
    return 1;  // Process not found.
  }

#elif defined(__linux__)
  char proc_p[256] = { 0 };
  // Collect processes whose parent matches `ppid`.
  // Rationale: children are defined in thread with same ID of process.
  snprintf(proc_p, sizeof(proc_p), "/proc/%d/task/%d/children", ppid, ppid);
  FILE *fp = fopen(proc_p, "r");
  if (fp == NULL) {
    return 2;  // Process not found, or /proc/…/children not supported.
  }
  int match_pid;
  while (fscanf(fp, "%d", &match_pid) > 0) {
    temp = xrealloc(temp, (*proc_count + 1) * sizeof(*temp));
    temp[*proc_count] = match_pid;
    (*proc_count)++;
  }
  fclose(fp);
#endif

  *proc_list = temp;
  return 0;
}

#ifdef WIN32
/// Gets various properties of the process identified by `pid`.
///
/// @param pid Process to inspect.
/// @return Map of process properties, empty on error.
Dictionary os_proc_info(int pid)
{
  Dictionary pinfo = ARRAY_DICT_INIT;
  PROCESSENTRY32 pe;

  // Snapshot of all processes.  This is used instead of:
  //    OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, …)
  // to avoid ERROR_PARTIAL_COPY.  https://stackoverflow.com/a/29942376
  HANDLE h = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if (h == INVALID_HANDLE_VALUE) {
    return pinfo;  // Return empty.
  }

  pe.dwSize = sizeof(PROCESSENTRY32);
  // Get root process.
  if (!Process32First(h, &pe)) {
    CloseHandle(h);
    return pinfo;  // Return empty.
  }
  // Find the process.
  do {
    if (pe.th32ProcessID == (DWORD)pid) {
      break;
    }
  } while (Process32Next(h, &pe));
  CloseHandle(h);

  if (pe.th32ProcessID == (DWORD)pid) {
    PUT(pinfo, "pid", INTEGER_OBJ(pid));
    PUT(pinfo, "ppid", INTEGER_OBJ((int)pe.th32ParentProcessID));
    PUT(pinfo, "name", STRING_OBJ(cstr_to_string(pe.szExeFile)));
  }

  return pinfo;
}
#endif

/// Return true if process `pid` is running.
bool os_proc_running(int pid)
{
  return uv_kill(pid, 0) == 0;
}
