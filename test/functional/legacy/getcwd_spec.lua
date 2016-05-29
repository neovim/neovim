-- Tests for getcwd(), haslocaldir(), and :lcd

local helpers = require('test.functional.helpers')(after_each)
local eq, eval, source = helpers.eq, helpers.eval, helpers.source
local call, clear, execute = helpers.call, helpers.clear, helpers.execute

describe('getcwd', function()
  before_each(clear)

  after_each(function()
    helpers.rmdir('Xtopdir')
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
    execute('new')
    execute('let cwd=getcwd()')
    call('mkdir', 'Xtopdir')
    execute('silent cd Xtopdir')
    call('mkdir', 'Xdir1')
    call('mkdir', 'Xdir2')
    call('mkdir', 'Xdir3')
    execute('new a')
    execute('new b')
    execute('new c')
    execute('3wincmd w')
    execute('silent lcd Xdir1')
    eq('a Xdir1 1', eval('GetCwdInfo(0, 0)'))
    execute('wincmd W')
    eq('b Xtopdir 0', eval('GetCwdInfo(0, 0)'))
    execute('wincmd W')
    execute('silent lcd Xdir3')
    eq('c Xdir3 1', eval('GetCwdInfo(0, 0)'))
    eq('a Xdir1 1', eval('GetCwdInfo(bufwinnr("a"), 0)'))
    eq('b Xtopdir 0', eval('GetCwdInfo(bufwinnr("b"), 0)'))
    eq('c Xdir3 1', eval('GetCwdInfo(bufwinnr("c"), 0)'))
    execute('wincmd W')
    eq('a Xdir1 1', eval('GetCwdInfo(bufwinnr("a"), tabpagenr())'))
    eq('b Xtopdir 0', eval('GetCwdInfo(bufwinnr("b"), tabpagenr())'))
    eq('c Xdir3 1', eval('GetCwdInfo(bufwinnr("c"), tabpagenr())'))

    execute('tabnew x')
    execute('new y')
    execute('new z')
    execute('3wincmd w')
    eq('x Xtopdir 0', eval('GetCwdInfo(0, 0)'))
    execute('wincmd W')
    execute('silent lcd Xdir2')
    eq('y Xdir2 1', eval('GetCwdInfo(0, 0)'))
    execute('wincmd W')
    execute('silent lcd Xdir3')
    eq('z Xdir3 1', eval('GetCwdInfo(0, 0)'))
    eq('x Xtopdir 0', eval('GetCwdInfo(bufwinnr("x"), 0)'))
    eq('y Xdir2 1', eval('GetCwdInfo(bufwinnr("y"), 0)'))
    eq('z Xdir3 1', eval('GetCwdInfo(bufwinnr("z"), 0)'))
    execute('let tp_nr = tabpagenr()')
    execute('tabrewind')
    eq('x Xtopdir 0', eval('GetCwdInfo(3, tp_nr)'))
    eq('y Xdir2 1', eval('GetCwdInfo(2, tp_nr)'))
    eq('z Xdir3 1', eval('GetCwdInfo(1, tp_nr)'))
  end)
end)
