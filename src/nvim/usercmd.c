// usercmd.c: User defined command support

#include <assert.h>
#include <inttypes.h>
#include <lauxlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include "auto/config.h"
#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/charset.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/eval.h"
#include "nvim/ex_docmd.h"
#include "nvim/garray.h"
#include "nvim/gettext_defs.h"
#include "nvim/globals.h"
#include "nvim/highlight.h"
#include "nvim/highlight_defs.h"
#include "nvim/keycodes.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/mapping.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/menu.h"
#include "nvim/message.h"
#include "nvim/option_vars.h"
#include "nvim/os/input.h"
#include "nvim/runtime.h"
#include "nvim/strings.h"
#include "nvim/usercmd.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "usercmd.c.generated.h"
#endif

garray_T ucmds = { 0, 0, sizeof(ucmd_T), 4, NULL };

static const char e_argument_required_for_str[]
  = N_("E179: Argument required for %s");
static const char e_no_such_user_defined_command_str[]
  = N_("E184: No such user-defined command: %s");
static const char e_complete_used_without_allowing_arguments[]
  = N_("E1208: -complete used without allowing arguments");
static const char e_no_such_user_defined_command_in_current_buffer_str[]
  = N_("E1237: No such user-defined command in current buffer: %s");

/// List of names for completion for ":command" with the EXPAND_ flag.
/// Must be alphabetical for completion.
static const char *command_complete[] = {
  [EXPAND_ARGLIST] = "arglist",
  [EXPAND_AUGROUP] = "augroup",
  [EXPAND_BUFFERS] = "buffer",
  [EXPAND_CHECKHEALTH] = "checkhealth",
  [EXPAND_COLORS] = "color",
  [EXPAND_COMMANDS] = "command",
  [EXPAND_COMPILER] = "compiler",
  [EXPAND_USER_DEFINED] = "custom",
  [EXPAND_USER_LIST] = "customlist",
  [EXPAND_USER_LUA] = "<Lua function>",
  [EXPAND_DIFF_BUFFERS] = "diff_buffer",
  [EXPAND_DIRECTORIES] = "dir",
  [EXPAND_ENV_VARS] = "environment",
  [EXPAND_EVENTS] = "event",
  [EXPAND_EXPRESSION] = "expression",
  [EXPAND_FILES] = "file",
  [EXPAND_FILES_IN_PATH] = "file_in_path",
  [EXPAND_FILETYPE] = "filetype",
  [EXPAND_FUNCTIONS] = "function",
  [EXPAND_HELP] = "help",
  [EXPAND_HIGHLIGHT] = "highlight",
  [EXPAND_HISTORY] = "history",
  [EXPAND_KEYMAP] = "keymap",
#ifdef HAVE_WORKING_LIBINTL
  [EXPAND_LOCALES] = "locale",
#endif
  [EXPAND_LUA] = "lua",
  [EXPAND_MAPCLEAR] = "mapclear",
  [EXPAND_MAPPINGS] = "mapping",
  [EXPAND_MENUS] = "menu",
  [EXPAND_MESSAGES] = "messages",
  [EXPAND_OWNSYNTAX] = "syntax",
  [EXPAND_SYNTIME] = "syntime",
  [EXPAND_SETTINGS] = "option",
  [EXPAND_PACKADD] = "packadd",
  [EXPAND_RUNTIME] = "runtime",
  [EXPAND_SHELLCMD] = "shellcmd",
  [EXPAND_SHELLCMDLINE] = "shellcmdline",
  [EXPAND_SIGN] = "sign",
  [EXPAND_TAGS] = "tag",
  [EXPAND_TAGS_LISTFILES] = "tag_listfiles",
  [EXPAND_USER] = "user",
  [EXPAND_USER_VARS] = "var",
  [EXPAND_BREAKPOINT] = "breakpoint",
  [EXPAND_SCRIPTNAMES] = "scriptnames",
  [EXPAND_DIRS_IN_CDPATH] = "dir_in_path",
};

/// List of names of address types.  Must be alphabetical for completion.
static struct {
  cmd_addr_T expand;
  char *name;
  char *shortname;
} addr_type_complete[] = {
  { ADDR_ARGUMENTS, "arguments", "arg" },
  { ADDR_LINES, "lines", "line" },
  { ADDR_LOADED_BUFFERS, "loaded_buffers", "load" },
  { ADDR_TABS, "tabs", "tab" },
  { ADDR_BUFFERS, "buffers", "buf" },
  { ADDR_WINDOWS, "windows", "win" },
  { ADDR_QUICKFIX, "quickfix", "qf" },
  { ADDR_OTHER, "other", "?" },
  { ADDR_NONE, NULL, NULL }
};

/// Search for a user command that matches "eap->cmd".
/// Return cmdidx in "eap->cmdidx", flags in "eap->argt", idx in "eap->useridx".
/// Return a pointer to just after the command.
/// Return NULL if there is no matching command.
///
/// @param *p      end of the command (possibly including count)
/// @param full    set to true for a full match
/// @param xp      used for completion, NULL otherwise
/// @param complp  completion flags or NULL
char *find_ucmd(exarg_T *eap, char *p, int *full, expand_T *xp, int *complp)
{
  int len = (int)(p - eap->cmd);
  int matchlen = 0;
  bool found = false;
  bool possible = false;
  bool amb_local = false;            // Found ambiguous buffer-local command,
                                     // only full match global is accepted.

  // Look for buffer-local user commands first, then global ones.
  garray_T *gap = &prevwin_curwin()->w_buffer->b_ucmds;
  while (true) {
    int j;
    for (j = 0; j < gap->ga_len; j++) {
      ucmd_T *uc = USER_CMD_GA(gap, j);
      char *cp = eap->cmd;
      char *np = uc->uc_name;
      int k = 0;
      while (k < len && *np != NUL && *cp++ == *np++) {
        k++;
      }
      if (k == len || (*np == NUL && ascii_isdigit(eap->cmd[k]))) {
        // If finding a second match, the command is ambiguous.  But
        // not if a buffer-local command wasn't a full match and a
        // global command is a full match.
        if (k == len && found && *np != NUL) {
          if (gap == &ucmds) {
            return NULL;
          }
          amb_local = true;
        }

        if (!found || (k == len && *np == NUL)) {
          // If we matched up to a digit, then there could
          // be another command including the digit that we
          // should use instead.
          if (k == len) {
            found = true;
          } else {
            possible = true;
          }

          if (gap == &ucmds) {
            eap->cmdidx = CMD_USER;
          } else {
            eap->cmdidx = CMD_USER_BUF;
          }
          eap->argt = uc->uc_argt;
          eap->useridx = j;
          eap->addr_type = uc->uc_addr_type;

          if (complp != NULL) {
            *complp = uc->uc_compl;
          }
          if (xp != NULL) {
            xp->xp_luaref = uc->uc_compl_luaref;
            xp->xp_arg = uc->uc_compl_arg;
            xp->xp_script_ctx = uc->uc_script_ctx;
            xp->xp_script_ctx.sc_lnum += SOURCING_LNUM;
          }
          // Do not search for further abbreviations
          // if this is an exact match.
          matchlen = k;
          if (k == len && *np == NUL) {
            if (full != NULL) {
              *full = true;
            }
            amb_local = false;
            break;
          }
        }
      }
    }

    // Stop if we found a full match or searched all.
    if (j < gap->ga_len || gap == &ucmds) {
      break;
    }
    gap = &ucmds;
  }

  // Only found ambiguous matches.
  if (amb_local) {
    if (xp != NULL) {
      xp->xp_context = EXPAND_UNSUCCESSFUL;
    }
    return NULL;
  }

  // The match we found may be followed immediately by a number.  Move "p"
  // back to point to it.
  if (found || possible) {
    return p + (matchlen - len);
  }
  return p;
}

