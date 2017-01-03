" Vim indent file
" Language: Javascript
" Maintainer: vim-javascript community
" URL: https://github.com/pangloss/vim-javascript
" Last Change: August 12, 2016

" Only load this indent file when no other was loaded.
if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

" Now, set up our indentation expression and keys that trigger it.
setlocal indentexpr=GetJavascriptIndent()
setlocal nolisp
setlocal indentkeys=0{,0},0),0],:,!^F,o,O,e
setlocal cinoptions+=j1,J1

let b:undo_indent = 'setlocal indentexpr< indentkeys< cinoptions<'

" Only define the function once.
if exists('*GetJavascriptIndent')
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" Get shiftwidth value
if exists('*shiftwidth')
  function s:sw()
    return shiftwidth()
  endfunction
else
  function s:sw()
    return &sw
  endfunction
endif

let s:line_pre = '^\s*\%(\/\*.\{-}\*\/\s*\)*'
let s:expr_case = s:line_pre . '\%(\%(case\>.\+\)\|default\)\s*:'
" Regex of syntax group names that are or delimit string or are comments.
let s:syng_strcom = '\%(s\%(tring\|pecial\)\|comment\|regex\|doc\|template\)'

" Regex of syntax group names that are strings or documentation.
let s:syng_comment = '\%(comment\|doc\)'

" Expression used to check whether we should skip a match with searchpair().
let s:skip_expr = "line('.') < (prevnonblank(v:lnum) - 2000) ? dummy : synIDattr(synID(line('.'),col('.'),0),'name') =~? '".s:syng_strcom."'"

function s:lookForParens(start,end,flags,time)
  if has('reltime')
    return searchpair(a:start,'',a:end,a:flags,s:skip_expr,0,a:time)
  else
    return searchpair(a:start,'',a:end,a:flags,0,0)
  endif
endfunction

let s:line_term = '\%(\s*\%(\/\*.\{-}\*\/\s*\)\=\)\@>$'

" configurable regexes that define continuation lines, not including (, {, or [.
if !exists('g:javascript_opfirst')
  let g:javascript_opfirst = '\%([<>,:?^%]\|\([-/.+]\)\%(\1\|\*\|\/\)\@!\|\*\/\@!\|=>\@!\||\|&\|in\%(stanceof\)\=\>\)'
endif
let g:javascript_opfirst = s:line_pre . g:javascript_opfirst

if !exists('g:javascript_continuation')
  let g:javascript_continuation = '\%([<*,.?:^%]\|+\@<!+\|-\@<!-\|=\@<!>\|\*\@<!\/\|=\||\|&\|\<in\%(stanceof\)\=\)'
endif
let g:javascript_continuation .= s:line_term

