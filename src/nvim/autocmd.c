// This is an open source non-commercial project. Dear PVS-Studio, please check
// it. PVS-Studio Static Code Analyzer for C, C++ and C#: http://www.viva64.com

// autocmd.c: Autocommand related functions

#include "nvim/autocmd.h"

#include "nvim/api/private/handle.h"
#include "nvim/ascii.h"
#include "nvim/buffer.h"
#include "nvim/charset.h"
#include "nvim/cursor.h"
#include "nvim/edit.h"
#include "nvim/eval.h"
#include "nvim/eval/userfunc.h"
#include "nvim/ex_docmd.h"
#include "nvim/fileio.h"
#include "nvim/getchar.h"
#include "nvim/misc1.h"
#include "nvim/option.h"
#include "nvim/regexp.h"
#include "nvim/search.h"
#include "nvim/state.h"
#include "nvim/ui_compositor.h"
#include "nvim/vim.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
#include "auevents_name_map.generated.h"
#include "autocmd.c.generated.h"
#endif

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

/// List of autocmd group names
static garray_T augroups = { 0, 0, sizeof(char_u *), 10, NULL };
#define AUGROUP_NAME(i) (((char **)augroups.ga_data)[i])
#define BUFLOCAL_PAT_LEN 25

// use get_deleted_augroup() to get this
static const char *deleted_augroup = NULL;

// The ID of the current group.  Group 0 is the default one.
static int current_augroup = AUGROUP_DEFAULT;

static int au_need_clean = false;  // need to delete marked patterns

static event_T last_event;
static int last_group;
static int autocmd_blocked = 0;  // block all autocmds

static bool autocmd_nested = false;
static bool autocmd_include_groups = false;

static char_u *old_termresponse = NULL;

static inline const char *get_deleted_augroup(void) FUNC_ATTR_ALWAYS_INLINE
{
  if (deleted_augroup == NULL) {
    deleted_augroup = _("--Deleted--");
  }
  return deleted_augroup;
}

