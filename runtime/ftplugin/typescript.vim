" Vim filetype plugin file
" Language:	TypeScript
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:	2019 Aug 30

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo-=C

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal formatoptions-=t formatoptions+=croql

" Set 'comments' to format dashed lists in comments.
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://

setlocal commentstring=//%s

setlocal suffixesadd+=.ts,.d.ts,.tsx,.js,.jsx,.cjs,.mjs

" Change the :browse e filter to primarily show TypeScript-related files.
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
    let  b:browsefilter="TypeScript Files (*.ts)\t*.ts\n" .
		\	"TypeScript Declaration Files (*.d.ts)\t*.d.ts\n" .
		\	"TSX Files (*.tsx)\t*.tsx\n" .
		\	"JavaScript Files (*.js)\t*.js\n" .
		\	"JavaScript Modules (*.es, *.cjs, *.mjs)\t*.es;*.cjs;*.mjs\n" .
		\	"JSON Files (*.json)\t*.json\n" .
		\	"All Files (*.*)\t*.*\n"
endif
       
let b:undo_ftplugin = "setl fo< com< cms< sua< | unlet! b:browsefilter" 

let &cpo = s:cpo_save
unlet s:cpo_save
