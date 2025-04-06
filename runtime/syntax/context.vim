" Vim syntax file
" Language:           ConTeXt typesetting engine
" Maintainer:         Nicola Vitacolonna <nvitacolonna@gmail.com>
" Former Maintainers: Nikolai Weibull <now@bitwi.se>
" Latest Revision:    2016 Oct 16

if exists("b:current_syntax")
  finish
endif

runtime! syntax/plaintex.vim
unlet b:current_syntax

let s:cpo_save = &cpo
set cpo&vim

" Dictionary of (filetype, group) pairs to highlight between \startGROUP \stopGROUP.
let s:context_include = get(b:, 'context_include', get(g:, 'context_include', {'xml': 'XML'}))

" For backward compatibility (g:context_include used to be a List)
if type(s:context_include) ==# type([])
  let g:context_metapost = (index(s:context_include, 'mp') != -1)
  let s:context_include = filter(
        \ {'c': 'C', 'javascript': 'JS', 'ruby': 'Ruby', 'xml': 'XML'},
        \ { k,_ -> index(s:context_include, k) != -1 }
        \ )
endif

syn iskeyword @,48-57,a-z,A-Z,192-255

syn spell   toplevel

" ConTeXt options, i.e., [...] blocks
syn region  contextOptions    matchgroup=contextDelimiter start='\['  end=']\|\ze\\stop' skip='\\\[\|\\\]' contains=ALLBUT,contextBeginEndLua,@Spell

" Highlight braces
syn match   contextDelimiter  '[{}]'

" Comments
syn match   contextComment '\\\@<!\%(\\\\\)*\zs%.*$' display contains=initexTodo
syn match   contextComment '^\s*%[CDM].*$'           display contains=initexTodo

syn match   contextBlockDelim '\\\%(start\|stop\)\a\+' contains=@NoSpell

syn region  contextEscaped    matchgroup=contextPreProc start='\\type\%(\s*\|\n\)*\z([^A-Za-z%]\)' end='\z1'
syn region  contextEscaped    matchgroup=contextPreProc start='\\type\=\%(\s\|\n\)*{' end='}'
syn region  contextEscaped    matchgroup=contextPreProc start='\\type\=\%(\s*\|\n\)*<<' end='>>'
syn region  contextEscaped    matchgroup=contextPreProc
                              \ start='\\start\z(\a*\%(typing\|typen\)\)'
                              \ end='\\stop\z1' contains=plaintexComment keepend
syn region  contextEscaped    matchgroup=contextPreProc start='\\\h\+Type\%(\s\|\n\)*{' end='}'
syn region  contextEscaped    matchgroup=contextPreProc start='\\Typed\h\+\%(\s\|\n\)*{' end='}'

syn match   contextBuiltin    display contains=@NoSpell
      \ '\\\%(unprotect\|protect\|unexpanded\)\>'

syn match   contextPreProc    '^\s*\\\%(start\|stop\)\=\%(component\|environment\|project\|product\)\>'
                              \ contains=@NoSpell

if get(b:, 'context_metapost', get(g:, 'context_metapost', 1))
  let b:mp_metafun_macros = 1 " Highlight MetaFun keywords
  syn include @mpTop          syntax/mp.vim
  unlet b:current_syntax

  syn region  contextMPGraphic  matchgroup=contextBlockDelim
                                \ start='\\start\z(MP\%(clip\|code\|definitions\|drawing\|environment\|extensions\|inclusions\|initializations\|page\|\)\)\>.*$'
                                \ end='\\stop\z1'
                                \ contains=@mpTop,@NoSpell
  syn region  contextMPGraphic  matchgroup=contextBlockDelim
                                \ start='\\start\z(\%(\%[re]usable\|use\|unique\|static\)MPgraphic\|staticMPfigure\|uniqueMPpagegraphic\)\>.*$'
                                \ end='\\stop\z1'
                                \ contains=@mpTop,@NoSpell
endif

if get(b:, 'context_lua', get(g:, 'context_lua', 1))
  syn include @luaTop          syntax/lua.vim
  unlet b:current_syntax

  syn region  contextLuaCode    matchgroup=contextBlockDelim
                                \ start='\\startluacode\>'
                                \ end='\\stopluacode\>' keepend
                                \ contains=@luaTop,@NoSpell

  syn match   contextDirectLua  "\\\%(directlua\|ctxlua\)\>\%(\s*%.*$\)\="
                                \ nextgroup=contextBeginEndLua skipwhite skipempty
                                \ contains=initexComment
  syn region  contextBeginEndLua matchgroup=contextSpecial
                                \ start="{" end="}" skip="\\[{}]"
                                \ contained contains=@luaTop,@NoSpell
endif

for synname in keys(s:context_include)
  execute 'syn include @' . synname . 'Top' 'syntax/' . synname . '.vim'
  unlet b:current_syntax
  execute 'syn region context' . s:context_include[synname] . 'Code'
        \ 'matchgroup=contextBlockDelim'
        \ 'start=+\\start' . s:context_include[synname] . '+'
        \ 'end=+\\stop' . s:context_include[synname] . '+'
        \ 'contains=@' . synname . 'Top,@NoSpell'
endfor

syn match   contextSectioning '\\\%(start\|stop\)\=\%(\%(sub\)*section\|\%(sub\)*subject\|chapter\|part\|component\|product\|title\)\>'
                              \ contains=@NoSpell

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

hi def link contextOptions    Typedef
hi def link contextComment    Comment
hi def link contextBlockDelim Keyword
hi def link contextBuiltin    Keyword
hi def link contextDelimiter  Delimiter
hi def link contextEscaped    String
hi def link contextPreProc    PreProc
hi def link contextSectioning PreProc
hi def link contextSpecial    Special
hi def link contextType       Type
hi def link contextStyle      contextType
hi def link contextFont       contextType
hi def link contextDirectLua  Keyword

let b:current_syntax = "context"

let &cpo = s:cpo_save
unlet s:cpo_save
