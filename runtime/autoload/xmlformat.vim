" Vim plugin for formatting XML
" Last Change: Thu, 22 May 2018 21:26:55 +0100
" Version: 0.1
" Author: Christian Brabandt <cb@256bit.org>
" Script:  http://www.vim.org/scripts/script.php?script_id=
" License: VIM License
" GetLatestVimScripts: ???? 18 :AutoInstall: xmlformat.vim
" Documentation: see :h xmlformat.txt (TODO!)
" ---------------------------------------------------------------------
" Load Once: {{{1
if exists("g:loaded_xmlformat") || &cp
  finish
endif
let g:loaded_xmlformat = 1
let s:keepcpo       = &cpo
set cpo&vim

" Main function: Format the input {{{1
func! xmlformat#Format()
  " only allow reformatting through the gq command
  " (e.g. Vim is in normal mode)
  if mode() != 'n'
    " do not fall back to internal formatting
    return 0
  endif
  let sw  = shiftwidth()
  let prev = prevnonblank(v:lnum-1)
  let s:indent = indent(prev)/sw
  let result = []
  let lastitem = prev ? getline(prev) : ''
  let is_xml_decl = 0
  " split on `<`, but don't split on very first opening <
  for item in split(join(getline(v:lnum, (v:lnum + v:count - 1))), '.\@<=[>]\zs')
    if s:EndTag(item)
      let s:indent = s:DecreaseIndent()
      call add(result, s:Indent(item))
    elseif s:EmptyTag(lastitem)
      call add(result, s:Indent(item))
    elseif s:StartTag(lastitem) && s:IsTag(item)
      let s:indent += 1
      call add(result, s:Indent(item))
     else
       if !s:IsTag(item)
         " Simply split on '<'
         let t=split(item, '.<\@=\zs')
         let s:indent+=1
         call add(result, s:Indent(t[0]))
         let s:indent = s:DecreaseIndent()
         call add(result, s:Indent(t[1]))
       else
        call add(result, s:Indent(item))
      endif
     endif
     let lastitem = item
   endfor

   if !empty(result)
    exe v:lnum. ",". (v:lnum + v:count - 1). 'd'
    call append(v:lnum - 1, result)
    " Might need to remove the last line, if it became empty because of the
    " append() call
    let last = v:lnum + len(result)
    if getline(last) is ''
      exe last. 'd'
    endif
  endif

  " do not run internal formatter!
  return 0
endfunc
" Check if given tag is XML Declaration header {{{1
func! s:IsXMLDecl(tag)
  return a:tag =~? '^\s*<?xml\s\?\%(version="[^"]*"\)\?\s\?\%(encoding="[^"]*"\)\? ?>\s*$'
endfunc
" Return tag indented by current level {{{1
func! s:Indent(item)
  return repeat(' ', shiftwidth()*s:indent). s:Trim(a:item)
endfu
" Return item trimmed from leading whitespace {{{1
func! s:Trim(item)
  if exists('*trim')
    return trim(a:item)
  else
    return matchstr(a:item, '\S\+.*')
  endif
endfunc
" Check if tag is a new opening tag <tag> {{{1
func! s:StartTag(tag)
  return a:tag =~? '^\s*<[^/?]'
endfunc
" Remove one level of indentation {{{1
func! s:DecreaseIndent()
  return (s:indent > 0 ? s:indent - 1 : 0)
endfunc
" Check if tag is a closing tag </tag> {{{1
func! s:EndTag(tag)
  return a:tag =~? '^\s*</'
endfunc
" Check that the tag is actually a tag and not {{{1
" something like "foobar</foobar>"
func! s:IsTag(tag)
  return s:Trim(a:tag)[0] == '<'
endfunc
" Check if tag is empty <tag/> {{{1
func! s:EmptyTag(tag)
  return a:tag =~ '/>\s*$'
endfunc
" Restoration And Modelines: {{{1
let &cpo= s:keepcpo
unlet s:keepcpo
" Modeline {{{1
" vim: fdm=marker fdl=0 ts=2 et sw=0 sts=-1
