#include <inttypes.h>
#include <lauxlib.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#include "klib/kvec.h"
#include "nvim/api/command.h"
#include "nvim/api/keysets_defs.h"
#include "nvim/api/private/defs.h"
#include "nvim/api/private/dispatch.h"
#include "nvim/api/private/helpers.h"
#include "nvim/api/private/validate.h"
#include "nvim/ascii_defs.h"
#include "nvim/autocmd.h"
#include "nvim/autocmd_defs.h"
#include "nvim/buffer_defs.h"
#include "nvim/cmdexpand_defs.h"
#include "nvim/ex_cmds_defs.h"
#include "nvim/ex_docmd.h"
#include "nvim/ex_eval.h"
#include "nvim/garray.h"
#include "nvim/garray_defs.h"
#include "nvim/globals.h"
#include "nvim/lua/executor.h"
#include "nvim/macros_defs.h"
#include "nvim/mbyte.h"
#include "nvim/memory.h"
#include "nvim/memory_defs.h"
#include "nvim/ops.h"
#include "nvim/pos_defs.h"
#include "nvim/regexp.h"
#include "nvim/strings.h"
#include "nvim/types_defs.h"
#include "nvim/usercmd.h"
#include "nvim/vim_defs.h"
#include "nvim/window.h"

#ifdef INCLUDE_GENERATED_DECLARATIONS
# include "api/command.c.generated.h"
#endif

