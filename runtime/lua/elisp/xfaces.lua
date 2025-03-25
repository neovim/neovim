local vars = require 'elisp.vars'
local lisp = require 'elisp.lisp'
local signal = require 'elisp.signal'
local nvim = require 'elisp.nvim'
local alloc = require 'elisp.alloc'
local frame_ = require 'elisp.frame'
local font_ = require 'elisp.font'
local term = require 'elisp.term'

---@class vim.elisp.face
---@field lface vim.elisp.obj
---@field id number
---@field ascii_face vim.elisp.face

---@class vim.elisp.face_cache
---@field faces_by_id vim.elisp.face[]
---@field buckets table<vim.elisp.face,vim.elisp.face>

local lface_id_to_name = {}
local font_sort_order

local FRAME_WINDOW_P = false --no frames are graphical
local FRAME_TERMCAP_P = true --all frames are in a terminal

local M = {}

---@enum vim.elisp.lface_index
M.lface_index = {
  _symbol_face = 0,
  family = 1,
  foundry = 2,
  swidth = 3,
  height = 4,
  weight = 5,
  slant = 6,
  underline = 7,
  inverse = 8,
  foreground = 9,
  background = 10,
  stipple = 11,
  overline = 12,
  strike_through = 13,
  box = 14,
  font = 15,
  inherit = 16,
  fontset = 17,
  distant_foreground = 18,
  extend = 19,
  size = 20,
}
---@enum vim.elisp.face_id
local face_id = {
  default = 0,
  mode_line_active = 1,
  mode_line_inactive = 2,
  tool_bar = 3,
  fringe = 4,
  header_line = 5,
  scroll_bar = 6,
  border = 7,
  cursor = 8,
  mouse = 9,
  menu = 10,
  vertical_border = 11,
  window_divider = 12,
  window_divider_first_pixel = 13,
  window_divider_last_pixel = 14,
  internal_border = 15,
  child_frame_border = 16,
  tab_bar = 17,
  tab_line = 18,
}

local function check_lface(_) end
local function check_lface_attrs(_) end
local function resolve_face_name(face_name, signal_p)
  if lisp.stringp(face_name) then
    face_name = vars.F.intern(face_name)
  end
  if lisp.nilp(face_name) or not lisp.symbolp(face_name) then
    return face_name
  end
  local orig_face = face_name
  local hare = face_name
  local has_visited = {}
  while true do
    face_name = hare
    hare = vars.F.get(face_name, vars.Qface_alias)
    if lisp.nilp(hare) or not lisp.symbolp(hare) then
      break
    end
    if has_visited[hare] then
      if signal_p then
        signal.xsignal(vars.Qcircular_list, orig_face)
      end
      return vars.Qdefault
    end
    has_visited[hare] = true
  end
  return face_name
end
---@param f vim.elisp._frame?
---@param face_name vim.elisp.obj
---@param signal_p boolean
---@return vim.elisp.obj
local function lface_from_face_name_no_resolve(f, face_name, signal_p)
  local lface
  if f then
    lface = vars.F.gethash(face_name, nvim.frame_hash_table(f), vars.Qnil)
  else
    lface = vars.F.cdr(vars.F.gethash(face_name, vars.V.face_new_frame_defaults, vars.Qnil))
  end
  if signal_p and lisp.nilp(lface) then
    signal.signal_error('Invalid face', face_name)
  end
  check_lface(lface)
  return lface
end
---@param f vim.elisp._frame?
---@param face_name vim.elisp.obj
---@param signal_p boolean
---@return vim.elisp.obj
local function lface_from_face_name(f, face_name, signal_p)
  face_name = resolve_face_name(face_name, signal_p)
  return lface_from_face_name_no_resolve(f, face_name, signal_p)
end
local function unspecifiedp(obj)
  return lisp.eq(obj, vars.Qunspecified)
end
local function ignore_defface_p(obj)
  return lisp.eq(obj, vars.QCignore_defface)
end
local function reset_p(obj)
  return lisp.eq(obj, vars.Qreset)
end
local function lface_fully_specified_p(lface)
  for i = 1, lisp.asize(lface) - 1 do
    if
      (
        i ~= M.lface_index.font
        and i ~= M.lface_index.inherit
        and i ~= M.lface_index.distant_foreground
      ) and (unspecifiedp(lisp.aref(lface, i)) or ignore_defface_p(lisp.aref(lface, i)))
    then
      return false
    end
  end
  return lisp.asize(lface) == M.lface_index.size
end
---@param lface vim.elisp.obj
---@return vim.elisp.face
local function make_realized_face(lface)
  ---@type vim.elisp.face
  local face = {} --[[@as unknown]]
  face.lface = lface
  face.ascii_face = face
  if _G.vim_elisp_later then
    error('TODO: maybe need zero out all other options (emacs does it)')
  end
  return face
end
---@param f vim.elisp._frame
---@param lface vim.elisp.obj
---@return vim.elisp.face
local function realize_tty_face(f, lface)
  local face = make_realized_face(lface)
  if _G.vim_elisp_later then
    error('TODO: implement realize_tty_face')
  end
  return face
end
---@param f vim.elisp._frame
---@param face vim.elisp.face
local function cache_face(f, face)
  local cache = nvim.frame_face_cache(f)
  face.id = #cache.faces_by_id + (cache.faces_by_id[0] and 1 or 0)
  cache.faces_by_id[face.id] = face
  cache.buckets[face] = face
end
local function uncache_face(f, face)
  local cache = nvim.frame_face_cache(f)
  cache.buckets[face] = nil
  cache.faces_by_id[face.id] = nil
