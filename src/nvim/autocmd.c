// autocmd.c: Autocommand related functions

#include <assert.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/cursor.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/eval/vars.h"
#include "nvim/event/loop.h"
#include "nvim/event/multiqueue.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/fileio.h"
#include "nvim/getchar.h"
#include "nvim/getchar_defs.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/grid.h"
#include "nvim/grid_defs.h"
#include "nvim/hashtab.h"
#include "nvim/highlight_defs.h"
#include "nvim/insexpand.h"
#include "nvim/lua/executor.h"
#include "nvim/main.h"
#include "nvim/map_defs.h"
#include "nvim/memory.h"
#include "nvim/message.h"
#include "nvim/option.h"
#include "nvim/option_defs.h"
#include "nvim/option_vars.h"
#include "nvim/os/input.h"
#include "nvim/os/os.h"
#include "nvim/os/os_defs.h"
#include "nvim/os/time.h"
#include "nvim/os/time_defs.h"
#include "nvim/path.h"
#include "nvim/profile.h"
#include "nvim/regexp.h"
#include "nvim/runtime.h"
#include "nvim/runtime_defs.h"
#include "nvim/search.h"
#include "nvim/state.h"
#include "nvim/state_defs.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/ui_compositor.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"
#include "nvim/winfloat.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "auevents_name_map.generated.h"
# include "autocmd.c.generated.h"
#endif

static const char e_autocommand_nesting_too_deep[]
  = N_("E218: Autocommand nesting too deep");

// Naming Conventions:
//  - general autocmd behavior start with au_
//  - AutoCmd start with aucmd_
//  - AutoPat start with aupat_
//  - Groups start with augroup_
//  - Events start with event_

// The autocommands are stored in a contiguous vector for each event.
//
// The order of AutoCmds is important, this is the order in which they
// were defined and will have to be executed.
//
// To avoid having to match the pattern too often, patterns are reference
// counted and reused for consecutive autocommands.

// Code for automatic commands.
static AutoPatCmd *active_apc_list = NULL;  // stack of active autocommands

// ID for associating autocmds created via nvim_create_autocmd
// Used to delete autocmds from nvim_del_autocmd
static int next_augroup_id = 1;

// use get_deleted_augroup() to get this
static const char *deleted_augroup = NULL;

// The ID of the current group.
static int current_augroup = AUGROUP_DEFAULT;

// Whether we need to delete marked patterns.
// While deleting autocmds, they aren't actually remover, just marked.
static bool au_need_clean = false;

static int autocmd_blocked = 0;  // block all autocmds

static bool autocmd_nested = false;
static bool autocmd_include_groups = false;

static char *old_termresponse = NULL;

// Map of autocmd group names and ids.
//  name -> ID
//  ID -> name
static Map(String, int) map_augroup_name_to_id = MAP_INIT;
static Map(int, String) map_augroup_id_to_name = MAP_INIT;

static void augroup_map_del(int id, const char *name)
{
  if (name != NULL) {
    String key;
    map_del(String, int)(&map_augroup_name_to_id, cstr_as_string(name), &key);
    api_free_string(key);
  }
  if (id > 0) {
    String mapped = map_del(int, String)(&map_augroup_id_to_name, id, NULL);
    api_free_string(mapped);
  }
}

static inline const char *get_deleted_augroup(void) FUNC_ATTR_ALWAYS_INLINE
{
  if (deleted_augroup == NULL) {
    deleted_augroup = _("--Deleted--");
  }
  return deleted_augroup;
}

static void au_show_for_all_events(int group, const char *pat)
{
  FOR_ALL_AUEVENTS(event) {
    au_show_for_event(group, event, pat);
  }
}

static void au_show_for_event(int group, event_T event, const char *pat)
{
  AutoCmdVec *const acs = &autocmds[(int)event];
  // Return early if there are no autocmds for this event
  if (kv_size(*acs) == 0) {
    return;
  }

  char buflocal_pat[BUFLOCAL_PAT_LEN];  // for "<buffer=X>"
  int patlen;
  if (*pat != NUL) {
    patlen = (int)aucmd_pattern_length(pat);

    // detect special <buffer[=X]> buffer-local patterns
    if (aupat_is_buflocal(pat, patlen)) {
      // normalize pat into standard "<buffer>#N" form
      aupat_normalize_buflocal_pat(buflocal_pat, pat, patlen, aupat_get_buflocal_nr(pat, patlen));
      pat = buflocal_pat;
      patlen = (int)strlen(buflocal_pat);
    }

    if (patlen == 0) {
      return;
    }
    assert(*pat != NUL);
  } else {
    pat = NULL;
    patlen = 0;
  }

  // Loop through all the specified patterns.
  while (true) {
    AutoPat *last_ap = NULL;
    int last_group = AUGROUP_ERROR;
    const char *last_group_name = NULL;

    for (size_t i = 0; i < kv_size(*acs); i++) {
      AutoCmd *const ac = &kv_A(*acs, i);

      // Skip deleted autocommands.
      if (ac->pat == NULL) {
        continue;
      }

      // Accept a pattern when:
      // - a group was specified and it's that group
      // - the length of the pattern matches
      // - the pattern matches.
      // For <buffer[=X]>, this condition works because we normalize
      // all buffer-local patterns.
      if ((group != AUGROUP_ALL && ac->pat->group != group)
          || (pat != NULL
              && (ac->pat->patlen != patlen || strncmp(pat, ac->pat->pat, (size_t)patlen) != 0))) {
        continue;
      }

      // Show event name and group only if one of them changed.
      if (ac->pat->group != last_group) {
        last_group = ac->pat->group;
        last_group_name = augroup_name(ac->pat->group);

        if (got_int) {
          return;
        }

        msg_putchar('\n');
        if (got_int) {
          return;
        }

        // When switching groups, we need to show the new group information.
        // show the group name, if it's not the default group
        if (ac->pat->group != AUGROUP_DEFAULT) {
          if (last_group_name == NULL) {
            msg_puts_hl(get_deleted_augroup(), HLF_E, false);
          } else {
            msg_puts_hl(last_group_name, HLF_T, false);
          }
          msg_puts("  ");
        }
        // show the event name
        msg_puts_hl(event_nr2name(event), HLF_T, false);
      }

      // Show pattern only if it changed.
      if (last_ap != ac->pat) {
        last_ap = ac->pat;

        msg_putchar('\n');
        if (got_int) {
          return;
        }

        msg_col = 4;
        msg_outtrans(ac->pat->pat, 0, false);
      }

      if (got_int) {
        return;
      }

      if (msg_col >= 14) {
        msg_putchar('\n');
      }
      msg_col = 14;
      if (got_int) {
        return;
      }

      char *handler_str = aucmd_handler_to_string(ac);
      if (ac->desc != NULL) {
        size_t msglen = 100;
        char *msg = xmallocz(msglen);
        if (ac->handler_cmd) {
          snprintf(msg, msglen, "%s [%s]", handler_str, ac->desc);
        } else {
          msg_puts_hl(handler_str, HLF_8, false);
          snprintf(msg, msglen, " [%s]", ac->desc);
        }
        msg_outtrans(msg, 0, false);
        XFREE_CLEAR(msg);
      } else if (ac->handler_cmd) {
        msg_outtrans(handler_str, 0, false);
      } else {
        msg_puts_hl(handler_str, HLF_8, false);
      }
      XFREE_CLEAR(handler_str);
      if (p_verbose > 0) {
        last_set_msg(ac->script_ctx);
      }

      if (got_int) {
        return;
      }
    }

    // If a pattern is provided, find next pattern. Otherwise exit after single iteration.
    if (pat != NULL) {
      pat = aucmd_next_pattern(pat, (size_t)patlen);
      patlen = (int)aucmd_pattern_length(pat);
      if (patlen == 0) {
        break;
      }
    } else {
      break;
    }
  }
}

// Delete autocommand.
static void aucmd_del(AutoCmd *ac)
{
  if (ac->pat != NULL && --ac->pat->refcount == 0) {
    XFREE_CLEAR(ac->pat->pat);
    vim_regfree(ac->pat->reg_prog);
    xfree(ac->pat);
  }
  ac->pat = NULL;
  if (ac->handler_cmd) {
    XFREE_CLEAR(ac->handler_cmd);
  } else {
    callback_free(&ac->handler_fn);
  }
  XFREE_CLEAR(ac->desc);

  au_need_clean = true;
}

void aucmd_del_for_event_and_group(event_T event, int group)
{
  AutoCmdVec *const acs = &autocmds[(int)event];
  for (size_t i = 0; i < kv_size(*acs); i++) {
    AutoCmd *const ac = &kv_A(*acs, i);
    if (ac->pat != NULL && ac->pat->group == group) {
      aucmd_del(ac);
    }
  }

  au_cleanup();
}

/// Cleanup autocommands that have been deleted.
/// This is only done when not executing autocommands.
static void au_cleanup(void)
{
  if (autocmd_busy || !au_need_clean) {
    return;
  }

  // Loop over all events.
  FOR_ALL_AUEVENTS(event) {
    // Loop over all autocommands.
    AutoCmdVec *const acs = &autocmds[(int)event];
    size_t nsize = 0;
    for (size_t i = 0; i < kv_size(*acs); i++) {
      AutoCmd *const ac = &kv_A(*acs, i);
      if (nsize != i) {
        kv_A(*acs, nsize) = *ac;
      }
      if (ac->pat != NULL) {
        nsize++;
      }
    }
    if (nsize == 0) {
      kv_destroy(*acs);
    } else {
      acs->size = nsize;
    }
  }

  au_need_clean = false;
}

AutoCmdVec *au_get_autocmds_for_event(event_T event)
  FUNC_ATTR_PURE
{
  return &autocmds[(int)event];
}

// Called when buffer is freed, to remove/invalidate related buffer-local autocmds.
void aubuflocal_remove(buf_T *buf)
{
  // invalidate currently executing autocommands
  for (AutoPatCmd *apc = active_apc_list; apc != NULL; apc = apc->next) {
    if (buf->b_fnum == apc->arg_bufnr) {
      apc->arg_bufnr = 0;
    }
  }

  // invalidate buflocals looping through events
  FOR_ALL_AUEVENTS(event) {
    AutoCmdVec *const acs = &autocmds[(int)event];
    for (size_t i = 0; i < kv_size(*acs); i++) {
      AutoCmd *const ac = &kv_A(*acs, i);
      if (ac->pat == NULL || ac->pat->buflocal_nr != buf->b_fnum) {
        continue;
      }

      aucmd_del(ac);

      if (p_verbose >= 6) {
        verbose_enter();
        smsg(0, _("auto-removing autocommand: %s <buffer=%d>"), event_nr2name(event), buf->b_fnum);
        verbose_leave();
      }
    }
  }
  au_cleanup();
}

// Add an autocmd group name or return existing group matching name.
// Return its ID.
int augroup_add(const char *name)
{
  assert(STRICMP(name, "end") != 0);

  int existing_id = augroup_find(name);
  if (existing_id > 0) {
    assert(existing_id != AUGROUP_DELETED);
    return existing_id;
  }

  if (existing_id == AUGROUP_DELETED) {
    augroup_map_del(existing_id, name);
  }

  int next_id = next_augroup_id++;
  String name_key = cstr_to_string(name);
  String name_val = cstr_to_string(name);
  map_put(String, int)(&map_augroup_name_to_id, name_key, next_id);
  map_put(int, String)(&map_augroup_id_to_name, next_id, name_val);

  return next_id;
}

/// Delete the augroup that matches name.
/// @param stupid_legacy_mode bool: This parameter determines whether to run the augroup
///     deletion in the same fashion as `:augroup! {name}` where if there are any remaining
///     autocmds left in the augroup, it will change the name of the augroup to `--- DELETED ---`
///     but leave the autocmds existing. These are _separate_ augroups, so if you do this for
///     multiple augroups, you will have a bunch of `--- DELETED ---` augroups at the same time.
///     There is no way, as far as I could tell, how to actually delete them at this point as a user
///
///     I did not consider this good behavior, so now when NOT in stupid_legacy_mode, we actually
///     delete these groups and their commands, like you would expect (and don't leave hanging
///     `--- DELETED ---` groups around)
void augroup_del(char *name, bool stupid_legacy_mode)
{
  int group = augroup_find(name);
  if (group == AUGROUP_ERROR) {  // the group doesn't exist
    semsg(_("E367: No such group: \"%s\""), name);
    return;
  } else if (group == current_augroup) {
    emsg(_("E936: Cannot delete the current group"));
    return;
  }

  if (stupid_legacy_mode) {
    FOR_ALL_AUEVENTS(event) {
      AutoCmdVec *const acs = &autocmds[(int)event];
      for (size_t i = 0; i < kv_size(*acs); i++) {
        AutoPat *const ap = kv_A(*acs, i).pat;
        if (ap != NULL && ap->group == group) {
          give_warning(_("W19: Deleting augroup that is still in use"), true);
          map_put(String, int)(&map_augroup_name_to_id, cstr_as_string(name), AUGROUP_DELETED);
          augroup_map_del(ap->group, NULL);
          return;
        }
      }
    }
  } else {
    FOR_ALL_AUEVENTS(event) {
      AutoCmdVec *const acs = &autocmds[(int)event];
      for (size_t i = 0; i < kv_size(*acs); i++) {
        AutoCmd *const ac = &kv_A(*acs, i);
        if (ac->pat != NULL && ac->pat->group == group) {
          aucmd_del(ac);
        }
      }
    }
  }

  // Remove the group because it's not currently in use.
  augroup_map_del(group, name);
  au_cleanup();
}

/// Find the ID of an autocmd group name.
///
/// @param name augroup name
///
/// @return the ID or AUGROUP_ERROR (< 0) for error.
int augroup_find(const char *name)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  int existing_id = map_get(String, int)(&map_augroup_name_to_id, cstr_as_string(name));
  if (existing_id == AUGROUP_DELETED) {
    return existing_id;
  }

  if (existing_id > 0) {
    return existing_id;
  }

  return AUGROUP_ERROR;
}

/// Gets the name for a particular group.
char *augroup_name(int group)
{
  assert(group != 0);

  if (group == AUGROUP_DELETED) {
    return (char *)get_deleted_augroup();
  }

  if (group == AUGROUP_ALL) {
    group = current_augroup;
  }

  // next_augroup_id is the "source of truth" about what autocmds have existed
  //
  // The map_size is not the source of truth because groups can be removed from
  // the map. When this happens, the map size is reduced. That's why this function
  // relies on next_augroup_id instead.

  // "END" is always considered the last augroup ID.
  // Used for expand_get_event_name and expand_get_augroup_name
  if (group == next_augroup_id) {
    return "END";
  }

  // If it's larger than the largest group, then it doesn't have a name
  if (group > next_augroup_id) {
    return NULL;
  }

  String key = map_get(int, String)(&map_augroup_id_to_name, group);
  if (key.data != NULL) {
    return key.data;
  }

  // If it's not in the map anymore, then it must have been deleted.
  return (char *)get_deleted_augroup();
}

/// Return true if augroup "name" exists.
///
/// @param name augroup name
bool augroup_exists(const char *name)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return augroup_find(name) > 0;
}

/// ":augroup {name}".
void do_augroup(char *arg, bool del_group)
{
  if (del_group) {
    if (*arg == NUL) {
      emsg(_(e_argreq));
    } else {
      augroup_del(arg, true);
    }
  } else if (STRICMP(arg, "end") == 0) {  // ":aug end": back to group 0
    current_augroup = AUGROUP_DEFAULT;
  } else if (*arg) {  // ":aug xxx": switch to group xxx
    current_augroup = augroup_add(arg);
  } else {  // ":aug": list the group names
    msg_start();
    msg_ext_set_kind("list_cmd");

    String name;
    int value;
    map_foreach(&map_augroup_name_to_id, name, value, {
      if (value > 0) {
        msg_puts(name.data);
      } else {
        msg_puts(augroup_name(value));
      }

      msg_puts("  ");
    });

    msg_clr_eos();
    msg_end();
  }
}

#if defined(EXITFREE)
void free_all_autocmds(void)
{
  FOR_ALL_AUEVENTS(event) {
    AutoCmdVec *const acs = &autocmds[(int)event];
    for (size_t i = 0; i < kv_size(*acs); i++) {
      aucmd_del(&kv_A(*acs, i));
    }
    kv_destroy(*acs);
    au_need_clean = false;
  }

  // Delete the augroup_map, including free the data
  String name;
  map_foreach_key(&map_augroup_name_to_id, name, {
    api_free_string(name);
  })
  map_destroy(String, &map_augroup_name_to_id);

  map_foreach_value(&map_augroup_id_to_name, name, {
    api_free_string(name);
  })
  map_destroy(int, &map_augroup_id_to_name);

  // aucmd_win[] is freed in win_free_all()
}
#endif

/// Return true if "win" is an active entry in aucmd_win[].
bool is_aucmd_win(win_T *win)
{
  for (int i = 0; i < AUCMD_WIN_COUNT; i++) {
    if (aucmd_win[i].auc_win_used && aucmd_win[i].auc_win == win) {
      return true;
    }
  }
  return false;
}

/// Return the event number for event name "start".
/// Return NUM_EVENTS if the event name was not found.
/// Return a pointer to the next event name in "end".
event_T event_name2nr(const char *start, char **end)
{
  const char *p;

  // the event name ends with end of line, '|', a blank or a comma
  for (p = start; *p && !ascii_iswhite(*p) && *p != ',' && *p != '|'; p++) {}

  int hash_idx = event_name2nr_hash(start, (size_t)(p - start));
  if (*p == ',') {
    p++;
  }
  *end = (char *)p;
  if (hash_idx < 0) {
    return NUM_EVENTS;
  }
  return (event_T)abs(event_names[event_hash[hash_idx]].event);
}

/// Return the event number for event name "str".
/// Return NUM_EVENTS if the event name was not found.
event_T event_name2nr_str(String str)
{
  int hash_idx = event_name2nr_hash(str.data, str.size);
  if (hash_idx < 0) {
    return NUM_EVENTS;
  }
  return (event_T)abs(event_names[event_hash[hash_idx]].event);
}

/// Return the name for event
///
/// @param[in]  event  Event to return name for.
///
/// @return Event name, static string. Returns "Unknown" for unknown events.
const char *event_nr2name(event_T event)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_CONST
{
  return event >= 0 && event < NUM_EVENTS ? event_names[event].name : "Unknown";
}

/// Return true if "event" is included in 'eventignore(win)'.
///
/// @param event event to check
bool event_ignored(event_T event, char *ei)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  while (*ei != NUL) {
    if (STRNICMP(ei, "all", 3) == 0 && (ei[3] == NUL || ei[3] == ',')) {
      return true;
    } else if (event_name2nr(ei, &ei) == event) {
      return true;
    }
  }

  return false;
}

/// Return OK when the contents of 'eventignore' or 'eventignorewin' is valid,
/// FAIL otherwise.
int check_ei(char *ei)
{
  bool win = ei != p_ei;

  while (*ei) {
    if (STRNICMP(ei, "all", 3) == 0 && (ei[3] == NUL || ei[3] == ',')) {
      ei += 3;
      if (*ei == ',') {
        ei++;
      }
    } else {
      event_T event = event_name2nr(ei, &ei);
      if (event == NUM_EVENTS || (win && event_names[event].event > 0)) {
        return FAIL;
      }
    }
  }

  return OK;
}

// Add "what" to 'eventignore' to skip loading syntax highlighting for every
// buffer loaded into the window.  "what" must start with a comma.
// Returns the old value of 'eventignore' in allocated memory.
char *au_event_disable(char *what)
{
  size_t p_ei_len = strlen(p_ei);
  char *save_ei = xmemdupz(p_ei, p_ei_len);
  char *new_ei = xstrnsave(p_ei, p_ei_len + strlen(what));
  if (*what == ',' && *p_ei == NUL) {
    STRCPY(new_ei, what + 1);
  } else {
    STRCPY(new_ei + p_ei_len, what);
  }
  set_option_direct(kOptEventignore, CSTR_AS_OPTVAL(new_ei), 0, SID_NONE);
  xfree(new_ei);
  return save_ei;
}

void au_event_restore(char *old_ei)
{
  if (old_ei != NULL) {
    set_option_direct(kOptEventignore, CSTR_AS_OPTVAL(old_ei), 0, SID_NONE);
    xfree(old_ei);
  }
}

