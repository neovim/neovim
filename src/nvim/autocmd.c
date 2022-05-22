// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// autocmd.c: Autocommand related functions
#include <signal.h>

#include "lauxlib.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_getln.h"
#include "nvim/fileio.h"
#include "nvim/getchar.h"
#include "nvim/lua/executor.h"
#include "nvim/map.h"
#include "nvim/option.h"
#include "nvim/os/input.h"
#include "nvim/regexp.h"
#include "nvim/search.h"
#include "nvim/state.h"
#include "nvim/ui_compositor.h"
#include "nvim/vim.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "auevents_name_map.generated.h"
# include "autocmd.c.generated.h"
#endif

// Naming Conventions:
//  - general autocmd behavior start with au_
//  - AutoCmd start with aucmd_
//  - Autocmd.exec stat with aucmd_exec
//  - AutoPat start with aupat_
//  - Groups start with augroup_
//  - Events start with event_

//
// The autocommands are stored in a list for each event.
// Autocommands for the same pattern, that are consecutive, are joined
// together, to avoid having to match the pattern too often.
// The result is an array of Autopat lists, which point to AutoCmd lists:
//
// last_autopat[0]  -----------------------------+
//                                               V
// first_autopat[0] --> Autopat.next  -->  Autopat.next -->  NULL
//                      Autopat.cmds       Autopat.cmds
//                          |                    |
//                          V                    V
//                      AutoCmd.next       AutoCmd.next
//                          |                    |
//                          V                    V
//                      AutoCmd.next            NULL
//                          |
//                          V
//                         NULL
//
// last_autopat[1]  --------+
//                          V
// first_autopat[1] --> Autopat.next  -->  NULL
//                      Autopat.cmds
//                          |
//                          V
//                      AutoCmd.next
//                          |
//                          V
//                         NULL
//   etc.
//
//   The order of AutoCmds is important, this is the order in which they were
//   defined and will have to be executed.
//

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
static int au_need_clean = false;

static int autocmd_blocked = 0;  // block all autocmds

static bool autocmd_nested = false;
static bool autocmd_include_groups = false;

static char *old_termresponse = NULL;

/// Iterates over all the AutoPats for a particular event
#define FOR_ALL_AUPATS_IN_EVENT(event, ap) \
  for (AutoPat *ap = first_autopat[event]; ap != NULL; ap = ap->next)  // NOLINT

// Map of autocmd group names and ids.
//  name -> ID
//  ID -> name
static Map(String, int) map_augroup_name_to_id = MAP_INIT;
static Map(int, String) map_augroup_id_to_name = MAP_INIT;

static void augroup_map_del(int id, char *name)
{
  if (name != NULL) {
    String key = map_key(String, int)(&map_augroup_name_to_id, cstr_as_string(name));
    map_del(String, int)(&map_augroup_name_to_id, key);
    api_free_string(key);
  }
  if (id > 0) {
    String mapped = map_get(int, String)(&map_augroup_id_to_name, id);
    api_free_string(mapped);
    map_del(int, String)(&map_augroup_id_to_name, id);
  }
}

static inline const char *get_deleted_augroup(void) FUNC_ATTR_ALWAYS_INLINE
{
  if (deleted_augroup == NULL) {
    deleted_augroup = _("--Deleted--");
  }
  return deleted_augroup;
}

// Show the autocommands for one AutoPat.
static void aupat_show(AutoPat *ap, event_T event, int previous_group)
{
  // Check for "got_int" (here and at various places below), which is set
  // when "q" has been hit for the "--more--" prompt
  if (got_int) {
    return;
  }

  // pattern has been removed
  if (ap->pat == NULL) {
    return;
  }

  char *name = augroup_name(ap->group);

  msg_putchar('\n');
  if (got_int) {
    return;
  }
  // When switching groups, we need to show the new group information.
  if (ap->group != previous_group) {
    // show the group name, if it's not the default group
    if (ap->group != AUGROUP_DEFAULT) {
      if (name == NULL) {
        msg_puts_attr(get_deleted_augroup(), HL_ATTR(HLF_E));
      } else {
        msg_puts_attr(name, HL_ATTR(HLF_T));
      }
      msg_puts("  ");
    }
    // show the event name
    msg_puts_attr(event_nr2name(event), HL_ATTR(HLF_T));
    msg_putchar('\n');
    if (got_int) {
      return;
    }
  }

  msg_col = 4;
  msg_outtrans((char_u *)ap->pat);

  for (AutoCmd *ac = ap->cmds; ac != NULL; ac = ac->next) {
    // skip removed commands
    if (aucmd_exec_is_deleted(ac->exec)) {
      continue;
    }

    if (msg_col >= 14) {
      msg_putchar('\n');
    }
    msg_col = 14;
    if (got_int) {
      return;
    }

    char *exec_to_string = aucmd_exec_to_string(ac, ac->exec);
    if (ac->desc != NULL) {
      size_t msglen = 100;
      char *msg = (char *)xmallocz(msglen);
      snprintf(msg, msglen, "%s [%s]", exec_to_string, ac->desc);
      msg_outtrans((char_u *)msg);
      XFREE_CLEAR(msg);
    } else {
      msg_outtrans((char_u *)exec_to_string);
    }
    XFREE_CLEAR(exec_to_string);
    if (p_verbose > 0) {
      last_set_msg(ac->script_ctx);
    }
    if (got_int) {
      return;
    }
    if (ac->next != NULL) {
      msg_putchar('\n');
      if (got_int) {
        return;
      }
    }
  }
}

static void au_show_for_all_events(int group, char *pat)
{
  FOR_ALL_AUEVENTS(event) {
    au_show_for_event(group, event, pat);
  }
}

static void au_show_for_event(int group, event_T event, char *pat)
{
  // Return early if there are no autocmds for this event
  if (au_event_is_empty(event)) {
    return;
  }

  // always need to show group information before the first pattern for the event
  int previous_group = AUGROUP_ERROR;

  if (*pat == NUL) {
    FOR_ALL_AUPATS_IN_EVENT(event, ap) {
      if (group == AUGROUP_ALL || ap->group == group) {
        aupat_show(ap, event, previous_group);
        previous_group = ap->group;
      }
    }
    return;
  }

  char buflocal_pat[BUFLOCAL_PAT_LEN];  // for "<buffer=X>"
  // Loop through all the specified patterns.
  int patlen = (int)aucmd_pattern_length(pat);
  while (patlen) {
    // detect special <buffer[=X]> buffer-local patterns
    if (aupat_is_buflocal(pat, patlen)) {
      // normalize pat into standard "<buffer>#N" form
      aupat_normalize_buflocal_pat(buflocal_pat, pat, patlen, aupat_get_buflocal_nr(pat, patlen));
      pat = (char *)buflocal_pat;
      patlen = (int)STRLEN(buflocal_pat);
    }

    assert(*pat != NUL);

    // Find AutoPat entries with this pattern.
    // always goes at or after the last one, so start at the end.
    FOR_ALL_AUPATS_IN_EVENT(event, ap) {
      if (ap->pat != NULL) {
        // Accept a pattern when:
        // - a group was specified and it's that group
        // - the length of the pattern matches
        // - the pattern matches.
        // For <buffer[=X]>, this condition works because we normalize
        // all buffer-local patterns.
        if ((group == AUGROUP_ALL || ap->group == group)
            && ap->patlen == patlen
            && STRNCMP(pat, ap->pat, patlen) == 0) {
          // Show autocmd's for this autopat, or buflocals <buffer=X>
          aupat_show(ap, event, previous_group);
          previous_group = ap->group;
        }
      }
    }

    pat = aucmd_next_pattern(pat, (size_t)patlen);
    patlen = (int)aucmd_pattern_length(pat);
  }
}

