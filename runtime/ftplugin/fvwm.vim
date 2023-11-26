" Created	: Tue 09 May 2006 02:07:31 PM CDT
" Modified	: Tue 09 May 2006 02:07:31 PM CDT
" Author	: Gautam Iyer <gi1242@users.sourceforge.net>
" Description	: ftplugin for fvwm config files

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl com< cms< fo<"

setlocal comments=:# commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql
