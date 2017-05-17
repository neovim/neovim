#ifndef NVIM_IF_CSCOPE_DEFS_H
#define NVIM_IF_CSCOPE_DEFS_H

/*
 * CSCOPE support for Vim added by Andy Kahn <kahn@zk3.dec.com>
 * Ported to Win32 by Sergey Khorev <sergey.khorev@gmail.com>
 *
 * The basic idea/structure of cscope for Vim was borrowed from Nvi.
 * There might be a few lines of code that look similar to what Nvi
 * has.  If this is a problem and requires inclusion of the annoying
 * BSD license, then sue me; I'm not worth much anyway.
 */


#if defined(UNIX)
# include <sys/types.h>         /* pid_t */
#endif

#include "nvim/os/os_defs.h"
#include "nvim/os/fs_defs.h"
#include "nvim/ex_cmds_defs.h"

#define CSCOPE_SUCCESS          0
#define CSCOPE_FAILURE          -1

#define CSCOPE_DBFILE           "cscope.out"
#define CSCOPE_PROMPT           ">> "

// See ":help cscope-find" for the possible queries.

typedef struct {
  char *  name;
  int (*func)(exarg_T *eap);
  char *  help;
  char *  usage;
  int cansplit;                 /* if supports splitting window */
} cscmd_T;

typedef struct csi {
  char *          fname;        /* cscope db name */
  char *          ppath;        /* path to prepend (the -P option) */
  char *          flags;        /* additional cscope flags/options (e.g, -p2) */
#if defined(UNIX)
  pid_t pid;                    // PID of the connected cscope process
#else
    DWORD         pid;          // PID of the connected cscope process
    HANDLE        hProc;        // cscope process handle
    DWORD         nVolume;      // Volume serial number, instead of st_dev
    DWORD         nIndexHigh;   // st_ino has no meaning on Windows
    DWORD         nIndexLow;
#endif
  FileID file_id;

  FILE *          fr_fp;        /* from cscope: FILE. */
  FILE *          to_fp;        /* to cscope: FILE. */
} csinfo_T;

typedef enum { Add, Find, Help, Kill, Reset, Show } csid_e;

typedef enum {
  Store,
  Get,
  Free,
  Print
} mcmd_e;

#endif  // NVIM_IF_CSCOPE_DEFS_H
