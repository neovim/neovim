----------------------------------------
-- This file is generated via github.com/tjdevries/vim9jit
-- For any bugs, please first consider reporting there.
----------------------------------------

-- Ignore "value assigned to a local variable is unused" because
--  we can't guarantee that local variables will be used by plugins
-- luacheck: ignore 311

local vim9 = require('_vim9script')
local M = {}
local undo_opts = nil
local GDScriptIndent = nil
-- vim9script

-- # Vim indent file
-- # Language: gdscript (Godot game engine)
-- # Maintainer: Maxim Kim <habamax@gmail.com>
-- # Based on python indent file.

if vim9.bool(vim9.fn.exists('b:did_indent')) then
  return M
end
vim.b['did_indent'] = 1

undo_opts = 'setl indentexpr< indentkeys< lisp< autoindent<'

if vim9.bool(vim9.fn.exists('b:undo_indent')) then
  vim.b['undo_indent'] = vim.b['undo_indent'] .. '|' .. undo_opts
else
  vim.b['undo_indent'] = undo_opts
end

pcall(vim.cmd, [[ setlocal nolisp ]])
pcall(vim.cmd, [[ setlocal autoindent ]])
pcall(vim.cmd, [[ setlocal indentexpr=GDScriptIndent() ]])
pcall(vim.cmd, [[ setlocal indentkeys+=<:>,=elif,=except ]])

GDScriptIndent = function()
  -- # If this line is explicitly joined: If the previous line was also joined,
  -- # line it up with that one, otherwise add two 'shiftwidth'
  if vim9.ops.RegexpMatches(vim9.fn.getline(vim9.ops.Minus(vim.v['lnum'], 1)), '\\\\$') then
    if
      vim.v['lnum'] > 1
      and vim9.ops.RegexpMatches(vim9.fn.getline(vim9.ops.Minus(vim.v['lnum'], 2)), '\\\\$')
    then
      return vim9.fn.indent(vim9.ops.Minus(vim.v['lnum'], 1))
    end
    return vim9.fn.indent(vim9.ops.Minus(vim.v['lnum'], 1)) + (vim9.fn.shiftwidth() * 2)
  end

  -- # If the start of the line is in a string don't change the indent.
  if
    vim9.bool(
      vim9.ops.And(
        vim9.fn.has('syntax_items'),
        vim9.ops.RegexpMatches(synIDattr(synID(vim.v['lnum'], 1, 1), 'name'), 'String$')
      )
    )
  then
    return -1
  end

  -- # Search backwards for the previous non-empty line.
  local plnum = vim9.fn.prevnonblank(vim9.ops.Minus(vim.v['lnum'], 1))

  if plnum == 0 then
    -- # This is the first non-empty line, use zero indent.
    return 0
  end

  local plindent = vim9.fn.indent(plnum)
  local plnumstart = plnum

  -- # Get the line and remove a trailing comment.
  -- # Use syntax highlighting attributes when possible.
  local pline = vim9.fn.getline(plnum)
  local pline_len = vim9.fn.strlen(pline)
  if vim9.bool(vim9.fn.has('syntax_items')) then
    -- # If the last character in the line is a comment, do a binary search for
    -- # the start of the comment.  synID() is slow, a linear search would take
    -- # too long on a long line.
    if
      vim9.ops.RegexpMatches(synIDattr(synID(plnum, pline_len, 1), 'name'), '\\(Comment\\|Todo\\)$')
    then
      local min = 1
      local max = pline_len
      while min < max do
        local col = vim9.ops.Divide((vim9.ops.Plus(min, max)), 2)
        if
          vim9.ops.RegexpMatches(synIDattr(synID(plnum, col, 1), 'name'), '\\(Comment\\|Todo\\)$')
        then
          max = col
        else
          min = vim9.ops.Plus(col, 1)
        end
      end
      pline = vim9.fn.strpart(pline, 0, vim9.ops.Minus(min, 1))
    end
  else
    local col = 0
    while col < pline_len do
      if vim9.index(pline, col) == '#' then
        pline = vim9.fn.strpart(pline, 0, col)
        break
      end
      col = vim9.ops.Plus(col, 1)
    end
  end

  -- # When "inside" parenthesis: If at the first line below the parenthesis add
  -- # one 'shiftwidth' ("inside" is simplified and not really checked)
  -- # my_var = (
  -- #     a
  -- #     + b
  -- #     + c
  -- # )
  if vim9.ops.RegexpMatches(pline, '[({\\[]\\s*$') then
    return vim9.fn.indent(plnum) + vim9.fn.shiftwidth()
  end

  -- # If the previous line ended with a colon, indent this line
  if vim9.ops.RegexpMatches(pline, ':\\s*$') then
    return vim9.ops.Plus(plindent, vim9.fn.shiftwidth())
  end

  -- # If the previous line was a stop-execution statement...
  if
    vim9.ops.RegexpMatches(
      vim9.fn.getline(plnum),
      '^\\s*\\(break\\|continue\\|raise\\|return\\|pass\\)\\>'
    )
  then
    -- # See if the user has already dedented
    if vim9.fn.indent(vim.v['lnum']) > vim9.fn.indent(plnum) - vim9.fn.shiftwidth() then
      -- # If not, recommend one dedent
      return vim9.fn.indent(plnum) - vim9.fn.shiftwidth()
    end
    -- # Otherwise, trust the user
    return -1
  end

  -- # If the current line begins with a keyword that lines up with "try"
  if vim9.ops.RegexpMatches(vim9.fn.getline(vim.v['lnum']), '^\\s*\\(except\\|finally\\)\\>') then
    local lnum = vim9.ops.Minus(vim.v['lnum'], 1)
    while lnum >= 1 do
      if vim9.ops.RegexpMatches(vim9.fn.getline(lnum), '^\\s*\\(try\\|except\\)\\>') then
        local ind = vim9.fn.indent(lnum)
        if ind >= vim9.fn.indent(vim.v['lnum']) then
          return -1
        end
        return ind
      end
      lnum = vim9.ops.Minus(lnum, 1)
    end
    return -1
  end

  -- # If the current line begins with a header keyword, dedent
  if vim9.ops.RegexpMatches(vim9.fn.getline(vim.v['lnum']), '^\\s*\\(elif\\|else\\)\\>') then
    -- # Unless the previous line was a one-liner
    if vim9.ops.RegexpMatches(vim9.fn.getline(plnumstart), '^\\s*\\(for\\|if\\|try\\)\\>') then
      return plindent
    end

    -- # Or the user has already dedented
    if vim9.fn.indent(vim.v['lnum']) <= vim9.ops.Minus(plindent, vim9.fn.shiftwidth()) then
      return -1
    end

    return vim9.ops.Minus(plindent, vim9.fn.shiftwidth())
  end

  return -1
end

return M
