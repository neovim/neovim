----------------------------------------
-- This file is generated via github.com/tjdevries/vim9jit
-- For any bugs, please first consider reporting there.
----------------------------------------

-- Ignore "value assigned to a local variable is unused" because
--  we can't guarantee that local variables will be used by plugins
-- luacheck: ignore 311

local vim9 = require('_vim9script')
local M = {}
local Qf_filter = nil
-- vim9script

-- # cfilter.vim: Plugin to filter entries from a quickfix/location list
-- # Last Change: Jun 30, 2022
-- # Maintainer: Yegappan Lakshmanan (yegappan AT yahoo DOT com)
-- # Version: 2.0
-- #
-- # Commands to filter the quickfix list:
-- #   :Cfilter[!] /{pat}/
-- #       Create a new quickfix list from entries matching {pat} in the current
-- #       quickfix list. Both the file name and the text of the entries are
-- #       matched against {pat}. If ! is supplied, then entries not matching
-- #       {pat} are used. The pattern can be optionally enclosed using one of
-- #       the following characters: ', ", /. If the pattern is empty, then the
-- #       last used search pattern is used.
-- #   :Lfilter[!] /{pat}/
-- #       Same as :Cfilter but operates on the current location list.
-- #

Qf_filter = function(qf, searchpat, bang)
  qf = vim9.bool(qf)
  local Xgetlist = function() end
  local Xsetlist = function() end
  local cmd = ''
  local firstchar = ''
  local lastchar = ''
  local pat = ''
  local title = ''
  local Cond = function() end
  local items = {}

  if vim9.bool(qf) then
    Xgetlist = function(...)
      return vim.fn['getqflist'](...)
    end
    Xsetlist = function(...)
      return vim.fn['setqflist'](...)
    end
    cmd = ':Cfilter' .. bang
  else
    Xgetlist = function(...)
      return vim9.fn_ref(M, 'getloclist', vim.deepcopy({ 0 }), ...)
    end

    Xsetlist = function(...)
      return vim9.fn_ref(M, 'setloclist', vim.deepcopy({ 0 }), ...)
    end

    cmd = ':Lfilter' .. bang
  end

  firstchar = vim9.index(searchpat, 0)
  lastchar = vim9.slice(searchpat, -1, nil)
  if firstchar == lastchar and (firstchar == '/' or firstchar == '"' or firstchar == "'") then
    pat = vim9.slice(searchpat, 1, -2)
    if pat == '' then
      -- # Use the last search pattern
      pat = vim.fn.getreg('/')
    end
  else
    pat = searchpat
  end

  if pat == '' then
    return
  end

  if bang == '!' then
    Cond = function(_, val)
      return vim9.ops.NotRegexpMatches(val.text, pat)
        and vim9.ops.NotRegexpMatches(vim9.fn.bufname(val.bufnr), pat)
    end
  else
    Cond = function(_, val)
      return vim9.ops.RegexpMatches(val.text, pat)
        or vim9.ops.RegexpMatches(vim9.fn.bufname(val.bufnr), pat)
    end
  end

  items = vim9.fn_mut('filter', { Xgetlist(), Cond }, { replace = 0 })
  title = cmd .. ' /' .. pat .. '/'
  Xsetlist({}, ' ', { ['title'] = title, ['items'] = items })
end

vim.api.nvim_create_user_command('Cfilter', function(__vim9_arg_1)
  Qf_filter(true, __vim9_arg_1.args, (__vim9_arg_1.bang and '!' or ''))
end, {
  bang = true,
  nargs = '+',
  complete = nil,
})

vim.api.nvim_create_user_command('Lfilter', function(__vim9_arg_1)
  Qf_filter(false, __vim9_arg_1.args, (__vim9_arg_1.bang and '!' or ''))
end, {
  bang = true,
  nargs = '+',
  complete = nil,
})

-- # vim: shiftwidth=2 sts=2 expandtab
return M
