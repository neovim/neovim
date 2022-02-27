#include <stdbool.h>
#include <stdio.h>

#include "lauxlib.h"
#include "nvim/api/autocmd.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/eval/typval.h"
#include "nvim/fileio.h"
#include "nvim/lua/executor.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/autocmd.c.generated.h"
#endif

#define AUCMD_MAX_PATTERNS 256

// Check whether every item in the array is a kObjectTypeString
#define CHECK_STRING_ARRAY(__array, k, v, goto_name) \
  for (size_t j = 0; j < __array.size; j++) { \
    Object item = __array.items[j]; \
    if (item.type != kObjectTypeString) { \
      api_set_error(err, \
                    kErrorTypeValidation, \
                    "All entries in '%s' must be strings", \
                    k); \
      goto goto_name; \
    } \
  }

// Copy string or array of strings into an empty array.
#define UNPACK_STRING_OR_ARRAY(__array, k, v, goto_name) \
  if (v->type == kObjectTypeString) { \
    ADD(__array, copy_object(*v)); \
  } else if (v->type == kObjectTypeArray) { \
    CHECK_STRING_ARRAY(__array, k, v, goto_name); \
    __array = copy_array(v->data.array); \
  } else { \
    api_set_error(err, \
                  kErrorTypeValidation, \
                  "'%s' must be an array or a string.", \
                  k); \
    goto goto_name; \
  }

// Get the event number, unless it is an error. Then goto `goto_name`.
#define GET_ONE_EVENT(event_nr, event_str, goto_name) \
  char_u *__next_ev; \
  event_T event_nr = \
    event_name2nr((char_u *)event_str.data.string.data, &__next_ev); \
  if (event_nr >= NUM_EVENTS) { \
    api_set_error(err, kErrorTypeValidation, "unexpected event"); \
    goto goto_name; \
  }


// ID for associating autocmds created via nvim_create_autocmd
// Used to delete autocmds from nvim_del_autocmd
static int64_t next_autocmd_id = 1;

