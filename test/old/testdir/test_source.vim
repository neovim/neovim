" Tests for the :source command.

source check.vim
source view_util.vim

func Test_source_autocmd()
  call writefile([
	\ 'let did_source = 1',
	\ ], 'Xsourced')
  au SourcePre *source* let did_source_pre = 1
  au SourcePost *source* let did_source_post = 1

  source Xsourced

  call assert_equal(g:did_source, 1)
  call assert_equal(g:did_source_pre, 1)
  call assert_equal(g:did_source_post, 1)

  call delete('Xsourced')
  au! SourcePre
  au! SourcePost
  unlet g:did_source
  unlet g:did_source_pre
  unlet g:did_source_post
endfunc

func Test_source_cmd()
  au SourceCmd *source* let did_source = expand('<afile>')
  au SourcePre *source* let did_source_pre = 2
  au SourcePost *source* let did_source_post = 2

  source Xsourced

  call assert_equal(g:did_source, 'Xsourced')
  call assert_false(exists('g:did_source_pre'))
  call assert_equal(g:did_source_post, 2)

  au! SourceCmd
  au! SourcePre
  au! SourcePost
endfunc

func Test_source_sandbox()
  new
  call writefile(["Ohello\<Esc>"], 'Xsourcehello')
  source! Xsourcehello | echo
  call assert_equal('hello', getline(1))
  call assert_fails('sandbox source! Xsourcehello', 'E48:')
  bwipe!
  call delete('Xsourcehello')
endfunc

" When deleting a file and immediately creating a new one the inode may be
" recycled.  Vim should not recognize it as the same script.
func Test_different_script()
  call writefile(['let s:var = "asdf"'], 'XoneScript', 'D')
  source XoneScript
  call writefile(['let g:var = s:var'], 'XtwoScript', 'D')
  call assert_fails('source XtwoScript', 'E121:')
endfunc

" When sourcing a vim script, shebang should be ignored.
func Test_source_ignore_shebang()
  call writefile(['#!./xyzabc', 'let g:val=369'], 'Xfile.vim')
  source Xfile.vim
  call assert_equal(g:val, 369)
  call delete('Xfile.vim')
endfunc

" Test for expanding <sfile> in a autocmd and for <slnum> and <sflnum>
func Test_source_autocmd_sfile()
  let code =<< trim [CODE]
    let g:SfileName = ''
    augroup sfiletest
      au!
      autocmd User UserAutoCmd let g:Sfile = '<sfile>:t'
    augroup END
    doautocmd User UserAutoCmd
    let g:Slnum = expand('<slnum>')
    let g:Sflnum = expand('<sflnum>')
    augroup! sfiletest
  [CODE]
  call writefile(code, 'Xscript.vim')
  source Xscript.vim
  call assert_equal('Xscript.vim', g:Sfile)
  call assert_equal('7', g:Slnum)
  call assert_equal('8', g:Sflnum)
  call delete('Xscript.vim')
endfunc

func Test_source_error()
  call assert_fails('scriptencoding utf-8', 'E167:')
  call assert_fails('finish', 'E168:')
  " call assert_fails('scriptversion 2', 'E984:')
  call assert_fails('source!', 'E471:')
  new
  call setline(1, ['', '', '', ''])
  call assert_fails('1,3source Xscript.vim', 'E481:')
  call assert_fails('1,3source! Xscript.vim', 'E481:')
  bw!
endfunc

" Test for sourcing a script recursively
func Test_nested_script()
  CheckRunVimInTerminal
  call writefile([':source! Xscript.vim', ''], 'Xscript.vim')
  let buf = RunVimInTerminal('', {'rows': 6})
  call term_wait(buf)
  call term_sendkeys(buf, ":set noruler\n")
  call term_sendkeys(buf, ":source! Xscript.vim\n")
  call term_wait(buf)
  call WaitForAssert({-> assert_match('E22: Scripts nested too deep\s*', term_getline(buf, 6))})
  call delete('Xscript.vim')
  call StopVimInTerminal(buf)
endfunc

