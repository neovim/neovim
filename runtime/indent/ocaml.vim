" Vim indent file
" Language:     OCaml
" Maintainers:  Jean-Francois Yuen   <jfyuen@happycoders.org>
"               Mike Leary           <leary@nwlink.com>
"               Markus Mottl         <markus.mottl@gmail.com>
" URL:          https://github.com/ocaml/vim-ocaml
" Last Change:  2017 Jun 13
"               2005 Jun 25 - Fixed multiple bugs due to 'else\nreturn ind' working
"               2005 May 09 - Added an option to not indent OCaml-indents specially (MM)
"               2013 June   - commented textwidth (Marc Weber)
"
" Marc Weber's comment: This file may contain a lot of (very custom) stuff
" which eventually should be moved somewhere else ..

" Only load this indent file when no other was loaded.
if exists("b:did_indent")
 finish
endif
let b:did_indent = 1

setlocal expandtab
setlocal indentexpr=GetOCamlIndent()
setlocal indentkeys+=0=and,0=class,0=constraint,0=done,0=else,0=end,0=exception,0=external,0=if,0=in,0=include,0=inherit,0=initializer,0=let,0=method,0=open,0=then,0=type,0=val,0=with,0;;,0>\],0\|\],0>},0\|,0},0\],0)
setlocal nolisp
setlocal nosmartindent

" At least Marc Weber and Markus Mottl do not like this:
" setlocal textwidth=80

" Comment formatting
if !exists("no_ocaml_comments")
 if (has("comments"))
   setlocal comments=sr:(*\ ,mb:\ ,ex:*)
   setlocal comments^=sr:(**,mb:\ \ ,ex:*)
   setlocal fo=cqort
 endif
endif

" Only define the function once.
if exists("*GetOCamlIndent")
 finish
endif

" Define some patterns:
let s:beflet = '^\s*\(initializer\|method\|try\)\|\(\<\(begin\|do\|else\|in\|then\|try\)\|->\|<-\|=\|;\|(\)\s*$'
let s:letpat = '^\s*\(let\|type\|module\|class\|open\|exception\|val\|include\|external\)\>'
let s:letlim = '\(\<\(sig\|struct\)\|;;\)\s*$'
let s:lim = '^\s*\(exception\|external\|include\|let\|module\|open\|type\|val\)\>'
let s:module = '\<\%(begin\|sig\|struct\|object\)\>'
let s:obj = '^\s*\(constraint\|inherit\|initializer\|method\|val\)\>\|\<\(object\|object\s*(.*)\)\s*$'
let s:type = '^\s*\%(class\|let\|type\)\>.*='

" Skipping pattern, for comments
function! s:GetLineWithoutFullComment(lnum)
 let lnum = prevnonblank(a:lnum - 1)
 let lline = substitute(getline(lnum), '(\*.*\*)\s*$', '', '')
 while lline =~ '^\s*$' && lnum > 0
   let lnum = prevnonblank(lnum - 1)
   let lline = substitute(getline(lnum), '(\*.*\*)\s*$', '', '')
 endwhile
 return lnum
endfunction

" Indent for ';;' to match multiple 'let'
function! s:GetInd(lnum, pat, lim)
 let llet = search(a:pat, 'bW')
 let old = indent(a:lnum)
 while llet > 0
   let old = indent(llet)
   let nb = s:GetLineWithoutFullComment(llet)
   if getline(nb) =~ a:lim
     return old
   endif
   let llet = search(a:pat, 'bW')
 endwhile
 return old
endfunction

" Indent pairs
function! s:FindPair(pstart, pmid, pend)
 call search(a:pend, 'bW')
 return indent(searchpair(a:pstart, a:pmid, a:pend, 'bWn', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment"'))
endfunction

" Indent 'let'
function! s:FindLet(pstart, pmid, pend)
 call search(a:pend, 'bW')
 return indent(searchpair(a:pstart, a:pmid, a:pend, 'bWn', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment" || getline(".") =~ "^\\s*let\\>.*=.*\\<in\\s*$" || getline(prevnonblank(".") - 1) =~ s:beflet'))
endfunction

function! GetOCamlIndent()
 " Find a non-commented line above the current line.
 let lnum = s:GetLineWithoutFullComment(v:lnum)

 " At the start of the file use zero indent.
 if lnum == 0
   return 0
 endif

 let ind = indent(lnum)
 let lline = substitute(getline(lnum), '(\*.*\*)\s*$', '', '')

 " Return double 'shiftwidth' after lines matching:
 if lline =~ '^\s*|.*->\s*$'
   return ind + 2 * shiftwidth()
 endif

 let line = getline(v:lnum)

 " Indent if current line begins with 'end':
 if line =~ '^\s*end\>'
   return s:FindPair(s:module, '','\<end\>')

 " Indent if current line begins with 'done' for 'do':
 elseif line =~ '^\s*done\>'
   return s:FindPair('\<do\>', '','\<done\>')

 " Indent if current line begins with '}' or '>}':
 elseif line =~ '^\s*\(\|>\)}'
   return s:FindPair('{', '','}')

 " Indent if current line begins with ']', '|]' or '>]':
 elseif line =~ '^\s*\(\||\|>\)\]'
   return s:FindPair('\[', '','\]')

 " Indent if current line begins with ')':
 elseif line =~ '^\s*)'
   return s:FindPair('(', '',')')

 " Indent if current line begins with 'let':
 elseif line =~ '^\s*let\>'
   if lline !~ s:lim . '\|' . s:letlim . '\|' . s:beflet
     return s:FindLet(s:type, '','\<let\s*$')
   endif

 " Indent if current line begins with 'class' or 'type':
 elseif line =~ '^\s*\(class\|type\)\>'
   if lline !~ s:lim . '\|\<and\s*$\|' . s:letlim
     return s:FindLet(s:type, '','\<\(class\|type\)\s*$')
   endif

 " Indent for pattern matching:
 elseif line =~ '^\s*|'
   if lline !~ '^\s*\(|[^\]]\|\(match\|type\|with\)\>\)\|\<\(function\|parser\|private\|with\)\s*$'
     call search('|', 'bW')
     return indent(searchpair('^\s*\(match\|type\)\>\|\<\(function\|parser\|private\|with\)\s*$', '', '^\s*|', 'bWn', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string\\|comment" || getline(".") !~ "^\\s*|.*->"'))
   endif

 " Indent if current line begins with ';;':
 elseif line =~ '^\s*;;'
   if lline !~ ';;\s*$'
     return s:GetInd(v:lnum, s:letpat, s:letlim)
   endif

 " Indent if current line begins with 'in':
 elseif line =~ '^\s*in\>'
   if lline !~ '^\s*\(let\|and\)\>'
     return s:FindPair('\<let\>', '', '\<in\>')
   endif

 " Indent if current line begins with 'else':
 elseif line =~ '^\s*else\>'
   if lline !~ '^\s*\(if\|then\)\>'
     return s:FindPair('\<if\>', '', '\<else\>')
   endif

 " Indent if current line begins with 'then':
 elseif line =~ '^\s*then\>'
   if lline !~ '^\s*\(if\|else\)\>'
     return s:FindPair('\<if\>', '', '\<then\>')
   endif

 " Indent if current line begins with 'and':
 elseif line =~ '^\s*and\>'
   if lline !~ '^\s*\(and\|let\|type\)\>\|\<end\s*$'
     return ind - shiftwidth()
   endif

 " Indent if current line begins with 'with':
 elseif line =~ '^\s*with\>'
   if lline !~ '^\s*\(match\|try\)\>'
     return s:FindPair('\<\%(match\|try\)\>', '','\<with\>')
   endif

 " Indent if current line begins with 'exception', 'external', 'include' or
 " 'open':
 elseif line =~ '^\s*\(exception\|external\|include\|open\)\>'
   if lline !~ s:lim . '\|' . s:letlim
     call search(line)
     return indent(search('^\s*\(\(exception\|external\|include\|open\|type\)\>\|val\>.*:\)', 'bW'))
   endif

 " Indent if current line begins with 'val':
 elseif line =~ '^\s*val\>'
   if lline !~ '^\s*\(exception\|external\|include\|open\)\>\|' . s:obj . '\|' . s:letlim
     return indent(search('^\s*\(\(exception\|include\|initializer\|method\|open\|type\|val\)\>\|external\>.*:\)', 'bW'))
   endif

 " Indent if current line begins with 'constraint', 'inherit', 'initializer'
 " or 'method':
 elseif line =~ '^\s*\(constraint\|inherit\|initializer\|method\)\>'
   if lline !~ s:obj
     return indent(search('\<\(object\|object\s*(.*)\)\s*$', 'bW')) + shiftwidth()
   endif

 endif

 " Add a 'shiftwidth' after lines ending with:
 if lline =~ '\(:\|=\|->\|<-\|(\|\[\|{\|{<\|\[|\|\[<\|\<\(begin\|do\|else\|fun\|function\|functor\|if\|initializer\|object\|parser\|private\|sig\|struct\|then\|try\)\|\<object\s*(.*)\)\s*$'
   let ind = ind + shiftwidth()

 " Back to normal indent after lines ending with ';;':
 elseif lline =~ ';;\s*$' && lline !~ '^\s*;;'
   let ind = s:GetInd(v:lnum, s:letpat, s:letlim)

 " Back to normal indent after lines ending with 'end':
 elseif lline =~ '\<end\s*$'
   let ind = s:FindPair(s:module, '','\<end\>')

 " Back to normal indent after lines ending with 'in':
 elseif lline =~ '\<in\s*$' && lline !~ '^\s*in\>'
   let ind = s:FindPair('\<let\>', '', '\<in\>')

 " Back to normal indent after lines ending with 'done':
 elseif lline =~ '\<done\s*$'
   let ind = s:FindPair('\<do\>', '','\<done\>')

 " Back to normal indent after lines ending with '}' or '>}':
 elseif lline =~ '\(\|>\)}\s*$'
   let ind = s:FindPair('{', '','}')

 " Back to normal indent after lines ending with ']', '|]' or '>]':
 elseif lline =~ '\(\||\|>\)\]\s*$'
   let ind = s:FindPair('\[', '','\]')

 " Back to normal indent after comments:
 elseif lline =~ '\*)\s*$'
   call search('\*)', 'bW')
   let ind = indent(searchpair('(\*', '', '\*)', 'bWn', 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"'))

 " Back to normal indent after lines ending with ')':
 elseif lline =~ ')\s*$'
   let ind = s:FindPair('(', '',')')

 " If this is a multiline comment then align '*':
 elseif lline =~ '^\s*(\*' && line =~ '^\s*\*'
   let ind = ind + 1

 else
 " Don't change indentation of this line
 " for new lines (indent==0) use indentation of previous line

 " This is for preventing removing indentation of these args:
 "   let f x =
 "     let y = x + 1 in
 "     Printf.printf
 "       "o"           << here
 "       "oeuth"       << don't touch indentation

   let i = indent(v:lnum)
   return i == 0 ? ind : i

 endif

 " Subtract a 'shiftwidth' after lines matching 'match ... with parser':
 if lline =~ '\<match\>.*\<with\>\s*\<parser\s*$'
   let ind = ind - shiftwidth()
 endif

 return ind

endfunction

" vim:sw=2
