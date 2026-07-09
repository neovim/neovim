local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local api = n.api
local clear = n.clear
local command = n.command
local eq = t.eq
local matches = t.matches
local exec = n.exec
local feed = n.feed

local function set_lines(lines)
  api.nvim_buf_set_lines(0, 0, -1, false, lines)
end

local function get_lines()
  return api.nvim_buf_get_lines(0, 0, -1, false)
end

local function setup(lines, ft)
  command('filetype plugin on')
  set_lines(lines)
  command('set filetype=' .. ft)
end

local function cursor(line, col)
  api.nvim_win_set_cursor(0, { line, col - 1 })
end

local function line_after(keys)
  feed(keys)
  return api.nvim_win_get_cursor(0)[1]
end

describe('matchit', function()
  before_each(function()
    clear({ args = { '-u', 'NORC' } })
    command('packadd matchit')
  end)

  it('loads default mappings', function()
    eq(1, api.nvim_get_var('loaded_matchit'))
    eq('<Plug>(MatchitNormalForward)', n.fn.maparg('%', 'n', false))
    eq('<Plug>(MatchitNormalBackward)', n.fn.maparg('g%', 'n', false))
  end)

  it('respects no_plugin_maps', function()
    clear({ args = { '-u', 'NORC', '--cmd', 'let g:no_plugin_maps = 1' } })
    eq('', n.fn.maparg('%', 'n', false))
    matches('^<Lua %d+: .*/runtime/lua/nvim/matchit.lua:%d+>$', n.fn.maparg('<Plug>(MatchitNormalForward)', 'n', false))
    api.nvim_del_var('no_plugin_maps')
    command('MatchEnable')
    eq('<Plug>(MatchitNormalForward)', n.fn.maparg('%', 'n', false))
  end)

  it('matches html tags', function()
    setup({ '<b>', '<big>some text</big>', '</b>' }, 'html')
    cursor(1, 2)
    eq(3, line_after('%'))
    cursor(3, 3)
    eq(1, line_after('%'))
    cursor(2, 2)
    eq(2, line_after('%'))
  end)

  it('matches html tags with attributes', function()
    setup({ '<b id="123">', '<big>some text</big>', '</b>' }, 'html')
    cursor(1, 2)
    eq(3, line_after('%'))
    cursor(3, 3)
    eq(1, line_after('%'))
    cursor(2, 2)
    eq(2, line_after('%'))
  end)

  it('matches html tags with multiline attributes', function()
    setup({ '<b', '  id="123"', '  name="abc"', '>', '<big>some text</big>', '</b>' }, 'html')
    cursor(1, 2)
    eq(6, line_after('%'))
    cursor(6, 3)
    eq(1, line_after('%'))
    cursor(5, 2)
    eq(5, line_after('%'))
  end)

  it('cycles lua keyword groups', function()
    setup({ 'if x then', '  a()', 'elseif y then', '  b()', 'else', '  c()', 'end' }, 'lua')
    cursor(1, 1)
    eq(3, line_after('%'))
    cursor(3, 1)
    eq(5, line_after('%'))
    cursor(5, 1)
    eq(7, line_after('%'))
    cursor(7, 1)
    eq(1, line_after('%'))
    cursor(5, 1)
    eq(3, line_after('g%'))
  end)

  it('jumps to unmatched groups', function()
    exec([[let b:match_words='\<if\>:\<endif\>']])
    set_lines({ 'if', '  if', '  endif', 'endif' })
    cursor(2, 3)
    eq(3, line_after(']%'))
    cursor(2, 1)
    eq(4, line_after(']%'))
    cursor(3, 3)
    eq(2, line_after('[%'))
  end)

  it('jumps to bracket pairs with matchit motions', function()
    set_lines({ 'a = (b + c)' })
    cursor(1, 5)
    eq(1, line_after(']%'))
    eq(11, api.nvim_win_get_cursor(0)[2] + 1)
    cursor(1, 11)
    eq(1, line_after('[%'))
    eq(5, api.nvim_win_get_cursor(0)[2] + 1)
  end)

  it('prefers earlier groups when matches start together', function()
    set_lines({ '<tag>body</tag>' })
    exec([[let b:match_words='<:>,<tag>:</tag>']])
    cursor(1, 1)
    feed('%')
    eq(5, api.nvim_win_get_cursor(0)[2] + 1)
    cursor(1, 3)
    feed('%')
    eq(10, api.nvim_win_get_cursor(0)[2] + 1)
  end)

  it('selects visual text object', function()
    setup({ '<b>', '<big>some text</big>', '</b>' }, 'html')
    cursor(2, 7)
    feed('va%y')
    eq('<big>some text</big>', n.fn.getreg('"'))
  end)

  it('selects visual text object from an opening tag', function()
    setup({ '<b>', '  <i>text</i>', '</b>' }, 'html')
    cursor(1, 2)
    feed('va%y')
    eq('<b>\n  <i>text</i>\n</b>', n.fn.getreg('"'))
  end)

  it('handles exclusive visual selections', function()
    setup({ '<b>', 'text', '</b>' }, 'html')
    command('set selection=exclusive')
    cursor(1, 2)
    feed('v%y')
    eq('b>\ntext\n</', n.fn.getreg('"'))
  end)

  it('uses operator-pending mappings', function()
    set_lines({ '(foo)' })
    cursor(1, 1)
    feed('d%')
    eq({ '' }, get_lines())
  end)

  it('can enable and disable mappings', function()
    command('MatchDisable')
    eq('', n.fn.maparg('%', 'n', false))
    command('MatchEnable')
    eq('<Plug>(MatchitNormalForward)', n.fn.maparg('%', 'n', false))
  end)

  it('keeps count percent behavior', function()
    local lines = {}
    for i = 1, 100 do
      lines[i] = tostring(i)
    end
    set_lines(lines)
    cursor(1, 1)
    eq(50, line_after('50%'))
  end)

  it('uses match ignorecase', function()
    set_lines({ 'IF', 'endif' })
    exec([[let b:match_words='\<if\>:\<endif\>']])
    exec('let b:match_ignorecase = 1')
    cursor(1, 1)
    eq(2, line_after('%'))
  end)

  it('matches backrefs with captures at the end of patterns', function()
    exec([[let b:match_words='\(foo\|bar\):end\1']])
    set_lines({ 'foo', 'endfoo', 'bar', 'endbar' })
    cursor(1, 1)
    eq(2, line_after('%'))
    cursor(3, 1)
    eq(4, line_after('%'))
  end)

  it('matches lua long brackets', function()
    setup({ '--[[', 'x', ']]' }, 'lua')
    cursor(1, 1)
    eq(3, line_after('%'))
    cursor(3, 1)
    eq(1, line_after('%'))
  end)

  it('matches lua long brackets with equals signs', function()
    setup({ '--[=[', 'x', ']=]' }, 'lua')
    cursor(1, 1)
    eq(3, line_after('%'))
    cursor(3, 1)
    eq(1, line_after('%'))
  end)

  it('uses match skip expressions', function()
    set_lines({ 'if', '  if', 'endif' })
    exec([[let b:match_words='\<if\>:\<endif\>']])
    exec([[let b:match_skip='r:^  ']])
    cursor(3, 1)
    eq(1, line_after('%'))
  end)

  it('handles invalid match skip expressions gracefully', function()
    set_lines({ 'if', 'endif' })
    exec([[let b:match_words='\<if\>:\<endif\>']])
    exec([[let b:match_skip='s']])
    cursor(1, 1)
    eq(2, line_after('%'))
  end)

  it('uses match function hooks', function()
    set_lines({ 'alpha', 'beta', 'gamma' })
    exec([[
      function! MatchitTestHook(forward) abort
        return [3, 1]
      endfunction
      let b:match_function = function('MatchitTestHook')
    ]])
    cursor(1, 1)
    eq(3, line_after('%'))
  end)

  it('falls back when match function hooks return no match', function()
    set_lines({ 'if', 'endif' })
    exec([[
      let b:match_words='\<if\>:\<endif\>'
      function! MatchitFallbackHook(forward) abort
        return []
      endfunction
      let b:match_function = function('MatchitFallbackHook')
    ]])
    cursor(1, 1)
    eq(2, line_after('%'))
  end)
end)
