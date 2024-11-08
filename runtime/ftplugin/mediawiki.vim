" Language: MediaWiki
" Maintainer: Avid Seeker <avidseeker7@protonmail.com>
" Home: http://en.wikipedia.org/wiki/Wikipedia:Text_editor_support#Vim
" Last Change: 2024 Jul 14
" Credits: chikamichi
"

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

" Many MediaWiki wikis prefer line breaks only at the end of paragraphs
" (like in a text processor), which results in long, wrapping lines.
setlocal wrap linebreak
setlocal textwidth=0

setlocal formatoptions-=tc formatoptions+=l formatoptions+=roq
setlocal matchpairs+=<:>

" Treat lists, indented text and tables as comment lines and continue with the
" same formatting in the next line (i.e. insert the comment leader) when hitting
" <CR> or using "o".
setlocal comments=n:#,n:*,n:\:,s:{\|,m:\|,ex:\|},s:<!--,m:\ \ \ \ ,e:-->
setlocal commentstring=<!--\ %s\ -->

" match HTML tags (taken directly from $VIM/ftplugin/html.vim)
if exists("loaded_matchit")
    let b:match_ignorecase=0
    let b:match_skip = 's:Comment'
    let b:match_words = '<:>,' .
    \ '<\@<=[ou]l\>[^>]*\%(>\|$\):<\@<=li\>:<\@<=/[ou]l>,' .
    \ '<\@<=dl\>[^>]*\%(>\|$\):<\@<=d[td]\>:<\@<=/dl>,' .
    \ '<\@<=\([^/][^ \t>]*\)[^>]*\%(>\|$\):<\@<=/\1>'
endif

" Enable folding based on ==sections==
setlocal foldexpr=getline(v:lnum)=~'^\\(=\\+\\)[^=]\\+\\1\\(\\s*<!--.*-->\\)\\=\\s*$'?\">\".(len(matchstr(getline(v:lnum),'^=\\+'))-1):\"=\"
setlocal foldmethod=expr

let b:undo_ftplugin = "setl commentstring< comments< formatoptions< foldexpr< foldmethod<"
let b:undo_ftplugin += " matchpairs< linebreak< wrap< textwidth<"