end
---@param f vim.elisp._frame
---@param lface vim.elisp.obj
---@param former_face_id number
local function realize_face(f, lface, former_face_id)
  local face
  check_lface_attrs(lface)
  local cache = nvim.frame_face_cache(f)
  if former_face_id >= 0 and cache.faces_by_id[former_face_id] then
    uncache_face(f, cache.faces_by_id[former_face_id])
    if _G.vim_elisp_later then
      error('TODO: redraw')
    end
  end
  if FRAME_WINDOW_P then
    error('TODO')
  elseif FRAME_TERMCAP_P then
    face = realize_tty_face(f, lface)
  else
    error('TODO')
  end
  cache_face(f, face)
  return face
end
---@param f vim.elisp._frame
---@return boolean
local function realize_default_face(f)
  local lface = lface_from_face_name(f, vars.Qdefault, false)
  if lisp.nilp(lface) then
    local frame = f --[[@as vim.elisp.obj]]
    lface = vars.F.internal_make_lisp_face(vars.Qdefault, frame)
  end
  if FRAME_WINDOW_P then
    error('TODO')
  end
  if not FRAME_WINDOW_P then
    lisp.aset(lface, M.lface_index.family, alloc.make_string('default'))
    lisp.aset(lface, M.lface_index.foundry, lisp.aref(lface, M.lface_index.family))
    lisp.aset(lface, M.lface_index.swidth, vars.Qnormal)
    lisp.aset(lface, M.lface_index.height, lisp.make_fixnum(1))
    if unspecifiedp(lisp.aref(lface, M.lface_index.weight)) then
      lisp.aset(lface, M.lface_index.weight, vars.Qnormal)
    end
    if unspecifiedp(lisp.aref(lface, M.lface_index.slant)) then
      lisp.aset(lface, M.lface_index.slant, vars.Qnormal)
    end
    if unspecifiedp(lisp.aref(lface, M.lface_index.fontset)) then
      lisp.aset(lface, M.lface_index.fontset, vars.Qnil)
    end
  end
  if unspecifiedp(lisp.aref(lface, M.lface_index.extend)) then
    lisp.aset(lface, M.lface_index.extend, vars.Qnil)
  end
  if unspecifiedp(lisp.aref(lface, M.lface_index.underline)) then
    lisp.aset(lface, M.lface_index.underline, vars.Qnil)
  end
  if unspecifiedp(lisp.aref(lface, M.lface_index.overline)) then
    lisp.aset(lface, M.lface_index.overline, vars.Qnil)
  end
  if unspecifiedp(lisp.aref(lface, M.lface_index.strike_through)) then
    lisp.aset(lface, M.lface_index.strike_through, vars.Qnil)
  end
  if unspecifiedp(lisp.aref(lface, M.lface_index.box)) then
    lisp.aset(lface, M.lface_index.box, vars.Qnil)
  end
  if unspecifiedp(lisp.aref(lface, M.lface_index.inverse)) then
    lisp.aset(lface, M.lface_index.inverse, vars.Qnil)
  end
  if unspecifiedp(lisp.aref(lface, M.lface_index.foreground)) then
    local color = vars.F.assq(vars.Qforeground_color, nvim.frame_param_alist(f))
    if lisp.consp(color) and lisp.stringp(lisp.xcdr(color)) then
      lisp.aset(lface, M.lface_index.foreground, lisp.xcdr(color))
    elseif FRAME_WINDOW_P then
      return false
    elseif FRAME_TERMCAP_P then
      lisp.aset(lface, M.lface_index.foreground, alloc.make_string('unspecified-fg'))
    end
  end
  if unspecifiedp(lisp.aref(lface, M.lface_index.background)) then
    local color = vars.F.assq(vars.Qbackground_color, nvim.frame_param_alist(f))
    if lisp.consp(color) and lisp.stringp(lisp.xcdr(color)) then
      lisp.aset(lface, M.lface_index.background, lisp.xcdr(color))
    elseif FRAME_WINDOW_P then
      return false
    elseif FRAME_TERMCAP_P then
      lisp.aset(lface, M.lface_index.background, alloc.make_string('unspecified-bg'))
    end
  end
  if unspecifiedp(lisp.aref(lface, M.lface_index.stipple)) then
    lisp.aset(lface, M.lface_index.stipple, vars.Qnil)
  end
  assert(lface_fully_specified_p(lface))
  check_lface(lface)
  realize_face(f, lface, face_id.default)
  if FRAME_WINDOW_P then
    error('TODO')
  end
  return true
end
local function get_lface_attributes_no_remap(f, sym, signal_p)
  local lface = lface_from_face_name_no_resolve(f, sym, signal_p)
  if not lisp.nilp(lface) then
    return vars.F.copy_sequence(lface)
  end
  return vars.Qnil
end
local function merge_face_vectors(w, f, from, to, named_merge_points)
  if
    not unspecifiedp(lisp.aref(from, M.lface_index.inherit))
    and not lisp.nilp(lisp.aref(from, M.lface_index.inherit))
  then
    error('TODO')
  end
  local font = vars.Qnil
  if lisp.fontp(lisp.aref(from, M.lface_index.font)) then
    error('TODO')
  end
  for i = 1, M.lface_index.size - 1 do
    if not unspecifiedp(lisp.aref(from, i)) then
      if i == M.lface_index.height and not lisp.fixnump(lisp.aref(from, i)) then
        error('TODO')
      elseif i ~= M.lface_index.font and not lisp.eq(lisp.aref(from, i), lisp.aref(to, i)) then
        error('TODO')
      end
    end
  end
  if not lisp.nilp(font) then
    error('TODO')
  end
  lisp.aset(to, M.lface_index.inherit, vars.Qnil)
