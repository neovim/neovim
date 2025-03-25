local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local alloc = require 'elisp.alloc'
local nvim = require 'elisp.nvim'

---@type vim.elisp.obj
local frame_and_buffer_state

local function defvar_kboard(name, symname, doc)
  vars.defvar_lisp(name, symname, doc)
  vars.V[name] = vars.Qnil
  if _G.vim_elisp_later then
    error('TODO')
  end
end

local M = {}
---@type vim.elisp.F
local F = {}
F.frame_or_buffer_changed_p = {
  'frame-or-buffer-changed-p',
  0,
  1,
  0,
  [[Return non-nil if the frame and buffer state appears to have changed.
VARIABLE is a variable name whose value is either nil or a state vector
that will be updated to contain all frames and buffers,
aside from buffers whose names start with space,
along with the buffers' read-only and modified flags.  This allows a fast
check to see whether buffer menus might need to be recomputed.
If this function returns non-nil, it updates the internal vector to reflect
the current state.

If VARIABLE is nil, an internal variable is used.  Users should not
pass nil for VARIABLE.]],
}
function F.frame_or_buffer_changed_p.f(variable)
  local state
  if not lisp.nilp(variable) then
    error('TODO')
  else
    state = frame_and_buffer_state
  end
  local buflist = nvim.buffer_list()
  local framelist = nvim.frame_list()
  local idx = 0
  for _, frame in ipairs(framelist) do
    if idx == lisp.asize(state) then
      goto changed
    elseif lisp.aref(state, idx) ~= frame then
      goto changed
    end
    idx = idx + 1
    if idx == lisp.asize(state) then
      goto changed
    elseif
      lisp.aref(state, idx) ~= nvim.frame_name(frame --[[@as vim.elisp._frame]])
    then
      goto changed
    end
    idx = idx + 1
  end
  for _, buf in ipairs(buflist) do
    if
      lisp.sdata(nvim.bvar(buf--[[@as vim.elisp._buffer]], 'name')):sub(1, 1) == ' '
    then
      goto continue
    end
    if idx == lisp.asize(state) then
      goto changed
    elseif lisp.aref(state, idx) ~= buf then
      goto changed
    end
    idx = idx + 1
    if idx == lisp.asize(state) then
      goto changed
    elseif
      lisp.aref(state, idx) ~= nvim.bvar(buf--[[@as vim.elisp._buffer]], 'read_only')
    then
      goto changed
    end
    idx = idx + 1
    if idx == lisp.asize(state) then
      goto changed
    elseif lisp.aref(state, idx) ~= vars.F.buffer_modified_p(buf) then
      goto changed
    end
    idx = idx + 1
    ::continue::
  end
  if idx == lisp.asize(state) then
    goto changed
  end
  if lisp.eq(lisp.aref(state, idx), vars.Qlambda) then
    return vars.Qnil
  end
  ::changed::
  local n = 1
  for _ in ipairs(framelist) do
    n = n + 2
  end
  for _ in ipairs(buflist) do
    n = n + 3
  end
  if not lisp.vectorp(state) or n > lisp.asize(state) or (n + 20) < (lisp.asize(state) / 2) then
    state = alloc.make_vector(n + 20, vars.Qlambda)
    if not lisp.nilp(variable) then
      vars.F.set(variable, state)
    else
      frame_and_buffer_state = state
    end
  end
  idx = 0
  for _, frame in ipairs(framelist) do
    lisp.aset(state, idx, frame)
    idx = idx + 1
    lisp.aset(state, idx, nvim.frame_name(frame --[[@as vim.elisp._frame]]))
    idx = idx + 1
  end
  for _, buf in ipairs(buflist) do
    if
      lisp.sdata(nvim.bvar(buf--[[@as vim.elisp._buffer]], 'name')):sub(1, 1) == ' '
    then
      goto continue
    end
    lisp.aset(state, idx, buf)
    idx = idx + 1
    lisp.aset(state, idx, nvim.bvar(buf--[[@as vim.elisp._buffer]], 'read_only'))
    idx = idx + 1
    lisp.aset(state, idx, vars.F.buffer_modified_p(buf))
    idx = idx + 1
    ::continue::
  end
  lisp.aset(state, idx, vars.Qlambda)
  idx = idx + 1
  while idx < lisp.asize(state) do
    lisp.aset(state, idx, vars.Qnil)
    idx = idx + 1
  end
  assert(idx <= lisp.asize(state))
  return vars.Qt
end

function M.init()
  frame_and_buffer_state = alloc.make_vector(20, vars.Qlambda)
end
function M.init_syms()
  vars.defsubr(F, 'frame_or_buffer_changed_p')

  defvar_kboard(
    'window_system',
    'window-system',
    [[Name of window system through which the selected frame is displayed.
The value is a symbol:
 nil for a termcap frame (a character-only terminal),
 `x' for an Emacs frame that is really an X window,
 `w32' for an Emacs frame that is a window on MS-Windows display,
 `ns' for an Emacs frame on a GNUstep or Macintosh Cocoa display,
 `pc' for a direct-write MS-DOS frame.
 `pgtk' for an Emacs frame using pure GTK facilities.
 `haiku' for an Emacs frame running in Haiku.

Use of this variable as a boolean is deprecated.  Instead,
use `display-graphic-p' or any of the other `display-*-p'
predicates which report frame's specific UI-related capabilities.]]
  )
end

return M