/// Set completion context for :command
const char *set_context_in_user_cmd(expand_T *xp, const char *arg_in)
{
  const char *arg = arg_in;
  const char *p;

  // Check for attributes
  while (*arg == '-') {
    arg++;  // Skip "-".
    p = skiptowhite(arg);
    if (*p == NUL) {
      // Cursor is still in the attribute.
      p = strchr(arg, '=');
      if (p == NULL) {
        // No "=", so complete attribute names.
        xp->xp_context = EXPAND_USER_CMD_FLAGS;
        xp->xp_pattern = (char *)arg;
        return NULL;
      }

      // For the -complete, -nargs and -addr attributes, we complete
      // their arguments as well.
      if (STRNICMP(arg, "complete", p - arg) == 0) {
        xp->xp_context = EXPAND_USER_COMPLETE;
        xp->xp_pattern = (char *)p + 1;
        return NULL;
      } else if (STRNICMP(arg, "nargs", p - arg) == 0) {
        xp->xp_context = EXPAND_USER_NARGS;
        xp->xp_pattern = (char *)p + 1;
        return NULL;
      } else if (STRNICMP(arg, "addr", p - arg) == 0) {
        xp->xp_context = EXPAND_USER_ADDR_TYPE;
        xp->xp_pattern = (char *)p + 1;
        return NULL;
      }
      return NULL;
    }
    arg = skipwhite(p);
  }

  // After the attributes comes the new command name.
  p = skiptowhite(arg);
  if (*p == NUL) {
    xp->xp_context = EXPAND_USER_COMMANDS;
    xp->xp_pattern = (char *)arg;
    return NULL;
  }

  // And finally comes a normal command.
  return skipwhite(p);
}

/// Set the completion context for the argument of a user defined command.
const char *set_context_in_user_cmdarg(const char *cmd FUNC_ATTR_UNUSED, const char *arg,
                                       uint32_t argt, int context, expand_T *xp, bool forceit)
{
  if (context == EXPAND_NOTHING) {
    return NULL;
  }

  if (argt & EX_XFILE) {
    // EX_XFILE: file names are handled before this call.
    return NULL;
  }

  if (context == EXPAND_MENUS) {
    return set_context_in_menu_cmd(xp, cmd, (char *)arg, forceit);
  }
  if (context == EXPAND_COMMANDS) {
    return arg;
  }
  if (context == EXPAND_MAPPINGS) {
    return set_context_in_map_cmd(xp, "map", (char *)arg, forceit, false, false,
                                  CMD_map);
  }
  // Find start of last argument.
  const char *p = arg;
  while (*p) {
    if (*p == ' ') {
      // argument starts after a space
      arg = p + 1;
    } else if (*p == '\\' && *(p + 1) != NUL) {
      p++;  // skip over escaped character
    }
    MB_PTR_ADV(p);
  }
  xp->xp_pattern = (char *)arg;
  xp->xp_context = context;

  return NULL;
}

char *expand_user_command_name(int idx)
{
  return get_user_commands(NULL, idx - CMD_SIZE);
}

/// Function given to ExpandGeneric() to obtain the list of user command names.
char *get_user_commands(expand_T *xp FUNC_ATTR_UNUSED, int idx)
  FUNC_ATTR_PURE FUNC_ATTR_WARN_UNUSED_RESULT
{
  // In cmdwin, the alternative buffer should be used.
  const buf_T *const buf = prevwin_curwin()->w_buffer;

  if (idx < buf->b_ucmds.ga_len) {
    return USER_CMD_GA(&buf->b_ucmds, idx)->uc_name;
  }

  idx -= buf->b_ucmds.ga_len;
  if (idx < ucmds.ga_len) {
    char *name = USER_CMD(idx)->uc_name;

    for (int i = 0; i < buf->b_ucmds.ga_len; i++) {
      if (strcmp(name, USER_CMD_GA(&buf->b_ucmds, i)->uc_name) == 0) {
        // global command is overruled by buffer-local one
        return "";
      }
    }
    return name;
  }
  return NULL;
}

/// Get the name of user command "idx".  "cmdidx" can be CMD_USER or
/// CMD_USER_BUF.
///
/// @return  NULL if the command is not found.
char *get_user_command_name(int idx, int cmdidx)
{
  if (cmdidx == CMD_USER && idx < ucmds.ga_len) {
    return USER_CMD(idx)->uc_name;
  }
  if (cmdidx == CMD_USER_BUF) {
    // In cmdwin, the alternative buffer should be used.
    const buf_T *const buf = prevwin_curwin()->w_buffer;

    if (idx < buf->b_ucmds.ga_len) {
      return USER_CMD_GA(&buf->b_ucmds, idx)->uc_name;
    }
  }
  return NULL;
}

/// Function given to ExpandGeneric() to obtain the list of user address type names.
char *get_user_cmd_addr_type(expand_T *xp, int idx)
{
  return addr_type_complete[idx].name;
}

/// Function given to ExpandGeneric() to obtain the list of user command
/// attributes.
char *get_user_cmd_flags(expand_T *xp, int idx)
{
  static char *user_cmd_flags[] = { "addr",   "bang",     "bar",
                                    "buffer", "complete", "count",
                                    "nargs",  "range",    "register",
                                    "keepscript" };

  if (idx >= (int)ARRAY_SIZE(user_cmd_flags)) {
    return NULL;
  }
  return user_cmd_flags[idx];
}

/// Function given to ExpandGeneric() to obtain the list of values for -nargs.
char *get_user_cmd_nargs(expand_T *xp, int idx)
{
  static char *user_cmd_nargs[] = { "0", "1", "*", "?", "+" };

  if (idx >= (int)ARRAY_SIZE(user_cmd_nargs)) {
    return NULL;
  }
  return user_cmd_nargs[idx];
}

static char *get_command_complete(int arg)
{
  if (arg >= (int)(ARRAY_SIZE(command_complete))) {
    return NULL;
  }
  return (char *)command_complete[arg];
}

/// Function given to ExpandGeneric() to obtain the list of values for -complete.
char *get_user_cmd_complete(expand_T *xp, int idx)
{
  if (idx >= (int)ARRAY_SIZE(command_complete)) {
    return NULL;
  }
  char *cmd_compl = get_command_complete(idx);
  if (cmd_compl == NULL || idx == EXPAND_USER_LUA) {
    return "";
  }
  return cmd_compl;
}

