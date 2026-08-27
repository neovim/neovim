" Vim indent file
" Language: Javascript
" Maintainer: Chris Paul ( https://github.com/bounceme )
" URL: https://github.com/pangloss/vim-javascript
" Last Change: 2025 Apr 13

" Only load this indent file when no other was loaded.
if exists('b:did_indent')
  finish
endif
let b:did_indent = 1

" Now, set up our indentation expression and keys that trigger it.
setlocal indentexpr=GetJavascriptIndent()
setlocal autoindent nolisp nosmartindent
setlocal indentkeys+=0],0)
" Testable with something like:
" vim  -eNs "+filetype plugin indent on" "+syntax on" "+set ft=javascript" \
"       "+norm! gg=G" '+%print' '+:q!' testfile.js \
"       | diff -uBZ testfile.js -

let b:undo_indent = 'setlocal indentexpr< smartindent< autoindent< indentkeys<'

" Only define the function once.
if exists('*GetJavascriptIndent')
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

" indent correctly if inside <script>
" vim/vim@690afe1 for the switch from cindent
" overridden with b:html_indent_script1
call extend(g:,{'html_indent_script1': 'inc'},'keep')

" Regex of syntax group names that are or delimit string or are comments.
let s:bvars = {
      \ 'syng_strcom': 'string\|comment\|regex\|special\|doc\|template\%(braces\)\@!',
      \ 'syng_str': 'string\|template\|special' }
" template strings may want to be excluded when editing graphql:
" au! Filetype javascript let b:syng_str = '^\%(.*template\)\@!.*string\|special'
" au! Filetype javascript let b:syng_strcom = '^\%(.*template\)\@!.*string\|comment\|regex\|special\|doc'

function s:GetVars()
  call extend(b:,extend(s:bvars,{'js_cache': [0,0,0]}),'keep')
endfunction

" Get shiftwidth value
if exists('*shiftwidth')
  function s:sw()
    return shiftwidth()
  endfunction
else
  function s:sw()
    return &l:shiftwidth ? &l:shiftwidth : &l:tabstop
  endfunction
endif

" Performance for forwards search(): start search at pos rather than masking
" matches before pos.
let s:z = has('patch-7.4.984') ? 'z' : ''

" Expression used to check whether we should skip a match with searchpair().
let s:skip_expr = "s:SynAt(line('.'),col('.')) =~? b:syng_strcom"
let s:in_comm = s:skip_expr[:-14] . "'comment\\|doc'"

