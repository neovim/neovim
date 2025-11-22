// register.c: functions for managing registers

#include "nvim/api/private/helpers.h"
#include "nvim/autocmd.h"
#include "nvim/buffer.h"
#include "nvim/buffer_defs.h"
#include "nvim/buffer_updates.h"
#include "nvim/change.h"
#include "nvim/charset.h"
#include "nvim/clipboard.h"
#include "nvim/cursor.h"
#include "nvim/drawscreen.h"
#include "nvim/edit.h"
#include "nvim/errors.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/ex_cmds2.h"
#include "nvim/ex_getln.h"
#include "nvim/extmark.h"
#include "nvim/file_search.h"
#include "nvim/fold.h"
#include "nvim/garray.h"
#include "nvim/getchar.h"
#include "nvim/globals.h"
#include "nvim/indent.h"
#include "nvim/keycodes.h"
#include "nvim/mark.h"
#include "nvim/mbyte.h"
#include "nvim/memline.h"
#include "nvim/message.h"
#include "nvim/move.h"
#include "nvim/normal.h"
#include "nvim/ops.h"
#include "nvim/option.h"
#include "nvim/option_vars.h"
#include "nvim/os/input.h"
#include "nvim/os/time.h"
#include "nvim/plines.h"
#include "nvim/register.h"
#include "nvim/search.h"
#include "nvim/strings.h"
#include "nvim/terminal.h"
#include "nvim/types_defs.h"
#include "nvim/ui.h"
#include "nvim/undo.h"

#include "register.c.generated.h"

// Keep the last expression line here, for repeating.
static char *expr_line = NULL;

static int execreg_lastc = NUL;

static yankreg_T y_regs[NUM_REGISTERS] = { 0 };

static yankreg_T *y_previous = NULL;  // ptr to last written yankreg

static const char e_search_pattern_and_expression_register_may_not_contain_two_or_more_lines[]
  = N_("E883: Search pattern and expression register may not contain two or more lines");

/// @return the index of the register "" points to.
int get_unname_register(void)
{
  return y_previous == NULL ? -1 : (int)(y_previous - &y_regs[0]);
}

yankreg_T *get_y_register(int reg)
{
  return &y_regs[reg];
}

yankreg_T *get_y_previous(void)
  FUNC_ATTR_PURE
{
  return y_previous;
}

/// Get an expression for the "\"=expr1" or "CTRL-R =expr1"
///
/// @return  '=' when OK, NUL otherwise.
int get_expr_register(void)
{
  char *new_line = getcmdline('=', 0, 0, true);
  if (new_line == NULL) {
    return NUL;
  }
  if (*new_line == NUL) {  // use previous line
    xfree(new_line);
  } else {
    set_expr_line(new_line);
  }
  return '=';
}

/// Set the expression for the '=' register.
/// Argument must be an allocated string.
void set_expr_line(char *new_line)
{
  xfree(expr_line);
  expr_line = new_line;
}

/// Get the result of the '=' register expression.
///
/// @return  a pointer to allocated memory, or NULL for failure.
char *get_expr_line(void)
{
  static int nested = 0;

  if (expr_line == NULL) {
    return NULL;
  }

  // Make a copy of the expression, because evaluating it may cause it to be
  // changed.
  char *expr_copy = xstrdup(expr_line);

  // When we are invoked recursively limit the evaluation to 10 levels.
  // Then return the string as-is.
  if (nested >= 10) {
    return expr_copy;
  }

  nested++;
  char *rv = eval_to_string(expr_copy, true, false);
  nested--;
  xfree(expr_copy);
  return rv;
}

/// Get the '=' register expression itself, without evaluating it.
char *get_expr_line_src(void)
{
  if (expr_line == NULL) {
    return NULL;
  }
  return xstrdup(expr_line);
}

/// @return  whether `regname` is a valid name of a yank register.
///
/// @note: There is no check for 0 (default register), caller should do this.
/// The black hole register '_' is regarded as valid.
///
/// @param regname name of register
/// @param writing allow only writable registers
bool valid_yank_reg(int regname, bool writing)
{
  if ((regname > 0 && ASCII_ISALNUM(regname))
      || (!writing && vim_strchr("/.%:=", regname) != NULL)
      || regname == '#'
      || regname == '"'
      || regname == '-'
      || regname == '_'
      || regname == '*'
      || regname == '+') {
    return true;
  }
  return false;
}

/// Check if the default register (used in an unnamed paste) should be a
/// clipboard register. This happens when `clipboard=unnamed[plus]` is set
/// and a provider is available.
///
/// @returns the name of of a clipboard register that should be used, or `NUL` if none.
int get_default_register_name(void)
{
  int name = NUL;
  adjust_clipboard_name(&name, true, false);
  return name;
}

/// Iterate over registers `regs`.
///
/// @param[in]   iter      Iterator. Pass NULL to start iteration.
/// @param[in]   regs      Registers list to be iterated.
/// @param[out]  name      Register name.
/// @param[out]  reg       Register contents.
///
/// @return Pointer that must be passed to next `op_register_iter` call or
///         NULL if iteration is over.
const void *op_reg_iter(const void *const iter, const yankreg_T *const regs, char *const name,
                        yankreg_T *const reg, bool *is_unnamed)
  FUNC_ATTR_NONNULL_ARG(3, 4, 5) FUNC_ATTR_WARN_UNUSED_RESULT
{
  *name = NUL;
  const yankreg_T *iter_reg = (iter == NULL
                               ? &(regs[0])
                               : (const yankreg_T *const)iter);
  while (iter_reg - &(regs[0]) < NUM_SAVED_REGISTERS && reg_empty(iter_reg)) {
    iter_reg++;
  }
  if (iter_reg - &(regs[0]) == NUM_SAVED_REGISTERS || reg_empty(iter_reg)) {
    return NULL;
  }
  int iter_off = (int)(iter_reg - &(regs[0]));
  *name = (char)get_register_name(iter_off);
  *reg = *iter_reg;
  *is_unnamed = (iter_reg == y_previous);
  while (++iter_reg - &(regs[0]) < NUM_SAVED_REGISTERS) {
    if (!reg_empty(iter_reg)) {
      return (void *)iter_reg;
    }
  }
  return NULL;
}

/// Iterate over global registers.
///
/// @see op_register_iter
const void *op_global_reg_iter(const void *const iter, char *const name, yankreg_T *const reg,
                               bool *is_unnamed)
  FUNC_ATTR_NONNULL_ARG(2, 3, 4) FUNC_ATTR_WARN_UNUSED_RESULT
{
  return op_reg_iter(iter, y_regs, name, reg, is_unnamed);
}

/// Get a number of non-empty registers
size_t op_reg_amount(void)
  FUNC_ATTR_WARN_UNUSED_RESULT
{
  size_t ret = 0;
  for (size_t i = 0; i < NUM_SAVED_REGISTERS; i++) {
    if (!reg_empty(y_regs + i)) {
      ret++;
    }
  }
  return ret;
}

/// Set register to a given value
///
/// @param[in]  name  Register name.
/// @param[in]  reg  Register value.
/// @param[in]  is_unnamed  Whether to set the unnamed regiseter to reg
///
/// @return true on success, false on failure.
bool op_reg_set(const char name, const yankreg_T reg, bool is_unnamed)
{
  int i = op_reg_index(name);
  if (i == -1) {
    return false;
  }
  free_register(&y_regs[i]);
  y_regs[i] = reg;

  if (is_unnamed) {
    y_previous = &y_regs[i];
  }
  return true;
}

/// Get register with the given name
///
/// @param[in]  name  Register name.
///
/// @return Pointer to the register contents or NULL.
const yankreg_T *op_reg_get(const char name)
{
  int i = op_reg_index(name);
  if (i == -1) {
    return NULL;
  }
  return &y_regs[i];
}

/// Set the previous yank register
///
/// @param[in]  name  Register name.
///
/// @return true on success, false on failure.
bool op_reg_set_previous(const char name)
{
  int i = op_reg_index(name);
  if (i == -1) {
    return false;
  }

  y_previous = &y_regs[i];
  return true;
}

/// Updates the "y_width" of a blockwise register based on its contents.
/// Do nothing on a non-blockwise register.
void update_yankreg_width(yankreg_T *reg)
{
  if (reg->y_type == kMTBlockWise) {
    size_t maxlen = 0;
    for (size_t i = 0; i < reg->y_size; i++) {
      size_t rowlen = mb_string2cells_len(reg->y_array[i].data, reg->y_array[i].size);
      maxlen = MAX(maxlen, rowlen);
    }
    assert(maxlen <= INT_MAX);
    reg->y_width = MAX(reg->y_width, (int)maxlen - 1);
  }
}

/// @return yankreg_T to use, according to the value of `regname`.
/// Cannot handle the '_' (black hole) register.
/// Must only be called with a valid register name!
///
/// @param regname The name of the register used or 0 for the unnamed register
/// @param mode One of the following three flags:
///
/// `YREG_PASTE`:
/// Prepare for pasting the register `regname`. With no regname specified,
/// read from last written register, or from unnamed clipboard (depending on the
/// `clipboard=unnamed` option). Queries the clipboard provider if necessary.
///
/// `YREG_YANK`:
/// Preparare for yanking into `regname`. With no regname specified,
/// yank into `"0` register. Update `y_previous` for next unnamed paste.
///
/// `YREG_PUT`:
/// Obtain the location that would be read when pasting `regname`.
yankreg_T *get_yank_register(int regname, int mode)
{
  yankreg_T *reg;

  if ((mode == YREG_PASTE || mode == YREG_PUT)
      && get_clipboard(regname, &reg, false)) {
    // reg is set to clipboard contents.
    return reg;
  } else if (mode == YREG_PUT && (regname == '*' || regname == '+')) {
    // in case clipboard not available and we aren't actually pasting,
    // return an empty register
    static yankreg_T empty_reg = { .y_array = NULL };
    return &empty_reg;
  } else if (mode != YREG_YANK
             && (regname == 0 || regname == '"' || regname == '*' || regname == '+')
             && y_previous != NULL) {
    // in case clipboard not available, paste from previous used register
    return y_previous;
  }

  int i = op_reg_index(regname);
  // when not 0-9, a-z, A-Z or '-'/'+'/'*': use register 0
  if (i == -1) {
    i = 0;
  }
  reg = &y_regs[i];

  if (mode == YREG_YANK) {
    // remember the written register for unnamed paste
    y_previous = reg;
  }
  return reg;
}

/// Check if the current yank register has kMTLineWise register type
/// For valid, non-blackhole registers also provides pointer to the register
/// structure prepared for pasting.
///
/// @param regname The name of the register used or 0 for the unnamed register
/// @param reg Pointer to store yankreg_T* for the requested register. Will be
///        set to NULL for invalid or blackhole registers.
bool yank_register_mline(int regname, yankreg_T **reg)
{
  *reg = NULL;
  if (regname != 0 && !valid_yank_reg(regname, false)) {
    return false;
  }
  if (regname == '_') {  // black hole is always empty
    return false;
  }
  *reg = get_yank_register(regname, YREG_PASTE);
  return (*reg)->y_type == kMTLineWise;
}