/// Parse command line.
///
/// Doesn't check the validity of command arguments.
///
/// @param str       Command line string to parse. Cannot contain "\n".
/// @param opts      Optional parameters. Reserved for future use.
/// @param[out] err  Error details, if any.
/// @return Dict containing command information, with these keys:
///         - cmd: (string) Command name.
///         - range: (array) (optional) Command range ([<line1>] [<line2>]).
///                          Omitted if command doesn't accept a range.
///                          Otherwise, has no elements if no range was specified, one element if
///                          only a single range item was specified, or two elements if both range
///                          items were specified.
///         - count: (number) (optional) Command [<count>].
///                           Omitted if command cannot take a count.
///         - reg: (string) (optional) Command [<register>].
///                         Omitted if command cannot take a register.
///         - bang: (boolean) Whether command contains a [<bang>] (!) modifier.
///         - args: (array) Command arguments.
///         - addr: (string) Value of |:command-addr|. Uses short name or "line" for -addr=lines.
///         - nargs: (string) Value of |:command-nargs|.
///         - nextcmd: (string) Next command if there are multiple commands separated by a |:bar|.
///                             Empty if there isn't a next command.
///         - magic: (dict) Which characters have special meaning in the command arguments.
///             - file: (boolean) The command expands filenames. Which means characters such as "%",
///                               "#" and wildcards are expanded.
///             - bar: (boolean) The "|" character is treated as a command separator and the double
///                              quote character (") is treated as the start of a comment.
///         - mods: (dict) |:command-modifiers|.
///             - filter: (dict) |:filter|.
///                 - pattern: (string) Filter pattern. Empty string if there is no filter.
///                 - force: (boolean) Whether filter is inverted or not.
///             - silent: (boolean) |:silent|.
///             - emsg_silent: (boolean) |:silent!|.
///             - unsilent: (boolean) |:unsilent|.
///             - sandbox: (boolean) |:sandbox|.
///             - noautocmd: (boolean) |:noautocmd|.
///             - browse: (boolean) |:browse|.
///             - confirm: (boolean) |:confirm|.
///             - hide: (boolean) |:hide|.
///             - horizontal: (boolean) |:horizontal|.
///             - keepalt: (boolean) |:keepalt|.
///             - keepjumps: (boolean) |:keepjumps|.
///             - keepmarks: (boolean) |:keepmarks|.
///             - keeppatterns: (boolean) |:keeppatterns|.
///             - lockmarks: (boolean) |:lockmarks|.
///             - noswapfile: (boolean) |:noswapfile|.
///             - tab: (integer) |:tab|. -1 when omitted.
///             - verbose: (integer) |:verbose|. -1 when omitted.
///             - vertical: (boolean) |:vertical|.
///             - split: (string) Split modifier string, is an empty string when there's no split
///                               modifier. If there is a split modifier it can be one of:
///               - "aboveleft": |:aboveleft|.
///               - "belowright": |:belowright|.
///               - "topleft": |:topleft|.
///               - "botright": |:botright|.
Dict(cmd) nvim_parse_cmd(String str, Dict(empty) *opts, Arena *arena, Error *err)
  FUNC_API_SINCE(10) FUNC_API_FAST
{
  Dict(cmd) result = KEYDICT_INIT;

  // Parse command line
  exarg_T ea;
  CmdParseInfo cmdinfo;
  char *cmdline = arena_memdupz(arena, str.data, str.size);
  const char *errormsg = NULL;

  if (!parse_cmdline(cmdline, &ea, &cmdinfo, &errormsg)) {
    if (errormsg != NULL) {
      api_set_error(err, kErrorTypeException, "Parsing command-line: %s", errormsg);
    } else {
      api_set_error(err, kErrorTypeException, "Parsing command-line");
    }
    goto end;
  }

  // Parse arguments
  Array args = ARRAY_DICT_INIT;
  size_t length = strlen(ea.arg);

  // For nargs = 1 or '?', pass the entire argument list as a single argument,
  // otherwise split arguments by whitespace.
  if (ea.argt & EX_NOSPC) {
    if (*ea.arg != NUL) {
      args = arena_array(arena, 1);
      ADD_C(args, STRING_OBJ(cstrn_as_string(ea.arg, length)));
    }
  } else {
    size_t end = 0;
    size_t len = 0;
    char *buf = arena_alloc(arena, length + 1, false);
    bool done = false;
    args = arena_array(arena, uc_nargs_upper_bound(ea.arg, length));

    while (!done) {
      done = uc_split_args_iter(ea.arg, length, &end, buf, &len);
      if (len > 0) {
        ADD_C(args, STRING_OBJ(cstrn_as_string(buf, len)));
        buf += len + 1;
      }
    }
  }

  ucmd_T *cmd = NULL;
  if (ea.cmdidx == CMD_USER) {
    cmd = USER_CMD(ea.useridx);
  } else if (ea.cmdidx == CMD_USER_BUF) {
    cmd = USER_CMD_GA(&curbuf->b_ucmds, ea.useridx);
  }

  char *name = (cmd != NULL ? cmd->uc_name : get_command_name(NULL, ea.cmdidx));
  PUT_KEY(result, cmd, cmd, cstr_as_string(name));

  if ((ea.argt & EX_RANGE) && ea.addr_count > 0) {
    Array range = arena_array(arena, 2);
    if (ea.addr_count > 1) {
      ADD_C(range, INTEGER_OBJ(ea.line1));
    }
    ADD_C(range, INTEGER_OBJ(ea.line2));
    PUT_KEY(result, cmd, range, range);
  }

  if (ea.argt & EX_COUNT) {
    Integer count = ea.addr_count > 0 ? ea.line2 : (cmd != NULL ? cmd->uc_def : 0);
    PUT_KEY(result, cmd, count, count);
  }

  if (ea.argt & EX_REGSTR) {
    char reg[2] = { (char)ea.regname, NUL };
    PUT_KEY(result, cmd, reg, CSTR_TO_ARENA_STR(arena, reg));
  }

  PUT_KEY(result, cmd, bang, ea.forceit);
  PUT_KEY(result, cmd, args, args);

  char nargs[2];
  if (ea.argt & EX_EXTRA) {
    if (ea.argt & EX_NOSPC) {
      if (ea.argt & EX_NEEDARG) {
        nargs[0] = '1';
      } else {
        nargs[0] = '?';
      }
    } else if (ea.argt & EX_NEEDARG) {
      nargs[0] = '+';
    } else {
      nargs[0] = '*';
    }
  } else {
    nargs[0] = '0';
  }
  nargs[1] = NUL;
  PUT_KEY(result, cmd, nargs, CSTR_TO_ARENA_OBJ(arena, nargs));

  char *addr;
  switch (ea.addr_type) {
  case ADDR_LINES:
    addr = "line";
    break;
  case ADDR_ARGUMENTS:
    addr = "arg";
    break;
  case ADDR_BUFFERS:
    addr = "buf";
    break;
  case ADDR_LOADED_BUFFERS:
    addr = "load";
    break;
  case ADDR_WINDOWS:
    addr = "win";
    break;
  case ADDR_TABS:
    addr = "tab";
    break;
  case ADDR_QUICKFIX:
    addr = "qf";
    break;
  case ADDR_NONE:
    addr = "none";
    break;
  default:
    addr = "?";
    break;
  }
  PUT_KEY(result, cmd, addr, cstr_as_string(addr));
  PUT_KEY(result, cmd, nextcmd, cstr_as_string(ea.nextcmd));

  // TODO(bfredl): nested keydict would be nice..
  Dict mods = arena_dict(arena, 20);

  Dict filter = arena_dict(arena, 2);
  PUT_C(filter, "pattern", CSTR_TO_ARENA_OBJ(arena, cmdinfo.cmdmod.cmod_filter_pat));
  PUT_C(filter, "force", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_filter_force));
  PUT_C(mods, "filter", DICT_OBJ(filter));

  PUT_C(mods, "silent", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_SILENT));
  PUT_C(mods, "emsg_silent", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_ERRSILENT));
  PUT_C(mods, "unsilent", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_UNSILENT));
  PUT_C(mods, "sandbox", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_SANDBOX));
  PUT_C(mods, "noautocmd", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_NOAUTOCMD));
  PUT_C(mods, "tab", INTEGER_OBJ(cmdinfo.cmdmod.cmod_tab - 1));
  PUT_C(mods, "verbose", INTEGER_OBJ(cmdinfo.cmdmod.cmod_verbose - 1));
  PUT_C(mods, "browse", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_BROWSE));
  PUT_C(mods, "confirm", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_CONFIRM));
  PUT_C(mods, "hide", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_HIDE));
  PUT_C(mods, "keepalt", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_KEEPALT));
  PUT_C(mods, "keepjumps", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_KEEPJUMPS));
  PUT_C(mods, "keepmarks", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_KEEPMARKS));
  PUT_C(mods, "keeppatterns", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_KEEPPATTERNS));
  PUT_C(mods, "lockmarks", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_LOCKMARKS));
  PUT_C(mods, "noswapfile", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_flags & CMOD_NOSWAPFILE));
  PUT_C(mods, "vertical", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_split & WSP_VERT));
  PUT_C(mods, "horizontal", BOOLEAN_OBJ(cmdinfo.cmdmod.cmod_split & WSP_HOR));

  char *split;
  if (cmdinfo.cmdmod.cmod_split & WSP_BOT) {
    split = "botright";
  } else if (cmdinfo.cmdmod.cmod_split & WSP_TOP) {
    split = "topleft";
  } else if (cmdinfo.cmdmod.cmod_split & WSP_BELOW) {
    split = "belowright";
  } else if (cmdinfo.cmdmod.cmod_split & WSP_ABOVE) {
    split = "aboveleft";
  } else {
    split = "";
  }
  PUT_C(mods, "split", CSTR_AS_OBJ(split));

  PUT_KEY(result, cmd, mods, mods);

  Dict magic = arena_dict(arena, 2);
  PUT_C(magic, "file", BOOLEAN_OBJ(cmdinfo.magic.file));
  PUT_C(magic, "bar", BOOLEAN_OBJ(cmdinfo.magic.bar));
  PUT_KEY(result, cmd, magic, magic);

  undo_cmdmod(&cmdinfo.cmdmod);
end:
  return result;
}

