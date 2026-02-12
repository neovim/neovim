local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local command = n.command
local api = n.api
local fn = n.fn
local eval = n.eval
local feed = n.feed
local clear = n.clear
local eq = t.eq
local neq = t.neq

describe('optwin.lua', function()
  before_each(clear)

  it(':options shows options UI', function()
    command 'options'

    command '/^ 1'
    local lnum = fn.line('.')
    feed('<CR>')
    neq(lnum, fn.line('.'))

    n.add_builddir_to_rtp()
    command '/^startofline'
    local win = api.nvim_get_current_win()
    feed('<CR>')
    neq(win, api.nvim_get_current_win())
    eq('help', eval('&filetype'))
    api.nvim_win_close(0, true)
    eq(win, api.nvim_get_current_win())

    command '/^ \t'
    local opt_value = eval('&startofline')
    local line = api.nvim_get_current_line()
    feed('<CR>')
    neq(opt_value, eval('&startofline'))
    neq(line, api.nvim_get_current_line())

    command('set startofline!')
    neq(line, api.nvim_get_current_line())
    feed('<space>')
    eq(line, api.nvim_get_current_line())

    command 'wincmd j'
    command 'wincmd k'
    command '/^number'
    command '/^ \t'
    line = api.nvim_get_current_line()
    feed('<CR>')
    neq(line, api.nvim_get_current_line())
    command 'wincmd o'
    feed('<CR>')
    neq(line, api.nvim_get_current_line())
  end)

  it(':options shows all options', function()
    local ignore = {
      -- These options are removed/unused/deprecated
      'compatible',
      'paste',
      'highlight',
      'terse',
      'aleph',
      'encoding',
      'termencoding',
      'maxcombine',
      'secure',
      'prompt',
      'edcompatible',
      'gdefault',
      'guioptions',
      'guitablabel',
      'guitabtooltip',
      'insertmode',
      'magic',
      'mouseshape',
      'imcmdline',
      'imdisable',
      'pastetoggle',
      'langnoremap',
      'opendevice',
      'ttyfast',
      'remap',
      'hkmap',
      'hkmapp',

      -- These options are read-only
      'channel',
    }

    command 'options'

    local options = ignore
    for _, line in ipairs(api.nvim_buf_get_lines(0, 0, -1, true)) do
      if line:match('^[a-z]') then
        table.insert(options, line:match('^[a-z]+'))
      end
    end

    eq(fn.sort(vim.tbl_keys(api.nvim_get_all_options_info())), fn.sort(options))
  end)
end)