/// @return  a copy of contents in register `name` for use in do_put. Should be
///          freed by caller.
yankreg_T *copy_register(int name)
  FUNC_ATTR_NONNULL_RET
{
  yankreg_T *reg = get_yank_register(name, YREG_PASTE);

  yankreg_T *copy = xmalloc(sizeof(yankreg_T));
  *copy = *reg;
  if (copy->y_size == 0) {
    copy->y_array = NULL;
  } else {
    copy->y_array = xcalloc(copy->y_size, sizeof(String));
    for (size_t i = 0; i < copy->y_size; i++) {
      copy->y_array[i] = copy_string(reg->y_array[i], NULL);
    }
  }
  return copy;
}

/// Stuff string "p" into yank register "regname" as a single line (append if
/// uppercase). "p" must have been allocated.
///
/// @return  FAIL for failure, OK otherwise
static int stuff_yank(int regname, char *p)
{
  // check for read-only register
  if (regname != 0 && !valid_yank_reg(regname, true)) {
    xfree(p);
    return FAIL;
  }
  if (regname == '_') {             // black hole: don't do anything
    xfree(p);
    return OK;
  }

  const size_t plen = strlen(p);
  yankreg_T *reg = get_yank_register(regname, YREG_YANK);
  if (is_append_register(regname) && reg->y_array != NULL) {
    String *pp = &(reg->y_array[reg->y_size - 1]);
    const size_t tmplen = pp->size + plen;
    char *tmp = xmalloc(tmplen + 1);
    memcpy(tmp, pp->data, pp->size);
    memcpy(tmp + pp->size, p, plen);
    *(tmp + tmplen) = NUL;
    xfree(p);
    xfree(pp->data);
    *pp = cbuf_as_string(tmp, tmplen);
  } else {
    free_register(reg);
    reg->additional_data = NULL;
    reg->y_array = xmalloc(sizeof(String));
    reg->y_array[0] = cbuf_as_string(p, plen);
    reg->y_size = 1;
    reg->y_type = kMTCharWise;
  }
  reg->timestamp = os_time();
  return OK;
}

/// Start or stop recording into a yank register.
///
/// @return  FAIL for failure, OK otherwise.
int do_record(int c)
{
  static int regname;
  int retval;

  if (reg_recording == 0) {
    // start recording
    // registers 0-9, a-z and " are allowed
    if (c < 0 || (!ASCII_ISALNUM(c) && c != '"')) {
      retval = FAIL;
    } else {
      reg_recording = c;
      // TODO(bfredl): showmode based messaging is currently missing with cmdheight=0
      showmode();
      regname = c;
      retval = OK;

      apply_autocmds(EVENT_RECORDINGENTER, NULL, NULL, false, curbuf);
    }
  } else {  // stop recording
    save_v_event_T save_v_event;
    // Set the v:event dictionary with information about the recording.
    dict_T *dict = get_v_event(&save_v_event);

    // The recorded text contents.
    char *p = get_recorded();
    if (p != NULL) {
      // Remove escaping for K_SPECIAL in multi-byte chars.
      vim_unescape_ks(p);
      tv_dict_add_str(dict, S_LEN("regcontents"), p);
    }

    // Name of requested register, or empty string for unnamed operation.
    char buf[NUMBUFLEN + 2];
    buf[0] = (char)regname;
    buf[1] = NUL;
    tv_dict_add_str(dict, S_LEN("regname"), buf);
    tv_dict_set_keys_readonly(dict);

    // Get the recorded key hits.  K_SPECIAL will be escaped, this
    // needs to be removed again to put it in a register.  exec_reg then
    // adds the escaping back later.
    apply_autocmds(EVENT_RECORDINGLEAVE, NULL, NULL, false, curbuf);
    restore_v_event(dict, &save_v_event);
    reg_recorded = reg_recording;
    reg_recording = 0;
    if (p_ch == 0 || ui_has(kUIMessages)) {
      showmode();
    } else {
      msg("", 0);
    }
    if (p == NULL) {
      retval = FAIL;
    } else {
      // We don't want to change the default register here, so save and
      // restore the current register name.
      yankreg_T *old_y_previous = y_previous;

      retval = stuff_yank(regname, p);

      y_previous = old_y_previous;
    }
  }
  return retval;
}

/// Insert register contents "s" into the typeahead buffer, so that it will be
/// executed again.
///
/// @param esc    when true then it is to be taken literally: Escape K_SPECIAL
///               characters and no remapping.
/// @param colon  add ':' before the line
static int put_in_typebuf(char *s, bool esc, bool colon, int silent)
{
  int retval = OK;

  put_reedit_in_typebuf(silent);
  if (colon) {
    retval = ins_typebuf("\n", REMAP_NONE, 0, true, silent);
  }
  if (retval == OK) {
    char *p;

    if (esc) {
      p = vim_strsave_escape_ks(s);
    } else {
      p = s;
    }
    if (p == NULL) {
      retval = FAIL;
    } else {
      retval = ins_typebuf(p, esc ? REMAP_NONE : REMAP_YES, 0, true, silent);
    }
    if (esc) {
      xfree(p);
    }
  }
  if (colon && retval == OK) {
    retval = ins_typebuf(":", REMAP_NONE, 0, true, silent);
  }
  return retval;
}

/// If "restart_edit" is not zero, put it in the typeahead buffer, so that it's
/// used only after other typeahead has been processed.
static void put_reedit_in_typebuf(int silent)
{
  uint8_t buf[3];

  if (restart_edit == NUL) {
    return;
  }

  if (restart_edit == 'V') {
    buf[0] = 'g';
    buf[1] = 'R';
    buf[2] = NUL;
  } else {
    buf[0] = (uint8_t)(restart_edit == 'I' ? 'i' : restart_edit);
    buf[1] = NUL;
  }
  if (ins_typebuf((char *)buf, REMAP_NONE, 0, true, silent) == OK) {
    restart_edit = NUL;
  }
}

/// When executing a register as a series of ex-commands, if the
/// line-continuation character is used for a line, then join it with one or
/// more previous lines. Note that lines are processed backwards starting from
/// the last line in the register.
///
/// @param lines list of lines in the register
/// @param idx   index of the line starting with \ or "\. Join this line with all the immediate
///              predecessor lines that start with a \ and the first line that doesn't start
///              with a \. Lines that start with a comment "\ character are ignored.
/// @returns the concatenated line. The index of the line that should be
///          processed next is returned in idx.
static char *execreg_line_continuation(String *lines, size_t *idx)
{
  size_t i = *idx;
  assert(i > 0);
  const size_t cmd_end = i;

  garray_T ga;
  ga_init(&ga, (int)sizeof(char), 400);

  // search backwards to find the first line of this command.
  // Any line not starting with \ or "\ is the start of the
  // command.
  while (--i > 0) {
    char *p = skipwhite(lines[i].data);
    if (*p != '\\' && (p[0] != '"' || p[1] != '\\' || p[2] != ' ')) {
      break;
    }
  }
  const size_t cmd_start = i;

  // join all the lines
  ga_concat(&ga, lines[cmd_start].data);
  for (size_t j = cmd_start + 1; j <= cmd_end; j++) {
    char *p = skipwhite(lines[j].data);
    if (*p == '\\') {
      // Adjust the growsize to the current length to
      // speed up concatenating many lines.
      if (ga.ga_len > 400) {
        ga_set_growsize(&ga, MIN(ga.ga_len, 8000));
      }
      ga_concat(&ga, p + 1);
    }
  }
  ga_append(&ga, NUL);
  char *str = xmemdupz(ga.ga_data, (size_t)ga.ga_len);
  ga_clear(&ga);

  *idx = i;
  return str;
}

/// Execute a yank register: copy it into the stuff buffer
///
/// @param colon   insert ':' before each line
/// @param addcr   always add '\n' to end of line
/// @param silent  set "silent" flag in typeahead buffer
///
/// @return FAIL for failure, OK otherwise
int do_execreg(int regname, int colon, int addcr, int silent)
{
  int retval = OK;

  if (regname == '@') {                 // repeat previous one
    if (execreg_lastc == NUL) {
      emsg(_("E748: No previously used register"));
      return FAIL;
    }
    regname = execreg_lastc;
  }
  // check for valid regname
  if (regname == '%' || regname == '#' || !valid_yank_reg(regname, false)) {
    emsg_invreg(regname);
    return FAIL;
  }
  execreg_lastc = regname;

  if (regname == '_') {                 // black hole: don't stuff anything
    return OK;
  }

  if (regname == ':') {                 // use last command line
    if (last_cmdline == NULL) {
      emsg(_(e_nolastcmd));
      return FAIL;
    }
    // don't keep the cmdline containing @:
    XFREE_CLEAR(new_last_cmdline);
    // Escape all control characters with a CTRL-V
    char *p = vim_strsave_escaped_ext(last_cmdline,
                                      "\001\002\003\004\005\006\007"
                                      "\010\011\012\013\014\015\016\017"
                                      "\020\021\022\023\024\025\026\027"
                                      "\030\031\032\033\034\035\036\037",
                                      Ctrl_V, false);
    // When in Visual mode "'<,'>" will be prepended to the command.
    // Remove it when it's already there.
    if (VIsual_active && strncmp(p, "'<,'>", 5) == 0) {
      retval = put_in_typebuf(p + 5, true, true, silent);
    } else {
      retval = put_in_typebuf(p, true, true, silent);
    }
    xfree(p);
  } else if (regname == '=') {
    char *p = get_expr_line();
    if (p == NULL) {
      return FAIL;
    }
    retval = put_in_typebuf(p, true, colon, silent);
    xfree(p);
  } else if (regname == '.') {        // use last inserted text
    char *p = get_last_insert_save();
    if (p == NULL) {
      emsg(_(e_noinstext));
      return FAIL;
    }
    retval = put_in_typebuf(p, false, colon, silent);
    xfree(p);
  } else {
    yankreg_T *reg = get_yank_register(regname, YREG_PASTE);
    if (reg->y_array == NULL) {
      return FAIL;
    }

    // Disallow remapping for ":@r".
    int remap = colon ? REMAP_NONE : REMAP_YES;

    // Insert lines into typeahead buffer, from last one to first one.
    put_reedit_in_typebuf(silent);
    for (size_t i = reg->y_size; i-- > 0;) {  // from y_size - 1 to 0 included
      // insert NL between lines and after last line if type is kMTLineWise
      if (reg->y_type == kMTLineWise || i < reg->y_size - 1 || addcr) {
        if (ins_typebuf("\n", remap, 0, true, silent) == FAIL) {
          return FAIL;
        }
      }

      // Handle line-continuation for :@<register>
      char *str = reg->y_array[i].data;
      bool free_str = false;
      if (colon && i > 0) {
        char *p = skipwhite(str);
        if (*p == '\\' || (p[0] == '"' && p[1] == '\\' && p[2] == ' ')) {
          str = execreg_line_continuation(reg->y_array, &i);
          free_str = true;
        }
      }
      char *escaped = vim_strsave_escape_ks(str);
      if (free_str) {
        xfree(str);
      }
      retval = ins_typebuf(escaped, remap, 0, true, silent);
      xfree(escaped);
      if (retval == FAIL) {
        return FAIL;
      }
      if (colon
          && ins_typebuf(":", remap, 0, true, silent) == FAIL) {
        return FAIL;
      }
    }
    reg_executing = regname == 0 ? '"' : regname;  // disable the 'q' command
    pending_end_reg_executing = false;
  }
  return retval;
}