int cmdcomplete_str_to_type(const char *complete_str)
{
  if (strncmp(complete_str, "custom,", 7) == 0) {
    return EXPAND_USER_DEFINED;
  }
  if (strncmp(complete_str, "customlist,", 11) == 0) {
    return EXPAND_USER_LIST;
  }

  for (int i = 0; i < (int)(ARRAY_SIZE(command_complete)); i++) {
    char *cmd_compl = get_command_complete(i);
    if (cmd_compl == NULL) {
      continue;
    }
    if (strcmp(complete_str, command_complete[i]) == 0) {
      return i;
    }
  }

  return EXPAND_NOTHING;
}

static void uc_list(char *name, size_t name_len)
{
  bool found = false;

  // In cmdwin, the alternative buffer should be used.
  const garray_T *gap = &prevwin_curwin()->w_buffer->b_ucmds;
  while (true) {
    int i;
    for (i = 0; i < gap->ga_len; i++) {
      ucmd_T *cmd = USER_CMD_GA(gap, i);
      uint32_t a = cmd->uc_argt;

      // Skip commands which don't match the requested prefix and
      // commands filtered out.
      if (strncmp(name, cmd->uc_name, name_len) != 0
          || message_filtered(cmd->uc_name)) {
        continue;
      }

      // Put out the title first time
      if (!found) {
        msg_puts_title(_("\n    Name              Args Address Complete    Definition"));
      }
      found = true;
      msg_putchar('\n');
      if (got_int) {
        break;
      }

      // Special cases
      size_t len = 4;
      if (a & EX_BANG) {
        msg_putchar('!');
        len--;
      }
      if (a & EX_REGSTR) {
        msg_putchar('"');
        len--;
      }
      if (gap != &ucmds) {
        msg_putchar('b');
        len--;
      }
      if (a & EX_TRLBAR) {
        msg_putchar('|');
        len--;
      }
      while (len-- > 0) {
        msg_putchar(' ');
      }

      msg_outtrans(cmd->uc_name, HLF_D + 1, false);
      len = strlen(cmd->uc_name) + 4;

      do {
        msg_putchar(' ');
        len++;
      } while (len < 22);

      // "over" is how much longer the name is than the column width for
      // the name, we'll try to align what comes after.
      const int64_t over = (int64_t)len - 22;
      len = 0;

      // Arguments
      switch (a & (EX_EXTRA | EX_NOSPC | EX_NEEDARG)) {
      case 0:
        IObuff[len++] = '0';
        break;
      case (EX_EXTRA):
        IObuff[len++] = '*';
        break;
      case (EX_EXTRA | EX_NOSPC):
        IObuff[len++] = '?';
        break;
      case (EX_EXTRA | EX_NEEDARG):
        IObuff[len++] = '+';
        break;
      case (EX_EXTRA | EX_NOSPC | EX_NEEDARG):
        IObuff[len++] = '1';
        break;
      }

      do {
        IObuff[len++] = ' ';
      } while ((int64_t)len < 5 - over);

      // Address / Range
      if (a & (EX_RANGE | EX_COUNT)) {
        if (a & EX_COUNT) {
          // -count=N
          int rc = snprintf(IObuff + len, IOSIZE - len, "%" PRId64 "c", cmd->uc_def);
          assert(rc > 0);
          len += (size_t)rc;
        } else if (a & EX_DFLALL) {
          IObuff[len++] = '%';
        } else if (cmd->uc_def >= 0) {
          // -range=N
          int rc = snprintf(IObuff + len, IOSIZE - len, "%" PRId64 "", cmd->uc_def);
          assert(rc > 0);
          len += (size_t)rc;
        } else {
          IObuff[len++] = '.';
        }
      }

      do {
        IObuff[len++] = ' ';
      } while ((int64_t)len < 8 - over);

      // Address Type
      for (int j = 0; addr_type_complete[j].expand != ADDR_NONE; j++) {
        if (addr_type_complete[j].expand != ADDR_LINES
            && addr_type_complete[j].expand == cmd->uc_addr_type) {
          int rc = snprintf(IObuff + len, IOSIZE - len, "%s", addr_type_complete[j].shortname);
          assert(rc > 0);
          len += (size_t)rc;
          break;
        }
      }

      do {
        IObuff[len++] = ' ';
      } while ((int64_t)len < 13 - over);

      // Completion
      char *cmd_compl = get_command_complete(cmd->uc_compl);
      if (cmd_compl != NULL) {
        int rc = snprintf(IObuff + len, IOSIZE - len, "%s", get_command_complete(cmd->uc_compl));
        assert(rc > 0);
        len += (size_t)rc;
      }

      do {
        IObuff[len++] = ' ';
      } while ((int64_t)len < 25 - over);

      IObuff[len] = NUL;
      msg_outtrans(IObuff, 0, false);

      if (cmd->uc_luaref != LUA_NOREF) {
        char *fn = nlua_funcref_str(cmd->uc_luaref, NULL);
        msg_puts_hl(fn, HLF_8 + 1, false);
        xfree(fn);
        // put the description on a new line
        if (*cmd->uc_rep != NUL) {
          msg_puts("\n                                               ");
        }
      }

      msg_outtrans_special(cmd->uc_rep, false,
                           name_len == 0 ? Columns - 47 : 0);
      if (p_verbose > 0) {
        last_set_msg(cmd->uc_script_ctx);
      }
      line_breakcheck();
      if (got_int) {
        break;
      }
    }
    if (gap == &ucmds || i < gap->ga_len) {
      break;
    }
    gap = &ucmds;
  }

  if (!found) {
    msg(_("No user-defined commands found"), 0);
  }
}

/// Parse address type argument
int parse_addr_type_arg(char *value, int vallen, cmd_addr_T *addr_type_arg)
  FUNC_ATTR_NONNULL_ALL
{
  int i;

  for (i = 0; addr_type_complete[i].expand != ADDR_NONE; i++) {
    int a = (int)strlen(addr_type_complete[i].name) == vallen;
    int b = strncmp(value, addr_type_complete[i].name, (size_t)vallen) == 0;
    if (a && b) {
      *addr_type_arg = addr_type_complete[i].expand;
      break;
    }
  }

  if (addr_type_complete[i].expand == ADDR_NONE) {
    char *err = value;

    for (i = 0; err[i] != NUL && !ascii_iswhite(err[i]); i++) {}
    err[i] = NUL;
    semsg(_("E180: Invalid address type value: %s"), err);
    return FAIL;
  }

  return OK;
}

/// Parse a completion argument "value[vallen]".
/// The detected completion goes in "*complp", argument type in "*argt".
/// When there is an argument, for function and user defined completion, it's
/// copied to allocated memory and stored in "*compl_arg".
///
/// @return  FAIL if something is wrong.
int parse_compl_arg(const char *value, int vallen, int *complp, uint32_t *argt, char **compl_arg)
  FUNC_ATTR_NONNULL_ALL
{
  const char *arg = NULL;
  size_t arglen = 0;
  int valend = vallen;

  // Look for any argument part - which is the part after any ','
  for (int i = 0; i < vallen; i++) {
    if (value[i] == ',') {
      arg = (char *)&value[i + 1];
      arglen = (size_t)(vallen - i - 1);
      valend = i;
      break;
    }
  }

  int i;
  for (i = 0; i < (int)ARRAY_SIZE(command_complete); i++) {
    if (get_command_complete(i) == NULL) {
      continue;
    }
    if ((int)strlen(command_complete[i]) == valend
        && strncmp(value, command_complete[i], (size_t)valend) == 0) {
      *complp = i;
      if (i == EXPAND_BUFFERS) {
        *argt |= EX_BUFNAME;
      } else if (i == EXPAND_DIRECTORIES || i == EXPAND_FILES
                 || i == EXPAND_SHELLCMDLINE) {
        *argt |= EX_XFILE;
      }
      break;
    }
  }

  if (i == (int)ARRAY_SIZE(command_complete)) {
    semsg(_("E180: Invalid complete value: %s"), value);
    return FAIL;
  }

  if (*complp != EXPAND_USER_DEFINED && *complp != EXPAND_USER_LIST
      && arg != NULL) {
    emsg(_("E468: Completion argument only allowed for custom completion"));
    return FAIL;
  }

  if ((*complp == EXPAND_USER_DEFINED || *complp == EXPAND_USER_LIST)
      && arg == NULL) {
    emsg(_("E467: Custom completion requires a function argument"));
    return FAIL;
  }

  if (arg != NULL) {
    *compl_arg = xstrnsave(arg, arglen);
  }
  return OK;
}

static int uc_scan_attr(char *attr, size_t len, uint32_t *argt, int *def, int *flags, int *complp,
                        char **compl_arg, cmd_addr_T *addr_type_arg)
  FUNC_ATTR_NONNULL_ALL
{
  if (len == 0) {
    emsg(_("E175: No attribute specified"));
    return FAIL;
  }

  // First, try the simple attributes (no arguments)
  if (STRNICMP(attr, "bang", len) == 0) {
    *argt |= EX_BANG;
  } else if (STRNICMP(attr, "buffer", len) == 0) {
    *flags |= UC_BUFFER;
  } else if (STRNICMP(attr, "register", len) == 0) {
    *argt |= EX_REGSTR;
  } else if (STRNICMP(attr, "keepscript", len) == 0) {
    *argt |= EX_KEEPSCRIPT;
  } else if (STRNICMP(attr, "bar", len) == 0) {
    *argt |= EX_TRLBAR;
  } else {
    char *val = NULL;
    size_t vallen = 0;
    size_t attrlen = len;

    // Look for the attribute name - which is the part before any '='
    for (int i = 0; i < (int)len; i++) {
      if (attr[i] == '=') {
        val = &attr[i + 1];
        vallen = len - (size_t)i - 1;
        attrlen = (size_t)i;
        break;
      }
    }

    if (STRNICMP(attr, "nargs", attrlen) == 0) {
      if (vallen == 1) {
        if (*val == '0') {
          // Do nothing - this is the default;
        } else if (*val == '1') {
          *argt |= (EX_EXTRA | EX_NOSPC | EX_NEEDARG);
        } else if (*val == '*') {
          *argt |= EX_EXTRA;
        } else if (*val == '?') {
          *argt |= (EX_EXTRA | EX_NOSPC);
        } else if (*val == '+') {
          *argt |= (EX_EXTRA | EX_NEEDARG);
        } else {
          goto wrong_nargs;
        }
      } else {
wrong_nargs:
        emsg(_("E176: Invalid number of arguments"));
        return FAIL;
      }
    } else if (STRNICMP(attr, "range", attrlen) == 0) {
      *argt |= EX_RANGE;
      if (vallen == 1 && *val == '%') {
        *argt |= EX_DFLALL;
      } else if (val != NULL) {
        char *p = val;
        if (*def >= 0) {
two_count:
          emsg(_("E177: Count cannot be specified twice"));
          return FAIL;
        }

        *def = getdigits_int(&p, true, 0);
        *argt |= EX_ZEROR;

        if (p != val + vallen || vallen == 0) {
invalid_count:
          emsg(_("E178: Invalid default value for count"));
          return FAIL;
        }
      }
      // default for -range is using buffer lines
      if (*addr_type_arg == ADDR_NONE) {
        *addr_type_arg = ADDR_LINES;
      }
    } else if (STRNICMP(attr, "count", attrlen) == 0) {
      *argt |= (EX_COUNT | EX_ZEROR | EX_RANGE);
      // default for -count is using any number
      if (*addr_type_arg == ADDR_NONE) {
        *addr_type_arg = ADDR_OTHER;
      }

      if (val != NULL) {
        char *p = val;
        if (*def >= 0) {
          goto two_count;
        }

        *def = getdigits_int(&p, true, 0);

        if (p != val + vallen) {
          goto invalid_count;
        }
      }

      *def = MAX(*def, 0);
    } else if (STRNICMP(attr, "complete", attrlen) == 0) {
      if (val == NULL) {
        semsg(_(e_argument_required_for_str), "-complete");
        return FAIL;
      }

      if (parse_compl_arg(val, (int)vallen, complp, argt, compl_arg)
          == FAIL) {
        return FAIL;
      }
    } else if (STRNICMP(attr, "addr", attrlen) == 0) {
      *argt |= EX_RANGE;
      if (val == NULL) {
        semsg(_(e_argument_required_for_str), "-addr");
        return FAIL;
      }
      if (parse_addr_type_arg(val, (int)vallen, addr_type_arg) == FAIL) {
        return FAIL;
      }
      if (*addr_type_arg != ADDR_LINES) {
        *argt |= EX_ZEROR;
      }
    } else {
      char ch = attr[len];
      attr[len] = NUL;
      semsg(_("E181: Invalid attribute: %s"), attr);
      attr[len] = ch;
      return FAIL;
    }
  }

  return OK;
}

/// Check for a valid user command name
///
/// If the given {name} is valid, then a pointer to the end of the valid name is returned.
/// Otherwise, returns NULL.
char *uc_validate_name(char *name)
{
  if (ASCII_ISALPHA(*name)) {
    while (ASCII_ISALNUM(*name)) {
      name++;
    }
  }
  if (!ends_excmd(*name) && !ascii_iswhite(*name)) {
    return NULL;
  }

  return name;
}

