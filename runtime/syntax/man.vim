" Maintainer:          Anmol Sethi <anmol@aubble.com>
" Previous Maintainer: SungHyun Nam <goweol@gmail.com>

if exists('b:current_syntax')
  finish
endif

syntax case  ignore
syntax match manReference          '[^()[:space:]]\+([0-9nx][a-z]*)'
syntax match manSectionHeading     '^\%(\S.*\)\=\S$'
syntax match manTitle              '^\%1l.*$'
syntax match manSubHeading         '^\s\{3\}\S.*$'
syntax match manOptionDesc         '^\s\+\%(+\|--\=\)\S\+'

highlight default link manTitle          Title
highlight default link manSectionHeading Statement
highlight default link manOptionDesc     Constant
highlight default link manReference      PreProc
highlight default link manSubHeading     Function

if getline(1) =~# '^[^()[:space:]]\+([23].*'
  syntax include @cCode $VIMRUNTIME/syntax/c.vim
  syntax match manCFuncDefinition display '\<\h\w*\>\s*('me=e-1 contained
  syntax region manSynopsis start='\V\^\%(
        \SYNOPSIS\|
        \SYNTAX\|
        \SINTASSI\|
        \SKŁADNIA\|
        \СИНТАКСИС\|
        \書式\)\$'hs=s+8 end='^\%(\S.*\)\=\S$'me=e-12 keepend contains=manSectionHeading,@cCode,manCFuncDefinition
  highlight default link manCFuncDefinition Function
endif

" Prevent everything else from matching the last line
execute 'syntax match manFooter "^\%'.line('$').'l.*$"'

let b:current_syntax = 'man'
