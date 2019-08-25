#include <stdbool.h>

#include "lauxlib.h"
#include "nvim/api/autocmd.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/helpers.h"
#include "nvim/fileio.h"
#include "nvim/lua/executor.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/autocmd.c.generated.h"
#endif

#define MAX_PATTERNS 256

#define FOREACH_KEY_VALUE(d, k, v, code) \
  for (size_t i = 0; i < d.size; i++) { \
    String k = d.items[i].key; \
    Object *v = &d.items[i].value; \
    code; \
  }

#define FOREACH_ITEM(a, __foreach_item, code) \
  for (size_t __foreach_i = 0; __foreach_i < a.size; __foreach_i++) { \
    Object __foreach_item = a.items[__foreach_i]; \
    code; \
  }

#define UNPACK_EVENTS(event_array, v, goto_name) \
  if (v->type == kObjectTypeString) { \
    ADD(event_array, copy_object(*v)); \
  } else if (v->type == kObjectTypeArray) { \
    for (size_t j = 0; j < event_array.size; j++) { \
      Object item = event_array.items[j]; \
      if (item.type != kObjectTypeString) { \
        api_set_error( \
            err, \
            kErrorTypeValidation, \
            "All entries in 'event' must be strings"); \
        goto goto_name; \
      } \
    } \
    event_array = copy_array(v->data.array); \
  } else { \
    api_set_error( \
        err, \
        kErrorTypeValidation, \
        "'event' must be an array or a string."); \
    goto goto_name; \
  }

#define GET_ONE_EVENT(event_nr, event_str, goto_name) \
  char_u *__next_ev; \
  event_T event_nr = \
    event_name2nr((char_u *)event_str.data.string.data, &__next_ev); \
  if (event_nr >= NUM_EVENTS) { \
    api_set_error(err, kErrorTypeValidation, "unexpected event"); \
    goto goto_name; \
  }



