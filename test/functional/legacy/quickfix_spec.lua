-- Test for the quickfix commands.

local helpers = require('test.functional.helpers')(after_each)
local source, clear = helpers.source, helpers.clear
local eq, nvim, call = helpers.eq, helpers.meths, helpers.call
local eval = helpers.eval
local execute = helpers.execute

local function expected_empty()
  eq({}, nvim.get_vvar('errors'))
end

describe('helpgrep', function()
  before_each(function()
    clear()

    source([[
      " Tests for the :clist and :llist commands
      function XlistTests(cchar)
        let Xlist = a:cchar . 'list'
        let Xgetexpr = a:cchar . 'getexpr'

        " With an empty list, command should return error
        exe Xgetexpr . ' []'
        exe 'silent! ' . Xlist
        call assert_true(v:errmsg ==# 'E42: No Errors')

        " Populate the list and then try
        exe Xgetexpr . " ['non-error 1', 'Xtestfile1:1:3:Line1',
                  \ 'non-error 2', 'Xtestfile2:2:2:Line2',
                  \ 'non-error 3', 'Xtestfile3:3:1:Line3']"

        " List only valid entries
        redir => result
        exe 'silent ' . Xlist
        redir END
        let l = split(result, "\n")
        call assert_equal([' 2 Xtestfile1:1 col 3: Line1',
                   \ ' 4 Xtestfile2:2 col 2: Line2',
                   \ ' 6 Xtestfile3:3 col 1: Line3'], l)

        " List all the entries
        redir => result
        exe 'silent ' . Xlist . "!"
        redir END
        let l = split(result, "\n")
        call assert_equal([' 1: non-error 1', ' 2 Xtestfile1:1 col 3: Line1',
                   \ ' 3: non-error 2', ' 4 Xtestfile2:2 col 2: Line2',
                   \ ' 5: non-error 3', ' 6 Xtestfile3:3 col 1: Line3'], l)

        " List a range of errors
        redir => result
        exe 'silent '. Xlist . " 3,6"
        redir END
        let l = split(result, "\n")
        call assert_equal([' 4 Xtestfile2:2 col 2: Line2',
                   \ ' 6 Xtestfile3:3 col 1: Line3'], l)

        redir => result
        exe 'silent ' . Xlist . "! 3,4"
        redir END
        let l = split(result, "\n")
        call assert_equal([' 3: non-error 2', ' 4 Xtestfile2:2 col 2: Line2'], l)

        redir => result
        exe 'silent ' . Xlist . " -6,-4"
        redir END
        let l = split(result, "\n")
        call assert_equal([' 2 Xtestfile1:1 col 3: Line1'], l)

        redir => result
        exe 'silent ' . Xlist . "! -5,-3"
        redir END
        let l = split(result, "\n")
        call assert_equal([' 2 Xtestfile1:1 col 3: Line1',
                   \ ' 3: non-error 2', ' 4 Xtestfile2:2 col 2: Line2'], l)
      endfunction

      " Tests for the :colder, :cnewer, :lolder and :lnewer commands
      " Note that this test assumes that a quickfix/location list is
      " already set by the caller
      function XageTests(cchar)
        let Xolder = a:cchar . 'older'
        let Xnewer = a:cchar . 'newer'
        let Xgetexpr = a:cchar . 'getexpr'
        if a:cchar == 'c'
          let Xgetlist = 'getqflist()'
        else
          let Xgetlist = 'getloclist(0)'
        endif

        " Jumping to a non existent list should return error
        exe 'silent! ' . Xolder . ' 99'
        call assert_true(v:errmsg ==# 'E380: At bottom of quickfix stack')

        exe 'silent! ' . Xnewer . ' 99'
        call assert_true(v:errmsg ==# 'E381: At top of quickfix stack')

        " Add three quickfix/location lists
        exe Xgetexpr . " ['Xtestfile1:1:3:Line1']"
        exe Xgetexpr . " ['Xtestfile2:2:2:Line2']"
        exe Xgetexpr . " ['Xtestfile3:3:1:Line3']"

        " Go back two lists
        exe Xolder
        exe 'let l = ' . Xgetlist
        call assert_equal('Line2', l[0].text)

        " Go forward two lists
        exe Xnewer
        exe 'let l = ' . Xgetlist
        call assert_equal('Line3', l[0].text)

        " Test for the optional count argument
        exe Xolder . ' 2'
        exe 'let l = ' . Xgetlist
        call assert_equal('Line1', l[0].text)

        exe Xnewer . ' 2'
        exe 'let l = ' . Xgetlist
        call assert_equal('Line3', l[0].text)
      endfunction

      " Tests for the :cwindow, :lwindow :cclose, :lclose, :copen and :lopen
      " commands
      function XwindowTests(cchar)
        let Xwindow = a:cchar . 'window'
        let Xclose = a:cchar . 'close'
        let Xopen = a:cchar . 'open'
        let Xgetexpr = a:cchar . 'getexpr'

        " Create a list with no valid entries
        exe Xgetexpr . " ['non-error 1', 'non-error 2', 'non-error 3']"

        " Quickfix/Location window should not open with no valid errors
        exe Xwindow
        call assert_true(winnr('$') == 1)

        " Create a list with valid entries
        exe Xgetexpr . " ['Xtestfile1:1:3:Line1', 'Xtestfile2:2:2:Line2',
                  \ 'Xtestfile3:3:1:Line3']"

        " Open the window
        exe Xwindow
        call assert_true(winnr('$') == 2 && winnr() == 2 &&
        \ getline('.') ==# 'Xtestfile1|1 col 3| Line1')

        " Close the window
        exe Xclose
        call assert_true(winnr('$') == 1)

        " Create a list with no valid entries
        exe Xgetexpr . " ['non-error 1', 'non-error 2', 'non-error 3']"

        " Open the window
        exe Xopen . ' 5'
        call assert_true(winnr('$') == 2 && getline('.') ==# '|| non-error 1'
                      \  && winheight('.') == 5)

        " Opening the window again, should move the cursor to that window
        wincmd t
        exe Xopen . ' 7'
        call assert_true(winnr('$') == 2 && winnr() == 2 &&
        \ winheight('.') == 7 &&
        \ getline('.') ==# '|| non-error 1')


        " Calling cwindow should close the quickfix window with no valid errors
        exe Xwindow
        call assert_true(winnr('$') == 1)
      endfunction

      " Tests for the :cfile, :lfile, :caddfile, :laddfile, :cgetfile and :lgetfile
      " commands.
      function XfileTests(cchar)
        let Xfile = a:cchar . 'file'
        let Xgetfile = a:cchar . 'getfile'
        let Xaddfile = a:cchar . 'addfile'
        if a:cchar == 'c'
          let Xgetlist = 'getqflist()'
        else
          let Xgetlist = 'getloclist(0)'
        endif

        call writefile(['Xtestfile1:700:10:Line 700',
        \ 'Xtestfile2:800:15:Line 800'], 'Xqftestfile1')

        enew!
        exe Xfile . ' Xqftestfile1'
        exe 'let l = ' . Xgetlist
        call assert_true(len(l) == 2 &&
        \ l[0].lnum == 700 && l[0].col == 10 && l[0].text ==# 'Line 700' &&
        \ l[1].lnum == 800 && l[1].col == 15 && l[1].text ==# 'Line 800')

        " Run cfile/lfile from a modified buffer
        enew!
        silent! put ='Quickfix'
        exe 'silent! ' . Xfile . ' Xqftestfile1'
        call assert_true(v:errmsg ==# 'E37: No write since last change (add ! to override)')

        call writefile(['Xtestfile3:900:30:Line 900'], 'Xqftestfile1')
        exe Xaddfile . ' Xqftestfile1'
        exe 'let l = ' . Xgetlist
        call assert_true(len(l) == 3 &&
        \ l[2].lnum == 900 && l[2].col == 30 && l[2].text ==# 'Line 900')

        call writefile(['Xtestfile1:222:77:Line 222',
        \ 'Xtestfile2:333:88:Line 333'], 'Xqftestfile1')

        enew!
        exe Xgetfile . ' Xqftestfile1'
        exe 'let l = ' . Xgetlist
        call assert_true(len(l) == 2 &&
        \ l[0].lnum == 222 && l[0].col == 77 && l[0].text ==# 'Line 222' &&
        \ l[1].lnum == 333 && l[1].col == 88 && l[1].text ==# 'Line 333')

        call delete('Xqftestfile1')
      endfunction

      " Tests for the :cbuffer, :lbuffer, :caddbuffer, :laddbuffer, :cgetbuffer and
      " :lgetbuffer commands.
      function XbufferTests(cchar)
        let Xbuffer = a:cchar . 'buffer'
        let Xgetbuffer = a:cchar . 'getbuffer'
        let Xaddbuffer = a:cchar . 'addbuffer'
        if a:cchar == 'c'
          let Xgetlist = 'getqflist()'
        else
          let Xgetlist = 'getloclist(0)'
        endif

        enew!
        silent! call setline(1, ['Xtestfile7:700:10:Line 700',
        \ 'Xtestfile8:800:15:Line 800'])
        exe Xbuffer . "!"
        exe 'let l = ' . Xgetlist
        call assert_true(len(l) == 2 &&
        \ l[0].lnum == 700 && l[0].col == 10 && l[0].text ==# 'Line 700' &&
        \ l[1].lnum == 800 && l[1].col == 15 && l[1].text ==# 'Line 800')

        enew!
        silent! call setline(1, ['Xtestfile9:900:55:Line 900',
        \ 'Xtestfile10:950:66:Line 950'])
        exe Xgetbuffer
        exe 'let l = ' . Xgetlist
        call assert_true(len(l) == 2 &&
        \ l[0].lnum == 900 && l[0].col == 55 && l[0].text ==# 'Line 900' &&
        \ l[1].lnum == 950 && l[1].col == 66 && l[1].text ==# 'Line 950')

        enew!
        silent! call setline(1, ['Xtestfile11:700:20:Line 700',
        \ 'Xtestfile12:750:25:Line 750'])
        exe Xaddbuffer
        exe 'let l = ' . Xgetlist
        call assert_true(len(l) == 4 &&
        \ l[1].lnum == 950 && l[1].col == 66 && l[1].text ==# 'Line 950' &&
        \ l[2].lnum == 700 && l[2].col == 20 && l[2].text ==# 'Line 700' &&
        \ l[3].lnum == 750 && l[3].col == 25 && l[3].text ==# 'Line 750')

      endfunction
      ]])
  end)

  it('copen/cclose work', function()
    source([[
      helpgrep quickfix
      copen
      " This wipes out the buffer, make sure that doesn't cause trouble.
      cclose
    ]])
  end)

  it('clist/llist work', function()
    call('XlistTests', 'c')
    expected_empty()
    call('XlistTests', 'l')
    expected_empty()
  end)

  it('colder/cnewer and lolder/lnewer work', function()
    local list = {{bufnr = 1, lnum = 1}}
    call('setqflist', list)
    call('XageTests', 'c')
    expected_empty()

    call('setloclist', 0, list)
    call('XageTests', 'l')
    expected_empty()
  end)

  it('quickfix/location list window commands work', function()
    call('XwindowTests', 'c')
    expected_empty()
    call('XwindowTests', 'l')
    expected_empty()
  end)

  it('quickfix/location list file commands work', function()
    call('XfileTests', 'c')
    expected_empty()
    call('XfileTests', 'l')
    expected_empty()
  end)

  it('quickfix/location list buffer commands work', function()
    call('XbufferTests', 'c')
    expected_empty()
    call('XbufferTests', 'l')
    expected_empty()
  end)

  it('autocommands triggered by quickfix can get title', function()
    execute('au FileType qf let g:foo = get(w:, "quickfix_title", "NONE")')
    execute('call setqflist([])')
    execute('copen')
    eq(':setqflist()', eval('g:foo'))
  end)
end)
