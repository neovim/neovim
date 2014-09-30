" Vim filetype plugin
" Language:    Hamster Script
" Version:     2.0.6.0
" Maintainer:  David Fishburn <fishburn@ianywhere.com>
" Last Change: Wed Nov 08 2006 12:03:09 PM

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo-=C

let b:undo_ftplugin = "setl fo< com< tw< commentstring<"
	\ . "| unlet! b:match_ignorecase b:match_words b:match_skip"

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal fo-=t fo+=croql

" Use the # sign for comments
setlocal comments=:#

" Format comments to be up to 78 characters long
if &tw == 0
  setlocal tw=78
endif

" Comments start with a double quote
setlocal commentstring=#%s

" Move around functions.
noremap <silent><buffer> [[ :call search('^\s*sub\>', "bW")<CR>
noremap <silent><buffer> ]] :call search('^\s*sub\>', "W")<CR>
noremap <silent><buffer> [] :call search('^\s*endsub\>', "bW")<CR>
noremap <silent><buffer> ][ :call search('^\s*endsub\>', "W")<CR>

" Move around comments
noremap <silent><buffer> ]# :call search('^\s*#\@!', "W")<CR>
noremap <silent><buffer> [# :call search('^\s*#\@!', "bW")<CR>

" Let the matchit plugin know what items can be matched.
if exists("loaded_matchit")
  let b:match_ignorecase = 0
  let b:match_words =
	\ '\<sub\>:\<return\>:\<endsub\>,' .
        \ '\<do\|while\|repeat\|for\>:\<break\>:\<continue\>:\<loop\|endwhile\|until\|endfor\>,' .
	\ '\<if\>:\<else\%[if]\>:\<endif\>' 

  " Ignore ":syntax region" commands, the 'end' argument clobbers if-endif
  " let b:match_skip = 'getline(".") =~ "^\\s*sy\\%[ntax]\\s\\+region" ||
  "	\ synIDattr(synID(line("."),col("."),1),"name") =~? "comment\\|string"'
endif

setlocal ignorecase
let &cpo = s:cpo_save
unlet s:cpo_save
setlocal cpo+=M		" makes \%( match \)
