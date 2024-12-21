#include <assert.h>
#include <lauxlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/autocmd.h"
#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/typval_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/globals.h"
#include "nvim/lua/executor.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/vim_defs.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/autocmd.c.generated.h"
#endif

#define AUCMD_MAX_PATTERNS 256

// Copy string or array of strings into an empty array.
// Get the event number, unless it is an error. Then do `or_else`.
#define GET_ONE_EVENT(event_nr, event_str, or_else) \
  event_T event_nr = \
    event_name2nr_str(event_str.data.string); \
  VALIDATE_S((event_nr < NUM_EVENTS), "event", event_str.data.string.data, { \
    or_else; \
  });

// ID for associating autocmds created via nvim_create_autocmd
// Used to delete autocmds from nvim_del_autocmd
static int64_t next_autocmd_id = 1;

/// Get all autocommands that match the corresponding {opts}.
///
/// These examples will get autocommands matching ALL the given criteria:
///
/// ```lua
/// -- Matches all criteria
/// autocommands = vim.api.nvim_get_autocmds({
///   group = "MyGroup",
///   event = {"BufEnter", "BufWinEnter"},
///   pattern = {"*.c", "*.h"}
/// })
///
/// -- All commands from one group
/// autocommands = vim.api.nvim_get_autocmds({
///   group = "MyGroup",
/// })
/// ```
///
/// NOTE: When multiple patterns or events are provided, it will find all the autocommands that
/// match any combination of them.
///
/// @param opts Dict with at least one of the following:
///             - group (string|integer): the autocommand group name or id to match against.
///             - event (string|array): event or events to match against |autocmd-events|.
///             - pattern (string|array): pattern or patterns to match against |autocmd-pattern|.
///             Cannot be used with {buffer}
///             - buffer: Buffer number or list of buffer numbers for buffer local autocommands
///             |autocmd-buflocal|. Cannot be used with {pattern}
/// @return Array of autocommands matching the criteria, with each item
///             containing the following fields:
///             - id (number): the autocommand id (only when defined with the API).
///             - group (integer): the autocommand group id.
///             - group_name (string): the autocommand group name.
///             - desc (string): the autocommand description.
///             - event (string): the autocommand event.
///             - command (string): the autocommand command. Note: this will be empty if a callback is set.
///             - callback (function|string|nil): Lua function or name of a Vim script function
///               which is executed when this autocommand is triggered.
///             - once (boolean): whether the autocommand is only run once.
///             - pattern (string): the autocommand pattern.
///               If the autocommand is buffer local |autocmd-buffer-local|:
///             - buflocal (boolean): true if the autocommand is buffer local.
///             - buffer (number): the buffer number.
Array nvim_get_autocmds(Dict(get_autocmds) *opts, Arena *arena, Error *err)
  FUNC_API_SINCE(9)
{
  // TODO(tjdevries): Would be cool to add nvim_get_autocmds({ id = ... })

  ArrayBuilder autocmd_list = KV_INITIAL_VALUE;
  kvi_init(autocmd_list);
  char *pattern_filters[AUCMD_MAX_PATTERNS];

  Array buffers = ARRAY_DICT_INIT;

  bool event_set[NUM_EVENTS] = { false };
  bool check_event = false;

  int group = 0;

  switch (opts->group.type) {
  case kObjectTypeNil:
    break;
  case kObjectTypeString:
    group = augroup_find(opts->group.data.string.data);
    VALIDATE_S((group >= 0), "group", opts->group.data.string.data, {
      goto cleanup;
    });
    break;
  case kObjectTypeInteger:
    group = (int)opts->group.data.integer;
    char *name = group == 0 ? NULL : augroup_name(group);
    VALIDATE_INT(augroup_exists(name), "group", opts->group.data.integer, {
      goto cleanup;
    });
    break;
  default:
    VALIDATE_EXP(false, "group", "String or Integer", api_typename(opts->group.type), {
      goto cleanup;
    });
  }

  if (HAS_KEY(opts, get_autocmds, event)) {
    check_event = true;

    Object v = opts->event;
    if (v.type == kObjectTypeString) {
      GET_ONE_EVENT(event_nr, v, goto cleanup);
      event_set[event_nr] = true;
    } else if (v.type == kObjectTypeArray) {
      FOREACH_ITEM(v.data.array, event_v, {
        VALIDATE_T("event item", kObjectTypeString, event_v.type, {
          goto cleanup;
        });

        GET_ONE_EVENT(event_nr, event_v, goto cleanup);
        event_set[event_nr] = true;
      })
    } else {
      VALIDATE_EXP(false, "event", "String or Array", NULL, {
        goto cleanup;
      });
    }
  }

  VALIDATE((!HAS_KEY(opts, get_autocmds, pattern) || !HAS_KEY(opts, get_autocmds, buffer)),
           "%s", "Cannot use both 'pattern' and 'buffer'", {
    goto cleanup;
  });

  int pattern_filter_count = 0;
  if (HAS_KEY(opts, get_autocmds, pattern)) {
    Object v = opts->pattern;
    if (v.type == kObjectTypeString) {
      pattern_filters[pattern_filter_count] = v.data.string.data;
      pattern_filter_count += 1;
    } else if (v.type == kObjectTypeArray) {
      VALIDATE((v.data.array.size <= AUCMD_MAX_PATTERNS),
               "Too many patterns (maximum of %d)", AUCMD_MAX_PATTERNS, {
        goto cleanup;
      });

      FOREACH_ITEM(v.data.array, item, {
        VALIDATE_T("pattern", kObjectTypeString, item.type, {
          goto cleanup;
        });

        pattern_filters[pattern_filter_count] = item.data.string.data;
        pattern_filter_count += 1;
      });
    } else {
      VALIDATE_EXP(false, "pattern", "String or Array", api_typename(v.type), {
        goto cleanup;
      });
    }
  }

  if (opts->buffer.type == kObjectTypeInteger || opts->buffer.type == kObjectTypeBuffer) {
    buf_T *buf = find_buffer_by_handle((Buffer)opts->buffer.data.integer, err);
    if (ERROR_SET(err)) {
      goto cleanup;
    }

    String pat = arena_printf(arena, "<buffer=%d>", (int)buf->handle);
    buffers = arena_array(arena, 1);
    ADD_C(buffers, STRING_OBJ(pat));
  } else if (opts->buffer.type == kObjectTypeArray) {
    if (opts->buffer.data.array.size > AUCMD_MAX_PATTERNS) {
      api_set_error(err, kErrorTypeValidation, "Too many buffers (maximum of %d)",
                    AUCMD_MAX_PATTERNS);
      goto cleanup;
    }

    buffers = arena_array(arena, kv_size(opts->buffer.data.array));
    FOREACH_ITEM(opts->buffer.data.array, bufnr, {
      VALIDATE_EXP((bufnr.type == kObjectTypeInteger || bufnr.type == kObjectTypeBuffer),
                   "buffer", "Integer", api_typename(bufnr.type), {
        goto cleanup;
      });

      buf_T *buf = find_buffer_by_handle((Buffer)bufnr.data.integer, err);
      if (ERROR_SET(err)) {
        goto cleanup;
      }

      ADD_C(buffers, STRING_OBJ(arena_printf(arena, "<buffer=%d>", (int)buf->handle)));
    });
  } else if (HAS_KEY(opts, get_autocmds, buffer)) {
    VALIDATE_EXP(false, "buffer", "Integer or Array", api_typename(opts->buffer.type), {
      goto cleanup;
    });
  }

  FOREACH_ITEM(buffers, bufnr, {
    pattern_filters[pattern_filter_count] = bufnr.data.string.data;
    pattern_filter_count += 1;
  });

  FOR_ALL_AUEVENTS(event) {
    if (check_event && !event_set[event]) {
      continue;
    }

    AutoCmdVec *acs = au_get_autocmds_for_event(event);
    for (size_t i = 0; i < kv_size(*acs); i++) {
      AutoCmd *const ac = &kv_A(*acs, i);
      AutoPat *const ap = ac->pat;

      if (ap == NULL) {
        continue;
      }

      // Skip autocmds from invalid groups if passed.
      if (group != 0 && ap->group != group) {
        continue;
      }

      // Skip 'pattern' from invalid patterns if passed.
      if (pattern_filter_count > 0) {
        bool passed = false;
        for (int j = 0; j < pattern_filter_count; j++) {
          assert(j < AUCMD_MAX_PATTERNS);
          assert(pattern_filters[j]);

          char *pat = pattern_filters[j];
          int patlen = (int)strlen(pat);

          char pattern_buflocal[BUFLOCAL_PAT_LEN];
          if (aupat_is_buflocal(pat, patlen)) {
            aupat_normalize_buflocal_pat(pattern_buflocal, pat, patlen,
                                         aupat_get_buflocal_nr(pat, patlen));
            pat = pattern_buflocal;
          }

          if (strequal(ap->pat, pat)) {
            passed = true;
            break;
          }
        }

        if (!passed) {
          continue;
        }
      }

      Dict autocmd_info = arena_dict(arena, 11);

      if (ap->group != AUGROUP_DEFAULT) {
        PUT_C(autocmd_info, "group", INTEGER_OBJ(ap->group));
        PUT_C(autocmd_info, "group_name", CSTR_AS_OBJ(augroup_name(ap->group)));
      }

      if (ac->id > 0) {
        PUT_C(autocmd_info, "id", INTEGER_OBJ(ac->id));
      }

      if (ac->desc != NULL) {
        PUT_C(autocmd_info, "desc", CSTR_AS_OBJ(ac->desc));
      }

      if (ac->exec.type == CALLABLE_CB) {
        PUT_C(autocmd_info, "command", STRING_OBJ(STRING_INIT));

        Callback *cb = &ac->exec.callable.cb;
        switch (cb->type) {
        case kCallbackLua:
          if (nlua_ref_is_function(cb->data.luaref)) {
            PUT_C(autocmd_info, "callback", LUAREF_OBJ(api_new_luaref(cb->data.luaref)));
          }
          break;
        case kCallbackFuncref:
        case kCallbackPartial:
          PUT_C(autocmd_info, "callback", CSTR_AS_OBJ(callback_to_string(cb, arena)));
          break;
        case kCallbackNone:
          abort();
        }
      } else {
        PUT_C(autocmd_info, "command", CSTR_AS_OBJ(ac->exec.callable.cmd));
      }

      PUT_C(autocmd_info, "pattern", CSTR_AS_OBJ(ap->pat));
      PUT_C(autocmd_info, "event", CSTR_AS_OBJ(event_nr2name(event)));
      PUT_C(autocmd_info, "once", BOOLEAN_OBJ(ac->once));

      if (ap->buflocal_nr) {
        PUT_C(autocmd_info, "buflocal", BOOLEAN_OBJ(true));
        PUT_C(autocmd_info, "buffer", INTEGER_OBJ(ap->buflocal_nr));
      } else {
        PUT_C(autocmd_info, "buflocal", BOOLEAN_OBJ(false));
      }

      // TODO(sctx): It would be good to unify script_ctx to actually work with lua
      //  right now it's just super weird, and never really gives you the info that
      //  you would expect from this.
      //
      //  I think we should be able to get the line number, filename, etc. from lua
      //  when we're executing something, and it should be easy to then save that
      //  info here.
      //
      //  I think it's a big loss not getting line numbers of where options, autocmds,
      //  etc. are set (just getting "Sourced (lua)" or something is not that helpful.
      //
      //  Once we do that, we can put these into the autocmd_info, but I don't think it's
      //  useful to do that at this time.
      //
      // PUT_C(autocmd_info, "sid", INTEGER_OBJ(ac->script_ctx.sc_sid));
      // PUT_C(autocmd_info, "lnum", INTEGER_OBJ(ac->script_ctx.sc_lnum));

      kvi_push(autocmd_list, DICT_OBJ(autocmd_info));
    }
  }

cleanup:
  return arena_take_arraybuilder(arena, &autocmd_list);
}

/// Creates an |autocommand| event handler, defined by `callback` (Lua function or Vimscript
/// function _name_ string) or `command` (Ex command string).
///
/// Example using Lua callback:
///
/// ```lua
/// vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
///   pattern = {"*.c", "*.h"},
///   callback = function(ev)
///     print(string.format('event fired: %s', vim.inspect(ev)))
///   end
/// })
/// ```
///
/// Example using an Ex command as the handler:
///
/// ```lua
/// vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
///   pattern = {"*.c", "*.h"},
///   command = "echo 'Entering a C or C++ file'",
/// })
/// ```
///
/// Note: `pattern` is NOT automatically expanded (unlike with |:autocmd|), thus names like "$HOME"
/// and "~" must be expanded explicitly:
///
/// ```lua
/// pattern = vim.fn.expand("~") .. "/some/path/*.py"
/// ```
///
/// @param event (string|array) Event(s) that will trigger the handler (`callback` or `command`).
/// @param opts Options dict:
///             - group (string|integer) optional: autocommand group name or id to match against.
///             - pattern (string|array) optional: pattern(s) to match literally |autocmd-pattern|.
///             - buffer (integer) optional: buffer number for buffer-local autocommands
///             |autocmd-buflocal|. Cannot be used with {pattern}.
///             - desc (string) optional: description (for documentation and troubleshooting).
///             - callback (function|string) optional: Lua function (or Vimscript function name, if
///             string) called when the event(s) is triggered. Lua callback can return a truthy
///             value (not `false` or `nil`) to delete the autocommand. Receives one argument,
///             a table with these keys: [event-args]()
///                 - id: (number) autocommand id
///                 - event: (string) name of the triggered event |autocmd-events|
///                 - group: (number|nil) autocommand group id, if any
///                 - file: (string) [<afile>] (not expanded to a full path)
///                 - match: (string) [<amatch>] (expanded to a full path)
///                 - buf: (number) [<abuf>]
///                 - data: (any) arbitrary data passed from [nvim_exec_autocmds()] [event-data]()
///             - command (string) optional: Vim command to execute on event. Cannot be used with
///             {callback}
///             - once (boolean) optional: defaults to false. Run the autocommand
///             only once |autocmd-once|.
///             - nested (boolean) optional: defaults to false. Run nested
///             autocommands |autocmd-nested|.
///
/// @return Autocommand id (number)
/// @see |autocommand|
/// @see |nvim_del_autocmd()|
Integer nvim_create_autocmd(uint64_t channel_id, Object event, Dict(create_autocmd) *opts,
                            Arena *arena, Error *err)
  FUNC_API_SINCE(9)
{
  int64_t autocmd_id = -1;
  char *desc = NULL;
  AucmdExecutable aucmd = AUCMD_EXECUTABLE_INIT;
  Callback cb = CALLBACK_NONE;

  Array event_array = unpack_string_or_array(event, "event", true, arena, err);
  if (ERROR_SET(err)) {
    goto cleanup;
  }

  VALIDATE((!HAS_KEY(opts, create_autocmd, callback) || !HAS_KEY(opts, create_autocmd, command)),
           "%s", "Cannot use both 'callback' and 'command'", {
    goto cleanup;
  });

  if (HAS_KEY(opts, create_autocmd, callback)) {
    // NOTE: We could accept callable tables, but that isn't common in the API.

    Object *callback = &opts->callback;
    switch (callback->type) {
    case kObjectTypeLuaRef:
      VALIDATE_S((callback->data.luaref != LUA_NOREF), "callback", "<no value>", {
        goto cleanup;
      });
      VALIDATE_S(nlua_ref_is_function(callback->data.luaref), "callback", "<not a function>", {
        goto cleanup;
      });

      cb.type = kCallbackLua;
      cb.data.luaref = callback->data.luaref;
      callback->data.luaref = LUA_NOREF;
      break;
    case kObjectTypeString:
      cb.type = kCallbackFuncref;
      cb.data.funcref = string_to_cstr(callback->data.string);
      break;
    default:
      VALIDATE_EXP(false, "callback", "Lua function or Vim function name",
                   api_typename(callback->type), {
        goto cleanup;
      });
    }

    aucmd.type = CALLABLE_CB;
    aucmd.callable.cb = cb;
  } else if (HAS_KEY(opts, create_autocmd, command)) {
    aucmd.type = CALLABLE_EX;
    aucmd.callable.cmd = string_to_cstr(opts->command);
  } else {
    VALIDATE(false, "%s", "Required: 'command' or 'callback'", {
      goto cleanup;
    });
  }

  int au_group = get_augroup_from_object(opts->group, err);
  if (au_group == AUGROUP_ERROR) {
    goto cleanup;
  }

  bool has_buffer = HAS_KEY(opts, create_autocmd, buffer);

  VALIDATE((!HAS_KEY(opts, create_autocmd, pattern) || !has_buffer),
           "%s", "Cannot use both 'pattern' and 'buffer' for the same autocmd", {
    goto cleanup;
  });

  Array patterns = get_patterns_from_pattern_or_buf(opts->pattern, has_buffer, opts->buffer, "*",
                                                    arena, err);
  if (ERROR_SET(err)) {
    goto cleanup;
  }

  if (HAS_KEY(opts, create_autocmd, desc)) {
    desc = opts->desc.data;
  }

  VALIDATE_R((event_array.size > 0), "event", {
    goto cleanup;
  });

  autocmd_id = next_autocmd_id++;
  FOREACH_ITEM(event_array, event_str, {
    GET_ONE_EVENT(event_nr, event_str, goto cleanup);

    int retval;

    FOREACH_ITEM(patterns, pat, {
      // See: TODO(sctx)
      WITH_SCRIPT_CONTEXT(channel_id, {
        retval = autocmd_register(autocmd_id,
                                  event_nr,
                                  pat.data.string.data,
                                  (int)pat.data.string.size,
                                  au_group,
                                  opts->once,
                                  opts->nested,
                                  desc,
                                  aucmd);
      });

      if (retval == FAIL) {
        api_set_error(err, kErrorTypeException, "Failed to set autocmd");
        goto cleanup;
      }
    })
  });

cleanup:
  aucmd_exec_free(&aucmd);

  return autocmd_id;
}

/// Deletes an autocommand by id.
///
/// @param id Integer Autocommand id returned by |nvim_create_autocmd()|
void nvim_del_autocmd(Integer id, Error *err)
  FUNC_API_SINCE(9)
{
  VALIDATE_INT((id > 0), "autocmd id", id, {
    return;
  });
  if (!autocmd_delete_id(id)) {
    api_set_error(err, kErrorTypeException, "Failed to delete autocmd");
  }
}

/// Clears all autocommands selected by {opts}. To delete autocmds see |nvim_del_autocmd()|.
///
/// @param opts Parameters
///         - event: (string|table)
///              Examples:
///              - event: "pat1"
///              - event: { "pat1" }
///              - event: { "pat1", "pat2", "pat3" }
///         - pattern: (string|table)
///             - pattern or patterns to match exactly.
///                 - For example, if you have `*.py` as that pattern for the autocmd,
///                   you must pass `*.py` exactly to clear it. `test.py` will not
///                   match the pattern.
///             - defaults to clearing all patterns.
///             - NOTE: Cannot be used with {buffer}
///         - buffer: (bufnr)
///             - clear only |autocmd-buflocal| autocommands.
///             - NOTE: Cannot be used with {pattern}
///         - group: (string|int) The augroup name or id.
///             - NOTE: If not passed, will only delete autocmds *not* in any group.
///
void nvim_clear_autocmds(Dict(clear_autocmds) *opts, Arena *arena, Error *err)
  FUNC_API_SINCE(9)
{
  // TODO(tjdevries): Future improvements:
  //        - once: (boolean) - Only clear autocmds with once. See |autocmd-once|
  //        - nested: (boolean) - Only clear autocmds with nested. See |autocmd-nested|
  //        - group: Allow passing "*" or true or something like that to force doing all
  //        autocmds, regardless of their group.

  Array event_array = unpack_string_or_array(opts->event, "event", false, arena, err);
  if (ERROR_SET(err)) {
    return;
  }

  bool has_buffer = HAS_KEY(opts, clear_autocmds, buffer);

  VALIDATE((!HAS_KEY(opts, clear_autocmds, pattern) || !has_buffer),
           "%s", "Cannot use both 'pattern' and 'buffer'", {
    return;
  });

  int au_group = get_augroup_from_object(opts->group, err);
  if (au_group == AUGROUP_ERROR) {
    return;
  }

  // When we create the autocmds, we want to say that they are all matched, so that's *
  // but when we clear them, we want to say that we didn't pass a pattern, so that's NUL
  Array patterns = get_patterns_from_pattern_or_buf(opts->pattern, has_buffer, opts->buffer, "",
                                                    arena, err);
  if (ERROR_SET(err)) {
    return;
  }

  // If we didn't pass any events, that means clear all events.
  if (event_array.size == 0) {
    FOR_ALL_AUEVENTS(event) {
      FOREACH_ITEM(patterns, pat_object, {
        char *pat = pat_object.data.string.data;
        if (!clear_autocmd(event, pat, au_group, err)) {
          return;
        }
      });
    }
  } else {
    FOREACH_ITEM(event_array, event_str, {
      GET_ONE_EVENT(event_nr, event_str, return );

      FOREACH_ITEM(patterns, pat_object, {
        char *pat = pat_object.data.string.data;
        if (!clear_autocmd(event_nr, pat, au_group, err)) {
          return;
        }
      });
    });
  }
}