/// Executes an Ex command.
///
/// Unlike |nvim_command()| this command takes a structured Dict instead of a String. This
/// allows for easier construction and manipulation of an Ex command. This also allows for things
/// such as having spaces inside a command argument, expanding filenames in a command that otherwise
/// doesn't expand filenames, etc. Command arguments may also be Number, Boolean or String.
///
/// The first argument may also be used instead of count for commands that support it in order to
/// make their usage simpler with |vim.cmd()|. For example, instead of
/// `vim.cmd.bdelete{ count = 2 }`, you may do `vim.cmd.bdelete(2)`.
///
/// On execution error: fails with Vimscript error, updates v:errmsg.
///
/// @see |nvim_exec2()|
/// @see |nvim_command()|
///
/// @param cmd       Command to execute. Must be a Dict that can contain the same values as
///                  the return value of |nvim_parse_cmd()| except "addr", "nargs" and "nextcmd"
///                  which are ignored if provided. All values except for "cmd" are optional.
/// @param opts      Optional parameters.
///                  - output: (boolean, default false) Whether to return command output.
/// @param[out] err  Error details, if any.
/// @return Command output (non-error, non-shell |:!|) if `output` is true, else empty string.
String nvim_cmd(uint64_t channel_id, Dict(cmd) *cmd, Dict(cmd_opts) *opts, Arena *arena, Error *err)
  FUNC_API_SINCE(10)
{
  exarg_T ea;
  CLEAR_FIELD(ea);

  CmdParseInfo cmdinfo;
  CLEAR_FIELD(cmdinfo);

  char *cmdline = NULL;
  char *cmdname = NULL;
  ArrayOf(String) args = ARRAY_DICT_INIT;

  String retv = (String)STRING_INIT;

#define OBJ_TO_BOOL(var, value, default, varname) \
  do { \
    (var) = api_object_to_bool(value, varname, default, err); \
    if (ERROR_SET(err)) { \
      goto end; \
    } \
  } while (0)

#define VALIDATE_MOD(cond, mod_, name_) \
  do { \
    if (!(cond)) { \
      api_set_error(err, kErrorTypeValidation, "Command cannot accept %s: %s", (mod_), (name_)); \
      goto end; \
    } \
  } while (0)

  VALIDATE_R(HAS_KEY(cmd, cmd, cmd), "cmd", {
    goto end;
  });
  VALIDATE_EXP((cmd->cmd.data[0] != NUL), "cmd", "non-empty String", NULL, {
    goto end;
  });

  cmdname = arena_string(arena, cmd->cmd).data;
  ea.cmd = cmdname;

  char *p = find_ex_command(&ea, NULL);

  // If this looks like an undefined user command and there are CmdUndefined
  // autocommands defined, trigger the matching autocommands.
  if (p != NULL && ea.cmdidx == CMD_SIZE && ASCII_ISUPPER(*ea.cmd)
      && has_event(EVENT_CMDUNDEFINED)) {
    p = arena_string(arena, cmd->cmd).data;
    int ret = apply_autocmds(EVENT_CMDUNDEFINED, p, p, true, NULL);
    // If the autocommands did something and didn't cause an error, try
    // finding the command again.
    p = (ret && !aborting()) ? find_ex_command(&ea, NULL) : ea.cmd;
  }

  VALIDATE((p != NULL && ea.cmdidx != CMD_SIZE), "Command not found: %s", cmdname, {
    goto end;
  });
  VALIDATE(!is_cmd_ni(ea.cmdidx), "Command not implemented: %s", cmdname, {
    goto end;
  });
  const char *fullname = IS_USER_CMDIDX(ea.cmdidx)
                         ? get_user_command_name(ea.useridx, ea.cmdidx)
                         : get_command_name(NULL, ea.cmdidx);
  VALIDATE(strncmp(fullname, cmdname, strlen(cmdname)) == 0, "Invalid command: \"%s\"", cmdname, {
    goto end;
  });

  // Get the command flags so that we can know what type of arguments the command uses.
  // Not required for a user command since `find_ex_command` already deals with it in that case.
  if (!IS_USER_CMDIDX(ea.cmdidx)) {
    ea.argt = get_cmd_argt(ea.cmdidx);
  }

  // Parse command arguments since it's needed to get the command address type.
  if (HAS_KEY(cmd, cmd, args)) {
    // Process all arguments. Convert non-String arguments to String and check if String arguments
    // have non-whitespace characters.
    args = arena_array(arena, cmd->args.size);
    for (size_t i = 0; i < cmd->args.size; i++) {
      Object elem = cmd->args.items[i];
      char *data_str;

      switch (elem.type) {
      case kObjectTypeBoolean:
        data_str = arena_alloc(arena, 2, false);
        data_str[0] = elem.data.boolean ? '1' : '0';
        data_str[1] = NUL;
        ADD_C(args, CSTR_AS_OBJ(data_str));
        break;
      case kObjectTypeBuffer:
      case kObjectTypeWindow:
      case kObjectTypeTabpage:
      case kObjectTypeInteger:
        data_str = arena_alloc(arena, NUMBUFLEN, false);
        snprintf(data_str, NUMBUFLEN, "%" PRId64, elem.data.integer);
        ADD_C(args, CSTR_AS_OBJ(data_str));
        break;
      case kObjectTypeString:
        VALIDATE_EXP(!string_iswhite(elem.data.string), "command arg", "non-whitespace", NULL, {
          goto end;
        });
        ADD_C(args, elem);
        break;
      default:
        VALIDATE_EXP(false, "command arg", "valid type", api_typename(elem.type), {
          goto end;
        });
        break;
      }
    }

    bool argc_valid;

    // Check if correct number of arguments is used.
    switch (ea.argt & (EX_EXTRA | EX_NOSPC | EX_NEEDARG)) {
    case EX_EXTRA | EX_NOSPC | EX_NEEDARG:
      argc_valid = args.size == 1;
      break;
    case EX_EXTRA | EX_NOSPC:
      argc_valid = args.size <= 1;
      break;
    case EX_EXTRA | EX_NEEDARG:
      argc_valid = args.size >= 1;
      break;
    case EX_EXTRA:
      argc_valid = true;
      break;
    default:
      argc_valid = args.size == 0;
      break;
    }

    VALIDATE(argc_valid, "%s", "Wrong number of arguments", {
      goto end;
    });
  }

  // Simply pass the first argument (if it exists) as the arg pointer to `set_cmd_addr_type()`
  // since it only ever checks the first argument.
  set_cmd_addr_type(&ea, args.size > 0 ? args.items[0].data.string.data : NULL);

  if (HAS_KEY(cmd, cmd, range)) {
    VALIDATE_MOD((ea.argt & EX_RANGE), "range", cmd->cmd.data);
    VALIDATE_EXP((cmd->range.size <= 2), "range", "<=2 elements", NULL, {
      goto end;
    });

    Array range = cmd->range;
    ea.addr_count = (int)range.size;

    for (size_t i = 0; i < range.size; i++) {
      Object elem = range.items[i];
      VALIDATE_EXP((elem.type == kObjectTypeInteger && elem.data.integer >= 0),
                   "range element", "non-negative Integer", NULL, {
        goto end;
      });
    }

    if (range.size > 0) {
      ea.line1 = (linenr_T)range.items[0].data.integer;
      ea.line2 = (linenr_T)range.items[range.size - 1].data.integer;
    }

    VALIDATE_S((invalid_range(&ea) == NULL), "range", "", {
      goto end;
    });
  }
  if (ea.addr_count == 0) {
    if (ea.argt & EX_DFLALL) {
      set_cmd_dflall_range(&ea);  // Default range for range=%
    } else {
      ea.line1 = ea.line2 = get_cmd_default_range(&ea);  // Default range.

      if (ea.addr_type == ADDR_OTHER) {
        // Default is 1, not cursor.
        ea.line2 = 1;
      }
    }
  }

  if (HAS_KEY(cmd, cmd, count)) {
    VALIDATE_MOD((ea.argt & EX_COUNT), "count", cmd->cmd.data);
    VALIDATE_EXP((cmd->count >= 0), "count", "non-negative Integer", NULL, {
      goto end;
    });
    set_cmd_count(&ea, (linenr_T)cmd->count, true);
  }

  if (HAS_KEY(cmd, cmd, reg)) {
    VALIDATE_MOD((ea.argt & EX_REGSTR), "register", cmd->cmd.data);
    VALIDATE_EXP((cmd->reg.size == 1),
                 "reg", "single character", cmd->reg.data, {
      goto end;
    });
    char regname = cmd->reg.data[0];
    VALIDATE((regname != '='), "%s", "Cannot use register \"=", {
      goto end;
    });
    VALIDATE(valid_yank_reg(regname,
                            (!IS_USER_CMDIDX(ea.cmdidx)
                             && ea.cmdidx != CMD_put && ea.cmdidx != CMD_iput)),
             "Invalid register: \"%c", regname, {
      goto end;
    });
    ea.regname = (uint8_t)regname;
  }

  ea.forceit = cmd->bang;
  VALIDATE_MOD((!ea.forceit || (ea.argt & EX_BANG)), "bang", cmd->cmd.data);

  if (HAS_KEY(cmd, cmd, magic)) {
    Dict(cmd_magic) magic[1] = KEYDICT_INIT;
    if (!api_dict_to_keydict(magic, DictHash(cmd_magic), cmd->magic, err)) {
      goto end;
    }

    cmdinfo.magic.file = HAS_KEY(magic, cmd_magic, file) ? magic->file : (ea.argt & EX_XFILE);
    cmdinfo.magic.bar = HAS_KEY(magic, cmd_magic, bar) ? magic->bar : (ea.argt & EX_TRLBAR);
    if (cmdinfo.magic.file) {
      ea.argt |= EX_XFILE;
    } else {
      ea.argt &= ~EX_XFILE;
    }
  } else {
    cmdinfo.magic.file = ea.argt & EX_XFILE;
    cmdinfo.magic.bar = ea.argt & EX_TRLBAR;
  }

  if (HAS_KEY(cmd, cmd, mods)) {
    Dict(cmd_mods) mods[1] = KEYDICT_INIT;
    if (!api_dict_to_keydict(mods, DictHash(cmd_mods), cmd->mods, err)) {
      goto end;
    }

    if (HAS_KEY(mods, cmd_mods, filter)) {
      Dict(cmd_mods_filter) filter[1] = KEYDICT_INIT;

      if (!api_dict_to_keydict(&filter, DictHash(cmd_mods_filter),
                               mods->filter, err)) {
        goto end;
      }

      if (HAS_KEY(filter, cmd_mods_filter, pattern)) {
        cmdinfo.cmdmod.cmod_filter_force = filter->force;

        // "filter! // is not no-op, so add a filter if either the pattern is non-empty or if filter
        // is inverted.
        if (*filter->pattern.data != NUL || cmdinfo.cmdmod.cmod_filter_force) {
          cmdinfo.cmdmod.cmod_filter_pat = string_to_cstr(filter->pattern);
          cmdinfo.cmdmod.cmod_filter_regmatch.regprog = vim_regcomp(cmdinfo.cmdmod.cmod_filter_pat,
                                                                    RE_MAGIC);
        }
      }
    }

    if (HAS_KEY(mods, cmd_mods, tab)) {
      if ((int)mods->tab >= 0) {
        // Silently ignore negative integers to allow mods.tab to be set to -1.
        cmdinfo.cmdmod.cmod_tab = (int)mods->tab + 1;
      }
    }

    if (HAS_KEY(mods, cmd_mods, verbose)) {
      if ((int)mods->verbose >= 0) {
        // Silently ignore negative integers to allow mods.verbose to be set to -1.
        cmdinfo.cmdmod.cmod_verbose = (int)mods->verbose + 1;
      }
    }

    cmdinfo.cmdmod.cmod_split |= (mods->vertical ? WSP_VERT : 0);

    cmdinfo.cmdmod.cmod_split |= (mods->horizontal ? WSP_HOR : 0);

    if (HAS_KEY(mods, cmd_mods, split)) {
      if (*mods->split.data == NUL) {
        // Empty string, do nothing.
      } else if (strcmp(mods->split.data, "aboveleft") == 0
                 || strcmp(mods->split.data, "leftabove") == 0) {
        cmdinfo.cmdmod.cmod_split |= WSP_ABOVE;
      } else if (strcmp(mods->split.data, "belowright") == 0
                 || strcmp(mods->split.data, "rightbelow") == 0) {
        cmdinfo.cmdmod.cmod_split |= WSP_BELOW;
      } else if (strcmp(mods->split.data, "topleft") == 0) {
        cmdinfo.cmdmod.cmod_split |= WSP_TOP;
      } else if (strcmp(mods->split.data, "botright") == 0) {
        cmdinfo.cmdmod.cmod_split |= WSP_BOT;
      } else {
        VALIDATE_S(false, "mods.split", "", {
          goto end;
        });
      }
    }

#define OBJ_TO_CMOD_FLAG(flag, value) \
  if (value) { \
    cmdinfo.cmdmod.cmod_flags |= (flag); \
  }

    OBJ_TO_CMOD_FLAG(CMOD_SILENT, mods->silent);
    OBJ_TO_CMOD_FLAG(CMOD_ERRSILENT, mods->emsg_silent);
    OBJ_TO_CMOD_FLAG(CMOD_UNSILENT, mods->unsilent);
    OBJ_TO_CMOD_FLAG(CMOD_SANDBOX, mods->sandbox);
    OBJ_TO_CMOD_FLAG(CMOD_NOAUTOCMD, mods->noautocmd);
    OBJ_TO_CMOD_FLAG(CMOD_BROWSE, mods->browse);
    OBJ_TO_CMOD_FLAG(CMOD_CONFIRM, mods->confirm);
    OBJ_TO_CMOD_FLAG(CMOD_HIDE, mods->hide);
    OBJ_TO_CMOD_FLAG(CMOD_KEEPALT, mods->keepalt);
    OBJ_TO_CMOD_FLAG(CMOD_KEEPJUMPS, mods->keepjumps);
    OBJ_TO_CMOD_FLAG(CMOD_KEEPMARKS, mods->keepmarks);
    OBJ_TO_CMOD_FLAG(CMOD_KEEPPATTERNS, mods->keeppatterns);
    OBJ_TO_CMOD_FLAG(CMOD_LOCKMARKS, mods->lockmarks);
    OBJ_TO_CMOD_FLAG(CMOD_NOSWAPFILE, mods->noswapfile);

    if (cmdinfo.cmdmod.cmod_flags & CMOD_ERRSILENT) {
      // CMOD_ERRSILENT must imply CMOD_SILENT, otherwise apply_cmdmod() and undo_cmdmod() won't
      // work properly.
      cmdinfo.cmdmod.cmod_flags |= CMOD_SILENT;
    }

    VALIDATE(!((cmdinfo.cmdmod.cmod_flags & CMOD_SANDBOX) && !(ea.argt & EX_SBOXOK)),
             "%s", "Command cannot be run in sandbox", {
      goto end;
    });
  }

  // Finally, build the command line string that will be stored inside ea.cmdlinep.
  // This also sets the values of ea.cmd, ea.arg, ea.args and ea.arglens.
  build_cmdline_str(&cmdline, &ea, &cmdinfo, args);
  ea.cmdlinep = &cmdline;

  garray_T capture_local;
  const int save_msg_silent = msg_silent;
  garray_T * const save_capture_ga = capture_ga;
  const int save_msg_col = msg_col;

  if (opts->output) {
    ga_init(&capture_local, 1, 80);
    capture_ga = &capture_local;
  }

  TRY_WRAP(err, {
    if (opts->output) {
      msg_silent++;
      msg_col = 0;  // prevent leading spaces
    }

    WITH_SCRIPT_CONTEXT(channel_id, {
      execute_cmd(&ea, &cmdinfo, false);
    });

    if (opts->output) {
      capture_ga = save_capture_ga;
      msg_silent = save_msg_silent;
      // Put msg_col back where it was, since nothing should have been written.
      msg_col = save_msg_col;
    }
  });

  if (ERROR_SET(err)) {
    goto clear_ga;
  }

  if (opts->output && capture_local.ga_len > 1) {
    // TODO(bfredl): if there are more cases like this we might want custom xfree-list in arena
    retv = CBUF_TO_ARENA_STR(arena, capture_local.ga_data, (size_t)capture_local.ga_len);
    // redir usually (except :echon) prepends a newline.
    if (retv.data[0] == '\n') {
      retv.data++;
      retv.size--;
    }
  }
clear_ga:
  if (opts->output) {
    ga_clear(&capture_local);
  }
end:
  xfree(cmdline);
  xfree(ea.args);
  xfree(ea.arglens);

  return retv;

#undef OBJ_TO_BOOL
#undef OBJ_TO_CMOD_FLAG
#undef VALIDATE_MOD
}

