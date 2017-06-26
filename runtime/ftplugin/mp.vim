" Vim filetype plugin file
" Language:           MetaPost
" Maintainer:         Nicola Vitacolonna <nvitacolonna@gmail.com>
" Former Maintainers: Nikolai Weibull <now@bitwi.se>
" Latest Revision:    2016 Oct 2

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< fo< sua< inc< def< ofu<"
      \ . "| unlet! b:match_ignorecase b:match_words b:match_skip"

setlocal comments=:% commentstring=%\ %s formatoptions-=t formatoptions+=cjroql2
setlocal suffixesadd=.mp,.mpiv
let &l:include = '\<\%(input\|loadmodule\)\>' " loadmodule is in MetaFun
let &l:define = '\<\%(let\|newinternal\|interim\|def\|vardef\)\>\|\<\%(primary\|secondary\|tertiary\)def\>\s*[^ .]\+'
setlocal omnifunc=syntaxcomplete#Complete
let g:omni_syntax_group_include_mp = 'mf\w\+,mp\w\+'
let g:omni_syntax_group_exclude_mp = 'mfTodoComment'

if exists(":FixBeginfigs") != 2
  command -nargs=0 FixBeginfigs call s:fix_beginfigs()

  function! s:fix_beginfigs()
    let i = 1
    g/^beginfig(\d*);$/s//\='beginfig('.i.');'/ | let i = i + 1
  endfunction
endif

let s:mp_regex = {
      \ 'beginsection' : '^\s*\%(\%(\|var\|primary\|secondary\|tertiary\)def\|begin\%(fig\|char\|logochar\|glyph\|graph\)\)\>',
      \ 'endsection'   : '^\s*\%(enddef\|end\%(fig\|char\|glyph\|graph\)\)\>',
      \ 'beginblock'   : '^\s*\%(begingroup\|if\|for\%(\|suffixes\|ever\)\)\>',
      \ 'endblock'     : '^\s*\%(endgroup\|fi\|endfor\)\>'
      \ }

function! s:move_around(count, what, flags, visual)
  if a:visual
    exe "normal! gv"
  endif
  call search(s:mp_regex[a:what], a:flags.'s') " 's' sets previous context mark
  call map(range(2, a:count), 'search(s:mp_regex[a:what], a:flags)')
endfunction


" Move around macros.
nnoremap <silent><buffer> [[ :<C-U>call <SID>move_around(v:count1, "beginsection", "bW", v:false) <CR>
vnoremap <silent><buffer> [[ :<C-U>call <SID>move_around(v:count1, "beginsection", "bW", v:true)  <CR>
nnoremap <silent><buffer> ]] :<C-U>call <SID>move_around(v:count1, "beginsection", "W",  v:false) <CR>
vnoremap <silent><buffer> ]] :<C-U>call <SID>move_around(v:count1, "beginsection", "W",  v:true)  <CR>
nnoremap <silent><buffer> [] :<C-U>call <SID>move_around(v:count1, "endsection",   "bW", v:false) <CR>
vnoremap <silent><buffer> [] :<C-U>call <SID>move_around(v:count1, "endsection",   "bW", v:true)  <CR>
nnoremap <silent><buffer> ][ :<C-U>call <SID>move_around(v:count1, "endsection",   "W",  v:false) <CR>
vnoremap <silent><buffer> ][ :<C-U>call <SID>move_around(v:count1, "endsection",   "W",  v:true)  <CR>
nnoremap <silent><buffer> [{ :<C-U>call <SID>move_around(v:count1, "beginblock",   "bW", v:false) <CR>
vnoremap <silent><buffer> [{ :<C-U>call <SID>move_around(v:count1, "beginblock",   "bW", v:true)  <CR>
nnoremap <silent><buffer> ]} :<C-U>call <SID>move_around(v:count1, "endblock",     "W",  v:false) <CR>
vnoremap <silent><buffer> ]} :<C-U>call <SID>move_around(v:count1, "endblock",     "W",  v:true)  <CR>

if exists("loaded_matchit")
  let b:match_ignorecase = 0
  let b:match_words =
        \ '\<if\>:\<else\%[if]\>:\<fi\>,' .
        \ '\<for\%(\|suffixes\|ever\)\>:\<exit\%(if\|unless\)\>:\<endfor\>,' .
        \ '\<\%(\|var\|primary\|secondary\|tertiary\)def\>:\<enddef\>,' .
        \ '\<beginfig\>:\<endfig\>,' .
        \ '\<begingroup\>:\<endgroup\>,' .
        \ '\<begin\%(logo\)\?char\>:\<endchar\>,' .
        \ '\<beginglyph\>:\<endglyph\>,' .
        \ '\<begingraph\>:\<endgraph\>'
  " Ignore comments and strings
  let b:match_skip = 'synIDattr(synID(line("."), col("."), 1), "name")
        \ =~# "^mf\\%(Comment\\|String\\|\\)$\\|^mpTeXinsert$"'
endif

let &cpo = s:cpo_save
unlet s:cpo_save