/// Insert a yank register: copy it into the Read buffer.
/// Used by CTRL-R command and middle mouse button in insert mode.
///
/// @param literally_arg  insert literally, not as if typed
///
/// @return FAIL for failure, OK otherwise
int insert_reg(int regname, yankreg_T *reg, bool literally_arg)
{
  int retval = OK;
  bool allocated;
  const bool literally = literally_arg || is_literal_register(regname);

  // It is possible to get into an endless loop by having CTRL-R a in
  // register a and then, in insert mode, doing CTRL-R a.
  // If you hit CTRL-C, the loop will be broken here.
  os_breakcheck();
  if (got_int) {
    return FAIL;
  }

  // check for valid regname
  if (regname != NUL && !valid_yank_reg(regname, false)) {
    return FAIL;
  }

  char *arg;
  if (regname == '.') {  // Insert last inserted text.
    retval = stuff_inserted(NUL, 1, true);
  } else if (get_spec_reg(regname, &arg, &allocated, true)) {
    if (arg == NULL) {
      return FAIL;
    }
    stuffescaped(arg, literally);
    if (allocated) {
      xfree(arg);
    }
  } else {  // Name or number register.
    if (reg == NULL) {
      reg = get_yank_register(regname, YREG_PASTE);
    }
    if (reg->y_array == NULL) {
      retval = FAIL;
    } else {
      for (size_t i = 0; i < reg->y_size; i++) {
        if (regname == '-' && reg->y_type == kMTCharWise) {
          Direction dir = BACKWARD;
          if ((State & REPLACE_FLAG) != 0) {
            pos_T curpos;
            if (u_save_cursor() == FAIL) {
              return FAIL;
            }
            del_chars(mb_charlen(reg->y_array[0].data), true);
            curpos = curwin->w_cursor;
            if (oneright() == FAIL) {
              // hit end of line, need to put forward (after the current position)
              dir = FORWARD;
            }
            curwin->w_cursor = curpos;
          }

          AppendCharToRedobuff(Ctrl_R);
          AppendCharToRedobuff(regname);
          do_put(regname, NULL, dir, 1, PUT_CURSEND);
        } else {
          stuffescaped(reg->y_array[i].data, literally);
          // Insert a newline between lines and after last line if
          // y_type is kMTLineWise.
          if (reg->y_type == kMTLineWise || i < reg->y_size - 1) {
            stuffcharReadbuff('\n');
          }
        }
      }
    }
  }

  return retval;
}

/// If "regname" is a special register, return true and store a pointer to its
/// value in "argp".
///
/// @param allocated  return: true when value was allocated
/// @param errmsg     give error message when failing
///
/// @return  true if "regname" is a special register,
bool get_spec_reg(int regname, char **argp, bool *allocated, bool errmsg)
{
  *argp = NULL;
  *allocated = false;
  switch (regname) {
  case '%':                     // file name
    if (errmsg) {
      check_fname();            // will give emsg if not set
    }
    *argp = curbuf->b_fname;
    return true;

  case '#':                       // alternate file name
    *argp = getaltfname(errmsg);  // may give emsg if not set
    return true;

  case '=':                     // result of expression
    *argp = get_expr_line();
    *allocated = true;
    return true;

  case ':':                     // last command line
    if (last_cmdline == NULL && errmsg) {
      emsg(_(e_nolastcmd));
    }
    *argp = last_cmdline;
    return true;

  case '/':                     // last search-pattern
    if (last_search_pat() == NULL && errmsg) {
      emsg(_(e_noprevre));
    }
    *argp = last_search_pat();
    return true;

  case '.':                     // last inserted text
    *argp = get_last_insert_save();
    *allocated = true;
    if (*argp == NULL && errmsg) {
      emsg(_(e_noinstext));
    }
    return true;

  case Ctrl_F:                  // Filename under cursor
  case Ctrl_P:                  // Path under cursor, expand via "path"
    if (!errmsg) {
      return false;
    }
    *argp = file_name_at_cursor(FNAME_MESS | FNAME_HYP | (regname == Ctrl_P ? FNAME_EXP : 0),
                                1, NULL);
    *allocated = true;
    return true;

  case Ctrl_W:                  // word under cursor
  case Ctrl_A:                  // WORD (mnemonic All) under cursor
    if (!errmsg) {
      return false;
    }
    size_t cnt = find_ident_under_cursor(argp, (regname == Ctrl_W
                                                ? (FIND_IDENT|FIND_STRING)
                                                : FIND_STRING));
    *argp = cnt ? xmemdupz(*argp, cnt) : NULL;
    *allocated = true;
    return true;

  case Ctrl_L:                  // Line under cursor
    if (!errmsg) {
      return false;
    }

    *argp = ml_get_buf(curwin->w_buffer, curwin->w_cursor.lnum);
    return true;

  case '_':                     // black hole: always empty
    *argp = "";
    return true;
  }

  return false;
}

/// Paste a yank register into the command line.
/// Only for non-special registers.
/// Used by CTRL-R in command-line mode.
/// insert_reg() can't be used here, because special characters from the
/// register contents will be interpreted as commands.
///
/// @param regname   Register name.
/// @param literally_arg Insert text literally instead of "as typed".
/// @param remcr     When true, don't add CR characters.
///
/// @returns FAIL for failure, OK otherwise
bool cmdline_paste_reg(int regname, bool literally_arg, bool remcr)
{
  const bool literally = literally_arg || is_literal_register(regname);

  yankreg_T *reg = get_yank_register(regname, YREG_PASTE);
  if (reg->y_array == NULL) {
    return FAIL;
  }

  for (size_t i = 0; i < reg->y_size; i++) {
    cmdline_paste_str(reg->y_array[i].data, literally);

    // Insert ^M between lines, unless `remcr` is true.
    if (i < reg->y_size - 1 && !remcr) {
      cmdline_paste_str("\r", literally);
    }

    // Check for CTRL-C, in case someone tries to paste a few thousand
    // lines and gets bored.
    os_breakcheck();
    if (got_int) {
      return FAIL;
    }
  }
  return OK;
}

/// Shift the delete registers: "9 is cleared, "8 becomes "9, etc.
void shift_delete_registers(bool y_append)
{
  free_register(&y_regs[9]);  // free register "9
  for (int n = 9; n > 1; n--) {
    y_regs[n] = y_regs[n - 1];
  }
  if (!y_append) {
    y_previous = &y_regs[1];
  }
  y_regs[1].y_array = NULL;  // set register "1 to empty
}

#ifdef EXITFREE
void clear_registers(void)
{
  for (int i = 0; i < NUM_REGISTERS; i++) {
    free_register(&y_regs[i]);
  }
}
#endif

/// Free contents of yankreg `reg`.
/// Called for normal freeing and in case of error.
///
/// @param reg  must not be NULL (but `reg->y_array` might be)
void free_register(yankreg_T *reg)
  FUNC_ATTR_NONNULL_ALL
{
  XFREE_CLEAR(reg->additional_data);
  if (reg->y_array == NULL) {
    return;
  }

  for (size_t i = reg->y_size; i-- > 0;) {  // from y_size - 1 to 0 included
    API_CLEAR_STRING(reg->y_array[i]);
  }
  XFREE_CLEAR(reg->y_array);
}

/// Copy a block range into a register.
///
/// @param exclude_trailing_space  if true, do not copy trailing whitespaces.
static void yank_copy_line(yankreg_T *reg, struct block_def *bd, size_t y_idx,
                           bool exclude_trailing_space)
  FUNC_ATTR_NONNULL_ALL
{
  if (exclude_trailing_space) {
    bd->endspaces = 0;
  }
  int size = bd->startspaces + bd->endspaces + bd->textlen;
  assert(size >= 0);
  char *pnew = xmallocz((size_t)size);
  reg->y_array[y_idx].data = pnew;
  memset(pnew, ' ', (size_t)bd->startspaces);
  pnew += bd->startspaces;
  memmove(pnew, bd->textstart, (size_t)bd->textlen);
  pnew += bd->textlen;
  memset(pnew, ' ', (size_t)bd->endspaces);
  pnew += bd->endspaces;
  if (exclude_trailing_space) {
    int s = bd->textlen + bd->endspaces;

    while (s > 0 && ascii_iswhite(*(bd->textstart + s - 1))) {
      s = s - utf_head_off(bd->textstart, bd->textstart + s - 1) - 1;
      pnew--;
    }
  }
  *pnew = NUL;
  reg->y_array[y_idx].size = (size_t)(pnew - reg->y_array[y_idx].data);
}

