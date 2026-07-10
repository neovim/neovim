local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api = n.api
local clear = n.clear
local command = n.command
local eq = t.eq
local exec_lua = n.exec_lua
local feed = n.feed
local fn = n.fn
local source = n.source

describe('matchit', function()
  before_each(function()
    clear { args = { '-u', 'NORC' } }
    command('filetype plugin on')
  end)

  local function set_lines(lines, filetype)
    api.nvim_buf_set_lines(0, 0, -1, true, lines)
    command('setfiletype ' .. filetype)
  end

  local function cursor(line, col)
    api.nvim_win_set_cursor(0, { line, col - 1 })
  end

  local function pos()
    local value = api.nvim_win_get_cursor(0)
    return { value[1], value[2] + 1 }
  end

  it('loads by default and enables and disables the default mappings', function()
    eq(1, api.nvim_get_var('loaded_matchit'))
    eq('<Plug>(MatchitNormalForward)', fn.maparg('%', 'n'))
    eq('<Plug>(MatchitNormalBackward)', fn.maparg('g%', 'n'))
    eq('<Plug>(MatchitNormalMultiBackward)', fn.maparg('[%', 'n'))
    eq('<Plug>(MatchitNormalMultiForward)', fn.maparg(']%', 'n'))
    eq(2, fn.exists(':MatchDebug'))
    eq(2, fn.exists(':MatchDisable'))
    eq(2, fn.exists(':MatchEnable'))

    command('MatchDisable')
    eq('', fn.maparg('%', 'n'))
    eq('', fn.maparg('a%', 'x'))

    command('MatchEnable')
    eq('<Plug>(MatchitNormalForward)', fn.maparg('%', 'n'))
    eq('<Plug>(MatchitVisualTextObject)', fn.maparg('a%', 'x'))
  end)

  it('respects g:no_plugin_maps while defining the plug mappings', function()
    clear { args = { '--cmd', 'let g:no_plugin_maps = 1', '-u', 'NORC' } }

    eq('', fn.maparg('%', 'n'))
    eq('', fn.maparg(']%', 'n'))
    eq(0, fn.empty(fn.maparg('<Plug>(MatchitNormalForward)', 'n')))
  end)

  it('matches HTML tags with attributes and back references', function()
    set_lines({ '<b id="outer">', '<big>some text</big>', '</b>' }, 'html')

    cursor(1, 2)
    feed('%')
    eq({ 3, 2 }, pos())
    feed('%')
    eq({ 1, 2 }, pos())

    cursor(2, 2)
    feed('%')
    eq({ 2, 16 }, pos())
    feed('g%')
    eq({ 2, 2 }, pos())
  end)

  it('uses custom start, middle, and end words in both directions', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { 'IF', 'ELSE', 'ENDIF' })
    exec_lua(function()
      vim.b.match_words = [[\<if\>:\<else\>:\<endif\>]]
      vim.b.match_ignorecase = 1
    end)

    cursor(1, 1)
    feed('%')
    eq({ 2, 1 }, pos())
    feed('%')
    eq({ 3, 1 }, pos())
    feed('g%')
    eq({ 2, 1 }, pos())
    feed('g%')
    eq({ 1, 1 }, pos())
  end)

  it('honors line skip expressions', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { 'if', '# endif', 'endif' })
    exec_lua(function()
      vim.b.match_words = [[\<if\>:\<endif\>]]
      vim.b.match_skip = 'r:#'
    end)

    cursor(1, 1)
    feed('%')
    eq({ 3, 1 }, pos())
  end)

  it('jumps to the nearest unmatched group with [% and ]%', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { 'if', '  if', '  endif', 'endif' })
    exec_lua(function()
      vim.b.match_words = [[\<if\>:\<endif\>]]
    end)

    cursor(3, 3)
    feed('[%')
    eq({ 2, 3 }, pos())
    feed(']%')
    eq({ 3, 3 }, pos())
  end)

  it('uses b:match_function and falls back after an empty result', function()
    source([[
      function! MatchitTest(forward)
        return a:forward ? [3, 1] : [1, 1]
      endfunction
    ]])
    command([[let b:match_function = function('MatchitTest')]])
    api.nvim_buf_set_lines(0, 0, -1, true, { 'start', 'middle', 'end' })

    cursor(1, 1)
    feed('%')
    eq({ 3, 1 }, pos())
    feed('g%')
    eq({ 1, 1 }, pos())

    source([[
      function! MatchitFallback(forward)
        return []
      endfunction
    ]])
    command([[let b:match_function = function('MatchitFallback')]])
    exec_lua(function()
      vim.b.match_words = [[\<start\>:\<end\>]]
    end)
    feed('%')
    eq({ 3, 1 }, pos())
  end)

  it('restores options changed while searching', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { 'IF', 'endif' })
    command('set noignorecase smartcase virtualedit=all')
    exec_lua(function()
      vim.b.match_words = [[\<if\>:\<endif\>]]
      vim.b.match_ignorecase = 1
    end)

    cursor(1, 1)
    feed('%')
    eq({ 2, 1 }, pos())
    eq(false, api.nvim_get_option_value('ignorecase', {}))
    eq(true, api.nvim_get_option_value('smartcase', {}))
    eq('all', api.nvim_get_option_value('virtualedit', {}))
  end)

  it('keeps the autoload compatibility functions callable', function()
    api.nvim_buf_set_lines(0, 0, -1, true, { 'if', 'endif' })
    exec_lua(function()
      vim.b.match_words = [[\<if\>:\<endif\>]]
    end)

    cursor(1, 1)
    command([[call matchit#Match_wrapper('', 1, 'n')]])
    eq({ 2, 1 }, pos())
    command('call matchit#Match_debug()')
    eq(1, exec_lua('return vim.b.match_debug'))
  end)
end)
