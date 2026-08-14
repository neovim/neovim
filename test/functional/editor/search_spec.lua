local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
local api = n.api
local clear = n.clear
local command = n.command
local eq = t.eq
local feed = n.feed
local fn = n.fn
local pcall_err = t.pcall_err

describe('search (/)', function()
  before_each(clear)

  it('fails with huge column (%c) value #9930', function()
    eq([[Vim:E951: \% value too large]], pcall_err(command, '/\\v%18446744071562067968c'))
    eq([[Vim:E951: \% value too large]], pcall_err(command, '/\\v%2147483648c'))
  end)
end)

describe('gn', function()
  before_each(function()
    clear()
    api.nvim_buf_set_lines(0, 0, -1, true, { 'a b foo bar', 'x y zub foo' })
    feed('ggVG<Esc>') -- Visual-select the whole buffer to set '< and '>
  end)

  it('with a pending operator does not modify the Visual marks #40949', function()
    fn.setreg('/', [[\%Vfoo]])
    feed('gg0cgnX<Esc>')
    eq({ 'a b X bar', 'x y zub foo' }, api.nvim_buf_get_lines(0, 0, -1, true))
    eq({ 1, 0 }, api.nvim_buf_get_mark(0, '<'))
    eq({ 2, 2147483647 }, api.nvim_buf_get_mark(0, '>'))
    eq('V', fn.visualmode())
    -- The second match is still inside the \%V area, so "." reaches it.
    feed('.')
    eq({ 'a b X bar', 'x y zub X' }, api.nvim_buf_get_lines(0, 0, -1, true))
    eq({ 1, 0 }, api.nvim_buf_get_mark(0, '<'))
    eq({ 2, 2147483647 }, api.nvim_buf_get_mark(0, '>'))
  end)

  it('in Visual mode still sets the Visual marks', function()
    fn.setreg('/', 'foo')
    feed('gg0vgn<Esc>')
    eq({ 1, 0 }, api.nvim_buf_get_mark(0, '<'))
    eq({ 1, 6 }, api.nvim_buf_get_mark(0, '>'))
    eq('v', fn.visualmode())
  end)
end)