// Show the autocommands for one AutoPat.
static void show_autocmd(AutoPat *ap, event_T event)
{
  AutoCmd *ac;

  // Check for "got_int" (here and at various places below), which is set
  // when "q" has been hit for the "--more--" prompt
  if (got_int) {
    return;
  }
  // pattern has been removed
  if (ap->pat == NULL) {
    return;
  }

  msg_putchar('\n');
  if (got_int) {
    return;
  }
  if (event != last_event || ap->group != last_group) {
    if (ap->group != AUGROUP_DEFAULT) {
      if (AUGROUP_NAME(ap->group) == NULL) {
        msg_puts_attr(get_deleted_augroup(), HL_ATTR(HLF_E));
      } else {
        msg_puts_attr(AUGROUP_NAME(ap->group), HL_ATTR(HLF_T));
      }
      msg_puts("  ");
    }
    msg_puts_attr(event_nr2name(event), HL_ATTR(HLF_T));
    last_event = event;
    last_group = ap->group;
    msg_putchar('\n');
    if (got_int) {
      return;
    }
  }
  msg_col = 4;
  msg_outtrans(ap->pat);

  for (ac = ap->cmds; ac != NULL; ac = ac->next) {
    if (ac->cmd == NULL) {  // skip removed commands
      continue;
    }
    if (msg_col >= 14) {
      msg_putchar('\n');
    }
    msg_col = 14;
    if (got_int) {
      return;
    }
    msg_outtrans(ac->cmd);
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

// Mark an autocommand handler for deletion.
static void au_remove_pat(AutoPat *ap)
{
  XFREE_CLEAR(ap->pat);
  ap->buflocal_nr = -1;
  au_need_clean = true;
}

// Mark all commands for a pattern for deletion.
static void au_remove_cmds(AutoPat *ap)
{
  for (AutoCmd *ac = ap->cmds; ac != NULL; ac = ac->next) {
    XFREE_CLEAR(ac->cmd);
  }
  au_need_clean = true;
}

// Delete one command from an autocmd pattern.
static void au_del_cmd(AutoCmd *ac)
{
  XFREE_CLEAR(ac->cmd);
  au_need_clean = true;
}

/// Cleanup autocommands and patterns that have been deleted.
/// This is only done when not executing autocommands.
static void au_cleanup(void)
{
  AutoPat *ap, **prev_ap;
  event_T event;

  if (autocmd_busy || !au_need_clean) {
    return;
  }

  // Loop over all events.
  for (event = (event_T)0; (int)event < (int)NUM_EVENTS;
       event = (event_T)((int)event + 1)) {
    // Loop over all autocommand patterns.
    prev_ap = &(first_autopat[(int)event]);
    for (ap = *prev_ap; ap != NULL; ap = *prev_ap) {
      bool has_cmd = false;

      // Loop over all commands for this pattern.
      AutoCmd **prev_ac = &(ap->cmds);
      for (AutoCmd *ac = *prev_ac; ac != NULL; ac = *prev_ac) {
        // Remove the command if the pattern is to be deleted or when
        // the command has been marked for deletion.
        if (ap->pat == NULL || ac->cmd == NULL) {
          *prev_ac = ac->next;
          xfree(ac->cmd);
          xfree(ac);
        } else {
          has_cmd = true;
          prev_ac = &(ac->next);
        }
      }

      if (ap->pat != NULL && !has_cmd) {
        // Pattern was not marked for deletion, but all of its commands were.
        // So mark the pattern for deletion.
        au_remove_pat(ap);
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

// Called when buffer is freed, to remove/invalidate related buffer-local
// autocmds.
void aubuflocal_remove(buf_T *buf)
{
  AutoPat *ap;
  event_T event;
  AutoPatCmd *apc;

  // invalidate currently executing autocommands
  for (apc = active_apc_list; apc; apc = apc->next) {
    if (buf->b_fnum == apc->arg_bufnr) {
      apc->arg_bufnr = 0;
    }
  }

  // invalidate buflocals looping through events
  for (event = (event_T)0; (int)event < (int)NUM_EVENTS;
       event = (event_T)((int)event + 1)) {
    // loop over all autocommand patterns
    for (ap = first_autopat[(int)event]; ap != NULL; ap = ap->next) {
      if (ap->buflocal_nr == buf->b_fnum) {
        au_remove_pat(ap);
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

// Add an autocmd group name.
// Return its ID.  Returns AUGROUP_ERROR (< 0) for error.
static int au_new_group(char_u *name)
{
  int i = au_find_group(name);
  if (i == AUGROUP_ERROR) {  // the group doesn't exist yet, add it.
    // First try using a free entry.
    for (i = 0; i < augroups.ga_len; i++) {
      if (AUGROUP_NAME(i) == NULL) {
        break;
      }
    }
    if (i == augroups.ga_len) {
      ga_grow(&augroups, 1);
    }

    AUGROUP_NAME(i) = xstrdup((char *)name);
    if (i == augroups.ga_len) {
      augroups.ga_len++;
    }
  }

  return i;
}

static void au_del_group(char_u *name)
{
  int i = au_find_group(name);
  if (i == AUGROUP_ERROR) {  // the group doesn't exist
    EMSG2(_("E367: No such group: \"%s\""), name);
  } else if (i == current_augroup) {
    EMSG(_("E936: Cannot delete the current group"));
  } else {
    event_T event;
    AutoPat *ap;
    int in_use = false;

    for (event = (event_T)0; (int)event < (int)NUM_EVENTS;
         event = (event_T)((int)event + 1)) {
      for (ap = first_autopat[(int)event]; ap != NULL; ap = ap->next) {
        if (ap->group == i && ap->pat != NULL) {
          give_warning(
              (char_u *)_("W19: Deleting augroup that is still in use"), true);
          in_use = true;
          event = NUM_EVENTS;
          break;
        }
      }
    }
    xfree(AUGROUP_NAME(i));
    if (in_use) {
      AUGROUP_NAME(i) = (char *)get_deleted_augroup();
    } else {
      AUGROUP_NAME(i) = NULL;
    }
  }
}

/// Find the ID of an autocmd group name.
///
/// @param name augroup name
///
/// @return the ID or AUGROUP_ERROR (< 0) for error.
static int au_find_group(const char_u *name)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  for (int i = 0; i < augroups.ga_len; i++) {
    if (AUGROUP_NAME(i) != NULL && AUGROUP_NAME(i) != get_deleted_augroup()
        && STRCMP(AUGROUP_NAME(i), name) == 0) {
      return i;
    }
  }
  return AUGROUP_ERROR;
}

/// Return true if augroup "name" exists.
///
/// @param name augroup name
bool au_has_group(const char_u *name)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  return au_find_group(name) != AUGROUP_ERROR;
}

/// ":augroup {name}".
void do_augroup(char_u *arg, int del_group)
{
  if (del_group) {
    if (*arg == NUL) {
      EMSG(_(e_argreq));
    } else {
      au_del_group(arg);
    }
  } else if (STRICMP(arg, "end") == 0) {  // ":aug end": back to group 0
    current_augroup = AUGROUP_DEFAULT;
  } else if (*arg) {  // ":aug xxx": switch to group xxx
    int i = au_new_group(arg);
    if (i != AUGROUP_ERROR) {
      current_augroup = i;
    }
  } else {  // ":aug": list the group names
    msg_start();
    for (int i = 0; i < augroups.ga_len; i++) {
      if (AUGROUP_NAME(i) != NULL) {
        msg_puts(AUGROUP_NAME(i));
        msg_puts("  ");
      }
    }
    msg_clr_eos();
    msg_end();
  }
}

#if defined(EXITFREE)
void free_all_autocmds(void)
{
  for (current_augroup = -1; current_augroup < augroups.ga_len;
       current_augroup++) {
    do_autocmd((char_u *)"", true);
  }

  for (int i = 0; i < augroups.ga_len; i++) {
    char *const s = ((char **)(augroups.ga_data))[i];
    if ((const char *)s != get_deleted_augroup()) {
      xfree(s);
    }
  }
  ga_clear(&augroups);
}
#endif

// Return the event number for event name "start".
// Return NUM_EVENTS if the event name was not found.
// Return a pointer to the next event name in "end".
static event_T event_name2nr(const char_u *start, char_u **end)
{
  const char_u *p;
  int i;
  int len;

  // the event name ends with end of line, '|', a blank or a comma
  for (p = start; *p && !ascii_iswhite(*p) && *p != ',' && *p != '|'; p++) {
  }
  for (i = 0; event_names[i].name != NULL; i++) {
    len = (int)event_names[i].len;
    if (len == p - start && STRNICMP(event_names[i].name, start, len) == 0) {
      break;
    }
  }
  if (*p == ',') {
    p++;
  }
  *end = (char_u *)p;
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
static const char *event_nr2name(event_T event)
  FUNC_ATTR_NONNULL_RET FUNC_ATTR_WARN_UNUSED_RESULT FUNC_ATTR_CONST
{
  int i;

  for (i = 0; event_names[i].name != NULL; i++) {
    if (event_names[i].event == event) {
      return event_names[i].name;
    }
  }
  return "Unknown";
}

/// Scan over the events.  "*" stands for all events.
/// true when group name was found
static char_u *find_end_event(char_u *arg, int have_group)
{
  char_u *pat;
  char_u *p;

  if (*arg == '*') {
    if (arg[1] && !ascii_iswhite(arg[1])) {
      EMSG2(_("E215: Illegal character after *: %s"), arg);
      return NULL;
    }
    pat = arg + 1;
  } else {
    for (pat = arg; *pat && *pat != '|' && !ascii_iswhite(*pat); pat = p) {
      if ((int)event_name2nr(pat, &p) >= (int)NUM_EVENTS) {
        if (have_group) {
          EMSG2(_("E216: No such event: %s"), pat);
        } else {
          EMSG2(_("E216: No such group or event: %s"), pat);
        }
        return NULL;
      }
    }
  }
  return pat;
}

/// Return true if "event" is included in 'eventignore'.
///
/// @param event event to check
static bool event_ignored(event_T event)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  char_u *p = p_ei;

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
  char_u *p = p_ei;

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
char_u *au_event_disable(char *what)
{
  char_u *new_ei;
  char_u *save_ei;

  save_ei = vim_strsave(p_ei);
  new_ei = vim_strnsave(p_ei, STRLEN(p_ei) + STRLEN(what));
  if (*what == ',' && *p_ei == NUL) {
    STRCPY(new_ei, what + 1);
  } else {
    STRCAT(new_ei, what);
  }
  set_string_option_direct("ei", -1, new_ei, OPT_FREE, SID_NONE);
  xfree(new_ei);

  return save_ei;
}

void au_event_restore(char_u *old_ei)
{
  if (old_ei != NULL) {
    set_string_option_direct("ei", -1, old_ei, OPT_FREE, SID_NONE);
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
void do_autocmd(char_u *arg_in, int forceit)
{
  char_u *arg = arg_in;
  char_u *pat;
  char_u *envpat = NULL;
  char_u *cmd;
  int need_free = false;
  int nested = false;
  bool once = false;
  int group;

  if (*arg == '|') {
    arg = (char_u *)"";
    group = AUGROUP_ALL;  // no argument, use all groups
  } else {
    // Check for a legal group name.  If not, use AUGROUP_ALL.
    group = au_get_grouparg(&arg);
  }

  // Scan over the events.
  // If we find an illegal name, return here, don't do anything.
  pat = find_end_event(arg, group != AUGROUP_ALL);
  if (pat == NULL) {
    return;
  }

  pat = skipwhite(pat);
  if (*pat == '|') {
    pat = (char_u *)"";
    cmd = (char_u *)"";
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
    for (size_t i = 0; i < 2; i++) {
      if (*cmd != NUL) {
        // Check for "++once" flag.
        if (STRNCMP(cmd, "++once", 6) == 0 && ascii_iswhite(cmd[6])) {
          if (once) {
            EMSG2(_(e_duparg2), "++once");
          }
          once = true;
          cmd = skipwhite(cmd + 6);
        }

        // Check for "++nested" flag.
        if ((STRNCMP(cmd, "++nested", 8) == 0 && ascii_iswhite(cmd[8]))) {
          if (nested) {
            EMSG2(_(e_duparg2), "++nested");
          }
          nested = true;
          cmd = skipwhite(cmd + 8);
        }

        // Check for the old (deprecated) "nested" flag.
        if (STRNCMP(cmd, "nested", 6) == 0 && ascii_iswhite(cmd[6])) {
          if (nested) {
            EMSG2(_(e_duparg2), "nested");
          }
          nested = true;
          cmd = skipwhite(cmd + 6);
        }
      }
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

  // Print header when showing autocommands.
  if (!forceit && *cmd == NUL) {
    // Highlight title
    MSG_PUTS_TITLE(_("\n--- Autocommands ---"));
  }

  // Loop over the events.
  last_event = (event_T)-1;    // for listing the event name
  last_group = AUGROUP_ERROR;  // for listing the group name
  if (*arg == '*' || *arg == NUL || *arg == '|') {
    if (!forceit && *cmd != NUL) {
      EMSG(_(e_cannot_define_autocommands_for_all_events));
    } else {
      for (event_T event = (event_T)0; event < (int)NUM_EVENTS;
           event = (event_T)(event + 1)) {
        if (do_autocmd_event(event, pat, once, nested, cmd, forceit, group)
            == FAIL) {
          break;
        }
      }
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

  if (need_free) {
    xfree(cmd);
  }
  xfree(envpat);
}

// Find the group ID in a ":autocmd" or ":doautocmd" argument.
// The "argp" argument is advanced to the following argument.
//
// Returns the group ID or AUGROUP_ALL.
static int au_get_grouparg(char_u **argp)
{
  char_u *group_name;
  char_u *p;
  char_u *arg = *argp;
  int group = AUGROUP_ALL;

  for (p = arg; *p && !ascii_iswhite(*p) && *p != '|'; p++) {
  }
  if (p > arg) {
    group_name = vim_strnsave(arg, (size_t)(p - arg));
    group = au_find_group(group_name);
    if (group == AUGROUP_ERROR) {
      group = AUGROUP_ALL;  // no match, use all groups
    } else {
      *argp = skipwhite(p);  // match, skip over group name
    }
    xfree(group_name);
  }
  return group;
}

// do_autocmd() for one event.
// Defines an autocmd (does not execute; cf. apply_autocmds_group).
//
// If *pat == NUL: do for all patterns.
// If *cmd == NUL: show entries.
// If forceit == true: delete entries.
// If group is not AUGROUP_ALL: only use this group.
static int do_autocmd_event(event_T event,
                            char_u *pat,
                            bool once,
                            int nested,
                            char_u *cmd,
                            int forceit,
                            int group)
{
  AutoPat *ap;
  AutoPat **prev_ap;
  AutoCmd *ac;
  AutoCmd **prev_ac;
  int brace_level;
  char_u *endpat;
  int findgroup;
  int allgroups;
  int patlen;
  int is_buflocal;
  int buflocal_nr;
  char_u buflocal_pat[BUFLOCAL_PAT_LEN];  // for "<buffer=X>"

  if (group == AUGROUP_ALL) {
    findgroup = current_augroup;
  } else {
    findgroup = group;
  }
  allgroups = (group == AUGROUP_ALL && !forceit && *cmd == NUL);

  // Show or delete all patterns for an event.
  if (*pat == NUL) {
    for (ap = first_autopat[event]; ap != NULL; ap = ap->next) {
      if (forceit) {  // delete the AutoPat, if it's in the current group
        if (ap->group == findgroup) {
          au_remove_pat(ap);
        }
      } else if (group == AUGROUP_ALL || ap->group == group) {
        show_autocmd(ap, event);
      }
    }
  }

  // Loop through all the specified patterns.
  for (; *pat; pat = (*endpat == ',' ? endpat + 1 : endpat)) {
    // Find end of the pattern.
    // Watch out for a comma in braces, like "*.\{obj,o\}".
    endpat = pat;
    // ignore single comma
    if (*endpat == ',') {
      continue;
    }
    brace_level = 0;
    for (; *endpat && (*endpat != ',' || brace_level || endpat[-1] == '\\');
         endpat++) {
      if (*endpat == '{') {
        brace_level++;
      } else if (*endpat == '}') {
        brace_level--;
      }
    }
    patlen = (int)(endpat - pat);

    // detect special <buflocal[=X]> buffer-local patterns
    is_buflocal = false;
    buflocal_nr = 0;

    if (patlen >= 8 && STRNCMP(pat, "<buffer", 7) == 0
        && pat[patlen - 1] == '>') {
      // "<buffer...>": Error will be printed only for addition.
      // printing and removing will proceed silently.
      is_buflocal = true;
      if (patlen == 8) {
        // "<buffer>"
        buflocal_nr = curbuf->b_fnum;
      } else if (patlen > 9 && pat[7] == '=') {
        if (patlen == 13 && STRNICMP(pat, "<buffer=abuf>", 13) == 0) {
          // "<buffer=abuf>"
          buflocal_nr = autocmd_bufnr;
        } else if (skipdigits(pat + 8) == pat + patlen - 1) {
          // "<buffer=123>"
          buflocal_nr = atoi((char *)pat + 8);
        }
      }
    }

    if (is_buflocal) {
      // normalize pat into standard "<buffer>#N" form
      snprintf(
          (char *)buflocal_pat,
          BUFLOCAL_PAT_LEN,
          "<buffer=%d>",
          buflocal_nr);

      pat = buflocal_pat;                  // can modify pat and patlen
      patlen = (int)STRLEN(buflocal_pat);  //   but not endpat
    }

    // Find AutoPat entries with this pattern.  When adding a command it
    // always goes at or after the last one, so start at the end.
    if (!forceit && *cmd != NUL && last_autopat[(int)event] != NULL) {
      prev_ap = &last_autopat[(int)event];
    } else {
      prev_ap = &first_autopat[(int)event];
    }
    while ((ap = *prev_ap) != NULL) {
      if (ap->pat != NULL) {
        // Accept a pattern when:
        // - a group was specified and it's that group, or a group was
        //   not specified and it's the current group, or a group was
        //   not specified and we are listing
        // - the length of the pattern matches
        // - the pattern matches.
        // For <buffer[=X]>, this condition works because we normalize
        // all buffer-local patterns.
        if ((allgroups || ap->group == findgroup) && ap->patlen == patlen
            && STRNCMP(pat, ap->pat, patlen) == 0) {
          // Remove existing autocommands.
          // If adding any new autocmd's for this AutoPat, don't
          // delete the pattern from the autopat list, append to
          // this list.
          if (forceit) {
            if (*cmd != NUL && ap->next == NULL) {
              au_remove_cmds(ap);
              break;
            }
            au_remove_pat(ap);
          } else if (*cmd == NUL) {
            // Show autocmd's for this autopat, or buflocals <buffer=X>
            show_autocmd(ap, event);

          } else if (ap->next == NULL) {
            // Add autocmd to this autopat, if it's the last one.
            break;
          }
        }
      }
      prev_ap = &ap->next;
    }

    // Add a new command.
    if (*cmd != NUL) {
      // If the pattern we want to add a command to does appear at the
      // end of the list (or not is not in the list at all), add the
      // pattern at the end of the list.
      if (ap == NULL) {
        // refuse to add buffer-local ap if buffer number is invalid
        if (is_buflocal
            && (buflocal_nr == 0 || buflist_findnr(buflocal_nr) == NULL)) {
          emsgf(_("E680: <buffer=%d>: invalid buffer number "), buflocal_nr);
          return FAIL;
        }

        ap = xmalloc(sizeof(AutoPat));
        ap->pat = vim_strnsave(pat, (size_t)patlen);
        ap->patlen = patlen;

        if (is_buflocal) {
          ap->buflocal_nr = buflocal_nr;
          ap->reg_prog = NULL;
        } else {
          char_u *reg_pat;

          ap->buflocal_nr = 0;
          reg_pat = file_pat_to_reg_pat(pat, endpat, &ap->allow_dirs, true);
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
      prev_ac = &(ap->cmds);
      while ((ac = *prev_ac) != NULL) {
        prev_ac = &ac->next;
      }
      ac = xmalloc(sizeof(AutoCmd));
      ac->cmd = vim_strsave(cmd);
      ac->script_ctx = current_sctx;
      ac->script_ctx.sc_lnum += sourcing_lnum;
      ac->next = NULL;
      *prev_ac = ac;
      ac->once = once;
      ac->nested = nested;
    }
  }

  au_cleanup();  // may really delete removed patterns/commands now
  return OK;
}

// Implementation of ":doautocmd [group] event [fname]".
// Return OK for success, FAIL for failure;
int do_doautocmd(char_u *arg,
                 bool do_msg,  // give message for no matching autocmds?
                 bool *did_something)
{
  char_u *fname;
  int nothing_done = true;
  int group;

  if (did_something != NULL) {
    *did_something = false;
  }

  // Check for a legal group name.  If not, use AUGROUP_ALL.
  group = au_get_grouparg(&arg);

  if (*arg == '*') {
    EMSG(_("E217: Can't execute autocommands for ALL events"));
    return FAIL;
  }

  // Scan over the events.
  // If we find an illegal name, return here, don't do anything.
  fname = find_end_event(arg, group != AUGROUP_ALL);
  if (fname == NULL) {
    return FAIL;
  }

  fname = skipwhite(fname);

  // Loop over the events.
  while (*arg && !ends_excmd(*arg) && !ascii_iswhite(*arg)) {
    if (apply_autocmds_group(event_name2nr(arg, &arg), fname, NULL, true, group,
                             curbuf, NULL)) {
      nothing_done = false;
    }
  }

  if (nothing_done && do_msg) {
    MSG(_("No matching autocommands"));
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
  char_u *arg = eap->arg;
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

  check_cursor();  // just in case lines got deleted
}

/// Check *argp for <nomodeline>.  When it is present return false, otherwise
/// return true and advance *argp to after it. Thus do_modelines() should be
/// called when true is returned.
///
/// @param[in,out] argp argument string
bool check_nomodeline(char_u **argp)
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
      handle_register_window(aucmd_win);
      win_config_float(aucmd_win, aucmd_win->w_float_config);
    }
    // Prevent chdir() call in win_enter_ext(), through do_autochdir()
    int save_acd = p_acd;
    p_acd = false;
    win_enter(aucmd_win, false);
    p_acd = save_acd;
    unblock_autocmds();
    curwin = aucmd_win;
  }
  curbuf = buf;
  aco->new_curwin_handle = curwin->handle;
  set_bufref(&aco->new_curbuf, curbuf);
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
    handle_unregister_window(curwin);
    if (curwin->w_grid.chars != NULL) {
      ui_comp_remove_grid(&curwin->w_grid);
      ui_call_win_hide(curwin->w_grid.handle);
      grid_free(&curwin->w_grid);
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
    prevwin = win_find_by_handle(aco->save_prevwin_handle);
    vars_clear(&aucmd_win->w_vars->dv_hashtab);         // free all w: variables
    hash_init(&aucmd_win->w_vars->dv_hashtab);          // re-use the hashtab
    curbuf = curwin->w_buffer;

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
bool apply_autocmds(event_T event,
                    char_u *fname,
                    char_u *fname_io,
                    bool force,
                    buf_T *buf)
{
  return apply_autocmds_group(event, fname, fname_io, force, AUGROUP_ALL, buf,
                              NULL);
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
bool apply_autocmds_exarg(event_T event,
                          char_u *fname,
                          char_u *fname_io,
                          bool force,
                          buf_T *buf,
                          exarg_T *eap)
{
  return apply_autocmds_group(event, fname, fname_io, force, AUGROUP_ALL, buf,
                              eap);
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
bool apply_autocmds_retval(event_T event,
                           char_u *fname,
                           char_u *fname_io,
                           bool force,
                           buf_T *buf,
                           int *retval)
{
  if (should_abort(*retval)) {
    return false;
  }

  bool did_cmd = apply_autocmds_group(event, fname, fname_io, force,
                                      AUGROUP_ALL, buf, NULL);
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
  return has_event(
      (get_real_state() == NORMAL_BUSY ? EVENT_CURSORHOLD : EVENT_CURSORHOLDI));
  // return first_autopat[] != NULL;
}

/// Return true if the CursorHold/CursorHoldI event can be triggered.
bool trigger_cursorhold(void) FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  int state;

  if (!did_cursorhold && has_cursorhold() && reg_recording == 0
      && typebuf.tb_len == 0 && !ins_compl_active()) {
    state = get_real_state();
    if (state == NORMAL_BUSY || (state & INSERT) != 0) {
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
static bool apply_autocmds_group(event_T event,
                                 char_u *fname,
                                 char_u *fname_io,
                                 bool force,
                                 int group,
                                 buf_T *buf,
                                 exarg_T *eap)
{
  char_u *sfname = NULL;  // short file name
  char_u *tail;
  bool save_changed;
  buf_T *old_curbuf;
  bool retval = false;
  char_u *save_sourcing_name;
  linenr_T save_sourcing_lnum;
  char_u *save_autocmd_fname;
  int save_autocmd_bufnr;
  char_u *save_autocmd_match;
  int save_autocmd_busy;
  int save_autocmd_nested;
  static int nesting = 0;
  AutoPatCmd patcmd;
  AutoPat *ap;
  char_u *save_cmdarg;
  long save_cmdbang;
  static int filechangeshell_busy = false;
  proftime_T wait_time;
  bool did_save_redobuff = false;
  save_redo_T save_redo;
  const bool save_KeyTyped = KeyTyped;

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
    EMSG(_("E218: autocommand nesting too deep"));
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
  save_autocmd_fname = autocmd_fname;
  save_autocmd_bufnr = autocmd_bufnr;
  save_autocmd_match = autocmd_match;
  save_autocmd_busy = autocmd_busy;
  save_autocmd_nested = autocmd_nested;
  save_changed = curbuf->b_changed;
  old_curbuf = curbuf;

  // Set the file name to be used for <afile>.
  // Make a copy to avoid that changing a buffer name or directory makes it
  // invalid.
  if (fname_io == NULL) {
    if (event == EVENT_COLORSCHEME || event == EVENT_COLORSCHEMEPRE
        || event == EVENT_OPTIONSET) {
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
  if (autocmd_fname != NULL) {
    // Allocate MAXPATHL for when eval_vars() resolves the fullpath.
    autocmd_fname = vim_strnsave(autocmd_fname, MAXPATHL);
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
        fname = buf->b_p_syn;
      } else if (event == EVENT_FILETYPE) {
        fname = buf->b_p_ft;
      } else {
        if (buf->b_sfname != NULL) {
          sfname = vim_strsave(buf->b_sfname);
        }
        fname = buf->b_ffname;
      }
    }
    if (fname == NULL) {
      fname = (char_u *)"";
    }
    fname = vim_strsave(fname);  // make a copy, so we can change it
  } else {
    sfname = vim_strsave(fname);
    // Don't try expanding the following events.
    if (event == EVENT_CMDLINECHANGED || event == EVENT_CMDLINEENTER
        || event == EVENT_CMDLINELEAVE || event == EVENT_CMDWINENTER
        || event == EVENT_CMDWINLEAVE || event == EVENT_CMDUNDEFINED
        || event == EVENT_COLORSCHEME || event == EVENT_COLORSCHEMEPRE
        || event == EVENT_DIRCHANGED || event == EVENT_FILETYPE
        || event == EVENT_FUNCUNDEFINED || event == EVENT_OPTIONSET
        || event == EVENT_QUICKFIXCMDPOST || event == EVENT_QUICKFIXCMDPRE
        || event == EVENT_REMOTEREPLY || event == EVENT_SPELLFILEMISSING
        || event == EVENT_SYNTAX || event == EVENT_SIGNAL
        || event == EVENT_TABCLOSED || event == EVENT_WINCLOSED) {
      fname = vim_strsave(fname);
    } else {
      fname = (char_u *)FullName_save((char *)fname, false);
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
  save_sourcing_name = sourcing_name;
  sourcing_name = NULL;  // don't free this one
  save_sourcing_lnum = sourcing_lnum;
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

  tail = path_tail(fname);

  // Find first autocommand that matches
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
    check_lnums(true);  // make sure cursor and topline are valid

    // Execute the autocmd. The `getnextac` callback handles iteration.
    do_cmdline(NULL, getnextac, (void *)&patcmd,
               DOCMD_NOWAIT | DOCMD_VERBOSE | DOCMD_REPEAT);

    reset_lnums();  // restore cursor and topline, unless they were changed

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
  if (is_autocmd_blocked()) {
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
  if (is_autocmd_blocked()
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
          ? match_file_pat(
              NULL,
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
        snprintf((char *)sourcing_name, sourcing_name_len, s, name,
                 (char *)ap->pat);
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

/// Get next autocommand command.
/// Called by do_cmdline() to get the next line for ":if".
/// @return allocated string, or NULL for end of autocommands.
char_u *getnextac(int c, void *cookie, int indent, bool do_concat)
{
  AutoPatCmd *acp = (AutoPatCmd *)cookie;
  char_u *retval;
  AutoCmd *ac;

  // Can be called again after returning the last line.
  if (acp->curpat == NULL) {
    return NULL;
  }

  // repeat until we find an autocommand to execute
  for (;;) {
    // skip removed commands
    while (acp->nextcmd != NULL && acp->nextcmd->cmd == NULL) {
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

  ac = acp->nextcmd;

  if (p_verbose >= 9) {
    verbose_enter_scroll();
    smsg(_("autocommand %s"), ac->cmd);
    msg_puts("\n");  // don't overwrite this either
    verbose_leave_scroll();
  }
  retval = vim_strsave(ac->cmd);
  // Remove one-shot ("once") autocmd in anticipation of its execution.
  if (ac->once) {
    au_del_cmd(ac);
  }
  autocmd_nested = ac->nested;
  current_sctx = ac->script_ctx;
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
bool has_autocmd(event_T event,
                 char_u *sfname,
                 buf_T *buf) FUNC_ATTR_WARN_UNUSED_RESULT
{
  AutoPat *ap;
  char_u *fname;
  char_u *tail = path_tail(sfname);
  bool retval = false;

  fname = (char_u *)FullName_save((char *)sfname, false);
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

  for (ap = first_autopat[(int)event]; ap != NULL; ap = ap->next) {
    if (ap->pat != NULL && ap->cmds != NULL
        && (ap->buflocal_nr == 0
            ? match_file_pat(
                NULL,
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
char_u *get_augroup_name(expand_T *xp, int idx)
{
  if (idx == augroups.ga_len) {  // add "END" add the end
    return (char_u *)"END";
  }
  if (idx >= augroups.ga_len) {  // end of list
    return NULL;
  }
  if (AUGROUP_NAME(idx) == NULL || AUGROUP_NAME(idx) == get_deleted_augroup()) {
    // skip deleted entries
    return (char_u *)"";
  }
  return (char_u *)AUGROUP_NAME(idx);
}

char_u *set_context_in_autocmd(
    expand_T *xp,
    char_u *arg,
    int doautocmd  // true for :doauto*, false for :autocmd
)
{
  char_u *p;
  int group;

  // check for a group name, skip it if present
  autocmd_include_groups = false;
  p = arg;
  group = au_get_grouparg(&arg);

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
char_u *get_event_name(expand_T *xp, int idx)
{
  if (idx < augroups.ga_len) {  // First list group names, if wanted
    if (!autocmd_include_groups || AUGROUP_NAME(idx) == NULL
        || AUGROUP_NAME(idx) == get_deleted_augroup()) {
      return (char_u *)"";  // skip deleted entries
    }
    return (char_u *)AUGROUP_NAME(idx);
  }
  return (char_u *)event_names[idx - augroups.ga_len].name;
}

/// Check whether given autocommand is supported
///
/// @param[in]  event  Event to check.
///
/// @return True if it is, false otherwise.
bool autocmd_supported(const char *const event)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  char_u *p;
  return event_name2nr((const char_u *)event, &p) != NUM_EVENTS;
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
  event_T event;
  AutoPat *ap;
  buf_T *buflocal_buf = NULL;
  int group;
  bool retval = false;

  // Make a copy so that we can change the '#' chars to a NUL.
  char *const arg_save = xstrdup(arg);
  char *p = strchr(arg_save, '#');
  if (p != NULL) {
    *p++ = NUL;
  }

  // First, look for an autocmd group name.
  group = au_find_group((char_u *)arg_save);
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
  event = event_name2nr((char_u *)event_name, (char_u **)&p);

  // return false if the event name is not recognized
  if (event == NUM_EVENTS) {
    goto theend;
  }

  // Find the first autocommand for this event.
  // If there isn't any, return false;
  // If there is one and no pattern given, return true;
  ap = first_autopat[(int)event];
  if (ap == NULL) {
    goto theend;
  }

  // if pattern is "<buffer>", special handling is needed which uses curbuf
  // for pattern "<buffer=N>, fnamecmp() will work fine
  if (pattern != NULL && STRICMP(pattern, "<buffer>") == 0) {
    buflocal_buf = curbuf;
  }

  // Check if there is an autocommand with the given pattern.
  for (; ap != NULL; ap = ap->next) {
    // only use a pattern when it has not been removed and has commands.
    // For buffer-local autocommands, fnamecmp() works fine.
    if (ap->pat != NULL && ap->cmds != NULL
        && (group == AUGROUP_ALL || ap->group == group)
        && (pattern == NULL
            || (buflocal_buf == NULL
                ? fnamecmp(ap->pat, (char_u *)pattern) == 0
                : ap->buflocal_nr == buflocal_buf->b_fnum))) {
      retval = true;
      break;
    }
  }

theend:
  xfree(arg_save);
  return retval;
}
