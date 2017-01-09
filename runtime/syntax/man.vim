" Maintainer:          Anmol Sethi <anmol@aubble.com>
" Previous Maintainer: SungHyun Nam <goweol@gmail.com>

if exists('b:current_syntax')
  finish
endif

syntax match manBackspacedChar      display conceal contained '.\b'
syntax match manBold                display contains=manBackspacedChar
      \ '\%(.\b.\)\+'
syntax match manUnderline           display contains=manBackspacedChar
      \ '\%(_\b[^_]\)\+'

if !exists('#man_init_highlight_groups')
  augroup man_init_highlight_groups
    autocmd!
    autocmd ColorScheme * call man#init_highlight_groups()
  augroup END
  call man#init_highlight_groups()
endif

if !exists('b:man_sect')
  call man#init_pager()
endif
if b:man_sect =~# '^[23]'
  syntax include @c $VIMRUNTIME/syntax/c.vim
  syntax match manCFuncDefinition display '\<\h\w*\>\ze\(\s\|\n\)*(' contained
  syntax region manSynopsis start='^\%(
        \SYNOPSIS\|
        \SYNTAX\|
        \SINTASSI\|
        \SKŁADNIA\|
        \СИНТАКСИС\|
        \書式\)$' end='^\%(\S.*\)\=\S$' keepend contains=manSectionHeading,@c,manCFuncDefinition
  highlight default link manCFuncDefinition Function
endif

" Prevent everything else from matching the last line
execute 'syntax match manFooter display "^\%'.line('$').'l.*$"'

let b:current_syntax = 'man'