// Implements :autocmd.
// Defines an autocmd (does not execute; cf. apply_autocmds_group).
//
// Can be used in the following ways:
//
// :autocmd <event> <pat> <cmd>     Add <cmd> to the list of commands that
//                                  will be automatically executed for <event>
//                                  when editing a file matching <pat>, in
//                                  the current group.
// :autocmd <event> <pat>           Show the autocommands associated with
//                                  <event> and <pat>.
// :autocmd <event>                 Show the autocommands associated with
//                                  <event>.
// :autocmd                         Show all autocommands.
// :autocmd! <event> <pat> <cmd>    Remove all autocommands associated with
//                                  <event> and <pat>, and add the command
//                                  <cmd>, for the current group.
// :autocmd! <event> <pat>          Remove all autocommands associated with
//                                  <event> and <pat> for the current group.
// :autocmd! <event>                Remove all autocommands associated with
//                                  <event> for the current group.
// :autocmd!                        Remove ALL autocommands for the current
//                                  group.
//
//  Multiple events and patterns may be given separated by commas.  Here are
//  some examples:
// :autocmd bufread,bufenter *.c,*.h    set tw=0 smartindent noic
// :autocmd bufleave         *          set tw=79 nosmartindent ic infercase
//
// :autocmd * *.c               show all autocommands for *.c files.
//
// Mostly a {group} argument can optionally appear before <event>.
void do_autocmd(exarg_T *eap, char *arg_in, int forceit)
{
  char *arg = arg_in;
  char *envpat = NULL;
  char *cmd;
  bool need_free = false;
  bool nested = false;
  bool once = false;
  int group;

  if (*arg == '|') {
    eap->nextcmd = arg + 1;
    arg = "";
    group = AUGROUP_ALL;  // no argument, use all groups
  } else {
    // Check for a legal group name.  If not, use AUGROUP_ALL.
    group = arg_augroup_get(&arg);
  }

  // Scan over the events.
  // If we find an illegal name, return here, don't do anything.
  char *pat = arg_event_skip(arg, group != AUGROUP_ALL);
  if (pat == NULL) {
    return;
  }

  pat = skipwhite(pat);
  if (*pat == '|') {
    eap->nextcmd = pat + 1;
    pat = "";
    cmd = "";
  } else {
    // Scan over the pattern.  Put a NUL at the end.
    cmd = pat;
    while (*cmd && (!ascii_iswhite(*cmd) || cmd[-1] == '\\')) {
      cmd++;
    }
    if (*cmd) {
      *cmd++ = NUL;
    }

    // Expand environment variables in the pattern.  Set 'shellslash', we want
    // forward slashes here.
    if (vim_strchr(pat, '$') != NULL || vim_strchr(pat, '~') != NULL) {
#ifdef BACKSLASH_IN_FILENAME
      int p_ssl_save = p_ssl;

      p_ssl = true;
#endif
      envpat = expand_env_save(pat);
#ifdef BACKSLASH_IN_FILENAME
      p_ssl = p_ssl_save;
#endif
      if (envpat != NULL) {
        pat = envpat;
      }
    }

    cmd = skipwhite(cmd);

    bool invalid_flags = false;
    for (size_t i = 0; i < 2; i++) {
      if (*cmd == NUL) {
        continue;
      }

      invalid_flags |= arg_autocmd_flag_get(&once, &cmd, "++once", 6);
      invalid_flags |= arg_autocmd_flag_get(&nested, &cmd, "++nested", 8);

      // Check the deprecated "nested" flag.
      invalid_flags |= arg_autocmd_flag_get(&nested, &cmd, "nested", 6);
    }

    if (invalid_flags) {
      return;
    }

    // Find the start of the commands.
    // Expand <sfile> in it.
    if (*cmd != NUL) {
      cmd = expand_sfile(cmd);
      if (cmd == NULL) {  // some error
        return;
      }
      need_free = true;
    }
  }

  const bool is_showing = !forceit && *cmd == NUL;

  // Print header when showing autocommands.
  if (is_showing) {
    // Highlight title
    msg_ext_set_kind("list_cmd");
    msg_puts_title(_("\n--- Autocommands ---"));

    if (*arg == '*' || *arg == '|' || *arg == NUL) {
      au_show_for_all_events(group, pat);
    } else {
      event_T event = event_name2nr(arg, &arg);
      assert(event < NUM_EVENTS);
      au_show_for_event(group, event, pat);
    }
  } else {
    if (*arg == '*' || *arg == NUL || *arg == '|') {
      if (*cmd != NUL) {
        emsg(_(e_cannot_define_autocommands_for_all_events));
      } else {
        do_all_autocmd_events(pat, once, nested, cmd, forceit, group);
      }
    } else {
      while (*arg && *arg != '|' && !ascii_iswhite(*arg)) {
        event_T event = event_name2nr(arg, &arg);
        assert(event < NUM_EVENTS);
        if (do_autocmd_event(event, pat, once, nested, cmd, forceit, group) == FAIL) {
          break;
        }
      }
    }
  }

  if (need_free) {
    xfree(cmd);
  }
  xfree(envpat);
}

void do_all_autocmd_events(const char *pat, bool once, int nested, char *cmd, bool del, int group)
{
  FOR_ALL_AUEVENTS(event) {
    if (do_autocmd_event(event, pat, once, nested, cmd, del, group) == FAIL) {
      return;
    }
  }
}

// do_autocmd() for one event.
// Defines an autocmd (does not execute; cf. apply_autocmds_group).
//
// If *pat == NUL: do for all patterns.
// If *cmd == NUL: show entries.
// If forceit == true: delete entries.
// If group is not AUGROUP_ALL: only use this group.
int do_autocmd_event(event_T event, const char *pat, bool once, int nested, const char *cmd,
                     bool del, int group)
  FUNC_ATTR_NONNULL_ALL
{
  // Cannot be used to show all patterns. See au_show_for_event or au_show_for_all_events
  assert(*pat != NUL || del);

  char buflocal_pat[BUFLOCAL_PAT_LEN];  // for "<buffer=X>"

  bool is_adding_cmd = *cmd != NUL;
  const int findgroup = group == AUGROUP_ALL ? current_augroup : group;

  // Delete all aupat for an event.
  if (*pat == NUL && del) {
    aucmd_del_for_event_and_group(event, findgroup);
    return OK;
  }

  // Loop through all the specified patterns.
  int patlen = (int)aucmd_pattern_length(pat);
  while (patlen) {
    // detect special <buffer[=X]> buffer-local patterns
    bool is_buflocal = aupat_is_buflocal(pat, patlen);
    if (is_buflocal) {
      const int buflocal_nr = aupat_get_buflocal_nr(pat, patlen);

      // normalize pat into standard "<buffer>#N" form
      aupat_normalize_buflocal_pat(buflocal_pat, pat, patlen, buflocal_nr);

      pat = buflocal_pat;
      patlen = (int)strlen(buflocal_pat);
    }

    if (del) {
      assert(*pat != NUL);

      // Find existing autocommands with this pattern.
      AutoCmdVec *const acs = &autocmds[(int)event];
      for (size_t i = 0; i < kv_size(*acs); i++) {
        AutoCmd *const ac = &kv_A(*acs, i);
        AutoPat *const ap = ac->pat;
        // Accept a pattern when:
        // - a group was specified and it's that group
        // - the length of the pattern matches
        // - the pattern matches.
        // For <buffer[=X]>, this condition works because we normalize
        // all buffer-local patterns.
        if (ap != NULL && ap->group == findgroup && ap->patlen == patlen
            && strncmp(pat, ap->pat, (size_t)patlen) == 0) {
          // Remove existing autocommands.
          // If adding any new autocmd's for this AutoPat, don't
          // delete the pattern from the autopat list, append to
          // this list.
          aucmd_del(ac);
        }
      }
    }

    if (is_adding_cmd) {
      Callback handler_fn = CALLBACK_INIT;
      autocmd_register(0, event, pat, patlen, group, once, nested, NULL, cmd, &handler_fn);
    }

    pat = aucmd_next_pattern(pat, (size_t)patlen);
    patlen = (int)aucmd_pattern_length(pat);
  }

  au_cleanup();  // may really delete removed patterns/commands now
  return OK;
}

/// Registers an autocmd. The handler may be a Ex command or callback function, decided by
/// the `handler_cmd` or `handler_fn` args.
///
/// @param handler_cmd Handler Ex command, or NULL if handler is a function (`handler_fn`).
/// @param handler_fn Handler function, ignored if `handler_cmd` is not NULL.
int autocmd_register(int64_t id, event_T event, const char *pat, int patlen, int group, bool once,
                     bool nested, char *desc, const char *handler_cmd, Callback *handler_fn)
{
  // 0 is not a valid group.
  assert(group != 0);

  if (patlen > (int)strlen(pat)) {
    return FAIL;
  }

  const int findgroup = group == AUGROUP_ALL ? current_augroup : group;

  // detect special <buffer[=X]> buffer-local patterns
  const bool is_buflocal = aupat_is_buflocal(pat, patlen);
  int buflocal_nr = 0;

  char buflocal_pat[BUFLOCAL_PAT_LEN];  // for "<buffer=X>"
  if (is_buflocal) {
    buflocal_nr = aupat_get_buflocal_nr(pat, patlen);

    // normalize pat into standard "<buffer>#N" form
    aupat_normalize_buflocal_pat(buflocal_pat, pat, patlen, buflocal_nr);

    pat = buflocal_pat;
    patlen = (int)strlen(buflocal_pat);
  }

  // Try to reuse pattern from the last existing autocommand.
  AutoPat *ap = NULL;
  AutoCmdVec *const acs = &autocmds[(int)event];
  for (ptrdiff_t i = (ptrdiff_t)kv_size(*acs) - 1; i >= 0; i--) {
    ap = kv_A(*acs, i).pat;
    if (ap == NULL) {
      continue;  // Skip deleted autocommands.
    }
    // Set result back to NULL if the last pattern doesn't match.
    if (ap->group != findgroup || ap->patlen != patlen
        || strncmp(pat, ap->pat, (size_t)patlen) != 0) {
      ap = NULL;
    }
    break;
  }

  // No matching pattern found, allocate a new one.
  if (ap == NULL) {
    // refuse to add buffer-local ap if buffer number is invalid
    if (is_buflocal && (buflocal_nr == 0 || buflist_findnr(buflocal_nr) == NULL)) {
      semsg(_("E680: <buffer=%d>: invalid buffer number "), buflocal_nr);
      return FAIL;
    }

    ap = xmalloc(sizeof(AutoPat));

    if (is_buflocal) {
      ap->buflocal_nr = buflocal_nr;
      ap->reg_prog = NULL;
    } else {
      ap->buflocal_nr = 0;
      char *reg_pat = file_pat_to_reg_pat(pat, pat + patlen, &ap->allow_dirs, true);
      if (reg_pat != NULL) {
        ap->reg_prog = vim_regcomp(reg_pat, RE_MAGIC);
      }
      xfree(reg_pat);
      if (reg_pat == NULL || ap->reg_prog == NULL) {
        xfree(ap);
        return FAIL;
      }
    }

    ap->refcount = 0;
    ap->pat = xmemdupz(pat, (size_t)patlen);
    ap->patlen = patlen;

    // need to initialize last_mode for the first ModeChanged autocmd
    if (event == EVENT_MODECHANGED && !has_event(EVENT_MODECHANGED)) {
      get_mode(last_mode);
    }

    // If the event is CursorMoved or CursorMovedI, update the last cursor position
    // position to avoid immediately triggering the autocommand
    if ((event == EVENT_CURSORMOVED && !has_event(EVENT_CURSORMOVED))
        || (event == EVENT_CURSORMOVEDI && !has_event(EVENT_CURSORMOVEDI))) {
      last_cursormoved_win = curwin;
      last_cursormoved = curwin->w_cursor;
    }

    // Initialize the fields checked by the WinScrolled and
    // WinResized trigger to prevent them from firing right after
    // the first autocmd is defined.
    if ((event == EVENT_WINSCROLLED || event == EVENT_WINRESIZED)
        && !(has_event(EVENT_WINSCROLLED) || has_event(EVENT_WINRESIZED))) {
      tabpage_T *save_curtab = curtab;
      FOR_ALL_TABS(tp) {
        unuse_tabpage(curtab);
        use_tabpage(tp);
        snapshot_windows_scroll_size();
      }
      unuse_tabpage(curtab);
      use_tabpage(save_curtab);
    }

    ap->group = group == AUGROUP_ALL ? current_augroup : group;
  }

  ap->refcount++;

  // Add the autocmd at the end of the AutoCmd vector.
  AutoCmd *ac = kv_pushp(autocmds[(int)event]);
  ac->pat = ap;
  ac->id = id;
  if (handler_cmd) {
    ac->handler_cmd = xstrdup(handler_cmd);
  } else {
    ac->handler_cmd = NULL;
    callback_copy(&ac->handler_fn, handler_fn);
  }
  ac->script_ctx = current_sctx;
  ac->script_ctx.sc_lnum += SOURCING_LNUM;
  nlua_set_sctx(&ac->script_ctx);
  ac->once = once;
  ac->nested = nested;
  ac->desc = desc == NULL ? NULL : xstrdup(desc);

  return OK;
}

