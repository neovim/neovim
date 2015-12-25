-- Tests for the :cdo, :cfdo, :ldo and :lfdo commands

local helpers = require('test.functional.helpers')
local feed, insert, source = helpers.feed, helpers.insert, helpers.source
local clear, execute, expect = helpers.clear, helpers.execute, helpers.expect

describe('cdo', function()
  before_each(function()
    clear()

    execute([[call writefile(["Line1", "Line2", "Line3"], 'Xtestfile1')]])
    execute([[call writefile(["Line1", "Line2", "Line3"], 'Xtestfile2')]])
    execute([[call writefile(["Line1", "Line2", "Line3"], 'Xtestfile3')]])

    source([=[
      :function RunTests(cchar)
      :  let result=''
      :  let nl="\n"

      :  enew
      :  " Try with an empty list
      :  exe a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"

      :  " Populate the list and then try
      :  exe a:cchar . "getexpr ['non-error 1', 'Xtestfile1:1:3:Line1', 'non-error 2', 'Xtestfile2:2:2:Line2', 'non-error 3', 'Xtestfile3:3:1:Line3']"
      :  exe a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"

      :  " Run command only on selected error lines
      :  enew
      :  exe "2,3" . a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  " Boundary condition tests
      :  enew
      :  exe "1,1" . a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  enew
      :  exe "3" . a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  " Range test commands
      :  enew
      :  exe "%" . a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  enew
      :  exe "1,$" . a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  enew
      :  exe a:cchar . 'prev'
      :  exe "." . a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  " Invalid error lines test
      :  enew
      :  exe "27" . a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  exe "4,5" . a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"

      :  " Run commands from an unsaved buffer
      :  let v:errmsg=''
      :  enew
      :  setlocal modified
      :  exe "2,2" . a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  if v:errmsg =~# 'No write since last change'
      :     let result .= 'Unsaved file change test passed' . nl
      :  else
      :     let result .= 'Unsaved file change test failed' . nl
      :  endif

      :  " If the executed command fails, then the operation should be aborted
      :  enew!
      :  let subst_count = 0
      :  exe a:cchar . "do s/Line/xLine/ | let subst_count += 1"
      :  if subst_count == 1 && getline('.') == 'xLine1'
      :     let result .= 'Abort command on error test passed' . nl
      :  else
      :     let result .= 'Abort command on error test failed' . nl
      :  endif

      :  exe "2,2" . a:cchar . "do! let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"

      :  " List with no valid error entries
      :  edit! +2 Xtestfile1
      :  exe a:cchar . "getexpr ['non-error 1', 'non-error 2', 'non-error 3']"
      :  exe a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  exe "2" . a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  let v:errmsg=''
      :  exe "%" . a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  exe "1,$" . a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  exe "." . a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  let result .= v:errmsg

      :  " List with only one valid entry
      :  exe a:cchar . "getexpr ['Xtestfile3:3:1:Line3']"
      :  exe a:cchar . "do let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"

      :  " Tests for :cfdo and :lfdo commands
      :  exe a:cchar . "getexpr ['non-error 1', 'Xtestfile1:1:3:Line1', 'Xtestfile1:2:1:Line2', 'non-error 2', 'Xtestfile2:2:2:Line2', 'non-error 3', 'Xtestfile3:2:3:Line2', 'Xtestfile3:3:1:Line3']"
      :  exe a:cchar . "fdo let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  exe "3" . a:cchar . "fdo let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  exe "2,3" . a:cchar . "fdo let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  exe "%" . a:cchar . "fdo let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  exe "1,$" . a:cchar . "fdo let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"
      :  exe a:cchar . 'pfile'
      :  exe "." . a:cchar . "fdo let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"

      :  " List with only one valid entry
      :  exe a:cchar . "getexpr ['Xtestfile2:2:5:Line2']"
      :  exe a:cchar . "fdo let result .= expand('%') . ' ' . line('.') . 'L' . ' ' . col('.') . 'C' . nl"

      :  " Show results in buffer
      :  enew!
      :  0put=result
      :endfunction
    ]=])
  end)

  after_each(function()
    os.remove('Xtestfile1')
    os.remove('Xtestfile2')
    os.remove('Xtestfile3')
  end)

  it('works for :cdo', function()
    execute("call RunTests('c')")

    -- Assert buffer contents.
    expect([[
      Xtestfile1 1L 3C
      Xtestfile2 2L 2C
      Xtestfile3 3L 1C
      Xtestfile2 2L 2C
      Xtestfile3 3L 1C
      Xtestfile1 1L 3C
      Xtestfile3 3L 1C
      Xtestfile1 1L 3C
      Xtestfile2 2L 2C
      Xtestfile3 3L 1C
      Xtestfile1 1L 3C
      Xtestfile2 2L 2C
      Xtestfile3 3L 1C
      Xtestfile2 2L 2C
      Unsaved file change test passed
      Abort command on error test passed
      Xtestfile2 2L 2C
      Xtestfile3 3L 1C
      Xtestfile1 1L 3C
      Xtestfile2 2L 2C
      Xtestfile3 2L 3C
      Xtestfile3 2L 3C
      Xtestfile2 2L 2C
      Xtestfile3 2L 3C
      Xtestfile1 1L 3C
      Xtestfile2 2L 2C
      Xtestfile3 2L 3C
      Xtestfile1 1L 3C
      Xtestfile2 2L 2C
      Xtestfile3 2L 3C
      Xtestfile2 2L 2C
      Xtestfile2 2L 5C
      ]])
  end)

  it('works for :ldo', function()
    execute("call RunTests('c')")

    -- Assert buffer contents.
    expect([[
      Xtestfile1 1L 3C
      Xtestfile2 2L 2C
      Xtestfile3 3L 1C
      Xtestfile2 2L 2C
      Xtestfile3 3L 1C
      Xtestfile1 1L 3C
      Xtestfile3 3L 1C
      Xtestfile1 1L 3C
      Xtestfile2 2L 2C
      Xtestfile3 3L 1C
      Xtestfile1 1L 3C
      Xtestfile2 2L 2C
      Xtestfile3 3L 1C
      Xtestfile2 2L 2C
      Unsaved file change test passed
      Abort command on error test passed
      Xtestfile2 2L 2C
      Xtestfile3 3L 1C
      Xtestfile1 1L 3C
      Xtestfile2 2L 2C
      Xtestfile3 2L 3C
      Xtestfile3 2L 3C
      Xtestfile2 2L 2C
      Xtestfile3 2L 3C
      Xtestfile1 1L 3C
      Xtestfile2 2L 2C
      Xtestfile3 2L 3C
      Xtestfile1 1L 3C
      Xtestfile2 2L 2C
      Xtestfile3 2L 3C
      Xtestfile2 2L 2C
      Xtestfile2 2L 5C
      ]])
  end)
end)