/// Create a new user command {name}, if one doesn't already exist.
///
/// This function takes ownership of compl_arg, compl_luaref, and luaref.
///
/// @return  OK if the command is created, FAIL otherwise.
int uc_add_command(char *name, size_t name_len, const char *rep, uint32_t argt, int64_t def,
                   int flags, int context, char *compl_arg, LuaRef compl_luaref,
                   LuaRef preview_luaref, cmd_addr_T addr_type, LuaRef luaref, bool force)
  FUNC_ATTR_NONNULL_ARG(1, 3)
{
  ucmd_T *cmd = NULL;
  int cmp = 1;
  char *rep_buf = NULL;
  garray_T *gap;

  replace_termcodes(rep, strlen(rep), &rep_buf, 0, 0, NULL, p_cpo);
  if (rep_buf == NULL) {
    // Can't replace termcodes - try using the string as is
    rep_buf = xstrdup(rep);
  }

  // get address of growarray: global or in curbuf
  if (flags & UC_BUFFER) {
    gap = &curbuf->b_ucmds;
    if (gap->ga_itemsize == 0) {
      ga_init(gap, (int)sizeof(ucmd_T), 4);
    }
  } else {
    gap = &ucmds;
  }

  int i;

  // Search for the command in the already defined commands.
  for (i = 0; i < gap->ga_len; i++) {
    cmd = USER_CMD_GA(gap, i);
    size_t len = strlen(cmd->uc_name);
    cmp = strncmp(name, cmd->uc_name, name_len);
    if (cmp == 0) {
      if (name_len < len) {
        cmp = -1;
      } else if (name_len > len) {
        cmp = 1;
      }
    }

    if (cmp == 0) {
      // Command can be replaced with "command!" and when sourcing the
      // same script again, but only once.
      if (!force
          && (cmd->uc_script_ctx.sc_sid != current_sctx.sc_sid
              || cmd->uc_script_ctx.sc_seq == current_sctx.sc_seq)) {
        semsg(_("E174: Command already exists: add ! to replace it: %s"),
              name);
        goto fail;
      }

      XFREE_CLEAR(cmd->uc_rep);
      XFREE_CLEAR(cmd->uc_compl_arg);
      NLUA_CLEAR_REF(cmd->uc_luaref);
      NLUA_CLEAR_REF(cmd->uc_compl_luaref);
      NLUA_CLEAR_REF(cmd->uc_preview_luaref);
      break;
    }

    // Stop as soon as we pass the name to add
    if (cmp < 0) {
      break;
    }
  }

  // Extend the array unless we're replacing an existing command
  if (cmp != 0) {
    ga_grow(gap, 1);

    char *const p = xstrnsave(name, name_len);

    cmd = USER_CMD_GA(gap, i);
    memmove(cmd + 1, cmd, (size_t)(gap->ga_len - i) * sizeof(ucmd_T));

    gap->ga_len++;

    cmd->uc_name = p;
  }

  cmd->uc_rep = rep_buf;
  cmd->uc_argt = argt;
  cmd->uc_def = def;
  cmd->uc_compl = context;
  cmd->uc_script_ctx = current_sctx;
  cmd->uc_script_ctx.sc_lnum += SOURCING_LNUM;
  nlua_set_sctx(&cmd->uc_script_ctx);
  cmd->uc_compl_arg = compl_arg;
  cmd->uc_compl_luaref = compl_luaref;
  cmd->uc_preview_luaref = preview_luaref;
  cmd->uc_addr_type = addr_type;
  cmd->uc_luaref = luaref;

  return OK;

fail:
  xfree(rep_buf);
  xfree(compl_arg);
  NLUA_CLEAR_REF(luaref);
  NLUA_CLEAR_REF(compl_luaref);
  NLUA_CLEAR_REF(preview_luaref);
  return FAIL;
}

/// ":command ..."
void ex_command(exarg_T *eap)
{
  char *end;
  uint32_t argt = 0;
  int def = -1;
  int flags = 0;
  int context = EXPAND_NOTHING;
  char *compl_arg = NULL;
  cmd_addr_T addr_type_arg = ADDR_NONE;
  int has_attr = (eap->arg[0] == '-');

  char *p = eap->arg;

  // Check for attributes
  while (*p == '-') {
    p++;
    end = skiptowhite(p);
    if (uc_scan_attr(p, (size_t)(end - p), &argt, &def, &flags, &context, &compl_arg,
                     &addr_type_arg) == FAIL) {
      goto theend;
    }
    p = skipwhite(end);
  }

  // Get the name (if any) and skip to the following argument.
  char *name = p;
  end = uc_validate_name(name);
  if (!end) {
    emsg(_("E182: Invalid command name"));
    goto theend;
  }
  size_t name_len = (size_t)(end - name);

  // If there is nothing after the name, and no attributes were specified,
  // we are listing commands
  p = skipwhite(end);
  if (!has_attr && ends_excmd(*p)) {
    uc_list(name, name_len);
  } else if (!ASCII_ISUPPER(*name)) {
    emsg(_("E183: User defined commands must start with an uppercase letter"));
  } else if (name_len <= 4 && strncmp(name, "Next", name_len) == 0) {
    emsg(_("E841: Reserved name, cannot be used for user defined command"));
  } else if (context > 0 && (argt & EX_EXTRA) == 0) {
    emsg(_(e_complete_used_without_allowing_arguments));
  } else {
    uc_add_command(name, name_len, p, argt, def, flags, context, compl_arg, LUA_NOREF, LUA_NOREF,
                   addr_type_arg, LUA_NOREF, eap->forceit);

    return;  // success
  }

theend:
  xfree(compl_arg);
}

/// ":comclear"
/// Clear all user commands, global and for current buffer.
void ex_comclear(exarg_T *eap)
{
  uc_clear(&ucmds);
  uc_clear(&curbuf->b_ucmds);
}

void free_ucmd(ucmd_T *cmd)
{
  xfree(cmd->uc_name);
  xfree(cmd->uc_rep);
  xfree(cmd->uc_compl_arg);
  NLUA_CLEAR_REF(cmd->uc_compl_luaref);
  NLUA_CLEAR_REF(cmd->uc_luaref);
  NLUA_CLEAR_REF(cmd->uc_preview_luaref);
}

/// Clear all user commands for "gap".
void uc_clear(garray_T *gap)
{
  GA_DEEP_CLEAR(gap, ucmd_T, free_ucmd);
}

void ex_delcommand(exarg_T *eap)
{
  int i = 0;
  ucmd_T *cmd = NULL;
  int res = -1;
  const char *arg = eap->arg;
  bool buffer_only = false;

  if (strncmp(arg, "-buffer", 7) == 0 && ascii_iswhite(arg[7])) {
    buffer_only = true;
    arg = skipwhite(arg + 7);
  }

  garray_T *gap = &curbuf->b_ucmds;
  while (true) {
    for (i = 0; i < gap->ga_len; i++) {
      cmd = USER_CMD_GA(gap, i);
      res = strcmp(arg, cmd->uc_name);
      if (res <= 0) {
        break;
      }
    }
    if (gap == &ucmds || res == 0 || buffer_only) {
      break;
    }
    gap = &ucmds;
  }

  if (res != 0) {
    semsg(_(buffer_only
            ? e_no_such_user_defined_command_in_current_buffer_str
            : e_no_such_user_defined_command_str),
          arg);
    return;
  }

  free_ucmd(cmd);

  gap->ga_len--;

  if (i < gap->ga_len) {
    memmove(cmd, cmd + 1, (size_t)(gap->ga_len - i) * sizeof(ucmd_T));
  }
}

/// Split a string by unescaped whitespace (space & tab), used for f-args on Lua commands callback.
/// Similar to uc_split_args(), but does not allocate, add quotes, add commas and is an iterator.
///
/// @param[in]  arg String to split
/// @param[in]  arglen Length of {arg}
/// @param[inout] end Index of last character of previous iteration
/// @param[out] buf Buffer to copy string into
/// @param[out] len Length of string in {buf}
///
/// @return true if iteration is complete, else false
bool uc_split_args_iter(const char *arg, size_t arglen, size_t *end, char *buf, size_t *len)
{
  if (!arglen) {
    return true;
  }

  size_t pos = *end;
  while (pos < arglen && ascii_iswhite(arg[pos])) {
    pos++;
  }

  size_t l = 0;
  for (; pos < arglen - 1; pos++) {
    if (arg[pos] == '\\' && (arg[pos + 1] == '\\' || ascii_iswhite(arg[pos + 1]))) {
      buf[l++] = arg[++pos];
    } else {
      buf[l++] = arg[pos];
    }
    if (ascii_iswhite(arg[pos + 1])) {
      *end = pos + 1;
      *len = l;
      return false;
    }
  }

  if (pos < arglen && !ascii_iswhite(arg[pos])) {
    buf[l++] = arg[pos];
  }

  *len = l;
  return true;
}

