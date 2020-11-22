" Vim plugin for formatting XML
" Last Change: 2019 Oct 24
"     Version: 0.2
"      Author: Christian Brabandt <cb@256bit.org>
"  Repository: https://github.com/chrisbra/vim-xml-ftplugin
"     License: VIM License
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
  let count_orig = v:count
  let sw  = shiftwidth()
  let prev = prevnonblank(v:lnum-1)
  let s:indent = indent(prev)/sw
  let result = []
  let lastitem = prev ? getline(prev) : ''
  let is_xml_decl = 0
  " go through every line, but don't join all content together and join it
  " back. We might lose empty lines
  let list = getline(v:lnum, (v:lnum + count_orig - 1))
  let current = 0
  for line in list
    " Keep empty input lines?
    if empty(line)
      call add(result, '')
      continue
    elseif line !~# '<[/]\?[^>]*>'
      let nextmatch = match(list, '<[/]\?[^>]*>', current)
      let line .= join(list[(current + 1):(nextmatch-1)], "\n")
      call remove(list, current+1, nextmatch-1)
    endif
    " split on `>`, but don't split on very first opening <
    " this means, items can be like ['<tag>', 'tag content</tag>']
    for item in split(line, '.\@<=[>]\zs')
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
          " Simply split on '<', if there is one,
          " but reformat according to &textwidth
          let t=split(item, '.<\@=\zs')
          " t should only contain 2 items, but just be safe here
          if s:IsTag(lastitem)
            let s:indent+=1
          endif
          let result+=s:FormatContent([t[0]])
          if s:EndTag(t[1])
            let s:indent = s:DecreaseIndent()
          endif
          "for y in t[1:]
            let result+=s:FormatContent(t[1:])
          "endfor
        else
          call add(result, s:Indent(item))
        endif
      endif
      let lastitem = item
    endfor
    let current += 1
  endfor

  if !empty(result)
    let lastprevline = getline(v:lnum + count_orig)
    let delete_lastline = v:lnum + count_orig - 1 == line('$')
    exe v:lnum. ",". (v:lnum + count_orig - 1). 'd'
    call append(v:lnum - 1, result)
    " Might need to remove the last line, if it became empty because of the
    " append() call
    let last = v:lnum + len(result)
    " do not use empty(), it returns true for `empty(0)`
    if getline(last) is '' && lastprevline is '' && delete_lastline
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
  let is_comment = s:IsComment(a:tag)
  return a:tag =~? '^\s*<[^/?]' && !is_comment
endfunc
" Check if tag is a Comment start {{{1
func! s:IsComment(tag)
  return a:tag =~? '<!--'
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
" Format input line according to textwidth {{{1
func! s:FormatContent(list)
  let result=[]
  let limit = 80
  if &textwidth > 0
    let limit = &textwidth
  endif
  let column=0
  let idx = -1
  let add_indent = 0
  let cnt = 0
  for item in a:list
    for word in split(item, '\s\+\S\+\zs')
      let column += strdisplaywidth(word, column)
      if match(word, "^\\s*\n\\+\\s*$") > -1
        call add(result, '')
        let idx += 1
        let column = 0
        let add_indent = 1
      elseif column > limit || cnt == 0
        let add = s:Indent(s:Trim(word))
        call add(result, add)
        let column = strdisplaywidth(add)
        let idx += 1
      else
        if add_indent
          let result[idx] = s:Indent(s:Trim(word))
        else
          let result[idx] .= ' '. s:Trim(word)
        endif
        let add_indent = 0
      endif
      let cnt += 1
    endfor
  endfor
  return result
endfunc
" Restoration And Modelines: {{{1
let &cpo= s:keepcpo
unlet s:keepcpo
" Modeline {{{1
" vim: fdm=marker fdl=0 ts=2 et sw=0 sts=-1