/// Get autocmds that match the requirements passed to {opts}.
/// group
/// event
/// pattern
///
/// -- @param {string} event - event or events to match against
/// vim.api.nvim_get_autocmds({ event = "FileType" })
///
Array nvim_get_autocmds(Dict(get_autocmds) *opts, Error *err)
  FUNC_API_SINCE(9)
{
  Array autocmd_list = ARRAY_DICT_INIT;
  char_u *pattern_filters[AUCMD_MAX_PATTERNS];
  char_u pattern_buflocal[BUFLOCAL_PAT_LEN];

  bool event_set[NUM_EVENTS] = { false };
  bool check_event = false;

  int group = 0;

  if (opts->group.type != kObjectTypeNil) {
    Object v = opts->group;
    if (v.type != kObjectTypeString) {
      api_set_error(err, kErrorTypeValidation, "group must be a string.");
      goto cleanup;
    }

    group = augroup_find(v.data.string.data);

    if (group < 0) {
      api_set_error(err, kErrorTypeValidation, "invalid augroup passed.");
      goto cleanup;
    }
  }

  if (opts->event.type != kObjectTypeNil) {
    check_event = true;

    Object v = opts->event;
    if (v.type == kObjectTypeString) {
      GET_ONE_EVENT(event_nr, v, cleanup);
      event_set[event_nr] = true;
    } else if (v.type == kObjectTypeArray) {
      FOREACH_ITEM(v.data.array, event_v, {
        if (event_v.type != kObjectTypeString) {
          api_set_error(err,
                        kErrorTypeValidation,
                        "Every event must be a string in 'event'");
          goto cleanup;
        }

        GET_ONE_EVENT(event_nr, event_v, cleanup);
        event_set[event_nr] = true;
      })
    } else {
      api_set_error(err,
                    kErrorTypeValidation,
                    "Not a valid 'event' value. Must be a string or an array");
      goto cleanup;
    }
  }

  int pattern_filter_count = 0;
  if (opts->pattern.type != kObjectTypeNil) {
    Object v = opts->pattern;
    if (v.type == kObjectTypeString) {
      pattern_filters[pattern_filter_count] = (char_u *)v.data.string.data;
      pattern_filter_count += 1;
    } else if (v.type == kObjectTypeArray) {
      FOREACH_ITEM(v.data.array, item, {
        pattern_filters[pattern_filter_count] = (char_u *)item.data.string.data;
        pattern_filter_count += 1;
      });
    } else {
      api_set_error(err,
                    kErrorTypeValidation,
                    "Not a valid 'pattern' value. Must be a string or an array");
      goto cleanup;
    }

    if (pattern_filter_count >= AUCMD_MAX_PATTERNS) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "Too many patterns. Please limit yourself to less");
      goto cleanup;
    }
  }

  FOR_ALL_AUEVENTS(event) {
    if (check_event && !event_set[event]) {
      continue;
    }

    for (AutoPat *ap = au_get_autopat_for_event(event);
         ap != NULL;
         ap = ap->next) {
      if (ap == NULL || ap->cmds == NULL) {
        continue;
      }

      // Skip autocmds from invalid groups if passed.
      if (group != 0 && ap->group != group) {
        continue;
      }

      // Skip 'pattern' from invalid patterns if passed.
      if (pattern_filter_count > 0) {
        bool passed = false;
        for (int i = 0; i < pattern_filter_count; i++) {
          assert(i < AUCMD_MAX_PATTERNS);
          assert(pattern_filters[i]);

          char_u *pat = pattern_filters[i];
          int patlen = (int)STRLEN(pat);

          if (aupat_is_buflocal(pat, patlen)) {
            aupat_normalize_buflocal_pat(pattern_buflocal,
                                         pat,
                                         patlen,
                                         aupat_get_buflocal_nr(pat, patlen));

            pat = pattern_buflocal;
          }

          if (strequal((char *)ap->pat, (char *)pat)) {
            passed = true;
            break;
          }
        }

        if (!passed) {
          continue;
        }
      }

      for (AutoCmd *ac = ap->cmds; ac != NULL; ac = ac->next) {
        if (aucmd_exec_is_deleted(ac->exec)) {
          continue;
        }
        Dictionary autocmd_info = ARRAY_DICT_INIT;

        if (ap->group != AUGROUP_DEFAULT) {
          PUT(autocmd_info, "group", INTEGER_OBJ(ap->group));
        }

        if (ac->id > 0) {
          PUT(autocmd_info, "id", INTEGER_OBJ(ac->id));
        }

        if (ac->desc != NULL) {
          PUT(autocmd_info, "desc", CSTR_TO_OBJ(ac->desc));
        }

        PUT(autocmd_info,
            "command",
            STRING_OBJ(cstr_to_string(aucmd_exec_to_string(ac, ac->exec))));

        PUT(autocmd_info,
            "pattern",
            STRING_OBJ(cstr_to_string((char *)ap->pat)));

        PUT(autocmd_info, "once", BOOLEAN_OBJ(ac->once));

        if (ap->buflocal_nr) {
          PUT(autocmd_info, "buflocal", BOOLEAN_OBJ(true));
          PUT(autocmd_info, "buffer", INTEGER_OBJ(ap->buflocal_nr));
        } else {
          PUT(autocmd_info, "buflocal", BOOLEAN_OBJ(false));
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
        // PUT(autocmd_info, "sid", INTEGER_OBJ(ac->script_ctx.sc_sid));
        // PUT(autocmd_info, "lnum", INTEGER_OBJ(ac->script_ctx.sc_lnum));

        ADD(autocmd_list, DICTIONARY_OBJ(autocmd_info));
      }
    }
  }

cleanup:
  return autocmd_list;
}