void op_yank_reg(oparg_T *oap, bool message, yankreg_T *reg, bool append)
{
  yankreg_T newreg;  // new yank register when appending
  MotionType yank_type = oap->motion_type;
  size_t yanklines = (size_t)oap->line_count;
  linenr_T yankendlnum = oap->end.lnum;
  struct block_def bd;

  yankreg_T *curr = reg;  // copy of current register
  // append to existing contents
  if (append && reg->y_array != NULL) {
    reg = &newreg;
  } else {
    free_register(reg);  // free previously yanked lines
  }

  // If the cursor was in column 1 before and after the movement, and the
  // operator is not inclusive, the yank is always linewise.
  if (oap->motion_type == kMTCharWise
      && oap->start.col == 0
      && !oap->inclusive
      && (!oap->is_VIsual || *p_sel == 'o')
      && oap->end.col == 0
      && yanklines > 1) {
    yank_type = kMTLineWise;
    yankendlnum--;
    yanklines--;
  }

  reg->y_size = yanklines;
  reg->y_type = yank_type;  // set the yank register type
  reg->y_width = 0;
  reg->y_array = xcalloc(yanklines, sizeof(String));
  reg->additional_data = NULL;
  reg->timestamp = os_time();

  size_t y_idx = 0;  // index in y_array[]
  linenr_T lnum = oap->start.lnum;  // current line number

  if (yank_type == kMTBlockWise) {
    // Visual block mode
    reg->y_width = oap->end_vcol - oap->start_vcol;

    if (curwin->w_curswant == MAXCOL && reg->y_width > 0) {
      reg->y_width--;
    }
  }

  for (; lnum <= yankendlnum; lnum++, y_idx++) {
    switch (reg->y_type) {
    case kMTBlockWise:
      block_prep(oap, &bd, lnum, false);
      yank_copy_line(reg, &bd, y_idx, oap->excl_tr_ws);
      break;

    case kMTLineWise:
      reg->y_array[y_idx] = cbuf_to_string(ml_get(lnum), (size_t)ml_get_len(lnum));
      break;

    case kMTCharWise:
      charwise_block_prep(oap->start, oap->end, &bd, lnum, oap->inclusive);
      // make sure bd.textlen is not longer than the text
      int tmp = (int)strlen(bd.textstart);
      if (tmp < bd.textlen) {
        bd.textlen = tmp;
      }
      yank_copy_line(reg, &bd, y_idx, false);
      break;

    // NOTREACHED
    case kMTUnknown:
      abort();
    }
  }

  if (curr != reg) {      // append the new block to the old block
    size_t j;
    String *new_ptr = xmalloc(sizeof(String) * (curr->y_size + reg->y_size));
    for (j = 0; j < curr->y_size; j++) {
      new_ptr[j] = curr->y_array[j];
    }
    xfree(curr->y_array);
    curr->y_array = new_ptr;

    if (yank_type == kMTLineWise) {
      // kMTLineWise overrides kMTCharWise and kMTBlockWise
      curr->y_type = kMTLineWise;
    }

    // Concatenate the last line of the old block with the first line of
    // the new block, unless being Vi compatible.
    if (curr->y_type == kMTCharWise
        && vim_strchr(p_cpo, CPO_REGAPPEND) == NULL) {
      char *pnew = xmalloc(curr->y_array[curr->y_size - 1].size
                           + reg->y_array[0].size + 1);
      j--;
      STRCPY(pnew, curr->y_array[j].data);
      STRCPY(pnew + curr->y_array[j].size, reg->y_array[0].data);
      xfree(curr->y_array[j].data);
      curr->y_array[j] = cbuf_as_string(pnew,
                                        curr->y_array[j].size + reg->y_array[0].size);
      j++;
      API_CLEAR_STRING(reg->y_array[0]);
      y_idx = 1;
    } else {
      y_idx = 0;
    }
    while (y_idx < reg->y_size) {
      curr->y_array[j++] = reg->y_array[y_idx++];
    }
    curr->y_size = j;
    xfree(reg->y_array);
  }

  if (message) {  // Display message about yank?
    if (yank_type == kMTCharWise && yanklines == 1) {
      yanklines = 0;
    }
    // Some versions of Vi use ">=" here, some don't...
    if (yanklines > (size_t)p_report) {
      char namebuf[100];

      if (oap->regname == NUL) {
        *namebuf = NUL;
      } else {
        vim_snprintf(namebuf, sizeof(namebuf), _(" into \"%c"), oap->regname);
      }

      // redisplay now, so message is not deleted
      update_topline(curwin);
      if (must_redraw) {
        update_screen();
      }
      if (yank_type == kMTBlockWise) {
        smsg(0, NGETTEXT("block of %" PRId64 " line yanked%s",
                         "block of %" PRId64 " lines yanked%s", yanklines),
             (int64_t)yanklines, namebuf);
      } else {
        smsg(0, NGETTEXT("%" PRId64 " line yanked%s",
                         "%" PRId64 " lines yanked%s", yanklines),
             (int64_t)yanklines, namebuf);
      }
    }
  }

  if ((cmdmod.cmod_flags & CMOD_LOCKMARKS) == 0) {
    // Set "'[" and "']" marks.
    curbuf->b_op_start = oap->start;
    curbuf->b_op_end = oap->end;
    if (yank_type == kMTLineWise) {
      curbuf->b_op_start.col = 0;
      curbuf->b_op_end.col = MAXCOL;
    }
    if (yank_type != kMTLineWise && !oap->inclusive) {
      // Exclude the end position.
      decl(&curbuf->b_op_end);
    }
  }
}

/// Format the register type as a string.
///
/// @param reg_type The register type.
/// @param reg_width The width, only used if "reg_type" is kMTBlockWise.
/// @param[out] buf Buffer to store formatted string. The allocated size should
///                 be at least NUMBUFLEN+2 to always fit the value.
/// @param buf_len The allocated size of the buffer.
void format_reg_type(MotionType reg_type, colnr_T reg_width, char *buf, size_t buf_len)
  FUNC_ATTR_NONNULL_ALL
{
  assert(buf_len > 1);
  switch (reg_type) {
  case kMTLineWise:
    buf[0] = 'V';
    buf[1] = NUL;
    break;
  case kMTCharWise:
    buf[0] = 'v';
    buf[1] = NUL;
    break;
  case kMTBlockWise:
    snprintf(buf, buf_len, CTRL_V_STR "%" PRIdCOLNR, reg_width + 1);
    break;
  case kMTUnknown:
    buf[0] = NUL;
    break;
  }
}

/// Execute autocommands for TextYankPost.
///
/// @param oap Operator arguments.
/// @param reg The yank register used.
void do_autocmd_textyankpost(oparg_T *oap, yankreg_T *reg)
  FUNC_ATTR_NONNULL_ALL
{
  static bool recursive = false;

  if (recursive || !has_event(EVENT_TEXTYANKPOST)) {
    // No autocommand was defined, or we yanked from this autocommand.
    return;
  }

  recursive = true;

  save_v_event_T save_v_event;
  // Set the v:event dictionary with information about the yank.
  dict_T *dict = get_v_event(&save_v_event);

  // The yanked text contents.
  list_T *const list = tv_list_alloc((ptrdiff_t)reg->y_size);
  for (size_t i = 0; i < reg->y_size; i++) {
    tv_list_append_string(list, reg->y_array[i].data, -1);
  }
  tv_list_set_lock(list, VAR_FIXED);
  tv_dict_add_list(dict, S_LEN("regcontents"), list);

  // Register type.
  char buf[NUMBUFLEN + 2];
  format_reg_type(reg->y_type, reg->y_width, buf, ARRAY_SIZE(buf));
  tv_dict_add_str(dict, S_LEN("regtype"), buf);

  // Name of requested register, or empty string for unnamed operation.
  buf[0] = (char)oap->regname;
  buf[1] = NUL;
  tv_dict_add_str(dict, S_LEN("regname"), buf);

  // Motion type: inclusive or exclusive.
  tv_dict_add_bool(dict, S_LEN("inclusive"),
                   oap->inclusive ? kBoolVarTrue : kBoolVarFalse);

  // Kind of operation: yank, delete, change).
  buf[0] = (char)get_op_char(oap->op_type);
  buf[1] = NUL;
  tv_dict_add_str(dict, S_LEN("operator"), buf);

  // Selection type: visual or not.
  tv_dict_add_bool(dict, S_LEN("visual"),
                   oap->is_VIsual ? kBoolVarTrue : kBoolVarFalse);

  tv_dict_set_keys_readonly(dict);
  textlock++;
  apply_autocmds(EVENT_TEXTYANKPOST, NULL, NULL, false, curbuf);
  textlock--;
  restore_v_event(dict, &save_v_event);

  recursive = false;
}

/// Yanks the text between "oap->start" and "oap->end" into a yank register.
/// If we are to append (uppercase register), we first yank into a new yank
/// register and then concatenate the old and the new one.
/// Do not call this from a delete operation. Use op_yank_reg() instead.
///
/// @param oap operator arguments
/// @param message show message when more than `&report` lines are yanked.
/// @returns whether the operation register was writable.
bool op_yank(oparg_T *oap, bool message)
  FUNC_ATTR_NONNULL_ALL
{
  // check for read-only register
  if (oap->regname != 0 && !valid_yank_reg(oap->regname, true)) {
    beep_flush();
    return false;
  }
  if (oap->regname == '_') {
    return true;  // black hole: nothing to do
  }

  yankreg_T *reg = get_yank_register(oap->regname, YREG_YANK);
  op_yank_reg(oap, message, reg, is_append_register(oap->regname));
  set_clipboard(oap->regname, reg);
  do_autocmd_textyankpost(oap, reg);
  return true;
}