Array nvim_get_autocmds(Dictionary opts, Error *err)
  FUNC_API_SINCE(7)
{
  Array autocmd_list = ARRAY_DICT_INIT;

  bool event_set[NUM_EVENTS];
  bool check_event = false;

  int group_filter = 0;

  int pattern_filter_count = 0;
  char *pattern_filters[MAX_PATTERNS];

  char_u pattern_buflocal[BUFLOCAL_PAT_LEN];

  for (size_t i = 0; i < opts.size; i++) {
    String k = opts.items[i].key;
    Object v = opts.items[i].value;

    if (strequal("augroup", k.data)) {
      if (v.type != kObjectTypeString) {
        api_set_error(err, kErrorTypeValidation, "augroup must be a string.");
        goto cleanup;
      }

      group_filter = au_find_group((char_u *)v.data.string.data);

      if (group_filter == AUGROUP_ERROR) {
        api_set_error(err, kErrorTypeValidation, "invalid augroup passed.");
        goto cleanup;
      }
    } else if (strequal("events", k.data)) {
      check_event = true;

      if (v.type == kObjectTypeString) {
        GET_ONE_EVENT(event_nr, v, cleanup);
        event_set[event_nr] = true;
      } else if (v.type == kObjectTypeArray) {
        FOREACH_ITEM(v.data.array, event_v, {
          if (event_v.type != kObjectTypeString) {
            api_set_error(
                err,
                kErrorTypeValidation,
                "Every event must be a string in events");
            goto cleanup;
          }

          GET_ONE_EVENT(event_nr, event_v, cleanup);
          event_set[event_nr] = true;
        })
      } else {
        api_set_error(
            err,
            kErrorTypeValidation,
            "Not a valid 'events' value. Must be a string or an array");
        goto cleanup;
      }
    } else if (strequal("patterns", k.data)) {
      if (v.type == kObjectTypeString) {
        pattern_filters[pattern_filter_count] = v.data.string.data;
        pattern_filter_count += 1;
      } else if (v.type == kObjectTypeArray) {
        FOREACH_ITEM(v.data.array, item, {
          pattern_filters[pattern_filter_count] = item.data.string.data;
          pattern_filter_count += 1;
        });
      } else {
        api_set_error(
            err,
            kErrorTypeValidation,
            "Not a valid 'patterns' value. Must be a string or an array");
        goto cleanup;
      }

      if (pattern_filter_count >= MAX_PATTERNS) {
        api_set_error(
            err,
            kErrorTypeValidation,
            "Too many patterns. Please limit yourself to less");
        goto cleanup;
      }
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
      if (group_filter != 0 && ap->group != group_filter) {
        continue;
      }

      // Skip patterns from invalid patterns if passed.
      if (pattern_filter_count > 0) {
        bool passed = false;
        for (int i = 0; i < pattern_filter_count; i++) {
          assert(i < MAX_PATTERNS);
          assert(pattern_filters[i]);

          char_u *pat = (char_u *)pattern_filters[i];
          int patlen = (int)STRLEN(pat);

          if (aupat_is_buflocal(pat, patlen)) {
            aupat_normalize_buflocal_pat(
                pattern_buflocal,
                pat,
                patlen,
                aupat_get_buflocal_nr(pat, patlen));

            pat = pattern_buflocal;
          }

          ILOG("Comparing pat: %s == %s", ap->pat, pat);
          if (strequal((char *)ap->pat, (char *)pat)) {
            ILOG("SUCCESS");
            passed = true;
            break;
          }
        }

        if (!passed) {
          continue;
        }
      }

      for (AutoCmd *ac = ap->cmds; ac != NULL; ac = ac->next) {
        Dictionary autocmd_info = ARRAY_DICT_INIT;

        if (ap->group != AUGROUP_DEFAULT) {
          PUT(autocmd_info, "group", INTEGER_OBJ(ap->group));
        }
        if (ac->cmd) {
          PUT(autocmd_info,
              "command",
              STRING_OBJ(cstr_to_string((char *)ac->cmd)));
        }

        PUT(autocmd_info,
            "pattern",
            STRING_OBJ(cstr_to_string((char *)ap->pat)));

        PUT(autocmd_info, "once", BOOLEAN_OBJ(ac->once));

        if (ap->buflocal_nr) {
          PUT(autocmd_info, "buflocal", BOOLEAN_OBJ(true));
          PUT(autocmd_info, "bufnr", INTEGER_OBJ(ap->buflocal_nr));
        } else {
          PUT(autocmd_info, "buflocal", BOOLEAN_OBJ(false));
        }

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
void nvim_autocmd_define(
    DictionaryOf(LuaRef) opts,
    Error *err)
  FUNC_API_SINCE(7)
{
//   char_u *pattern = NULL;
//
//   bool is_once = false;
//   bool is_nested = false;
//   int au_group = AUGROUP_ALL;
//
//   char_u *vim_command;
//   char_u *vim_callable;
//   LuaCallable lua_callable = nlua_init_callable();
//
//   Array event_array = ARRAY_DICT_INIT;
//
//   FOREACH_KEY_VALUE(opts, k, v, {
//     if (strequal("callback", k.data)) {
//       if (v->type == kObjectTypeLuaRef) {
//         lua_callable.func_ref = v->data.luaref;
//         v->data.luaref = LUA_NOREF;
//       } else if (v->type == kObjectTypeString) {
//         vim_callable = (char_u *)v->data.string.data;
//       } else {
//         api_set_error(
//             err,
//             kErrorTypeValidation,
//             "'callback' must be a string or LuaRef");
//       }
//     } else if (strequal("command", k.data)) {
//       if (v->type == kObjectTypeString) {
//         vim_command = (char_u *)v->data.string.data;
//       } else {
//         api_set_error(
//             err,
//             kErrorTypeValidation,
//             "'command' must be a string");
//         goto cleanup;
//       }
//     } else if (strequal("vim_func", k.data)) {
//       if (v->type == kObjectTypeString) {
//         vim_callable = (char_u *)v->data.string.data;
//       } else {
//         api_set_error(
//             err,
//             kErrorTypeValidation,
//             "'vim_func' must be a string");
//         goto cleanup;
//       }
//     } else if (strequal("pattern", k.data)) {
//       if (v->type == kObjectTypeString) {
//         pattern = (char_u *)v->data.string.data;
//       } else {
//         api_set_error(
//             err,
//             kErrorTypeValidation,
//             "'pattern' must be a string");
//         goto cleanup;
//       }
//     } else if (strequal("event", k.data)) {
//       UNPACK_EVENTS(event_array, v, cleanup)
//     } else if (strequal("once", k.data)) {
//       is_once = api_object_to_bool(*v, "once", true, err);
//     } else if (strequal("nested", k.data)) {
//       is_nested = api_object_to_bool(*v, "nested", true, err);
//     } else if (strequal("group", k.data)) {
//       if (v->type != kObjectTypeString) {
//         api_set_error(err, kErrorTypeValidation, "'group' must be a string");
//         goto cleanup;
//       }
//
//       au_group = au_find_group((char_u *)v->data.string.data);
//
//       if (au_group == AUGROUP_ERROR) {
//         api_set_error(
//             err,
//             kErrorTypeException,
//             "invalid augroup: %s", v->data.string.data);
//
//         goto cleanup;
//       }
//     } else if (strequal("namespace", k.data)) {
//       api_set_error(
//           err,
//           kErrorTypeException,
//           "'namespace': Not implemented yet!");
//
//       goto cleanup;
//     } else {
//       api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
//       goto cleanup;
//     }
//   })
//
//   if (lua_callable.func_ref == LUA_NOREF
//       && vim_callable == NULL
//       && vim_command == NULL) {
//     api_set_error(
//         err,
//         kErrorTypeValidation,
//         "'command' or 'callback' is required");
//     goto cleanup;
//   }
//
//   if (pattern == NULL) {
//     pattern = (char_u *)"*";
//   }
//
//   if (event_array.size == 0) {
//     api_set_error(err, kErrorTypeValidation, "'event' is a required key");
//     goto cleanup;
//   }
//
//   // char_u *autocmd_command;
//
//   FOREACH_ITEM(event_array, event_str, {
//     GET_ONE_EVENT(event_nr, event_str, cleanup)
//
//     int retval;
//
//     // TODO(autocmd): Switch to autocmd_register_event
//     retval = define_one_autocmd(
//         event_nr,
//         pattern,
//         is_once,
//         is_nested,
//         nlua_is_valid_callable(lua_callable) ? (char_u *)"" : vim_command,
//         au_group,
//         false);
//
//     if (retval == FAIL) {
//       api_set_error(err, kErrorTypeException, "Failed to set autocmd");
//       goto cleanup;
//     }
//   });
//
// cleanup:
//   api_free_array(event_array);
//
//   if (ERROR_SET(err)) {
//     api_free_luacallable(lua_callable);
//   }
//   */
//
//   return;
}

// TODO(tjdevries): Should probably make `undefine` for this.
//                  so you can get the same behavior as augroup!

void nvim_autocmd_group_define(String name, Dictionary opts, Error *err)
  FUNC_API_SINCE(7)
{
  bool clear_autocmds = true;

  FOREACH_KEY_VALUE(opts, k, v, {
    if (strequal("clear", k.data)) {
      clear_autocmds = api_object_to_bool(*v, "clear", true, err);
    } else {
      api_set_error(err, kErrorTypeValidation, "unexpected key: %s", k.data);
      return;
    }
  })

  int augroup = au_new_group((char_u *)name.data);

  if (clear_autocmds) {
    FOR_ALL_AUEVENTS(event) {
      if (autocmd_delete_event(augroup, event, (char_u *)"*") == FAIL) {
        api_set_error(err, kErrorTypeException, "Unabled to clear autocmds");
        return;
      }
    }
  }
}

void nvim_autocmd_do(Dictionary opts, Error *err)
  FUNC_API_SINCE(7)
{
  int au_group = AUGROUP_ALL;
  buf_T *buf = curbuf;
  char_u *fname = NULL;

  Array event_array = ARRAY_DICT_INIT;

  FOREACH_KEY_VALUE(opts, k, v, {
    if (strequal("group", k.data)) {
      if (v->type != kObjectTypeString) {
        api_set_error(err, kErrorTypeValidation, "'group' must be a string");
        goto cleanup;
      }

      au_group = au_find_group((char_u *)v->data.string.data);

      if (au_group == AUGROUP_ERROR) {
        api_set_error(
            err,
            kErrorTypeException,
            "invalid augroup: %s", v->data.string.data);

        goto cleanup;
      }
    } else if (strequal("bufnr", k.data)) {
      if (v->type != kObjectTypeInteger) {
        api_set_error(err, kErrorTypeException, "invalid bufnr");
        goto cleanup;
      }

      buf = find_buffer_by_handle((Buffer)v->data.integer, err);
      if (ERROR_SET(err)) {
        goto cleanup;
      }
    } else if (strequal("fname", k.data)) {
      STRCPY(fname, v->data.string.data);
    } else if (strequal("event", k.data)) {
      UNPACK_EVENTS(event_array, v, cleanup)
    } else {
      api_set_error(err, kErrorTypeValidation, "invalid key: %s", k.data);
      return;
    }
  })

  FOREACH_ITEM(event_array, event_str, {
    GET_ONE_EVENT(event_nr, event_str, cleanup)

    apply_autocmds_group(
        event_nr,
        fname,
        NULL,
        true,
        au_group,
        buf,
        NULL);
  })


cleanup:
  api_free_array(event_array);

  return;
}


#undef UNPACK_EVENTS
#undef GET_ONE_EVENT