/// Define an autocmd.
/// @param opts Dictionary
///          Required keys:
///              event: string | ArrayOf(string)
/// event = "pat1,pat2,pat3",
/// event = "pat1"
/// event = {"pat1"}
/// event = {"pat1", "pat2", "pat3"}
///
///
/// -- @param {string} name - augroup name
/// -- @param {string | table} event - event or events to match against
/// -- @param {string | table} pattern - pattern or patterns to match against
/// -- @param {string | function} callback - function or string to execute on autocmd
/// -- @param {string} command - optional, vimscript command
///          Eg. command = "let g:value_set = v:true"
/// -- @param {boolean} once - optional, defaults to false
///
/// -- pattern = comma delimited list of patterns | pattern | { pattern, ... }
///
/// pattern = "*.py,*.pyi"
/// pattern = "*.py"
/// pattern = {"*.py"}
/// pattern = { "*.py", "*.pyi" }
///
/// -- not supported
/// pattern = {"*.py,*.pyi"}
///
/// -- event = string | string[]
/// event = "FileType,CursorHold"
/// event = "BufPreWrite"
/// event = {"BufPostWrite"}
/// event = {"CursorHold", "BufPreWrite", "BufPostWrite"}
Integer nvim_create_autocmd(uint64_t channel_id, Dict(create_autocmd) *opts, Error *err)
  FUNC_API_SINCE(9)
{
  int64_t autocmd_id = -1;

  const char_u pattern_buflocal[BUFLOCAL_PAT_LEN];
  int au_group = AUGROUP_DEFAULT;
  char *desc = NULL;

  Array patterns = ARRAY_DICT_INIT;
  Array event_array = ARRAY_DICT_INIT;

  AucmdExecutable aucmd = AUCMD_EXECUTABLE_INIT;
  Callback cb = CALLBACK_NONE;

  if (opts->callback.type != kObjectTypeNil && opts->command.type != kObjectTypeNil) {
    api_set_error(err, kErrorTypeValidation,
                  "cannot pass both: 'callback' and 'command' for the same autocmd");
    goto cleanup;
  } else if (opts->callback.type != kObjectTypeNil) {
    // TODO(tjdevries): It's possible we could accept callable tables,
    // but we don't do that many other places, so for the moment let's
    // not do that.

    Object *callback = &opts->callback;
    if (callback->type == kObjectTypeLuaRef) {
      if (callback->data.luaref == LUA_NOREF) {
        api_set_error(err,
                      kErrorTypeValidation,
                      "must pass an actual value");
        goto cleanup;
      }

      if (!nlua_ref_is_function(callback->data.luaref)) {
        api_set_error(err,
                      kErrorTypeValidation,
                      "must pass a function for callback");
        goto cleanup;
      }

      cb.type = kCallbackLua;
      cb.data.luaref = api_new_luaref(callback->data.luaref);
    } else if (callback->type == kObjectTypeString) {
      cb.type = kCallbackFuncref;
      cb.data.funcref = vim_strsave((char_u *)callback->data.string.data);
    } else {
      api_set_error(err,
                    kErrorTypeException,
                    "'callback' must be a lua function or name of vim function");
      goto cleanup;
    }

    aucmd.type = CALLABLE_CB;
    aucmd.callable.cb = cb;
  } else if (opts->command.type != kObjectTypeNil) {
    Object *command = &opts->command;
    if (command->type == kObjectTypeString) {
      aucmd.type = CALLABLE_EX;
      aucmd.callable.cmd = vim_strsave((char_u *)command->data.string.data);
    } else {
      api_set_error(err,
                    kErrorTypeValidation,
                    "'command' must be a string");
      goto cleanup;
    }
  } else {
    api_set_error(err, kErrorTypeValidation, "must pass one of: 'command', 'callback'");
    goto cleanup;
  }

  if (opts->event.type != kObjectTypeNil) {
    UNPACK_STRING_OR_ARRAY(event_array, "event", (&opts->event), cleanup)
  }

  bool is_once = api_object_to_bool(opts->once, "once", false, err);
  bool is_nested = api_object_to_bool(opts->nested, "nested", false, err);

  // TOOD: accept number for namespace instead
  if (opts->group.type != kObjectTypeNil) {
    Object *v = &opts->group;
    if (v->type != kObjectTypeString) {
      api_set_error(err, kErrorTypeValidation, "'group' must be a string");
      goto cleanup;
    }

    au_group = augroup_find(v->data.string.data);

    if (au_group == AUGROUP_ERROR) {
      api_set_error(err,
                    kErrorTypeException,
                    "invalid augroup: %s", v->data.string.data);

      goto cleanup;
    }
  }

  if (opts->pattern.type != kObjectTypeNil && opts->buffer.type != kObjectTypeNil) {
    api_set_error(err, kErrorTypeValidation,
                  "cannot pass both: 'pattern' and 'buffer' for the same autocmd");
    goto cleanup;
  } else if (opts->pattern.type != kObjectTypeNil) {
    Object *v = &opts->pattern;

    if (v->type == kObjectTypeString) {
      char_u *pat = (char_u *)v->data.string.data;
      size_t patlen = aucmd_pattern_length(pat);
      while (patlen) {
        ADD(patterns, STRING_OBJ(cbuf_to_string((char *)pat, patlen)));

        pat = aucmd_next_pattern(pat, patlen);
        patlen = aucmd_pattern_length(pat);
      }
    } else if (v->type == kObjectTypeArray) {
      CHECK_STRING_ARRAY(patterns, "pattern", v, cleanup);

      Array array = v->data.array;
      for (size_t i = 0; i < array.size; i++) {
        char_u *pat = (char_u *)array.items[i].data.string.data;
        size_t patlen = aucmd_pattern_length(pat);
        while (patlen) {
          ADD(patterns, STRING_OBJ(cbuf_to_string((char *)pat, patlen)));

          pat = aucmd_next_pattern(pat, patlen);
          patlen = aucmd_pattern_length(pat);
        }
      }
    } else {
      api_set_error(err,
                    kErrorTypeValidation,
                    "'pattern' must be a string");
      goto cleanup;
    }
  } else if (opts->buffer.type != kObjectTypeNil) {
    if (opts->buffer.type != kObjectTypeInteger) {
      api_set_error(err,
                    kErrorTypeValidation,
                    "'buffer' must be an integer");
      goto cleanup;
    }

    buf_T *buf = find_buffer_by_handle((Buffer)opts->buffer.data.integer, err);
    if (ERROR_SET(err)) {
      goto cleanup;
    }

    snprintf((char *)pattern_buflocal, BUFLOCAL_PAT_LEN, "<buffer=%d>", (int)buf->handle);
    ADD(patterns, STRING_OBJ(cstr_to_string((char *)pattern_buflocal)));
  }

  if (aucmd.type == CALLABLE_NONE) {
    api_set_error(err,
                  kErrorTypeValidation,
                  "'command' or 'callback' is required");
    goto cleanup;
  }

  if (opts->desc.type != kObjectTypeNil) {
    if (opts->desc.type == kObjectTypeString) {
      desc = opts->desc.data.string.data;
    } else {
      api_set_error(err,
                    kErrorTypeValidation,
                    "'desc' must be a string");
      goto cleanup;
    }
  }

  if (patterns.size == 0) {
    ADD(patterns, STRING_OBJ(STATIC_CSTR_TO_STRING("*")));
  }

  if (event_array.size == 0) {
    api_set_error(err, kErrorTypeValidation, "'event' is a required key");
    goto cleanup;
  }

  autocmd_id = next_autocmd_id++;
  FOREACH_ITEM(event_array, event_str, {
    GET_ONE_EVENT(event_nr, event_str, cleanup);

    int retval;

    for (size_t i = 0; i < patterns.size; i++) {
      Object pat = patterns.items[i];

      // See: TODO(sctx)
      WITH_SCRIPT_CONTEXT(channel_id, {
        retval = autocmd_register(autocmd_id,
                                  event_nr,
                                  (char_u *)pat.data.string.data,
                                  (int)pat.data.string.size,
                                  au_group,
                                  is_once,
                                  is_nested,
                                  desc,
                                  aucmd);
      });

      if (retval == FAIL) {
        api_set_error(err, kErrorTypeException, "Failed to set autocmd");
        goto cleanup;
      }
    }
  });


cleanup:
  aucmd_exec_free(&aucmd);
  api_free_array(event_array);
  api_free_array(patterns);

  return autocmd_id;
}

