local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local nvim = require 'elisp.nvim'
local signal = require 'elisp.signal'
local alloc = require 'elisp.alloc'

local M = {}

---@enum vim.elisp.bvar
M.bvar = {
  name = 'name',
  filename = 'filename',
  directory = 'directory',
  backed_up = 'backed_up',
  save_length = 'save_length',
  auto_save_file_name = 'auto_save_file_name',
  read_only = 'read_only',
  mark = 'mark',
  local_var_alist = 'local_var_alist',
  major_mode = 'major_mode',
  local_minor_modes = 'local_minor_modes',
  mode_name = 'mode_name',
  mode_line_format = 'mode_line_format',
  header_line_format = 'header_line_format',
  tab_line_format = 'tab_line_format',
  keymap = 'keymap',
  abbrev_table = 'abbrev_table',
  syntax_table = 'syntax_table',
  category_table = 'category_table',
  case_fold_search = 'case_fold_search',
  tab_width = 'tab_width',
  fill_column = 'fill_column',
  left_margin = 'left_margin',
  auto_fill_function = 'auto_fill_function',
  downcase_table = 'downcase_table',
  upcase_table = 'upcase_table',
  case_canon_table = 'case_canon_table',
  case_eqv_table = 'case_eqv_table',
  truncate_lines = 'truncate_lines',
  word_wrap = 'word_wrap',
  ctl_arrow = 'ctl_arrow',
  bidi_display_reordering = 'bidi_display_reordering',
  bidi_paragraph_direction = 'bidi_paragraph_direction',
  bidi_paragraph_separate_re = 'bidi_paragraph_separate_re',
  bidi_paragraph_start_re = 'bidi_paragraph_start_re',
  selective_display = 'selective_display',
  selective_display_ellipses = 'selective_display_ellipses',
  overwrite_mode = 'overwrite_mode',
  abbrev_mode = 'abbrev_mode',
  display_table = 'display_table',
  mark_active = 'mark_active',
  enable_multibyte_characters = 'enable_multibyte_characters',
  buffer_file_coding_system = 'buffer_file_coding_system',
  file_format = 'file_format',
  auto_save_file_format = 'auto_save_file_format',
  cache_long_scans = 'cache_long_scans',
  width_table = 'width_table',
  pt_marker = 'pt_marker',
  begv_marker = 'begv_marker',
  zv_marker = 'zv_marker',
  point_before_scroll = 'point_before_scroll',
  file_truename = 'file_truename',
  invisibility_spec = 'invisibility_spec',
  last_selected_window = 'last_selected_window',
  display_count = 'display_count',
  left_margin_cols = 'left_margin_cols',
  right_margin_cols = 'right_margin_cols',
  left_fringe_width = 'left_fringe_width',
  right_fringe_width = 'right_fringe_width',
  fringes_outside_margins = 'fringes_outside_margins',
  scroll_bar_width = 'scroll_bar_width',
  scroll_bar_height = 'scroll_bar_height',
  vertical_scroll_bar_type = 'vertical_scroll_bar_type',
  horizontal_scroll_bar_type = 'horizontal_scroll_bar_type',
  indicate_empty_lines = 'indicate_empty_lines',
  indicate_buffer_boundaries = 'indicate_buffer_boundaries',
  fringe_indicator_alist = 'fringe_indicator_alist',
  fringe_cursor_alist = 'fringe_cursor_alist',
  display_time = 'display_time',
  scroll_up_aggressively = 'scroll_up_aggressively',
  scroll_down_aggressively = 'scroll_down_aggressively',
  cursor_type = 'cursor_type',
  extra_line_spacing = 'extra_line_spacing',
  ts_parser_list = 'ts_parser_list',
  cursor_in_non_selected_windows = 'cursor_in_non_selected_windows',
  undo_list = 'undo_list',
}

---@param x vim.elisp.obj
---@return vim.elisp.obj
---@nodiscard
function M.check_fixnum_coerce_marker(x)
  if lisp.markerp(x) then
    error('TODO')
  elseif lisp.bignump(x) then
    error('TODO')
  end
  lisp.check_fixnum(x)
  return x
