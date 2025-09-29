// clipboard.c: Functions to handle the clipboard

#include <assert.h>

#include "nvim/api/private/helpers.h"
#include "nvim/ascii_defs.h"
#include "nvim/clipboard.h"
#include "nvim/eval.h"
#include "nvim/eval/typval.h"
#include "nvim/option_vars.h"
#include "nvim/register.h"

#include "clipboard.c.generated.h"

// for behavior between start_batch_changes() and end_batch_changes())
static int batch_change_count = 0;           // inside a script
static bool clipboard_delay_update = false;  // delay clipboard update
static bool clipboard_needs_update = false;  // clipboard was updated
static bool clipboard_didwarn = false;

/// Determine if register `*name` should be used as a clipboard.
/// In an unnamed operation, `*name` is `NUL` and will be adjusted to */+ if
/// `clipboard=unnamed[plus]` is set.
///
/// @param name The name of register, or `NUL` if unnamed.
/// @param quiet Suppress error messages
/// @param writing if we're setting the contents of the clipboard
///
/// @returns the yankreg that should be written into, or `NULL`
/// if the register isn't a clipboard or provider isn't available.
yankreg_T *adjust_clipboard_name(int *name, bool quiet, bool writing)
{
#define MSG_NO_CLIP "clipboard: No provider. " \
  "Try \":checkhealth\" or \":h clipboard\"."

  yankreg_T *target = NULL;
  bool explicit_cb_reg = (*name == '*' || *name == '+');
  bool implicit_cb_reg = (*name == NUL) && (cb_flags & (kOptCbFlagUnnamed | kOptCbFlagUnnamedplus));
  if (!explicit_cb_reg && !implicit_cb_reg) {
    goto end;
  }

  if (!eval_has_provider("clipboard", false)) {
    if (batch_change_count <= 1 && !quiet
        && (!clipboard_didwarn || (explicit_cb_reg && !redirecting()))) {
      clipboard_didwarn = true;
      // Do NOT error (emsg()) here--if it interrupts :redir we get into
      // a weird state, stuck in "redirect mode".
      msg(MSG_NO_CLIP, 0);
    }
    // ... else, be silent (don't flood during :while, :redir, etc.).
    goto end;
  }

  if (explicit_cb_reg) {
    target = get_y_register(*name == '*' ? STAR_REGISTER : PLUS_REGISTER);
    if (writing && (cb_flags & (*name == '*' ? kOptCbFlagUnnamed : kOptCbFlagUnnamedplus))) {
      clipboard_needs_update = false;
    }
    goto end;
  } else {  // unnamed register: "implicit" clipboard
    if (writing && clipboard_delay_update) {
      // For "set" (copy), defer the clipboard call.
      clipboard_needs_update = true;
      goto end;
    } else if (!writing && clipboard_needs_update) {
      // For "get" (paste), use the internal value.
      goto end;
    }

    if (cb_flags & kOptCbFlagUnnamedplus) {
      *name = (cb_flags & kOptCbFlagUnnamed && writing) ? '"' : '+';
      target = get_y_register(PLUS_REGISTER);
    } else {
      *name = '*';
      target = get_y_register(STAR_REGISTER);
    }
    goto end;
  }

end:
  return target;
}

