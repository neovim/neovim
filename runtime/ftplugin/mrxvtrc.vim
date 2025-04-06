" Created	: Wed 26 Apr 2006 01:20:53 AM CDT
" Modified	: Fri 28 Apr 2006 03:24:01 AM CDT
" Author	: Gautam Iyer <gi1242@users.sourceforge.net>
" Description	: ftplugin for mrxvtrc

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = "setl com< cms< fo<"

" Really any line that does not match an option is a comment. But use '!' for
" compatibility with x-defaults files, and "#" (preferred) for compatibility
" with all other config files.
"
" Comments beginning with "#" are preferred because Vim will not flag the
" first word as a spelling error if it is not capitalised. The '!' used as
" comment leaders makes Vim think that every comment line is a new sentence.

setlocal comments=:!,:# commentstring=#\ %s
setlocal formatoptions-=t formatoptions+=croql