/// Create or get an autocommand group |autocmd-groups|.
///
/// To get an existing group id, do:
///
/// ```lua
/// local id = vim.api.nvim_create_augroup("MyGroup", {
///     clear = false
/// })
/// ```
///
/// @param name String: The name of the group
/// @param opts Dict Parameters
///                 - clear (bool) optional: defaults to true. Clear existing
///                 commands if the group already exists |autocmd-groups|.
/// @return Integer id of the created group.
/// @see |autocmd-groups|
Integer nvim_create_augroup(uint64_t channel_id, String name, Dict(create_augroup) *opts,
                            Error *err)
  FUNC_API_SINCE(9)
{
  char *augroup_name = name.data;
  bool clear_autocmds = GET_BOOL_OR_TRUE(opts, create_augroup, clear);

  int augroup = -1;
  WITH_SCRIPT_CONTEXT(channel_id, {
    augroup = augroup_add(augroup_name);
    if (augroup == AUGROUP_ERROR) {
      api_set_error(err, kErrorTypeException, "Failed to set augroup");
      return -1;
    }

    if (clear_autocmds) {
      FOR_ALL_AUEVENTS(event) {
        aucmd_del_for_event_and_group(event, augroup);
      }
    }
  });

  return augroup;
}

/// Delete an autocommand group by id.
///
/// To get a group id one can use |nvim_get_autocmds()|.
///
/// NOTE: behavior differs from |:augroup-delete|. When deleting a group, autocommands contained in
/// this group will also be deleted and cleared. This group will no longer exist.
/// @param id Integer The id of the group.
/// @see |nvim_del_augroup_by_name()|
/// @see |nvim_create_augroup()|
void nvim_del_augroup_by_id(Integer id, Error *err)
  FUNC_API_SINCE(9)
{
  TRY_WRAP(err, {
    char *name = id == 0 ? NULL : augroup_name((int)id);
    augroup_del(name, false);
  });
}

/// Delete an autocommand group by name.
///
/// NOTE: behavior differs from |:augroup-delete|. When deleting a group, autocommands contained in
/// this group will also be deleted and cleared. This group will no longer exist.
/// @param name String The name of the group.
/// @see |autocmd-groups|
void nvim_del_augroup_by_name(String name, Error *err)
  FUNC_API_SINCE(9)
{
  TRY_WRAP(err, {
    augroup_del(name.data, false);
  });
}

/// Execute all autocommands for {event} that match the corresponding
///  {opts} |autocmd-execute|.
/// @param event (String|Array) The event or events to execute
/// @param opts Dict of autocommand options:
///             - group (string|integer) optional: the autocommand group name or
///             id to match against. |autocmd-groups|.
///             - pattern (string|array) optional: defaults to "*" |autocmd-pattern|. Cannot be used
///             with {buffer}.
///             - buffer (integer) optional: buffer number |autocmd-buflocal|. Cannot be used with
///             {pattern}.
///             - modeline (bool) optional: defaults to true. Process the
///             modeline after the autocommands [<nomodeline>].
///             - data (any): arbitrary data to send to the autocommand callback. See
///             |nvim_create_autocmd()| for details.
/// @see |:doautocmd|
void nvim_exec_autocmds(Object event, Dict(exec_autocmds) *opts, Arena *arena, Error *err)
  FUNC_API_SINCE(9)
{
  int au_group = AUGROUP_ALL;
  bool modeline = true;

  buf_T *buf = curbuf;

  Object *data = NULL;

  Array event_array = unpack_string_or_array(event, "event", true, arena, err);
  if (ERROR_SET(err)) {
    return;
  }

  switch (opts->group.type) {
  case kObjectTypeNil:
    break;
  case kObjectTypeString:
    au_group = augroup_find(opts->group.data.string.data);
    VALIDATE_S((au_group != AUGROUP_ERROR), "group", opts->group.data.string.data, {
      return;
    });
    break;
  case kObjectTypeInteger:
    au_group = (int)opts->group.data.integer;
    char *name = au_group == 0 ? NULL : augroup_name(au_group);
    VALIDATE_INT(augroup_exists(name), "group", (int64_t)au_group, {
      return;
    });
    break;
  default:
    VALIDATE_EXP(false, "group", "String or Integer", api_typename(opts->group.type), {
      return;
    });
  }

  bool has_buffer = false;
  if (HAS_KEY(opts, exec_autocmds, buffer)) {
    VALIDATE((!HAS_KEY(opts, exec_autocmds, pattern)),
             "%s", "Cannot use both 'pattern' and 'buffer' for the same autocmd", {
      return;
    });

    has_buffer = true;
    buf = find_buffer_by_handle(opts->buffer, err);

    if (ERROR_SET(err)) {
      return;
    }
  }

  Array patterns = get_patterns_from_pattern_or_buf(opts->pattern, has_buffer, opts->buffer, "",
                                                    arena, err);
  if (ERROR_SET(err)) {
    return;
  }

  if (HAS_KEY(opts, exec_autocmds, data)) {
    data = &opts->data;
  }

  modeline = GET_BOOL_OR_TRUE(opts, exec_autocmds, modeline);

  bool did_aucmd = false;
  FOREACH_ITEM(event_array, event_str, {
    GET_ONE_EVENT(event_nr, event_str, return )

    FOREACH_ITEM(patterns, pat, {
      char *fname = !has_buffer ? pat.data.string.data : NULL;
      did_aucmd |= apply_autocmds_group(event_nr, fname, NULL, true, au_group, buf, NULL, data);
    })
  })

  if (did_aucmd && modeline) {
    do_modelines(0);
  }
}