bool get_clipboard(int name, yankreg_T **target, bool quiet)
{
  // show message on error
  bool errmsg = true;

  yankreg_T *reg = adjust_clipboard_name(&name, quiet, false);
  if (reg == NULL) {
    return false;
  }
  free_register(reg);

  list_T *const args = tv_list_alloc(1);
  const char regname = (char)name;
  tv_list_append_string(args, &regname, 1);

  typval_T result = eval_call_provider("clipboard", "get", args, false);

  if (result.v_type != VAR_LIST) {
    if (result.v_type == VAR_NUMBER && result.vval.v_number == 0) {
      // failure has already been indicated by provider
      errmsg = false;
    }
    goto err;
  }

  list_T *res = result.vval.v_list;
  list_T *lines = NULL;
  if (tv_list_len(res) == 2
      && TV_LIST_ITEM_TV(tv_list_first(res))->v_type == VAR_LIST) {
    lines = TV_LIST_ITEM_TV(tv_list_first(res))->vval.v_list;
    if (TV_LIST_ITEM_TV(tv_list_last(res))->v_type != VAR_STRING) {
      goto err;
    }
    char *regtype = TV_LIST_ITEM_TV(tv_list_last(res))->vval.v_string;
    if (regtype == NULL || strlen(regtype) > 1) {
      goto err;
    }
    switch (regtype[0]) {
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
      goto err;
    }
  } else {
    lines = res;
    // provider did not specify regtype, calculate it below
    reg->y_type = kMTUnknown;
  }

  reg->y_array = xcalloc((size_t)tv_list_len(lines), sizeof(String));
  reg->y_size = (size_t)tv_list_len(lines);
  reg->additional_data = NULL;
  reg->timestamp = 0;
  // Timestamp is not saved for clipboard registers because clipboard registers
  // are not saved in the ShaDa file.

  size_t tv_idx = 0;
  TV_LIST_ITER_CONST(lines, li, {
    if (TV_LIST_ITEM_TV(li)->v_type != VAR_STRING) {
      goto err;
    }
    const char *s = TV_LIST_ITEM_TV(li)->vval.v_string;
    reg->y_array[tv_idx++] = cstr_to_string(s != NULL ? s : "");
  });

  if (reg->y_size > 0 && reg->y_array[reg->y_size - 1].size == 0) {
    // a known-to-be charwise yank might have a final linebreak
    // but otherwise there is no line after the final newline
    if (reg->y_type != kMTCharWise) {
      xfree(reg->y_array[reg->y_size - 1].data);
      reg->y_size--;
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

  *target = reg;
  return true;

err:
  if (reg->y_array) {
    for (size_t i = 0; i < reg->y_size; i++) {
      xfree(reg->y_array[i].data);
    }
    xfree(reg->y_array);
  }
  reg->y_array = NULL;
  reg->y_size = 0;
  reg->additional_data = NULL;
  reg->timestamp = 0;
  if (errmsg) {
    emsg("clipboard: provider returned invalid data");
  }
  *target = reg;
  return false;
}

void set_clipboard(int name, yankreg_T *reg)
{
  if (!adjust_clipboard_name(&name, false, true)) {
    return;
  }

  list_T *const lines = tv_list_alloc((ptrdiff_t)reg->y_size + (reg->y_type != kMTCharWise));

  for (size_t i = 0; i < reg->y_size; i++) {
    tv_list_append_string(lines, reg->y_array[i].data, -1);
  }

  char regtype;
  switch (reg->y_type) {
  case kMTLineWise:
    regtype = 'V';
    tv_list_append_string(lines, NULL, 0);
    break;
  case kMTCharWise:
    regtype = 'v';
    break;
  case kMTBlockWise:
    regtype = 'b';
    tv_list_append_string(lines, NULL, 0);
    break;
  case kMTUnknown:
    abort();
  }

  list_T *args = tv_list_alloc(3);
  tv_list_append_list(args, lines);
  tv_list_append_string(args, &regtype, 1);
  tv_list_append_string(args, ((char[]) { (char)name }), 1);

  eval_call_provider("clipboard", "set", args, true);
}

/// Avoid slow things (clipboard) during batch operations (while/for-loops).
void start_batch_changes(void)
{
  if (++batch_change_count > 1) {
    return;
  }
  clipboard_delay_update = true;
}

/// Counterpart to start_batch_changes().
void end_batch_changes(void)
{
  if (--batch_change_count > 0) {
    // recursive
    return;
  }
  clipboard_delay_update = false;
  if (clipboard_needs_update) {
    // must be before, as set_clipboard will invoke
    // start/end_batch_changes recursively
    clipboard_needs_update = false;
    // unnamed ("implicit" clipboard)
    set_clipboard(NUL, get_y_previous());
  }
}

int save_batch_count(void)
{
  int save_count = batch_change_count;
  batch_change_count = 0;
  clipboard_delay_update = false;
  if (clipboard_needs_update) {
    clipboard_needs_update = false;
    // unnamed ("implicit" clipboard)
    set_clipboard(NUL, get_y_previous());
  }
  return save_count;
}

void restore_batch_count(int save_count)
{
  assert(batch_change_count == 0);
  batch_change_count = save_count;
  if (batch_change_count > 0) {
    clipboard_delay_update = true;
  }
}