size_t aucmd_pattern_length(const char *pat)
  FUNC_ATTR_PURE
{
  if (*pat == NUL) {
    return 0;
  }

  const char *endpat;

  for (; *pat; pat = endpat + 1) {
    // Find end of the pattern.
    // Watch out for a comma in braces, like "*.\{obj,o\}".
    endpat = pat;
    // ignore single comma
    if (*endpat == ',') {
      continue;
    }
    int brace_level = 0;
    for (; *endpat && (*endpat != ',' || brace_level || endpat[-1] == '\\'); endpat++) {
      if (*endpat == '{') {
        brace_level++;
      } else if (*endpat == '}') {
        brace_level--;
      }
    }

    return (size_t)(endpat - pat);
  }

  return strlen(pat);
}

const char *aucmd_next_pattern(const char *pat, size_t patlen)
  FUNC_ATTR_PURE
{
  pat = pat + patlen;
  if (*pat == ',') {
    pat = pat + 1;
  }
  return pat;
}

/// Implementation of ":doautocmd [group] event [fname]".
/// Return OK for success, FAIL for failure;
///
/// @param do_msg  give message for no matching autocmds?
int do_doautocmd(char *arg_start, bool do_msg, bool *did_something)
{
  char *arg = arg_start;
  int nothing_done = true;

  if (did_something != NULL) {
    *did_something = false;
  }

  // Check for a legal group name.  If not, use AUGROUP_ALL.
  int group = arg_augroup_get(&arg);

  if (*arg == '*') {
    emsg(_("E217: Can't execute autocommands for ALL events"));
    return FAIL;
  }

  // Scan over the events.
  // If we find an illegal name, return here, don't do anything.
  char *fname = arg_event_skip(arg, group != AUGROUP_ALL);
  if (fname == NULL) {
    return FAIL;
  }

  fname = skipwhite(fname);

  // Loop over the events.
  while (*arg && !ends_excmd(*arg) && !ascii_iswhite(*arg)) {
    if (apply_autocmds_group(event_name2nr(arg, &arg), fname, NULL, true, group,
                             curbuf, NULL, NULL)) {
      nothing_done = false;
    }
  }

  if (nothing_done && do_msg && !aborting()) {
    smsg(0, _("No matching autocommands: %s"), arg_start);
  }
  if (did_something != NULL) {
    *did_something = !nothing_done;
  }

  return aborting() ? FAIL : OK;
}

// ":doautoall": execute autocommands for each loaded buffer.
void ex_doautoall(exarg_T *eap)
{
  int retval = OK;
  aco_save_T aco;
  char *arg = eap->arg;
  int call_do_modelines = check_nomodeline(&arg);
  bufref_T bufref;
  bool did_aucmd;

  // This is a bit tricky: For some commands curwin->w_buffer needs to be
  // equal to curbuf, but for some buffers there may not be a window.
  // So we change the buffer for the current window for a moment.  This
  // gives problems when the autocommands make changes to the list of
  // buffers or windows...
  FOR_ALL_BUFFERS(buf) {
    // Only do loaded buffers and skip the current buffer, it's done last.
    if (buf->b_ml.ml_mfp == NULL || buf == curbuf) {
      continue;
    }

    // Find a window for this buffer and save some values.
    aucmd_prepbuf(&aco, buf);
    set_bufref(&bufref, buf);

    // execute the autocommands for this buffer
    retval = do_doautocmd(arg, false, &did_aucmd);

    if (call_do_modelines && did_aucmd) {
      // Execute the modeline settings, but don't set window-local
      // options if we are using the current window for another
      // buffer.
      do_modelines(is_aucmd_win(curwin) ? OPT_NOWIN : 0);
    }

    // restore the current window
    aucmd_restbuf(&aco);

    // Stop if there is some error or buffer was deleted.
    if (retval == FAIL || !bufref_valid(&bufref)) {
      retval = FAIL;
      break;
    }
  }

  // Execute autocommands for the current buffer last.
  if (retval == OK) {
    do_doautocmd(arg, false, &did_aucmd);
    if (call_do_modelines && did_aucmd) {
      do_modelines(0);
    }
  }
}

/// Check *argp for <nomodeline>.  When it is present return false, otherwise
/// return true and advance *argp to after it. Thus do_modelines() should be
/// called when true is returned.
///
/// @param[in,out] argp argument string
bool check_nomodeline(char **argp)
  FUNC_ATTR_NONNULL_ALL FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (strncmp(*argp, "<nomodeline>", 12) == 0) {
    *argp = skipwhite(*argp + 12);
    return false;
  }
  return true;
}

/// Prepare for executing autocommands for (hidden) buffer `buf`.
/// If the current buffer is not in any visible window, put it in a temporary
/// floating window using an entry in `aucmd_win[]`.
/// Set `curbuf` and `curwin` to match `buf`.
///
/// @param aco  structure to save values in
/// @param buf  new curbuf
void aucmd_prepbuf(aco_save_T *aco, buf_T *buf)
{
  win_T *win;
  bool need_append = true;  // Append `aucmd_win` to the window list.

  // Find a window that is for the new buffer
  if (buf == curbuf) {  // be quick when buf is curbuf
    win = curwin;
  } else {
    win = NULL;
    FOR_ALL_WINDOWS_IN_TAB(wp, curtab) {
      if (wp->w_buffer == buf) {
        win = wp;
        break;
      }
    }
  }

  // Allocate a window when needed.
  win_T *auc_win = NULL;
  int auc_idx = AUCMD_WIN_COUNT;
  if (win == NULL) {
    for (auc_idx = 0; auc_idx < AUCMD_WIN_COUNT; auc_idx++) {
      if (!aucmd_win[auc_idx].auc_win_used) {
        break;
      }
    }

    if (auc_idx == AUCMD_WIN_COUNT) {
      kv_push(aucmd_win_vec, ((aucmdwin_T){
        .auc_win = NULL,
        .auc_win_used = false,
      }));
    }

    if (aucmd_win[auc_idx].auc_win == NULL) {
      win_alloc_aucmd_win(auc_idx);
      need_append = false;
    }
    auc_win = aucmd_win[auc_idx].auc_win;
    aucmd_win[auc_idx].auc_win_used = true;
  }

  aco->save_curwin_handle = curwin->handle;
  aco->save_prevwin_handle = prevwin == NULL ? 0 : prevwin->handle;
  aco->save_State = State;
  if (bt_prompt(curbuf)) {
    aco->save_prompt_insert = curbuf->b_prompt_insert;
  }

  if (win != NULL) {
    // There is a window for "buf" in the current tab page, make it the
    // curwin.  This is preferred, it has the least side effects (esp. if
    // "buf" is curbuf).
    aco->use_aucmd_win_idx = -1;
    curwin = win;
  } else {
    // There is no window for "buf", use "auc_win".  To minimize the side
    // effects, insert it in the current tab page.
    // Anything related to a window (e.g., setting folds) may have
    // unexpected results.
    aco->use_aucmd_win_idx = auc_idx;
    auc_win->w_buffer = buf;
    auc_win->w_s = &buf->b_s;
    buf->b_nwindows++;
    win_init_empty(auc_win);  // set cursor and topline to safe values

    // Make sure w_localdir, tp_localdir and globaldir are NULL to avoid a
    // chdir() in win_enter_ext().
    XFREE_CLEAR(auc_win->w_localdir);
    aco->tp_localdir = curtab->tp_localdir;
    curtab->tp_localdir = NULL;
    aco->globaldir = globaldir;
    globaldir = NULL;

    block_autocmds();  // We don't want BufEnter/WinEnter autocommands.
    if (need_append) {
      win_append(lastwin, auc_win, NULL);
      pmap_put(int)(&window_handles, auc_win->handle, auc_win);
      win_config_float(auc_win, auc_win->w_config);
    }
    // Prevent chdir() call in win_enter_ext(), through do_autochdir()
    const int save_acd = p_acd;
    p_acd = false;
    // no redrawing and don't set the window title
    RedrawingDisabled++;
    win_enter(auc_win, false);
    RedrawingDisabled--;
    p_acd = save_acd;
    unblock_autocmds();
    curwin = auc_win;
  }
  curbuf = buf;
  aco->new_curwin_handle = curwin->handle;
  set_bufref(&aco->new_curbuf, curbuf);

  // disable the Visual area, the position may be invalid in another buffer
  aco->save_VIsual_active = VIsual_active;
  VIsual_active = false;
}

/// Cleanup after executing autocommands for a (hidden) buffer.
/// Restore the window as it was (if possible).
///
/// @param aco  structure holding saved values
void aucmd_restbuf(aco_save_T *aco)
{
  if (aco->use_aucmd_win_idx >= 0) {
    win_T *awp = aucmd_win[aco->use_aucmd_win_idx].auc_win;

    // Find "awp", it can't be closed, but it may be in another tab page.
    // Do not trigger autocommands here.
    block_autocmds();
    if (curwin != awp) {
      FOR_ALL_TAB_WINDOWS(tp, wp) {
        if (wp == awp) {
          if (tp != curtab) {
            goto_tabpage_tp(tp, true, true);
          }
          win_goto(awp);
          goto win_found;
        }
      }
    }
win_found:
    curbuf->b_nwindows--;
    const bool save_stop_insert_mode = stop_insert_mode;
    // May need to stop Insert mode if we were in a prompt buffer.
    leaving_window(curwin);
    // Do not stop Insert mode when already in Insert mode before.
    if (aco->save_State & MODE_INSERT) {
      stop_insert_mode = save_stop_insert_mode;
    }
    // Remove the window.
    win_remove(curwin, NULL);
    pmap_del(int)(&window_handles, curwin->handle, NULL);
    if (curwin->w_grid_alloc.chars != NULL) {
      ui_comp_remove_grid(&curwin->w_grid_alloc);
      ui_call_win_hide(curwin->w_grid_alloc.handle);
      grid_free(&curwin->w_grid_alloc);
    }

    // The window is marked as not used, but it is not freed, it can be
    // used again.
    aucmd_win[aco->use_aucmd_win_idx].auc_win_used = false;

    if (!valid_tabpage_win(curtab)) {
      // no valid window in current tabpage
      close_tabpage(curtab);
    }

    unblock_autocmds();

    win_T *const save_curwin = win_find_by_handle(aco->save_curwin_handle);
    if (save_curwin != NULL) {
      curwin = save_curwin;
    } else {
      // Hmm, original window disappeared.  Just use the first one.
      curwin = firstwin;
    }
    curbuf = curwin->w_buffer;
    // May need to restore insert mode for a prompt buffer.
    entering_window(curwin);
    if (bt_prompt(curbuf)) {
      curbuf->b_prompt_insert = aco->save_prompt_insert;
    }

    prevwin = win_find_by_handle(aco->save_prevwin_handle);
    vars_clear(&awp->w_vars->dv_hashtab);         // free all w: variables
    hash_init(&awp->w_vars->dv_hashtab);          // re-use the hashtab

    // If :lcd has been used in the autocommand window, correct current
    // directory before restoring tp_localdir and globaldir.
    if (awp->w_localdir != NULL) {
      win_fix_current_dir();
    }
    xfree(curtab->tp_localdir);
    curtab->tp_localdir = aco->tp_localdir;
    xfree(globaldir);
    globaldir = aco->globaldir;

    // the buffer contents may have changed
    VIsual_active = aco->save_VIsual_active;
    check_cursor(curwin);
    if (curwin->w_topline > curbuf->b_ml.ml_line_count) {
      curwin->w_topline = curbuf->b_ml.ml_line_count;
      curwin->w_topfill = 0;
    }
  } else {
    // Restore curwin.  Use the window ID, a window may have been closed
    // and the memory re-used for another one.
    win_T *const save_curwin = win_find_by_handle(aco->save_curwin_handle);
    if (save_curwin != NULL) {
      // Restore the buffer which was previously edited by curwin, if it was
      // changed, we are still the same window and the buffer is valid.
      if (curwin->handle == aco->new_curwin_handle
          && curbuf != aco->new_curbuf.br_buf
          && bufref_valid(&aco->new_curbuf)
          && aco->new_curbuf.br_buf->b_ml.ml_mfp != NULL) {
        if (curwin->w_s == &curbuf->b_s) {
          curwin->w_s = &aco->new_curbuf.br_buf->b_s;
        }
        curbuf->b_nwindows--;
        curbuf = aco->new_curbuf.br_buf;
        curwin->w_buffer = curbuf;
        curbuf->b_nwindows++;
      }

      curwin = save_curwin;
      curbuf = curwin->w_buffer;
      prevwin = win_find_by_handle(aco->save_prevwin_handle);

      // In case the autocommand moves the cursor to a position that does not
      // exist in curbuf
      VIsual_active = aco->save_VIsual_active;
      check_cursor(curwin);
    }
  }

  VIsual_active = aco->save_VIsual_active;
  check_cursor(curwin);  // just in case lines got deleted
  if (VIsual_active) {
    check_pos(curbuf, &VIsual);
  }
}

/// Execute autocommands for "event" and file name "fname".
///
/// @param event event that occurred
/// @param fname filename, NULL or empty means use actual file name
/// @param fname_io filename to use for <afile> on cmdline
/// @param force When true, ignore autocmd_busy
/// @param buf Buffer for <abuf>
///
/// @return true if some commands were executed.
bool apply_autocmds(event_T event, char *fname, char *fname_io, bool force, buf_T *buf)
{
  return apply_autocmds_group(event, fname, fname_io, force, AUGROUP_ALL, buf, NULL, NULL);
}

/// Like apply_autocmds(), but with extra "eap" argument.  This takes care of
/// setting v:filearg.
///
/// @param event event that occurred
/// @param fname NULL or empty means use actual file name
/// @param fname_io fname to use for <afile> on cmdline
/// @param force When true, ignore autocmd_busy
/// @param buf Buffer for <abuf>
/// @param exarg Ex command arguments
///
/// @return true if some commands were executed.
bool apply_autocmds_exarg(event_T event, char *fname, char *fname_io, bool force, buf_T *buf,
                          exarg_T *eap)
{
  return apply_autocmds_group(event, fname, fname_io, force, AUGROUP_ALL, buf, eap, NULL);
}

/// Like apply_autocmds(), but handles the caller's retval.  If the script
/// processing is being aborted or if retval is FAIL when inside a try
/// conditional, no autocommands are executed.  If otherwise the autocommands
/// cause the script to be aborted, retval is set to FAIL.
///
/// @param event event that occurred
/// @param fname NULL or empty means use actual file name
/// @param fname_io fname to use for <afile> on cmdline
/// @param force When true, ignore autocmd_busy
/// @param buf Buffer for <abuf>
/// @param[in,out] retval caller's retval
///
/// @return true if some autocommands were executed
bool apply_autocmds_retval(event_T event, char *fname, char *fname_io, bool force, buf_T *buf,
                           int *retval)
{
  if (should_abort(*retval)) {
    return false;
  }

  bool did_cmd = apply_autocmds_group(event, fname, fname_io, force, AUGROUP_ALL, buf, NULL, NULL);
  if (did_cmd && aborting()) {
    *retval = FAIL;
  }
  return did_cmd;
}

/// Return true if "event" autocommand is defined.
///
/// @param event the autocommand to check
bool has_event(event_T event) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return kv_size(autocmds[(int)event]) != 0;
}

/// Return true when there is a CursorHold/CursorHoldI autocommand defined for
/// the current mode.
bool has_cursorhold(void) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return has_event((get_real_state() == MODE_NORMAL_BUSY ? EVENT_CURSORHOLD : EVENT_CURSORHOLDI));
}

/// Return true if the CursorHold/CursorHoldI event can be triggered.
bool trigger_cursorhold(void) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  if (!did_cursorhold && has_cursorhold() && reg_recording == 0
      && typebuf.tb_len == 0 && !ins_compl_active()) {
    int state = get_real_state();
    if (state == MODE_NORMAL_BUSY || (state & MODE_INSERT) != 0) {
      return true;
    }
  }
  return false;
}

/// Execute autocommands for "event" and file name "fname".
///
/// @param event event that occurred
/// @param fname filename, NULL or empty means use actual file name
/// @param fname_io filename to use for <afile> on cmdline,
///                 NULL means use `fname`.
/// @param force When true, ignore autocmd_busy
/// @param group autocmd group ID or AUGROUP_ALL
/// @param buf Buffer for <abuf>
/// @param eap Ex command arguments
///
/// @return true if some commands were executed.
bool apply_autocmds_group(event_T event, char *fname, char *fname_io, bool force, int group,
                          buf_T *buf, exarg_T *eap, Object *data)
{
  char *sfname = NULL;  // short file name
  bool retval = false;
  static int nesting = 0;
  char *save_cmdarg;
  static bool filechangeshell_busy = false;
  proftime_T wait_time;
  bool did_save_redobuff = false;
  save_redo_T save_redo;
  const bool save_KeyTyped = KeyTyped;

  // Quickly return if there are no autocommands for this event or
  // autocommands are blocked.
  if (event == NUM_EVENTS || kv_size(autocmds[(int)event]) == 0 || is_autocmd_blocked()) {
    goto BYPASS_AU;
  }

  // When autocommands are busy, new autocommands are only executed when
  // explicitly enabled with the "nested" flag.
  if (autocmd_busy && !(force || autocmd_nested)) {
    goto BYPASS_AU;
  }

  // Quickly return when immediately aborting on error, or when an interrupt
  // occurred or an exception was thrown but not caught.
  if (aborting()) {
    goto BYPASS_AU;
  }

  // FileChangedShell never nests, because it can create an endless loop.
  if (filechangeshell_busy
      && (event == EVENT_FILECHANGEDSHELL || event == EVENT_FILECHANGEDSHELLPOST)) {
    goto BYPASS_AU;
  }

  // Ignore events in 'eventignore'.
  if (event_ignored(event, p_ei)) {
    goto BYPASS_AU;
  }

  bool win_ignore = false;
  // If event is allowed in 'eventignorewin', check if curwin or all windows
  // into "buf" are ignoring the event.
  if (buf == curbuf && event_names[event].event <= 0) {
    win_ignore = event_ignored(event, curwin->w_p_eiw);
  } else if (buf != NULL && event_names[event].event <= 0) {
    for (size_t i = 0; i < kv_size(buf->b_wininfo); i++) {
      WinInfo *wip = kv_A(buf->b_wininfo, i);
      if (wip->wi_win != NULL && wip->wi_win->w_buffer == buf) {
        win_ignore = event_ignored(event, wip->wi_win->w_p_eiw);
      }
    }
  }
  if (win_ignore) {
    goto BYPASS_AU;
  }

  // Allow nesting of autocommands, but restrict the depth, because it's
  // possible to create an endless loop.
  if (nesting == 10) {
    emsg(_(e_autocommand_nesting_too_deep));
    goto BYPASS_AU;
  }

  // Check if these autocommands are disabled.  Used when doing ":all" or
  // ":ball".
  if ((autocmd_no_enter && (event == EVENT_WINENTER || event == EVENT_BUFENTER))
      || (autocmd_no_leave && (event == EVENT_WINLEAVE || event == EVENT_BUFLEAVE))) {
    goto BYPASS_AU;
  }

  // Save the autocmd_* variables and info about the current buffer.
  char *save_autocmd_fname = autocmd_fname;
  bool save_autocmd_fname_full = autocmd_fname_full;
  int save_autocmd_bufnr = autocmd_bufnr;
  char *save_autocmd_match = autocmd_match;
  int save_autocmd_busy = autocmd_busy;
  int save_autocmd_nested = autocmd_nested;
  bool save_changed = curbuf->b_changed;
  buf_T *old_curbuf = curbuf;

  // Set the file name to be used for <afile>.
  // Make a copy to avoid that changing a buffer name or directory makes it
  // invalid.
  if (fname_io == NULL) {
    if (event == EVENT_COLORSCHEME || event == EVENT_COLORSCHEMEPRE
        || event == EVENT_OPTIONSET || event == EVENT_MODECHANGED) {
      autocmd_fname = NULL;
    } else if (fname != NULL && !ends_excmd(*fname)) {
      autocmd_fname = fname;
    } else if (buf != NULL) {
      autocmd_fname = buf->b_ffname;
    } else {
      autocmd_fname = NULL;
    }
  } else {
    autocmd_fname = fname_io;
  }
  char *afile_orig = NULL;  ///< Unexpanded <afile>
  if (autocmd_fname != NULL) {
    afile_orig = xstrdup(autocmd_fname);
    // Allocate MAXPATHL for when eval_vars() resolves the fullpath.
    autocmd_fname = xstrnsave(autocmd_fname, MAXPATHL);
  }
  autocmd_fname_full = false;  // call FullName_save() later

  // Set the buffer number to be used for <abuf>.
  autocmd_bufnr = buf == NULL ? 0 : buf->b_fnum;

  // When the file name is NULL or empty, use the file name of buffer "buf".
  // Always use the full path of the file name to match with, in case
  // "allow_dirs" is set.
  if (fname == NULL || *fname == NUL) {
    if (buf == NULL) {
      fname = NULL;
    } else {
      if (event == EVENT_SYNTAX) {
        fname = buf->b_p_syn;
      } else if (event == EVENT_FILETYPE) {
        fname = buf->b_p_ft;
      } else {
        if (buf->b_sfname != NULL) {
          sfname = xstrdup(buf->b_sfname);
        }
        fname = buf->b_ffname;
      }
    }
    if (fname == NULL) {
      fname = "";
    }
    fname = xstrdup(fname);  // make a copy, so we can change it
  } else {
    sfname = xstrdup(fname);
    // Don't try expanding the following events.
    if (event == EVENT_CMDLINECHANGED
        || event == EVENT_CMDLINEENTER
        || event == EVENT_CMDLINELEAVEPRE
        || event == EVENT_CMDLINELEAVE
        || event == EVENT_CMDUNDEFINED
        || event == EVENT_CURSORMOVEDC
        || event == EVENT_CMDWINENTER
        || event == EVENT_CMDWINLEAVE
        || event == EVENT_COLORSCHEME
        || event == EVENT_COLORSCHEMEPRE
        || event == EVENT_DIRCHANGED
        || event == EVENT_DIRCHANGEDPRE
        || event == EVENT_FILETYPE
        || event == EVENT_FUNCUNDEFINED
        || event == EVENT_MENUPOPUP
        || event == EVENT_MODECHANGED
        || event == EVENT_OPTIONSET
        || event == EVENT_QUICKFIXCMDPOST
        || event == EVENT_QUICKFIXCMDPRE
        || event == EVENT_REMOTEREPLY
        || event == EVENT_SIGNAL
        || event == EVENT_SPELLFILEMISSING
        || event == EVENT_SYNTAX
        || event == EVENT_TABCLOSED
        || event == EVENT_USER
        || event == EVENT_WINCLOSED
        || event == EVENT_WINRESIZED
        || event == EVENT_WINSCROLLED) {
      fname = xstrdup(fname);
      autocmd_fname_full = true;  // don't expand it later
    } else {
      fname = FullName_save(fname, false);
    }
  }
  if (fname == NULL) {  // out of memory
    xfree(sfname);
    retval = false;
    goto BYPASS_AU;
  }

#ifdef BACKSLASH_IN_FILENAME
  // Replace all backslashes with forward slashes. This makes the
  // autocommand patterns portable between Unix and Windows.
  if (sfname != NULL) {
    forward_slash(sfname);
  }
  forward_slash(fname);
#endif

  // Set the name to be used for <amatch>.
  autocmd_match = fname;

  // Don't redraw while doing autocommands.
  RedrawingDisabled++;

  // name and lnum are filled in later
  estack_push(ETYPE_AUCMD, NULL, 0);

  const sctx_T save_current_sctx = current_sctx;

  if (do_profiling == PROF_YES) {
    prof_child_enter(&wait_time);  // doesn't count for the caller itself
  }

  // Don't use local function variables, if called from a function.
  funccal_entry_T funccal_entry;
  save_funccal(&funccal_entry);

  // When starting to execute autocommands, save the search patterns.
  if (!autocmd_busy) {
    save_search_patterns();
    if (!ins_compl_active()) {
      saveRedobuff(&save_redo);
      did_save_redobuff = true;
    }
    curbuf->b_did_filetype = curbuf->b_keep_filetype;
  }

  // Note that we are applying autocmds.  Some commands need to know.
  autocmd_busy = true;
  filechangeshell_busy = (event == EVENT_FILECHANGEDSHELL);
  nesting++;  // see matching decrement below

  // Remember that FileType was triggered.  Used for did_filetype().
  if (event == EVENT_FILETYPE) {
    curbuf->b_did_filetype = true;
  }

  char *tail = path_tail(fname);

  // Find first autocommand that matches
  AutoPatCmd patcmd = {
    // aucmd_next will set lastpat back to NULL if there are no more autocommands left to run
    .lastpat = NULL,
    // current autocommand index
    .auidx = 0,
    // save vector size, to avoid an endless loop when more patterns
    // are added when executing autocommands
    .ausize = kv_size(autocmds[(int)event]),
    .afile_orig = afile_orig,
    .fname = fname,
    .sfname = sfname,
    .tail = tail,
    .group = group,
    .event = event,
    .arg_bufnr = autocmd_bufnr,
  };
  aucmd_next(&patcmd);

  // Found first autocommand, start executing them
  if (patcmd.lastpat != NULL) {
    // add to active_apc_list
    patcmd.next = active_apc_list;
    active_apc_list = &patcmd;

    // Attach data to command
    patcmd.data = data;

    // set v:cmdarg (only when there is a matching pattern)
    varnumber_T save_cmdbang = get_vim_var_nr(VV_CMDBANG);
    if (eap != NULL) {
      save_cmdarg = set_cmdarg(eap, NULL);
      set_vim_var_nr(VV_CMDBANG, eap->forceit);
    } else {
      save_cmdarg = NULL;  // avoid gcc warning
    }
    retval = true;

    // Make sure cursor and topline are valid.  The first time the current
    // values are saved, restored by reset_lnums().  When nested only the
    // values are corrected when needed.
    if (nesting == 1) {
      check_lnums(true);
    } else {
      check_lnums_nested(true);
    }

    const int save_did_emsg = did_emsg;
    const bool save_ex_pressedreturn = get_pressedreturn();

    // Execute the autocmd. The `getnextac` callback handles iteration.
    do_cmdline(NULL, getnextac, &patcmd, DOCMD_NOWAIT | DOCMD_VERBOSE | DOCMD_REPEAT);

    did_emsg += save_did_emsg;
    set_pressedreturn(save_ex_pressedreturn);

    if (nesting == 1) {
      // restore cursor and topline, unless they were changed
      reset_lnums();
    }

    if (eap != NULL) {
      set_cmdarg(NULL, save_cmdarg);
      set_vim_var_nr(VV_CMDBANG, save_cmdbang);
    }
    // delete from active_apc_list
    if (active_apc_list == &patcmd) {  // just in case
      active_apc_list = patcmd.next;
    }
  }

  RedrawingDisabled--;
  autocmd_busy = save_autocmd_busy;
  filechangeshell_busy = false;
  autocmd_nested = save_autocmd_nested;
  xfree(SOURCING_NAME);
  estack_pop();
  xfree(afile_orig);
  xfree(autocmd_fname);
  autocmd_fname = save_autocmd_fname;
  autocmd_fname_full = save_autocmd_fname_full;
  autocmd_bufnr = save_autocmd_bufnr;
  autocmd_match = save_autocmd_match;
  current_sctx = save_current_sctx;
  restore_funccal();
  if (do_profiling == PROF_YES) {
    prof_child_exit(&wait_time);
  }
  KeyTyped = save_KeyTyped;
  xfree(fname);
  xfree(sfname);
  nesting--;  // see matching increment above

  // When stopping to execute autocommands, restore the search patterns and
  // the redo buffer. Free any buffers in the au_pending_free_buf list and
  // free any windows in the au_pending_free_win list.
  if (!autocmd_busy) {
    restore_search_patterns();
    if (did_save_redobuff) {
      restoreRedobuff(&save_redo);
    }
    curbuf->b_did_filetype = false;
    while (au_pending_free_buf != NULL) {
      buf_T *b = au_pending_free_buf->b_next;

      xfree(au_pending_free_buf);
      au_pending_free_buf = b;
    }
    while (au_pending_free_win != NULL) {
      win_T *w = au_pending_free_win->w_next;

      xfree(au_pending_free_win);
      au_pending_free_win = w;
    }
  }

  // Some events don't set or reset the Changed flag.
  // Check if still in the same buffer!
  if (curbuf == old_curbuf
      && (event == EVENT_BUFREADPOST || event == EVENT_BUFWRITEPOST
          || event == EVENT_FILEAPPENDPOST || event == EVENT_VIMLEAVE
          || event == EVENT_VIMLEAVEPRE)) {
    if (curbuf->b_changed != save_changed) {
      need_maketitle = true;
    }
    curbuf->b_changed = save_changed;
  }

  au_cleanup();  // may really delete removed patterns/commands now

BYPASS_AU:
  // When wiping out a buffer make sure all its buffer-local autocommands
  // are deleted.
  if (event == EVENT_BUFWIPEOUT && buf != NULL) {
    aubuflocal_remove(buf);
  }

  if (retval == OK && event == EVENT_FILETYPE) {
    curbuf->b_au_did_filetype = true;
  }

  return retval;
}

// Block triggering autocommands until unblock_autocmd() is called.
// Can be used recursively, so long as it's symmetric.
void block_autocmds(void)
{
  // Remember the value of v:termresponse.
  if (!is_autocmd_blocked()) {
    old_termresponse = get_vim_var_str(VV_TERMRESPONSE);
  }
  autocmd_blocked++;
}

void unblock_autocmds(void)
{
  autocmd_blocked--;

  // When v:termresponse was set while autocommands were blocked, trigger
  // the autocommands now.  Esp. useful when executing a shell command
  // during startup (nvim -d).
  if (!is_autocmd_blocked() && get_vim_var_str(VV_TERMRESPONSE) != old_termresponse) {
    apply_autocmds(EVENT_TERMRESPONSE, NULL, NULL, false, curbuf);
  }
}

bool is_autocmd_blocked(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return autocmd_blocked != 0;
}

