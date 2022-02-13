" Tests for the :cdo, :cfdo, :ldo and :lfdo commands

if !has('quickfix')
  throw 'Skipped: quickfix feature missing'
endif

" Create the files used by the tests
function SetUp()
  call writefile(["Line1", "Line2", "Line3"], 'Xtestfile1')
  call writefile(["Line1", "Line2", "Line3"], 'Xtestfile2')
  call writefile(["Line1", "Line2", "Line3"], 'Xtestfile3')
endfunction

" Remove the files used by the tests
function TearDown()
  call delete('Xtestfile1')
  call delete('Xtestfile2')
  call delete('Xtestfile3')
endfunction

" Returns the current line in '<filename> <linenum>L <column>C' format
function GetRuler()
  return expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C'
endfunction

" Tests for the :cdo and :ldo commands
function XdoTests(cchar)
  enew

  " Shortcuts for calling the cdo and ldo commands
  let Xdo = a:cchar . 'do'
  let Xgetexpr = a:cchar . 'getexpr'
  let Xprev = a:cchar. 'prev'
  let XdoCmd = Xdo . ' call add(l, GetRuler())'

  " Try with an empty list
  let l = []
  exe XdoCmd
  call assert_equal([], l)

  " Populate the list and then try
  exe Xgetexpr . " ['non-error 1', 'Xtestfile1:1:3:Line1', 'non-error 2', 'Xtestfile2:2:2:Line2', 'non-error 3', 'Xtestfile3:3:1:Line3']"

  let l = []
  exe XdoCmd
  call assert_equal(['Xtestfile1 1L 3C', 'Xtestfile2 2L 2C', 'Xtestfile3 3L 1C'], l)

  " Run command only on selected error lines
  let l = []
  enew
  exe "2,3" . XdoCmd
  call assert_equal(['Xtestfile2 2L 2C', 'Xtestfile3 3L 1C'], l)

  " Boundary condition tests
  let l = []
  enew
  exe "1,1" . XdoCmd
  call assert_equal(['Xtestfile1 1L 3C'], l)

  let l = []
  enew
  exe "3" . XdoCmd
  call assert_equal(['Xtestfile3 3L 1C'], l)

  " Range test commands
  let l = []
  enew
  exe "%" . XdoCmd
  call assert_equal(['Xtestfile1 1L 3C', 'Xtestfile2 2L 2C', 'Xtestfile3 3L 1C'], l)

  let l = []
  enew
  exe "1,$" . XdoCmd
  call assert_equal(['Xtestfile1 1L 3C', 'Xtestfile2 2L 2C', 'Xtestfile3 3L 1C'], l)

  let l = []
  enew
  exe Xprev
  exe "." . XdoCmd
  call assert_equal(['Xtestfile2 2L 2C'], l)

  let l = []
  enew
  exe "+" . XdoCmd
  call assert_equal(['Xtestfile3 3L 1C'], l)

  " Invalid error lines test
  let l = []
  enew
  exe "silent! 27" . XdoCmd
  exe "silent! 4,5" . XdoCmd
  call assert_equal([], l)

  " Run commands from an unsaved buffer
  let v:errmsg=''
  let l = []
  enew
  setlocal modified
  exe "silent! 2,2" . XdoCmd
  if v:errmsg !~# 'No write since last change'
    call add(v:errors, 'Unsaved file change test failed')
  endif

  " If the executed command fails, then the operation should be aborted
  enew!
  let subst_count = 0
  exe "silent!" . Xdo . " s/Line/xLine/ | let subst_count += 1"
  if subst_count != 1 || getline('.') != 'xLine1'
    call add(v:errors, 'Abort command on error test failed')
  endif

  let l = []
  exe "2,2" . Xdo . "! call add(l, GetRuler())"
  call assert_equal(['Xtestfile2 2L 2C'], l)

  " List with no valid error entries
  let l = []
  edit! +2 Xtestfile1
  exe Xgetexpr . " ['non-error 1', 'non-error 2', 'non-error 3']"
  exe XdoCmd
  call assert_equal([], l)
  exe "silent! 2" . XdoCmd
  call assert_equal([], l)
  let v:errmsg=''
  exe "%" . XdoCmd
  exe "1,$" . XdoCmd
  exe "." . XdoCmd
  call assert_equal('', v:errmsg)

  " List with only one valid entry
  let l = []
  exe Xgetexpr . " ['Xtestfile3:3:1:Line3']"
  exe XdoCmd
  call assert_equal(['Xtestfile3 3L 1C'], l)

endfunction

" Tests for the :cfdo and :lfdo commands
function XfdoTests(cchar)
  enew

  " Shortcuts for calling the cfdo and lfdo commands
  let Xfdo = a:cchar . 'fdo'
  let Xgetexpr = a:cchar . 'getexpr'
  let XfdoCmd = Xfdo . ' call add(l, GetRuler())'
  let Xpfile = a:cchar. 'pfile'

  " Clear the quickfix/location list
  exe Xgetexpr . " []"

  " Try with an empty list
  let l = []
  exe XfdoCmd
  call assert_equal([], l)

  " Populate the list and then try
  exe Xgetexpr . " ['non-error 1', 'Xtestfile1:1:3:Line1', 'Xtestfile1:2:1:Line2', 'non-error 2', 'Xtestfile2:2:2:Line2', 'non-error 3', 'Xtestfile3:2:3:Line2', 'Xtestfile3:3:1:Line3']"

  let l = []
  exe XfdoCmd
  call assert_equal(['Xtestfile1 1L 3C', 'Xtestfile2 2L 2C', 'Xtestfile3 2L 3C'], l)

  " Run command only on selected error lines
  let l = []
  exe "2,3" . XfdoCmd
  call assert_equal(['Xtestfile2 2L 2C', 'Xtestfile3 2L 3C'], l)

  " Boundary condition tests
  let l = []
  exe "3" . XfdoCmd
  call assert_equal(['Xtestfile3 2L 3C'], l)

  " Range test commands
  let l = []
  exe "%" . XfdoCmd
  call assert_equal(['Xtestfile1 1L 3C', 'Xtestfile2 2L 2C', 'Xtestfile3 2L 3C'], l)

  let l = []
  exe "1,$" . XfdoCmd
  call assert_equal(['Xtestfile1 1L 3C', 'Xtestfile2 2L 2C', 'Xtestfile3 2L 3C'], l)

  let l = []
  exe Xpfile
  exe "." . XfdoCmd
  call assert_equal(['Xtestfile2 2L 2C'], l)

  " List with only one valid entry
  let l = []
  exe Xgetexpr . " ['Xtestfile2:2:5:Line2']"
  exe XfdoCmd
  call assert_equal(['Xtestfile2 2L 5C'], l)

endfunction

" Tests for cdo and cfdo
function Test_cdo()
  call XdoTests('c')
  call XfdoTests('c')
endfunction

" Tests for ldo and lfdo
function Test_ldo()
  call XdoTests('l')
  call XfdoTests('l')
endfunction
