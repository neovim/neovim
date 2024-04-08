-- Tests for getcwd(), haslocaldir(), and :lcd

local t = require('test.functional.testutil')(after_each)
local eq, eval, source = t.eq, t.eval, t.source
local call, clear, command = t.call, t.clear, t.command

describe('getcwd', function()
  before_each(clear)

  after_each(function()
    t.rmdir('Xtopdir')
  end)

  it('is working', function()
    source([[
      function! GetCwdInfo(win, tab)
       let tab_changed = 0
       let mod = ":t"
       if a:tab > 0 && a:tab != tabpagenr()
         let tab_changed = 1
         exec "tabnext " . a:tab
       endif
       let bufname = fnamemodify(bufname(winbufnr(a:win)), mod)
       if tab_changed
         tabprevious
       endif
       if a:win == 0 && a:tab == 0
         let dirname = fnamemodify(getcwd(), mod)
         let lflag = haslocaldir()
       elseif a:tab == 0
         let dirname = fnamemodify(getcwd(a:win), mod)
         let lflag = haslocaldir(a:win)
       else
         let dirname = fnamemodify(getcwd(a:win, a:tab), mod)
         let lflag = haslocaldir(a:win, a:tab)
       endif
       return bufname . ' ' . dirname . ' ' . lflag
      endfunction
    ]])
    command('new')
    command('let cwd=getcwd()')
    call('mkdir', 'Xtopdir')
    command('silent cd Xtopdir')
    call('mkdir', 'Xdir1')
    call('mkdir', 'Xdir2')
    call('mkdir', 'Xdir3')
    command('new a')
    command('new b')
    command('new c')
    command('3wincmd w')
    command('silent lcd Xdir1')
    eq('a Xdir1 1', eval('GetCwdInfo(0, 0)'))
    command('wincmd W')
    eq('b Xtopdir 0', eval('GetCwdInfo(0, 0)'))
    command('wincmd W')
    command('silent lcd Xdir3')
    eq('c Xdir3 1', eval('GetCwdInfo(0, 0)'))
    eq('a Xdir1 1', eval('GetCwdInfo(bufwinnr("a"), 0)'))
    eq('b Xtopdir 0', eval('GetCwdInfo(bufwinnr("b"), 0)'))
    eq('c Xdir3 1', eval('GetCwdInfo(bufwinnr("c"), 0)'))
    command('wincmd W')
    eq('a Xdir1 1', eval('GetCwdInfo(bufwinnr("a"), tabpagenr())'))
    eq('b Xtopdir 0', eval('GetCwdInfo(bufwinnr("b"), tabpagenr())'))
    eq('c Xdir3 1', eval('GetCwdInfo(bufwinnr("c"), tabpagenr())'))

    command('tabnew x')
    command('new y')
    command('new z')
    command('3wincmd w')
    eq('x Xtopdir 0', eval('GetCwdInfo(0, 0)'))
    command('wincmd W')
    command('silent lcd Xdir2')
    eq('y Xdir2 1', eval('GetCwdInfo(0, 0)'))
    command('wincmd W')
    command('silent lcd Xdir3')
    eq('z Xdir3 1', eval('GetCwdInfo(0, 0)'))
    eq('x Xtopdir 0', eval('GetCwdInfo(bufwinnr("x"), 0)'))
    eq('y Xdir2 1', eval('GetCwdInfo(bufwinnr("y"), 0)'))
    eq('z Xdir3 1', eval('GetCwdInfo(bufwinnr("z"), 0)'))
    command('let tp_nr = tabpagenr()')
    command('tabrewind')
    eq('x Xtopdir 0', eval('GetCwdInfo(3, tp_nr)'))
    eq('y Xdir2 1', eval('GetCwdInfo(2, tp_nr)'))
    eq('z Xdir3 1', eval('GetCwdInfo(1, tp_nr)'))
  end)
end)
