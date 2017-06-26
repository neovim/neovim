-- Tests for tab pages

local helpers = require('test.functional.helpers')(after_each)
local feed, insert, source, clear, command, expect, eval, eq =
  helpers.feed, helpers.insert, helpers.source, helpers.clear,
  helpers.command, helpers.expect, helpers.eval, helpers.eq
local exc_exec = helpers.exc_exec

describe('tab pages', function()
  before_each(clear)

  it('can be opened and closed', function()
    command('tabnew')
    eq(2, eval('tabpagenr()'))
    command('quit')
    eq(1, eval('tabpagenr()'))
  end)

  it('can be iterated with :tabdo', function()
    source([[
      0tabnew
      1tabnew
      $tabnew
      tabdo call append(line('$'), 'this is tab page ' . tabpagenr())
      tabclose! 2
      tabrewind
    ]])
    eq('this is tab page 1', eval("getline('$')"))
    command('tablast')
    eq('this is tab page 4', eval("getline('$')"))
  end)

  it('have local variables accasible with settabvar()/gettabvar()', function()
    -- Test for settabvar() and gettabvar() functions. Open a new tab page and
    -- set 3 variables to a number, string and a list. Verify that the
    -- variables are correctly set.
    source([[
      tabnew
      tabfirst
      call settabvar(2, 'val_num', 100)
      call settabvar(2, 'val_str', 'SetTabVar test')
      call settabvar(2, 'val_list', ['red', 'blue', 'green'])
    ]])

    eq(100, eval('gettabvar(2, "val_num")'))
    eq('SetTabVar test', eval('gettabvar(2, "val_str")'))
    eq({'red', 'blue', 'green'}, eval('gettabvar(2, "val_list")'))
    command('tabnext 2')
    eq(100, eval('t:val_num'))
    eq('SetTabVar test', eval('t:val_str'))
    eq({'red', 'blue', 'green'}, eval('t:val_list'))
  end)

  it('work together with the drop feature and loaded buffers', function()
    -- Test for ":tab drop exist-file" to keep current window.
    command('sp test1')
    command('tab drop test1')
    eq(1, eval('tabpagenr("$")'))
    eq(2, eval('winnr("$")'))
    eq(1, eval('winnr()'))
  end)

  it('work together with the drop feature and new files', function()
    -- Test for ":tab drop new-file" to keep current window of tabpage 1.
    command('split')
    command('tab drop newfile')
    eq(2, eval('tabpagenr("$")'))
    eq(2, eval('tabpagewinnr(1, "$")'))
    eq(1, eval('tabpagewinnr(1)'))
  end)

  it('work together with the drop feature and multi loaded buffers', function()
    -- Test for ":tab drop multi-opend-file" to keep current tabpage and
    -- window.
    command('new test1')
    command('tabnew')
    command('new test1')
    command('tab drop test1')
    eq(2, eval('tabpagenr()'))
    eq(2, eval('tabpagewinnr(2, "$")'))
    eq(1, eval('tabpagewinnr(2)'))
  end)

  it('can be navigated with :tabmove', function()
    command('lang C')
    command('for i in range(9) | tabnew | endfor')
    feed('1gt')
    eq(1, eval('tabpagenr()'))
    command('tabmove 5')
    eq(5, eval('tabpagenr()'))
    command('.tabmove')
    eq(5, eval('tabpagenr()'))
    command('tabmove -')
    eq(4, eval('tabpagenr()'))
    command('tabmove +')
    eq(5, eval('tabpagenr()'))
    command('tabmove -2')
    eq(3, eval('tabpagenr()'))
    command('tabmove +4')
    eq(7, eval('tabpagenr()'))
    command('tabmove')
    eq(10, eval('tabpagenr()'))
    command('0tabmove')
    eq(1, eval('tabpagenr()'))
    command('$tabmove')
    eq(10, eval('tabpagenr()'))
    command('tabmove 0')
    eq(1, eval('tabpagenr()'))
    command('tabmove $')
    eq(10, eval('tabpagenr()'))
    command('3tabmove')
    eq(4, eval('tabpagenr()'))
    command('7tabmove 5')
    eq(5, eval('tabpagenr()'))
    command('let a="No error caught."')
    eq('Vim(tabmove):E474: Invalid argument: tabmove foo',
       exc_exec('tabmove foo'))
  end)

  it('can trigger certain autocommands', function()
    insert('Results:')

    -- Test autocommands.
    source([[
      tabonly!
      let g:r=[]
      command -nargs=1 -bar C :call add(g:r, '=== '.<q-args>.' ===')|<args>
      function Test()
	  autocmd TabEnter * :call add(g:r, 'TabEnter')
	  autocmd WinEnter * :call add(g:r, 'WinEnter')
	  autocmd BufEnter * :call add(g:r, 'BufEnter')
	  autocmd TabLeave * :call add(g:r, 'TabLeave')
	  autocmd WinLeave * :call add(g:r, 'WinLeave')
	  autocmd BufLeave * :call add(g:r, 'BufLeave')
          let t:a='a'
          C tab split
          let t:a='b'
          C tabnew
          let t:a='c'
          call add(g:r, join(map(range(1, tabpagenr('$')),
	    \ 'gettabvar(v:val, "a")')))
          C call map(range(1, tabpagenr('$')),
	    \ 'settabvar(v:val, ''a'', v:val*2)')
          call add(g:r, join(map(range(1, tabpagenr('$')),
	    \ 'gettabvar(v:val, "a")')))
          let w:a='a'
          C vsplit
          let w:a='a'
          let tabn=tabpagenr()
          let winr=range(1, winnr('$'))
          C tabnext 1
          call add(g:r, join(map(copy(winr),
	    \ 'gettabwinvar('.tabn.', v:val, "a")')))
          C call map(copy(winr),
	    \ 'settabwinvar('.tabn.', v:val, ''a'', v:val*2)')
          call add(g:r, join(map(copy(winr),
	    \ 'gettabwinvar('.tabn.', v:val, "a")')))
	  augroup TabDestructive
	      autocmd TabEnter * :C tabnext 2 | C tabclose 3
	  augroup END
	  C tabnext 3
	  let g:r+=[tabpagenr().'/'.tabpagenr('$')]
	  autocmd! TabDestructive TabEnter
	  C tabnew
	  C tabnext 1
	  autocmd TabDestructive TabEnter * nested
	    \ :C tabnext 2 | C tabclose 3
	  C tabnext 2
	  let g:r+=[tabpagenr().'/'.tabpagenr('$')]
      endfunction
      call Test()
      $ put =g:r
    ]])

    -- Assert buffer contents.
    expect([[
      Results:
      === tab split ===
      WinLeave
      TabLeave
      WinEnter
      TabEnter
      === tabnew ===
      WinLeave
      TabLeave
      WinEnter
      TabEnter
      BufLeave
      BufEnter
      a b c
      === call map(range(1, tabpagenr('$')), 'settabvar(v:val, ''a'', v:val*2)') ===
      2 4 6
      === vsplit ===
      WinLeave
      WinEnter
      === tabnext 1 ===
      BufLeave
      WinLeave
      TabLeave
      WinEnter
      TabEnter
      BufEnter
      a a
      === call map(copy(winr), 'settabwinvar('.tabn.', v:val, ''a'', v:val*2)') ===
      2 4
      === tabnext 3 ===
      BufLeave
      WinLeave
      TabLeave
      WinEnter
      TabEnter
      === tabnext 2 ===
      === tabclose 3 ===
      2/2
      === tabnew ===
      WinLeave
      TabLeave
      WinEnter
      TabEnter
      BufLeave
      BufEnter
      === tabnext 1 ===
      BufLeave
      WinLeave
      TabLeave
      WinEnter
      TabEnter
      BufEnter
      === tabnext 2 ===
      WinLeave
      TabLeave
      WinEnter
      TabEnter
      === tabnext 2 ===
      === tabclose 3 ===
      2/2]])
      eq(2, eval("tabpagenr('$')"))
  end)
end)
