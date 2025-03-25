local lisp = require 'elisp.lisp'
local vars = require 'elisp.vars'

---@class vim.elisp.intervals
---@field total_length number
---@field position number
---@field left vim.elisp.intervals?
---@field right vim.elisp.intervals?
---@field up vim.elisp.intervals|vim.elisp.obj?
---@field up_is_obj boolean?
---@field write_protect boolean?
---@field visible boolean?
---@field front_sticky boolean?
---@field rear_sticky boolean?
---@field plist vim.elisp.obj

local M = {}
---@param i vim.elisp.intervals
local function balance_possible_root_interval(i)
  if _G.vim_elisp_later then
    error('TODO')
  end
end
---@param i vim.elisp.intervals?
---@return number
local function total_length0(i)
  return i and i.total_length or 0
end
---@param tree vim.elisp.intervals?
---@param position number
---@return vim.elisp.intervals?
function M.find_interval(tree, position)
  if not tree then
    return nil
  end
  local relative_position = position
  if tree.up_is_obj then
    if
      lisp.bufferp(tree.up --[[@as vim.elisp.obj]])
    then
      error('TODO')
    end
  end
  assert(relative_position <= tree.total_length)
  balance_possible_root_interval(tree)
  while true do
    assert(tree)
    if relative_position < total_length0(tree.left) then
      tree = tree.left
    elseif
      tree.right ~= nil and relative_position >= (tree.total_length - total_length0(tree.right))
    then
      relative_position = relative_position - (tree.total_length - total_length0(tree.right))
      tree = tree.right
    else
      tree.position = (position - relative_position + total_length0(tree.left))
      return tree
    end
  end
end
---@param i vim.elisp.intervals
---@param parent vim.elisp.intervals?
local function set_interval_parent(i, parent)
  i.up_is_obj = false or nil
  i.up = parent
end
---@param i vim.elisp.intervals
local function reset_interval(i)
  i.total_length = 0
  i.position = 0
  i.left = nil
  i.right = nil
  set_interval_parent(i, nil)
  i.write_protect = false or nil
  i.visible = false or nil
  i.front_sticky = false or nil
  i.rear_sticky = false or nil
  i.plist = vars.Qnil
end
---@return vim.elisp.intervals
local function make_interval()
  local new = {}
  reset_interval(new)
  return new
end
---@param i vim.elisp.intervals
function M.length(i)
  return i.total_length
    - (i.left and i.left.total_length or 0)
    - (i.right and i.right.total_length or 0)
end
---@param i vim.elisp.intervals
---@param obj vim.elisp.obj
local function set_interval_obj(i, obj)
  assert(lisp.stringp(obj) or lisp.bufferp(obj))
  i.up_is_obj = true
  i.up = obj
end
---@param parent vim.elisp.obj
---@return vim.elisp.intervals
function M.create_root_interval(parent)
  local new = make_interval()
  if not lisp.stringp(parent) then
    error('TODO')
  else
    new.total_length = lisp.schars(parent)
    assert(new.total_length >= 0)
    lisp.set_string_intervals(parent, new)
    new.position = 0
  end
  assert(M.length(new) > 0)
  set_interval_obj(new, parent)
  return new
end
---@param i vim.elisp.intervals
---@param offset number
---@return vim.elisp.intervals
function M.split_right(i, offset)
  local new = make_interval()
  local position = i.position
  local new_length = M.length(i) - offset
  new.position = position + offset
  set_interval_parent(new, i)
  if i.right == nil then
    i.right = new
    new.total_length = new_length
    assert(M.length(new) > 0)
  else
    error('TODO')
  end
  balance_possible_root_interval(i)
  return new
end
---@param i vim.elisp.intervals
---@param offset number
---@return vim.elisp.intervals
function M.split_left(i, offset)
  local new = make_interval()
  local new_length = offset
  new.position = i.position
  i.position = i.position + offset
  set_interval_parent(new, i)
  if i.left == nil then
    i.left = new
    new.total_length = new_length
    assert(M.length(new) > 0)
  else
    error('TODO')
  end
  balance_possible_root_interval(i)
  return new
end
---@param i vim.elisp.intervals
---@param j vim.elisp.intervals
function M.copy_properties(i, j)
  if lisp.nilp(i.plist) or lisp.nilp(j.plist) then
    return
  end
  error('TODO')
end
return M