end
---@param symname string
---@param bvar vim.elisp.bvar
---@param predicate vim.elisp.obj
---@param doc string
local function defvar_per_buffer(symname, bvar, predicate, doc)
  vars.defvar_forward(nil, symname, doc, function(con)
    local buffer = con.buffer
      or (
        nvim.buffer_get_current() --[[@as vim.elisp._buffer]]
      )
    return nvim.bvar(buffer, bvar)
  end, function(val, con)
    local buffer = con.buffer
      or (
        nvim.buffer_get_current() --[[@as vim.elisp._buffer]]
      )
    nvim.bvar_set(buffer, bvar, val)
  end, true)
end

---@param buffer vim.elisp._buffer
---@return boolean
function M.BUFFERLIVEP(buffer)
  return not lisp.nilp(nvim.bvar(buffer, M.bvar.name))
end
---@param c number
---@return number
function M.downcase(c)
  if _G.vim_elisp_later then
    error('TODO: BVAR(current_buffer,downcase_table), needs BVAR to be implemented first')
  else
    return string.byte(vim.fn.tolower(string.char(c)))
  end
end

---@type vim.elisp.F
local F = {}
F.get_buffer = {
  'get-buffer',
  1,
  1,
  0,
  [[Return the buffer named BUFFER-OR-NAME.
BUFFER-OR-NAME must be either a string or a buffer.  If BUFFER-OR-NAME
is a string and there is no buffer with that name, return nil.  If
BUFFER-OR-NAME is a buffer, return it as given.]],
}
function F.get_buffer.f(buffer_or_name)
  if lisp.bufferp(buffer_or_name) then
    return buffer_or_name
  end
  lisp.check_string(buffer_or_name)
  return nvim.buffer_get_by_name(buffer_or_name)
end
local function nsberror(spec)
  if lisp.stringp(spec) then
    signal.error('No buffer named %s', lisp.sdata(spec))
  end
  signal.error('Invalid buffer argument')
end
F.set_buffer = {
  'set-buffer',
  1,
  1,
  0,
  [[Make buffer BUFFER-OR-NAME current for editing operations.
BUFFER-OR-NAME may be a buffer or the name of an existing buffer.
See also `with-current-buffer' when you want to make a buffer current
temporarily.  This function does not display the buffer, so its effect
ends when the current command terminates.  Use `switch-to-buffer' or
`pop-to-buffer' to switch buffers permanently.
The return value is the buffer made current.]],
}
function F.set_buffer.f(buf)
  local buffer = vars.F.get_buffer(buf)
  if lisp.nilp(buffer) then
    nsberror(buf)
  end
  if
    not M.BUFFERLIVEP(buffer --[[@as vim.elisp._buffer]])
  then
    signal.error('Selecting deleted buffer')
  end
  nvim.buffer_set_current(buffer --[[@as vim.elisp._buffer]])
  return buffer
end
F.get_buffer_create = {
  'get-buffer-create',
  1,
  2,
  0,
  [[Return the buffer specified by BUFFER-OR-NAME, creating a new one if needed.
If BUFFER-OR-NAME is a string and a live buffer with that name exists,
return that buffer.  If no such buffer exists, create a new buffer with
that name and return it.

If BUFFER-OR-NAME starts with a space, the new buffer does not keep undo
information.  If optional argument INHIBIT-BUFFER-HOOKS is non-nil, the
new buffer does not run the hooks `kill-buffer-hook',
`kill-buffer-query-functions', and `buffer-list-update-hook'.  This
avoids slowing down internal or temporary buffers that are never
presented to users or passed on to other applications.

If BUFFER-OR-NAME is a buffer instead of a string, return it as given,
even if it is dead.  The return value is never nil.]],
}
function F.get_buffer_create.f(buffer_or_name, inhibit_buffer_hooks)
  local buffer = vars.F.get_buffer(buffer_or_name)
  if not lisp.nilp(buffer) then
    return buffer
  end
  if lisp.schars(buffer_or_name) == 0 then
    signal.error('Empty string for buffer name is not allowed')
  end
  return nvim.buffer_create(buffer_or_name)
