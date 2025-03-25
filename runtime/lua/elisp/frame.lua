local nvim = require 'elisp.nvim'
local lisp = require 'elisp.lisp'
local vars = require 'elisp.vars'
local alloc = require 'elisp.alloc'
local signal = require 'elisp.signal'

local FRAME_WINDOW_P = false --no frames are graphical
local M = {}
---@param f vim.elisp.obj
function M.check_live_frame(f)
  lisp.check_type(
    lisp.framep(f) and nvim.frame_live_p(f --[[@as vim.elisp._frame]]),
    vars.Qframe_live_p,
    f
  )
end

---@type vim.elisp.F
local F = {}
F.frame_list = {
  'frame-list',
  0,
  0,
  0,
  [[Return a list of all live frames.
The return value does not include any tooltip frame.]],
}
function F.frame_list.f()
  return lisp.list(unpack(nvim.frame_list()))
end
---@param f vim.elisp.obj
---@return vim.elisp._frame
local function decode_any_frame(f)
  if lisp.nilp(f) then
    f = nvim.frame_get_current()
  end
  lisp.check_frame(f)
  return f --[[@as vim.elisp._frame]]
end
---@nodiscard
local function store_in_alist(alist, prop, val)
  local tem = vars.F.assq(prop, alist)
  if lisp.nilp(tem) then
    return vars.F.cons(vars.F.cons(prop, val), alist)
  end
  vars.F.setcdr(tem, val)
  return alist
end
F.frame_parameters = {
  'frame-parameters',
  0,
  1,
  0,
  [[Return the parameters-alist of frame FRAME.
It is a list of elements of the form (PARM . VALUE), where PARM is a symbol.
The meaningful PARMs depend on the kind of frame.
If FRAME is omitted or nil, return information on the currently selected frame.]],
}
function F.frame_parameters.f(frame)
  local f = decode_any_frame(frame)
  frame = f --[[@as vim.elisp.obj]]
  if not nvim.frame_live_p(f) then
    return vars.Qnil
  end
  local alist = vars.F.copy_alist(nvim.frame_param_alist(f))
  if not FRAME_WINDOW_P then
    local elt
    elt = vars.F.assq(vars.Qforeground_color, alist)
    local xfaces = require 'elisp.xfaces'
    if lisp.consp(elt) and lisp.stringp(lisp.xcdr(elt)) then
      error('TODO')
    else
      alist = store_in_alist(
        alist,
        vars.Qforeground_color,
        xfaces.tty_color_name(f, nvim.frame_foreground_pixel(f))
      )
    end
    elt = vars.F.assq(vars.Qbackground_color, alist)
    if lisp.consp(elt) and lisp.stringp(lisp.xcdr(elt)) then
      error('TODO')
    else
      alist = store_in_alist(
        alist,
        vars.Qbackground_color,
        xfaces.tty_color_name(f, nvim.frame_background_pixel(f))
      )
    end
    alist = store_in_alist(alist, vars.Qfont, alloc.make_string('tty'))
  end
  alist = store_in_alist(alist, vars.Qname, nvim.frame_name(f))
  local height = nvim.frame_height(f)
  alist = store_in_alist(alist, vars.Qheight, lisp.make_fixnum(height))
  local width = nvim.frame_width(f)
  alist = store_in_alist(alist, vars.Qwidth, lisp.make_fixnum(width))

  alist =
    store_in_alist(alist, vars.Qmodeline, nvim.frame_wants_modeline_p(f) and vars.Qt or vars.Qnil)
  alist = store_in_alist(alist, vars.Qunsplittable, vars.Qnil)
  alist = store_in_alist(alist, vars.Qbuffer_list, nvim.frame_buffer_list(f))
  alist = store_in_alist(alist, vars.Qburied_buffer_list, nvim.frame_buried_buffer_list(f))

  local menu_bar_lines = nvim.frame_menu_bar_lines(f)
  alist = store_in_alist(alist, vars.Qmenu_bar_lines, lisp.make_fixnum(menu_bar_lines))
  local tab_bar_lines = nvim.frame_tab_bar_lines(f)
  alist = store_in_alist(alist, vars.Qtab_bar_lines, lisp.make_fixnum(tab_bar_lines))

  return alist