end
---@param f vim.elisp._frame
---@param sym vim.elisp.obj
---@param id number
local function realize_named_face(f, sym, id)
  local c = nvim.frame_face_cache(f)
  local lface = lface_from_face_name(f, sym, false)
  local attrs = get_lface_attributes_no_remap(f, vars.Qdefault, true)
  check_lface_attrs(attrs)
  assert(lface_fully_specified_p(attrs))
  if lisp.nilp(lface) then
    local frame = f --[[@as vim.elisp.obj]]
    lface = vars.F.internal_make_lisp_face(sym, frame)
  end
  local symbol_attrs = get_lface_attributes_no_remap(f, sym, true)
  for i = 1, M.lface_index.size - 1 do
    if lisp.eq(lisp.aref(symbol_attrs, i), vars.Qreset) then
      lisp.aset(symbol_attrs, i, lisp.aref(attrs, i))
    end
  end
  merge_face_vectors(nil, f, symbol_attrs, attrs, nil)
  realize_face(f, attrs, id)
end
---@param f vim.elisp._frame
---@return boolean
local function realize_basic_faces(f)
  local success_p = false
  if realize_default_face(f) then
    realize_named_face(f, vars.Qmode_line_active, face_id.mode_line_active)
    realize_named_face(f, vars.Qmode_line_inactive, face_id.mode_line_inactive)
    realize_named_face(f, vars.Qtool_bar, face_id.tool_bar)
    realize_named_face(f, vars.Qfringe, face_id.fringe)
    realize_named_face(f, vars.Qheader_line, face_id.header_line)
    realize_named_face(f, vars.Qscroll_bar, face_id.scroll_bar)
    realize_named_face(f, vars.Qborder, face_id.border)
    realize_named_face(f, vars.Qcursor, face_id.cursor)
    realize_named_face(f, vars.Qmouse, face_id.mouse)
    realize_named_face(f, vars.Qmenu, face_id.menu)
    realize_named_face(f, vars.Qvertical_border, face_id.vertical_border)
    realize_named_face(f, vars.Qwindow_divider, face_id.window_divider)
    realize_named_face(f, vars.Qwindow_divider_first_pixel, face_id.window_divider_first_pixel)
    realize_named_face(f, vars.Qwindow_divider_last_pixel, face_id.window_divider_last_pixel)
    realize_named_face(f, vars.Qinternal_border, face_id.internal_border)
    realize_named_face(f, vars.Qchild_frame_border, face_id.child_frame_border)
    realize_named_face(f, vars.Qtab_bar, face_id.tab_bar)
    realize_named_face(f, vars.Qtab_line, face_id.tab_line)
    success_p = true
  end
  return success_p
end
---@param f vim.elisp._frame
---@param idx number
---@return vim.elisp.obj
function M.tty_color_name(f, idx)
  if idx >= 0 then
    local _ = f
    error('TODO')
  end
  if idx == -2 then
    return alloc.make_string('unspecified-fg')
  elseif idx == -3 then
    return alloc.make_string('unspecified-bg')
  end
  return vars.Qunspecified
end
---@param f vim.elisp._frame
function M.init_frame_faces(f)
  assert(realize_basic_faces(f))
end

---@type vim.elisp.F
local F = {}
F.internal_lisp_face_p = {
  'internal-lisp-face-p',
  1,
  2,
  0,
  [[Return non-nil if FACE names a face.
FACE should be a symbol or string.
If optional second argument FRAME is non-nil, check for the
existence of a frame-local face with name FACE on that frame.
Otherwise check for the existence of a global face.]],
}
function F.internal_lisp_face_p.f(face, frame)
  face = resolve_face_name(face, true)
  local lface
  if not lisp.nilp(frame) then
    error('TODO')
  else
    lface = lface_from_face_name(nil, face, false)
  end
  return lface
end
local function lfacep(lface)
  return lisp.vectorp(lface)
    and lisp.eq(lisp.aref(lface, 0), vars.Qface)
    and lisp.asize(lface) == M.lface_index.size