size_t uc_nargs_upper_bound(const char *arg, size_t arglen)
{
  bool was_white = true;  // space before first arg
  size_t nargs = 0;
  for (size_t i = 0; i < arglen; i++) {
    bool is_white = ascii_iswhite(arg[i]);
    if (was_white && !is_white) {
      nargs++;
    }
    was_white = is_white;
  }
  return nargs;
}

/// split and quote args for <f-args>
static char *uc_split_args(const char *arg, char **args, const size_t *arglens, size_t argc,
                           size_t *lenp)
{
  // Precalculate length
  int len = 2;   // Initial and final quotes
  if (args == NULL) {
    const char *p = arg;

    while (*p) {
      if (p[0] == '\\' && p[1] == '\\') {
        len += 2;
        p += 2;
      } else if (p[0] == '\\' && ascii_iswhite(p[1])) {
        len += 1;
        p += 2;
      } else if (*p == '\\' || *p == '"') {
        len += 2;
        p += 1;
      } else if (ascii_iswhite(*p)) {
        p = skipwhite(p);
        if (*p == NUL) {
          break;
        }
        len += 4;  // ", "
      } else {
        const int charlen = utfc_ptr2len(p);

        len += charlen;
        p += charlen;
      }
    }
  } else {
    for (size_t i = 0; i < argc; i++) {
      const char *p = args[i];
      const char *arg_end = args[i] + arglens[i];

      while (p < arg_end) {
        if (*p == '\\' || *p == '"') {
          len += 2;
          p += 1;
        } else {
          const int charlen = utfc_ptr2len(p);

          len += charlen;
          p += charlen;
        }
      }

      if (i != argc - 1) {
        len += 4;  // ", "
      }
    }
  }

  char *buf = xmalloc((size_t)len + 1);

  char *q = buf;
  *q++ = '"';

  if (args == NULL) {
    const char *p = arg;
    while (*p) {
      if (p[0] == '\\' && p[1] == '\\') {
        *q++ = '\\';
        *q++ = '\\';
        p += 2;
      } else if (p[0] == '\\' && ascii_iswhite(p[1])) {
        *q++ = p[1];
        p += 2;
      } else if (*p == '\\' || *p == '"') {
        *q++ = '\\';
        *q++ = *p++;
      } else if (ascii_iswhite(*p)) {
        p = skipwhite(p);
        if (*p == NUL) {
          break;
        }
        *q++ = '"';
        *q++ = ',';
        *q++ = ' ';
        *q++ = '"';
      } else {
        mb_copy_char(&p, &q);
      }
    }
  } else {
    for (size_t i = 0; i < argc; i++) {
      const char *p = args[i];
      const char *arg_end = args[i] + arglens[i];

      while (p < arg_end) {
        if (*p == '\\' || *p == '"') {
          *q++ = '\\';
          *q++ = *p++;
        } else {
          mb_copy_char(&p, &q);
        }
      }
      if (i != argc - 1) {
        *q++ = '"';
        *q++ = ',';
        *q++ = ' ';
        *q++ = '"';
      }
    }
  }

  *q++ = '"';
  *q = 0;

  *lenp = (size_t)len;
  return buf;
}

static size_t add_cmd_modifier(char *buf, char *mod_str, bool *multi_mods)
{
  size_t result = strlen(mod_str);
  if (*multi_mods) {
    result++;
  }

  if (buf != NULL) {
    if (*multi_mods) {
      strcat(buf, " ");
    }
    strcat(buf, mod_str);
  }

  *multi_mods = true;
  return result;
}

/// Add modifiers from "cmod->cmod_split" to "buf".  Set "multi_mods" when one
/// was added.
///
/// @return the number of bytes added
size_t add_win_cmd_modifiers(char *buf, const cmdmod_T *cmod, bool *multi_mods)
{
  size_t result = 0;

  // :aboveleft and :leftabove
  if (cmod->cmod_split & WSP_ABOVE) {
    result += add_cmd_modifier(buf, "aboveleft", multi_mods);
  }
  // :belowright and :rightbelow
  if (cmod->cmod_split & WSP_BELOW) {
    result += add_cmd_modifier(buf, "belowright", multi_mods);
  }
  // :botright
  if (cmod->cmod_split & WSP_BOT) {
    result += add_cmd_modifier(buf, "botright", multi_mods);
  }

  // :tab
  if (cmod->cmod_tab > 0) {
    int tabnr = cmod->cmod_tab - 1;
    if (tabnr == tabpage_index(curtab)) {
      // For compatibility, don't add a tabpage number if it is the same
      // as the default number for :tab.
      result += add_cmd_modifier(buf, "tab", multi_mods);
    } else {
      char tab_buf[NUMBUFLEN + 3];
      snprintf(tab_buf, sizeof(tab_buf), "%dtab", tabnr);
      result += add_cmd_modifier(buf, tab_buf, multi_mods);
    }
  }

  // :topleft
  if (cmod->cmod_split & WSP_TOP) {
    result += add_cmd_modifier(buf, "topleft", multi_mods);
  }
  // :vertical
  if (cmod->cmod_split & WSP_VERT) {
    result += add_cmd_modifier(buf, "vertical", multi_mods);
  }
  // :horizontal
  if (cmod->cmod_split & WSP_HOR) {
    result += add_cmd_modifier(buf, "horizontal", multi_mods);
  }
  return result;
}

/// Generate text for the "cmod" command modifiers.
/// If "buf" is NULL just return the length.
size_t uc_mods(char *buf, const cmdmod_T *cmod, bool quote)
{
  size_t result = 0;
  bool multi_mods = false;

  typedef struct {
    int flag;
    char *name;
  } mod_entry_T;
  static mod_entry_T mod_entries[] = {
    { CMOD_BROWSE, "browse" },
    { CMOD_CONFIRM, "confirm" },
    { CMOD_HIDE, "hide" },
    { CMOD_KEEPALT, "keepalt" },
    { CMOD_KEEPJUMPS, "keepjumps" },
    { CMOD_KEEPMARKS, "keepmarks" },
    { CMOD_KEEPPATTERNS, "keeppatterns" },
    { CMOD_LOCKMARKS, "lockmarks" },
    { CMOD_NOSWAPFILE, "noswapfile" },
    { CMOD_UNSILENT, "unsilent" },
    { CMOD_NOAUTOCMD, "noautocmd" },
    { CMOD_SANDBOX, "sandbox" },
  };

  result = quote ? 2 : 0;
  if (buf != NULL) {
    if (quote) {
      *buf++ = '"';
    }
    *buf = NUL;
  }

  // the modifiers that are simple flags
  for (size_t i = 0; i < ARRAY_SIZE(mod_entries); i++) {
    if (cmod->cmod_flags & mod_entries[i].flag) {
      result += add_cmd_modifier(buf, mod_entries[i].name, &multi_mods);
    }
  }

  // :silent
  if (cmod->cmod_flags & CMOD_SILENT) {
    result += add_cmd_modifier(buf,
                               (cmod->cmod_flags & CMOD_ERRSILENT) ? "silent!" : "silent",
                               &multi_mods);
  }
  // :verbose
  if (cmod->cmod_verbose > 0) {
    int verbose_value = cmod->cmod_verbose - 1;
    if (verbose_value == 1) {
      result += add_cmd_modifier(buf, "verbose", &multi_mods);
    } else {
      char verbose_buf[NUMBUFLEN];
      snprintf(verbose_buf, sizeof(verbose_buf), "%dverbose", verbose_value);
      result += add_cmd_modifier(buf, verbose_buf, &multi_mods);
    }
  }
  // flags from cmod->cmod_split
  result += add_win_cmd_modifiers(buf, cmod, &multi_mods);

  if (quote && buf != NULL) {
    buf += result - 2;
    *buf = '"';
  }
  return result;
}

