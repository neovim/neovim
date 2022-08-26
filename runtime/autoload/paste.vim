" Vim support file to help with paste mappings and menus
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2019 Jan 27

" Define the string to use for items that are present both in Edit, Popup and
" Toolbar menu.  Also used in mswin.vim and macmap.vim.

let paste#paste_cmd = {'n': ":call paste#Paste()<CR>"}
let paste#paste_cmd['v'] = '"-c<Esc>' . paste#paste_cmd['n']
let paste#paste_cmd['i'] = "\<c-\>\<c-o>\"+gP"

func! paste#Paste()
  let ove = &ve
  set ve=all
  normal! `^
  if @+ != ''
    normal! "+gP
  endif
  let c = col(".")
  normal! i
  if col(".") < c	" compensate for i<ESC> moving the cursor left
    normal! l
  endif
  let &ve = ove
endfunc