end
F.internal_make_lisp_face = {
  'internal-make-lisp-face',
  1,
  2,
  0,
  [[Make FACE, a symbol, a Lisp face with all attributes nil.
If FACE was not known as a face before, create a new one.
If optional argument FRAME is specified, make a frame-local face
for that frame.  Otherwise operate on the global face definition.
Value is a vector of face attributes.]],
}
function F.internal_make_lisp_face.f(face, frame)
  lisp.check_symbol(face)
  local global_lface = lface_from_face_name(nil, face, false)
  local f, lface
  if not lisp.nilp(frame) then
    frame_.check_live_frame(frame)
    f = frame --[[@as vim.elisp._frame]]
    lface = lface_from_face_name(f, face, false)
  else
    lface = vars.Qnil
  end
  if lisp.nilp(global_lface) then
    table.insert(lface_id_to_name, face)
    local face_id_ = lisp.make_fixnum(#lface_id_to_name)
    vars.F.put(face, vars.Qface, face_id_)
    global_lface = alloc.make_vector(M.lface_index.size, vars.Qunspecified)
    lisp.aset(global_lface, 0, vars.Qface)
    vars.F.puthash(face, vars.F.cons(face_id_, global_lface), vars.V.face_new_frame_defaults)
  elseif f == nil then
    for i = 1, M.lface_index.size - 1 do
      lisp.aset(global_lface, i, vars.Qunspecified)
    end
  end
  if f then
    if lisp.nilp(lface) then
      lface = alloc.make_vector(M.lface_index.size, vars.Qunspecified)
      lisp.aset(lface, 0, vars.Qface)
      vars.F.puthash(face, lface, nvim.frame_hash_table(f))
    else
      for i = 1, M.lface_index.size - 1 do
        lisp.aset(lface, i, vars.Qunspecified)
      end
    end
  else
    lface = global_lface
  end
  if lisp.nilp(vars.F.get(face, vars.Qface_no_inherit)) then
    if _G.vim_elisp_later then
      error('TODO: redraw')
    end
  end
  assert(lfacep(lface))
  check_lface(lface)
  return lface
end
local function merge_face_heights(from, to, invalid)
  local result = invalid
  if lisp.fixnump(from) then
    result = from
  elseif lisp.floatp(from) then
    if lisp.fixnump(to) then
      result = lisp.make_fixnum(lisp.xfloat_data(from) * lisp.fixnum(to))
    else
      error('TODO')
    end
  else
    error('TODO')
  end
  return result
end
F.internal_set_lisp_face_attribute = {
  'internal-set-lisp-face-attribute',
  3,
  4,
  0,
  [[Set attribute ATTR of FACE to VALUE.
FRAME being a frame means change the face on that frame.
FRAME nil means change the face of the selected frame.
FRAME t means change the default for new frames.
FRAME 0 means change the face on all frames, and change the default
  for new frames.]],
}
function F.internal_set_lisp_face_attribute.f(face, attr, value, frame)
  lisp.check_symbol(face)
  lisp.check_symbol(attr)
  face = resolve_face_name(face, true)
  if lisp.fixnump(frame) and lisp.fixnum(frame) == 0 then
    error('TODO')
  end

  local lface
  local old_value = vars.Qnil
  local prop_index

  if lisp.eq(frame, vars.Qt) then
    error('TODO')
  else
    if lisp.nilp(frame) then
      frame = nvim.frame_get_current()
    end
    frame_.check_live_frame(frame)
    local f = frame --[[@as vim.elisp._frame]]
    lface = lface_from_face_name(f, face, false)
    if lisp.nilp(lface) then
      lface = vars.F.internal_make_lisp_face(face, frame)
    end
  end
  if lisp.eq(attr, vars.QCfamily) then
    if not unspecifiedp(value) and not ignore_defface_p(value) and not reset_p(value) then
      lisp.check_string(value)
      if lisp.schars(value) == 0 then
        signal.signal_error('Invalid face family', value)
      end
    end
    old_value = lisp.aref(lface, M.lface_index.family)
    lisp.aset(lface, M.lface_index.family, value)
    prop_index = font_.font_index.family
  elseif lisp.eq(attr, vars.QCfoundry) then
    if not unspecifiedp(value) and not ignore_defface_p(value) and not reset_p(value) then
      lisp.check_string(value)
      if lisp.schars(value) == 0 then
        signal.signal_error('Invalid face foundry', value)
      end
    end
    old_value = lisp.aref(lface, M.lface_index.foundry)
    lisp.aset(lface, M.lface_index.foundry, value)
    prop_index = font_.font_index.foundry
  elseif lisp.eq(attr, vars.QCheight) then
    if not unspecifiedp(value) and not ignore_defface_p(value) and not reset_p(value) then
      if lisp.eq(face, vars.Qdefault) then
        error('TODO')
      else
        local test = merge_face_heights(value, lisp.make_fixnum(10), vars.Qnil)
        if not lisp.fixnump(test) or lisp.fixnum(test) <= 0 then
          signal.signal_error('Face height does not produce a positive integer', value)
        end
      end
    end
    old_value = lisp.aref(lface, M.lface_index.height)
    lisp.aset(lface, M.lface_index.height, value)
    prop_index = font_.font_index.size
  elseif lisp.eq(attr, vars.QCweight) then
    if not unspecifiedp(value) and not ignore_defface_p(value) and not reset_p(value) then
      lisp.check_symbol(value)
      if font_.font_weight_name_numeric(value) < 0 then
        signal.signal_error('Invalid face weight', value)
      end
    end
    old_value = lisp.aref(lface, M.lface_index.weight)
    lisp.aset(lface, M.lface_index.weight, value)
    prop_index = font_.font_index.weight
  elseif lisp.eq(attr, vars.QCslant) then
    if not unspecifiedp(value) and not ignore_defface_p(value) and not reset_p(value) then
      lisp.check_symbol(value)
      if font_.font_slant_name_numeric(value) < 0 then
        signal.signal_error('Invalid face slant', value)
      end
    end
    old_value = lisp.aref(lface, M.lface_index.slant)
    lisp.aset(lface, M.lface_index.slant, value)
    prop_index = font_.font_index.slant
  elseif lisp.eq(attr, vars.QCunderline) then
    local valid_p = false
    if unspecifiedp(value) or ignore_defface_p(value) or reset_p(value) then
      valid_p = true
    elseif lisp.nilp(value) or lisp.eq(value, vars.Qt) then
      valid_p = true
    elseif lisp.stringp(value) and lisp.schars(value) > 0 then
      valid_p = true
    elseif lisp.consp(value) then
      error('TODO')
    end
    if not valid_p then
      signal.signal_error('Invalid face underline', value)
    end
    old_value = lisp.aref(lface, M.lface_index.underline)
    lisp.aset(lface, M.lface_index.underline, value)
  elseif lisp.eq(attr, vars.QCoverline) then
    if
      (not unspecifiedp(value) and not ignore_defface_p(value) and not reset_p(value))
      and (
        (lisp.symbolp(value) and not lisp.eq(value, vars.Qt) and not lisp.nilp(value))
        or (lisp.stringp(value) and lisp.schars(value) == 0)
      )
    then
      signal.signal_error('Invalid face overline', value)
    end
    old_value = lisp.aref(lface, M.lface_index.overline)
    lisp.aset(lface, M.lface_index.overline, value)
  elseif lisp.eq(attr, vars.QCstrike_through) then
    if
      (not unspecifiedp(value) and not ignore_defface_p(value) and not reset_p(value))
      and (
        (lisp.symbolp(value) and not lisp.eq(value, vars.Qt) and not lisp.nilp(value))
        or (lisp.stringp(value) and lisp.schars(value) == 0)
      )
    then
      signal.signal_error('Invalid face strike-through', value)
    end
    old_value = lisp.aref(lface, M.lface_index.strike_through)
    lisp.aset(lface, M.lface_index.strike_through, value)
  elseif lisp.eq(attr, vars.QCbox) then
    local valid_p = false
    if lisp.eq(value, vars.Qt) then
      value = lisp.make_fixnum(1)
    end
    if unspecifiedp(value) or ignore_defface_p(value) or reset_p(value) then
      valid_p = true
    elseif lisp.nilp(value) then
      valid_p = true
    elseif lisp.fixnump(value) then
      valid_p = lisp.fixnum(value) ~= 0
    elseif lisp.stringp(value) then
      valid_p = lisp.schars(value) > 0
    elseif
      lisp.consp(value)
      and lisp.fixnump(lisp.xcar(value))
      and lisp.fixnump(lisp.xcdr(value))
    then
      valid_p = true
    elseif lisp.consp(value) then
      local tem = value
      while lisp.consp(tem) do
        local k = lisp.xcar(tem)
        tem = lisp.xcdr(tem)
        if not lisp.consp(tem) then
          break
        end
        local v = lisp.xcar(tem)
        if lisp.eq(k, vars.QCline_width) then
          if
            (
              not lisp.consp(v)
              or not lisp.fixnump(lisp.xcar(v))
              or lisp.fixnum(lisp.xcar(v)) == 0
              or not lisp.fixnump(lisp.xcdr(v))
              or lisp.fixnum(lisp.xcdr(v)) == 0
            ) and (not lisp.fixnump(v) or lisp.fixnum(v) == 0)
          then
            break
          end
        elseif lisp.eq(k, vars.QCcolor) then
          error('TODO')
        elseif lisp.eq(k, vars.QCstyle) then
          if
            not lisp.eq(v, vars.Qpressed_button)
            and not lisp.eq(v, vars.Qreleased_button)
            and not lisp.eq(v, vars.Qflat_button)
          then
            break
          end
        else
          break
        end
        tem = lisp.xcdr(tem)
      end
      valid_p = lisp.nilp(tem)
    end
    if not valid_p then
      signal.signal_error('Invalid face box', value)
    end
    old_value = lisp.aref(lface, M.lface_index.box)
    lisp.aset(lface, M.lface_index.box, value)
  elseif lisp.eq(attr, vars.QCinverse_video) or lisp.eq(attr, vars.QCreverse_video) then
    if not unspecifiedp(value) and not ignore_defface_p(value) and not reset_p(value) then
      lisp.check_symbol(value)
      if not lisp.eq(value, vars.Qt) and not lisp.nilp(value) then
        signal.signal_error('Invalid inverse-video face attribute value', value)
      end
    end
    old_value = lisp.aref(lface, M.lface_index.inverse)
    lisp.aset(lface, M.lface_index.inverse, value)
  elseif lisp.eq(attr, vars.QCextend) then
    if not unspecifiedp(value) and not ignore_defface_p(value) and not reset_p(value) then
      lisp.check_symbol(value)
      if not lisp.eq(value, vars.Qt) and not lisp.nilp(value) then
        signal.signal_error('Invalid extend face attribute value', value)
      end
    end
    old_value = lisp.aref(lface, M.lface_index.extend)
    lisp.aset(lface, M.lface_index.extend, value)
  elseif lisp.eq(attr, vars.QCforeground) then
    if lisp.nilp(value) then
      error('TODO')
    end
    if not unspecifiedp(value) and not ignore_defface_p(value) and not reset_p(value) then
      lisp.check_string(value)
      if lisp.schars(value) == 0 then
        signal.signal_error('Empty foreground color value', value)
      end
    end
    old_value = lisp.aref(lface, M.lface_index.foreground)
    lisp.aset(lface, M.lface_index.foreground, value)
  elseif lisp.eq(attr, vars.QCdistant_foreground) then
    error('TODO')
  elseif lisp.eq(attr, vars.QCbackground) then
    if lisp.nilp(value) then
      error('TODO')
    end
    if not unspecifiedp(value) and not ignore_defface_p(value) and not reset_p(value) then
      lisp.check_string(value)
      if lisp.schars(value) == 0 then
        signal.signal_error('Empty background color value', value)
      end
    end
    old_value = lisp.aref(lface, M.lface_index.background)
    lisp.aset(lface, M.lface_index.background, value)
  elseif lisp.eq(attr, vars.QCstipple) then
  elseif lisp.eq(attr, vars.QCwidth) then
    if not unspecifiedp(value) and not ignore_defface_p(value) and not reset_p(value) then
      error('TODO')
    end
    old_value = lisp.aref(lface, M.lface_index.swidth)
    lisp.aset(lface, M.lface_index.swidth, value)
    prop_index = font_.font_index.width
  elseif lisp.eq(attr, vars.QCfont) then
    error('TODO')
  elseif lisp.eq(attr, vars.QCfontset) then
    error('TODO')
  elseif lisp.eq(attr, vars.QCinherit) then
    local tail
    if lisp.symbolp(value) then
      tail = vars.Qnil
    else
      tail = value
      while lisp.consp(tail) do
        if not lisp.symbolp(lisp.xcar(tail)) then
          break
        end
        tail = lisp.xcdr(tail)
      end
    end
    if lisp.nilp(tail) then
      lisp.aset(lface, M.lface_index.inherit, value)
    else
      signal.signal_error('Invalid face inheritance', value)
    end
  elseif lisp.eq(attr, vars.QCbold) then
    error('TODO')
  elseif lisp.eq(attr, vars.QCitalic) then
    error('TODO')
  else
    signal.signal_error('Invalid face attribute name', attr)
  end

  if prop_index then
    font_.font_clear_prop(lface, prop_index)
  end
  if
    not lisp.eq(frame, vars.Qt)
    and lisp.nilp(vars.F.get(face, vars.Qface_no_inherit))
    and lisp.nilp(vars.F.equal(old_value, value))
  then
    if _G.vim_elisp_later then
      error('TODO: redraw')
    end
  end
  if
    not unspecifiedp(value)
    and not ignore_defface_p(value)
    and lisp.nilp(vars.F.equal(old_value, value))
  then
    local param = vars.Qnil
    if lisp.eq(face, vars.Qdefault) then
      if lisp.eq(attr, vars.QCforeground) then
        error('TODO')
      elseif lisp.eq(attr, vars.QCbackground) then
        error('TODO')
      end
    elseif lisp.eq(face, vars.Qmenu) then
      if _G.vim_elisp_later then
        error('TODO: signal menu face changed')
      end
    end
    if not lisp.nilp(param) then
      error('TODO')
    end
  end
  return face
end
F.internal_set_font_selection_order = {
  'internal-set-font-selection-order',
  1,
  1,
  0,
  [[Set font selection order for face font selection to ORDER.
ORDER must be a list of length 4 containing the symbols `:width',
`:height', `:weight', and `:slant'.  Face attributes appearing
first in ORDER are matched first, e.g. if `:height' appears before
`:weight' in ORDER, font selection first tries to find a font with
a suitable height, and then tries to match the font weight.
Value is ORDER.]],
}
function F.internal_set_font_selection_order.f(order)
  lisp.check_list(order)
  local list = order
  local indices = {}
  for i = 1, 4 do
    if not lisp.consp(list) then
      break
    end
    local attr = lisp.xcar(list)
    local xlfd
    if lisp.eq(attr, vars.QCwidth) then
      xlfd = font_.xlfd.swidth
    elseif lisp.eq(attr, vars.QCheight) then
      xlfd = font_.xlfd.point_size
    elseif lisp.eq(attr, vars.QCweight) then
      xlfd = font_.xlfd.weight
    elseif lisp.eq(attr, vars.QCslant) then
      xlfd = font_.xlfd.slant
    end
    if not xlfd or indices[i] then
      break
    end
    indices[i] = xlfd

    list = lisp.xcdr(list)
  end
  if not lisp.nilp(list) or #indices ~= 4 then
    signal.signal_error('Invalid font sort order', order)
  end
  font_sort_order = indices
  font_.font_update_sort_order(font_sort_order)

  return vars.Qnil
end
F.internal_set_alternative_font_family_alist = {
  'internal-set-alternative-font-family-alist',
  1,
  1,
  0,
  [[Define alternative font families to try in face font selection.
ALIST is an alist of (FAMILY ALTERNATIVE1 ALTERNATIVE2 ...) entries.
Each ALTERNATIVE is tried in order if no fonts of font family FAMILY can
be found.  Value is ALIST.]],
}
function F.internal_set_alternative_font_family_alist.f(alist)
  lisp.check_list(alist)
  alist = vars.F.copy_sequence(alist)
  local tail = alist
  while lisp.consp(tail) do
    local entry = lisp.xcar(tail)
    lisp.check_list(entry)
    entry = vars.F.copy_sequence(entry)
    lisp.xsetcar(tail, entry)
    local tail2 = entry
    while lisp.consp(tail2) do
      lisp.xsetcar(tail2, vars.F.intern(lisp.xcar(tail2), vars.Qnil))
      tail2 = lisp.xcdr(tail2)
    end
    tail = lisp.xcdr(tail)
  end
  vars.face_alternative_font_family_alist = alist
  return alist
end
F.internal_set_alternative_font_registry_alist = {
  'internal-set-alternative-font-registry-alist',
  1,
  1,
  0,
  [[Define alternative font registries to try in face font selection.
ALIST is an alist of (REGISTRY ALTERNATIVE1 ALTERNATIVE2 ...) entries.
Each ALTERNATIVE is tried in order if no fonts of font registry REGISTRY can
be found.  Value is ALIST.]],
}
function F.internal_set_alternative_font_registry_alist.f(alist)
  lisp.check_list(alist)
  alist = vars.F.copy_sequence(alist)
  local tail = alist
  while lisp.consp(tail) do
    local entry = lisp.xcar(tail)
    lisp.check_list(entry)
    entry = vars.F.copy_sequence(entry)
    lisp.xsetcar(tail, entry)
    local tail2 = entry
    while lisp.consp(tail2) do
      lisp.xsetcar(tail2, vars.F.downcase(lisp.xcar(tail2)))
      tail2 = lisp.xcdr(tail2)
    end
    tail = lisp.xcdr(tail)
  end
  vars.face_alternative_font_registry_alist = alist
  return alist
end
local function filter_face_ref(face_ref, w, err_msg)
  if not lisp.consp(face_ref) then
    return face_ref, true
  end
  if not lisp.eq(lisp.xcar(face_ref), vars.QCfiltered) then
    return face_ref, true
  end
  error('TODO')
end
---@param err_msg boolean
---@param attr_filter vim.elisp.lface_index
---@param to vim.elisp.obj
local function merge_face_ref(w, f, face_ref, to, err_msg, named_merge_points, attr_filter)
  local filtered_face_ref = face_ref
  local ok = true
  while true do
    face_ref = filtered_face_ref
    filtered_face_ref, ok = filter_face_ref(face_ref, w, err_msg)
    if not ok then
      return false
    end
    if lisp.eq(face_ref, filtered_face_ref) then
      break
    end
  end
  if lisp.nilp(face_ref) then
    return true
  elseif lisp.consp(face_ref) then
    local first = lisp.xcar(face_ref)
    if lisp.eq(first, vars.Qforeground_color) or lisp.eq(first, vars.Qbackground_color) then
      error('TODO')
    elseif lisp.symbolp(first) and lisp.sdata(lisp.symbol_name(first)):sub(1, 1) == ':' then
      if attr_filter > 0 then
        error('TODO')
      end
      while lisp.consp(face_ref) and lisp.consp(lisp.xcdr(face_ref)) do
        local err = false
        local keyword = lisp.xcar(face_ref)
        local value = lisp.xcar(lisp.xcdr(face_ref))
        if lisp.eq(value, vars.Qunspecified) then
        elseif lisp.eq(keyword, vars.QCfamily) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCfoundry) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCheight) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCweight) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCslant) then
          if lisp.symbolp(value) and font_.font_slant_name_numeric(value) >= 0 then
            lisp.aset(to, M.lface_index.slant, value)
            font_.font_clear_prop(to, font_.font_index.slant)
          else
            err = true
          end
        elseif lisp.eq(keyword, vars.QCunderline) then
          if
            lisp.eq(value, vars.Qt)
            or lisp.nilp(value)
            or lisp.stringp(value)
            or lisp.consp(value)
          then
            lisp.aset(to, M.lface_index.underline, value)
          else
            err = true
          end
        elseif lisp.eq(keyword, vars.QCoverline) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCstrike_through) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCbox) then
          if lisp.eq(value, vars.Qt) then
            value = lisp.make_fixnum(1)
          end
          if
            (lisp.fixnump(value) and lisp.fixnum(value) ~= 0)
            or lisp.stringp(value)
            or lisp.consp(value)
            or lisp.nilp(value)
          then
            lisp.aset(to, M.lface_index.box, value)
          else
            err = true
          end
        elseif lisp.eq(keyword, vars.QCinverse_video) or lisp.eq(keyword, vars.QCreverse_video) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCforeground) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCdistant_foreground) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCbackground) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCstipple) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCwidth) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCfont) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCfontset) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCinherit) then
          error('TODO')
        elseif lisp.eq(keyword, vars.QCextend) then
          error('TODO')
        else
          err = true
        end
        if err then
          ok = false
        end
        face_ref = lisp.xcdr(lisp.xcdr(face_ref))
      end
    else
      error('TODO')
    end
  else
    error('TODO')
  end
  return ok
end
local function face_from_id_or_nil(f, id)
  return nvim.frame_face_cache(f).faces_by_id[id]
end
local function face_from_id(f, id)
  return assert(face_from_id_or_nil(f, id))
end
local function face_attr_equal_p(a, b)
  if lisp.xtype(a) ~= lisp.xtype(b) then
    return false
  end
  if lisp.eq(a, b) then
    return true
  end
  local typ = lisp.xtype(a)
  if typ == lisp.type.symbol or typ == lisp.type.int0 then
    return false
  else
    error('TODO')
  end
end
local function tty_supports_face_attributes_p(f, attrs, def_face)
  if
    not (
      unspecifiedp(lisp.aref(attrs, M.lface_index.family))
      and unspecifiedp(lisp.aref(attrs, M.lface_index.foundry))
      and unspecifiedp(lisp.aref(attrs, M.lface_index.stipple))
      and unspecifiedp(lisp.aref(attrs, M.lface_index.height))
      and unspecifiedp(lisp.aref(attrs, M.lface_index.swidth))
      and unspecifiedp(lisp.aref(attrs, M.lface_index.overline))
      and unspecifiedp(lisp.aref(attrs, M.lface_index.box))
    )
  then
    return false
  end

  local def_attrs = def_face.lface
  local test_caps = 0

  local val = lisp.aref(attrs, M.lface_index.weight)
  if not unspecifiedp(val) then
    error('TODO')
  end

  val = lisp.aref(attrs, M.lface_index.slant)
  if not unspecifiedp(val) then
    local slant = font_.font_slant_name_numeric(val)
    if slant >= 0 then
      local def_slant = font_.font_slant_name_numeric(lisp.aref(def_attrs, M.lface_index.slant))
      if slant == 100 or slant == def_slant then
        return false
      else
        test_caps = bit.bor(test_caps, term.tty_cap.italic)
      end
    end
  end

  val = lisp.aref(attrs, M.lface_index.underline)
  if not unspecifiedp(val) then
    if lisp.stringp(val) then
      if _G.vim_elisp_later then
        error('TODO: neovim actually supports collored underline')
      end
      return false
    elseif
      lisp.eq(vars.F.car_safe(val), vars.QCstyle)
      and lisp.eq(vars.F.car_safe(vars.F.cdr_safe(val)), vars.Qwave)
    then
      if _G.vim_elisp_later then
        error('TODO: neovim actually supports wave underline')
      end
      return false
    elseif face_attr_equal_p(val, lisp.aref(def_attrs, M.lface_index.underline)) then
      if _G.vim_elisp_later then
        error('TODO: neovim actually supports some styled underline')
      end
      return false
    else
      test_caps = bit.bor(test_caps, term.tty_cap.underline)
    end
  end

  val = lisp.aref(attrs, M.lface_index.inverse)
  if not unspecifiedp(val) then
    error('TODO')
  end

  val = lisp.aref(attrs, M.lface_index.strike_through)
  if not unspecifiedp(val) then
    error('TODO')
  end

  val = lisp.aref(attrs, M.lface_index.foreground)
  if not unspecifiedp(val) then
    error('TODO')
  end

  val = lisp.aref(attrs, M.lface_index.background)
  if not unspecifiedp(val) then
    error('TODO')
  end

  return term.tty_capable_p(f, test_caps)
end
F.display_supports_face_attributes_p = {
  'display-supports-face-attributes-p',
  1,
  2,
  0,
  [[Return non-nil if all the face attributes in ATTRIBUTES are supported.
The optional argument DISPLAY can be a display name, a frame, or
nil (meaning the selected frame's display).

For instance, to check whether the display supports underlining:

  (display-supports-face-attributes-p \\='(:underline t))

The definition of `supported' is somewhat heuristic, but basically means
that a face containing all the attributes in ATTRIBUTES, when merged
with the default face for display, can be represented in a way that's

 (1) different in appearance from the default face, and
 (2) `close in spirit' to what the attributes specify, if not exact.

Point (2) implies that a `:weight black' attribute will be satisfied by
any display that can display bold, and a `:foreground \"yellow\"' as long
as it can display a yellowish color, but `:slant italic' will _not_ be
satisfied by the tty display code's automatic substitution of a `dim'
face for italic.]],
}
function F.display_supports_face_attributes_p.f(attributes, display)
  local frame
  if lisp.nilp(display) then
    frame = nvim.frame_get_current()
  elseif lisp.framep(display) then
    frame = display
  else
    error('TODO')
  end
  frame_.check_live_frame(frame)
  local f = frame --[[@as vim.elisp._frame]]
  local attrs = alloc.make_vector(M.lface_index.size, vars.Qunspecified)
  merge_face_ref(nil, f, attributes, attrs, true, nil, 0)
  local def_face = face_from_id_or_nil(f, face_id.default)
  if def_face == nil then
    if not realize_basic_faces(f) then
      signal.error('Cannot realize default face')
    end
    def_face = face_from_id(f, face_id.default)
  end
  local supports
  if FRAME_TERMCAP_P then
    supports = tty_supports_face_attributes_p(f, attrs, def_face)
  else
    error('TODO')
  end
  return supports and vars.Qt or vars.Qnil
end
F.clear_face_cache = {
  'clear-face-cache',
  0,
  1,
  0,
  [[Clear face caches on all frames.
Optional THOROUGHLY non-nil means try to free unused fonts, too.]],
}
function F.clear_face_cache.f(thoroughly)
  --Only does stuff if windowing system
  return vars.Qnil
end

function M.init()
  vars.V.face_new_frame_defaults =
    vars.F.make_hash_table(vars.QCtest, vars.Qeq, vars.QCsize, lisp.make_fixnum(33))
  vars.face_alternative_font_family_alist = vars.Qnil
  vars.face_alternative_font_registry_alist = vars.Qnil
end
function M.init_syms()
  vars.defsubr(F, 'internal_lisp_face_p')
  vars.defsubr(F, 'internal_make_lisp_face')
  vars.defsubr(F, 'internal_set_lisp_face_attribute')
  vars.defsubr(F, 'internal_set_font_selection_order')
  vars.defsubr(F, 'internal_set_alternative_font_family_alist')
  vars.defsubr(F, 'internal_set_alternative_font_registry_alist')
  vars.defsubr(F, 'display_supports_face_attributes_p')
  vars.defsubr(F, 'clear_face_cache')

  vars.defsym('Qface', 'face')
  vars.defsym('Qface_no_inherit', 'face-no-inherit')
  vars.defsym('Qunspecified', 'unspecified')
  vars.defsym('Qface_alias', 'face-alias')
  vars.defsym('Qdefault', 'default')
  vars.defsym('Qnormal', 'normal')
  vars.defsym('Qforeground_color', 'foreground-color')
  vars.defsym('Qbackground_color', 'background-color')
  vars.defsym('QCignore_defface', ':ignore-defface')

  vars.defsym('Qmode_line_active', 'mode-line-active')
  vars.defsym('Qmode_line_inactive', 'mode-line-inactive')
  vars.defsym('Qtool_bar', 'tool-bar')
  vars.defsym('Qfringe', 'fringe')
  vars.defsym('Qscroll_bar', 'scroll-bar')
  vars.defsym('Qborder', 'border')
  vars.defsym('Qcursor', 'cursor')
  vars.defsym('Qmouse', 'mouse')
  vars.defsym('Qmenu', 'menu')
  vars.defsym('Qvertical_border', 'vertical-border')
  vars.defsym('Qwindow_divider', 'window-divider')
  vars.defsym('Qwindow_divider_first_pixel', 'window-divider-first-pixel')
  vars.defsym('Qwindow_divider_last_pixel', 'window-divider-last-pixel')
  vars.defsym('Qinternal_border', 'internal-border')
  vars.defsym('Qchild_frame_border', 'child-frame-border')
  vars.defsym('Qtab_bar', 'tab-bar')
  vars.defsym('Qreset', 'reset')
  vars.defsym('Qpressed_button', 'pressed-button')
  vars.defsym('Qreleased_button', 'released-button')
  vars.defsym('Qflat_button', 'flat-button')
  vars.defsym('Qwave', 'wave')

  vars.defsym('QCfamily', ':family')
  vars.defsym('QCfoundry', ':foundry')
  vars.defsym('QCheight', ':height')
  vars.defsym('QCweight', ':weight')
  vars.defsym('QCslant', ':slant')
  vars.defsym('QCunderline', ':underline')
  vars.defsym('QCoverline', ':overline')
  vars.defsym('QCstrike_through', ':strike-through')
  vars.defsym('QCbox', ':box')
  vars.defsym('QCinverse_video', ':inverse-video')
  vars.defsym('QCreverse_video', ':reverse-video')
  vars.defsym('QCextend', ':extend')
  vars.defsym('QCforeground', ':foreground')
  vars.defsym('QCdistant_foreground', ':distant-foreground')
  vars.defsym('QCbackground', ':background')
  vars.defsym('QCstipple', ':stipple')
  vars.defsym('QCwidth', ':width')
  vars.defsym('QCfont', ':font')
  vars.defsym('QCfontset', ':fontset')
  vars.defsym('QCinherit', ':inherit')
  vars.defsym('QCbold', ':bold')
  vars.defsym('QCitalic', ':italic')
  vars.defsym('QCfiltered', ':filtered')
  vars.defsym('QCstyle', ':style')
  vars.defsym('QCline_width', ':line-width')
  vars.defsym('QCcolor', ':color')

  vars.defvar_lisp(
    'face_new_frame_defaults',
    'face--new-frame-defaults',
    [[Hash table of global face definitions (for internal use only.)]]
  )
end
return M