/// Put contents of register "regname" into the text.
/// Caller must check "regname" to be valid!
///
/// @param flags  PUT_FIXINDENT     make indent look nice
///               PUT_CURSEND       leave cursor after end of new text
///               PUT_LINE          force linewise put (":put")
///               PUT_BLOCK_INNER   in block mode, do not add trailing spaces
/// @param dir    BACKWARD for 'P', FORWARD for 'p'
void do_put(int regname, yankreg_T *reg, int dir, int count, int flags)
{
  size_t totlen = 0;  // init for gcc
  linenr_T lnum = 0;
  MotionType y_type;
  size_t y_size;
  int y_width = 0;
  colnr_T vcol = 0;
  String *y_array = NULL;
  linenr_T nr_lines = 0;
  bool allocated = false;
  const pos_T orig_start = curbuf->b_op_start;
  const pos_T orig_end = curbuf->b_op_end;
  unsigned cur_ve_flags = get_ve_flags(curwin);

  curbuf->b_op_start = curwin->w_cursor;        // default for '[ mark
  curbuf->b_op_end = curwin->w_cursor;          // default for '] mark

  // Using inserted text works differently, because the register includes
  // special characters (newlines, etc.).
  if (regname == '.' && !reg) {
    bool non_linewise_vis = (VIsual_active && VIsual_mode != 'V');

    // PUT_LINE has special handling below which means we use 'i' to start.
    char command_start_char = non_linewise_vis
                              ? 'c'
                              : (flags & PUT_LINE ? 'i' : (dir == FORWARD ? 'a' : 'i'));

    // To avoid 'autoindent' on linewise puts, create a new line with `:put _`.
    if (flags & PUT_LINE) {
      do_put('_', NULL, dir, 1, PUT_LINE);
    }

    // If given a count when putting linewise, we stuff the readbuf with the
    // dot register 'count' times split by newlines.
    if (flags & PUT_LINE) {
      stuffcharReadbuff(command_start_char);
      for (; count > 0; count--) {
        stuff_inserted(NUL, 1, count != 1);
        if (count != 1) {
          // To avoid 'autoindent' affecting the text, use Ctrl_U to remove any
          // whitespace. Can't just insert Ctrl_U into readbuf1, this would go
          // back to the previous line in the case of 'noautoindent' and
          // 'backspace' includes "eol". So we insert a dummy space for Ctrl_U
          // to consume.
          stuffReadbuff("\n ");
          stuffcharReadbuff(Ctrl_U);
        }
      }
    } else {
      stuff_inserted(command_start_char, count, false);
    }

    // Putting the text is done later, so can't move the cursor to the next
    // character.  Simulate it with motion commands after the insert.
    if (flags & PUT_CURSEND) {
      if (flags & PUT_LINE) {
        stuffReadbuff("j0");
      } else {
        // Avoid ringing the bell from attempting to move into the space after
        // the current line. We can stuff the readbuffer with "l" if:
        // 1) 'virtualedit' is "all" or "onemore"
        // 2) We are not at the end of the line
        // 3) We are not  (one past the end of the line && on the last line)
        //    This allows a visual put over a selection one past the end of the
        //    line joining the current line with the one below.

        // curwin->w_cursor.col marks the byte position of the cursor in the
        // currunt line. It increases up to a max of
        // strlen(ml_get(curwin->w_cursor.lnum)). With 'virtualedit' and the
        // cursor past the end of the line, curwin->w_cursor.coladd is
        // incremented instead of curwin->w_cursor.col.
        char *cursor_pos = get_cursor_pos_ptr();
        bool one_past_line = (*cursor_pos == NUL);
        bool eol = false;
        if (!one_past_line) {
          eol = (*(cursor_pos + utfc_ptr2len(cursor_pos)) == NUL);
        }

        bool ve_allows = (cur_ve_flags == kOptVeFlagAll || cur_ve_flags == kOptVeFlagOnemore);
        bool eof = curbuf->b_ml.ml_line_count == curwin->w_cursor.lnum
                   && one_past_line;
        if (ve_allows || !(eol || eof)) {
          stuffcharReadbuff('l');
        }
      }
    } else if (flags & PUT_LINE) {
      stuffReadbuff("g'[");
    }

    // So the 'u' command restores cursor position after ".p, save the cursor
    // position now (though not saving any text).
    if (command_start_char == 'a') {
      if (u_save(curwin->w_cursor.lnum, curwin->w_cursor.lnum + 1) == FAIL) {
        return;
      }
    }
    return;
  }

  // For special registers '%' (file name), '#' (alternate file name) and
  // ':' (last command line), etc. we have to create a fake yank register.
  String insert_string = STRING_INIT;
  if (!reg && get_spec_reg(regname, &insert_string.data, &allocated, true)) {
    if (insert_string.data == NULL) {
      return;
    }
  }

  if (!curbuf->terminal) {
    // Autocommands may be executed when saving lines for undo.  This might
    // make y_array invalid, so we start undo now to avoid that.
    if (u_save(curwin->w_cursor.lnum, curwin->w_cursor.lnum + 1) == FAIL) {
      return;
    }
  }

  if (insert_string.data != NULL) {
    insert_string.size = strlen(insert_string.data);
    y_type = kMTCharWise;
    if (regname == '=') {
      // For the = register we need to split the string at NL
      // characters.
      // Loop twice: count the number of lines and save them.
      while (true) {
        y_size = 0;
        char *ptr = insert_string.data;
        size_t ptrlen = insert_string.size;
        while (ptr != NULL) {
          if (y_array != NULL) {
            y_array[y_size].data = ptr;
          }
          y_size++;
          char *tmp = vim_strchr(ptr, '\n');
          if (tmp == NULL) {
            if (y_array != NULL) {
              y_array[y_size - 1].size = ptrlen;
            }
          } else {
            if (y_array != NULL) {
              *tmp = NUL;
              y_array[y_size - 1].size = (size_t)(tmp - ptr);
              ptrlen -= y_array[y_size - 1].size + 1;
            }
            tmp++;
            // A trailing '\n' makes the register linewise.
            if (*tmp == NUL) {
              y_type = kMTLineWise;
              break;
            }
          }
          ptr = tmp;
        }
        if (y_array != NULL) {
          break;
        }
        y_array = xmalloc(y_size * sizeof(String));
      }
    } else {
      y_size = 1;               // use fake one-line yank register
      y_array = &insert_string;
    }
  } else {
    // in case of replacing visually selected text
    // the yankreg might already have been saved to avoid
    // just restoring the deleted text.
    if (reg == NULL) {
      reg = get_yank_register(regname, YREG_PASTE);
    }

    y_type = reg->y_type;
    y_width = reg->y_width;
    y_size = reg->y_size;
    y_array = reg->y_array;
  }

  if (curbuf->terminal) {
    terminal_paste(count, y_array, y_size);
    return;
  }

  colnr_T split_pos = 0;
  if (y_type == kMTLineWise) {
    if (flags & PUT_LINE_SPLIT) {
      // "p" or "P" in Visual mode: split the lines to put the text in
      // between.
      if (u_save_cursor() == FAIL) {
        goto end;
      }
      char *curline = get_cursor_line_ptr();
      char *p = get_cursor_pos_ptr();
      char *const p_orig = p;
      const size_t plen = (size_t)get_cursor_pos_len();
      if (dir == FORWARD && *p != NUL) {
        MB_PTR_ADV(p);
      }
      // we need this later for the correct extmark_splice() event
      split_pos = (colnr_T)(p - curline);

      char *ptr = xmemdupz(p, plen - (size_t)(p - p_orig));
      ml_append(curwin->w_cursor.lnum, ptr, 0, false);
      xfree(ptr);

      ptr = xmemdupz(get_cursor_line_ptr(), (size_t)split_pos);
      ml_replace(curwin->w_cursor.lnum, ptr, false);
      nr_lines++;
      dir = FORWARD;

      buf_updates_send_changes(curbuf, curwin->w_cursor.lnum, 1, 1);
    }
    if (flags & PUT_LINE_FORWARD) {
      // Must be "p" for a Visual block, put lines below the block.
      curwin->w_cursor = curbuf->b_visual.vi_end;
      dir = FORWARD;
    }
    curbuf->b_op_start = curwin->w_cursor;      // default for '[ mark
    curbuf->b_op_end = curwin->w_cursor;        // default for '] mark
  }

  if (flags & PUT_LINE) {  // :put command or "p" in Visual line mode.
    y_type = kMTLineWise;
  }

  if (y_size == 0 || y_array == NULL) {
    semsg(_("E353: Nothing in register %s"),
          regname == 0 ? "\"" : transchar(regname));
    goto end;
  }

  if (y_type == kMTBlockWise) {
    lnum = curwin->w_cursor.lnum + (linenr_T)y_size + 1;
    lnum = MIN(lnum, curbuf->b_ml.ml_line_count + 1);
    if (u_save(curwin->w_cursor.lnum - 1, lnum) == FAIL) {
      goto end;
    }
  } else if (y_type == kMTLineWise) {
    lnum = curwin->w_cursor.lnum;
    // Correct line number for closed fold.  Don't move the cursor yet,
    // u_save() uses it.
    if (dir == BACKWARD) {
      hasFolding(curwin, lnum, &lnum, NULL);
    } else {
      hasFolding(curwin, lnum, NULL, &lnum);
    }
    if (dir == FORWARD) {
      lnum++;
    }
    // In an empty buffer the empty line is going to be replaced, include
    // it in the saved lines.
    if ((buf_is_empty(curbuf)
         ? u_save(0, 2) : u_save(lnum - 1, lnum)) == FAIL) {
      goto end;
    }
    if (dir == FORWARD) {
      curwin->w_cursor.lnum = lnum - 1;
    } else {
      curwin->w_cursor.lnum = lnum;
    }
    curbuf->b_op_start = curwin->w_cursor;      // for mark_adjust()
  } else if (u_save_cursor() == FAIL) {
    goto end;
  }

  if (cur_ve_flags == kOptVeFlagAll && y_type == kMTCharWise) {
    if (gchar_cursor() == TAB) {
      int viscol = getviscol();
      OptInt ts = curbuf->b_p_ts;
      // Don't need to insert spaces when "p" on the last position of a
      // tab or "P" on the first position.
      if (dir == FORWARD
          ? tabstop_padding(viscol, ts, curbuf->b_p_vts_array) != 1
          : curwin->w_cursor.coladd > 0) {
        coladvance_force(viscol);
      } else {
        curwin->w_cursor.coladd = 0;
      }
    } else if (curwin->w_cursor.coladd > 0 || gchar_cursor() == NUL) {
      coladvance_force(getviscol() + (dir == FORWARD));
    }
  }

  lnum = curwin->w_cursor.lnum;
  colnr_T col = curwin->w_cursor.col;

  // Block mode
  if (y_type == kMTBlockWise) {
    int incr = 0;
    struct block_def bd;
    int c = gchar_cursor();
    colnr_T endcol2 = 0;

    if (dir == FORWARD && c != NUL) {
      if (cur_ve_flags == kOptVeFlagAll) {
        getvcol(curwin, &curwin->w_cursor, &col, NULL, &endcol2);
      } else {
        getvcol(curwin, &curwin->w_cursor, NULL, NULL, &col);
      }

      // move to start of next multi-byte character
      curwin->w_cursor.col += utfc_ptr2len(get_cursor_pos_ptr());
      col++;
    } else {
      getvcol(curwin, &curwin->w_cursor, &col, NULL, &endcol2);
    }

    col += curwin->w_cursor.coladd;
    if (cur_ve_flags == kOptVeFlagAll
        && (curwin->w_cursor.coladd > 0 || endcol2 == curwin->w_cursor.col)) {
      if (dir == FORWARD && c == NUL) {
        col++;
      }
      if (dir != FORWARD && c != NUL && curwin->w_cursor.coladd > 0) {
        curwin->w_cursor.col++;
      }
      if (c == TAB) {
        if (dir == BACKWARD && curwin->w_cursor.col) {
          curwin->w_cursor.col--;
        }
        if (dir == FORWARD && col - 1 == endcol2) {
          curwin->w_cursor.col++;
        }
      }
    }
    curwin->w_cursor.coladd = 0;
    bd.textcol = 0;
    for (size_t i = 0; i < y_size; i++) {
      int spaces = 0;
      char shortline;
      // can just be 0 or 1, needed for blockwise paste beyond the current
      // buffer end
      int lines_appended = 0;

      bd.startspaces = 0;
      bd.endspaces = 0;
      vcol = 0;
      int delcount = 0;

      // add a new line
      if (curwin->w_cursor.lnum > curbuf->b_ml.ml_line_count) {
        if (ml_append(curbuf->b_ml.ml_line_count, "", 1, false) == FAIL) {
          break;
        }
        nr_lines++;
        lines_appended = 1;
      }
      // get the old line and advance to the position to insert at
      char *oldp = get_cursor_line_ptr();
      colnr_T oldlen = get_cursor_line_len();

      CharsizeArg csarg;
      CSType cstype = init_charsize_arg(&csarg, curwin, curwin->w_cursor.lnum, oldp);
      StrCharInfo ci = utf_ptr2StrCharInfo(oldp);
      vcol = 0;
      while (vcol < col && *ci.ptr != NUL) {
        incr = win_charsize(cstype, vcol, ci.ptr, ci.chr.value, &csarg).width;
        vcol += incr;
        ci = utfc_next(ci);
      }
      char *ptr = ci.ptr;
      bd.textcol = (colnr_T)(ptr - oldp);

      shortline = (vcol < col) || (vcol == col && !*ptr);

      if (vcol < col) {     // line too short, pad with spaces
        bd.startspaces = col - vcol;
      } else if (vcol > col) {
        bd.endspaces = vcol - col;
        bd.startspaces = incr - bd.endspaces;
        bd.textcol--;
        delcount = 1;
        bd.textcol -= utf_head_off(oldp, oldp + bd.textcol);
        if (oldp[bd.textcol] != TAB) {
          // Only a Tab can be split into spaces.  Other
          // characters will have to be moved to after the
          // block, causing misalignment.
          delcount = 0;
          bd.endspaces = 0;
        }
      }

      const int yanklen = (int)y_array[i].size;

      if ((flags & PUT_BLOCK_INNER) == 0) {
        // calculate number of spaces required to fill right side of block
        spaces = y_width + 1;

        cstype = init_charsize_arg(&csarg, curwin, 0, y_array[i].data);
        ci = utf_ptr2StrCharInfo(y_array[i].data);
        while (*ci.ptr != NUL) {
          spaces -= win_charsize(cstype, 0, ci.ptr, ci.chr.value, &csarg).width;
          ci = utfc_next(ci);
        }
        spaces = MAX(spaces, 0);
      }

      // Insert the new text.
      // First check for multiplication overflow.
      if (yanklen + spaces != 0
          && count > ((INT_MAX - (bd.startspaces + bd.endspaces)) / (yanklen + spaces))) {
        emsg(_(e_resulting_text_too_long));
        break;
      }

      totlen = (size_t)count * (size_t)(yanklen + spaces) + (size_t)bd.startspaces +
               (size_t)bd.endspaces;
      char *newp = xmalloc(totlen + (size_t)oldlen + 1);

      // copy part up to cursor to new line
      ptr = newp;
      memmove(ptr, oldp, (size_t)bd.textcol);
      ptr += bd.textcol;

      // may insert some spaces before the new text
      memset(ptr, ' ', (size_t)bd.startspaces);
      ptr += bd.startspaces;

      // insert the new text
      for (int j = 0; j < count; j++) {
        memmove(ptr, y_array[i].data, (size_t)yanklen);
        ptr += yanklen;

        // insert block's trailing spaces only if there's text behind
        if ((j < count - 1 || !shortline) && spaces > 0) {
          memset(ptr, ' ', (size_t)spaces);
          ptr += spaces;
        } else {
          totlen -= (size_t)spaces;  // didn't use these spaces
        }
      }

      // may insert some spaces after the new text
      memset(ptr, ' ', (size_t)bd.endspaces);
      ptr += bd.endspaces;

      // move the text after the cursor to the end of the line.
      int columns = oldlen - bd.textcol - delcount + 1;
      assert(columns >= 0);
      memmove(ptr, oldp + bd.textcol + delcount, (size_t)columns);
      ml_replace(curwin->w_cursor.lnum, newp, false);
      extmark_splice_cols(curbuf, (int)curwin->w_cursor.lnum - 1, bd.textcol,
                          delcount, (int)totlen + lines_appended, kExtmarkUndo);

      curwin->w_cursor.lnum++;
      if (i == 0) {
        curwin->w_cursor.col += bd.startspaces;
      }
    }

    changed_lines(curbuf, lnum, 0, curbuf->b_op_start.lnum + (linenr_T)y_size
                  - nr_lines, nr_lines, true);

    // Set '[ mark.
    curbuf->b_op_start = curwin->w_cursor;
    curbuf->b_op_start.lnum = lnum;

    // adjust '] mark
    curbuf->b_op_end.lnum = curwin->w_cursor.lnum - 1;
    curbuf->b_op_end.col = MAX(bd.textcol + (colnr_T)totlen - 1, 0);
    curbuf->b_op_end.coladd = 0;
    if (flags & PUT_CURSEND) {
      curwin->w_cursor = curbuf->b_op_end;
      curwin->w_cursor.col++;

      // in Insert mode we might be after the NUL, correct for that
      colnr_T len = get_cursor_line_len();
      curwin->w_cursor.col = MIN(curwin->w_cursor.col, len);
    } else {
      curwin->w_cursor.lnum = lnum;
    }
  } else {
    const int yanklen = (int)y_array[0].size;

    // Character or Line mode
    if (y_type == kMTCharWise) {
      // if type is kMTCharWise, FORWARD is the same as BACKWARD on the next
      // char
      if (dir == FORWARD && gchar_cursor() != NUL) {
        int bytelen = utfc_ptr2len(get_cursor_pos_ptr());

        // put it on the next of the multi-byte character.
        col += bytelen;
        if (yanklen) {
          curwin->w_cursor.col += bytelen;
          curbuf->b_op_end.col += bytelen;
        }
      }
      curbuf->b_op_start = curwin->w_cursor;
    } else if (dir == BACKWARD) {
      // Line mode: BACKWARD is the same as FORWARD on the previous line
      lnum--;
    }
    pos_T new_cursor = curwin->w_cursor;

    // simple case: insert into one line at a time
    if (y_type == kMTCharWise && y_size == 1) {
      linenr_T end_lnum = 0;  // init for gcc
      linenr_T start_lnum = lnum;
      int first_byte_off = 0;

      if (VIsual_active) {
        end_lnum = MAX(curbuf->b_visual.vi_end.lnum, curbuf->b_visual.vi_start.lnum);
        if (end_lnum > start_lnum) {
          // "col" is valid for the first line, in following lines
          // the virtual column needs to be used.  Matters for
          // multi-byte characters.
          pos_T pos = {
            .lnum = lnum,
            .col = col,
            .coladd = 0,
          };
          getvcol(curwin, &pos, NULL, &vcol, NULL);
        }
      }

      if (count == 0 || yanklen == 0) {
        if (VIsual_active) {
          lnum = end_lnum;
        }
      } else if (count > INT_MAX / yanklen) {
        // multiplication overflow
        emsg(_(e_resulting_text_too_long));
      } else {
        totlen = (size_t)count * (size_t)yanklen;
        do {
          char *oldp = ml_get(lnum);
          colnr_T oldlen = ml_get_len(lnum);
          if (lnum > start_lnum) {
            pos_T pos = {
              .lnum = lnum,
            };
            if (getvpos(curwin, &pos, vcol) == OK) {
              col = pos.col;
            } else {
              col = MAXCOL;
            }
          }
          if (VIsual_active && col > oldlen) {
            lnum++;
            continue;
          }
          char *newp = xmalloc(totlen + (size_t)oldlen + 1);
          memmove(newp, oldp, (size_t)col);
          char *ptr = newp + col;
          for (size_t i = 0; i < (size_t)count; i++) {
            memmove(ptr, y_array[0].data, (size_t)yanklen);
            ptr += yanklen;
          }
          memmove(ptr, oldp + col, (size_t)(oldlen - col) + 1);  // +1 for NUL
          ml_replace(lnum, newp, false);

          // compute the byte offset for the last character
          first_byte_off = utf_head_off(newp, ptr - 1);

          // Place cursor on last putted char.
          if (lnum == curwin->w_cursor.lnum) {
            // make sure curwin->w_virtcol is updated
            changed_cline_bef_curs(curwin);
            invalidate_botline(curwin);
            curwin->w_cursor.col += (colnr_T)(totlen - 1);
          }
          changed_bytes(lnum, col);
          extmark_splice_cols(curbuf, (int)lnum - 1, col,
                              0, (int)totlen, kExtmarkUndo);
          if (VIsual_active) {
            lnum++;
          }
        } while (VIsual_active && lnum <= end_lnum);

        if (VIsual_active) {  // reset lnum to the last visual line
          lnum--;
        }
      }

      // put '] at the first byte of the last character
      curbuf->b_op_end = curwin->w_cursor;
      curbuf->b_op_end.col -= first_byte_off;

      // For "CTRL-O p" in Insert mode, put cursor after last char
      if (totlen && (restart_edit != 0 || (flags & PUT_CURSEND))) {
        curwin->w_cursor.col++;
      } else {
        curwin->w_cursor.col -= first_byte_off;
      }
    } else {
      linenr_T new_lnum = new_cursor.lnum;
      int indent;
      int orig_indent = 0;
      int indent_diff = 0;        // init for gcc
      bool first_indent = true;
      int lendiff = 0;

      if (flags & PUT_FIXINDENT) {
        orig_indent = get_indent();
      }

      // Insert at least one line.  When y_type is kMTCharWise, break the first
      // line in two.
      for (int cnt = 1; cnt <= count; cnt++) {
        size_t i = 0;
        if (y_type == kMTCharWise) {
          // Split the current line in two at the insert position.
          // First insert y_array[size - 1] in front of second line.
          // Then append y_array[0] to first line.
          lnum = new_cursor.lnum;
          char *ptr = ml_get(lnum) + col;
          size_t ptrlen = (size_t)ml_get_len(lnum) - (size_t)col;
          totlen = y_array[y_size - 1].size;
          char *newp = xmalloc(ptrlen + totlen + 1);
          STRCPY(newp, y_array[y_size - 1].data);
          STRCPY(newp + totlen, ptr);
          // insert second line
          ml_append(lnum, newp, 0, false);
          new_lnum++;
          xfree(newp);

          char *oldp = ml_get(lnum);
          newp = xmalloc((size_t)col + (size_t)yanklen + 1);
          // copy first part of line
          memmove(newp, oldp, (size_t)col);
          // append to first line
          memmove(newp + col, y_array[0].data, (size_t)yanklen + 1);
          ml_replace(lnum, newp, false);

          curwin->w_cursor.lnum = lnum;
          i = 1;
        }

        for (; i < y_size; i++) {
          if ((y_type != kMTCharWise || i < y_size - 1)) {
            if (ml_append(lnum, y_array[i].data, 0, false) == FAIL) {
              goto error;
            }
            new_lnum++;
          }
          lnum++;
          nr_lines++;
          if (flags & PUT_FIXINDENT) {
            pos_T old_pos = curwin->w_cursor;
            curwin->w_cursor.lnum = lnum;
            char *ptr = ml_get(lnum);
            if (cnt == count && i == y_size - 1) {
              lendiff = ml_get_len(lnum);
            }
            if (*ptr == '#' && preprocs_left()) {
              indent = 0;                   // Leave # lines at start
            } else if (*ptr == NUL) {
              indent = 0;                   // Ignore empty lines
            } else if (first_indent) {
              indent_diff = orig_indent - get_indent();
              indent = orig_indent;
              first_indent = false;
            } else if ((indent = get_indent() + indent_diff) < 0) {
              indent = 0;
            }
            set_indent(indent, SIN_NOMARK);
            curwin->w_cursor = old_pos;
            // remember how many chars were removed
            if (cnt == count && i == y_size - 1) {
              lendiff -= ml_get_len(lnum);
            }
          }
        }

        bcount_t totsize = 0;
        int lastsize = 0;
        if (y_type == kMTCharWise
            || (y_type == kMTLineWise && (flags & PUT_LINE_SPLIT))) {
          for (i = 0; i < y_size - 1; i++) {
            totsize += (bcount_t)y_array[i].size + 1;
          }
          lastsize = (int)y_array[y_size - 1].size;
          totsize += lastsize;
        }
        if (y_type == kMTCharWise) {
          extmark_splice(curbuf, (int)new_cursor.lnum - 1, col, 0, 0, 0,
                         (int)y_size - 1, lastsize, totsize,
                         kExtmarkUndo);
        } else if (y_type == kMTLineWise && (flags & PUT_LINE_SPLIT)) {
          // Account for last pasted NL + last NL
          extmark_splice(curbuf, (int)new_cursor.lnum - 1, split_pos, 0, 0, 0,
                         (int)y_size + 1, 0, totsize + 2, kExtmarkUndo);
        }

        if (cnt == 1) {
          new_lnum = lnum;
        }
      }

error:
      // Adjust marks.
      if (y_type == kMTLineWise) {
        curbuf->b_op_start.col = 0;
        if (dir == FORWARD) {
          curbuf->b_op_start.lnum++;
        }
      }

      ExtmarkOp kind = (y_type == kMTLineWise && !(flags & PUT_LINE_SPLIT))
                       ? kExtmarkUndo : kExtmarkNOOP;
      mark_adjust(curbuf->b_op_start.lnum + (y_type == kMTCharWise),
                  (linenr_T)MAXLNUM, nr_lines, 0, kind);

      // note changed text for displaying and folding
      if (y_type == kMTCharWise) {
        changed_lines(curbuf, curwin->w_cursor.lnum, col,
                      curwin->w_cursor.lnum + 1, nr_lines, true);
      } else {
        changed_lines(curbuf, curbuf->b_op_start.lnum, 0,
                      curbuf->b_op_start.lnum, nr_lines, true);
      }

      // Put the '] mark on the first byte of the last inserted character.
      // Correct the length for change in indent.
      curbuf->b_op_end.lnum = new_lnum;
      col = MAX(0, (colnr_T)y_array[y_size - 1].size - lendiff);
      if (col > 1) {
        curbuf->b_op_end.col = col - 1;
        if (y_array[y_size - 1].size > 0) {
          curbuf->b_op_end.col -= utf_head_off(y_array[y_size - 1].data,
                                               y_array[y_size - 1].data
                                               + y_array[y_size - 1].size - 1);
        }
      } else {
        curbuf->b_op_end.col = 0;
      }

      if (flags & PUT_CURSLINE) {
        // ":put": put cursor on last inserted line
        curwin->w_cursor.lnum = lnum;
        beginline(BL_WHITE | BL_FIX);
      } else if (flags & PUT_CURSEND) {
        // put cursor after inserted text
        if (y_type == kMTLineWise) {
          if (lnum >= curbuf->b_ml.ml_line_count) {
            curwin->w_cursor.lnum = curbuf->b_ml.ml_line_count;
          } else {
            curwin->w_cursor.lnum = lnum + 1;
          }
          curwin->w_cursor.col = 0;
        } else {
          curwin->w_cursor.lnum = new_lnum;
          curwin->w_cursor.col = col;
          curbuf->b_op_end = curwin->w_cursor;
          if (col > 1) {
            curbuf->b_op_end.col = col - 1;
          }
        }
      } else if (y_type == kMTLineWise) {
        // put cursor on first non-blank in first inserted line
        curwin->w_cursor.col = 0;
        if (dir == FORWARD) {
          curwin->w_cursor.lnum++;
        }
        beginline(BL_WHITE | BL_FIX);
      } else {  // put cursor on first inserted character
        curwin->w_cursor = new_cursor;
      }
    }
  }

  msgmore(nr_lines);
  curwin->w_set_curswant = true;

  // Make sure the cursor is not after the NUL.
  int len = get_cursor_line_len();
  if (curwin->w_cursor.col > len) {
    if (cur_ve_flags == kOptVeFlagAll) {
      curwin->w_cursor.coladd = curwin->w_cursor.col - len;
    }
    curwin->w_cursor.col = len;
  }

end:
  if (cmdmod.cmod_flags & CMOD_LOCKMARKS) {
    curbuf->b_op_start = orig_start;
    curbuf->b_op_end = orig_end;
  }
  if (allocated) {
    xfree(insert_string.data);
  }
  if (regname == '=') {
    xfree(y_array);
  }

  VIsual_active = false;

  // If the cursor is past the end of the line put it at the end.
  adjust_cursor_eol();
}

/// display a string for do_dis()
/// truncate at end of screen line
///
/// @param skip_esc  if true, ignore trailing ESC
static void dis_msg(const char *p, bool skip_esc)
  FUNC_ATTR_NONNULL_ALL
{
  int n = Columns - 6;
  while (*p != NUL
         && !(*p == ESC && skip_esc && *(p + 1) == NUL)
         && (n -= ptr2cells(p)) >= 0) {
    int l;
    if ((l = utfc_ptr2len(p)) > 1) {
      msg_outtrans_len(p, l, 0, false);
      p += l;
    } else {
      msg_outtrans_len(p++, 1, 0, false);
    }
  }
  os_breakcheck();
}

/// ":dis" and ":registers": Display the contents of the yank registers.
void ex_display(exarg_T *eap)
{
  char *p;
  yankreg_T *yb;
  char *arg = eap->arg;
  int type;

  if (arg != NULL && *arg == NUL) {
    arg = NULL;
  }
  int hl_id = HLF_8;

  msg_ext_set_kind("list_cmd");
  msg_ext_skip_flush = true;
  // Highlight title
  msg_puts_title(_("\nType Name Content"));
  for (int i = -1; i < NUM_REGISTERS && !got_int; i++) {
    int name = get_register_name(i);
    if (arg != NULL && vim_strchr(arg, name) == NULL) {
      continue;             // did not ask for this register
    }

    switch (get_reg_type(name, NULL)) {
    case kMTLineWise:
      type = 'l'; break;
    case kMTCharWise:
      type = 'c'; break;
    default:
      type = 'b'; break;
    }

    if (i == -1) {
      if (y_previous != NULL) {
        yb = y_previous;
      } else {
        yb = &(y_regs[0]);
      }
    } else {
      yb = &(y_regs[i]);
    }

    get_clipboard(name, &yb, true);

    if (name == mb_tolower(redir_reg)
        || (redir_reg == '"' && yb == y_previous)) {
      continue;  // do not list register being written to, the
                 // pointer can be freed
    }

    if (yb->y_array != NULL) {
      bool do_show = false;

      for (size_t j = 0; !do_show && j < yb->y_size; j++) {
        do_show = !message_filtered(yb->y_array[j].data);
      }

      if (do_show || yb->y_size == 0) {
        msg_putchar('\n');
        msg_puts("  ");
        msg_putchar(type);
        msg_puts("  ");
        msg_putchar('"');
        msg_putchar(name);
        msg_puts("   ");

        int n = Columns - 11;
        for (size_t j = 0; j < yb->y_size && n > 1; j++) {
          if (j) {
            msg_puts_hl("^J", hl_id, false);
            n -= 2;
          }
          for (p = yb->y_array[j].data;
               *p != NUL && (n -= ptr2cells(p)) >= 0; p++) {
            int clen = utfc_ptr2len(p);
            msg_outtrans_len(p, clen, 0, false);
            p += clen - 1;
          }
        }
        if (n > 1 && yb->y_type == kMTLineWise) {
          msg_puts_hl("^J", hl_id, false);
        }
      }
      os_breakcheck();
    }
  }

  // display last inserted text
  String insert = get_last_insert();
  if ((p = insert.data) != NULL
      && (arg == NULL || vim_strchr(arg, '.') != NULL) && !got_int
      && !message_filtered(p)) {
    msg_puts("\n  c  \".   ");
    dis_msg(p, true);
  }

  // display last command line
  if (last_cmdline != NULL && (arg == NULL || vim_strchr(arg, ':') != NULL)
      && !got_int && !message_filtered(last_cmdline)) {
    msg_puts("\n  c  \":   ");
    dis_msg(last_cmdline, false);
  }

  // display current file name
  if (curbuf->b_fname != NULL
      && (arg == NULL || vim_strchr(arg, '%') != NULL) && !got_int
      && !message_filtered(curbuf->b_fname)) {
    msg_puts("\n  c  \"%   ");
    dis_msg(curbuf->b_fname, false);
  }

  // display alternate file name
  if ((arg == NULL || vim_strchr(arg, '%') != NULL) && !got_int) {
    char *fname;
    linenr_T dummy;

    if (buflist_name_nr(0, &fname, &dummy) != FAIL && !message_filtered(fname)) {
      msg_puts("\n  c  \"#   ");
      dis_msg(fname, false);
    }
  }

  // display last search pattern
  if (last_search_pat() != NULL
      && (arg == NULL || vim_strchr(arg, '/') != NULL) && !got_int
      && !message_filtered(last_search_pat())) {
    msg_puts("\n  c  \"/   ");
    dis_msg(last_search_pat(), false);
  }

  // display last used expression
  if (expr_line != NULL && (arg == NULL || vim_strchr(arg, '=') != NULL)
      && !got_int && !message_filtered(expr_line)) {
    msg_puts("\n  c  \"=   ");
    dis_msg(expr_line, false);
  }
  msg_ext_skip_flush = false;
}

