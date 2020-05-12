" Vim indent file
" Language:	Haml
" Maintainer:	Tim Pope <vimNOSPAM@tpope.org>
" Last Change:	2017 Jun 13

if exists("b:did_indent")
  finish
endif
runtime! indent/ruby.vim
unlet! b:did_indent
let b:did_indent = 1

setlocal autoindent sw=2 et
setlocal indentexpr=GetHamlIndent()
setlocal indentkeys=o,O,*<Return>,},],0),!^F,=end,=else,=elsif,=rescue,=ensure,=when

" Only define the function once.
if exists("*GetHamlIndent")
  finish
endif

let s:attributes = '\%({.\{-\}}\|\[.\{-\}\]\)'
let s:tag = '\%([%.#][[:alnum:]_-]\+\|'.s:attributes.'\)*[<>]*'

if !exists('g:haml_self_closing_tags')
  let g:haml_self_closing_tags = 'base|link|meta|br|hr|img|input'
endif

function! GetHamlIndent()
  let lnum = prevnonblank(v:lnum-1)
  if lnum == 0
    return 0
  endif
  let line = substitute(getline(lnum),'\s\+$','','')
  let cline = substitute(substitute(getline(v:lnum),'\s\+$','',''),'^\s\+','','')
  let lastcol = strlen(line)
  let line = substitute(line,'^\s\+','','')
  let indent = indent(lnum)
  let cindent = indent(v:lnum)
  let sw = shiftwidth()
  if cline =~# '\v^-\s*%(elsif|else|when)>'
    let indent = cindent < indent ? cindent : indent - sw
  endif
  let increase = indent + sw
  if indent == indent(lnum)
    let indent = cindent <= indent ? -1 : increase
  endif

  let group = synIDattr(synID(lnum,lastcol,1),'name')

  if line =~ '^!!!'
    return indent
  elseif line =~ '^/\%(\[[^]]*\]\)\=$'
    return increase
  elseif group == 'hamlFilter'
    return increase
  elseif line =~ '^'.s:tag.'[&!]\=[=~-]\s*\%(\%(if\|else\|elsif\|unless\|case\|when\|while\|until\|for\|begin\|module\|class\|def\)\>\%(.*\<end\>\)\@!\|.*do\%(\s*|[^|]*|\)\=\s*$\)'
    return increase
  elseif line =~ '^'.s:tag.'[&!]\=[=~-].*,\s*$'
    return increase
  elseif line == '-#'
    return increase
  elseif group =~? '\v^(hamlSelfCloser)$' || line =~? '^%\v%('.g:haml_self_closing_tags.')>'
    return indent
  elseif group =~? '\v^%(hamlTag|hamlAttributesDelimiter|hamlObjectDelimiter|hamlClass|hamlId|htmlTagName|htmlSpecialTagName)$'
    return increase
  elseif synIDattr(synID(v:lnum,1,1),'name') ==? 'hamlRubyFilter'
    return GetRubyIndent()
  else
    return indent
  endif
endfunction

" vim:set sw=2:
