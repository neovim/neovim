/* vi:set ts=8 sts=4 sw=4:
 *
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
# include <sys/stat.h>          /* dev_t, ino_t */
#else
#endif

#define CSCOPE_SUCCESS          0
#define CSCOPE_FAILURE          -1

#define CSCOPE_DBFILE           "cscope.out"
#define CSCOPE_PROMPT           ">> "

/*
 * s 0name	Find this C symbol
 * g 1name	Find this definition
 * d 2name	Find functions called by this function
 * c 3name	Find functions calling this function
 * t 4string	find text string (cscope 12.9)
 * t 4name	Find assignments to (cscope 13.3)
 *   5pattern	change pattern -- NOT USED
 * e 6pattern	Find this egrep pattern
 * f 7name	Find this file
 * i 8name	Find files #including this file
 */

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
  pid_t pid;                    /* PID of the connected cscope process. */
  dev_t st_dev;                 /* ID of dev containing cscope db */
  ino_t st_ino;                 /* inode number of cscope db */
#else
#endif

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



/* the end */
