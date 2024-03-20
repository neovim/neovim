local helpers = require('test.functional.helpers')(after_each)

local clear = helpers.clear
local command = helpers.command
local eq = helpers.eq
local eval = helpers.eval
local feed = helpers.feed

describe('autocmd CmdlineCharPre', function()
  it('works', function()
    clear()
    command("autocmd CmdlineCharPre * let v:char='b'")
    command('autocmd CmdlineChanged * let g:changed=1')
    feed(':a')
    eq('b', eval('getcmdline()'))
    eq(1, eval('g:changed'))
    clear()
    command("autocmd CmdlineCharPre * let v:char=expand('<afile>')")
    feed(':a')
    eq(':', eval('getcmdline()'))
    clear()
    command("autocmd CmdlineCharPre * let v:char=luaeval('vim.keycode([[<Up>]])')")
    feed(':a')
    eq(eval("luaeval('vim.keycode([[<Up>]])')"), eval('getcmdline()'))
    clear()
    command('let g:changed=0')
    command('autocmd CmdlineChanged * let g:changed=1')
    command("autocmd CmdlineCharPre * let v:char=''")
    feed(':a')
    eq('', eval('getcmdline()'))
    eq(0, eval('g:changed'))
    clear()
    command("autocmd CmdlineCharPre * let v:char='b'")
    feed(':<C-v>a')
    eq('a', eval('getcmdline()'))
    clear()
    command('cabbrev f foo')
    feed(':f')
    command("autocmd CmdlineCharPre * if v:char=='a'|let v:char=' '|endif")
    feed('a')
    eq('foo ', eval('getcmdline()'))
    clear()
    command('cabbrev f foo')
    feed(':f')
    command("autocmd CmdlineCharPre * if v:char=='a'|let v:char='  '|endif")
    feed('a')
    eq('f  ', eval('getcmdline()'))
    clear()
    command('cnoremap a b')
    command("autocmd CmdlineCharPre * if v:char=='b'|let v:char='c'|endif")
    feed(':a')
    eq('c', eval('getcmdline()'))
  end)
end)
