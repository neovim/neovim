#include <stdbool.h>                // for true

#include "nvim/channel.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/deprecated.h"
#include "nvim/eval/funcs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds.h"
#include "nvim/gettext_defs.h"      // for _
#include "nvim/globals.h"
#include "nvim/macros_defs.h"       // for S_LEN
#include "nvim/message.h"           // for semsg
#include "nvim/types_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "eval/deprecated.c.generated.h"  // IWYU pragma: keep
#endif

/// "rpcstart()" function (DEPRECATED)
void f_rpcstart(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_NUMBER;
  rettv->vval.v_number = 0;

  if (check_secure()) {
    return;
  }

  if (argvars[0].v_type != VAR_STRING
      || (argvars[1].v_type != VAR_LIST && argvars[1].v_type != VAR_UNKNOWN)) {
    // Wrong argument types
    emsg(_(e_invarg));
    return;
  }

  list_T *args = NULL;
  int argsl = 0;
  if (argvars[1].v_type == VAR_LIST) {
    args = argvars[1].vval.v_list;
    argsl = tv_list_len(args);
    // Assert that all list items are strings
    int i = 0;
    TV_LIST_ITER_CONST(args, arg, {
      if (TV_LIST_ITEM_TV(arg)->v_type != VAR_STRING) {
        semsg(_("E5010: List item %d of the second argument is not a string"),
              i);
        return;
      }
      i++;
    });
  }

  if (argvars[0].vval.v_string == NULL || argvars[0].vval.v_string[0] == NUL) {
    emsg(_(e_api_spawn_failed));
    return;
  }

  // Allocate extra memory for the argument vector and the NULL pointer
  int argvl = argsl + 2;
  char **argv = xmalloc(sizeof(char *) * (size_t)argvl);

  // Copy program name
  argv[0] = xstrdup(argvars[0].vval.v_string);

  int i = 1;
  // Copy arguments to the vector
  if (argsl > 0) {
    TV_LIST_ITER_CONST(args, arg, {
      argv[i++] = xstrdup(tv_get_string(TV_LIST_ITEM_TV(arg)));
    });
  }

  // The last item of argv must be NULL
  argv[i] = NULL;

  Channel *chan = channel_job_start(argv, NULL, CALLBACK_READER_INIT,
                                    CALLBACK_READER_INIT, CALLBACK_NONE,
                                    false, true, false, false,
                                    kChannelStdinPipe, NULL, 0, 0, NULL,
                                    &rettv->vval.v_number);
  if (chan) {
    channel_create_event(chan, NULL);
  }
}

/// "rpcstop()" function
void f_rpcstop(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_NUMBER;
  rettv->vval.v_number = 0;

  if (check_secure()) {
    return;
  }

  if (argvars[0].v_type != VAR_NUMBER) {
    // Wrong argument types
    emsg(_(e_invarg));
    return;
  }

  // if called with a job, stop it, else closes the channel
  uint64_t id = (uint64_t)argvars[0].vval.v_number;
  if (find_job(id, false)) {
    f_jobstop(argvars, rettv, fptr);
  } else {
    const char *error;
    rettv->vval.v_number =
      channel_close((uint64_t)argvars[0].vval.v_number, kChannelPartRpc, &error);
    if (!rettv->vval.v_number) {
      emsg(error);
    }
  }
}

/// "last_buffer_nr()" function.
void f_last_buffer_nr(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  int n = 0;

  FOR_ALL_BUFFERS(buf) {
    if (n < buf->b_fnum) {
      n = buf->b_fnum;
    }
  }

  rettv->vval.v_number = n;
}

/// "termopen(cmd[, cwd])" function
void f_termopen(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  if (check_secure()) {
    return;
  }

  bool must_free = false;

  if (argvars[1].v_type == VAR_UNKNOWN) {
    must_free = true;
    argvars[1].v_type = VAR_DICT;
    argvars[1].vval.v_dict = tv_dict_alloc();
  }

  if (argvars[1].v_type != VAR_DICT) {
    // Wrong argument types
    semsg(_(e_invarg2), "expected dictionary");
    return;
  }

  tv_dict_add_bool(argvars[1].vval.v_dict, S_LEN("term"), true);
  f_jobstart(argvars, rettv, fptr);
  if (must_free) {
    tv_dict_free(argvars[1].vval.v_dict);
  }
}