end
F.frame_parameter = {
  'frame-parameter',
  2,
  2,
  0,
  [[Return FRAME's value for parameter PARAMETER.
If FRAME is nil, describe the currently selected frame.]],
}
function F.frame_parameter.f(frame, parameter)
  local f = decode_any_frame(frame)
  frame = f --[[@as vim.elisp.obj]]
  lisp.check_symbol(parameter)
  if not nvim.frame_live_p(f) then
    return vars.Qnil
  elseif lisp.eq(parameter, vars.Qname) then
    return nvim.frame_name(f)
  elseif
    lisp.eq(parameter, vars.Qbackground_color) or lisp.eq(parameter, vars.Qforeground_color)
  then
    error('TODO')
  elseif lisp.eq(parameter, vars.Qdisplay_type) or lisp.eq(parameter, vars.Qbackground_mode) then
    return vars.F.cdr(vars.F.assq(parameter, nvim.frame_param_alist(f)))
  else
    return vars.F.cdr(vars.F.assq(parameter, vars.F.frame_parameters(frame)))
  end
end
F.framep = {
  'framep',
  1,
  1,
  0,
  [[Return non-nil if OBJECT is a frame.
Value is:
  t for a termcap frame (a character-only terminal),
 `x' for an Emacs frame that is really an X window,
 `w32' for an Emacs frame that is a window on MS-Windows display,
 `ns' for an Emacs frame on a GNUstep or Macintosh Cocoa display,
 `pc' for a direct-write MS-DOS frame,
 `pgtk' for an Emacs frame running on pure GTK.
 `haiku' for an Emacs frame running in Haiku.
See also `frame-live-p'.]],
}
function F.framep.f(obj)
  if not lisp.framep(obj) then
    return vars.Qnil
  end
  if FRAME_WINDOW_P then
    error('TODO')
  end
  return vars.Qt
end
F.window_system = {
  'window-system',
  0,
  1,
  0,
  [[The name of the window system that FRAME is displaying through.
The value is a symbol:
 nil for a termcap frame (a character-only terminal),
 `x' for an Emacs frame that is really an X window,
 `w32' for an Emacs frame that is a window on MS-Windows display,
 `ns' for an Emacs frame on a GNUstep or Macintosh Cocoa display,
 `pc' for a direct-write MS-DOS frame.
 `pgtk' for an Emacs frame using pure GTK facilities.
 `haiku' for an Emacs frame running in Haiku.

FRAME defaults to the currently selected frame.

Use of this function as a predicate is deprecated.  Instead,
use `display-graphic-p' or any of the other `display-*-p'
predicates which report frame's specific UI-related capabilities.]],
}
function F.window_system.f(frame)
  if lisp.nilp(frame) then
    frame = nvim.frame_get_current()
  end
  local typ = vars.F.framep(frame)
  if lisp.nilp(typ) then
    signal.wrong_type_argument(vars.Qframep, frame)
  end
  if lisp.eq(typ, vars.Qt) then
    return vars.Qnil
  else
    return typ
  end
end

function M.init()
  vars.V.frame_internal_parameters = lisp.list(vars.Qname, vars.Qparent_id, vars.Qwindow_id)
end
function M.init_syms()
  vars.defsym('Qframep', 'framep')
  vars.defsym('Qname', 'name')
  vars.defsym('Qdisplay_type', 'display-type')
  vars.defsym('Qbackground_mode', 'background-mode')
  vars.defsym('Qfont', 'font')
  vars.defsym('Qheight', 'height')
  vars.defsym('Qwidth', 'width')
  vars.defsym('Qmodeline', 'modeline')
  vars.defsym('Qunsplittable', 'unsplittable')
  vars.defsym('Qbuffer_list', 'buffer-list')
  vars.defsym('Qburied_buffer_list', 'buried-buffer-list')
  vars.defsym('Qmenu_bar_lines', 'menu-bar-lines')
  vars.defsym('Qtab_bar_lines', 'tab-bar-lines')
  vars.defsym('Qparent_id', 'parent-id')
  vars.defsym('Qwindow_id', 'window-id')

  vars.defsubr(F, 'frame_list')
  vars.defsubr(F, 'frame_parameter')
  vars.defsubr(F, 'frame_parameters')
  vars.defsubr(F, 'framep')
  vars.defsubr(F, 'window_system')

  vars.defvar_lisp(
    'frame_internal_parameters',
    'frame-internal-parameters',
    [[Frame parameters specific to every frame.]]
  )
end
return M
