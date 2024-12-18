" Test for various indent options

source shared.vim
source check.vim

func Test_preserveindent()
  new
  " Test for autoindent copying indent from the previous line
  setlocal autoindent
  call setline(1, [repeat(' ', 16) .. 'line1'])
  call feedkeys("A\nline2", 'xt')
  call assert_equal("\t\tline2", getline(2))
  setlocal autoindent&

  " Test for using CTRL-T with and without 'preserveindent'
  set shiftwidth=4
  call cursor(1, 1)
  call setline(1, "    \t    ")
  call feedkeys("Al\<C-T>", 'xt')
  call assert_equal("\t\tl", getline(1))
  set preserveindent
  call setline(1, "    \t    ")
  call feedkeys("Al\<C-T>", 'xt')
  call assert_equal("    \t    \tl", getline(1))
  set pi& sw&

  " Test for using CTRL-T with 'expandtab' and 'preserveindent'
  call cursor(1, 1)
  call setline(1, "\t    \t")
  set shiftwidth=4 expandtab preserveindent
  call feedkeys("Al\<C-T>", 'xt')
  call assert_equal("\t    \t    l", getline(1))
  set sw& et& pi&

  close!
endfunc

" Test for indent()
func Test_indent_func()
  call assert_equal(-1, indent(-1))
  new
  call setline(1, "\tabc")
  call assert_equal(8, indent(1))
  call setline(1, "    abc")
  call assert_equal(4, indent(1))
  call setline(1, "    \t    abc")
  call assert_equal(12, indent(1))
  close!
endfunc

" Test for reindenting a line using the '=' operator
func Test_reindent()
  new
  call setline(1, 'abc')
  set nomodifiable
  call assert_fails('normal ==', 'E21:')
  set modifiable

  call setline(1, ['foo', 'bar'])
  call feedkeys('ggVG=', 'xt')
  call assert_equal(['foo', 'bar'], getline(1, 2))
  close!
endfunc

" Test indent operator creating one undo entry
func Test_indent_operator_undo()
  enew
  call setline(1, range(12)->map('"\t" .. v:val'))
  func FoldExpr()
    let g:foldcount += 1
    return '='
  endfunc
  set foldmethod=expr foldexpr=FoldExpr()
  let g:foldcount = 0
  redraw
  call assert_equal(12, g:foldcount)
  normal gg=G
  call assert_equal(24, g:foldcount)
  undo
  call assert_equal(38, g:foldcount)

  bwipe!
  set foldmethod& foldexpr=
  delfunc FoldExpr
  unlet g:foldcount
endfunc

" Test for shifting a line with a preprocessor directive ('#')
func Test_preproc_indent()
  new
  set sw=4
  call setline(1, '#define FOO 1')
  normal >>
  call assert_equal('    #define FOO 1', getline(1))

  " with 'smartindent'
  call setline(1, '#define FOO 1')
  set smartindent
  normal >>
  call assert_equal('#define FOO 1', getline(1))
  set smartindent&

  " with 'cindent'
  set cindent
  normal >>
  call assert_equal('#define FOO 1', getline(1))
  set cindent&

  close!
endfunc

" Test for 'copyindent'
func Test_copyindent()
  new
  set shiftwidth=4 autoindent expandtab copyindent
  call setline(1, "    \t    abc")
  call feedkeys("ol", 'xt')
  call assert_equal("    \t    l", getline(2))
  set noexpandtab
  call setline(1, "    \t    abc")
  call feedkeys("ol", 'xt')
  call assert_equal("    \t    l", getline(2))
  set sw& ai& et& ci&
  close!
endfunc

" Test for changing multiple lines with lisp indent
func Test_lisp_indent_change_multiline()
  new
  setlocal lisp autoindent
  call setline(1, ['(if a', '  (if b', '    (return 5)))'])
  normal! jc2j(return 4))
  call assert_equal('  (return 4))', getline(2))
  close!
endfunc

