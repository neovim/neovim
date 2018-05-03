#include <fcntl.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/os/os.h"
#include "nvim/os/cygterm.h"
#include "nvim/memory.h"

#define CYGWDLL "cygwin1.dll"
#define MSYSDLL "msys-2.0.dll"
#define CYG_INIT_FUNC "cygwin_dll_init"
#define MSYS_INIT_FUNC "msys_dll_init"

// These definition came from header file of Cygwin
#define EINTR          4

#define TCSANOW        2

#define TIOCGWINSZ     (('T' << 8) | 1)

#define CYG_O_BINARY   0x10000

#define NCCS           18

typedef unsigned char    cc_t;
typedef unsigned int     tcflag_t;
typedef unsigned int     speed_t;

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

struct winsize
{
  uint16_t ws_row, ws_col;
  uint16_t ws_xpixel, ws_ypixel;
};

struct per_process
{
  char *initial_sp;

  // The offset of these 3 values can never change.
  // magic_biscuit is the size of this class and should never change.
  uint32_t magic_biscuit;
  uint32_t dll_major;
  uint32_t dll_minor;

  struct _reent **impure_ptr_ptr;
#ifdef __i386__
  char ***envptr;
#endif

  // Used to point to the memory machine we should use.  Usually these
  //    point back into the dll, but they can be overridden by the user.
  void *(*malloc)(size_t);
  void (*free)(void *);
  void *(*realloc)(void *, size_t);

  int *fmode_ptr;

  int (*main)(int, char **, char **);
  void (**ctors)(void);
  void (**dtors)(void);

  // For fork
  void *data_start;
  void *data_end;
  void *bss_start;
  void *bss_end;

  void *(*calloc)(size_t, size_t);
  // For future expansion of values set by the app.
  void (*premain[4])  // NOLINT(whitespace/parens)
    (int, char **, struct per_process *);

  // non-zero if ctors have been run.  Inherited from parent.
  int32_t run_ctors_p;

  DWORD_PTR unused[7];

  // Pointers to real operator new/delete functions for forwarding.
  struct per_process_cxx_malloc *cxx_malloc;

  HMODULE hmodule;

  DWORD api_major;  // API version that this program was
  DWORD api_minor;  //  linked with
  // For future expansion, so apps won't have to be relinked if we
  // add an item.
#ifdef __x86_64__
  DWORD_PTR unused2[4];
#else
  DWORD_PTR unused2[2];
#endif

  int (*posix_memalign)(void **, size_t, size_t);

  void *pseudo_reloc_start;
  void *pseudo_reloc_end;
  void *image_base;

#if defined (__INSIDE_CYGWIN__) && defined (__cplusplus)
  MTinterface *threadinterface;
#else
  void *threadinterface;
#endif
  struct _reent *impure_ptr;
};

struct cygwin_utsname
{
  char sysname[20];
  char nodename[20];
  char release[20];
  char version[20];
  char machine[20];
};

struct msys_utsname
{
  char sysname[21];
  char nodename[20];
  char release[20];
  char version[20];
  char machine[20];
};

union utsname
{
  struct cygwin_utsname cygwin;
  struct msys_utsname msys;
};

typedef void (*init_fn) (void);
typedef int (*tcgetattr_fn) (int, struct termios *);
typedef int (*tcsetattr_fn) (int, int, const struct termios *);
typedef void (*cfmakeraw_fn) (struct termios *);
typedef int (*ioctl_fn) (int, int, ...);
typedef int (*open_fn) (const char *, int);
typedef int (*close_fn) (int);
typedef int *(*errno_fn) (void);
typedef char *(*strerror_fn) (int);
typedef int (*uname_fn) (union utsname *);

typedef struct {
  HMODULE hmodule;
  DWORD thread_id;
  MinttyType type;
  init_fn init;
  tcgetattr_fn tcgetattr;
  tcsetattr_fn tcsetattr;
  cfmakeraw_fn cfmakeraw;
  ioctl_fn ioctl;
  open_fn open;
  close_fn close;
  errno_fn __errno;
  strerror_fn strerror;
  uname_fn uname;
  struct per_process *user_data;
} CygwinDll;

struct CygTerm {
  CygwinDll *cygwindll;
  int width;
  int height;
  int fd;
  struct termios restore_termios;
  bool restore_termios_valid;
};

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "os/cygterm.c.generated.h"
#endif


