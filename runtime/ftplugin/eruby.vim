" Vim filetype plugin
" Language:		eRuby
" Maintainer:		Tim Pope <vimNOSPAM@tpope.org>
" URL:			https://github.com/vim-ruby/vim-ruby
" Release Coordinator:	Doug Kearns <dougkearns@gmail.com>
" Last Change:		2020 Jun 28

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

let s:save_cpo = &cpo
set cpo-=C

" Define some defaults in case the included ftplugins don't set them.
let s:undo_ftplugin = ""
let s:browsefilter = "All Files (*.*)\t*.*\n"
let s:match_words = ""

if !exists("g:eruby_default_subtype")
  let g:eruby_default_subtype = "html"
endif

if &filetype =~ '^eruby\.'
  let b:eruby_subtype = matchstr(&filetype,'^eruby\.\zs\w\+')
elseif !exists("b:eruby_subtype")
  let s:lines = getline(1)."\n".getline(2)."\n".getline(3)."\n".getline(4)."\n".getline(5)."\n".getline("$")
  let b:eruby_subtype = matchstr(s:lines,'eruby_subtype=\zs\w\+')
  if b:eruby_subtype == ''
    let b:eruby_subtype = matchstr(substitute(expand("%:t"),'\c\%(\.erb\|\.eruby\|\.erubis\|\.example\)\+$','',''),'\.\zs\w\+\%(\ze+\w\+\)\=$')
  endif
  if b:eruby_subtype == 'rhtml'
    let b:eruby_subtype = 'html'
  elseif b:eruby_subtype == 'rb'
    let b:eruby_subtype = 'ruby'
  elseif b:eruby_subtype == 'yml'
    let b:eruby_subtype = 'yaml'
  elseif b:eruby_subtype == 'js'
    let b:eruby_subtype = 'javascript'
  elseif b:eruby_subtype == 'txt'
    " Conventional; not a real file type
    let b:eruby_subtype = 'text'
  elseif b:eruby_subtype == ''
    let b:eruby_subtype = g:eruby_default_subtype
  endif
endif

if exists("b:eruby_subtype") && b:eruby_subtype != '' && b:eruby_subtype !=? 'eruby'
  exe "runtime! ftplugin/".b:eruby_subtype.".vim ftplugin/".b:eruby_subtype."_*.vim ftplugin/".b:eruby_subtype."/*.vim"
else
  runtime! ftplugin/html.vim ftplugin/html_*.vim ftplugin/html/*.vim
endif
unlet! b:did_ftplugin

" Override our defaults if these were set by an included ftplugin.
if exists("b:undo_ftplugin")
  let s:undo_ftplugin = b:undo_ftplugin
  unlet b:undo_ftplugin
endif
if exists("b:browsefilter")
  let s:browsefilter = b:browsefilter
  unlet b:browsefilter
endif
if exists("b:match_words")
  let s:match_words = b:match_words
  unlet b:match_words
endif

let s:cfilemap = v:version >= 704 ? maparg('<Plug><cfile>', 'c', 0, 1) : {}
if !get(s:cfilemap, 'buffer') || !s:cfilemap.expr || s:cfilemap.rhs =~# 'ErubyAtCursor()'
  let s:cfilemap = {}
endif
if !has_key(s:cfilemap, 'rhs')
  let s:cfilemap.rhs = "substitute(&l:inex =~# '\\<v:fname\\>' && len(expand('<cfile>')) ? eval(substitute(&l:inex, '\\<v:fname\\>', '\\=string(expand(\"<cfile>\"))', 'g')) : '', '^$', \"\\022\\006\",'')"
endif
let s:ctagmap = v:version >= 704 ? maparg('<Plug><ctag>', 'c', 0, 1) : {}
if !get(s:ctagmap, 'buffer') || !s:ctagmap.expr || s:ctagmap.rhs =~# 'ErubyAtCursor()'
  let s:ctagmap = {}
endif
let s:include = &l:include
let s:path = &l:path
let s:suffixesadd = &l:suffixesadd

runtime! ftplugin/ruby.vim ftplugin/ruby_*.vim ftplugin/ruby/*.vim
let b:did_ftplugin = 1

" Combine the new set of values with those previously included.
if exists("b:undo_ftplugin")
  let s:undo_ftplugin = b:undo_ftplugin . " | " . s:undo_ftplugin
endif
if exists ("b:browsefilter")
  let s:browsefilter = substitute(b:browsefilter,'\cAll Files (\*\.\*)\t\*\.\*\n','','') . s:browsefilter
endif
if exists("b:match_words")
  let s:match_words = b:match_words . ',' . s:match_words
endif

if len(s:include)
  let &l:include = s:include
endif
let &l:path = s:path . (s:path =~# ',$\|^$' ? '' : ',') . &l:path
let &l:suffixesadd = s:suffixesadd . (s:suffixesadd =~# ',$\|^$' ? '' : ',') . &l:suffixesadd
exe 'cmap <buffer><script><expr> <Plug><cfile> ErubyAtCursor() ? ' . maparg('<Plug><cfile>', 'c') . ' : ' . s:cfilemap.rhs
exe 'cmap <buffer><script><expr> <Plug><ctag> ErubyAtCursor() ? ' . maparg('<Plug><ctag>', 'c') . ' : ' . get(s:ctagmap, 'rhs', '"\022\027"')
unlet s:cfilemap s:ctagmap s:include s:path s:suffixesadd

" Change the browse dialog on Win32 to show mainly eRuby-related files
if has("gui_win32")
  let b:browsefilter="eRuby Files (*.erb, *.rhtml)\t*.erb;*.rhtml\n" . s:browsefilter
endif

" Load the combined list of match_words for matchit.vim
if exists("loaded_matchit")
  let b:match_words = s:match_words
endif

" TODO: comments=
setlocal commentstring=<%#%s%>

let b:undo_ftplugin = "setl cms< " .
      \ " | unlet! b:browsefilter b:match_words | " . s:undo_ftplugin

let &cpo = s:save_cpo
unlet s:save_cpo

function! ErubyAtCursor() abort
  let groups = map(['erubyBlock', 'erubyComment', 'erubyExpression', 'erubyOneLiner'], 'hlID(v:val)')
  return !empty(filter(synstack(line('.'), col('.')), 'index(groups, v:val) >= 0'))
endfunction

" vim: nowrap sw=2 sts=2 ts=8:
