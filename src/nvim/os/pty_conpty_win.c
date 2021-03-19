// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

#include <uv.h>

#include "nvim/vim.h"
#include "nvim/ascii.h"
#include "nvim/eval.h"
#include "nvim/os/os.h"
#include "nvim/os/pty_conpty_win.h"
#include "nvim/path.h"

#ifndef EXTENDED_STARTUPINFO_PRESENT
# define EXTENDED_STARTUPINFO_PRESENT 0x00080000
#endif
#ifndef PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE
# define PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE 0x00020016
#endif

HRESULT (WINAPI *pCreatePseudoConsole)(COORD, HANDLE, HANDLE, DWORD, HPCON *);
HRESULT (WINAPI *pResizePseudoConsole)(HPCON, COORD);
void (WINAPI *pClosePseudoConsole)(HPCON);

bool os_has_conpty_working(void)
{
  static TriState has_conpty = kNone;
  if (has_conpty == kNone) {
    has_conpty = os_dyn_conpty_init();
  }

  return has_conpty == kTrue;
}

TriState os_dyn_conpty_init(void)
{
#define OPENCONSOLE "OpenConsole.exe"
  wchar_t *utf16_dll_path = NULL;
  char *utf8_dll_path = NULL;
  char *exe_path = NULL;
  TriState result = kFalse;
  uv_lib_t lib_kernel32;
  uv_lib_t *need_close = &lib_kernel32;
  if (uv_dlopen("kernel32.dll", &lib_kernel32)) {
    goto end;
  }
  static struct {
    char *name;
    FARPROC *ptr;
    FARPROC proc;
  } conpty_entry[] = {
    { "CreatePseudoConsole", (FARPROC *)&pCreatePseudoConsole, NULL },
    { "ResizePseudoConsole", (FARPROC *)&pResizePseudoConsole, NULL },
    { "ClosePseudoConsole", (FARPROC *)&pClosePseudoConsole, NULL }
  };
  for (int i = 0; i < (int)ARRAY_SIZE(conpty_entry); i++) {
    if (uv_dlsym(&lib_kernel32, conpty_entry[i].name,
                 (void **)&conpty_entry[i].proc)) {
      goto end;
    }
    *conpty_entry[i].ptr = conpty_entry[i].proc;
  }
  result = kTrue;
  uv_lib_t lib_conpty;
  need_close = &lib_conpty;
  if (uv_dlopen("conpty.dll", &lib_conpty)) {
    goto end;
  } else {
    for (int i = 0; i < (int)ARRAY_SIZE(conpty_entry); i++) {
      if (uv_dlsym(&lib_conpty, conpty_entry[i].name,
                   (void **)&conpty_entry[i].proc)) {
        goto end;
      }
    }
    DWORD buf_len = MAXPATHL * sizeof(wchar_t);
    utf16_dll_path = xmalloc(buf_len);
    DWORD ret;
    retry:
    SetLastError(ERROR_SUCCESS);
    ret = GetModuleFileNameW(lib_conpty.handle, utf16_dll_path, buf_len);
    if (ret != 0) {
      if (GetLastError() == ERROR_INSUFFICIENT_BUFFER) {
        buf_len *= 2;
        utf16_dll_path = xrealloc(utf16_dll_path, buf_len);
        goto retry;
      }
    } else {
      goto end;
    }
    if (utf16_to_utf8(utf16_dll_path, -1, &utf8_dll_path)) {
      goto end;
    }
    char *tail = (char *)path_tail((char_u *)utf8_dll_path);
    *tail = NUL;
    size_t len = sizeof OPENCONSOLE + (size_t)(tail - utf8_dll_path);
    exe_path = xmalloc(len);
    snprintf(exe_path, len, "%s%s", utf8_dll_path, OPENCONSOLE);
    if (!os_can_exe(exe_path, NULL, false)) {
      goto end;
    }
    need_close = &lib_kernel32;
    for (int i = 0; i < (int)ARRAY_SIZE(conpty_entry); i++) {
      *conpty_entry[i].ptr = conpty_entry[i].proc;
    }
  }

end:
  uv_dlclose(need_close);
  xfree(utf16_dll_path);
  xfree(utf8_dll_path);
  xfree(exe_path);
  return result;
#undef OPENCONSOLE
}

conpty_t *os_conpty_init(char **in_name, char **out_name,
                         uint16_t width, uint16_t height)
{
  static int count = 0;
  conpty_t *conpty_object = xcalloc(1, sizeof(*conpty_object));
  const char *emsg = NULL;
  HANDLE in_read = INVALID_HANDLE_VALUE;
  HANDLE out_write = INVALID_HANDLE_VALUE;
  char buf[MAXPATHL];
  SECURITY_ATTRIBUTES sa = { 0 };
  const DWORD mode = PIPE_ACCESS_INBOUND
    | PIPE_ACCESS_OUTBOUND | FILE_FLAG_FIRST_PIPE_INSTANCE;

  sa.nLength = sizeof(sa);
  snprintf(buf, sizeof(buf), "\\\\.\\pipe\\nvim-term-in-%"PRIx64"-%d",
           os_get_pid(), count);
  *in_name = xstrdup(buf);
  if ((in_read = CreateNamedPipeA(
      *in_name,
      mode,
      PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
      1,
      0,
      0,
      30000,
      &sa)) == INVALID_HANDLE_VALUE) {
    emsg = "create input pipe failed";
    goto failed;
  }
  snprintf(buf, sizeof(buf), "\\\\.\\pipe\\nvim-term-out-%"PRIx64"-%d",
           os_get_pid(), count);
  *out_name = xstrdup(buf);
  if ((out_write = CreateNamedPipeA(
      *out_name,
      mode,
      PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
      1,
      0,
      0,
      30000,
      &sa)) == INVALID_HANDLE_VALUE) {
    emsg = "create output pipe failed";
    goto failed;
  }
  assert(width <= SHRT_MAX);
  assert(height <=  SHRT_MAX);
  COORD size = { (int16_t)width, (int16_t)height };
  HRESULT hr;
  hr = pCreatePseudoConsole(size, in_read, out_write, 0, &conpty_object->pty);
  if (FAILED(hr)) {
    emsg = "create psudo console failed";
    goto failed;
  }

  conpty_object->si_ex.StartupInfo.cb = sizeof(conpty_object->si_ex);
  size_t bytes_required;
  InitializeProcThreadAttributeList(NULL, 1, 0,  & bytes_required);
  conpty_object->si_ex.lpAttributeList =
    (PPROC_THREAD_ATTRIBUTE_LIST)xmalloc(bytes_required);
  if (!InitializeProcThreadAttributeList(
      conpty_object->si_ex.lpAttributeList,
      1,
      0,
      &bytes_required)) {
    emsg = "InitializeProcThreadAttributeList failed";
    goto failed;
  }
  if (!UpdateProcThreadAttribute(
      conpty_object->si_ex.lpAttributeList,
      0,
      PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE,
      conpty_object->pty,
      sizeof(conpty_object->pty),
      NULL,
      NULL)) {
    emsg = "UpdateProcThreadAttribute failed";
    goto failed;
  }
  count++;
  goto finished;

failed:
  ELOG("os_conpty_init:%s : error code: %d",
       emsg, os_translate_sys_error((int)GetLastError()));
  os_conpty_free(conpty_object);
  conpty_object = NULL;
finished:
  if (in_read != INVALID_HANDLE_VALUE) {
    CloseHandle(in_read);
  }
  if (out_write != INVALID_HANDLE_VALUE) {
    CloseHandle(out_write);
  }
  return conpty_object;
}

bool os_conpty_spawn(conpty_t *conpty_object, HANDLE *process_handle,
                     wchar_t *name, wchar_t *cmd_line, wchar_t *cwd,
                     wchar_t *env)
{
  PROCESS_INFORMATION pi = { 0 };
  if (!CreateProcessW(
      name,
      cmd_line,
      NULL,
      NULL,
      false,
      EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT,
      env,
      cwd,
      &conpty_object->si_ex.StartupInfo,
      &pi)) {
    return false;
  }
  *process_handle = pi.hProcess;
  return true;
}

void os_conpty_set_size(conpty_t *conpty_object,
                        uint16_t width, uint16_t height)
{
    assert(width <= SHRT_MAX);
    assert(height <= SHRT_MAX);
    COORD size = { (int16_t)width, (int16_t)height };
    if (pResizePseudoConsole(conpty_object->pty, size) != S_OK) {
      ELOG("ResizePseudoConsoel failed: error code: %d",
           os_translate_sys_error((int)GetLastError()));
    }
}

void os_conpty_free(conpty_t *conpty_object)
{
  if (conpty_object != NULL) {
    if (conpty_object->si_ex.lpAttributeList != NULL) {
      DeleteProcThreadAttributeList(conpty_object->si_ex.lpAttributeList);
      xfree(conpty_object->si_ex.lpAttributeList);
    }
    if (conpty_object->pty != NULL) {
      pClosePseudoConsole(conpty_object->pty);
    }
  }
  xfree(conpty_object);
}
