-- Tests for tab pages

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('tab pages', function()
  setup(clear)

  it('is working', function()
    insert([=[
      Results:]=])

    execute('lang C')

    -- Simple test for opening and closing a tab page.
    source([[
      tabnew
      let nr = tabpagenr()
      q
      call append(line('$'), 'tab page ' . nr)
      unlet nr
    ]])

    -- Open three tab pages and use ":tabdo".
    source([[
      0tabnew
      1tabnew
      $tabnew
      tabdo call append(line('$'), 'this is tab page ' . tabpagenr())
      tabclose! 2
      tabrewind
      let line1 = getline('$')
      undo
      q
      tablast
      let line2 = getline('$')
      q!
      call append(line('$'), line1)
      call append(line('$'), line2)
      unlet line1 line2
    ]])

    -- Test for settabvar() and gettabvar() functions. Open a new tab page and
    -- set 3 variables to a number, string and a list. Verify that the
    -- variables are correctly set.
    source([=[
      tabnew
      tabfirst
      call settabvar(2, 'val_num', 100)
      call settabvar(2, 'val_str', 'SetTabVar test')
      call settabvar(2, 'val_list', ['red', 'blue', 'green'])

      let test_status = 'gettabvar: fail'
      if  gettabvar(2, 'val_num') == 100 &&
	\ gettabvar(2, 'val_str') == 'SetTabVar test' &&
	\ gettabvar(2, 'val_list') == ['red', 'blue', 'green']
          let test_status = 'gettabvar: pass'
      endif
      call append(line('$'), test_status)

      tabnext 2
      let test_status = 'settabvar: fail'
      if  t:val_num == 100 &&
	\ t:val_str == 'SetTabVar test' &&
	\ t:val_list == ['red', 'blue', 'green']
         let test_status = 'settabvar: pass'
      endif
      tabclose
      call append(line('$'), test_status)
    ]=])

    -- Test some drop features
    source([[
      " Test for ":tab drop exist-file" to keep current window.
      sp test1
      tab drop test1
      let test_status = 'tab drop 1: fail'
      if tabpagenr('$') == 1 && winnr('$') == 2 && winnr() == 1
	  let test_status = 'tab drop 1: pass'
      endif
      close
      call append(line('$'), test_status)

      " Test for ":tab drop new-file" to keep current window of tabpage 1.
      split
      tab drop newfile
      let test_status = 'tab drop 2: fail'
      if  tabpagenr('$') == 2 &&
	\ tabpagewinnr(1, '$') == 2 &&
	\ tabpagewinnr(1) == 1
	  let test_status = 'tab drop 2: pass'
      endif
      tabclose
      q
      call append(line('$'), test_status)

      " Test for ":tab drop multi-opend-file" to keep current tabpage and
      " window.
      new test1
      tabnew
      new test1
      tab drop test1
      let test_status = 'tab drop 3: fail'
      if  tabpagenr() == 2 &&
	\ tabpagewinnr(2, '$') == 2 &&
	\ tabpagewinnr(2) == 1
	  let test_status = 'tab drop 3: pass'
      endif
      tabclose
      q
      call append(line('$'), test_status)
    ]])
-------

    execute('for i in range(9) | tabnew | endfor')
    feed('1gt')
    feed('Go<C-R>=tabpagenr()<C-M><C-M><esc>')
    execute('tabmove 5')
    feed('i<C-R>=tabpagenr()<C-M><C-M><esc>')
    execute('tabmove -2')
    feed('i<C-R>=tabpagenr()<C-M><C-M><esc>')
    execute('tabmove +4')
    feed('i<C-R>=tabpagenr()<C-M><C-M><esc>')
    execute('tabmove')
    feed('i<C-R>=tabpagenr()<C-M><C-M><esc>')
    execute('tabmove -20')
    feed('i<C-R>=tabpagenr()<C-M><C-M><esc>')
    execute('tabmove +20')
    feed('i<C-R>=tabpagenr()<C-M><C-M><esc>')
    execute('3tabmove')
    feed('i<C-R>=tabpagenr()<C-M><C-M><esc>')
    execute('7tabmove 5')
    feed('i<C-R>=tabpagenr()<C-M><C-M><esc>')
    execute([[let a='No error caught.']])
    execute('try')
    execute('tabmove foo')
    execute('catch E474')
    execute([[let a='E474 caught.']])
    execute('endtry')
    feed('i<C-R>=a<C-M><esc>')

    -- Test autocommands.
    source([=[
      tabonly!
      let g:r=[]
      command -nargs=1 -bar C :call add(g:r, '=== '.<q-args>.' ===')|<args>
      function Test()
          let hasau=has('autocmd')
          if hasau
              autocmd TabEnter * :call add(g:r, 'TabEnter')
              autocmd WinEnter * :call add(g:r, 'WinEnter')
              autocmd BufEnter * :call add(g:r, 'BufEnter')
              autocmd TabLeave * :call add(g:r, 'TabLeave')
              autocmd WinLeave * :call add(g:r, 'WinLeave')
              autocmd BufLeave * :call add(g:r, 'BufLeave')
          endif
          let t:a='a'
          C tab split
          if !hasau
              let g:r+=['WinLeave', 'TabLeave', 'WinEnter', 'TabEnter']
          endif
          let t:a='b'
          C tabnew
          if !hasau
              let g:r+=['WinLeave', 'TabLeave', 'WinEnter', 'TabEnter',
	              \ 'BufLeave', 'BufEnter']
          endif
          let t:a='c'
          call add(g:r, join(map(range(1, tabpagenr('$')),
	    \ 'gettabvar(v:val, "a")')))
          C call map(range(1, tabpagenr('$')),
	    \ 'settabvar(v:val, ''a'', v:val*2)')
          call add(g:r, join(map(range(1, tabpagenr('$')),
	    \ 'gettabvar(v:val, "a")')))
          let w:a='a'
          C vsplit
          if !hasau
              let g:r+=['WinLeave', 'WinEnter']
          endif
          let w:a='a'
          let tabn=tabpagenr()
          let winr=range(1, winnr('$'))
          C tabnext 1
          if !hasau
              let g:r+=['BufLeave', 'WinLeave', 'TabLeave', 'WinEnter',
		\ 'TabEnter', 'BufEnter']
          endif
          call add(g:r, join(map(copy(winr),
	    \ 'gettabwinvar('.tabn.', v:val, "a")')))
          C call map(copy(winr),
	    \ 'settabwinvar('.tabn.', v:val, ''a'', v:val*2)')
          call add(g:r, join(map(copy(winr),
	    \ 'gettabwinvar('.tabn.', v:val, "a")')))
          if hasau
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
              C tabnext 3
              let g:r+=[tabpagenr().'/'.tabpagenr('$')]
          else
              let g:r+=["=== tabnext 3 ===", "BufLeave", "WinLeave",
		\ "TabLeave", "WinEnter", "TabEnter", "=== tabnext 2 ===",
		\ "=== tabclose 3 ===", "2/2", "=== tabnew ===", "WinLeave",
		\ "TabLeave", "WinEnter", "TabEnter", "BufLeave", "BufEnter",
		\ "=== tabnext 1 ===", "BufLeave", "WinLeave", "TabLeave",
		\ "WinEnter", "TabEnter", "BufEnter", "=== tabnext 3 ===",
		\ "BufLeave", "WinLeave", "TabLeave", "WinEnter", "TabEnter",
		\ "=== tabnext 2 ===", "BufLeave", "WinLeave", "TabLeave",
		\ "WinEnter", "TabEnter", "=== tabnext 2 ===",
		\ "=== tabclose 3 ===", "BufEnter", "=== tabclose 3 ===",
		\ "2/2"]
          endif
      endfunction
      call Test()
      $ put =g:r
    ]=])


    --execute('0,/^Results/-1 d')
    --execute('qa!')

    -- Assert buffer contents.
    expect([=[
      Results:
      tab page 2
      this is tab page 3
      this is tab page 1
      this is tab page 4
      gettabvar: pass
      settabvar: pass
      tab drop 1: pass
      tab drop 2: pass
      tab drop 3: pass
      1
      6
      4
      8
      10
      1
      10
      4
      6
      E474 caught.
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
      === tabnext 3 ===
      BufLeave
      WinLeave
      TabLeave
      WinEnter
      TabEnter
      === tabnext 2 ===
      BufLeave
      WinLeave
      TabLeave
      WinEnter
      TabEnter
      === tabnext 2 ===
      === tabclose 3 ===
      BufEnter
      === tabclose 3 ===
      2/2]=])
  end)
end)
