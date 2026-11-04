#include <inttypes.h>
#include <stdbool.h>                // for true
#include <stdint.h>

#include "nvim/api/private/converter.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/autocmd.h"
#include "nvim/channel.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/deprecated.h"
#include "nvim/eval/funcs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/eval/userfunc.h"
#include "nvim/ex_cmds.h"
#include "nvim/garray.h"
#include "nvim/gettext_defs.h"      // for _
#include "nvim/globals.h"
#include "nvim/macros_defs.h"       // for S_LEN
#include "nvim/memory.h"
#include "nvim/message.h"           // for semsg
#include "nvim/msgpack_rpc/channel.h"
#include "nvim/runtime.h"
#include "nvim/types_defs.h"

#include "eval/deprecated.c.generated.h"  // IWYU pragma: keep

/// "rpcnotify()" function (DEPRECATED)
void f_rpcnotify(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_NUMBER;
  rettv->vval.v_number = 0;

  if (check_secure()) {
    return;
  }

  if (argvars[0].v_type != VAR_NUMBER || argvars[0].vval.v_number < 0) {
    semsg(_(e_invarg2), "Channel id must be a positive integer");
    return;
  }

  if (argvars[1].v_type != VAR_STRING) {
    semsg(_(e_invarg2), "Event type must be a string");
    return;
  }

  MAXSIZE_TEMP_ARRAY(args, MAX_FUNC_ARGS);
  Arena arena = ARENA_EMPTY;

  for (typval_T *tv = argvars + 2; tv->v_type != VAR_UNKNOWN; tv++) {
    ADD_C(args, vim_to_object(tv, &arena, true));
  }

  bool ok = rpc_send_event((uint64_t)argvars[0].vval.v_number,
                           tv_get_string(&argvars[1]), args);

  arena_mem_free(arena_finish(&arena));

  if (!ok) {
    semsg(_(e_invarg2), "Channel doesn't exist");
    return;
  }
  rettv->vval.v_number = 1;
}

/// "rpcrequest()" function (DEPRECATED)
void f_rpcrequest(typval_T *argvars, typval_T *rettv, EvalFuncData fptr)
{
  rettv->v_type = VAR_NUMBER;
  rettv->vval.v_number = 0;
  const int l_provider_call_nesting = provider_call_nesting;

  if (check_secure()) {
    return;
  }

  if (argvars[0].v_type != VAR_NUMBER || argvars[0].vval.v_number <= 0) {
    semsg(_(e_invarg2), "Channel id must be a positive integer");
    return;
  }

  if (argvars[1].v_type != VAR_STRING) {
    semsg(_(e_invarg2), "Method name must be a string");
    return;
  }

  MAXSIZE_TEMP_ARRAY(args, MAX_FUNC_ARGS);
  Arena arena = ARENA_EMPTY;

  for (typval_T *tv = argvars + 2; tv->v_type != VAR_UNKNOWN; tv++) {
    ADD_C(args, vim_to_object(tv, &arena, true));
  }

  sctx_T save_current_sctx;
  char *save_autocmd_fname, *save_autocmd_match;
  bool save_autocmd_fname_full;
  int save_autocmd_bufnr;
  funccal_entry_T funccal_entry;

  if (l_provider_call_nesting) {
    // If this is called from a provider function, restore the scope
    // information of the caller.
    save_current_sctx = current_sctx;
    save_autocmd_fname = autocmd_fname;
    save_autocmd_match = autocmd_match;
    save_autocmd_fname_full = autocmd_fname_full;
    save_autocmd_bufnr = autocmd_bufnr;
    save_funccal(&funccal_entry);

    current_sctx = provider_caller_scope.script_ctx;
    ga_grow(&exestack, 1);
    ((estack_T *)exestack.ga_data)[exestack.ga_len++] = provider_caller_scope.es_entry;
    autocmd_fname = provider_caller_scope.autocmd_fname;
    autocmd_match = provider_caller_scope.autocmd_match;
    autocmd_fname_full = provider_caller_scope.autocmd_fname_full;
    autocmd_bufnr = provider_caller_scope.autocmd_bufnr;
    set_current_funccal((funccall_T *)(provider_caller_scope.funccalp));
  }

  Error err = ERROR_INIT;

  uint64_t chan_id = (uint64_t)argvars[0].vval.v_number;
  const char *method = tv_get_string(&argvars[1]);

  ArenaMem res_mem = NULL;
  Object result = rpc_send_call(chan_id, method, args, -1, &res_mem, &err);
  arena_mem_free(arena_finish(&arena));

  if (l_provider_call_nesting) {
    current_sctx = save_current_sctx;
    exestack.ga_len--;
    autocmd_fname = save_autocmd_fname;
    autocmd_match = save_autocmd_match;
    autocmd_fname_full = save_autocmd_fname_full;
    autocmd_bufnr = save_autocmd_bufnr;
    restore_funccal();
  }

  if (ERROR_SET(&err)) {
    const char *name = NULL;
    Channel *chan = find_channel(chan_id);
    if (chan) {
      name = get_client_info(chan, "name");
    }
    if (name) {
      semsg_multiline("rpc_error", "Invoking '%s' on channel %" PRIu64 " (%s):\n%s",
                      method, chan_id, name, err.msg);
    } else {
      semsg_multiline("rpc_error", "Invoking '%s' on channel %" PRIu64 ":\n%s",
                      method, chan_id, err.msg);
    }

    goto end;
  }

  object_to_vim(result, rettv, &err);

end:
  arena_mem_free(res_mem);
  api_clear_error(&err);
}

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
