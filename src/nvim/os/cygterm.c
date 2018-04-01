#include <fcntl.h>
#include <stdbool.h>
#include <stdlib.h>

#include "nvim/os/os.h"
#include "nvim/os/cygterm.h"
#include "nvim/memory.h"

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

// Hack to detect mintty, ported from vim
// https://fossies.org/linux/vim/src/iscygpty.c
// See https://github.com/BurntSushi/ripgrep/issues/94#issuecomment-261745480
// for an explanation on why this works
int query_mintty(int fd, MinttyQueryType query_type)
{
  const size_t size = sizeof(FILE_NAME_INFO) + sizeof(WCHAR) * MAX_PATH;
  WCHAR *p = NULL;
  WCHAR *start_pty_no = NULL;
  WCHAR *end_pty_no = NULL;

  const HANDLE h = (HANDLE)_get_osfhandle(fd);
  if (h == INVALID_HANDLE_VALUE) {
    return false;
  }
  // Cygwin/msys's pty is a pipe.
  if (GetFileType(h) != FILE_TYPE_PIPE) {
    return false;
  }
  FILE_NAME_INFO *nameinfo = xmalloc(size);
  if (nameinfo == NULL) {
    return false;
  }
  // Check the name of the pipe:
  // '\{cygwin,msys}-XXXXXXXXXXXXXXXX-ptyN-{from,to}-master'
  int result = (int)kNoneMintty;
  if (GetFileInformationByHandleEx(h, FileNameInfo, nameinfo, size)) {
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
    result = wcstoul(start_pty_no, &endptr, 10);
    if (end_pty_no != endptr) {
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

MinttyType detect_mintty_type(int fd)
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

int get_pty_no(int fd)
{
  return query_mintty(fd, kPtyNo);
}

HMODULE get_cygwin_dll_handle(void)
{
  static HMODULE hmodule = NULL;
  void (*init)(void);
  if (hmodule) {
    return hmodule;
  } else {
    MinttyType mintty;
    const char *dll = NULL;
    const char *init_func = NULL;
    for (int i = 0; i < 3; i++) {
      mintty = detect_mintty_type(i);
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
    if (dll) {
      hmodule = LoadLibrary(dll);
      if (!hmodule) {
        return NULL;
      }
      init = (void (*)(void))GetProcAddress(hmodule, init_func);
      if (init) {
        init();
      } else {
        hmodule = NULL;
      }
    }
  }
  return hmodule;
}

CygTerm *cygterm_new(int fd)
{
  MinttyType mintty = detect_mintty_type(fd);
  if (mintty == kNoneMintty) {
    return NULL;
  }

  CygTerm *cygterm = (CygTerm *)xmalloc(sizeof(CygTerm));
  if (!cygterm) {
    return NULL;
  }

  cygterm->hmodule = get_cygwin_dll_handle();
  cygterm->tcgetattr =
    (tcgetattr_fn)GetProcAddress(cygterm->hmodule, "tcgetattr");
  cygterm->tcsetattr =
    (tcsetattr_fn)GetProcAddress(cygterm->hmodule, "tcsetattr");
  cygterm->ioctl = (ioctl_fn)GetProcAddress(cygterm->hmodule, "ioctl");
  cygterm->open = (open_fn)GetProcAddress(cygterm->hmodule, "open");
  cygterm->close = (close_fn)GetProcAddress(cygterm->hmodule, "close");
  cygterm->__errno = (errno_fn)GetProcAddress(cygterm->hmodule, "__errno");

  if (!cygterm->tcgetattr
      || !cygterm->tcsetattr
      || !cygterm->ioctl
      || !cygterm->open
      || !cygterm->close
      || !cygterm->__errno) {
    goto abort;
  }
  cygterm->is_started = false;
  int pty_no = get_pty_no(fd);
  if (pty_no == -1) {
    goto abort;
  }
  char pty_dev[MAX_PATH];
  snprintf(pty_dev, sizeof(pty_dev), "/dev/pty%d", pty_no);
  size_t len = strlen(pty_dev) + 1;
  cygterm->tty = xmalloc(len);
  snprintf(cygterm->tty, len, "%s", pty_dev);
  cygterm->fd = -1;
  cygterm_start(cygterm);
  return cygterm;

abort:
  xfree(cygterm);
  return NULL;
}

void cygterm_start(CygTerm *cygterm)
{
  if (cygterm->is_started) {
    return;
  }

  if (cygterm->fd == -1) {
    int fd = cygterm->open(cygterm->tty, O_RDWR | CYG_O_BINARY);
    if (fd == -1) {
      return;
    }
    cygterm->fd = fd;
  }

  struct termios termios;
  if (cygterm->tcgetattr(cygterm->fd, &termios) == 0) {
    cygterm->restore_termios = termios;
    cygterm->restore_termios_valid = true;

    termios.c_iflag &= ~(IXON|INLCR|ICRNL);
    termios.c_lflag &= ~(ICANON|ECHO|IEXTEN);
    termios.c_cc[VMIN] = 1;
    termios.c_cc[VTIME] = 0;
    termios.c_lflag &= ~ISIG;

    cygterm->tcsetattr(cygterm->fd, TCSANOW, &termios);
  }

  cygterm->is_started = true;
}

void cygterm_stop(CygTerm *cygterm)
{
  if (!cygterm->is_started) {
    return;
  }

  if (cygterm->fd == -1) {
    int fd = cygterm->open(cygterm->tty, O_RDWR | CYG_O_BINARY);
    if (fd == -1) {
      return;
    }
    cygterm->fd = fd;
  }
  if (cygterm->restore_termios_valid) {
    cygterm->tcsetattr(cygterm->fd, TCSANOW, &cygterm->restore_termios);
  }

  cygterm->is_started = false;
  cygterm->close(cygterm->fd);
}

bool cygterm_get_winsize(CygTerm *cygterm, int *width, int *height)
{
  struct winsize ws;
  int err, err_no;

  if (cygterm->fd == -1) {
    int fd = cygterm->open(cygterm->tty, O_RDWR | CYG_O_BINARY);
    if (fd == -1) {
      return false;
    }
    cygterm->fd = fd;
  }

  do {
    err = cygterm->ioctl(cygterm->fd, TIOCGWINSZ, &ws);
    int *e = cygterm->__errno();
    if (e == NULL) {
      err_no = -1;
    } else {
      err_no = *e;
    }
  } while (err == -1 && err_no == EINTR);

  if (err == -1) {
    return false;
  }

  *width = ws.ws_col;
  *height = ws.ws_row;

  return true;
}