" Test for sourcing a script from the current buffer
func Test_source_buffer()
  new
  " Source a simple script
  let lines =<< trim END
    let a = "Test"
    let b = 20

    let c = [1.1]
  END
  call setline(1, lines)
  source
  call assert_equal(['Test', 20, [1.1]], [g:a, g:b, g:c])

  " Source a range of lines in the current buffer
  %d _
  let lines =<< trim END
    let a = 10
    let a += 20
    let a += 30
    let a += 40
  END
  call setline(1, lines)
  .source
  call assert_equal(10, g:a)
  3source
  call assert_equal(40, g:a)
  2,3source
  call assert_equal(90, g:a)

  " Make sure the script line number is correct when sourcing a range of
  " lines.
  %d _
  let lines =<< trim END
     Line 1
     Line 2
     func Xtestfunc()
       return expand("<sflnum>")
     endfunc
     Line 3
     Line 4
  END
  call setline(1, lines)
  3,5source
  call assert_equal('4', Xtestfunc())
  delfunc Xtestfunc

  " Source a script with line continuation lines
  %d _
  let lines =<< trim END
    let m = [
      \   1,
      \   2,
      \ ]
    call add(m, 3)
  END
  call setline(1, lines)
  source
  call assert_equal([1, 2, 3], g:m)
  " Source a script with line continuation lines and a comment
  %d _
  let lines =<< trim END
    let m = [
      "\ first entry
      \   'a',
      "\ second entry
      \   'b',
      \ ]
    " third entry
    call add(m, 'c')
  END
  call setline(1, lines)
  source
  call assert_equal(['a', 'b', 'c'], g:m)
  " Source an incomplete line continuation line
  %d _
  let lines =<< trim END
    let k = [
      \
  END
  call setline(1, lines)
  call assert_fails('source', 'E697:')
  " Source a function with a for loop
  %d _
  let lines =<< trim END
    let m = []
    " test function
    func! Xtest()
      for i in range(5, 7)
        call add(g:m, i)
      endfor
    endfunc
    call Xtest()
  END
  call setline(1, lines)
  source
  call assert_equal([5, 6, 7], g:m)
  " Source an empty buffer
  %d _
  source

  " test for script local functions and variables
  let lines =<< trim END
    let s:var1 = 10
    func s:F1()
      let s:var1 += 1
      return s:var1
    endfunc
    func s:F2()
    endfunc
    let g:ScriptID = expand("<SID>")
  END
  call setline(1, lines)
  source
  call assert_true(g:ScriptID != '')
  call assert_true(exists('*' .. g:ScriptID .. 'F1'))
  call assert_true(exists('*' .. g:ScriptID .. 'F2'))
  call assert_equal(11, call(g:ScriptID .. 'F1', []))

  " the same script ID should be used even if the buffer is sourced more than
  " once
  %d _
  let lines =<< trim END
    let g:ScriptID = expand("<SID>")
    let g:Count += 1
  END
  call setline(1, lines)
  let g:Count = 0
  source
  call assert_true(g:ScriptID != '')
  let scid = g:ScriptID
  source
  call assert_equal(scid, g:ScriptID)
  call assert_equal(2, g:Count)
  source
  call assert_equal(scid, g:ScriptID)
  call assert_equal(3, g:Count)

  " test for the script line number
  %d _
  let lines =<< trim END
    " comment
    let g:Slnum1 = expand("<slnum>")
    let i = 1 +
           \ 2 +
          "\ comment
           \ 3
    let g:Slnum2 = expand("<slnum>")
  END
  call setline(1, lines)
  source
  call assert_equal('2', g:Slnum1)
  call assert_equal('7', g:Slnum2)

  " test for retaining the same script number across source calls
  let lines =<< trim END
     let g:ScriptID1 = expand("<SID>")
     let g:Slnum1 = expand("<slnum>")
     let l =<< trim END
       let g:Slnum2 = expand("<slnum>")
       let g:ScriptID2 = expand("<SID>")
     END
     new
     call setline(1, l)
     source
     bw!
     let g:ScriptID3 = expand("<SID>")
     let g:Slnum3 = expand("<slnum>")
  END
  call writefile(lines, 'Xscript')
  source Xscript
  call assert_true(g:ScriptID1 != g:ScriptID2)
  call assert_equal(g:ScriptID1, g:ScriptID3)
  call assert_equal('2', g:Slnum1)
  call assert_equal('1', g:Slnum2)
  call assert_equal('12', g:Slnum3)
  call delete('Xscript')

  " test for sourcing a heredoc
  %d _
  let lines =<< trim END
     let a = 1
     let heredoc =<< trim DATA
        red
          green
        blue
     DATA
     let b = 2
  END
  call setline(1, lines)
  source
  call assert_equal(['red', '  green', 'blue'], g:heredoc)

  " test for a while and for statement
  %d _
  let lines =<< trim END
     let a = 0
     let b = 1
     while b <= 10
       let a += 10
       let b += 1
     endwhile
     for i in range(5)
       let a += 10
     endfor
  END
  call setline(1, lines)
  source
  call assert_equal(150, g:a)

  " test for sourcing the same buffer multiple times after changing a function
  %d _
  let lines =<< trim END
     func Xtestfunc()
       return "one"
     endfunc
  END
  call setline(1, lines)
  source
  call assert_equal("one", Xtestfunc())
  call setline(2, '  return "two"')
  source
  call assert_equal("two", Xtestfunc())
  call setline(2, '  return "three"')
  source
  call assert_equal("three", Xtestfunc())
  delfunc Xtestfunc

  " test for using try/catch
  %d _
  let lines =<< trim END
     let Trace = '1'
     try
       let a1 = b1
     catch
       let Trace ..= '2'
     finally
       let Trace ..= '3'
     endtry
  END
  call setline(1, lines)
  source
  call assert_equal("123", g:Trace)

  " test with the finish command
  %d _
  let lines =<< trim END
     let g:Color = 'blue'
     finish
     let g:Color = 'green'
  END
  call setline(1, lines)
  source
  call assert_equal('blue', g:Color)

  " Test for the SourcePre and SourcePost autocmds
  augroup Xtest
    au!
    au SourcePre * let g:XsourcePre=4
          \ | let g:XsourcePreFile = expand("<afile>")
    au SourcePost * let g:XsourcePost=6
          \ | let g:XsourcePostFile = expand("<afile>")
  augroup END
  %d _
  let lines =<< trim END
     let a = 1
  END
  call setline(1, lines)
  source
  call assert_equal(4, g:XsourcePre)
  call assert_equal(6, g:XsourcePost)
  call assert_equal(':source buffer=' .. bufnr(), g:XsourcePreFile)
  call assert_equal(':source buffer=' .. bufnr(), g:XsourcePostFile)
  augroup Xtest
    au!
  augroup END
  augroup! Xtest

  %bw!
endfunc

" Test for sourcing a Vim9 script from the current buffer
func Test_source_buffer_vim9()
  throw 'Skipped: Vim9 script is N/A'
  new

  " test for sourcing a Vim9 script
  %d _
  let lines =<< trim END
     vim9script

     # check dict
     var x: number = 10
     def g:Xtestfunc(): number
       return x
     enddef
  END
  call setline(1, lines)
  source
  call assert_equal(10, Xtestfunc())

  " test for sourcing a vim9 script with line continuation
  %d _
  let lines =<< trim END
     vim9script

     g:Str1 = "hello "
              .. "world"
              .. ", how are you?"
     g:Colors = [
       'red',
       # comment
       'blue'
       ]
     g:Dict = {
       a: 22,
       # comment
       b: 33
       }

     # calling a function with line continuation
     def Sum(...values: list<number>): number
       var sum: number = 0
       for v in values
         sum += v
       endfor
       return sum
     enddef
     g:Total1 = Sum(10,
                   20,
                   30)

     var i: number = 0
     while i < 10
       # while loop
       i +=
           1
     endwhile
     g:Count1 = i

     # for loop
     g:Count2 = 0
     for j in range(10, 20)
       g:Count2 +=
           i
     endfor

     g:Total2 = 10 +
                20 -
                5

     g:Result1 = g:Total2 > 1
                ? 'red'
                : 'blue'

     g:Str2 = 'x'
              ->repeat(10)
              ->trim()
              ->strpart(4)

     g:Result2 = g:Dict
                    .a

     augroup Test
       au!
       au BufNewFile Xfile g:readFile = 1
             | g:readExtra = 2
     augroup END
     g:readFile = 0
     g:readExtra = 0
     new Xfile
     bwipe!
     augroup Test
       au!
     augroup END
  END
  call setline(1, lines)
  source
  call assert_equal("hello world, how are you?", g:Str1)
  call assert_equal(['red', 'blue'], g:Colors)
  call assert_equal(#{a: 22, b: 33}, g:Dict)
  call assert_equal(60, g:Total1)
  call assert_equal(10, g:Count1)
  call assert_equal(110, g:Count2)
  call assert_equal(25, g:Total2)
  call assert_equal('red', g:Result1)
  call assert_equal('xxxxxx', g:Str2)
  call assert_equal(22, g:Result2)
  call assert_equal(1, g:readFile)
  call assert_equal(2, g:readExtra)

  " test for sourcing the same buffer multiple times after changing a function
  %d _
  let lines =<< trim END
     vim9script
     def g:Xtestfunc(): string
       return "one"
     enddef
  END
  call setline(1, lines)
  source
  call assert_equal("one", Xtestfunc())
  call setline(3, '  return "two"')
  source
  call assert_equal("two", Xtestfunc())
  call setline(3, '  return "three"')
  source
  call assert_equal("three", Xtestfunc())
  delfunc Xtestfunc

  " Test for sourcing a range of lines. Make sure the script line number is
  " correct.
  %d _
  let lines =<< trim END
     Line 1
     Line 2
     vim9script
     def g:Xtestfunc(): string
       return expand("<sflnum>")
     enddef
     Line 3
     Line 4
  END
  call setline(1, lines)
  3,6source
  call assert_equal('5', Xtestfunc())
  delfunc Xtestfunc

  " test for sourcing a heredoc
  %d _
  let lines =<< trim END
    vim9script
    var a = 1
    g:heredoc =<< trim DATA
       red
         green
       blue
    DATA
    var b = 2
  END
  call setline(1, lines)
  source
  call assert_equal(['red', '  green', 'blue'], g:heredoc)

  " test for using the :vim9cmd modifier
  %d _
  let lines =<< trim END
    first line
    g:Math = {
         pi: 3.12,
         e: 2.71828
      }
    g:Editors = [
      'vim',
      # comment
      'nano'
      ]
    last line
  END
  call setline(1, lines)
  vim9cmd :2,10source
  call assert_equal(#{pi: 3.12, e: 2.71828}, g:Math)
  call assert_equal(['vim', 'nano'], g:Editors)

  " test for using try/catch
  %d _
  let lines =<< trim END
     vim9script
     g:Trace = '1'
     try
       a1 = b1
     catch
       g:Trace ..= '2'
     finally
       g:Trace ..= '3'
     endtry
  END
  call setline(1, lines)
  source
  call assert_equal('123', g:Trace)

  " test with the finish command
  %d _
  let lines =<< trim END
     vim9script
     g:Color = 'red'
     finish
     g:Color = 'blue'
  END
  call setline(1, lines)
  source
  call assert_equal('red', g:Color)

  " test for ++clear argument to clear all the functions/variables
  %d _
  let lines =<< trim END
     g:ScriptVarFound = exists("color")
     g:MyFuncFound = exists('*Myfunc')
     if g:MyFuncFound
       finish
     endif
     var color = 'blue'
     def Myfunc()
     enddef
  END
  call setline(1, lines)
  vim9cmd source
  call assert_false(g:MyFuncFound)
  call assert_false(g:ScriptVarFound)
  vim9cmd source
  call assert_true(g:MyFuncFound)
  call assert_true(g:ScriptVarFound)
  vim9cmd source ++clear
  call assert_false(g:MyFuncFound)
  call assert_false(g:ScriptVarFound)
  vim9cmd source ++clear
  call assert_false(g:MyFuncFound)
  call assert_false(g:ScriptVarFound)
  call assert_fails('vim9cmd source ++clearx', 'E475:')
  call assert_fails('vim9cmd source ++abcde', 'E484:')

  %bw!
endfunc

func Test_source_buffer_long_line()
  " This was reading past the end of the line.
  new
  norm300gr0
  so
  bwipe!

  let lines =<< trim END
      new
      norm 10a0000000000ø00000000000
      norm i0000000000000000000
      silent! so
  END
  call writefile(lines, 'Xtest.vim')
  source Xtest.vim
  bwipe!
  call delete('Xtest.vim')
endfunc


" vim: shiftwidth=2 sts=2 expandtab
