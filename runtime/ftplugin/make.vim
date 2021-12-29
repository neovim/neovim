" Vim filetype plugin file
" Language:	Make
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2020 Oct 16

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl et< sts< sw< fo< com< cms< inc<"

" Make sure a hard tab is used, required for most make programs
setlocal noexpandtab softtabstop=0 shiftwidth=0

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal fo-=t fo+=croql

" Set 'comments' to format dashed lists in comments
setlocal com=sO:#\ -,mO:#\ \ ,b:#

" Set 'commentstring' to put the marker after a #.
setlocal commentstring=#\ %s

" Including files.
let &l:include = '^\s*include'

" For matchit.vim, suggested by Albert Netymk and Ken Takata.
if exists("loaded_matchit")
  let b:match_words = '^ *ifn\=\(eq\|def\)\>:^ *else\(\s\+ifn\=\(eq\|def\)\)\=\>:^ *endif\>,\<define\>:\<endef\>,^!\s*if\(n\=def\)\=\>:^!\s*else\(if\(n\=def\)\=\)\=\>:^!\s*endif\>'
endif