/// Delete an autocmd by ID. Autocmds only return IDs when created
/// via the API.
///
/// @param id Integer The ID returned by nvim_create_autocmd
void nvim_del_autocmd(Integer id)
  FUNC_API_SINCE(9)
{
  autocmd_delete_id(id);
}

/// Create or get an augroup.
///
/// To get an existing augroup ID, do:
/// <pre>
///     local id = vim.api.nvim_create_augroup({ name = name, clear = false });
/// </pre>
///
/// @param opts Parameters
///                 - name (string): The name of the augroup
///                 - clear (bool): Whether to clear existing commands or not.
//                                  Defaults to true.
///                     See |autocmd-groups|
Integer nvim_create_augroup(uint64_t channel_id, Dict(create_augroup) *opts, Error *err)
  FUNC_API_SINCE(9)
{
  bool clear_autocmds = api_object_to_bool(opts->clear, "clear", true, err);

  if (opts->name.type != kObjectTypeString) {
    api_set_error(err, kErrorTypeValidation, "'name' is required and must be a string");
    return -1;
  }
  char *name = opts->name.data.string.data;

  int augroup = -1;
  WITH_SCRIPT_CONTEXT(channel_id, {
    augroup = augroup_add(name);
    if (augroup == AUGROUP_ERROR) {
      api_set_error(err, kErrorTypeException, "Failed to set augroup");
      return -1;
    }

    if (clear_autocmds) {
      FOR_ALL_AUEVENTS(event) {
        aupat_del_for_event_and_group(event, augroup);
      }
    }
  });

  return augroup;
}