static Array unpack_string_or_array(Object v, char *k, bool required, Arena *arena, Error *err)
{
  if (v.type == kObjectTypeString) {
    Array arr = arena_array(arena, 1);
    ADD_C(arr, v);
    return arr;
  } else if (v.type == kObjectTypeArray) {
    if (!check_string_array(v.data.array, k, true, err)) {
      return (Array)ARRAY_DICT_INIT;
    }
    return v.data.array;
  } else {
    VALIDATE_EXP(!required, k, "Array or String", api_typename(v.type), {
      return (Array)ARRAY_DICT_INIT;
    });
  }

  return (Array)ARRAY_DICT_INIT;
}

// Returns AUGROUP_ERROR if there was a problem with {group}
static int get_augroup_from_object(Object group, Error *err)
{
  int au_group = AUGROUP_ERROR;

  switch (group.type) {
  case kObjectTypeNil:
    return AUGROUP_DEFAULT;
  case kObjectTypeString:
    au_group = augroup_find(group.data.string.data);
    VALIDATE_S((au_group != AUGROUP_ERROR), "group", group.data.string.data, {
      return AUGROUP_ERROR;
    });

    return au_group;
  case kObjectTypeInteger:
    au_group = (int)group.data.integer;
    char *name = au_group == 0 ? NULL : augroup_name(au_group);
    VALIDATE_INT(augroup_exists(name), "group", (int64_t)au_group, {
      return AUGROUP_ERROR;
    });
    return au_group;
  default:
    VALIDATE_EXP(false, "group", "String or Integer", api_typename(group.type), {
      return AUGROUP_ERROR;
    });
  }
}