/// Determine if nvim is running in mintty. When running in mintty, it also
/// determines whether it is running with Cygwin or Msys.
///
/// @param  fd  File descriptor to determine.
///
/// @returns kMinttyNone if not running in minntty.
///          kMinttyMsys if running on Msys.
///          kMinttyCygwin if running on Cygwin.
///
MinttyType os_detect_mintty_type(int fd)
{
  int type = query_mintty(fd, kMinttyType);
  switch (type) {
    case (int)kMinttyMsys:  // NOLINT(whitespace/parens)
      return kMinttyMsys;
    case (int)kMinttyCygwin:  // NOLINT(whitespace/parens)
      return kMinttyCygwin;
    default:
      return kMinttyNone;
  }
}

/// Build the struct Cygterm.
///
/// @param  fd  File descriptor of a pipe passed from Cygwin's tty.
///
/// @return If construction succeeds, a pointer to a structure. Otherwise NULL.
///
CygTerm *os_cygterm_new(int fd)
{
  MinttyType mintty = os_detect_mintty_type(fd);
  if (mintty == kMinttyNone) {
    return NULL;
  }

  CygTerm *cygterm = (CygTerm *)xmalloc(sizeof(CygTerm));
  if (!cygterm) {
    return NULL;
  }
  cygterm->cygwindll = NULL;
  cygterm->width = cygterm->height = -1;
  cygterm->restore_termios_valid = false;

  CygwinDll *cygwindll = cygwin_get_dll();
  cygterm->cygwindll = cygwindll;

  int pty_no = cygterm_get_pty_no(fd);
  if (pty_no == -1) {
    goto abort;
  }
  char pty_dev[MAX_PATH];
  snprintf(pty_dev, sizeof(pty_dev), "/dev/pty%d", pty_no);
  cygwin_init_dll(cygwindll);
  cygterm->fd = cygwin_open(cygwindll, pty_dev, O_RDWR | CYG_O_BINARY);
  if (cygterm->fd == -1) {
    ELOG("Failed to open %s: %s", pty_dev,
         cygwin_strerror(cygwindll, cygwin_errno(cygwindll)));
    goto abort;
  }

  struct termios termios;
  if (cygwin_tcgetattr(cygwindll, cygterm->fd, &termios) == 0) {
    cygterm->restore_termios = termios;
    cygterm->restore_termios_valid = true;
    cygwin_cfmakeraw(cygwindll, &termios);
    int ret = cygwin_tcsetattr(cygwindll, cygterm->fd, TCSANOW, &termios);
    if (ret == -1) {
      ELOG("Failed to tcsetattr: %s",
           cygwin_strerror(cygwindll, cygwin_errno(cygwindll)));
    }
  } else {
    ELOG("Failed to tcgetattr: %s",
         cygwin_strerror(cygwindll, cygwin_errno(cygwindll)));
  }

  int width, height;
  if (cygterm_get_winsize(cygterm, &width, &height)) {
    cygterm->width = width;
    cygterm->height = height;
  }
  return cygterm;

abort:
  cygterm->cygwindll = NULL;
  return cygterm;
}

/// Discard the struct Cygterm.
///
/// @param  cygterm  Pointer to the structure returned by os_cygterm_new.
///
void os_cygterm_destroy(CygTerm *cygterm)
{
  if (!cygterm->cygwindll) {
    xfree(cygterm);
    return;
  }

  CygwinDll *cygwindll = cygterm->cygwindll;
  if (cygterm->restore_termios_valid) {
    int ret = cygwin_tcsetattr(cygwindll,
                               cygterm->fd,
                               TCSANOW,
                               &cygterm->restore_termios);
    if (ret == -1) {
      ELOG("Failed to tcsetattr: %s",
           cygwin_strerror(cygwindll, cygwin_errno(cygwindll)));
    }
  }

  int ret = cygwin_close(cygwindll, cygterm->fd);
  if (ret == -1) {
    ELOG("Failed to close pty: %s",
         cygwin_strerror(cygwindll, cygwin_errno(cygwindll)));
  }
  FreeLibrary(cygwindll->hmodule);
  xfree(cygterm);
}

