" Vim indent file
" Language:     Handlebars
" Maintainer:   Devin Weaver
" Last Change:  2026 Feb 20
" Origin:       https://github.com/joukevandermaas/vim-ember-hbs
" Credits:      Jouke van der Maas
" Acknowledgement: Based on eruby.vim indentation by TPope
" License:      MIT
" The MIT License (MIT)
"
" Copyright (c) 2026 Devin Weaver
" Copyright (c) 2015 Jouke van der Maas
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:
"
" The above copyright notice and this permission notice shall be included in all
" copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
" SOFTWARE.

if exists("b:did_indent")
  finish
endif

runtime! indent/html.vim
unlet! b:did_indent

" Force HTML indent to not keep state.
let b:html_indent_usestate = 0
let b:handlebars_current_indent = 0

if &l:indentexpr == ''
  if &l:cindent
    let &l:indentexpr = 'cindent(v:lnum)'
  else
    let &l:indentexpr = 'indent(prevnonblank(v:lnum-1))'
  endif
endif
let b:handlebars_subtype_indentexpr = &l:indentexpr

let b:did_indent = 1

setlocal indentexpr=GetHandlebarsIndent()
setlocal indentkeys=o,O,*<Return>,<>>,{,},0),0],o,O,!^F,=else,={{#,={{/

" Only define the function once.
if exists("*GetHandlebarsIndent")
  finish
endif

function! GetHandlebarsIndent(...)
  " The value of a single shift-width
  let sw = shiftwidth()

  if a:0 && a:1 == '.'
    let v:lnum = line('.')
  elseif a:0 && a:1 =~ '^\d'
    let v:lnum = a:1
  endif
  let vcol = col('.')
  call cursor(v:lnum,1)
  call cursor(v:lnum,vcol)
  exe "let ind = ".b:handlebars_subtype_indentexpr

  " Workaround for Andy Wokula's HTML indent. This should be removed after
  " some time, since the newest version is fixed in a different way. Credit
  " to eruby.vim indent by tpope
  if b:handlebars_subtype_indentexpr =~# '^HtmlIndent('
  \ && exists('b:indent')
  \ && type(b:indent) == type({})
  \ && has_key(b:indent, 'lnum')
    " Force HTML indent to not keep state
    let b:indent.lnum = -1
  endif

  let lnum = prevnonblank(v:lnum-1)
  let prevLine = getline(lnum)
  let currentLine = getline(v:lnum)

  " all indent rules only apply if the block opening/closing
  " tag is on a separate line

  " indent after block {{#block
  if prevLine =~# '\v\s*\{\{\#'
    let ind = ind + sw
  endif
  " but not if the block ends on the same line
  if prevLine =~# '\v\s*\{\{\#(.+)(\s+|\}\}).+\{\{\/\1'
    let ind = ind - sw
  endif
  " unindent after block close {{/block}}
  if currentLine =~# '\v^\s*\{\{\/'
    let ind = ind - sw
  endif
  " indent after component block {{a-component
  if prevLine =~# '\v\s*\{\{\w'
     let ind = ind + sw
  endif
  " but not if the component block ends on the same line
  if prevLine =~# '\v\s*\{\{\w(.+)\}\}'
    let ind = ind - sw
  endif
  " unindent }} lines
  if currentLine =~# '\v^\s*\}\}\s*$' || (currentLine !~# '\v^\s*\{\{\/' && prevLine =~# '\v^\s*[^\{\}]+\}\}\s*$')
    let ind = ind - sw
  endif
  " unindent {{else}}
  if currentLine =~# '\v^\s*\{\{else'
    let ind = ind - sw
  endif
  " indent again after {{else}}
  if prevLine =~# '\v^\s*\{\{else'
    let ind = ind + sw
  endif

  return ind
endfunction