// Mark an autocommand handler for deletion.
static void aupat_del(AutoPat *ap)
{
  XFREE_CLEAR(ap->pat);
  ap->buflocal_nr = -1;
  au_need_clean = true;
}

void aupat_del_for_event_and_group(event_T event, int group)
{
  FOR_ALL_AUPATS_IN_EVENT(event, ap) {
    if (ap->group == group) {
      aupat_del(ap);
    }
  }

  au_cleanup();
}

// Mark all commands for a pattern for deletion.
static void aupat_remove_cmds(AutoPat *ap)
{
  for (AutoCmd *ac = ap->cmds; ac != NULL; ac = ac->next) {
    aucmd_exec_free(&ac->exec);

    if (ac->desc != NULL) {
      XFREE_CLEAR(ac->desc);
    }
  }
  au_need_clean = true;
}

// Delete one command from an autocmd pattern.
static void aucmd_del(AutoCmd *ac)
{
  aucmd_exec_free(&ac->exec);
  if (ac->desc != NULL) {
    XFREE_CLEAR(ac->desc);
  }
  au_need_clean = true;
}

/// Cleanup autocommands and patterns that have been deleted.
/// This is only done when not executing autocommands.
static void au_cleanup(void)
{
  if (autocmd_busy || !au_need_clean) {
    return;
  }

  // Loop over all events.
  FOR_ALL_AUEVENTS(event) {
    // Loop over all autocommand patterns.
    AutoPat **prev_ap = &(first_autopat[(int)event]);
    for (AutoPat *ap = *prev_ap; ap != NULL; ap = *prev_ap) {
      bool has_cmd = false;

      // Loop over all commands for this pattern.
      AutoCmd **prev_ac = &(ap->cmds);
      for (AutoCmd *ac = *prev_ac; ac != NULL; ac = *prev_ac) {
        // Remove the command if the pattern is to be deleted or when
        // the command has been marked for deletion.
        if (ap->pat == NULL || aucmd_exec_is_deleted(ac->exec)) {
          *prev_ac = ac->next;
          aucmd_exec_free(&ac->exec);
          if (ac->desc != NULL) {
            XFREE_CLEAR(ac->desc);
          }

          xfree(ac);
        } else {
          has_cmd = true;
          prev_ac = &(ac->next);
        }
      }

      if (ap->pat != NULL && !has_cmd) {
        // Pattern was not marked for deletion, but all of its commands were.
        // So mark the pattern for deletion.
        aupat_del(ap);
      }

      // Remove the pattern if it has been marked for deletion.
      if (ap->pat == NULL) {
        if (ap->next == NULL) {
          if (prev_ap == &(first_autopat[(int)event])) {
            last_autopat[(int)event] = NULL;
          } else {
            // this depends on the "next" field being the first in
            // the struct
            last_autopat[(int)event] = (AutoPat *)prev_ap;
          }
        }
        *prev_ap = ap->next;
        vim_regfree(ap->reg_prog);
        xfree(ap);
      } else {
        prev_ap = &(ap->next);
      }
    }
  }

  au_need_clean = false;
}

// Get the first AutoPat for a particular event.
AutoPat *au_get_autopat_for_event(event_T event)
  FUNC_ATTR_PURE
{
  return first_autopat[(int)event];
}

// Called when buffer is freed, to remove/invalidate related buffer-local
// autocmds.
void aubuflocal_remove(buf_T *buf)
{
  // invalidate currently executing autocommands
  for (AutoPatCmd *apc = active_apc_list; apc; apc = apc->next) {
    if (buf->b_fnum == apc->arg_bufnr) {
      apc->arg_bufnr = 0;
    }
  }

  // invalidate buflocals looping through events
  FOR_ALL_AUEVENTS(event) {
    FOR_ALL_AUPATS_IN_EVENT(event, ap) {
      if (ap->buflocal_nr == buf->b_fnum) {
        aupat_del(ap);

        if (p_verbose >= 6) {
          verbose_enter();
          smsg(_("auto-removing autocommand: %s <buffer=%d>"),
               event_nr2name(event), buf->b_fnum);
          verbose_leave();
        }
      }
    }
  }
  au_cleanup();
}

// Add an autocmd group name or return existing group matching name.
// Return its ID.
int augroup_add(char *name)
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
  int i = augroup_find(name);
  if (i == AUGROUP_ERROR) {  // the group doesn't exist
    semsg(_("E367: No such group: \"%s\""), name);
  } else if (i == current_augroup) {
    emsg(_("E936: Cannot delete the current group"));
  } else {
    if (stupid_legacy_mode) {
      FOR_ALL_AUEVENTS(event) {
        FOR_ALL_AUPATS_IN_EVENT(event, ap) {
          if (ap->group == i && ap->pat != NULL) {
            give_warning((char_u *)_("W19: Deleting augroup that is still in use"), true);
            map_put(String, int)(&map_augroup_name_to_id, cstr_as_string(name), AUGROUP_DELETED);
            augroup_map_del(ap->group, NULL);
            return;
          }
        }
      }
    } else {
      FOR_ALL_AUEVENTS(event) {
        FOR_ALL_AUPATS_IN_EVENT(event, ap) {
          if (ap->group == i) {
            aupat_del(ap);
          }
        }
      }
    }

    // Remove the group because it's not currently in use.
    augroup_map_del(i, name);
    au_cleanup();
  }
}

/// Find the ID of an autocmd group name.
///
/// @param name augroup name
///
/// @return the ID or AUGROUP_ERROR (< 0) for error.
int augroup_find(const char *name)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  int existing_id = map_get(String, int)(&map_augroup_name_to_id, cstr_as_string((char *)name));
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
void do_augroup(char *arg, int del_group)
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
    FOR_ALL_AUPATS_IN_EVENT(event, ap) {
      aupat_del(ap);
    }
  }

  au_need_clean = true;
  au_cleanup();

  // Delete the augroup_map, including free the data
  String name;
  int id;
  map_foreach(&map_augroup_name_to_id, name, id, {
    (void)id;
    api_free_string(name);
  })
  map_destroy(String, int)(&map_augroup_name_to_id);

  map_foreach(&map_augroup_id_to_name, id, name, {
    (void)id;
    api_free_string(name);
  })
  map_destroy(int, String)(&map_augroup_id_to_name);
}
#endif