end
F.force_mode_line_update = {
  'force-mode-line-update',
  0,
  1,
  0,
  [[Force redisplay of the current buffer's mode line and header line.
With optional non-nil ALL, force redisplay of all mode lines, tab lines and
header lines.  This function also forces recomputation of the
menu bar menus and the frame title.]],
}
function F.force_mode_line_update.f(all)
  if lisp.nilp(all) then
    vim.cmd.redrawstatus()
    vim.cmd.redrawtabline()
  else
    vim.cmd.redrawstatus { bang = true }
    vim.cmd.redrawtabline()
  end
  return all
end
F.buffer_list = {
  'buffer-list',
  0,
  1,
  0,
  [[Return a list of all live buffers.
If the optional arg FRAME is a frame, return the buffer list in the
proper order for that frame: the buffers shown in FRAME come first,
followed by the rest of the buffers.]],
}
function F.buffer_list.f(frame)
  if _G.vim_elisp_later then
    error('TODO')
  end
  return nvim.buffer_clist()
end
F.current_buffer = { 'current-buffer', 0, 0, 0, [[Return the current buffer as a Lisp object.]] }
function F.current_buffer.f()
  return nvim.buffer_get_current()
end
---@param buffer vim.elisp.obj
---@return vim.elisp._buffer
function M.decode_buffer(buffer)
  if lisp.nilp(buffer) then
    return nvim.buffer_get_current() --[[@as vim.elisp._buffer]]
  end
  lisp.check_buffer(buffer)
  return buffer --[[@as vim.elisp._buffer]]
