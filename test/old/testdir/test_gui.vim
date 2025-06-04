
func SetUp()
  source $VIMRUNTIME/menu.vim
endfunc

func Test_colorscheme()
  " call assert_equal('16777216', &t_Co)

  let colorscheme_saved = exists('g:colors_name') ? g:colors_name : 'default'
  let g:color_count = 0
  augroup TestColors
    au!
    au ColorScheme * let g:color_count += 1
                 \ | let g:after_colors = g:color_count
                 \ | let g:color_after = expand('<amatch>')
    au ColorSchemePre * let g:color_count += 1
                    \ | let g:before_colors = g:color_count
                    \ | let g:color_pre = expand('<amatch>')
  augroup END

  colorscheme torte
  redraw!
  call assert_equal('dark', &background)
  call assert_equal(1, g:before_colors)
  call assert_equal(2, g:after_colors)
  call assert_equal('torte', g:color_pre)
  call assert_equal('torte', g:color_after)
  call assert_equal("\ntorte", execute('colorscheme'))

  let a = substitute(execute('hi Search'), "\n\\s\\+", ' ', 'g')
  " FIXME: temporarily check less while the colorscheme changes
  " call assert_match("\nSearch         xxx term=reverse cterm=reverse ctermfg=196 ctermbg=16 gui=reverse guifg=#ff0000 guibg=#000000", a)
  " call assert_match("\nSearch         xxx term=reverse ", a)

  call assert_fails('colorscheme does_not_exist', 'E185:')
  call assert_equal('does_not_exist', g:color_pre)
  call assert_equal('torte', g:color_after)

  exec 'colorscheme' colorscheme_saved
  augroup TestColors
    au!
  augroup END
  unlet g:color_count g:after_colors g:before_colors
  redraw!
endfunc

" Test that buffer names are shown at the end in the :Buffers menu
func Test_Buffers_Menu()
  doautocmd LoadBufferMenu VimEnter

  let name = '天'
  exe ':badd ' .. name
  let nr = bufnr('$')

  let cmd = printf(':amenu Buffers.%s\ (%d)', name, nr)
  let menu = split(execute(cmd), '\n')[1]
  call assert_match('^9999 '.. name, menu)
endfunc

" vim: shiftwidth=2 sts=2 expandtab
