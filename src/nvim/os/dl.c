/// Functions for using external native libraries

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <uv.h>

#include "nvim/gettext_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/os/dl.h"

/// possible function prototypes that can be called by os_libcall()
/// int -> int
/// int -> string
/// string -> string
/// string -> int
typedef void (*gen_fn)(void);
typedef const char *(*str_str_fn)(const char *str);
typedef int (*str_int_fn)(const char *str);
typedef const char *(*int_str_fn)(int i);
typedef int (*int_int_fn)(int i);

/// os_libcall - call a function in a dynamic loadable library
///
/// an example of calling a function that takes a string and returns an int:
///
///   int int_out = 0;
///   os_libcall("mylib.so", "somefn", "string-argument", 0, NULL, &int_out);
///
/// @param libname the name of the library to load (e.g.: libsomething.so)
/// @param funcname the name of the library function (e.g.: myfunc)
/// @param argv the input string, NULL when using `argi`
/// @param argi the input integer, not used when using `argv` != NULL
/// @param[out] str_out an allocated output string, caller must free if
///             not NULL. NULL when using `int_out`.
/// @param[out] int_out the output integer param
/// @return true on success, false on failure
bool os_libcall(const char *libname, const char *funcname, const char *argv, int argi,
                char **str_out, int *int_out)
{
  if (!libname || !funcname) {
    return false;
  }

  uv_lib_t lib;

  // open the dynamic loadable library
  if (uv_dlopen(libname, &lib)) {
    semsg(_("dlerror = \"%s\""), uv_dlerror(&lib));
    uv_dlclose(&lib);
    return false;
  }

  // find and load the requested function in the library
  gen_fn fn;
  if (uv_dlsym(&lib, funcname, (void **)&fn)) {
    semsg(_("dlerror = \"%s\""), uv_dlerror(&lib));
    uv_dlclose(&lib);
    return false;
  }

  // call the library and save the result
  // TODO(aktau): catch signals and use jmp (if available) to handle
  // exceptions. jmp's on Unix seem to interact trickily with signals as
  // well. So for now we only support those libraries that are well-behaved.
  if (str_out) {
    str_str_fn sfn = (str_str_fn)fn;
    int_str_fn ifn = (int_str_fn)fn;

    const char *res = argv ? sfn(argv) : ifn(argi);

    // assume that ptr values of NULL, 1 or -1 are illegal
    *str_out = (res && (intptr_t)res != 1 && (intptr_t)res != -1)
               ? xstrdup(res) : NULL;
  } else {
    str_int_fn sfn = (str_int_fn)fn;
    int_int_fn ifn = (int_int_fn)fn;
    *int_out = argv ? sfn(argv) : ifn(argi);
  }

  // free the library
  uv_dlclose(&lib);

  return true;
}