end
F.buffer_modified_p = {
  'buffer-modified-p',
  0,
  1,
  0,
  [[Return non-nil if BUFFER was modified since its file was last read or saved.
No argument or nil as argument means use current buffer as BUFFER.

If BUFFER was autosaved since it was last modified, this function
returns the symbol `autosaved'.]],
}
function F.buffer_modified_p.f(buffer)
  local buf = M.decode_buffer(buffer)
  if nvim.buf_save_modiff(buf) < nvim.buf_modiff(buf) then
    if _G.vim_elisp_later then
      error('TODO: how to detect autosaved buffer?')
    end
    return vars.Qt
  end
  return vars.Qnil
end
F.set_buffer_modified_p = {
  'set-buffer-modified-p',
  1,
  1,
  0,
  [[Mark current buffer as modified or unmodified according to FLAG.
A non-nil FLAG means mark the buffer modified.
In addition, this function unconditionally forces redisplay of the
mode lines of the windows that display the current buffer, and also
locks or unlocks the file visited by the buffer, depending on whether
the function's argument is non-nil, but only if both `buffer-file-name'
and `buffer-file-truename' are non-nil.]],
}
function F.set_buffer_modified_p.f(flag)
  nvim.buf_set_modiff(true, not lisp.nilp(flag))
  return vars.F.force_mode_line_update(vars.Qnil)
end
F.buffer_name = {
  'buffer-name',
  0,
  1,
  0,
  [[Return the name of BUFFER, as a string.
BUFFER defaults to the current buffer.
Return nil if BUFFER has been killed.]],
}
function F.buffer_name.f(buffer)
  return nvim.bvar(M.decode_buffer(buffer), M.bvar.name)
end
F.buffer_file_name = {
  'buffer-file-name',
  0,
  1,
  0,
  [[Return name of file BUFFER is visiting, or nil if none.
No argument or nil as argument means use the current buffer.]],
}
function F.buffer_file_name.f(buffer)
  return nvim.bvar(M.decode_buffer(buffer), M.bvar.filename)
end
---@param variable vim.elisp.obj
---@param buffer vim.elisp.obj
---@return vim.elisp.obj?
local function buffer_local_value(variable, buffer)
  lisp.check_symbol(variable)
  lisp.check_buffer(buffer)
  local buf = buffer --[[@as vim.elisp._buffer]]
  local sym = variable --[[@as vim.elisp._symbol]]
  if sym.redirect == lisp.symbol_redirect.plainval then
    return sym.value --[[@as vim.elisp.obj?]]
  elseif sym.redirect == lisp.symbol_redirect.forwarded then
    local fwd = sym.value --[[@as vim.elisp.forward]]
    if fwd.isbuffer then
      return fwd[1]({ buffer = buf })
    end
    return vars.F.default_value(variable)
  else
    error('TODO')
  end
end
F.buffer_local_value = {
  'buffer-local-value',
  2,
  2,
  0,
  [[Return the value of VARIABLE in BUFFER.
If VARIABLE does not have a buffer-local binding in BUFFER, the value
is the default binding of the variable.]],
}
function F.buffer_local_value.f(variable, buffer)
  local result = buffer_local_value(variable, buffer)
  if result == nil then
    signal.xsignal(vars.Qvoid_variable, variable)
    error('unreachable')
  end
  return result
end
F.buffer_enable_undo = {
  'buffer-enable-undo',
  0,
  1,
  '',
  [[Start keeping undo information for buffer BUFFER.
No argument or nil as argument means do this for the current buffer.]],
}
function F.buffer_enable_undo.f(buffer)
  local real_buffer
  if lisp.nilp(buffer) then
    real_buffer = nvim.buffer_get_current()
  else
    real_buffer = vars.F.get_buffer(buffer)
    if lisp.nilp(real_buffer) then
      nsberror(buffer)
    end
  end
  if
    lisp.eq(nvim.bvar(real_buffer --[[@as vim.elisp._buffer]], M.bvar.undo_list), vars.Qt)
  then
    nvim.bvar_set(real_buffer --[[@as vim.elisp._buffer]], M.bvar.undo_list, vars.Qnil)
  end
  return vars.Qnil
end
F.make_overlay = {
  'make-overlay',
  2,
  5,
  0,
  [[Create a new overlay with range BEG to END in BUFFER and return it.
If omitted, BUFFER defaults to the current buffer.
BEG and END may be integers or markers.
The fourth arg FRONT-ADVANCE, if non-nil, makes the marker
for the front of the overlay advance when text is inserted there
\(which means the text *is not* included in the overlay).
The fifth arg REAR-ADVANCE, if non-nil, makes the marker
for the rear of the overlay advance when text is inserted there
\(which means the text *is* included in the overlay).]],
}
F.make_overlay.f = function(beg, end_, buffer, front_advance, rear_advance)
  if lisp.nilp(buffer) then
    buffer = nvim.buffer_get_current()
  else
    lisp.check_buffer(buffer)
  end
  local b = buffer --[[@as vim.elisp._buffer]]
  if not M.BUFFERLIVEP(b) then
    signal.error('Attempt to create overlay in a dead buffer')
  end
  if lisp.markerp(beg) and error('TODO') then
    error('TODO')
  end
  if lisp.markerp(end_) and error('TODO') then
    error('TODO')
  end
  beg = M.check_fixnum_coerce_marker(beg)
  end_ = M.check_fixnum_coerce_marker(end_)
  if lisp.fixnum(beg) > lisp.fixnum(end_) then
    beg, end_ = end_, beg
  end
  local obeg = lisp.clip_to_bounds(1, lisp.fixnum(beg), nvim.buffer_z(b))
  local oend = lisp.clip_to_bounds(obeg, lisp.fixnum(end_), nvim.buffer_z(b))
  return nvim.overlay_make(b, obeg, oend, not lisp.nilp(front_advance), not lisp.nilp(rear_advance))
end
F.overlay_put = {
  'overlay-put',
  3,
  3,
  0,
  [[Set one property of overlay OVERLAY: give property PROP value VALUE.
VALUE will be returned.]],
}
function F.overlay_put.f(overlay, prop, value)
  if _G.vim_elisp_later then
    error('TODO: some of the prop are special and should change the underlying extmark')
  end
  lisp.check_overlay(overlay)
  local ov = overlay --[[@as vim.elisp._overlay]]
  local b = nvim.overlay_buffer(ov)
  local plist = nvim.overlay_plist(ov)
  local tail = plist
  local changed
  while lisp.consp(tail) and lisp.consp(lisp.xcdr(tail)) do
    if lisp.eq(lisp.xcar(tail), prop) then
      changed = not lisp.eq(lisp.xcar(lisp.xcdr(tail)), value)
      lisp.xsetcar(lisp.xcdr(tail), value)
      goto found
    end
    tail = lisp.xcdr(lisp.xcdr(tail))
  end
  changed = not lisp.nilp(value)
  nvim.overlay_set_plist(ov, vars.F.cons(prop, vars.F.cons(value, plist)))
  ::found::
  if b then
    if _G.vim_elisp_later then
      error('TODO')
    end
  end
  return value
end
F.delete_overlay = { 'delete-overlay', 1, 1, 0, [[Delete the overlay OVERLAY from its buffer.]] }
function F.delete_overlay.f(overlay)
  lisp.check_overlay(overlay)
  nvim.overlay_drop(overlay)
  return vars.Qnil
end

function M.init()
  defvar_per_buffer(
    'enable-multibyte-characters',
    M.bvar.enable_multibyte_characters,
    vars.Qnil,
    [[Non-nil means the buffer contents are regarded as multi-byte characters.
Otherwise they are regarded as unibyte.  This affects the display,
file I/O and the behavior of various editing commands.

This variable is buffer-local but you cannot set it directly;
use the function `set-buffer-multibyte' to change a buffer's representation.
To prevent any attempts to set it or make it buffer-local, Emacs will
signal an error in those cases.
See also Info node `(elisp)Text Representations'.]]
  )
  local lread = require 'elisp.lread'
  lisp.make_symbol_constant(lread.intern_c_string('enable-multibyte-characters'))

  defvar_per_buffer(
    'buffer-read-only',
    M.bvar.read_only,
    vars.Qnil,
    [[Non-nil if this buffer is read-only.]]
  )

  defvar_per_buffer(
    'buffer-undo-list',
    M.bvar.undo_list,
    vars.Qnil,
    [[List of undo entries in current buffer.
Recent changes come first; older changes follow newer.

An entry (BEG . END) represents an insertion which begins at
position BEG and ends at position END.

An entry (TEXT . POSITION) represents the deletion of the string TEXT
from (abs POSITION).  If POSITION is positive, point was at the front
of the text being deleted; if negative, point was at the end.

An entry (t . TIMESTAMP), where TIMESTAMP is in the style of
`current-time', indicates that the buffer was previously unmodified;
TIMESTAMP is the visited file's modification time, as of that time.
If the modification time of the most recent save is different, this
entry is obsolete.

An entry (t . 0) means the buffer was previously unmodified but
its time stamp was unknown because it was not associated with a file.
An entry (t . -1) is similar, except that it means the buffer's visited
file did not exist.

An entry (nil PROPERTY VALUE BEG . END) indicates that a text property
was modified between BEG and END.  PROPERTY is the property name,
and VALUE is the old value.

An entry (apply FUN-NAME . ARGS) means undo the change with
\(apply FUN-NAME ARGS).

An entry (apply DELTA BEG END FUN-NAME . ARGS) supports selective undo
in the active region.  BEG and END is the range affected by this entry
and DELTA is the number of characters added or deleted in that range by
this change.

An entry (MARKER . DISTANCE) indicates that the marker MARKER
was adjusted in position by the offset DISTANCE (an integer).

An entry of the form POSITION indicates that point was at the buffer
location given by the integer.  Undoing an entry of this form places
point at POSITION.

Entries with value nil mark undo boundaries.  The undo command treats
the changes between two undo boundaries as a single step to be undone.

If the value of the variable is t, undo information is not recorded.]]
  )

  defvar_per_buffer(
    'default-directory',
    M.bvar.directory,
    vars.Qstringp,
    [[Name of default directory of current buffer.
It should be an absolute directory name; on GNU and Unix systems,
these names start with "/" or "~" and end with "/".
To interactively change the default directory, use the command `cd'.]]
  )

  --This should be last, after all per buffer variables are defined
  vars.F.get_buffer_create(alloc.make_unibyte_string('*scratch*'), vars.Qnil)
end
function M.init_syms()
  vars.defsubr(F, 'get_buffer_create')
  vars.defsubr(F, 'get_buffer')
  vars.defsubr(F, 'set_buffer')
  vars.defsubr(F, 'force_mode_line_update')
  vars.defsubr(F, 'buffer_list')
  vars.defsubr(F, 'current_buffer')
  vars.defsubr(F, 'buffer_modified_p')
  vars.defsubr(F, 'set_buffer_modified_p')
  vars.defsubr(F, 'buffer_name')
  vars.defsubr(F, 'buffer_file_name')
  vars.defsubr(F, 'buffer_local_value')
  vars.defsubr(F, 'buffer_enable_undo')
  vars.defsubr(F, 'make_overlay')
  vars.defsubr(F, 'overlay_put')
  vars.defsubr(F, 'delete_overlay')
end
return M