/// Find next matching autocommand.
/// If next autocommand was not found, sets lastpat to NULL and cmdidx to SIZE_MAX on apc.
static void aucmd_next(AutoPatCmd *apc)
{
  estack_T *const entry = ((estack_T *)exestack.ga_data) + exestack.ga_len - 1;

  AutoCmdVec *const acs = &autocmds[(int)apc->event];
  assert(apc->ausize <= kv_size(*acs));
  for (size_t i = apc->auidx; i < apc->ausize && !got_int; i++) {
    AutoCmd *const ac = &kv_A(*acs, i);
    AutoPat *const ap = ac->pat;

    // Skip deleted autocommands.
    if (ap == NULL) {
      continue;
    }
    // Skip matching if pattern didn't change.
    if (ap != apc->lastpat) {
      // Skip autocommands that don't match the group.
      if (apc->group != AUGROUP_ALL && apc->group != ap->group) {
        continue;
      }
      // Skip autocommands that don't match the pattern or buffer number.
      if (ap->buflocal_nr == 0
          ? !match_file_pat(NULL, &ap->reg_prog, apc->fname, apc->sfname, apc->tail, ap->allow_dirs)
          : ap->buflocal_nr != apc->arg_bufnr) {
        continue;
      }

      const char *const name = event_nr2name(apc->event);
      const char *const s = _("%s Autocommands for \"%s\"");

      const size_t sourcing_name_len = strlen(s) + strlen(name) + (size_t)ap->patlen + 1;
      char *const namep = xmalloc(sourcing_name_len);
      snprintf(namep, sourcing_name_len, s, name, ap->pat);
      if (p_verbose >= 8) {
        verbose_enter();
        smsg(0, _("Executing %s"), namep);
        verbose_leave();
      }

      // Update the exestack entry for this autocmd.
      XFREE_CLEAR(entry->es_name);
      entry->es_name = namep;
      entry->es_info.aucmd = apc;
    }

    apc->lastpat = ap;
    apc->auidx = i;

    line_breakcheck();
    return;
  }

  // Clear the exestack entry for this ETYPE_AUCMD entry.
  XFREE_CLEAR(entry->es_name);
  entry->es_info.aucmd = NULL;

  apc->lastpat = NULL;
  apc->auidx = SIZE_MAX;
}

/// Executes an autocmd callback function (as opposed to an Ex command).
static bool au_callback(const AutoCmd *ac, const AutoPatCmd *apc)
{
  Callback callback = ac->handler_fn;
  if (callback.type == kCallbackLua) {
    MAXSIZE_TEMP_DICT(data, 7);
    PUT_C(data, "id", INTEGER_OBJ(ac->id));
    PUT_C(data, "event", CSTR_AS_OBJ(event_nr2name(apc->event)));
    PUT_C(data, "file", CSTR_AS_OBJ(apc->afile_orig));
    PUT_C(data, "match", CSTR_AS_OBJ(autocmd_match));
    PUT_C(data, "buf", INTEGER_OBJ(autocmd_bufnr));

    if (apc->data) {
      PUT_C(data, "data", *apc->data);
    }

    int group = ac->pat->group;
    switch (group) {
    case AUGROUP_ERROR:
      abort();  // unreachable
    case AUGROUP_DEFAULT:
    case AUGROUP_ALL:
    case AUGROUP_DELETED:
      // omit group in these cases
      break;
    default:
      PUT_C(data, "group", INTEGER_OBJ(group));
      break;
    }

    MAXSIZE_TEMP_ARRAY(args, 1);
    ADD_C(args, DICT_OBJ(data));

    Object result = nlua_call_ref(callback.data.luaref, NULL, args, kRetNilBool, NULL, NULL);
    return LUARET_TRUTHY(result);
  } else {
    typval_T argsin = TV_INITIAL_VALUE;
    typval_T rettv = TV_INITIAL_VALUE;
    callback_call(&callback, 0, &argsin, &rettv);
    return false;
  }
}

/// Get next autocommand command.
/// Called by do_cmdline() to get the next line for ":if".
/// @return allocated string, or NULL for end of autocommands.
char *getnextac(int c, void *cookie, int indent, bool do_concat)
{
  // These arguments are required for do_cmdline.
  (void)c;
  (void)indent;
  (void)do_concat;

  AutoPatCmd *const apc = (AutoPatCmd *)cookie;
  AutoCmdVec *const acs = &autocmds[(int)apc->event];

  aucmd_next(apc);
  if (apc->lastpat == NULL) {
    return NULL;
  }

  assert(apc->auidx < kv_size(*acs));
  AutoCmd *const ac = &kv_A(*acs, apc->auidx);
  assert(ac->pat != NULL);
  bool oneshot = ac->once;

  if (p_verbose >= 9) {
    verbose_enter_scroll();
    char *handler_str = aucmd_handler_to_string(ac);
    smsg(0, _("autocommand %s"), handler_str);
    msg_puts("\n");  // don't overwrite this either
    XFREE_CLEAR(handler_str);
    verbose_leave_scroll();
  }

  // Make sure to set autocmd_nested before executing
  // lua code, so that it works properly
  autocmd_nested = ac->nested;
  current_sctx = ac->script_ctx;
  apc->script_ctx = current_sctx;

  char *retval;
  if (ac->handler_cmd) {
    retval = xstrdup(ac->handler_cmd);
  } else {
    AutoCmd ac_copy = *ac;
    // Mark oneshot handler as "removed" now, to prevent recursion by e.g. `:doautocmd`. #25526
    ac->pat = oneshot ? NULL : ac->pat;
    // May reallocate `acs` kvec_t data and invalidate the `ac` pointer.
    bool rv = au_callback(&ac_copy, apc);
    if (oneshot) {
      // Restore `pat`. Use `acs` because `ac` may have been invalidated by the callback.
      kv_A(*acs, apc->auidx).pat = ac_copy.pat;
    }
    // If an autocommand callback returns true, delete the autocommand
    oneshot = oneshot || rv;

    // HACK(tjdevries):
    //  We just return "not-null" and continue going.
    //  This would be a good candidate for a refactor. You would need to refactor:
    //      1. do_cmdline to accept something besides a string
    //      OR
    //      2. make where we call do_cmdline for autocmds not have to return anything,
    //      and instead we loop over all the matches and just execute one-by-one.
    //          However, my expectation would be that could be expensive.
    retval = xcalloc(1, 1);
  }

  // Remove one-shot ("once") autocmd in anticipation of its execution.
  if (oneshot) {
    aucmd_del(&kv_A(*acs, apc->auidx));
  }

  if (apc->auidx < apc->ausize) {
    apc->auidx++;
  } else {
    apc->auidx = SIZE_MAX;
  }

  return retval;
}

/// Return true if there is a matching autocommand for "fname".
/// To account for buffer-local autocommands, function needs to know
/// in which buffer the file will be opened.
///
/// @param event event that occurred.
/// @param sfname filename the event occurred in.
/// @param buf buffer the file is open in
bool has_autocmd(event_T event, char *sfname, buf_T *buf)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  char *tail = path_tail(sfname);
  bool retval = false;

  char *fname = FullName_save(sfname, false);
  if (fname == NULL) {
    return false;
  }

#ifdef BACKSLASH_IN_FILENAME
  // Replace all backslashes with forward slashes. This makes the
  // autocommand patterns portable between Unix and Windows.
  sfname = xstrdup(sfname);
  forward_slash(sfname);
  forward_slash(fname);
#endif

  AutoCmdVec *const acs = &autocmds[(int)event];
  for (size_t i = 0; i < kv_size(*acs); i++) {
    AutoPat *const ap = kv_A(*acs, i).pat;
    if (ap != NULL
        && (ap->buflocal_nr == 0
            ? match_file_pat(NULL, &ap->reg_prog, fname, sfname, tail, ap->allow_dirs)
            : buf != NULL && ap->buflocal_nr == buf->b_fnum)) {
      retval = true;
      break;
    }
  }

  xfree(fname);
#ifdef BACKSLASH_IN_FILENAME
  xfree(sfname);
#endif

  return retval;
}

// Function given to ExpandGeneric() to obtain the list of autocommand group names.
char *expand_get_augroup_name(expand_T *xp, int idx)
{
  (void)xp;  // Required for ExpandGeneric
  return augroup_name(idx + 1);
}

/// @param doautocmd  true for :doauto*, false for :autocmd
char *set_context_in_autocmd(expand_T *xp, char *arg, bool doautocmd)
{
  // check for a group name, skip it if present
  autocmd_include_groups = false;
  char *p = arg;
  int group = arg_augroup_get(&arg);

  // If there only is a group name that's what we expand.
  if (*arg == NUL && group != AUGROUP_ALL && !ascii_iswhite(arg[-1])) {
    arg = p;
    group = AUGROUP_ALL;
  }

  // skip over event name
  for (p = arg; *p != NUL && !ascii_iswhite(*p); p++) {
    if (*p == ',') {
      arg = p + 1;
    }
  }
  if (*p == NUL) {
    if (group == AUGROUP_ALL) {
      autocmd_include_groups = true;
    }
    xp->xp_context = EXPAND_EVENTS;  // expand event name
    xp->xp_pattern = arg;
    return NULL;
  }

  // skip over pattern
  arg = skipwhite(p);
  while (*arg && (!ascii_iswhite(*arg) || arg[-1] == '\\')) {
    arg++;
  }
  if (*arg) {
    return arg;  // expand (next) command
  }

  if (doautocmd) {
    xp->xp_context = EXPAND_FILES;  // expand file names
  } else {
    xp->xp_context = EXPAND_NOTHING;  // pattern is not expanded
  }
  return NULL;
}

/// Function given to ExpandGeneric() to obtain the list of event names.
char *expand_get_event_name(expand_T *xp, int idx)
{
  (void)xp;  // xp is a required parameter to be used with ExpandGeneric

  // List group names
  char *name = augroup_name(idx + 1);
  if (name != NULL) {
    // skip when not including groups or skip deleted entries
    if (!autocmd_include_groups || name == get_deleted_augroup()) {
      return "";
    }

    return name;
  }

  int i = idx - next_augroup_id;
  if (i < 0 || i >= NUM_EVENTS) {
    return NULL;
  }

  // List event names
  return event_names[i].name;
}

/// Function given to ExpandGeneric() to obtain the list of event names. Don't
/// include groups.
char *get_event_name_no_group(expand_T *xp FUNC_ATTR_UNUSED, int idx, bool win)
{
  if (idx < 0 || idx >= NUM_EVENTS) {
    return NULL;
  }

  if (!win) {
    return event_names[idx].name;
  }

  // Need to check subset of allowed values for 'eventignorewin'.
  int j = 0;
  for (int i = 0; i < NUM_EVENTS; i++) {
    j += event_names[i].event <= 0;
    if (j == idx + 1) {
      return event_names[i].name;
    }
  }
  return NULL;
}

/// Check whether given autocommand is supported
///
/// @param[in]  event  Event to check.
///
/// @return True if it is, false otherwise.
bool autocmd_supported(const char *const event)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  char *p;
  return event_name2nr(event, &p) != NUM_EVENTS;
}

/// Return true if an autocommand is defined for a group, event and
/// pattern:  The group can be omitted to accept any group.
/// `event` and `pattern` can be omitted to accept any event and pattern.
/// Buffer-local patterns <buffer> or <buffer=N> are accepted.
/// Used for:
///   exists("#Group") or
///   exists("#Group#Event") or
///   exists("#Group#Event#pat") or
///   exists("#Event") or
///   exists("#Event#pat")
///
/// @param arg autocommand string
bool au_exists(const char *const arg)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  buf_T *buflocal_buf = NULL;
  bool retval = false;

  // Make a copy so that we can change the '#' chars to a NUL.
  char *const arg_save = xstrdup(arg);
  char *p = strchr(arg_save, '#');
  if (p != NULL) {
    *p++ = NUL;
  }

  // First, look for an autocmd group name.
  int group = augroup_find(arg_save);
  char *event_name;
  if (group == AUGROUP_ERROR) {
    // Didn't match a group name, assume the first argument is an event.
    group = AUGROUP_ALL;
    event_name = arg_save;
  } else {
    if (p == NULL) {
      // "Group": group name is present and it's recognized
      retval = true;
      goto theend;
    }

    // Must be "Group#Event" or "Group#Event#pat".
    event_name = p;
    p = strchr(event_name, '#');
    if (p != NULL) {
      *p++ = NUL;  // "Group#Event#pat"
    }
  }

  char *pattern = p;  // "pattern" is NULL when there is no pattern.

  // Find the index (enum) for the event name.
  event_T event = event_name2nr(event_name, &p);

  // return false if the event name is not recognized
  if (event == NUM_EVENTS) {
    goto theend;
  }

  // Find the first autocommand for this event.
  // If there isn't any, return false;
  // If there is one and no pattern given, return true;
  AutoCmdVec *const acs = &autocmds[(int)event];
  if (kv_size(*acs) == 0) {
    goto theend;
  }

  // if pattern is "<buffer>", special handling is needed which uses curbuf
  // for pattern "<buffer=N>, path_fnamecmp() will work fine
  if (pattern != NULL && STRICMP(pattern, "<buffer>") == 0) {
    buflocal_buf = curbuf;
  }

  // Check if there is an autocommand with the given pattern.
  for (size_t i = 0; i < kv_size(*acs); i++) {
    AutoPat *const ap = kv_A(*acs, i).pat;
    // Only use a pattern when it has not been removed.
    // For buffer-local autocommands, path_fnamecmp() works fine.
    if (ap != NULL
        && (group == AUGROUP_ALL || ap->group == group)
        && (pattern == NULL
            || (buflocal_buf == NULL
                ? path_fnamecmp(ap->pat, pattern) == 0
                : ap->buflocal_nr == buflocal_buf->b_fnum))) {
      retval = true;
      break;
    }
  }

theend:
  xfree(arg_save);
  return retval;
}

// Checks if a pattern is buflocal
bool aupat_is_buflocal(const char *pat, int patlen)
  FUNC_ATTR_PURE
{
  return patlen >= 8 && strncmp(pat, "<buffer", 7) == 0 && (pat)[patlen - 1] == '>';
}

int aupat_get_buflocal_nr(const char *pat, int patlen)
{
  assert(aupat_is_buflocal(pat, patlen));

  // "<buffer>"
  if (patlen == 8) {
    return curbuf->b_fnum;
  }

  if (patlen > 9 && (pat)[7] == '=') {
    // "<buffer=abuf>"
    if (patlen == 13 && STRNICMP(pat, "<buffer=abuf>", 13) == 0) {
      return autocmd_bufnr;
    }

    // "<buffer=123>"
    if (skipdigits(pat + 8) == pat + patlen - 1) {
      return atoi(pat + 8);
    }
  }

  return 0;
}

// normalize buffer pattern
void aupat_normalize_buflocal_pat(char *dest, const char *pat, int patlen, int buflocal_nr)
{
  assert(aupat_is_buflocal(pat, patlen));

  if (buflocal_nr == 0) {
    buflocal_nr = curbuf->handle;
  }

  // normalize pat into standard "<buffer>#N" form
  snprintf(dest, BUFLOCAL_PAT_LEN, "<buffer=%d>", buflocal_nr);
}

int autocmd_delete_event(int group, event_T event, const char *pat)
  FUNC_ATTR_NONNULL_ALL
{
  return do_autocmd_event(event, pat, false, false, "", true, group);
}

/// Deletes an autocmd by ID.
/// Only autocmds created via the API have IDs associated with them. There
/// is no way to delete a specific autocmd created via :autocmd
bool autocmd_delete_id(int64_t id)
{
  assert(id > 0);
  bool success = false;

  // Note that since multiple AutoCmd objects can have the same ID, we need to do a full scan.
  FOR_ALL_AUEVENTS(event) {
    AutoCmdVec *const acs = &autocmds[(int)event];
    for (size_t i = 0; i < kv_size(*acs); i++) {
      AutoCmd *const ac = &kv_A(*acs, i);
      if (ac->id == id) {
        aucmd_del(ac);
        success = true;
      }
    }
  }
  return success;
}

/// Gets an (allocated) string representation of an autocmd command/callback.
char *aucmd_handler_to_string(AutoCmd *ac)
  FUNC_ATTR_PURE
{
  if (ac->handler_cmd) {
    return xstrdup(ac->handler_cmd);
  }
  return callback_to_string(&ac->handler_fn, NULL);
}

bool au_event_is_empty(event_T event)
  FUNC_ATTR_PURE
{
  return kv_size(autocmds[(int)event]) == 0;
}

// Arg Parsing Functions

/// Scan over the events.  "*" stands for all events.
/// true when group name was found
static char *arg_event_skip(char *arg, bool have_group)
{
  char *pat;
  char *p;

  if (*arg == '*') {
    if (arg[1] && !ascii_iswhite(arg[1])) {
      semsg(_("E215: Illegal character after *: %s"), arg);
      return NULL;
    }
    pat = arg + 1;
  } else {
    for (pat = arg; *pat && *pat != '|' && !ascii_iswhite(*pat); pat = p) {
      if ((int)event_name2nr(pat, &p) >= NUM_EVENTS) {
        if (have_group) {
          semsg(_("E216: No such event: %s"), pat);
        } else {
          semsg(_("E216: No such group or event: %s"), pat);
        }
        return NULL;
      }
    }
  }
  return pat;
}

// Find the group ID in a ":autocmd" or ":doautocmd" argument.
// The "argp" argument is advanced to the following argument.
//
// Returns the group ID or AUGROUP_ALL.
static int arg_augroup_get(char **argp)
{
  char *p;
  char *arg = *argp;

  for (p = arg; *p && !ascii_iswhite(*p) && *p != '|'; p++) {}
  if (p <= arg) {
    return AUGROUP_ALL;
  }

  char *group_name = xmemdupz(arg, (size_t)(p - arg));
  int group = augroup_find(group_name);
  if (group == AUGROUP_ERROR) {
    group = AUGROUP_ALL;  // no match, use all groups
  } else {
    *argp = skipwhite(p);  // match, skip over group name
  }
  xfree(group_name);
  return group;
}

/// Handles grabbing arguments from `:autocmd` such as ++once and ++nested
static bool arg_autocmd_flag_get(bool *flag, char **cmd_ptr, char *pattern, int len)
{
  if (strncmp(*cmd_ptr, pattern, (size_t)len) == 0 && ascii_iswhite((*cmd_ptr)[len])) {
    if (*flag) {
      semsg(_(e_duparg2), pattern);
      return true;
    }

    *flag = true;
    *cmd_ptr = skipwhite(*cmd_ptr + len);
  }

  return false;
}

/// When kFalse: VimSuspend should be triggered next.
/// When kTrue: VimResume should be triggered next.
/// When kNone: Currently triggering VimSuspend or VimResume.
static TriState pending_vimresume = kFalse;

static void vimresume_event(void **argv)
{
  apply_autocmds(EVENT_VIMRESUME, NULL, NULL, false, NULL);
  pending_vimresume = kFalse;
}

/// Trigger VimSuspend or VimResume autocommand.
void may_trigger_vim_suspend_resume(bool suspend)
{
  if (suspend && pending_vimresume == kFalse) {
    pending_vimresume = kNone;
    apply_autocmds(EVENT_VIMSUSPEND, NULL, NULL, false, NULL);
    pending_vimresume = kTrue;
  } else if (!suspend && pending_vimresume == kTrue) {
    pending_vimresume = kNone;
    multiqueue_put(main_loop.events, vimresume_event, NULL);
  }
}

// UI Enter
void do_autocmd_uienter(uint64_t chanid, bool attached)
{
  static bool recursive = false;

#ifdef EXITFREE
  if (entered_free_all_mem) {
    return;
  }
#endif
  if (starting == NO_SCREEN) {
    return;  // user config hasn't been sourced yet
  }
  if (recursive) {
    return;  // disallow recursion
  }
  recursive = true;

  save_v_event_T save_v_event;
  dict_T *dict = get_v_event(&save_v_event);
  assert(chanid < VARNUMBER_MAX);
  tv_dict_add_nr(dict, S_LEN("chan"), (varnumber_T)chanid);
  tv_dict_set_keys_readonly(dict);
  apply_autocmds(attached ? EVENT_UIENTER : EVENT_UILEAVE, NULL, NULL, false, curbuf);
  restore_v_event(dict, &save_v_event);

  recursive = false;
}

// FocusGained

void do_autocmd_focusgained(bool gained)
{
  static bool recursive = false;
  static Timestamp last_time = 0;

  if (recursive) {
    return;  // disallow recursion
  }
  recursive = true;
  apply_autocmds((gained ? EVENT_FOCUSGAINED : EVENT_FOCUSLOST), NULL, NULL, false, curbuf);

  // When activated: Check if any file was modified outside of Vim.
  // Only do this when not done within the last two seconds as:
  // 1. Some filesystems have modification time granularity in seconds. Fat32
  //    has a granularity of 2 seconds.
  // 2. We could get multiple notifications in a row.
  if (gained && last_time + (Timestamp)2000 < os_now()) {
    check_timestamps(true);
    last_time = os_now();
  }

  recursive = false;
}

void do_filetype_autocmd(buf_T *buf, bool force)
{
  static int ft_recursive = 0;

  if (ft_recursive > 0 && !force) {
    return;  // disallow recursion
  }

  char **varp = &buf->b_p_ft;
  int secure_save = secure;

  // Reset the secure flag, since the value of 'filetype' has
  // been checked to be safe.
  secure = 0;

  ft_recursive++;
  buf->b_did_filetype = true;
  // Only pass true for "force" when it is true or
  // used recursively, to avoid endless recurrence.
  apply_autocmds(EVENT_FILETYPE, buf->b_p_ft, buf->b_fname, force || ft_recursive == 1, buf);
  ft_recursive--;

  // Just in case the old "buf" is now invalid
  if (varp != &(buf->b_p_ft)) {
    varp = NULL;
  }
  secure = secure_save;
}
