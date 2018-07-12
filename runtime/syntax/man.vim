" Maintainer:          Anmol Sethi <anmol@aubble.com>
" Previous Maintainer: SungHyun Nam <goweol@gmail.com>

if exists('b:current_syntax')
  finish
endif

syntax case  ignore
syntax match manReference      display '[^()[:space:]]\+([0-9nx][a-z]*)'
syntax match manSectionHeading display '^\S.*$'
syntax match manTitle          display '^\%1l.*$'
syntax match manSubHeading     display '^ \{3\}\S.*$'
syntax match manOptionDesc     display '^\s\+\%(+\|-\)\S\+'

highlight default link manTitle          Title
highlight default link manSectionHeading Statement
highlight default link manOptionDesc     Constant
highlight default link manReference      PreProc
highlight default link manSubHeading     Function

highlight default manUnderline cterm=underline gui=underline
highlight default manBold      cterm=bold      gui=bold
highlight default manItalic    cterm=italic    gui=italic

if &filetype != 'man'
  " May have been included by some other filetype.
  finish
endif

if !exists('b:man_sect')
  call man#init_pager()
endif
if b:man_sect =~# '^[023]'
  syntax case match
  syntax include @c $VIMRUNTIME/syntax/c.vim
  syntax match manCFuncDefinition display '\<\h\w*\>\ze\(\s\|\n\)*(' contained
  syntax match manSentence display '\%(^ \{3,7}\u\|\.  \u\)\_.\{-}
        \\%(-$\|\.$\|:$\)\|
        \ \{3,7}\a.*\%(\.\|:\)$' contained contains=manReference
  syntax region manSynopsis start='^\%(
        \SYNOPSIS\|
        \SYNTAX\|
        \SINTASSI\|
        \SKŁADNIA\|
        \СИНТАКСИС\|
        \書式\)$' end='^\%(\S.*\)\=\S$' keepend contains=manSentence,manSectionHeading,@c,manCFuncDefinition
  highlight default link manCFuncDefinition Function

  syntax region manExample start='^EXAMPLES\=$' end='^\%(\S.*\)\=\S$' keepend contains=manSentence,manSectionHeading,manSubHeading,@c,manCFuncDefinition

  " XXX: groupthere doesn't seem to work
  syntax sync minlines=500
  "syntax sync match manSyncExample groupthere manExample '^EXAMPLES\=$'
  "syntax sync match manSyncExample groupthere NONE '^\%(EXAMPLES\=\)\@!\%(\S.*\)\=\S$'
endif

" Prevent everything else from matching the last line
execute 'syntax match manFooter display "^\%'.line('$').'l.*$"'

let b:current_syntax = 'man'
