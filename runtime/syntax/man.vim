" Maintainer:          Anmol Sethi <anmol@aubble.com>
" Previous Maintainer: SungHyun Nam <goweol@gmail.com>

if exists('b:current_syntax')
  finish
endif

syntax match manBackspacedCharacter display conceal '.\b'
syntax match manBold                display contains=manBackspacedCharacter '\%(\([[:graph:]]\)\b\1\)\+'
syntax match manUnderline           display contains=manBackspacedCharacter '\%(_\b[^_]\)\+'

if !exists('#man_highlight_groups')
  function! s:init_highlight_groups() abort
    let group = 'Keyword'
    while 1
      let values = execute('highlight '.group)
      if values =~# '='
        let values = substitute(values, '.* \(\w\+=.*\)', '\1', '')
        break
      endif
      let group = substitute(values, '.* to \(\w\+\)', '\1', '')
    endwhile
    execute 'highlight default manBold' values 'cterm=bold gui=bold'
    highlight default manUnderline cterm=underline gui=underline
  endfunction
  augroup man_highlight_groups
    autocmd!
    autocmd ColorScheme * call s:init_highlight_groups()
  augroup END
  call s:init_highlight_groups()
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