let s:rel = has('reltime')
" searchpair() wrapper
if s:rel
  function s:GetPair(start,end,flags,skip)
    " VIM_INDENT_TEST_TRACE_START
    return searchpair('\m'.a:start,'','\m'.a:end,a:flags,a:skip,s:l1,a:skip ==# 's:SkipFunc()' ? 2000 : 200)
    " VIM_INDENT_TEST_TRACE_END s:GetPair
  endfunction
else
  function s:GetPair(start,end,flags,skip)
    return searchpair('\m'.a:start,'','\m'.a:end,a:flags,a:skip,s:l1)
  endfunction
endif

function s:SynAt(l,c)
  let byte = line2byte(a:l) + a:c - 1
  let pos = index(s:synid_cache[0], byte)
  if pos == -1
    let s:synid_cache[:] += [[byte], [synIDattr(synID(a:l, a:c, 0), 'name')]]
  endif
  return s:synid_cache[1][pos]
endfunction

function s:ParseCino(f)
  let [divider, n, cstr] = [0] + matchlist(&cino,
        \ '\%(.*,\)\=\%(\%d'.char2nr(a:f).'\(-\)\=\([.s0-9]*\)\)\=')[1:2]
  for c in split(cstr,'\zs')
    if c == '.' && !divider
      let divider = 1
    elseif c ==# 's'
      if n !~ '\d'
        return n . s:sw() + 0
      endif
      let n = str2nr(n) * s:sw()
      break
    else
      let [n, divider] .= [c, 0]
    endif
  endfor
  return str2nr(n) / max([str2nr(divider),1])
endfunction

" Optimized {skip} expr, only callable from the search loop which
" GetJavascriptIndent does to find the containing [[{(] (side-effects)
function s:SkipFunc()
  if s:top_col == 1
    throw 'out of bounds'
  elseif s:check_in
    if eval(s:skip_expr)
      return 1
    endif
    let s:check_in = 0
  elseif getline('.') =~ '\%<'.col('.').'c\/.\{-}\/\|\%>'.col('.').'c[''"]\|\\$'
    if eval(s:skip_expr)
      return 1
    endif
  elseif search('\m`\|\${\|\*\/','nW'.s:z,s:looksyn)
    if eval(s:skip_expr)
      let s:check_in = 1
      return 1
    endif
  else
    let s:synid_cache[:] += [[line2byte('.') + col('.') - 1], ['']]
  endif
  let [s:looksyn, s:top_col] = getpos('.')[1:2]
endfunction

function s:AlternatePair()
  let [pat, l:for] = ['[][(){};]', 2]
  while s:SearchLoop(pat,'bW','s:SkipFunc()')
    if s:LookingAt() == ';'
      if !l:for
        if s:GetPair('{','}','bW','s:SkipFunc()')
          return
        endif
        break
      else
        let [pat, l:for] = ['[{}();]', l:for - 1]
      endif
    else
      let idx = stridx('])}',s:LookingAt())
      if idx == -1
        return
      elseif !s:GetPair(['\[','(','{'][idx],'])}'[idx],'bW','s:SkipFunc()')
        break
      endif
    endif
  endwhile
  throw 'out of bounds'
endfunction

function s:Nat(int)
  return a:int * (a:int > 0)
endfunction

function s:LookingAt()
  return getline('.')[col('.')-1]
endfunction

function s:Token()
  return s:LookingAt() =~ '\k' ? expand('<cword>') : s:LookingAt()
endfunction

function s:PreviousToken(...)
  let [l:pos, tok] = [getpos('.'), '']
  if search('\m\k\{1,}\|\S','ebW')
    if getline('.')[col('.')-2:col('.')-1] == '*/'
      if eval(s:in_comm) && !s:SearchLoop('\S\ze\_s*\/[/*]','bW',s:in_comm)
        call setpos('.',l:pos)
      else
        let tok = s:Token()
      endif
    else
      let two = a:0 || line('.') != l:pos[1] ? strridx(getline('.')[:col('.')],'//') + 1 : 0
      if two && eval(s:in_comm)
        call cursor(0,two)
        let tok = s:PreviousToken(1)
        if tok is ''
          call setpos('.',l:pos)
        endif
      else
        let tok = s:Token()
      endif
    endif
  endif
  return tok
endfunction

function s:Pure(f,...)
  return eval("[call(a:f,a:000),cursor(a:firstline,".col('.').")][0]")
endfunction

function s:SearchLoop(pat,flags,expr)
  return s:GetPair(a:pat,'\_$.',a:flags,a:expr)
endfunction

function s:ExprCol()
  if getline('.')[col('.')-2] == ':'
    return 1
  endif
  let bal = 0
  while s:SearchLoop('[{}?:]','bW',s:skip_expr)
    if s:LookingAt() == ':'
      if getline('.')[col('.')-2] == ':'
        call cursor(0,col('.')-1)
        continue
      endif
      let bal -= 1
    elseif s:LookingAt() == '?'
      if getline('.')[col('.'):col('.')+1] =~ '^\.\d\@!'
        continue
      elseif !bal
        return 1
      endif
      let bal += 1
    elseif s:LookingAt() == '{'
      return !s:IsBlock()
    elseif !s:GetPair('{','}','bW',s:skip_expr)
      break
    endif
  endwhile
endfunction

" configurable regexes that define continuation lines, not including (, {, or [.
let s:opfirst = '^' . get(g:,'javascript_opfirst',
      \ '\C\%([<>=,.?^%|/&]\|\([-:+]\)\1\@!\|\*\+\|!=\|in\%(stanceof\)\=\>\)')
let s:continuation = get(g:,'javascript_continuation',
      \ '\C\%([<=,.~!?/*^%|&:]\|+\@<!+\|-\@<!-\|=\@<!>\|\<\%(typeof\|new\|delete\|void\|in\|instanceof\|await\)\)') . '$'

function s:Continues()
  let tok = matchstr(strpart(getline('.'),col('.')-15,15),s:continuation)
  if tok =~ '[a-z:]'
    return tok == ':' ? s:ExprCol() : s:PreviousToken() != '.'
  elseif tok !~ '[/>]'
    return tok isnot ''
  endif
  return s:SynAt(line('.'),col('.')) !~? (tok == '>' ? 'jsflow\|^html' : 'regex')
endfunction

" Check if line 'lnum' has a balanced amount of parentheses.
function s:Balanced(lnum,line)
  let l:open = 0
  let pos = match(a:line, '[][(){}]')
  while pos != -1
    if s:SynAt(a:lnum,pos + 1) !~? b:syng_strcom
      let l:open += match(' ' . a:line[pos],'[[({]')
      if l:open < 0
        return
      endif
    endif
    let pos = match(a:line, !l:open ? '[][(){}]' : '()' =~ a:line[pos] ?
          \ '[()]' : '{}' =~ a:line[pos] ? '[{}]' : '[][]', pos + 1)
  endwhile
  return !l:open
endfunction

function s:OneScope()
  if s:LookingAt() == ')' && s:GetPair('(', ')', 'bW', s:skip_expr)
    let tok = s:PreviousToken()
    return (count(split('for if let while with'),tok) ||
          \ tok =~# '^await$\|^each$' && s:PreviousToken() ==# 'for') &&
          \ s:Pure('s:PreviousToken') != '.' && !(tok == 'while' && s:DoWhile())
  elseif s:Token() =~# '^else$\|^do$'
    return s:Pure('s:PreviousToken') != '.'
  elseif strpart(getline('.'),col('.')-2,2) == '=>'
    call cursor(0,col('.')-1)
    if s:PreviousToken() == ')'
      return s:GetPair('(', ')', 'bW', s:skip_expr)
    endif
    return 1
  endif
endfunction

function s:DoWhile()
  let cpos = searchpos('\m\<','cbW')
  while s:SearchLoop('\C[{}]\|\<\%(do\|while\)\>','bW',s:skip_expr)
    if s:LookingAt() =~ '\a'
      if s:Pure('s:IsBlock')
        if s:LookingAt() ==# 'd'
          return 1
        endif
        break
      endif
    elseif s:LookingAt() != '}' || !s:GetPair('{','}','bW',s:skip_expr)
      break
    endif
  endwhile
  call call('cursor',cpos)
endfunction

" returns total offset from braceless contexts. 'num' is the lineNr which
" encloses the entire context, 'cont' if whether a:firstline is a continued
" expression, which could have started in a braceless context
function s:IsContOne(cont)
  let [l:num, b_l] = [b:js_cache[1] + !b:js_cache[1], 0]
  let pind = b:js_cache[1] ? indent(b:js_cache[1]) + s:sw() : 0
  let ind = indent('.') + !a:cont
  while line('.') > l:num && ind > pind || line('.') == l:num
    if indent('.') < ind && s:OneScope()
      let b_l += 1
    elseif !a:cont || b_l || ind < indent(a:firstline)
      break
    else
      call cursor(0,1)
    endif
    let ind = min([ind, indent('.')])
    if s:PreviousToken() is ''
      break
    endif
  endwhile
  return b_l
endfunction

function s:IsSwitch()
  call call('cursor',b:js_cache[1:])
  return search('\m\C\%#.\_s*\%(\%(\/\/.*\_$\|\/\*\_.\{-}\*\/\)\@>\_s*\)*\%(case\|default\)\>','nWc'.s:z)
endfunction

" https://github.com/sweet-js/sweet.js/wiki/design#give-lookbehind-to-the-reader
function s:IsBlock()
  let tok = s:PreviousToken()
  if join(s:stack) =~? 'xml\|jsx' && s:SynAt(line('.'),col('.')-1) =~? 'xml\|jsx'
    let s:in_jsx = 1
    return tok != '{'
  elseif tok =~ '\k'
    if tok ==# 'type'
      return s:Pure('eval',"s:PreviousToken() !~# '^\\%(im\\|ex\\)port$' || s:PreviousToken() == '.'")
    elseif tok ==# 'of'
      return s:Pure('eval',"!s:GetPair('[[({]','[])}]','bW',s:skip_expr) || s:LookingAt() != '(' ||"
            \ ."s:{s:PreviousToken() ==# 'await' ? 'Previous' : ''}Token() !=# 'for' || s:PreviousToken() == '.'")
    endif
    return index(split('return const let import export extends yield default delete var await void typeof throw case new in instanceof')
          \ ,tok) < (line('.') != a:firstline) || s:Pure('s:PreviousToken') == '.'
  elseif tok == '>'
    return getline('.')[col('.')-2] == '=' || s:SynAt(line('.'),col('.')) =~? 'jsflow\|^html'
  elseif tok == '*'
    return s:Pure('s:PreviousToken') == ':'
  elseif tok == ':'
    return s:Pure('eval',"s:PreviousToken() =~ '^\\K\\k*$' && !s:ExprCol()")
  elseif tok == '/'
    return s:SynAt(line('.'),col('.')) =~? 'regex'
  elseif tok !~ '[=~!<,.?^%|&([]'
    return tok !~ '[-+]' || line('.') != a:firstline && getline('.')[col('.')-2] == tok
  endif
endfunction

function GetJavascriptIndent()
  call s:GetVars()
  let s:synid_cache = [[],[]]
  let l:line = getline(v:lnum)
  " use synstack as it validates syn state and works in an empty line
  let s:stack = [''] + map(synstack(v:lnum,1),"synIDattr(v:val,'name')")

  " start with strings,comments,etc.
  if s:stack[-1] =~? 'comment\|doc'
    if l:line =~ '^\s*\*'
      return cindent(v:lnum)
    elseif l:line !~ '^\s*\/[/*]'
      return -1
    endif
  elseif s:stack[-1] =~? b:syng_str
    if b:js_cache[0] == v:lnum - 1 && s:Balanced(v:lnum-1,getline(v:lnum-1))
      let b:js_cache[0] = v:lnum
    endif
    return -1
  endif

  let s:l1 = max([0,prevnonblank(v:lnum) - (s:rel ? 2000 : 1000),
        \ get(get(b:,'hi_indent',{}),'blocklnr')])
  call cursor(v:lnum,1)
  if s:PreviousToken() is ''
    return
  endif
  let [l:lnum, pline] = [line('.'), getline('.')[:col('.')-1]]

  let l:line = substitute(l:line,'^\s*','','')
  let l:line_raw = l:line
  if l:line[:1] == '/*'
    let l:line = substitute(l:line,'^\%(\/\*.\{-}\*\/\s*\)*','','')
  endif
  if l:line =~ '^\/[/*]'
    let l:line = ''
  endif

  " the containing paren, bracket, or curly. Many hacks for performance
  call cursor(v:lnum,1)
  let idx = index([']',')','}'],l:line[0])
  if b:js_cache[0] > l:lnum && b:js_cache[0] < v:lnum ||
        \ b:js_cache[0] == l:lnum && s:Balanced(l:lnum,pline)
    call call('cursor',b:js_cache[1:])
  else
    let [s:looksyn, s:top_col, s:check_in, s:l1] = [v:lnum - 1,0,0,
          \ max([s:l1, &smc ? search('\m^.\{'.&smc.',}','nbW',s:l1 + 1) + 1 : 0])]
    try
      if idx != -1
        call s:GetPair(['\[','(','{'][idx],'])}'[idx],'bW','s:SkipFunc()')
      elseif getline(v:lnum) !~ '^\S' && s:stack[-1] =~? 'block\|^jsobject$'
        call s:GetPair('{','}','bW','s:SkipFunc()')
      else
        call s:AlternatePair()
      endif
    catch /^\Cout of bounds$/
      call cursor(v:lnum,1)
    endtry
    let b:js_cache[1:] = line('.') == v:lnum ? [0,0] : getpos('.')[1:2]
  endif

  let [b:js_cache[0], num] = [v:lnum, b:js_cache[1]]

  let [num_ind, is_op, b_l, l:switch_offset, s:in_jsx] = [s:Nat(indent(num)),0,0,0,0]
  if !num || s:LookingAt() == '{' && s:IsBlock()
    let ilnum = line('.')
    if num && !s:in_jsx && s:LookingAt() == ')' && s:GetPair('(',')','bW',s:skip_expr)
      if ilnum == num
        let [num, num_ind] = [line('.'), indent('.')]
      endif
      if idx == -1 && s:PreviousToken() ==# 'switch' && s:IsSwitch()
        let l:switch_offset = &cino !~ ':' ? s:sw() : s:ParseCino(':')
        if pline[-1:] != '.' && l:line =~# '^\%(default\|case\)\>'
          return s:Nat(num_ind + l:switch_offset)
        elseif &cino =~ '='
          let l:case_offset = s:ParseCino('=')
        endif
      endif
    endif
    if idx == -1 && pline[-1:] !~ '[{;]'
      call cursor(l:lnum, len(pline))
      let sol = matchstr(l:line,s:opfirst)
      if sol is '' || sol == '/' && s:SynAt(v:lnum,
            \ 1 + len(getline(v:lnum)) - len(l:line)) =~? 'regex'
        if s:Continues()
          let is_op = s:sw()
        endif
      elseif num && sol =~# '^\%(in\%(stanceof\)\=\|\*\)$' &&
            \ s:LookingAt() == '}' && s:GetPair('{','}','bW',s:skip_expr) &&
            \ s:PreviousToken() == ')' && s:GetPair('(',')','bW',s:skip_expr) &&
            \ (s:PreviousToken() == ']' || s:LookingAt() =~ '\k' &&
            \ s:{s:PreviousToken() == '*' ? 'Previous' : ''}Token() !=# 'function')
        return num_ind + s:sw()
      else
        let is_op = s:sw()
      endif
      call cursor(l:lnum, len(pline))
      let b_l = s:Nat(s:IsContOne(is_op) - (!is_op && l:line =~ '^{')) * s:sw()
    endif
  elseif idx.s:LookingAt().&cino =~ '^-1(.*(' && (search('\m\S','nbW',num) || s:ParseCino('U'))
    let pval = s:ParseCino('(')
    if !pval
      let [Wval, vcol] = [s:ParseCino('W'), virtcol('.')]
      if search('\m\S','W',num)
        return s:ParseCino('w') ? vcol : virtcol('.')-1
      endif
      return Wval ? s:Nat(num_ind + Wval) : vcol
    endif
    return s:Nat(num_ind + pval + searchpair('\m(','','\m)','nbrmW',s:skip_expr,num) * s:sw())
  endif

  " main return
  if l:line =~ '^[])}]\|^|}'
    if l:line_raw[0] == ')'
      if s:ParseCino('M')
        return indent(l:lnum)
      elseif num && &cino =~# 'm' && !s:ParseCino('m')
        return virtcol('.') - 1
      endif
    endif
    return num_ind
  elseif num
    return s:Nat(num_ind + get(l:,'case_offset',s:sw()) + l:switch_offset + b_l + is_op)
  endif

  let nest = get(get(b:, 'hi_indent', {}), 'blocklnr')
  if nest
    return indent(nextnonblank(nest + 1)) + b_l + is_op
  endif

  return b_l + is_op
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
