#include <fcntl.h>
#include <limits.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

#include "nvim/os/os.h"
#include "nvim/os/cygterm.h"
#include "nvim/memory.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "os/cygterm.c.generated.h"
#endif

#define CYGWDLL "cygwin1.dll"
#define MSYSDLL "msys-2.0.dll"
#define CYG_INIT_FUNC "cygwin_dll_init"
#define MSYS_INIT_FUNC "msys_dll_init"

// These definition came from header file of Cygwin
#define EINTR      4
// iflag bits
#define INLCR      0x00040
#define ICRNL      0x00100
#define IXON       0x00400

// lflag bits
#define ISIG       0x0001
#define ICANON     0x0002
#define ECHO       0x0004
#define IEXTEN     0x0100

#define TCSANOW    2

#define TIOCGWINSZ (('T' << 8) | 1)

#define CYG_O_BINARY   0x10000

struct winsize
{
  uint16_t ws_row, ws_col;
  uint16_t ws_xpixel, ws_ypixel;
};

typedef int (*tcgetattr_fn) (int, struct termios *);
typedef int (*tcsetattr_fn) (int, int, const struct termios *);
typedef void (*cfmakeraw_fn) (struct termios *);
typedef int (*ioctl_fn) (int, int, ...);
typedef int (*open_fn) (const char *, int);
typedef int (*close_fn) (int);
typedef int *(*errno_fn) (void);
typedef char *(*strerror_fn) (int);
typedef int (*uname_fn) (struct utsname *);

struct Cygwindll {
  HMODULE hmodule;
  tcgetattr_fn tcgetattr;
  tcsetattr_fn tcsetattr;
  cfmakeraw_fn cfmakeraw;
  ioctl_fn ioctl;
  open_fn open;
  close_fn close;
  errno_fn __errno;
  strerror_fn strerror;
};

/// Determine if nvim is running in mintty. When running in mintty, it also
/// determines whether it is running with Cygwin or Msys.
///
/// @param  fd  File descriptor to determine.
///
/// @returns kNoneMintty if not running in minntty.
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
      return kNoneMintty;
  }
}

bool os_init_cygwin_dll(void)
{
  return get_cygwin_dll() ? true : false;
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
  if (mintty == kNoneMintty) {
    return NULL;
  }

  CygTerm *cygterm = (CygTerm *)xmalloc(sizeof(CygTerm));
  if (!cygterm) {
    return NULL;
  }

  CygwinDll *cygwindll = get_cygwin_dll();
  cygterm->cygwindll = cygwindll;

  if (!cygterm->cygwindll) {
    goto abort;
  }
  int pty_no = get_cygterm_pty_no(fd);
  if (pty_no == -1) {
    goto abort;
  }
  char pty_dev[MAX_PATH];
  snprintf(pty_dev, sizeof(pty_dev), "/dev/pty%d", pty_no);
  cygterm->fd = cygwindll->open(pty_dev, O_RDWR | CYG_O_BINARY);
  if (cygterm->fd == -1) {
    ELOG("Failed to open %s: %s", pty_dev,
         cygwin_dll_strerror(cygwindll, cygwin_dll_errno(cygwindll)));
    goto abort;
  }

  struct termios termios;
  if (cygwindll->tcgetattr(cygterm->fd, &termios) == 0) {
    cygterm->restore_termios = termios;
    cygterm->restore_termios_valid = true;

    ((struct __oldtermios *)(&termios))->c_iflag &= (uint16_t)~(IXON|INLCR|ICRNL);
    ((struct __oldtermios *)(&termios))->c_lflag &= (uint16_t)~(ICANON|ECHO|IEXTEN);
    ((struct __oldtermios *)(&termios))->c_cc[VMIN] = 1;
    ((struct __oldtermios *)(&termios))->c_cc[VTIME] = 0;
    ((struct __oldtermios *)(&termios))->c_lflag &= (uint16_t)~ISIG;

    int ret = cygwindll->tcsetattr(cygterm->fd, TCSANOW, &termios);
    if (ret == -1) {
      ELOG("Failed to tcsetattr: %s",
           cygwin_dll_strerror(cygwindll, cygwin_dll_errno(cygwindll)));
    }
  } else {
    ELOG("Failed to tcgetattr: %s",
         cygwin_dll_strerror(cygwindll, cygwin_dll_errno(cygwindll)));
  }

  int width, height;
  if (os_cygterm_get_winsize(cygterm, &width, &height)) {
    cygterm->width = width;
    cygterm->height = height;
  }
  return cygterm;

abort:
  xfree(cygterm);
  return NULL;
}