static Array get_patterns_from_pattern_or_buf(Object pattern, bool has_buffer, Buffer buffer,
                                              char *fallback, Arena *arena, Error *err)
{
  ArrayBuilder patterns = ARRAY_DICT_INIT;
  kvi_init(patterns);

  if (pattern.type != kObjectTypeNil) {
    if (pattern.type == kObjectTypeString) {
      const char *pat = pattern.data.string.data;
      size_t patlen = aucmd_pattern_length(pat);
      while (patlen) {
        kvi_push(patterns, CBUF_TO_ARENA_OBJ(arena, pat, patlen));

        pat = aucmd_next_pattern(pat, patlen);
        patlen = aucmd_pattern_length(pat);
      }
    } else if (pattern.type == kObjectTypeArray) {
      if (!check_string_array(pattern.data.array, "pattern", true, err)) {
        return (Array)ARRAY_DICT_INIT;
      }

      Array array = pattern.data.array;
      FOREACH_ITEM(array, entry, {
        const char *pat = entry.data.string.data;
        size_t patlen = aucmd_pattern_length(pat);
        while (patlen) {
          kvi_push(patterns, CBUF_TO_ARENA_OBJ(arena, pat, patlen));

          pat = aucmd_next_pattern(pat, patlen);
          patlen = aucmd_pattern_length(pat);
        }
      })
    } else {
      VALIDATE_EXP(false, "pattern", "String or Table", api_typename(pattern.type), {
        return (Array)ARRAY_DICT_INIT;
      });
    }
  } else if (has_buffer) {
    buf_T *buf = find_buffer_by_handle(buffer, err);
    if (ERROR_SET(err)) {
      return (Array)ARRAY_DICT_INIT;
    }

    kvi_push(patterns, STRING_OBJ(arena_printf(arena, "<buffer=%d>", (int)buf->handle)));
  }

  if (kv_size(patterns) == 0 && fallback) {
    kvi_push(patterns, CSTR_AS_OBJ(fallback));
  }

  return arena_take_arraybuilder(arena, &patterns);
}

static bool clear_autocmd(event_T event, char *pat, int au_group, Error *err)
{
  if (do_autocmd_event(event, pat, false, false, "", true, au_group) == FAIL) {
    api_set_error(err, kErrorTypeException, "Failed to clear autocmd");
    return false;
  }

  return true;
}

#undef GET_ONE_EVENT
