" Language: D script as described in "Solaris Dynamic Tracing Guide",
"           http://docs.sun.com/app/docs/doc/817-6223
" Last Change: 2008/03/20
"              2024/05/23 by Riley Bruins <ribru17@gmail.com ('commentstring')
" Version: 1.2
" Maintainer: Nicolas Weber <nicolasweber@gmx.de>

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

" Using line continuation here.
let s:cpo_save = &cpo
set cpo-=C

let b:undo_ftplugin = "setl fo< com< cms< isk<"

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal fo-=t fo+=croql

" Set 'comments' to format dashed lists in comments.
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/

" dtrace uses /* */ comments. Set this explicitly, just in case the user
" changed this (/*\ %s\ */ is the default)
setlocal commentstring=/*\ %s\ */

setlocal iskeyword+=@,$

" When the matchit plugin is loaded, this makes the % command skip parens and
" braces in comments.
let b:match_words = &matchpairs
let b:match_skip = 's:comment\|string\|character'

let &cpo = s:cpo_save
unlet s:cpo_save