// Return the event number for event name "start".
// Return NUM_EVENTS if the event name was not found.
// Return a pointer to the next event name in "end".
event_T event_name2nr(const char *start, char **end)
{
  const char *p;
  int i;

  // the event name ends with end of line, '|', a blank or a comma
  for (p = start; *p && !ascii_iswhite(*p) && *p != ',' && *p != '|'; p++) {}
  for (i = 0; event_names[i].name != NULL; i++) {
    int len = (int)event_names[i].len;
    if (len == p - start && STRNICMP(event_names[i].name, start, len) == 0) {
      break;
    }
  }
  if (*p == ',') {
    p++;
  }
  *end = (char *)p;
  if (event_names[i].name == NULL) {
    return NUM_EVENTS;
  }
  return event_names[i].event;
}

/// Return the name for event
///
/// @param[in]  event  Event to return name for.
///
/// @return Event name, static string. Returns "Unknown" for unknown events.
const char *event_nr2name(event_T event)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_CONST
{
  for (int i = 0; event_names[i].name != NULL; i++) {
    if (event_names[i].event == event) {
      return event_names[i].name;
    }
  }
  return "Unknown";
}

/// Return true if "event" is included in 'eventignore'.
///
/// @param event event to check
static bool event_ignored(event_T event)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  char *p = (char *)p_ei;

  while (*p != NUL) {
    if (STRNICMP(p, "all", 3) == 0 && (p[3] == NUL || p[3] == ',')) {
      return true;
    }
    if (event_name2nr(p, &p) == event) {
      return true;
    }
  }

  return false;
}

// Return OK when the contents of p_ei is valid, FAIL otherwise.
int check_ei(void)
{
  char *p = (char *)p_ei;

  while (*p) {
    if (STRNICMP(p, "all", 3) == 0 && (p[3] == NUL || p[3] == ',')) {
      p += 3;
      if (*p == ',') {
        p++;
      }
    } else if (event_name2nr(p, &p) == NUM_EVENTS) {
      return FAIL;
    }
  }

  return OK;
}

// Add "what" to 'eventignore' to skip loading syntax highlighting for every
// buffer loaded into the window.  "what" must start with a comma.
// Returns the old value of 'eventignore' in allocated memory.
char *au_event_disable(char *what)
{
  char *save_ei = (char *)vim_strsave(p_ei);
  char *new_ei = (char *)vim_strnsave(p_ei, STRLEN(p_ei) + STRLEN(what));
  if (*what == ',' && *p_ei == NUL) {
    STRCPY(new_ei, what + 1);
  } else {
    STRCAT(new_ei, what);
  }
  set_string_option_direct("ei", -1, (char_u *)new_ei, OPT_FREE, SID_NONE);
  xfree(new_ei);

  return save_ei;
}