func Test_lisp_indent()
  new
  setlocal lisp autoindent
  call setline(1, ['(if a', '  ;; comment', '  \ abc', '', '  " str1\', '  " st\b', '  (return 5)'])
  normal! jo;; comment
  normal! jo\ abc
  normal! jo;; ret
  normal! jostr1"
  normal! jostr2"
  call assert_equal(['  ;; comment', '  ;; comment', '  \ abc', '  \ abc', '', '  ;; ret', '  " str1\', '  str1"', '  " st\b', '  str2"'], getline(2, 11))
  close!
endfunc

func Test_lisp_indent_quoted()
  " This was going past the end of the line
  new
  setlocal lisp autoindent
  call setline(1, ['"[', '='])
  normal Gvk=

  bwipe!
endfunc

" Test for setting the 'indentexpr' from a modeline
func Test_modeline_indent_expr()
  let modeline = &modeline
  set modeline
  func GetIndent()
    return line('.') * 2
  endfunc
  call writefile(['# vim: indentexpr=GetIndent()'], 'Xfile.txt')
  set modelineexpr
  new Xfile.txt
  call assert_equal('GetIndent()', &indentexpr)
  exe "normal Oa\nb\n"
  call assert_equal(['  a', '    b'], getline(1, 2))

  set modelineexpr&
  delfunc GetIndent
  let &modeline = modeline
  close!
  call delete('Xfile.txt')
endfunc

func Test_indent_func_with_gq()

  function GetTeXIndent()
    " Sample indent expression for TeX files
    let lnum = prevnonblank(v:lnum - 1)
    " At the start of the file use zero indent.
    if lnum == 0
      return 0
    endif
    let line = getline(lnum)
    let ind = indent(lnum)
    " Add a 'shiftwidth' after beginning of environments.
    if line =~ '\\begin{center}'
      let ind = ind + shiftwidth()
    endif
    return ind
  endfunction

  new
  setl et sw=2 sts=2 ts=2 tw=50 indentexpr=GetTeXIndent()
  put =[  '\documentclass{article}', '', '\begin{document}', '',
        \ 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Fusce ut enim non',
        \ 'libero efficitur aliquet. Maecenas metus justo, facilisis convallis blandit',
        \ 'non, semper eu urna. Suspendisse diam diam, iaculis faucibus lorem eu,',
        \ 'fringilla condimentum lectus. Quisque euismod diam at convallis vulputate.',
        \ 'Pellentesque laoreet tortor sit amet mauris euismod ornare. Sed varius',
        \ 'bibendum orci vel vehicula. Pellentesque tempor, ipsum et auctor accumsan,',
        \ 'metus lectus ultrices odio, sed elementum mi ante at arcu.', '', '\begin{center}', '',
        \ 'Proin nec risus consequat nunc dapibus consectetur. Mauris lacinia est a augue',
        \ 'tristique accumsan. Morbi pretium, felis molestie eleifend condimentum, arcu',
        \ 'ipsum congue nisl, quis euismod purus libero in ante.', '',
        \ 'Donec id semper purus.',
        \ 'Suspendisse eget aliquam nunc. Maecenas fringilla mauris vitae maximus',
        \ 'condimentum. Cras a quam in mi dictum eleifend at a lorem. Sed convallis',
        \ 'ante a commodo facilisis. Nam suscipit vulputate odio, vel dapibus nisl',
        \ 'dignissim facilisis. Vestibulum ante ipsum primis in faucibus orci luctus et',
        \ 'ultrices posuere cubilia curae;', '', '']
  1d_
  call cursor(5, 1)
  ka
  call cursor(14, 1)
  kb
  norm! 'agqap
  norm! 'bgqG
  let expected = [ '\documentclass{article}', '', '\begin{document}', '',
        \ 'Lorem ipsum dolor sit amet, consectetur adipiscing',
        \ 'elit. Fusce ut enim non libero efficitur aliquet.',
        \ 'Maecenas metus justo, facilisis convallis blandit',
        \ 'non, semper eu urna. Suspendisse diam diam,',
        \ 'iaculis faucibus lorem eu, fringilla condimentum',
        \ 'lectus. Quisque euismod diam at convallis',
        \ 'vulputate.  Pellentesque laoreet tortor sit amet',
        \ 'mauris euismod ornare. Sed varius bibendum orci',
        \ 'vel vehicula. Pellentesque tempor, ipsum et auctor',
        \ 'accumsan, metus lectus ultrices odio, sed',
        \ 'elementum mi ante at arcu.', '', '\begin{center}', '',
        \ '  Proin nec risus consequat nunc dapibus',
        \ '  consectetur. Mauris lacinia est a augue',
        \ '  tristique accumsan. Morbi pretium, felis',
        \ '  molestie eleifend condimentum, arcu ipsum congue',
        \ '  nisl, quis euismod purus libero in ante.',
        \ '',
        \ '  Donec id semper purus.  Suspendisse eget aliquam',
        \ '  nunc. Maecenas fringilla mauris vitae maximus',
        \ '  condimentum. Cras a quam in mi dictum eleifend',
        \ '  at a lorem. Sed convallis ante a commodo',
        \ '  facilisis. Nam suscipit vulputate odio, vel',
        \ '  dapibus nisl dignissim facilisis. Vestibulum',
        \ '  ante ipsum primis in faucibus orci luctus et',
        \ '  ultrices posuere cubilia curae;', '', '']
  call assert_equal(expected, getline(1, '$'))

  bwipe!
  delmark ab
  delfunction GetTeXIndent
endfu

func Test_formatting_keeps_first_line_indent()
  let lines =<< trim END
      foo()
      {
          int x;         // manually positioned
                         // more text that will be formatted
                         // but not reindented
  END
  new
  call setline(1, lines)
  setlocal sw=4 cindent tw=45 et
  normal! 4Ggqj
  let expected =<< trim END
      foo()
      {
          int x;         // manually positioned
                         // more text that will be
                         // formatted but not
                         // reindented
  END
  call assert_equal(expected, getline(1, '$'))
  bwipe!
endfunc

" Test for indenting with large amount, causes overflow
func Test_indent_overflow_count()
  throw 'skipped: TODO: '
  new
  setl sw=8
  call setline(1, "abc")
  norm! V2147483647>
  " indents by INT_MAX
  call assert_equal(2147483647, indent(1))
  close!
endfunc

func Test_indent_overflow_count2()
  throw 'skipped: Nvim does not support 64-bit number options'
  new
  " this only works, when long is 64bits
  try
    setl sw=0x180000000
  catch /^Vim\%((\a\+)\)\=:E487:/
  throw 'Skipped: value negative on this platform'
  endtry
  call setline(1, "\tabc")
  norm! <<
  call assert_equal(0, indent(1))
  close!
endfunc

" Test that mouse shape is restored to Normal mode after using "gq" when
" 'indentexpr' executes :normal.
func Test_indent_norm_with_gq()
  CheckFeature mouseshape
  CheckCanRunGui

  let lines =<< trim END
    func Indent()
      exe "normal! \<Ignore>"
      return 0
    endfunc

    setlocal indentexpr=Indent()
  END
  call writefile(lines, 'Xindentexpr.vim', 'D')

  let lines =<< trim END
    vim9script
    var mouse_shapes = []

    setline(1, [repeat('a', 80), repeat('b', 80)])

    feedkeys('ggVG')
    timer_start(50, (_) => {
      mouse_shapes += [getmouseshape()]
      timer_start(50, (_) => {
        feedkeys('gq')
        timer_start(50, (_) => {
          mouse_shapes += [getmouseshape()]
          timer_start(50, (_) => {
            writefile(mouse_shapes, 'Xmouseshapes')
            quit!
          })
        })
      })
    })
  END
  call writefile(lines, 'Xmouseshape.vim', 'D')

  call RunVim([], [], "-g -S Xindentexpr.vim -S Xmouseshape.vim")
  call WaitForAssert({-> assert_equal(['rightup-arrow', 'arrow'],
        \ readfile('Xmouseshapes'))}, 300)

  call delete('Xmouseshapes')
endfunc

" vim: shiftwidth=2 sts=2 expandtab