/// Check if a string contains only whitespace characters.
static bool string_iswhite(String str)
{
  for (size_t i = 0; i < str.size; i++) {
    if (!ascii_iswhite(str.data[i])) {
      // Found a non-whitespace character
      return false;
    } else if (str.data[i] == NUL) {
      // Terminate at first occurrence of a NUL character
      break;
    }
  }
  return true;
}

/// Build cmdline string for command, used by `nvim_cmd()`.
static void build_cmdline_str(char **cmdlinep, exarg_T *eap, CmdParseInfo *cmdinfo,
                              ArrayOf(String) args)
{
  size_t argc = args.size;
  StringBuilder cmdline = KV_INITIAL_VALUE;
  kv_resize(cmdline, 32);  // Make it big enough to handle most typical commands

  // Add command modifiers
  if (cmdinfo->cmdmod.cmod_tab != 0) {
    kv_printf(cmdline, "%dtab ", cmdinfo->cmdmod.cmod_tab - 1);
  }
  if (cmdinfo->cmdmod.cmod_verbose > 0) {
    kv_printf(cmdline, "%dverbose ", cmdinfo->cmdmod.cmod_verbose - 1);
  }

  if (cmdinfo->cmdmod.cmod_flags & CMOD_ERRSILENT) {
    kv_concat(cmdline, "silent! ");
  } else if (cmdinfo->cmdmod.cmod_flags & CMOD_SILENT) {
    kv_concat(cmdline, "silent ");
  }

  if (cmdinfo->cmdmod.cmod_flags & CMOD_UNSILENT) {
    kv_concat(cmdline, "unsilent ");
  }

  switch (cmdinfo->cmdmod.cmod_split & (WSP_ABOVE | WSP_BELOW | WSP_TOP | WSP_BOT)) {
  case WSP_ABOVE:
    kv_concat(cmdline, "aboveleft ");
    break;
  case WSP_BELOW:
    kv_concat(cmdline, "belowright ");
    break;
  case WSP_TOP:
    kv_concat(cmdline, "topleft ");
    break;
  case WSP_BOT:
    kv_concat(cmdline, "botright ");
    break;
  default:
    break;
  }

#define CMDLINE_APPEND_IF(cond, str) \
  do { \
    if (cond) { \
      kv_concat(cmdline, str); \
    } \
  } while (0)

  CMDLINE_APPEND_IF(cmdinfo->cmdmod.cmod_split & WSP_VERT, "vertical ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.cmod_split & WSP_HOR, "horizontal ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.cmod_flags & CMOD_SANDBOX, "sandbox ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.cmod_flags & CMOD_NOAUTOCMD, "noautocmd ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.cmod_flags & CMOD_BROWSE, "browse ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.cmod_flags & CMOD_CONFIRM, "confirm ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.cmod_flags & CMOD_HIDE, "hide ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.cmod_flags & CMOD_KEEPALT, "keepalt ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.cmod_flags & CMOD_KEEPJUMPS, "keepjumps ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.cmod_flags & CMOD_KEEPMARKS, "keepmarks ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.cmod_flags & CMOD_KEEPPATTERNS, "keeppatterns ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.cmod_flags & CMOD_LOCKMARKS, "lockmarks ");
  CMDLINE_APPEND_IF(cmdinfo->cmdmod.cmod_flags & CMOD_NOSWAPFILE, "noswapfile ");
#undef CMDLINE_APPEND_IF

  // Command range / count.
  if (eap->argt & EX_RANGE) {
    if (eap->addr_count == 1) {
      kv_printf(cmdline, "%" PRIdLINENR, eap->line2);
    } else if (eap->addr_count > 1) {
      kv_printf(cmdline, "%" PRIdLINENR ",%" PRIdLINENR, eap->line1, eap->line2);
      eap->addr_count = 2;  // Make sure address count is not greater than 2
    }
  }

  // Keep the index of the position where command name starts, so eap->cmd can point to it.
  size_t cmdname_idx = cmdline.size;
  kv_concat(cmdline, eap->cmd);

  // Command bang.
  if (eap->argt & EX_BANG && eap->forceit) {
    kv_concat(cmdline, "!");
  }

  // Command register.
  if (eap->argt & EX_REGSTR && eap->regname) {
    kv_printf(cmdline, " %c", eap->regname);
  }

  eap->argc = argc;
  eap->arglens = eap->argc > 0 ? xcalloc(argc, sizeof(size_t)) : NULL;
  size_t argstart_idx = cmdline.size;
  for (size_t i = 0; i < argc; i++) {
    String s = args.items[i].data.string;
    eap->arglens[i] = s.size;
    kv_concat(cmdline, " ");
    kv_concat_len(cmdline, s.data, s.size);
  }

  // Done appending to cmdline, ensure it is NUL terminated
  kv_push(cmdline, NUL);

  // Now that all the arguments are appended, use the command index and argument indices to set the
  // values of eap->cmd, eap->arg and eap->args.
  eap->cmd = cmdline.items + cmdname_idx;
  eap->args = eap->argc > 0 ? xcalloc(argc, sizeof(char *)) : NULL;
  size_t offset = argstart_idx;
  for (size_t i = 0; i < argc; i++) {
    offset++;  // Account for space
    eap->args[i] = cmdline.items + offset;
    offset += eap->arglens[i];
  }
  // If there isn't an argument, make eap->arg point to end of cmdline.
  eap->arg = argc > 0 ? eap->args[0]
                      : cmdline.items + cmdline.size - 1;  // Subtract 1 to account for NUL

  // Finally, make cmdlinep point to the cmdline string.
  *cmdlinep = cmdline.items;

  // Replace, :make and :grep with 'makeprg' and 'grepprg'.
  char *p = replace_makeprg(eap, eap->arg, cmdlinep);
  if (p != eap->arg) {
    // If replace_makeprg() modified the cmdline string, correct the eap->arg pointer.
    eap->arg = p;
    // This cannot be a user command, so eap->args will not be used.
    XFREE_CLEAR(eap->args);
    XFREE_CLEAR(eap->arglens);
    eap->argc = 0;
  }
}

/// Creates a global |user-commands| command.
///
/// For Lua usage see |lua-guide-commands-create|.
///
/// Example:
///
/// ```vim
/// :call nvim_create_user_command('SayHello', 'echo "Hello world!"', {'bang': v:true})
/// :SayHello
/// Hello world!
/// ```
///
/// @param  name    Name of the new user command. Must begin with an uppercase letter.
/// @param  command Replacement command to execute when this user command is executed. When called
///                 from Lua, the command can also be a Lua function. The function is called with a
///                 single table argument that contains the following keys:
///                 - name: (string) Command name
///                 - args: (string) The args passed to the command, if any [<args>]
///                 - fargs: (table) The args split by unescaped whitespace (when more than one
///                 argument is allowed), if any [<f-args>]
///                 - nargs: (string) Number of arguments |:command-nargs|
///                 - bang: (boolean) "true" if the command was executed with a ! modifier [<bang>]
///                 - line1: (number) The starting line of the command range [<line1>]
///                 - line2: (number) The final line of the command range [<line2>]
///                 - range: (number) The number of items in the command range: 0, 1, or 2 [<range>]
///                 - count: (number) Any count supplied [<count>]
///                 - reg: (string) The optional register, if specified [<reg>]
///                 - mods: (string) Command modifiers, if any [<mods>]
///                 - smods: (table) Command modifiers in a structured format. Has the same
///                 structure as the "mods" key of |nvim_parse_cmd()|.
/// @param  opts    Optional |command-attributes|.
///                 - Set boolean attributes such as |:command-bang| or |:command-bar| to true (but
///                   not |:command-buffer|, use |nvim_buf_create_user_command()| instead).
///                 - "complete" |:command-complete| also accepts a Lua function which works like
///                   |:command-completion-customlist|.
///                 - Other parameters:
///                   - desc: (string) Used for listing the command when a Lua function is used for
///                                    {command}.
///                   - force: (boolean, default true) Override any previous definition.
///                   - preview: (function) Preview callback for 'inccommand' |:command-preview|
/// @param[out] err Error details, if any.
void nvim_create_user_command(uint64_t channel_id, String name, Object command,
                              Dict(user_command) *opts, Error *err)
  FUNC_API_SINCE(9)
{
  create_user_command(channel_id, name, command, opts, 0, err);
}

/// Delete a user-defined command.
///
/// @param  name    Name of the command to delete.
/// @param[out] err Error details, if any.
void nvim_del_user_command(String name, Error *err)
  FUNC_API_SINCE(9)
{
  nvim_buf_del_user_command(-1, name, err);
}

/// Creates a buffer-local command |user-commands|.
///
/// @param  buffer  Buffer id, or 0 for current buffer.
/// @param[out] err Error details, if any.
/// @see nvim_create_user_command
void nvim_buf_create_user_command(uint64_t channel_id, Buffer buffer, String name, Object command,
                                  Dict(user_command) *opts, Error *err)
  FUNC_API_SINCE(9)
{
  buf_T *target_buf = find_buffer_by_handle(buffer, err);
  if (ERROR_SET(err)) {
    return;
  }

  buf_T *save_curbuf = curbuf;
  curbuf = target_buf;
  create_user_command(channel_id, name, command, opts, UC_BUFFER, err);
  curbuf = save_curbuf;
}

/// Delete a buffer-local user-defined command.
///
/// Only commands created with |:command-buffer| or
/// |nvim_buf_create_user_command()| can be deleted with this function.
///
/// @param  buffer  Buffer id, or 0 for current buffer.
/// @param  name    Name of the command to delete.
/// @param[out] err Error details, if any.
void nvim_buf_del_user_command(Buffer buffer, String name, Error *err)
  FUNC_API_SINCE(9)
{
  garray_T *gap;
  if (buffer == -1) {
    gap = &ucmds;
  } else {
    buf_T *buf = find_buffer_by_handle(buffer, err);
    if (ERROR_SET(err)) {
      return;
    }
    gap = &buf->b_ucmds;
  }

  for (int i = 0; i < gap->ga_len; i++) {
    ucmd_T *cmd = USER_CMD_GA(gap, i);
    if (!strcmp(name.data, cmd->uc_name)) {
      free_ucmd(cmd);

      gap->ga_len -= 1;

      if (i < gap->ga_len) {
        memmove(cmd, cmd + 1, (size_t)(gap->ga_len - i) * sizeof(ucmd_T));
      }

      return;
    }
  }

  api_set_error(err, kErrorTypeException, "Invalid command (not found): %s", name.data);
}

void create_user_command(uint64_t channel_id, String name, Object command, Dict(user_command) *opts,
                         int flags, Error *err)
{
  uint32_t argt = 0;
  int64_t def = -1;
  cmd_addr_T addr_type_arg = ADDR_NONE;
  int context = EXPAND_NOTHING;
  char *compl_arg = NULL;
  const char *rep = NULL;
  LuaRef luaref = LUA_NOREF;
  LuaRef compl_luaref = LUA_NOREF;
  LuaRef preview_luaref = LUA_NOREF;

  VALIDATE_S(uc_validate_name(name.data), "command name", name.data, {
    goto err;
  });
  VALIDATE_S(!mb_islower(name.data[0]), "command name (must start with uppercase)",
             name.data, {
    goto err;
  });
  VALIDATE((!HAS_KEY(opts, user_command, range) || !HAS_KEY(opts, user_command, count)), "%s",
           "Cannot use both 'range' and 'count'", {
    goto err;
  });

  if (opts->nargs.type == kObjectTypeInteger) {
    switch (opts->nargs.data.integer) {
    case 0:
      // Default value, nothing to do
      break;
    case 1:
      argt |= EX_EXTRA | EX_NOSPC | EX_NEEDARG;
      break;
    default:
      VALIDATE_INT(false, "nargs", (int64_t)opts->nargs.data.integer, {
        goto err;
      });
    }
  } else if (opts->nargs.type == kObjectTypeString) {
    VALIDATE_S((opts->nargs.data.string.size <= 1), "nargs", opts->nargs.data.string.data, {
      goto err;
    });

    switch (opts->nargs.data.string.data[0]) {
    case '*':
      argt |= EX_EXTRA;
      break;
    case '?':
      argt |= EX_EXTRA | EX_NOSPC;
      break;
    case '+':
      argt |= EX_EXTRA | EX_NEEDARG;
      break;
    default:
      VALIDATE_S(false, "nargs", opts->nargs.data.string.data, {
        goto err;
      });
    }
  } else if (HAS_KEY(opts, user_command, nargs)) {
    VALIDATE_S(false, "nargs", "", {
      goto err;
    });
  }

  VALIDATE((!HAS_KEY(opts, user_command, complete) || argt),
           "%s", "'complete' used without 'nargs'", {
    goto err;
  });

  if (opts->range.type == kObjectTypeBoolean) {
    if (opts->range.data.boolean) {
      argt |= EX_RANGE;
      addr_type_arg = ADDR_LINES;
    }
  } else if (opts->range.type == kObjectTypeString) {
    VALIDATE_S((opts->range.data.string.data[0] == '%' && opts->range.data.string.size == 1),
               "range", "", {
      goto err;
    });
    argt |= EX_RANGE | EX_DFLALL;
    addr_type_arg = ADDR_LINES;
  } else if (opts->range.type == kObjectTypeInteger) {
    argt |= EX_RANGE | EX_ZEROR;
    def = opts->range.data.integer;
    addr_type_arg = ADDR_LINES;
  } else if (HAS_KEY(opts, user_command, range)) {
    VALIDATE_S(false, "range", "", {
      goto err;
    });
  }

  if (opts->count.type == kObjectTypeBoolean) {
    if (opts->count.data.boolean) {
      argt |= EX_COUNT | EX_ZEROR | EX_RANGE;
      addr_type_arg = ADDR_OTHER;
      def = 0;
    }
  } else if (opts->count.type == kObjectTypeInteger) {
    argt |= EX_COUNT | EX_ZEROR | EX_RANGE;
    addr_type_arg = ADDR_OTHER;
    def = opts->count.data.integer;
  } else if (HAS_KEY(opts, user_command, count)) {
    VALIDATE_S(false, "count", "", {
      goto err;
    });
  }

  if (HAS_KEY(opts, user_command, addr)) {
    VALIDATE_T("addr", kObjectTypeString, opts->addr.type, {
      goto err;
    });

    VALIDATE_S(OK == parse_addr_type_arg(opts->addr.data.string.data,
                                         (int)opts->addr.data.string.size, &addr_type_arg), "addr",
               opts->addr.data.string.data, {
      goto err;
    });

    if (addr_type_arg != ADDR_LINES) {
      argt |= EX_ZEROR;
    }
  }

  if (opts->bang) {
    argt |= EX_BANG;
  }

  if (opts->bar) {
    argt |= EX_TRLBAR;
  }

  if (opts->register_) {
    argt |= EX_REGSTR;
  }

  if (opts->keepscript) {
    argt |= EX_KEEPSCRIPT;
  }

  bool force = GET_BOOL_OR_TRUE(opts, user_command, force);
  if (ERROR_SET(err)) {
    goto err;
  }

  if (opts->complete.type == kObjectTypeLuaRef) {
    context = EXPAND_USER_LUA;
    compl_luaref = opts->complete.data.luaref;
    opts->complete.data.luaref = LUA_NOREF;
  } else if (opts->complete.type == kObjectTypeString) {
    VALIDATE_S(OK == parse_compl_arg(opts->complete.data.string.data,
                                     (int)opts->complete.data.string.size, &context, &argt,
                                     &compl_arg),
               "complete", opts->complete.data.string.data, {
      goto err;
    });
  } else if (HAS_KEY(opts, user_command, complete)) {
    VALIDATE_EXP(false, "complete", "Function or String", NULL, {
      goto err;
    });
  }

  if (HAS_KEY(opts, user_command, preview)) {
    VALIDATE_T("preview", kObjectTypeLuaRef, opts->preview.type, {
      goto err;
    });

    argt |= EX_PREVIEW;
    preview_luaref = opts->preview.data.luaref;
    opts->preview.data.luaref = LUA_NOREF;
  }

  switch (command.type) {
  case kObjectTypeLuaRef:
    luaref = api_new_luaref(command.data.luaref);
    if (opts->desc.type == kObjectTypeString) {
      rep = opts->desc.data.string.data;
    } else {
      rep = "";
    }
    break;
  case kObjectTypeString:
    rep = command.data.string.data;
    break;
  default:
    VALIDATE_EXP(false, "command", "Function or String", NULL, {
      goto err;
    });
  }

  WITH_SCRIPT_CONTEXT(channel_id, {
    if (uc_add_command(name.data, name.size, rep, argt, def, flags, context, compl_arg,
                       compl_luaref, preview_luaref, addr_type_arg, luaref, force) != OK) {
      api_set_error(err, kErrorTypeException, "Failed to create user command");
      // Do not goto err, since uc_add_command now owns luaref, compl_luaref, and compl_arg
    }
  });

  return;

err:
  NLUA_CLEAR_REF(luaref);
  NLUA_CLEAR_REF(compl_luaref);
  xfree(compl_arg);
}
/// Gets a map of global (non-buffer-local) Ex commands.
///
/// Currently only |user-commands| are supported, not builtin Ex commands.
///
/// @see |nvim_get_all_options_info()|
///
/// @param  opts  Optional parameters. Currently only supports
///               {"builtin":false}
/// @param[out]  err   Error details, if any.
///
/// @returns Map of maps describing commands.
Dict nvim_get_commands(Dict(get_commands) *opts, Arena *arena, Error *err)
  FUNC_API_SINCE(4)
{
  return nvim_buf_get_commands(-1, opts, arena, err);
}

/// Gets a map of buffer-local |user-commands|.
///
/// @param  buffer  Buffer id, or 0 for current buffer
/// @param  opts  Optional parameters. Currently not used.
/// @param[out]  err   Error details, if any.
///
/// @returns Map of maps describing commands.
Dict nvim_buf_get_commands(Buffer buffer, Dict(get_commands) *opts, Arena *arena, Error *err)
  FUNC_API_SINCE(4)
{
  bool global = (buffer == -1);
  if (ERROR_SET(err)) {
    return (Dict)ARRAY_DICT_INIT;
  }

  if (global) {
    if (opts->builtin) {
      api_set_error(err, kErrorTypeValidation, "builtin=true not implemented");
      return (Dict)ARRAY_DICT_INIT;
    }
    return commands_array(NULL, arena);
  }

  buf_T *buf = find_buffer_by_handle(buffer, err);
  if (opts->builtin || !buf) {
    return (Dict)ARRAY_DICT_INIT;
  }
  return commands_array(buf, arena);
}
