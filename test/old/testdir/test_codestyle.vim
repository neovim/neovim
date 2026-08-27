" Test for checking the source code style.

func s:ReportError(fname, lnum, msg)
  if a:lnum > 0
    call assert_report(a:fname .. ' line ' .. a:lnum .. ': ' .. a:msg)
  endif
endfunc

func s:PerformCheck(fname, pattern, msg, skip)
  let prev_lnum = 1
  let lnum = 1
  while (lnum > 0)
    call cursor(lnum, 1)
    let lnum = search(a:pattern, 'W', 0, 0, a:skip)
    if (prev_lnum == lnum)
      break
    endif
    let prev_lnum = lnum
    if (lnum > 0)
      call s:ReportError(a:fname, lnum, a:msg)
    endif
  endwhile
endfunc

func Test_test_files()
  for fname in glob('*.vim', 0, 1)
    let g:ignoreSwapExists = 'e'
    exe 'edit ' .. fname

    " some files intentionally have misplaced white space
    if fname =~ 'test_cindent.vim' || fname =~ 'test_join.vim'
      continue
    endif

    " skip files that are known to have a space before a tab
    if fname !~ 'test_comments.vim'
          \ && fname !~ 'test_listchars.vim'
          \ && fname !~ 'test_visual.vim'
      call cursor(1, 1)
      let skip = 'getline(".") =~ "codestyle: ignore"'
      let lnum = search(fname =~ "test_regexp_latin" ? '[^á] \t' : ' \t', 'W', 0, 0, skip)
      call s:ReportError('testdir/' .. fname, lnum, 'space before Tab')
    endif

    " skip files that are known to have trailing white space
    if fname !~ 'test_cmdline.vim'
          \ && fname !~ 'test_let.vim'
          \ && fname !~ 'test_tagjump.vim'
          \ && fname !~ 'test_vim9_cmd.vim'
      call cursor(1, 1)
      let lnum = search(
            \ fname =~ 'test_vim9_assign.vim' ? '[^=]\s$'
            \ : fname =~ 'test_vim9_class.vim' ? '[^)]\s$'
            \ : fname =~ 'test_vim9_script.vim' ? '[^,:3]\s$'
            \ : fname =~ 'test_visual.vim' ? '[^/]\s$'
            \ : '[^\\]\s$')
      call s:ReportError('testdir/' .. fname, lnum, 'trailing white space')
    endif
  endfor

  bwipe!
endfunc

func Test_help_files()
  set nowrapscan

  for fpath in glob('../../../runtime/doc/*.txt', 0, 1)
    let g:ignoreSwapExists = 'e'
    exe 'edit ' .. fpath

    let fname = fnamemodify(fpath, ":t")

    " todo.txt is for developers, it's not need a strictly check
    " version*.txt is a history and large size, so it's not checked
    if fname == 'todo.txt' || fname =~ 'version.*\.txt'
      continue
    endif

    " Check for mixed tabs and spaces
    call cursor(1, 1)
    while 1
      let lnum = search('[^/] \t')
      if fname == 'visual.txt' && getline(lnum) =~ "STRING  \tjkl"
            \ || fname == 'usr_27.txt' && getline(lnum) =~ "\[^\? \t\]"
        continue
      endif
      call s:ReportError(fpath, lnum, 'space before tab')
      if lnum == 0
        break
      endif
    endwhile

    " Check for unnecessary whitespace at the end of a line
    call cursor(1, 1)
    while 1
      let lnum = search('\%([^/~\\]\|^\)\s\+$')
      " skip line that are known to have trailing white space
      if fname == 'map.txt' && getline(lnum) =~ "unmap @@ $"
            \ || fname == 'usr_12.txt' && getline(lnum) =~ "^\t/ \t$"
            \ || fname == 'usr_41.txt' && getline(lnum) =~ "map <F4> o#include  $"
            \ || fname == 'change.txt' && getline(lnum) =~ "foobar bla $"
        continue
      endif
      call s:ReportError('testdir' .. fpath, lnum, 'trailing white space')
      if lnum == 0
        break
      endif
    endwhile


  endfor

  set wrapscan&vim
  bwipe!
endfunc


func Test_runtime_wrong_shellescape()
  " Check that shellescape() is called with the {special} argument (a second,
  " non-zero argument) when its result is used in a ":!" ex command.
  " This could cause code injection!
  let pattern = '\<shellescape(\%([^,()]\|([^()]*)\)\+)'

  let q = "['" .. '"]'
  let bang_exe = '\<\%(exe\%[cute]\|sil\%[ent]\)\>.*' .. q .. '[^"' .. "']*!"

  let skip = 'getline(".") !~ ' .. string(bang_exe)
        \ .. ' || getline(".") =~ ' .. string('\<system\%(list\)\=(')
        \ .. ' || getline(".") =~ ' .. string('^\s*"')

  for fpath in glob('../../../runtime/**/*.vim', 0, 1)
    let g:ignoreSwapExists = 'e'
    exe 'edit ' .. fpath
    call s:PerformCheck(fpath, pattern,
          \ 'shellescape() without {special} flag used in ":!" command', skip)
  endfor

  :%bwipe!
endfunc

" vim: shiftwidth=2 sts=2 expandtab
