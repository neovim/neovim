" Test for getstacktrace() and v:stacktrace

source vim9.vim

let s:thisfile = expand('%:p')
let s:testdir = s:thisfile->fnamemodify(':h')

func Filepath(name)
  return s:testdir .. '/' .. a:name
endfunc

func AssertStacktrace(expect, actual)
  call assert_equal(Filepath('runtest.vim'), a:actual[0]['filepath'])
  call assert_equal(a:expect, a:actual[-len(a:expect):])
endfunc

func Test_getstacktrace()
  let g:stacktrace = []
  let lines1 =<< trim [SCRIPT]
  " Xscript1
  source Xscript2
  func Xfunc1()
    " Xfunc1
    call Xfunc2()
  endfunc
  [SCRIPT]
  let lines2 =<< trim [SCRIPT]
  " Xscript2
  func Xfunc2()
    " Xfunc2
    let g:stacktrace = getstacktrace()
  endfunc
  [SCRIPT]
  call writefile(lines1, 'Xscript1', 'D')
  call writefile(lines2, 'Xscript2', 'D')
  source Xscript1
  call Xfunc1()
  call AssertStacktrace([
        \ #{funcref: funcref('Test_getstacktrace'), lnum: 37, filepath: s:thisfile},
        \ #{funcref: funcref('Xfunc1'), lnum: 5, filepath: Filepath('Xscript1')},
        \ #{funcref: funcref('Xfunc2'), lnum: 4, filepath: Filepath('Xscript2')},
        \ ], g:stacktrace)
  unlet g:stacktrace
endfunc

func Test_getstacktrace_event()
  let g:stacktrace = []
  let lines1 =<< trim [SCRIPT]
  " Xscript1
  func Xfunc()
    " Xfunc
    let g:stacktrace = getstacktrace()
  endfunc
  augroup test_stacktrace
    autocmd SourcePre * call Xfunc()
  augroup END
  [SCRIPT]
  let lines2 =<< trim [SCRIPT]
  " Xscript2
  [SCRIPT]
  call writefile(lines1, 'Xscript1', 'D')
  call writefile(lines2, 'Xscript2', 'D')
  source Xscript1
  source Xscript2
  call AssertStacktrace([
       \ #{funcref: funcref('Test_getstacktrace_event'), lnum: 64, filepath: s:thisfile},
       \ #{event: 'SourcePre Autocommands for "*"', lnum: 7, filepath: Filepath('Xscript1')},
       \ #{funcref: funcref('Xfunc'), lnum: 4, filepath: Filepath('Xscript1')},
       \ ], g:stacktrace)
  augroup test_stacktrace
    autocmd!
  augroup END
  unlet g:stacktrace
endfunc

func Test_vstacktrace()
  let lines1 =<< trim [SCRIPT]
  " Xscript1
  source Xscript2
  func Xfunc1()
    " Xfunc1
    call Xfunc2()
  endfunc
  [SCRIPT]
  let lines2 =<< trim [SCRIPT]
  " Xscript2
  func Xfunc2()
    " Xfunc2
    throw 'Exception from Xfunc2'
  endfunc
  [SCRIPT]
  call writefile(lines1, 'Xscript1', 'D')
  call writefile(lines2, 'Xscript2', 'D')
  source Xscript1
  call assert_equal([], v:stacktrace)
  try
    call Xfunc1()
  catch
    let stacktrace = v:stacktrace
    try
      call Xfunc1()
    catch
      let stacktrace_inner = v:stacktrace
    endtry
    let stacktrace_after = v:stacktrace " should be restored by the exception stack to the previous one
  endtry
  call assert_equal([], v:stacktrace)
  call AssertStacktrace([
       \ #{funcref: funcref('Test_vstacktrace'), lnum: 97, filepath: s:thisfile},
       \ #{funcref: funcref('Xfunc1'), lnum: 5, filepath: Filepath('Xscript1')},
       \ #{funcref: funcref('Xfunc2'), lnum: 4, filepath: Filepath('Xscript2')},
       \ ], stacktrace)
  call AssertStacktrace([
       \ #{funcref: funcref('Test_vstacktrace'), lnum: 101, filepath: s:thisfile},
       \ #{funcref: funcref('Xfunc1'), lnum: 5, filepath: Filepath('Xscript1')},
       \ #{funcref: funcref('Xfunc2'), lnum: 4, filepath: Filepath('Xscript2')},
       \ ], stacktrace_inner)
  call assert_equal(stacktrace, stacktrace_after)
endfunc

func Test_stacktrace_vim9()
  let lines =<< trim [SCRIPT]
  var stacktrace = getstacktrace()
  assert_notequal([], stacktrace)
  for d in stacktrace
    assert_true(has_key(d, 'lnum'))
  endfor
  try
    throw 'Exception from s:Func'
  catch
    assert_notequal([], v:stacktrace)
    assert_equal(len(stacktrace), len(v:stacktrace))
    for d in v:stacktrace
      assert_true(has_key(d, 'lnum'))
    endfor
  endtry
  call assert_equal([], v:stacktrace)
  [SCRIPT]
  call CheckDefSuccess(lines)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