/// Check for a <> code in a user command.
///
/// @param code       points to the '<'.  "len" the length of the <> (inclusive).
/// @param buf        is where the result is to be added.
/// @param cmd        the user command we're expanding
/// @param eap        ex arguments
/// @param split_buf  points to a buffer used for splitting, caller should free it.
/// @param split_len  is the length of what "split_buf" contains.
///
/// @return           the length of the replacement, which has been added to "buf".
///                   Return -1 if there was no match, and only the "<" has been copied.
static size_t uc_check_code(char *code, size_t len, char *buf, ucmd_T *cmd, exarg_T *eap,
                            char **split_buf, size_t *split_len)
{
  size_t result = 0;
  char *p = code + 1;
  size_t l = len - 2;
  int quote = 0;
  enum {
    ct_ARGS,
    ct_BANG,
    ct_COUNT,
    ct_LINE1,
    ct_LINE2,
    ct_RANGE,
    ct_MODS,
    ct_REGISTER,
    ct_LT,
    ct_NONE,
  } type = ct_NONE;

  if ((vim_strchr("qQfF", (uint8_t)(*p)) != NULL) && p[1] == '-') {
    quote = (*p == 'q' || *p == 'Q') ? 1 : 2;
    p += 2;
    l -= 2;
  }

  l++;
  if (l <= 1) {
    // type = ct_NONE;
  } else if (STRNICMP(p, "args>", l) == 0) {
    type = ct_ARGS;
  } else if (STRNICMP(p, "bang>", l) == 0) {
    type = ct_BANG;
  } else if (STRNICMP(p, "count>", l) == 0) {
    type = ct_COUNT;
  } else if (STRNICMP(p, "line1>", l) == 0) {
    type = ct_LINE1;
  } else if (STRNICMP(p, "line2>", l) == 0) {
    type = ct_LINE2;
  } else if (STRNICMP(p, "range>", l) == 0) {
    type = ct_RANGE;
  } else if (STRNICMP(p, "lt>", l) == 0) {
    type = ct_LT;
  } else if (STRNICMP(p, "reg>", l) == 0 || STRNICMP(p, "register>", l) == 0) {
    type = ct_REGISTER;
  } else if (STRNICMP(p, "mods>", l) == 0) {
    type = ct_MODS;
  }

  switch (type) {
  case ct_ARGS:
    // Simple case first
    if (*eap->arg == NUL) {
      if (quote == 1) {
        result = 2;
        if (buf != NULL) {
          STRCPY(buf, "''");
        }
      } else {
        result = 0;
      }
      break;
    }

    // When specified there is a single argument don't split it.
    // Works for ":Cmd %" when % is "a b c".
    if ((eap->argt & EX_NOSPC) && quote == 2) {
      quote = 1;
    }

    switch (quote) {
    case 0:     // No quoting, no splitting
      result = strlen(eap->arg);
      if (buf != NULL) {
        STRCPY(buf, eap->arg);
      }
      break;
    case 1:     // Quote, but don't split
      result = strlen(eap->arg) + 2;
      for (p = eap->arg; *p; p++) {
        if (*p == '\\' || *p == '"') {
          result++;
        }
      }

      if (buf != NULL) {
        *buf++ = '"';
        for (p = eap->arg; *p; p++) {
          if (*p == '\\' || *p == '"') {
            *buf++ = '\\';
          }
          *buf++ = *p;
        }
        *buf = '"';
      }

      break;
    case 2:     // Quote and split (<f-args>)
      // This is hard, so only do it once, and cache the result
      if (*split_buf == NULL) {
        *split_buf = uc_split_args(eap->arg, eap->args, eap->arglens, eap->argc, split_len);
      }

      result = *split_len;
      if (buf != NULL && result != 0) {
        STRCPY(buf, *split_buf);
      }

      break;
    }
    break;

  case ct_BANG:
    result = eap->forceit ? 1 : 0;
    if (quote) {
      result += 2;
    }
    if (buf != NULL) {
      if (quote) {
        *buf++ = '"';
      }
      if (eap->forceit) {
        *buf++ = '!';
      }
      if (quote) {
        *buf = '"';
      }
    }
    break;

  case ct_LINE1:
  case ct_LINE2:
  case ct_RANGE:
  case ct_COUNT: {
    char num_buf[20];
    int64_t num = type == ct_LINE1
                  ? eap->line1
                  : (type == ct_LINE2
                     ? eap->line2
                     : (type == ct_RANGE
                        ? eap->addr_count
                        : (eap->addr_count > 0 ? eap->line2 : cmd->uc_def)));
    size_t num_len;

    snprintf(num_buf, sizeof(num_buf), "%" PRId64, num);
    num_len = strlen(num_buf);
    result = num_len;

    if (quote) {
      result += 2;
    }

    if (buf != NULL) {
      if (quote) {
        *buf++ = '"';
      }
      STRCPY(buf, num_buf);
      buf += num_len;
      if (quote) {
        *buf = '"';
      }
    }

    break;
  }

  case ct_MODS:
    result = uc_mods(buf, &cmdmod, quote);
    break;

  case ct_REGISTER:
    result = eap->regname ? 1 : 0;
    if (quote) {
      result += 2;
    }
    if (buf != NULL) {
      if (quote) {
        *buf++ = '\'';
      }
      if (eap->regname) {
        *buf++ = (char)eap->regname;
      }
      if (quote) {
        *buf = '\'';
      }
    }
    break;

  case ct_LT:
    result = 1;
    if (buf != NULL) {
      *buf = '<';
    }
    break;

  default:
    // Not recognized: just copy the '<' and return -1.
    result = (size_t)-1;
    if (buf != NULL) {
      *buf = '<';
    }
    break;
  }

  return result;
}