void au_event_restore(char *old_ei)
{
  if (old_ei != NULL) {
    set_string_option_direct("ei", -1, (char_u *)old_ei, OPT_FREE, SID_NONE);
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
void do_autocmd(char *arg_in, int forceit)
{
  char *arg = arg_in;
  char *envpat = NULL;
  char *cmd;
  int need_free = false;
  bool nested = false;
  bool once = false;
  int group;

  if (*arg == '|') {
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
      if (*cmd != NUL) {
        invalid_flags |= arg_autocmd_flag_get(&once, &cmd, "++once", 6);
        invalid_flags |= arg_autocmd_flag_get(&nested, &cmd, "++nested", 8);

        // Check the deprecated "nested" flag.
        invalid_flags |= arg_autocmd_flag_get(&nested, &cmd, "nested", 6);
      }
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

  bool is_showing = !forceit && *cmd == NUL;

  // Print header when showing autocommands.
  if (is_showing) {
    // Highlight title
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
      if (!forceit && *cmd != NUL) {
        emsg(_(e_cannot_define_autocommands_for_all_events));
      } else {
        do_all_autocmd_events(pat, once, nested, cmd, forceit, group);
      }
    } else {
      while (*arg && *arg != '|' && !ascii_iswhite(*arg)) {
        event_T event = event_name2nr(arg, &arg);
        assert(event < NUM_EVENTS);
        if (do_autocmd_event(event, pat, once, nested, cmd, forceit, group)
            == FAIL) {
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

void do_all_autocmd_events(char *pat, bool once, int nested, char *cmd, bool delete, int group)
{
  FOR_ALL_AUEVENTS(event) {
    if (do_autocmd_event(event, pat, once, nested, cmd, delete, group)
        == FAIL) {
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
int do_autocmd_event(event_T event, char *pat, bool once, int nested, char *cmd, bool delete,
                     int group)
  FUNC_ATTR_NONNULL_ALL
{
  // Cannot be used to show all patterns. See au_show_for_event or au_show_for_all_events
  assert(*pat != NUL || delete);

  AutoPat *ap;
  AutoPat **prev_ap;
  int findgroup;
  int buflocal_nr;
  char buflocal_pat[BUFLOCAL_PAT_LEN];  // for "<buffer=X>"

  bool is_adding_cmd = *cmd != NUL;

  if (group == AUGROUP_ALL) {
    findgroup = current_augroup;
  } else {
    findgroup = group;
  }

  // Delete all aupat for an event.
  if (*pat == NUL && delete) {
    aupat_del_for_event_and_group(event, findgroup);
    return OK;
  }

  // Loop through all the specified patterns.
  int patlen = (int)aucmd_pattern_length(pat);
  while (patlen) {
    // detect special <buffer[=X]> buffer-local patterns
    int is_buflocal = aupat_is_buflocal(pat, patlen);

    if (is_buflocal) {
      buflocal_nr = aupat_get_buflocal_nr(pat, patlen);

      // normalize pat into standard "<buffer>#N" form
      aupat_normalize_buflocal_pat(buflocal_pat, pat, patlen, buflocal_nr);

      pat = buflocal_pat;
      patlen = (int)STRLEN(buflocal_pat);
    }

    if (delete) {
      assert(*pat != NUL);

      // Find AutoPat entries with this pattern.
      prev_ap = &first_autopat[(int)event];
      while ((ap = *prev_ap) != NULL) {
        if (ap->pat != NULL) {
          // Accept a pattern when:
          // - a group was specified and it's that group
          // - the length of the pattern matches
          // - the pattern matches.
          // For <buffer[=X]>, this condition works because we normalize
          // all buffer-local patterns.
          if (ap->group == findgroup
              && ap->patlen == patlen
              && STRNCMP(pat, ap->pat, patlen) == 0) {
            // Remove existing autocommands.
            // If adding any new autocmd's for this AutoPat, don't
            // delete the pattern from the autopat list, append to
            // this list.
            if (is_adding_cmd && ap->next == NULL) {
              aupat_remove_cmds(ap);
              break;
            }
            aupat_del(ap);
          }
        }
        prev_ap = &ap->next;
      }
    }

    if (is_adding_cmd) {
      AucmdExecutable exec = AUCMD_EXECUTABLE_INIT;
      exec.type = CALLABLE_EX;
      exec.callable.cmd = cmd;
      autocmd_register(0, event, pat, patlen, group, once, nested, NULL, exec);
    }

    pat = aucmd_next_pattern(pat, (size_t)patlen);
    patlen = (int)aucmd_pattern_length(pat);
  }

  au_cleanup();  // may really delete removed patterns/commands now
  return OK;
}

int autocmd_register(int64_t id, event_T event, char *pat, int patlen, int group, bool once,
                     bool nested, char *desc, AucmdExecutable aucmd)
{
  // 0 is not a valid group.
  assert(group != 0);

  AutoPat *ap;
  AutoPat **prev_ap;
  AutoCmd *ac;
  int findgroup;
  char buflocal_pat[BUFLOCAL_PAT_LEN];  // for "<buffer=X>"

  if (patlen > (int)STRLEN(pat)) {
    return FAIL;
  }

  if (group == AUGROUP_ALL) {
    findgroup = current_augroup;
  } else {
    findgroup = group;
  }

  // detect special <buffer[=X]> buffer-local patterns
  int is_buflocal = aupat_is_buflocal(pat, patlen);
  int buflocal_nr = 0;

  if (is_buflocal) {
    buflocal_nr = aupat_get_buflocal_nr(pat, patlen);

    // normalize pat into standard "<buffer>#N" form
    aupat_normalize_buflocal_pat(buflocal_pat, pat, patlen, buflocal_nr);

    pat = buflocal_pat;
    patlen = (int)STRLEN(buflocal_pat);
  }

  // always goes at or after the last one, so start at the end.
  if (last_autopat[(int)event] != NULL) {
    prev_ap = &last_autopat[(int)event];
  } else {
    prev_ap = &first_autopat[(int)event];
  }

  while ((ap = *prev_ap) != NULL) {
    if (ap->pat != NULL) {
      // Accept a pattern when:
      // - a group was specified and it's that group
      // - the length of the pattern matches
      // - the pattern matches.
      // For <buffer[=X]>, this condition works because we normalize
      // all buffer-local patterns.
      if (ap->group == findgroup
          && ap->patlen == patlen
          && STRNCMP(pat, ap->pat, patlen) == 0) {
        if (ap->next == NULL) {
          // Add autocmd to this autopat, if it's the last one.
          break;
        }
      }
    }
    prev_ap = &ap->next;
  }

  // If the pattern we want to add a command to does appear at the
  // end of the list (or not is not in the list at all), add the
  // pattern at the end of the list.
  if (ap == NULL) {
    // refuse to add buffer-local ap if buffer number is invalid
    if (is_buflocal
        && (buflocal_nr == 0 || buflist_findnr(buflocal_nr) == NULL)) {
      semsg(_("E680: <buffer=%d>: invalid buffer number "), buflocal_nr);
      return FAIL;
    }

    ap = xmalloc(sizeof(AutoPat));
    ap->pat = xstrnsave(pat, (size_t)patlen);
    ap->patlen = patlen;

    if (is_buflocal) {
      ap->buflocal_nr = buflocal_nr;
      ap->reg_prog = NULL;
    } else {
      char *reg_pat;

      ap->buflocal_nr = 0;
      reg_pat = file_pat_to_reg_pat(pat, pat + patlen, &ap->allow_dirs, true);
      if (reg_pat != NULL) {
        ap->reg_prog = vim_regcomp(reg_pat, RE_MAGIC);
      }
      xfree(reg_pat);
      if (reg_pat == NULL || ap->reg_prog == NULL) {
        xfree(ap->pat);
        xfree(ap);
        return FAIL;
      }
    }

    // need to initialize last_mode for the first ModeChanged autocmd
    if (event == EVENT_MODECHANGED && !has_event(EVENT_MODECHANGED)) {
      get_mode(last_mode);
    }

    // If the event is CursorMoved, update the last cursor position
    // position to avoid immediately triggering the autocommand
    if (event == EVENT_CURSORMOVED && !has_event(EVENT_CURSORMOVED)) {
      curwin->w_last_cursormoved = curwin->w_cursor;
    }

    // Initialize the fields checked by the WinScrolled trigger to
    // stop it from firing right after the first autocmd is defined.
    if (event == EVENT_WINSCROLLED && !has_event(EVENT_WINSCROLLED)) {
      curwin->w_last_topline = curwin->w_topline;
      curwin->w_last_leftcol = curwin->w_leftcol;
      curwin->w_last_width = curwin->w_width;
      curwin->w_last_height = curwin->w_height;
    }

    ap->cmds = NULL;
    *prev_ap = ap;
    last_autopat[(int)event] = ap;
    ap->next = NULL;
    if (group == AUGROUP_ALL) {
      ap->group = current_augroup;
    } else {
      ap->group = group;
    }
  }

  // Add the autocmd at the end of the AutoCmd list.
  AutoCmd **prev_ac = &(ap->cmds);
  while ((ac = *prev_ac) != NULL) {
    prev_ac = &ac->next;
  }

  ac = xmalloc(sizeof(AutoCmd));
  *prev_ac = ac;

  ac->id = id;
  ac->exec = aucmd_exec_copy(aucmd);
  ac->script_ctx = current_sctx;
  ac->script_ctx.sc_lnum += sourcing_lnum;
  nlua_set_sctx(&ac->script_ctx);
  ac->next = NULL;
  ac->once = once;
  ac->nested = nested;
  ac->desc = NULL;

  // TODO(tjdevries): What to do about :autocmd and where/how to show lua stuffs there.
  // perhaps: <lua>DESCRIPTION or similar
  if (desc != NULL) {
    ac->desc = xstrdup(desc);
  }

  return OK;
}

size_t aucmd_pattern_length(char *pat)
  FUNC_ATTR_PURE
{
  if (*pat == NUL) {
    return 0;
  }

  char *endpat;

  for (; *pat; pat = endpat + 1) {
    // Find end of the pattern.
    // Watch out for a comma in braces, like "*.\{obj,o\}".
    endpat = pat;
    // ignore single comma
    if (*endpat == ',') {
      continue;
    }
    int brace_level = 0;
    for (; *endpat && (*endpat != ',' || brace_level || endpat[-1] == '\\');
         endpat++) {
      if (*endpat == '{') {
        brace_level++;
      } else if (*endpat == '}') {
        brace_level--;
      }
    }

    return (size_t)(endpat - pat);
  }

  return STRLEN(pat);
}

char *aucmd_next_pattern(char *pat, size_t patlen)
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
    smsg(_("No matching autocommands: %s"), arg_start);
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
      do_modelines(curwin == aucmd_win ? OPT_NOWIN : 0);
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
    (void)do_doautocmd(arg, false, &did_aucmd);
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
  if (STRNCMP(*argp, "<nomodeline>", 12) == 0) {
    *argp = skipwhite(*argp + 12);
    return false;
  }
  return true;
}

/// Prepare for executing autocommands for (hidden) buffer `buf`.
/// If the current buffer is not in any visible window, put it in a temporary
/// floating window `aucmd_win`.
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

  // Allocate the `aucmd_win` dummy floating window.
  if (win == NULL && aucmd_win == NULL) {
    win_alloc_aucmd_win();
    need_append = false;
  }
  if (win == NULL && aucmd_win_used) {
    // Strange recursive autocommand, fall back to using the current
    // window.  Expect a few side effects...
    win = curwin;
  }

  aco->save_curwin_handle = curwin->handle;
  aco->save_curbuf = curbuf;
  aco->save_prevwin_handle = prevwin == NULL ? 0 : prevwin->handle;
  if (win != NULL) {
    // There is a window for "buf" in the current tab page, make it the
    // curwin.  This is preferred, it has the least side effects (esp. if
    // "buf" is curbuf).
    aco->use_aucmd_win = false;
    curwin = win;
  } else {
    // There is no window for "buf", use "aucmd_win".  To minimize the side
    // effects, insert it in the current tab page.
    // Anything related to a window (e.g., setting folds) may have
    // unexpected results.
    aco->use_aucmd_win = true;
    aucmd_win_used = true;
    aucmd_win->w_buffer = buf;
    aucmd_win->w_s = &buf->b_s;
    buf->b_nwindows++;
    win_init_empty(aucmd_win);  // set cursor and topline to safe values

    // Make sure w_localdir and globaldir are NULL to avoid a chdir() in
    // win_enter_ext().
    XFREE_CLEAR(aucmd_win->w_localdir);
    aco->globaldir = globaldir;
    globaldir = NULL;

    block_autocmds();  // We don't want BufEnter/WinEnter autocommands.
    if (need_append) {
      win_append(lastwin, aucmd_win);
      pmap_put(handle_T)(&window_handles, aucmd_win->handle, aucmd_win);
      win_config_float(aucmd_win, aucmd_win->w_float_config);
    }
    // Prevent chdir() call in win_enter_ext(), through do_autochdir()
    int save_acd = p_acd;
    p_acd = false;
    // no redrawing and don't set the window title
    RedrawingDisabled++;
    win_enter(aucmd_win, false);
    RedrawingDisabled--;
    p_acd = save_acd;
    unblock_autocmds();
    curwin = aucmd_win;
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
  if (aco->use_aucmd_win) {
    curbuf->b_nwindows--;
    // Find "aucmd_win", it can't be closed, but it may be in another tab page.
    // Do not trigger autocommands here.
    block_autocmds();
    if (curwin != aucmd_win) {
      FOR_ALL_TAB_WINDOWS(tp, wp) {
        if (wp == aucmd_win) {
          if (tp != curtab) {
            goto_tabpage_tp(tp, true, true);
          }
          win_goto(aucmd_win);
          goto win_found;
        }
      }
    }
win_found:

    win_remove(curwin, NULL);
    pmap_del(handle_T)(&window_handles, curwin->handle);
    if (curwin->w_grid_alloc.chars != NULL) {
      ui_comp_remove_grid(&curwin->w_grid_alloc);
      ui_call_win_hide(curwin->w_grid_alloc.handle);
      grid_free(&curwin->w_grid_alloc);
    }

    aucmd_win_used = false;
    last_status(false);  // may need to remove last status line

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

    prevwin = win_find_by_handle(aco->save_prevwin_handle);
    vars_clear(&aucmd_win->w_vars->dv_hashtab);         // free all w: variables
    hash_init(&aucmd_win->w_vars->dv_hashtab);          // re-use the hashtab

    xfree(globaldir);
    globaldir = aco->globaldir;

    // the buffer contents may have changed
    check_cursor();
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
      check_cursor();
    }
  }

  check_cursor();  // just in case lines got deleted
  VIsual_active = aco->save_VIsual_active;
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

  bool did_cmd = apply_autocmds_group(event, fname, fname_io, force,
                                      AUGROUP_ALL, buf, NULL, NULL);
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
  return first_autopat[event] != NULL;
}

/// Return true when there is a CursorHold/CursorHoldI autocommand defined for
/// the current mode.
bool has_cursorhold(void) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return has_event((get_real_state() == MODE_NORMAL_BUSY ? EVENT_CURSORHOLD : EVENT_CURSORHOLDI));
  // return first_autopat[] != NULL;
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
  AutoPat *ap;
  char *save_cmdarg;
  long save_cmdbang;
  static int filechangeshell_busy = false;
  proftime_T wait_time;
  bool did_save_redobuff = false;
  save_redo_T save_redo;
  const bool save_KeyTyped = KeyTyped;  // NOLINT

  // Quickly return if there are no autocommands for this event or
  // autocommands are blocked.
  if (event == NUM_EVENTS || first_autopat[(int)event] == NULL
      || is_autocmd_blocked()) {
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
      && (event == EVENT_FILECHANGEDSHELL
          || event == EVENT_FILECHANGEDSHELLPOST)) {
    goto BYPASS_AU;
  }

  // Ignore events in 'eventignore'.
  if (event_ignored(event)) {
    goto BYPASS_AU;
  }

  // Allow nesting of autocommands, but restrict the depth, because it's
  // possible to create an endless loop.
  if (nesting == 10) {
    emsg(_("E218: autocommand nesting too deep"));
    goto BYPASS_AU;
  }

  // Check if these autocommands are disabled.  Used when doing ":all" or
  // ":ball".
  if ((autocmd_no_enter && (event == EVENT_WINENTER || event == EVENT_BUFENTER))
      || (autocmd_no_leave
          && (event == EVENT_WINLEAVE || event == EVENT_BUFLEAVE))) {
    goto BYPASS_AU;
  }

  // Save the autocmd_* variables and info about the current buffer.
  char *save_autocmd_fname = autocmd_fname;
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
      autocmd_fname = (char *)buf->b_ffname;
    } else {
      autocmd_fname = NULL;
    }
  } else {
    autocmd_fname = fname_io;
  }
  if (autocmd_fname != NULL) {
    // Allocate MAXPATHL for when eval_vars() resolves the fullpath.
    autocmd_fname = xstrnsave(autocmd_fname, MAXPATHL);
  }

  // Set the buffer number to be used for <abuf>.
  if (buf == NULL) {
    autocmd_bufnr = 0;
  } else {
    autocmd_bufnr = buf->b_fnum;
  }

  // When the file name is NULL or empty, use the file name of buffer "buf".
  // Always use the full path of the file name to match with, in case
  // "allow_dirs" is set.
  if (fname == NULL || *fname == NUL) {
    if (buf == NULL) {
      fname = NULL;
    } else {
      if (event == EVENT_SYNTAX) {
        fname = (char *)buf->b_p_syn;
      } else if (event == EVENT_FILETYPE) {
        fname = (char *)buf->b_p_ft;
      } else {
        if (buf->b_sfname != NULL) {
          sfname = (char *)vim_strsave(buf->b_sfname);
        }
        fname = (char *)buf->b_ffname;
      }
    }
    if (fname == NULL) {
      fname = "";
    }
    fname = xstrdup(fname);  // make a copy, so we can change it
  } else {
    sfname = xstrdup(fname);
    // Don't try expanding the following events.
    if (event == EVENT_CMDLINECHANGED || event == EVENT_CMDLINEENTER
        || event == EVENT_CMDLINELEAVE || event == EVENT_CMDWINENTER
        || event == EVENT_CMDWINLEAVE || event == EVENT_CMDUNDEFINED
        || event == EVENT_COLORSCHEME || event == EVENT_COLORSCHEMEPRE
        || event == EVENT_DIRCHANGED || event == EVENT_DIRCHANGEDPRE
        || event == EVENT_FILETYPE || event == EVENT_FUNCUNDEFINED
        || event == EVENT_MODECHANGED || event == EVENT_OPTIONSET
        || event == EVENT_QUICKFIXCMDPOST || event == EVENT_QUICKFIXCMDPRE
        || event == EVENT_REMOTEREPLY || event == EVENT_SPELLFILEMISSING
        || event == EVENT_SYNTAX || event == EVENT_SIGNAL
        || event == EVENT_TABCLOSED || event == EVENT_USER
        || event == EVENT_WINCLOSED || event == EVENT_WINSCROLLED) {
      fname = xstrdup(fname);
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
  char *save_sourcing_name = sourcing_name;
  sourcing_name = NULL;  // don't free this one
  linenr_T save_sourcing_lnum = sourcing_lnum;
  sourcing_lnum = 0;  // no line number here

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
    did_filetype = keep_filetype;
  }

  // Note that we are applying autocmds.  Some commands need to know.
  autocmd_busy = true;
  filechangeshell_busy = (event == EVENT_FILECHANGEDSHELL);
  nesting++;  // see matching decrement below

  // Remember that FileType was triggered.  Used for did_filetype().
  if (event == EVENT_FILETYPE) {
    did_filetype = true;
  }

  char *tail = path_tail(fname);

  // Find first autocommand that matches
  AutoPatCmd patcmd;
  patcmd.curpat = first_autopat[(int)event];
  patcmd.nextcmd = NULL;
  patcmd.group = group;
  patcmd.fname = fname;
  patcmd.sfname = sfname;
  patcmd.tail = tail;
  patcmd.event = event;
  patcmd.arg_bufnr = autocmd_bufnr;
  patcmd.next = NULL;
  auto_next_pat(&patcmd, false);

  // found one, start executing the autocommands
  if (patcmd.curpat != NULL) {
    // add to active_apc_list
    patcmd.next = active_apc_list;
    active_apc_list = &patcmd;

    // Attach data to command
    patcmd.data = data;

    // set v:cmdarg (only when there is a matching pattern)
    save_cmdbang = (long)get_vim_var_nr(VV_CMDBANG);
    if (eap != NULL) {
      save_cmdarg = set_cmdarg(eap, NULL);
      set_vim_var_nr(VV_CMDBANG, (long)eap->forceit);
    } else {
      save_cmdarg = NULL;  // avoid gcc warning
    }
    retval = true;
    // mark the last pattern, to avoid an endless loop when more patterns
    // are added when executing autocommands
    for (ap = patcmd.curpat; ap->next != NULL; ap = ap->next) {
      ap->last = false;
    }
    ap->last = true;

    if (nesting == 1) {
      // make sure cursor and topline are valid
      check_lnums(true);
    }

    // Execute the autocmd. The `getnextac` callback handles iteration.
    do_cmdline(NULL, getnextac, (void *)&patcmd,
               DOCMD_NOWAIT | DOCMD_VERBOSE | DOCMD_REPEAT);

    if (nesting == 1) {
      // restore cursor and topline, unless they were changed
      reset_lnums();
    }

    if (eap != NULL) {
      (void)set_cmdarg(NULL, save_cmdarg);
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
  xfree(sourcing_name);
  sourcing_name = save_sourcing_name;
  sourcing_lnum = save_sourcing_lnum;
  xfree(autocmd_fname);
  autocmd_fname = save_autocmd_fname;
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
    did_filetype = false;
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
    au_did_filetype = true;
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
  if (!is_autocmd_blocked()
      && get_vim_var_str(VV_TERMRESPONSE) != old_termresponse) {
    apply_autocmds(EVENT_TERMRESPONSE, NULL, NULL, false, curbuf);
  }
}

bool is_autocmd_blocked(void)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return autocmd_blocked != 0;
}

/// Find next autocommand pattern that matches.
/// stop when 'last' flag is set
void auto_next_pat(AutoPatCmd *apc, int stop_at_last)
{
  AutoPat *ap;
  AutoCmd *cp;
  char *s;

  XFREE_CLEAR(sourcing_name);

  for (ap = apc->curpat; ap != NULL && !got_int; ap = ap->next) {
    apc->curpat = NULL;

    // Only use a pattern when it has not been removed, has commands and
    // the group matches. For buffer-local autocommands only check the
    // buffer number.
    if (ap->pat != NULL && ap->cmds != NULL
        && (apc->group == AUGROUP_ALL || apc->group == ap->group)) {
      // execution-condition
      if (ap->buflocal_nr == 0
          ? match_file_pat(NULL,
                           &ap->reg_prog,
                           apc->fname,
                           apc->sfname,
                           apc->tail,
                           ap->allow_dirs)
          : ap->buflocal_nr == apc->arg_bufnr) {
        const char *const name = event_nr2name(apc->event);
        s = _("%s Autocommands for \"%s\"");

        const size_t sourcing_name_len
          = (STRLEN(s) + strlen(name) + (size_t)ap->patlen + 1);

        sourcing_name = xmalloc(sourcing_name_len);
        snprintf(sourcing_name, sourcing_name_len, s, name, ap->pat);
        if (p_verbose >= 8) {
          verbose_enter();
          smsg(_("Executing %s"), sourcing_name);
          verbose_leave();
        }

        apc->curpat = ap;
        apc->nextcmd = ap->cmds;
        // mark last command
        for (cp = ap->cmds; cp->next != NULL; cp = cp->next) {
          cp->last = false;
        }
        cp->last = true;
      }
      line_breakcheck();
      if (apc->curpat != NULL) {  // found a match
        break;
      }
    }
    if (stop_at_last && ap->last) {
      break;
    }
  }
}

static bool call_autocmd_callback(const AutoCmd *ac, const AutoPatCmd *apc)
{
  bool ret = false;
  Callback callback = ac->exec.callable.cb;
  if (callback.type == kCallbackLua) {
    Dictionary data = ARRAY_DICT_INIT;
    PUT(data, "id", INTEGER_OBJ(ac->id));
    PUT(data, "event", CSTR_TO_OBJ(event_nr2name(apc->event)));
    PUT(data, "match", CSTR_TO_OBJ((char *)autocmd_match));
    PUT(data, "file", CSTR_TO_OBJ((char *)autocmd_fname));
    PUT(data, "buf", INTEGER_OBJ(autocmd_bufnr));

    if (apc->data) {
      PUT(data, "data", copy_object(*apc->data));
    }

    int group = apc->curpat->group;
    switch (group) {
    case AUGROUP_ERROR:
      abort();  // unreachable
    case AUGROUP_DEFAULT:
    case AUGROUP_ALL:
    case AUGROUP_DELETED:
      // omit group in these cases
      break;
    default:
      PUT(data, "group", INTEGER_OBJ(group));
      break;
    }

    FIXED_TEMP_ARRAY(args, 1);
    args.items[0] = DICTIONARY_OBJ(data);

    Object result = nlua_call_ref(callback.data.luaref, NULL, args, true, NULL);
    if (result.type == kObjectTypeBoolean) {
      ret = result.data.boolean;
    }
    api_free_dictionary(data);
    api_free_object(result);
  } else {
    typval_T argsin = TV_INITIAL_VALUE;
    typval_T rettv = TV_INITIAL_VALUE;
    callback_call(&callback, 0, &argsin, &rettv);
  }

  return ret;
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

  AutoPatCmd *acp = (AutoPatCmd *)cookie;
  char *retval;

  // Can be called again after returning the last line.
  if (acp->curpat == NULL) {
    return NULL;
  }

  // repeat until we find an autocommand to execute
  for (;;) {
    // skip removed commands
    while (acp->nextcmd != NULL
           && aucmd_exec_is_deleted(acp->nextcmd->exec)) {
      if (acp->nextcmd->last) {
        acp->nextcmd = NULL;
      } else {
        acp->nextcmd = acp->nextcmd->next;
      }
    }

    if (acp->nextcmd != NULL) {
      break;
    }

    // at end of commands, find next pattern that matches
    if (acp->curpat->last) {
      acp->curpat = NULL;
    } else {
      acp->curpat = acp->curpat->next;
    }
    if (acp->curpat != NULL) {
      auto_next_pat(acp, true);
    }
    if (acp->curpat == NULL) {
      return NULL;
    }
  }

  AutoCmd *ac = acp->nextcmd;
  bool oneshot = ac->once;

  if (p_verbose >= 9) {
    verbose_enter_scroll();
    char *exec_to_string = aucmd_exec_to_string(ac, ac->exec);
    smsg(_("autocommand %s"), exec_to_string);
    msg_puts("\n");  // don't overwrite this either
    XFREE_CLEAR(exec_to_string);
    verbose_leave_scroll();
  }

  // Make sure to set autocmd_nested before executing
  // lua code, so that it works properly
  autocmd_nested = ac->nested;
  current_sctx = ac->script_ctx;

  if (ac->exec.type == CALLABLE_CB) {
    if (call_autocmd_callback(ac, acp)) {
      // If an autocommand callback returns true, delete the autocommand
      oneshot = true;
    }

    // TODO(tjdevries):
    //
    // Major Hack Alert:
    //  We just return "not-null" and continue going.
    //  This would be a good candidate for a refactor. You would need to refactor:
    //      1. do_cmdline to accept something besides a string
    //      OR
    //      2. make where we call do_cmdline for autocmds not have to return anything,
    //      and instead we loop over all the matches and just execute one-by-one.
    //          However, my expectation would be that could be expensive.
    retval = xstrdup("");
  } else {
    retval = xstrdup(ac->exec.callable.cmd);
  }

  // Remove one-shot ("once") autocmd in anticipation of its execution.
  if (oneshot) {
    aucmd_del(ac);
  }
  if (ac->last) {
    acp->nextcmd = NULL;
  } else {
    acp->nextcmd = ac->next;
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
  sfname = vim_strsave(sfname);
  forward_slash(sfname);
  forward_slash(fname);
#endif

  for (AutoPat *ap = first_autopat[(int)event]; ap != NULL; ap = ap->next) {
    if (ap->pat != NULL && ap->cmds != NULL
        && (ap->buflocal_nr == 0
            ? match_file_pat(NULL,
                             &ap->reg_prog,
                             fname,
                             sfname,
                             tail,
                             ap->allow_dirs)
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

// Function given to ExpandGeneric() to obtain the list of autocommand group
// names.
char *expand_get_augroup_name(expand_T *xp, int idx)
{
  // Required for ExpandGeneric
  (void)xp;

  return augroup_name(idx + 1);
}

/// @param doautocmd  true for :doauto*, false for :autocmd
char *set_context_in_autocmd(expand_T *xp, char *arg, int doautocmd)
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

// Function given to ExpandGeneric() to obtain the list of event names.
char *expand_get_event_name(expand_T *xp, int idx)
{
  // xp is a required parameter to be used with ExpandGeneric
  (void)xp;

  // List group names
  char *name = augroup_name(idx + 1);
  if (name != NULL) {
    // skip when not including groups or skip deleted entries
    if (!autocmd_include_groups || name == get_deleted_augroup()) {
      return "";
    }

    return name;
  }

  // List event names
  return event_names[idx - next_augroup_id].name;
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
bool au_exists(const char *const arg) FUNC_ATTR_WARN_UNUSED_RESULT
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
  AutoPat *ap = first_autopat[(int)event];
  if (ap == NULL) {
    goto theend;
  }

  // if pattern is "<buffer>", special handling is needed which uses curbuf
  // for pattern "<buffer=N>, FNAMECMP() will work fine
  if (pattern != NULL && STRICMP(pattern, "<buffer>") == 0) {
    buflocal_buf = curbuf;
  }

  // Check if there is an autocommand with the given pattern.
  for (; ap != NULL; ap = ap->next) {
    // only use a pattern when it has not been removed and has commands.
    // For buffer-local autocommands, FNAMECMP() works fine.
    if (ap->pat != NULL && ap->cmds != NULL
        && (group == AUGROUP_ALL || ap->group == group)
        && (pattern == NULL
            || (buflocal_buf == NULL
                ? FNAMECMP(ap->pat, pattern) == 0
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
bool aupat_is_buflocal(char *pat, int patlen)
  FUNC_ATTR_PURE
{
  return patlen >= 8
         && STRNCMP(pat, "<buffer", 7) == 0
         && (pat)[patlen - 1] == '>';
}

int aupat_get_buflocal_nr(char *pat, int patlen)
{
  assert(aupat_is_buflocal((char *)pat, patlen));

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
void aupat_normalize_buflocal_pat(char *dest, char *pat, int patlen, int buflocal_nr)
{
  assert(aupat_is_buflocal(pat, patlen));

  if (buflocal_nr == 0) {
    buflocal_nr = curbuf->handle;
  }

  // normalize pat into standard "<buffer>#N" form
  snprintf(dest,
           BUFLOCAL_PAT_LEN,
           "<buffer=%d>",
           buflocal_nr);
}

int autocmd_delete_event(int group, event_T event, char *pat)
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
    FOR_ALL_AUPATS_IN_EVENT(event, ap) {  // -V756
      for (AutoCmd *ac = ap->cmds; ac != NULL; ac = ac->next) {
        if (ac->id == id) {
          aucmd_del(ac);
          success = true;
        }
      }
    }
  }
  return success;
}

// ===========================================================================
//  AucmdExecutable Functions
// ===========================================================================

/// Generate a string description of a callback
static char *aucmd_callback_to_string(Callback cb)
{
  // NOTE: this function probably belongs in a helper

  size_t msglen = 100;
  char *msg = (char *)xmallocz(msglen);

  switch (cb.type) {
  case kCallbackLua:
    snprintf(msg, msglen, "<lua: %d>", cb.data.luaref);
    break;
  case kCallbackFuncref:
    // TODO(tjdevries): Is this enough space for this?
    snprintf(msg, msglen, "<vim function: %s>", cb.data.funcref);
    break;
  case kCallbackPartial:
    snprintf(msg, msglen, "<vim partial: %s>", cb.data.partial->pt_name);
    break;
  default:
    snprintf(msg, msglen, "%s", "");
    break;
  }
  return msg;
}

/// Generate a string description for the command/callback of an autocmd
char *aucmd_exec_to_string(AutoCmd *ac, AucmdExecutable acc)
  FUNC_ATTR_PURE
{
  switch (acc.type) {
  case CALLABLE_EX:
    return xstrdup(acc.callable.cmd);
  case CALLABLE_CB:
    return aucmd_callback_to_string(acc.callable.cb);
  case CALLABLE_NONE:
    return "This is not possible";
  }

  abort();
}

void aucmd_exec_free(AucmdExecutable *acc)
{
  switch (acc->type) {
  case CALLABLE_EX:
    XFREE_CLEAR(acc->callable.cmd);
    break;
  case CALLABLE_CB:
    callback_free(&acc->callable.cb);
    break;
  case CALLABLE_NONE:
    return;
  }

  acc->type = CALLABLE_NONE;
}

AucmdExecutable aucmd_exec_copy(AucmdExecutable src)
{
  AucmdExecutable dest = AUCMD_EXECUTABLE_INIT;

  switch (src.type) {
  case CALLABLE_EX:
    dest.type = CALLABLE_EX;
    dest.callable.cmd = xstrdup(src.callable.cmd);
    return dest;
  case CALLABLE_CB:
    dest.type = CALLABLE_CB;
    callback_copy(&dest.callable.cb, &src.callable.cb);
    return dest;
  case CALLABLE_NONE:
    return dest;
  }

  abort();
}

bool aucmd_exec_is_deleted(AucmdExecutable acc)
  FUNC_ATTR_PURE
{
  switch (acc.type) {
  case CALLABLE_EX:
    return acc.callable.cmd == NULL;
  case CALLABLE_CB:
    return acc.callable.cb.type == kCallbackNone;
  case CALLABLE_NONE:
    return true;
  }

  abort();
}

bool au_event_is_empty(event_T event)
  FUNC_ATTR_PURE
{
  return first_autopat[event] == NULL;
}

// Arg Parsing Functions

/// Scan over the events.  "*" stands for all events.
/// true when group name was found
static char *arg_event_skip(char *arg, int have_group)
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
  int group = AUGROUP_ALL;

  for (p = arg; *p && !ascii_iswhite(*p) && *p != '|'; p++) {}
  if (p > arg) {
    char *group_name = xstrnsave(arg, (size_t)(p - arg));
    group = augroup_find(group_name);
    if (group == AUGROUP_ERROR) {
      group = AUGROUP_ALL;  // no match, use all groups
    } else {
      *argp = skipwhite(p);  // match, skip over group name
    }
    xfree(group_name);
  }
  return group;
}

/// Handles grabbing arguments from `:autocmd` such as ++once and ++nested
static bool arg_autocmd_flag_get(bool *flag, char **cmd_ptr, char *pattern, int len)
{
  if (STRNCMP(*cmd_ptr, pattern, len) == 0 && ascii_iswhite((*cmd_ptr)[len])) {
    if (*flag) {
      semsg(_(e_duparg2), pattern);
      return true;
    }

    *flag = true;
    *cmd_ptr = skipwhite(*cmd_ptr + len);
  }

  return false;
}

// UI Enter
void do_autocmd_uienter(uint64_t chanid, bool attached)
{
  static bool recursive = false;

  if (recursive) {
    return;  // disallow recursion
  }
  recursive = true;

  save_v_event_T save_v_event;
  dict_T *dict = get_v_event(&save_v_event);
  assert(chanid < VARNUMBER_MAX);
  tv_dict_add_nr(dict, S_LEN("chan"), (varnumber_T)chanid);
  tv_dict_set_keys_readonly(dict);
  apply_autocmds(attached ? EVENT_UIENTER : EVENT_UILEAVE,
                 NULL, NULL, false, curbuf);
  restore_v_event(dict, &save_v_event);

  recursive = false;
}

// FocusGained

static void focusgained_event(void **argv)
{
  bool *gainedp = argv[0];
  do_autocmd_focusgained(*gainedp);
  xfree(gainedp);
}

void autocmd_schedule_focusgained(bool gained)
{
  bool *gainedp = xmalloc(sizeof(*gainedp));
  *gainedp = gained;
  loop_schedule_deferred(&main_loop,
                         event_create(focusgained_event, 1, gainedp));
}

static void do_autocmd_focusgained(bool gained)
{
  static bool recursive = false;
  static Timestamp last_time = (time_t)0;
  bool need_redraw = false;

  if (recursive) {
    return;  // disallow recursion
  }
  recursive = true;
  need_redraw |= apply_autocmds((gained ? EVENT_FOCUSGAINED : EVENT_FOCUSLOST),
                                NULL, NULL, false, curbuf);

  // When activated: Check if any file was modified outside of Vim.
  // Only do this when not done within the last two seconds as:
  // 1. Some filesystems have modification time granularity in seconds. Fat32
  //    has a granularity of 2 seconds.
  // 2. We could get multiple notifications in a row.
  if (gained && last_time + (Timestamp)2000 < os_now()) {
    need_redraw = check_timestamps(true);
    last_time = os_now();
  }

  if (need_redraw) {
    // Something was executed, make sure the cursor is put back where it
    // belongs.
    need_wait_return = false;

    if (State & MODE_CMDLINE) {
      redrawcmdline();
    } else if ((State & MODE_NORMAL) || (State & MODE_INSERT)) {
      if (must_redraw != 0) {
        update_screen(0);
      }

      setcursor();
    }

    ui_flush();
  }

  if (need_maketitle) {
    maketitle();
  }

  recursive = false;
}

// initialization

void init_default_autocmds(void)
{
  // open terminals when opening files that start with term://
#define PROTO "term://"
  do_cmdline_cmd("augroup nvim_terminal");
  do_cmdline_cmd("autocmd BufReadCmd " PROTO "* ++nested "
                 "if !exists('b:term_title')|call termopen("
                 // Capture the command string
                 "matchstr(expand(\"<amatch>\"), "
                 "'\\c\\m" PROTO "\\%(.\\{-}//\\%(\\d\\+:\\)\\?\\)\\?\\zs.*'), "
                 // capture the working directory
                 "{'cwd': expand(get(matchlist(expand(\"<amatch>\"), "
                 "'\\c\\m" PROTO "\\(.\\{-}\\)//'), 1, ''))})"
                 "|endif");
  do_cmdline_cmd("augroup END");
#undef PROTO

  // limit syntax synchronization in the command window
  do_cmdline_cmd("augroup nvim_cmdwin");
  do_cmdline_cmd("autocmd! CmdwinEnter [:>] syntax sync minlines=1 maxlines=1");
  do_cmdline_cmd("augroup END");
}
