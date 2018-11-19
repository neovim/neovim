" Vim filetype plugin
" Language:	Vim
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2018 Aug 07

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo-=C

if !exists('*VimFtpluginUndo')
  func VimFtpluginUndo()
    setl fo< isk< com< tw< commentstring< keywordprg<
    if exists('b:did_add_maps')
      silent! nunmap <buffer> [[
      silent! vunmap <buffer> [[
      silent! nunmap <buffer> ]]
      silent! vunmap <buffer> ]]
      silent! nunmap <buffer> []
      silent! vunmap <buffer> []
      silent! nunmap <buffer> ][
      silent! vunmap <buffer> ][
      silent! nunmap <buffer> ]"
      silent! vunmap <buffer> ]"
      silent! nunmap <buffer> ["
      silent! vunmap <buffer> ["
     endif
    unlet! b:match_ignorecase b:match_words b:match_skip b:did_add_maps
  endfunc
endif

let b:undo_ftplugin = "call VimFtpluginUndo()"

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal fo-=t fo+=croql

" To allow tag lookup via CTRL-] for autoload functions, '#' must be a
" keyword character.  E.g., for netrw#Nread().
setlocal isk+=#

" Use :help to lookup the keyword under the cursor with K.
setlocal keywordprg=:help

" Set 'comments' to format dashed lists in comments
setlocal com=sO:\"\ -,mO:\"\ \ ,eO:\"\",:\"

" Format comments to be up to 78 characters long
if &tw == 0
  setlocal tw=78
endif

" Comments start with a double quote
setlocal commentstring=\"%s

" Prefer Vim help instead of manpages.
setlocal keywordprg=:help

if !exists("no_plugin_maps") && !exists("no_vim_maps")
  let b:did_add_maps = 1

  " Move around functions.
  nnoremap <silent><buffer> [[ m':call search('^\s*fu\%[nction]\>', "bW")<CR>
  vnoremap <silent><buffer> [[ m':<C-U>exe "normal! gv"<Bar>call search('^\s*fu\%[nction]\>', "bW")<CR>
  nnoremap <silent><buffer> ]] m':call search('^\s*fu\%[nction]\>', "W")<CR>
  vnoremap <silent><buffer> ]] m':<C-U>exe "normal! gv"<Bar>call search('^\s*fu\%[nction]\>', "W")<CR>
  nnoremap <silent><buffer> [] m':call search('^\s*endf\%[unction]\>', "bW")<CR>
  vnoremap <silent><buffer> [] m':<C-U>exe "normal! gv"<Bar>call search('^\s*endf\%[unction]\>', "bW")<CR>
  nnoremap <silent><buffer> ][ m':call search('^\s*endf\%[unction]\>', "W")<CR>
  vnoremap <silent><buffer> ][ m':<C-U>exe "normal! gv"<Bar>call search('^\s*endf\%[unction]\>', "W")<CR>

  " Move around comments
  nnoremap <silent><buffer> ]" :call search('^\(\s*".*\n\)\@<!\(\s*"\)', "W")<CR>
  vnoremap <silent><buffer> ]" :<C-U>exe "normal! gv"<Bar>call search('^\(\s*".*\n\)\@<!\(\s*"\)', "W")<CR>
  nnoremap <silent><buffer> [" :call search('\%(^\s*".*\n\)\%(^\s*"\)\@!', "bW")<CR>
  vnoremap <silent><buffer> [" :<C-U>exe "normal! gv"<Bar>call search('\%(^\s*".*\n\)\%(^\s*"\)\@!', "bW")<CR>
endif

" Let the matchit plugin know what items can be matched.
if exists("loaded_matchit")
  let b:match_ignorecase = 0
  let b:match_words =
	\ '\<fu\%[nction]\>:\<retu\%[rn]\>:\<endf\%[unction]\>,' .
 	\ '\<\(wh\%[ile]\|for\)\>:\<brea\%[k]\>:\<con\%[tinue]\>:\<end\(w\%[hile]\|fo\%[r]\)\>,' .
	\ '\<if\>:\<el\%[seif]\>:\<en\%[dif]\>,' .
	\ '\<try\>:\<cat\%[ch]\>:\<fina\%[lly]\>:\<endt\%[ry]\>,' .
	\ '\<aug\%[roup]\s\+\%(END\>\)\@!\S:\<aug\%[roup]\s\+END\>,'
  " Ignore syntax region commands and settings, any 'en*' would clobber
  " if-endif.
  " - set spl=de,en
  " - au! FileType javascript syntax region foldBraces start=/{/ end=/}/ …
  let b:match_skip = 'synIDattr(synID(line("."),col("."),1),"name")
        \ =~? "comment\\|string\\|vimSynReg\\|vimSet"'
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" removed this, because 'cpoptions' is a global option.
" setlocal cpo+=M		" makes \%( match \)
