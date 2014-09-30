" Vim filetype plugin file
" Language:	Javascript
" Maintainer:	Doug Kearns <dougkearns@gmail.com>
" Last Change:  2008 Jun 15
" URL:		http://gus.gscit.monash.edu.au/~djkea2/vim/ftplugin/javascript.vim

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo-=C

" Set 'formatoptions' to break comment lines but not other lines,
" " and insert the comment leader when hitting <CR> or using "o".
setlocal formatoptions-=t formatoptions+=croql

" Set completion with CTRL-X CTRL-O to autoloaded function.
if exists('&ofu')
    setlocal omnifunc=javascriptcomplete#CompleteJS
endif

" Set 'comments' to format dashed lists in comments.
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://

setlocal commentstring=//%s

" Change the :browse e filter to primarily show Java-related files.
if has("gui_win32")
    let  b:browsefilter="Javascript Files (*.js)\t*.js\n" .
		\	"All Files (*.*)\t*.*\n"
endif
       
let b:undo_ftplugin = "setl fo< ofu< com< cms<" 

let &cpo = s:cpo_save
unlet s:cpo_save