/// NOTE: behavior differs from augroup-delete.
/// When deleting an augroup, autocmds contained by this augroup will also be deleted and cleared.
/// This augroup will no longer exist
void nvim_del_augroup_by_id(Integer id)
  FUNC_API_SINCE(9)
{
  char *name = augroup_name((int)id);
  augroup_del(name, false);
}

/// NOTE: behavior differs from augroup-delete.
/// When deleting an augroup, autocmds contained by this augroup will also be deleted and cleared.
/// This augroup will no longer exist
void nvim_del_augroup_by_name(String name)
  FUNC_API_SINCE(9)
{
  augroup_del(name.data, false);
}

/// -- @param {string} group - autocmd group name
/// -- @param {number} buffer - buffer number
/// -- @param {string | table} event - event or events to match against
/// -- @param {string | table} pattern - optional, defaults to "*".
/// vim.api.nvim_do_autcmd({ group, buffer, pattern, event, modeline })
void nvim_do_autocmd(Dict(do_autocmd) *opts, Error *err)
  FUNC_API_SINCE(9)
{
  int au_group = AUGROUP_ALL;
  bool modeline = true;

  buf_T *buf = curbuf;
  bool set_buf = false;

  char_u *pattern = NULL;
  bool set_pattern = false;

  Array event_array = ARRAY_DICT_INIT;

  if (opts->group.type != kObjectTypeNil) {
    if (opts->group.type != kObjectTypeString) {
      api_set_error(err, kErrorTypeValidation, "'group' must be a string");
      goto cleanup;
    }

    au_group = augroup_find(opts->group.data.string.data);

    if (au_group == AUGROUP_ERROR) {
      api_set_error(err,
                    kErrorTypeException,
                    "invalid augroup: %s", opts->group.data.string.data);

      goto cleanup;
    }
  }

  if (opts->buffer.type != kObjectTypeNil) {
    Object buf_obj = opts->buffer;
    if (buf_obj.type != kObjectTypeInteger && buf_obj.type != kObjectTypeBuffer) {
      api_set_error(err, kErrorTypeException, "invalid buffer: %d", buf_obj.type);
      goto cleanup;
    }

    buf = find_buffer_by_handle((Buffer)buf_obj.data.integer, err);
    set_buf = true;

    if (ERROR_SET(err)) {
      goto cleanup;
    }
  }

  if (opts->pattern.type != kObjectTypeNil) {
    if (opts->pattern.type != kObjectTypeString) {
      api_set_error(err, kErrorTypeValidation, "'pattern' must be a string");
      goto cleanup;
    }

    pattern = vim_strsave((char_u *)opts->pattern.data.string.data);
    set_pattern = true;
  }

  if (opts->event.type != kObjectTypeNil) {
    UNPACK_STRING_OR_ARRAY(event_array, "event", (&opts->event), cleanup)
  }

  if (opts->modeline.type != kObjectTypeNil) {
    modeline = api_object_to_bool(opts->modeline, "modeline", true, err);
  }

  if (set_pattern && set_buf) {
    api_set_error(err, kErrorTypeValidation, "must not set 'buffer' and 'pattern'");
    goto cleanup;
  }

  bool did_aucmd = false;
  FOREACH_ITEM(event_array, event_str, {
    GET_ONE_EVENT(event_nr, event_str, cleanup)

    did_aucmd |= apply_autocmds_group(event_nr, pattern, NULL, true, au_group, buf, NULL);
  })

  if (did_aucmd && modeline) {
    do_modelines(0);
  }

cleanup:
  api_free_array(event_array);
  XFREE_CLEAR(pattern);
}


#undef UNPACK_STRING_OR_ARRAY
#undef CHECK_STRING_ARRAY
#undef GET_ONE_EVENT
