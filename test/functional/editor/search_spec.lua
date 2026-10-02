local t = require('test.testutil')
local n = require('test.functional.testnvim')()

local describe, it, before_each = t.describe, t.it, t.before_each
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

  it('operator + gn does not modify the Visual marks #40949', function()
    fn.setline(1, { 'a b foo bar', 'x y zub foo', 'foo' })
    feed('ggVj<Esc>') -- Select lines 1-2.
    local vstart, vend = fn.getpos("'<"), fn.getpos("'>")
    feed([[/\%Vfoo<CR>]])
    feed('ggcgnX<Esc>')
    eq({ vstart, vend, 'V' }, { fn.getpos("'<"), fn.getpos("'>"), fn.visualmode() })
    -- "\%V" still means the selection: "." changes the next match in it, not the one on line 3.
    feed('.')
    eq({ 'a b X bar', 'x y zub X', 'foo' }, fn.getline(1, '$'))
    -- Same for a forced-blockwise motion.
    feed('ggd<C-v>j')
    eq({ vstart, vend, 'V' }, { fn.getpos("'<"), fn.getpos("'>"), fn.visualmode() })
    -- Same for an omap that starts Visual mode (custom textobj).
    command('onoremap <silent> F :<C-U>normal! 0viw<CR>')
    feed('GyF')
    eq('foo', fn.getreg('"'))
    eq({ vstart, vend, 'V' }, { fn.getpos("'<"), fn.getpos("'>"), fn.visualmode() })
  end)
end)