/// Used for getregtype()
///
/// @return  the type of a register or
///          kMTUnknown for error.
MotionType get_reg_type(int regname, colnr_T *reg_width)
{
  switch (regname) {
  case '%':     // file name
  case '#':     // alternate file name
  case '=':     // expression
  case ':':     // last command line
  case '/':     // last search-pattern
  case '.':     // last inserted text
  case Ctrl_F:  // Filename under cursor
  case Ctrl_P:  // Path under cursor, expand via "path"
  case Ctrl_W:  // word under cursor
  case Ctrl_A:  // WORD (mnemonic All) under cursor
  case '_':     // black hole: always empty
    return kMTCharWise;
  }

  if (regname != NUL && !valid_yank_reg(regname, false)) {
    return kMTUnknown;
  }

  yankreg_T *reg = get_yank_register(regname, YREG_PASTE);

  if (reg->y_array != NULL) {
    if (reg_width != NULL && reg->y_type == kMTBlockWise) {
      *reg_width = reg->y_width;
    }
    return reg->y_type;
  }
  return kMTUnknown;
}

/// When `flags` has `kGRegList` return a list with text `s`.
/// Otherwise just return `s`.
///
/// @return  a void * for use in get_reg_contents().
static void *get_reg_wrap_one_line(char *s, int flags)
{
  if (!(flags & kGRegList)) {
    return s;
  }
  list_T *const list = tv_list_alloc(1);
  tv_list_append_allocated_string(list, s);
  return list;
}

/// Gets the contents of a register.
/// @remark Used for `@r` in expressions and for `getreg()`.
///
/// @param regname  The register.
/// @param flags    see @ref GRegFlags
///
/// @returns The contents of the register as an allocated string.
/// @returns A linked list when `flags` contains @ref kGRegList.
/// @returns NULL for error.
void *get_reg_contents(int regname, int flags)
{
  // Don't allow using an expression register inside an expression.
  if (regname == '=') {
    if (flags & kGRegNoExpr) {
      return NULL;
    }
    if (flags & kGRegExprSrc) {
      return get_reg_wrap_one_line(get_expr_line_src(), flags);
    }
    return get_reg_wrap_one_line(get_expr_line(), flags);
  }

  if (regname == '@') {     // "@@" is used for unnamed register
    regname = '"';
  }

  // check for valid regname
  if (regname != NUL && !valid_yank_reg(regname, false)) {
    return NULL;
  }

  char *retval;
  bool allocated;
  if (get_spec_reg(regname, &retval, &allocated, false)) {
    if (retval == NULL) {
      return NULL;
    }
    if (allocated) {
      return get_reg_wrap_one_line(retval, flags);
    }
    return get_reg_wrap_one_line(xstrdup(retval), flags);
  }

  yankreg_T *reg = get_yank_register(regname, YREG_PUT);
  if (reg->y_array == NULL) {
    return NULL;
  }

  if (flags & kGRegList) {
    list_T *const list = tv_list_alloc((ptrdiff_t)reg->y_size);
    for (size_t i = 0; i < reg->y_size; i++) {
      tv_list_append_string(list, reg->y_array[i].data, -1);
    }

    return list;
  }

  // Compute length of resulting string.
  size_t len = 0;
  for (size_t i = 0; i < reg->y_size; i++) {
    len += reg->y_array[i].size;
    // Insert a newline between lines and after last line if y_type is kMTLineWise.
    if (reg->y_type == kMTLineWise || i < reg->y_size - 1) {
      len++;
    }
  }

  retval = xmalloc(len + 1);

  // Copy the lines of the yank register into the string.
  len = 0;
  for (size_t i = 0; i < reg->y_size; i++) {
    STRCPY(retval + len, reg->y_array[i].data);
    len += reg->y_array[i].size;

    // Insert a newline between lines and after the last line if y_type is kMTLineWise.
    if (reg->y_type == kMTLineWise || i < reg->y_size - 1) {
      retval[len++] = '\n';
    }
  }
  retval[len] = NUL;

  return retval;
}