int do_ucmd(exarg_T *eap, bool preview)
{
  char *end = NULL;

  size_t split_len = 0;
  char *split_buf = NULL;
  ucmd_T *cmd;

  if (eap->cmdidx == CMD_USER) {
    cmd = USER_CMD(eap->useridx);
  } else {
    cmd = USER_CMD_GA(&prevwin_curwin()->w_buffer->b_ucmds, eap->useridx);
  }

  if (preview) {
    assert(cmd->uc_preview_luaref > 0);
    return nlua_do_ucmd(cmd, eap, true);
  }

  if (cmd->uc_luaref > 0) {
    nlua_do_ucmd(cmd, eap, false);
    return 0;
  }

  // Replace <> in the command by the arguments.
  // First round: "buf" is NULL, compute length, allocate "buf".
  // Second round: copy result into "buf".
  char *buf = NULL;
  while (true) {
    char *p = cmd->uc_rep;        // source
    char *q = buf;                // destination
    size_t totlen = 0;

    while (true) {
      char *start = vim_strchr(p, '<');
      if (start != NULL) {
        end = vim_strchr(start + 1, '>');
      }
      if (buf != NULL) {
        char *ksp;
        for (ksp = p; *ksp != NUL && (uint8_t)(*ksp) != K_SPECIAL; ksp++) {}
        if ((uint8_t)(*ksp) == K_SPECIAL
            && (start == NULL || ksp < start || end == NULL)
            && ((uint8_t)ksp[1] == KS_SPECIAL && ksp[2] == KE_FILLER)) {
          // K_SPECIAL has been put in the buffer as K_SPECIAL
          // KS_SPECIAL KE_FILLER, like for mappings, but
          // do_cmdline() doesn't handle that, so convert it back.
          size_t len = (size_t)(ksp - p);
          if (len > 0) {
            memmove(q, p, len);
            q += len;
          }
          *q++ = (char)K_SPECIAL;
          p = ksp + 3;
          continue;
        }
      }

      // break if no <item> is found
      if (start == NULL || end == NULL) {
        break;
      }

      // Include the '>'
      end++;

      // Take everything up to the '<'
      size_t len = (size_t)(start - p);
      if (buf == NULL) {
        totlen += len;
      } else {
        memmove(q, p, len);
        q += len;
      }

      len = uc_check_code(start, (size_t)(end - start), q, cmd, eap, &split_buf, &split_len);
      if (len == (size_t)-1) {
        // no match, continue after '<'
        p = start + 1;
        len = 1;
      } else {
        p = end;
      }
      if (buf == NULL) {
        totlen += len;
      } else {
        q += len;
      }
    }
    if (buf != NULL) {              // second time here, finished
      STRCPY(q, p);
      break;
    }

    totlen += strlen(p);            // Add on the trailing characters
    buf = xmalloc(totlen + 1);
  }

  sctx_T save_current_sctx;
  bool restore_current_sctx = false;
  if ((cmd->uc_argt & EX_KEEPSCRIPT) == 0) {
    restore_current_sctx = true;
    save_current_sctx = current_sctx;
    current_sctx.sc_sid = cmd->uc_script_ctx.sc_sid;
  }
  do_cmdline(buf, eap->ea_getline, eap->cookie,
             DOCMD_VERBOSE|DOCMD_NOWAIT|DOCMD_KEYTYPED);

  // Careful: Do not use "cmd" here, it may have become invalid if a user
  // command was added.
  if (restore_current_sctx) {
    current_sctx = save_current_sctx;
  }
  xfree(buf);
  xfree(split_buf);

  return 0;
}

/// Gets a map of maps describing user-commands defined for buffer `buf` or
/// defined globally if `buf` is NULL.
///
/// @param buf  Buffer to inspect, or NULL to get global commands.
///
/// @return Map of maps describing commands
Dict commands_array(buf_T *buf, Arena *arena)
{
  garray_T *gap = (buf == NULL) ? &ucmds : &buf->b_ucmds;

  Dict rv = arena_dict(arena, (size_t)gap->ga_len);
  for (int i = 0; i < gap->ga_len; i++) {
    char arg[2] = { 0, 0 };
    Dict d = arena_dict(arena, 14);
    ucmd_T *cmd = USER_CMD_GA(gap, i);

    PUT_C(d, "name", CSTR_AS_OBJ(cmd->uc_name));
    PUT_C(d, "definition", CSTR_AS_OBJ(cmd->uc_rep));
    PUT_C(d, "script_id", INTEGER_OBJ(cmd->uc_script_ctx.sc_sid));
    PUT_C(d, "bang", BOOLEAN_OBJ(!!(cmd->uc_argt & EX_BANG)));
    PUT_C(d, "bar", BOOLEAN_OBJ(!!(cmd->uc_argt & EX_TRLBAR)));
    PUT_C(d, "register", BOOLEAN_OBJ(!!(cmd->uc_argt & EX_REGSTR)));
    PUT_C(d, "keepscript", BOOLEAN_OBJ(!!(cmd->uc_argt & EX_KEEPSCRIPT)));
    PUT_C(d, "preview", BOOLEAN_OBJ(!!(cmd->uc_argt & EX_PREVIEW)));

    switch (cmd->uc_argt & (EX_EXTRA | EX_NOSPC | EX_NEEDARG)) {
    case 0:
      arg[0] = '0'; break;
    case (EX_EXTRA):
      arg[0] = '*'; break;
    case (EX_EXTRA | EX_NOSPC):
      arg[0] = '?'; break;
    case (EX_EXTRA | EX_NEEDARG):
      arg[0] = '+'; break;
    case (EX_EXTRA | EX_NOSPC | EX_NEEDARG):
      arg[0] = '1'; break;
    }
    PUT_C(d, "nargs", CSTR_TO_ARENA_OBJ(arena, arg));

    char *cmd_compl = get_command_complete(cmd->uc_compl);
    PUT_C(d, "complete", (cmd_compl == NULL
                          ? NIL : CSTR_AS_OBJ(cmd_compl)));
    PUT_C(d, "complete_arg", cmd->uc_compl_arg == NULL
          ? NIL : CSTR_AS_OBJ(cmd->uc_compl_arg));

    Object obj = NIL;
    if (cmd->uc_argt & EX_COUNT) {
      if (cmd->uc_def >= 0) {
        obj = STRING_OBJ(arena_printf(arena, "%" PRId64, cmd->uc_def));    // -count=N
      } else {
        obj = CSTR_AS_OBJ("0");    // -count
      }
    }
    PUT_C(d, "count", obj);

    obj = NIL;
    if (cmd->uc_argt & EX_RANGE) {
      if (cmd->uc_argt & EX_DFLALL) {
        obj = STATIC_CSTR_AS_OBJ("%");    // -range=%
      } else if (cmd->uc_def >= 0) {
        obj = STRING_OBJ(arena_printf(arena, "%" PRId64, cmd->uc_def));    // -range=N
      } else {
        obj = STATIC_CSTR_AS_OBJ(".");    // -range
      }
    }
    PUT_C(d, "range", obj);

    obj = NIL;
    for (int j = 0; addr_type_complete[j].expand != ADDR_NONE; j++) {
      if (addr_type_complete[j].expand != ADDR_LINES
          && addr_type_complete[j].expand == cmd->uc_addr_type) {
        obj = CSTR_AS_OBJ(addr_type_complete[j].name);
        break;
      }
    }
    PUT_C(d, "addr", obj);

    PUT_C(rv, cmd->uc_name, DICT_OBJ(d));
  }
  return rv;
}