/// Discard the struct Cygterm.
///
/// @param  cygterm  Pointer to the structure returned by os_cygterm_new.
///
void os_cygterm_destroy(CygTerm *cygterm)
{
  if (!cygterm) {
    return;
  }

  CygwinDll *cygwindll = cygterm->cygwindll;
  if (cygterm->restore_termios_valid) {
    int ret = cygwindll->tcsetattr(cygterm->fd,
                                   TCSANOW,
                                   &cygterm->restore_termios);
    if (ret == -1) {
      ELOG("Failed to tcsetattr: %s",
           cygwin_dll_strerror(cygwindll, cygwin_dll_errno(cygwindll)));
    }
  }

  int ret = cygwindll->close(cygterm->fd);
  if (ret == -1) {
    ELOG("Failed to close pty: %s",
         cygwin_dll_strerror(cygwindll, cygwin_dll_errno(cygwindll)));
  }
  FreeLibrary(cygwindll->hmodule);
  xfree(cygterm->cygwindll);
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
  if (!cygterm) {
    return false;
  }

  struct winsize ws;
  int err, err_no;
  CygwinDll *cygwindll = cygterm->cygwindll;

  do {
    err = cygwindll->ioctl(cygterm->fd, TIOCGWINSZ, &ws);
    err_no = cygwin_dll_errno(cygwindll);
  } while (err == -1 && err_no == EINTR);

  if (err == -1) {
    return false;
  }

  *width = ws.ws_col;
  *height = ws.ws_row;

  return true;
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
  int result = (int)kNoneMintty;
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
    result =  p != NULL ? result : (int)kNoneMintty;
  } else {
    result = -1;
  }
  xfree(nameinfo);
  return result;
}

static int get_cygterm_pty_no(int fd)
{
  return query_mintty(fd, kPtyNo);
}

static CygwinDll *get_cygwin_dll(void)
{
  static CygwinDll *cygwindll = NULL;
  static bool is_init = false;
  const char *emsg = NULL;
  if (is_init) {
    return cygwindll;
  }
  is_init = true;
  cygwindll = xcalloc(1, sizeof(CygwinDll));
  if (!cygwindll) {
    return cygwindll;
  }
  void (*init)(void);
  if (cygwindll->hmodule) {
    return cygwindll;
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
      return cygwindll = NULL;
    }
    HMODULE hmodule = LoadLibrary(dll);
    if (!hmodule) {
      ELOG("Failed to LoadLibrary: %s", dll);
      xfree(cygwindll);
      return cygwindll = NULL;
    }
    cygwindll->hmodule = hmodule;
    init = (void (*)(void))GetProcAddress(hmodule, init_func);
    if (!init) {
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
    init();
    return cygwindll;
  }
cleanup:
  ELOG("Failed to GetProcAddress: %s", emsg);
  FreeLibrary(cygwindll->hmodule);
  xfree(cygwindll);
  return cygwindll = NULL;
}

static int cygwin_dll_errno(CygwinDll *cygwindll)
{
    int err_no = -1;
    int *err = cygwindll->__errno();
    if (err) {
      err_no = *err;
    }
    return err_no;
}

static char *cygwin_dll_strerror(CygwinDll *cygwindll, int err)
{
  return cygwindll->strerror(err);
}