static yankreg_T *init_write_reg(int name, yankreg_T **old_y_previous, bool must_append)
{
  if (!valid_yank_reg(name, true)) {  // check for valid reg name
    emsg_invreg(name);
    return NULL;
  }

  // Don't want to change the current (unnamed) register.
  *old_y_previous = y_previous;

  yankreg_T *reg = get_yank_register(name, YREG_YANK);
  if (!is_append_register(name) && !must_append) {
    free_register(reg);
  }
  return reg;
}

/// str_to_reg - Put a string into a register.
///
/// When the register is not empty, the string is appended.
///
/// @param y_ptr pointer to yank register
/// @param yank_type The motion type (kMTUnknown to auto detect)
/// @param str string or list of strings to put in register
/// @param len length of the string (Ignored when str_list=true.)
/// @param blocklen width of visual block, or -1 for "I don't know."
/// @param str_list True if str is `char **`.
static void str_to_reg(yankreg_T *y_ptr, MotionType yank_type, const char *str, size_t len,
                       colnr_T blocklen, bool str_list)
  FUNC_ATTR_NONNULL_ALL
{
  if (y_ptr->y_array == NULL) {  // NULL means empty register
    y_ptr->y_size = 0;
  }

  if (yank_type == kMTUnknown) {
    yank_type = ((str_list
                  || (len > 0 && (str[len - 1] == NL || str[len - 1] == CAR)))
                 ? kMTLineWise : kMTCharWise);
  }

  size_t newlines = 0;
  bool extraline = false;  // extra line at the end
  bool append = false;     // append to last line in register

  // Count the number of lines within the string
  if (str_list) {
    for (char **ss = (char **)str; *ss != NULL; ss++) {
      newlines++;
    }
  } else {
    newlines = memcnt(str, '\n', len);
    if (yank_type == kMTCharWise || len == 0 || str[len - 1] != '\n') {
      extraline = 1;
      newlines++;         // count extra newline at the end
    }
    if (y_ptr->y_size > 0 && y_ptr->y_type == kMTCharWise) {
      append = true;
      newlines--;         // uncount newline when appending first line
    }
  }

  // Without any lines make the register empty.
  if (y_ptr->y_size + newlines == 0) {
    XFREE_CLEAR(y_ptr->y_array);
    return;
  }

  // Grow the register array to hold the pointers to the new lines.
  String *pp = xrealloc(y_ptr->y_array, (y_ptr->y_size + newlines) * sizeof(String));
  y_ptr->y_array = pp;

  size_t lnum = y_ptr->y_size;  // The current line number.

  // If called with `blocklen < 0`, we have to update the yank reg's width.
  size_t maxlen = 0;

  // Find the end of each line and save it into the array.
  if (str_list) {
    for (char **ss = (char **)str; *ss != NULL; ss++, lnum++) {
      pp[lnum] = cstr_to_string(*ss);
      if (yank_type == kMTBlockWise) {
        size_t charlen = mb_string2cells(*ss);
        maxlen = MAX(maxlen, charlen);
      }
    }
  } else {
    size_t line_len;
    for (const char *start = str, *end = str + len;
         start < end + extraline;
         start += line_len + 1, lnum++) {
      int charlen = 0;

      const char *line_end = start;
      while (line_end < end) {  // find the end of the line
        if (*line_end == '\n') {
          break;
        }
        if (yank_type == kMTBlockWise) {
          charlen += utf_ptr2cells_len(line_end, (int)(end - line_end));
        }

        if (*line_end == NUL) {
          line_end++;  // registers can have NUL chars
        } else {
          line_end += utf_ptr2len_len(line_end, (int)(end - line_end));
        }
      }
      assert(line_end - start >= 0);
      line_len = (size_t)(line_end - start);
      maxlen = MAX(maxlen, (size_t)charlen);

      // When appending, copy the previous line and free it after.
      size_t extra = append ? pp[--lnum].size : 0;
      char *s = xmallocz(line_len + extra);
      if (extra > 0) {
        memcpy(s, pp[lnum].data, extra);
      }
      if (line_len > 0) {
        memcpy(s + extra, start, line_len);
      }
      size_t s_len = extra + line_len;

      if (append) {
        xfree(pp[lnum].data);
        append = false;  // only first line is appended
      }
      pp[lnum] = cbuf_as_string(s, s_len);

      // Convert NULs to '\n' to prevent truncation.
      memchrsub(pp[lnum].data, NUL, '\n', s_len);
    }
  }
  y_ptr->y_type = yank_type;
  y_ptr->y_size = lnum;
  XFREE_CLEAR(y_ptr->additional_data);
  y_ptr->timestamp = os_time();
  if (yank_type == kMTBlockWise) {
    y_ptr->y_width = (blocklen == -1 ? (colnr_T)maxlen - 1 : blocklen);
  } else {
    y_ptr->y_width = 0;
  }
}

static void finish_write_reg(int name, yankreg_T *reg, yankreg_T *old_y_previous)
{
  // Send text of clipboard register to the clipboard.
  set_clipboard(name, reg);

  // ':let @" = "val"' should change the meaning of the "" register
  if (name != '"') {
    y_previous = old_y_previous;
  }
}

/// store `str` in register `name`
///
/// @see write_reg_contents_ex
void write_reg_contents(int name, const char *str, ssize_t len, int must_append)
{
  write_reg_contents_ex(name, str, len, must_append, kMTUnknown, 0);
}

void write_reg_contents_lst(int name, char **strings, bool must_append, MotionType yank_type,
                            colnr_T block_len)
{
  if (name == '/' || name == '=') {
    char *s = strings[0];
    if (strings[0] == NULL) {
      s = "";
    } else if (strings[1] != NULL) {
      emsg(_(e_search_pattern_and_expression_register_may_not_contain_two_or_more_lines));
      return;
    }
    write_reg_contents_ex(name, s, -1, must_append, yank_type, block_len);
    return;
  }

  // black hole: nothing to do
  if (name == '_') {
    return;
  }

  yankreg_T *old_y_previous, *reg;
  if (!(reg = init_write_reg(name, &old_y_previous, must_append))) {
    return;
  }

  str_to_reg(reg, yank_type, (char *)strings, strlen((char *)strings),
             block_len, true);
  finish_write_reg(name, reg, old_y_previous);
}

/// write_reg_contents_ex - store `str` in register `name`
///
/// If `str` ends in '\n' or '\r', use linewise, otherwise use charwise.
///
/// @warning when `name` is '/', `len` and `must_append` are ignored. This
///          means that `str` MUST be NUL-terminated.
///
/// @param name The name of the register
/// @param str The contents to write
/// @param len If >= 0, write `len` bytes of `str`. Otherwise, write
///               `strlen(str)` bytes. If `len` is larger than the
///               allocated size of `src`, the behaviour is undefined.
/// @param must_append If true, append the contents of `str` to the current
///                    contents of the register. Note that regardless of
///                    `must_append`, this function will append when `name`
///                    is an uppercase letter.
/// @param yank_type The motion type (kMTUnknown to auto detect)
/// @param block_len width of visual block
void write_reg_contents_ex(int name, const char *str, ssize_t len, bool must_append,
                           MotionType yank_type, colnr_T block_len)
{
  if (len < 0) {
    len = (ssize_t)strlen(str);
  }

  // Special case: '/' search pattern
  if (name == '/') {
    set_last_search_pat(str, RE_SEARCH, true, true);
    return;
  }

  if (name == '#') {
    buf_T *buf;

    if (ascii_isdigit(*str)) {
      int num = atoi(str);

      buf = buflist_findnr(num);
      if (buf == NULL) {
        semsg(_(e_nobufnr), (int64_t)num);
      }
    } else {
      buf = buflist_findnr(buflist_findpat(str, str + len, true, false, false));
    }
    if (buf == NULL) {
      return;
    }
    curwin->w_alt_fnum = buf->b_fnum;
    return;
  }

  if (name == '=') {
    size_t offset = 0;
    size_t totlen = (size_t)len;

    if (must_append && expr_line) {
      // append has been specified and expr_line already exists, so we'll
      // append the new string to expr_line.
      size_t exprlen = strlen(expr_line);

      totlen += exprlen;
      offset = exprlen;
    }

    // modify the global expr_line, extend/shrink it if necessary (realloc).
    // Copy the input string into the adjusted memory at the specified
    // offset.
    expr_line = xrealloc(expr_line, totlen + 1);
    memcpy(expr_line + offset, str, (size_t)len);
    expr_line[totlen] = NUL;

    return;
  }

  if (name == '_') {        // black hole: nothing to do
    return;
  }

  yankreg_T *old_y_previous, *reg;
  if (!(reg = init_write_reg(name, &old_y_previous, must_append))) {
    return;
  }
  str_to_reg(reg, yank_type, str, (size_t)len, block_len, false);
  finish_write_reg(name, reg, old_y_previous);
}

/// @param[out] reg Expected to be empty
bool prepare_yankreg_from_object(yankreg_T *reg, String regtype, size_t lines)
{
  char type = regtype.data ? regtype.data[0] : NUL;

  switch (type) {
  case 0:
    reg->y_type = kMTUnknown;
    break;
  case 'v':
  case 'c':
    reg->y_type = kMTCharWise;
    break;
  case 'V':
  case 'l':
    reg->y_type = kMTLineWise;
    break;
  case 'b':
  case Ctrl_V:
    reg->y_type = kMTBlockWise;
    break;
  default:
    return false;
  }

  reg->y_width = 0;
  if (regtype.size > 1) {
    if (reg->y_type != kMTBlockWise) {
      return false;
    }

    // allow "b7" for a block at least 7 spaces wide
    if (!ascii_isdigit(regtype.data[1])) {
      return false;
    }
    const char *p = regtype.data + 1;
    reg->y_width = getdigits_int((char **)&p, false, 1) - 1;
    if (regtype.size > (size_t)(p - regtype.data)) {
      return false;
    }
  }

  reg->additional_data = NULL;
  reg->timestamp = 0;
  return true;
}

void finish_yankreg_from_object(yankreg_T *reg, bool clipboard_adjust)
{
  if (reg->y_size > 0 && reg->y_array[reg->y_size - 1].size == 0) {
    // a known-to-be charwise yank might have a final linebreak
    // but otherwise there is no line after the final newline
    if (reg->y_type != kMTCharWise) {
      if (reg->y_type == kMTUnknown || clipboard_adjust) {
        reg->y_size--;
      }
      if (reg->y_type == kMTUnknown) {
        reg->y_type = kMTLineWise;
      }
    }
  } else {
    if (reg->y_type == kMTUnknown) {
      reg->y_type = kMTCharWise;
    }
  }

  update_yankreg_width(reg);
}