function s:Onescope(lnum,text,add)
  return a:text =~# '\%(\<else\|\<do\|=>' . (a:add ? '\|\<try\|\<finally' : '' ) . '\)' . s:line_term ||
        \ ((a:add && a:text =~ s:line_pre . '$' && search('\%' . s:PrevCodeLine(a:lnum - 1) . 'l.)' . s:line_term)) ||
        \ cursor(a:lnum, match(a:text, ')' . s:line_term)) > -1) &&
        \ s:lookForParens('(', ')', 'cbW', 100) > 0 && search((a:add ?
        \ '\%(function\*\|[[:lower:][:upper:]_$][[:digit:][:lower:][:upper:]_$]*\)' :
        \ '\<\%(for\%(\s\+each\)\=\|if\|let\|w\%(hile\|ith\)\)') . '\_s*\%#\C','bW') &&
        \ (a:add || (expand('<cword>') ==# 'while' ? !s:lookForParens('\<do\>\C', '\<while\>\C','bW',100) : 1))
endfunction

" Auxiliary Functions {{{2

" strip line of comment
function s:StripLine(c)
  return a:c !~# s:expr_case ? substitute(a:c, '\%(:\@<!\/\/.*\)$', '','') : a:c
endfunction

" Find line above 'lnum' that isn't empty, in a comment, or in a string.
function s:PrevCodeLine(lnum)
  let l:lnum = prevnonblank(a:lnum)
  while l:lnum > 0
    if synIDattr(synID(l:lnum,matchend(getline(l:lnum), '^\s*[^''"]'),0),'name') !~? s:syng_strcom
      break
    endif
    let l:lnum = prevnonblank(l:lnum - 1)
  endwhile
  return l:lnum
endfunction

" Check if line 'lnum' has a balanced amount of parentheses.
function s:Balanced(lnum)
  let open_0 = 0
  let open_2 = 0
  let open_4 = 0
  let l:line = getline(a:lnum)
  let pos = match(l:line, '[][(){}]', 0)
  while pos != -1
    if synIDattr(synID(a:lnum,pos + 1,0),'name') !~? s:syng_strcom
      let idx = stridx('(){}[]', l:line[pos])
      if idx % 2 == 0
        let open_{idx} = open_{idx} + 1
      else
        let open_{idx - 1} = open_{idx - 1} - 1
      endif
    endif
    let pos = match(l:line, '[][(){}]', pos + 1)
  endwhile
  return (!open_4 + !open_2 + !open_0) - 2
endfunction
" }}}

function GetJavascriptIndent()
  if !exists('b:js_cache')
    let b:js_cache = [0,0,0]
  endif
  " Get the current line.
  let l:line = getline(v:lnum)
  let syns = synIDattr(synID(v:lnum, 1, 0), 'name')

  " start with strings,comments,etc.{{{2
  if (l:line !~ '^[''"`]' && syns =~? 'string\|template') ||
        \ (l:line !~ '^\s*[/*]' && syns =~? s:syng_comment)
    return -1
  endif
  if l:line !~ '^\%(\/\*\|\s*\/\/\)' && syns =~? s:syng_comment
    return cindent(v:lnum)
  endif
  let l:lnum = s:PrevCodeLine(v:lnum - 1)
  if l:lnum == 0
    return 0
  endif

  if (l:line =~# s:expr_case)
    let cpo_switch = &cpo
    set cpo+=%
    let ind = cindent(v:lnum)
    let &cpo = cpo_switch
    return ind
  endif
  "}}}

  " the containing paren, bracket, curly. Memoize, last lineNr either has the
  " same scope or starts a new one, unless if it closed a scope.
  call cursor(v:lnum,1)
  if b:js_cache[0] >= l:lnum  && b:js_cache[0] <= v:lnum && b:js_cache[0] &&
        \ (b:js_cache[0] > l:lnum || s:Balanced(l:lnum) > 0)
    let num = b:js_cache[1]
  elseif syns != '' && l:line[0] =~ '\s'
    let pattern = syns =~? 'block' ? ['{','}'] : syns =~? 'jsparen' ? ['(',')'] :
          \ syns =~? 'jsbracket'? ['\[','\]'] : ['[({[]','[])}]']
    let num = s:lookForParens(pattern[0],pattern[1],'bW',2000)
  else
    let num = s:lookForParens('[({[]','[])}]','bW',2000)
  endif
  let b:js_cache = [v:lnum,num,line('.') == v:lnum ? b:js_cache[2] : col('.')]

  if l:line =~ s:line_pre . '[])}]'
    return indent(num)
  endif

  let pline = s:StripLine(getline(l:lnum))
  let inb = num == 0 ? 1 : (s:Onescope(num, s:StripLine(strpart(getline(num),0,b:js_cache[2] - 1)),1) ||
        \ (l:line !~ s:line_pre . ',' && pline !~ ',' . s:line_term)) && num < l:lnum
  let switch_offset = (!inb || num == 0) || expand("<cword>") !=# 'switch' ? 0 : &cino !~ ':' || !has('float') ?  s:sw() :
        \ float2nr(str2float(matchstr(&cino,'.*:\zs[-0-9.]*')) * (&cino =~# '.*:[^,]*s' ? s:sw() : 1))

  " most significant, find the indent amount
  if (inb && (l:line =~# g:javascript_opfirst ||
        \ (pline =~# g:javascript_continuation && pline !~# s:expr_case && (pline !~ ':' . s:line_term || l:line !~#
        \ s:line_pre . '\%(d\%(o\|ebugger\)\|else\|f\%(or\|inally\)\|if\|let\|switch\|t\%(hrow\|ry\)\|w\%(hile\|ith\)\)\>')))) ||
        \ (num < l:lnum && s:Onescope(l:lnum,pline,0) && l:line !~ s:line_pre . '{')
    return (num > 0 ? indent(num) : -s:sw()) + (s:sw() * 2) + switch_offset
  elseif num > 0
    return indent(num) + s:sw() + switch_offset
  endif

endfunction


let &cpo = s:cpo_save
unlet s:cpo_save
