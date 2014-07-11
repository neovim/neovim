" Vim syntax file
" Language:         ConTeXt typesetting engine
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2006-08-10

if exists("b:current_syntax")
  finish
endif

runtime! syntax/plaintex.vim
unlet b:current_syntax

let s:cpo_save = &cpo
set cpo&vim

if !exists('g:context_include')
  let g:context_include = ['mp', 'javascript', 'xml']
endif

syn spell   toplevel

syn match   contextBlockDelim display '\\\%(start\|stop\)\a\+'
                              \ contains=@NoSpell

syn region  contextEscaped    display matchgroup=contextPreProc
                              \ start='\\type\z(\A\)' end='\z1'
syn region  contextEscaped    display matchgroup=contextPreProc
                              \ start='\\type\={' end='}'
syn region  contextEscaped    display matchgroup=contextPreProc
                              \ start='\\type\=<<' end='>>'
syn region  contextEscaped    matchgroup=contextPreProc
                              \ start='\\start\z(\a*\%(typing\|typen\)\)'
                              \ end='\\stop\z1' contains=plaintexComment keepend
syn region  contextEscaped    display matchgroup=contextPreProc
                              \ start='\\\h\+Type{' end='}'
syn region  contextEscaped    display matchgroup=contextPreProc
                              \ start='\\Typed\h\+{' end='}'

syn match   contextBuiltin    display contains=@NoSpell
      \ '\\\%(unprotect\|protect\|unexpanded\)' 

syn match   contextPreProc    '^\s*\\\%(start\|stop\)\=\%(component\|environment\|project\|product\).*$'
                              \ contains=@NoSpell

if index(g:context_include, 'mp') != -1
  syn include @mpTop          syntax/mp.vim
  unlet b:current_syntax

  syn region  contextMPGraphic  transparent matchgroup=contextBlockDelim
                                \ start='\\start\z(\a*MPgraphic\|MP\%(page\|inclusions\|run\)\).*'
                                \ end='\\stop\z1'
                                \ contains=@mpTop
endif

" TODO: also need to implement this for \\typeC or something along those
" lines.
function! s:include_syntax(name, group)
  if index(g:context_include, a:name) != -1
    execute 'syn include @' . a:name . 'Top' 'syntax/' . a:name . '.vim'
    unlet b:current_syntax
    execute 'syn region context' . a:group . 'Code'
          \ 'transparent matchgroup=contextBlockDelim'
          \ 'start=+\\start' . a:group . '+ end=+\\stop' . a:group . '+'
          \ 'contains=@' . a:name . 'Top'
  endif
endfunction

call s:include_syntax('c', 'C')
call s:include_syntax('ruby', 'Ruby')
call s:include_syntax('javascript', 'JS')
call s:include_syntax('xml', 'XML')

syn match   contextSectioning '\\chapter\>' contains=@NoSpell
syn match   contextSectioning '\\\%(sub\)*section\>' contains=@NoSpell

syn match   contextSpecial    '\\crlf\>\|\\par\>\|-\{2,3}\||[<>/]\=|'
                              \ contains=@NoSpell
syn match   contextSpecial    /\\[`'"]/
syn match   contextSpecial    +\\char\%(\d\{1,3}\|'\o\{1,3}\|"\x\{1,2}\)\>+
                              \ contains=@NoSpell
syn match   contextSpecial    '\^\^.'
syn match   contextSpecial    '`\%(\\.\|\^\^.\|.\)'

syn match   contextStyle      '\\\%(em\|ss\|hw\|cg\|mf\)\>'
                              \ contains=@NoSpell
syn match   contextFont       '\\\%(CAP\|Cap\|cap\|Caps\|kap\|nocap\)\>'
                              \ contains=@NoSpell
syn match   contextFont       '\\\%(Word\|WORD\|Words\|WORDS\)\>'
                              \ contains=@NoSpell
syn match   contextFont       '\\\%(vi\{1,3}\|ix\|xi\{0,2}\)\>'
                              \ contains=@NoSpell
syn match   contextFont       '\\\%(tf\|b[si]\|s[cl]\|os\)\%(xx\|[xabcd]\)\=\>'
                              \ contains=@NoSpell

hi def link contextBlockDelim Keyword
hi def link contextBuiltin    Keyword
hi def link contextDelimiter  Delimiter
hi def link contextPreProc    PreProc
hi def link contextSectioning PreProc
hi def link contextSpecial    Special
hi def link contextType       Type
hi def link contextStyle      contextType
hi def link contextFont       contextType

let b:current_syntax = "context"

let &cpo = s:cpo_save
unlet s:cpo_save
