#ifndef NVIM_PROBE_H
#define NVIM_PROBE_H

#if defined(UNIT_TESTING)

// TODO(zacharyl): Figure out how to pass these to unit tests
#include <stdio.h>
#define __PROBE(name, n, ...) fputs("PROBE" #n ": " #name "\n", stderr)

#elif defined(HAVE_SYS_SDT_H)

#include <sys/sdt.h>
#define __PROBE(name, n, ...) STAP_PROBE##n(neovim, name, ##__VA_ARGS__)

#else

#define __PROBE(name, n, ...)

#endif

#define PROBE_EVAL_GC_ENTRY(testing) __PROBE(eval__gc__entry, 1, testing)
#define PROBE_EVAL_GC_RETURN(did_free) __PROBE(eval__gc__return, 1, did_free)

#define PROBE_EVAL_CALL_FUNC_ENTRY(funcname, len)                              \
  __PROBE(eval__call_func__entry, 2, funcname, len)
#define PROBE_EVAL_CALL_FUNC_RETURN(funcname, len, ret)                        \
  __PROBE(eval__call_func__return, 3, funcname, len, ret)
#define PROBE_EVAL_DEFINE_FUNCTION(script, funcname)                           \
  __PROBE(eval__define_function, 2, script, funcname)

#define PROBE_OS_CALL_SHELL_ENTRY(cmd) __PROBE(os__call_shell__entry, 1, cmd)
#define PROBE_OS_CALL_SHELL_RETURN(exitcode)                                   \
  __PROBE(os__call_shell__return, 1, exitcode)

#define PROBE_OS_SYSTEM_ENTRY(argv, input, len)                                \
  __PROBE(os__system__entry, 3, argv, input, len)
#define PROBE_OS_SYSTEM_RETURN(ret, output, nread)                             \
  __PROBE(os__system__return, 3, ret, output, nread)

#endif  // NVIM_PROBE_H