/// Get the window size of Cygwin's tty.
///
/// @param[in]  cygterm  Pointer to struct Cygterm.
/// @param[out]  width  Window width.
/// @param[out]  height  Window height.
///
/// @return If size acquisiton succeeded, true. Otherwise false.
///
bool os_cygterm_get_winsize(CygTerm *cygterm, int *width, int *height)
{
  if (!cygterm->cygwindll || (cygterm->width == -1  && cygterm->height == -1)) {
    return false;
  }

  *width = cygterm->width;
  *height = cygterm->height;
  return true;
}

/// Query whether size of Cygwin's tty has been updated.
///
/// @param[in]  cygterm  Pointer to struct Cygterm.
///
/// @return If the size was updated, true. Otherwise false.
///
bool os_cygterm_is_size_update(CygTerm *cygterm)
{
  if (!cygterm->cygwindll) {
    return false;
  }

  int width = 0, height = 0;
  if (cygterm_get_winsize(cygterm, &width, &height)
      && (cygterm->width != width || cygterm->height != height)) {
    cygterm->width = width;
    cygterm->height = height;
    return true;
  }

  return false;
}

/// Load the Cygwin DLL
///
/// @return If load succeeded, true. Otherwise false.
///
bool os_cygwin_load_dll(void)
{
  CygwinDll *cygwindll = cygwin_get_dll();
  const char *emsg = NULL;
  if (cygwindll->hmodule) {
    ELOG("cygwin_load_dll() was called multiple times.");
    return false;
  } else {
    MinttyType mintty;
    const char *dll = NULL;
    const char *init_func = NULL;
    for (int i = 0; i < 3; i++) {
      mintty = os_detect_mintty_type(i);
      if (mintty == kMinttyCygwin) {
        dll = CYGWDLL;
        init_func = CYG_INIT_FUNC;
        break;
      } else if (mintty == kMinttyMsys) {
        dll = MSYSDLL;
        init_func = MSYS_INIT_FUNC;
        break;
      }
    }
    if (!dll) {
      xfree(cygwindll);
      ELOG("Failed to get DLL name.");
      return false;
    }
    cygwindll->type = mintty;
    HMODULE hmodule = LoadLibrary(dll);
    if (!hmodule) {
      ELOG("Failed to LoadLibrary: %s.", dll);
      xfree(cygwindll);
      return false;
    }
    cygwindll->hmodule = hmodule;
    cygwindll->init = (init_fn)GetProcAddress(hmodule, init_func);
    if (!cygwindll->init) {
      emsg = init_func;
      goto cleanup;
    }
    cygwindll->tcgetattr =
      (tcgetattr_fn)GetProcAddress(hmodule, "tcgetattr");
    if (!cygwindll->tcgetattr) {
      emsg = "tcgetattr";
      goto cleanup;
    }
    cygwindll->tcsetattr =
      (tcsetattr_fn)GetProcAddress(hmodule, "tcsetattr");
    if (!cygwindll->tcsetattr) {
      emsg = "tcsetattr";
      goto cleanup;
    }
    cygwindll->cfmakeraw =
      (cfmakeraw_fn)GetProcAddress(hmodule, "cfmakeraw");
    if (!cygwindll->cfmakeraw) {
      emsg = "cfmakeraw";
      goto cleanup;
    }
    cygwindll->ioctl = (ioctl_fn)GetProcAddress(hmodule, "ioctl");
    if (!cygwindll->ioctl) {
      emsg = "ioctl";
      goto cleanup;
    }
    cygwindll->open = (open_fn)GetProcAddress(hmodule, "open");
    if (!cygwindll->open) {
      emsg = "open";
      goto cleanup;
    }
    cygwindll->close = (close_fn)GetProcAddress(hmodule, "close");
    if (!cygwindll->close) {
      emsg = "close";
      goto cleanup;
    }
    cygwindll->__errno = (errno_fn)GetProcAddress(hmodule, "__errno");
    if (!cygwindll->__errno) {
      emsg = "__errno";
      goto cleanup;
    }
    cygwindll->strerror = (strerror_fn)GetProcAddress(hmodule, "strerror");
    if (!cygwindll->strerror) {
      emsg = "strerror";
      goto cleanup;
    }
    cygwindll->uname = (uname_fn)GetProcAddress(hmodule, "uname");
    if (!cygwindll->uname) {
      emsg = "uname";
      goto cleanup;
    }
    cygwindll->user_data =
      (struct per_process *)GetProcAddress(hmodule, "__cygwin_user_data");
    if (!cygwindll->user_data) {
      emsg = "__cygwin_user_data";
      goto cleanup;
    }
    return true;
  }
cleanup:
  ELOG("Failed to GetProcAddress %s.", emsg);
  FreeLibrary(cygwindll->hmodule);
  return false;
}

// Hack to detect mintty, ported from vim
// https://fossies.org/linux/vim/src/iscygpty.c
// See https://github.com/BurntSushi/ripgrep/issues/94#issuecomment-261745480
// for an explanation on why this works
static int query_mintty(int fd, MinttyQueryType query_type)
{
  const size_t size = sizeof(FILE_NAME_INFO) + sizeof(WCHAR) * MAX_PATH;
  if (size > UINT32_MAX) {
    return -1;
  }
  WCHAR *p = NULL;
  WCHAR *start_pty_no = NULL;
  WCHAR *end_pty_no = NULL;

  const HANDLE h = (HANDLE)_get_osfhandle(fd);
  if (h == INVALID_HANDLE_VALUE) {
    return -1;
  }
  // Cygwin/msys's pty is a pipe.
  if (GetFileType(h) != FILE_TYPE_PIPE) {
    return -1;
  }
  FILE_NAME_INFO *nameinfo = xmalloc(size);
  if (nameinfo == NULL) {
    return -1;
  }
  // Check the name of the pipe:
  // '\{cygwin,msys}-XXXXXXXXXXXXXXXX-ptyN-{from,to}-master'
  int result = (int)kMinttyNone;
  if (GetFileInformationByHandleEx(h, FileNameInfo, nameinfo, (uint32_t)size)) {
    nameinfo->FileName[nameinfo->FileNameLength / sizeof(WCHAR)] = L'\0';
    p = nameinfo->FileName;
    if (wcsstr(p, L"\\cygwin-") == p) {
      p += 8;
      result = (int)kMinttyCygwin;
    } else if (wcsstr(p, L"\\msys-") == p) {
      p += 6;
      result = (int)kMinttyMsys;
    } else {
      p = NULL;
    }
    if (p != NULL) {
      while (*p && isxdigit(*p)) {  // Skip 16-digit hexadecimal.
        p++;
      }
      if (wcsstr(p, L"-pty") == p) {
        p += 4;
      } else {
        p = NULL;
      }
    }
    if (p != NULL) {
      start_pty_no = p;
      while (*p && isdigit(*p)) {  // Skip pty number.
        p++;
      }
      end_pty_no = p;
      if (wcsstr(p, L"-from-master") != p && wcsstr(p, L"-to-master") != p) {
        p = start_pty_no = end_pty_no = NULL;
      }
    }
  }
  if (query_type == kPtyNo && start_pty_no && end_pty_no) {
    WCHAR *endptr = NULL;
    unsigned long pty_no = wcstoul(start_pty_no, &endptr, 10);
    if (pty_no <=  INT_MAX && (end_pty_no == endptr)) {
      result = (int)pty_no;
    } else {
      result = -1;
    }
  } else if (query_type == kMinttyType) {
    result =  p != NULL ? result : (int)kMinttyNone;
  } else {
    result = -1;
  }
  xfree(nameinfo);
  return result;
}

static int cygterm_get_pty_no(int fd)
{
  return query_mintty(fd, kPtyNo);
}

static bool cygterm_get_winsize(CygTerm *cygterm, int *width, int *height)
{
  assert(cygterm->cygwindll);
  struct winsize ws;
  int err, err_no;
  CygwinDll *cygwindll = cygterm->cygwindll;

  do {
    err = cygwin_ioctl(cygwindll, cygterm->fd, TIOCGWINSZ, (va_list)&ws);
    err_no = cygwin_errno(cygwindll);
  } while (err == -1 && err_no == EINTR);

  if (err == -1) {
    return false;
  }

  *width = ws.ws_col;
  *height = ws.ws_row;

  return true;
}

static CygwinDll *cygwin_get_dll(void)
{
  static CygwinDll cygwindll = {
    NULL,  // hmodule
    0,  // thread_id
    kMinttyNone,  // type
    NULL,  // init()
    NULL,  // tcgetattr()
    NULL,  // tcsetattr()
    NULL,  // cfmakeraw()
    NULL,  // ioctl()
    NULL,  // open()
    NULL,  // close()
    NULL,  // __errno()
    NULL,  // strerror()
    NULL,  // uname()
    NULL,  // user_data
  };
  return &cygwindll;
}

static void cygwin_init_dll(CygwinDll *cygwindll)
{
  static bool is_init = false;
  const char *emsg = NULL;
  if (is_init) {
    ELOG("cygwin_init_dll() called multiple times.");
    return;
  }
  is_init = true;
  cygwindll->thread_id = GetCurrentThreadId();
  cygwindll->init();
  union utsname un;
  if (cygwindll->uname(&un) == 0) {
    const char *p;
    if (cygwindll->type== kMinttyCygwin) {
      p = un.cygwin.release;
    } else {
      p = un.msys.release;
    }
    size_t len = strlen(p);
    len = len ? len : 20;
    while (1) {
      if (*p == '(') {
        p++;
        char *endptr;
        unsigned long major = strtoul(p, &endptr, 10);
        if (major > INT_MAX) {
          emsg = "Major api version is to big.";
          goto fallback;
        }
        p = endptr + 1;
        unsigned long minor = strtoul(p, &endptr, 10);
        if (minor > INT_MAX) {
          emsg = "Minor api version is to big.";
          goto fallback;
        }
        cygwindll->user_data->api_major = major;
        cygwindll->user_data->api_minor = minor;
        break;
      } else {
        len--;
        p++;
        if (len == 0) {
          emsg = "Failed to get cygwin api version.";
          goto fallback;
        }
      }
    }
  } else {
    emsg = "Faled to get uname().";
    goto fallback;
  }
  return;
fallback:
  ELOG("%s Use the fallback API version.", emsg);
  // The smallest API version in which the new termios are used.
  cygwindll->user_data->api_major = 0;
  cygwindll->user_data->api_minor = 6;
}

static int cygwin_tcgetattr(CygwinDll *cygwindll,
                            int fd,
                            struct termios *termios)
{
  if (cygwindll->thread_id != GetCurrentThreadId()) {
    ELOG("cygwin_tcgetattr() "
         "was called from other thread that initialized DLL.");
    return -1;
  }
  return cygwindll->tcgetattr(fd, termios);
}

static int cygwin_tcsetattr(CygwinDll *cygwindll,
                            int fd, int option,
                            struct termios *termios)
{
  if (cygwindll->thread_id != GetCurrentThreadId()) {
    ELOG("cygwin_tcsetattr() "
         "was called from other thread that initialized DLL.");
    return -1;
  }
  return cygwindll->tcsetattr(fd, option, termios);
}

static void cygwin_cfmakeraw(CygwinDll *cygwindll, struct termios *termios)
{
  if (cygwindll->thread_id != GetCurrentThreadId()) {
    ELOG("cygwin_cfmakeraw() "
         "was called from other thread that initialized DLL.");
    return;
  }
  cygwindll->cfmakeraw(termios);
}

static int cygwin_ioctl(CygwinDll *cygwindll, int fd, int request, va_list args)
{
  if (cygwindll->thread_id != GetCurrentThreadId()) {
    ELOG("cygwin_ioctl() was called from other thread that initialized DLL.");
    return -1;
  }
  return cygwindll->ioctl(fd, request, args);
}

static int cygwin_open(CygwinDll *cygwindll, const char *pathname, int flags)
{
  if (cygwindll->thread_id != GetCurrentThreadId()) {
    ELOG("cygwin_open() was called from other thread that initialized DLL.");
    return -1;
  }
  return cygwindll->open(pathname, flags);
}

static int cygwin_close(CygwinDll *cygwindll, int fd)
{
  if (cygwindll->thread_id != GetCurrentThreadId()) {
    ELOG("cygwin_close() was called from other thread that initialized DLL.");
    return -1;
  }
  return cygwindll->close(fd);
}

static int cygwin_errno(CygwinDll *cygwindll)
{
  int err_no = -1;
  if (cygwindll->thread_id != GetCurrentThreadId()) {
    ELOG("cygwin_errno() was called from other thread that initialized DLL.");
    return err_no;
  }
  int *err = cygwindll->__errno();
  if (err) {
    err_no = *err;
  }
  return err_no;
}

static char *cygwin_strerror(CygwinDll *cygwindll, int err)
{
  if (cygwindll->thread_id != GetCurrentThreadId()) {
    ELOG("cygwin_strerror() "
         "was called from other thread that initialized DLL.");
    return "";
  }
  return cygwindll->strerror(err);
}
