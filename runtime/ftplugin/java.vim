" Vim filetype plugin file
" Language:		Java
" Maintainer:		Aliaksei Budavei <0x000c70 AT gmail DOT com>
" Former Maintainer:	Dan Sharp
" Repository:		https://github.com/zzzyxwvut/java-vim.git
" Last Change:		2024 Apr 13
"			2024 Jan 14 by Vim Project (browsefilter)

if exists("b:did_ftplugin") | finish | endif
let b:did_ftplugin = 1

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:save_cpo = &cpo
set cpo-=C

" For filename completion, prefer the .java extension over the .class
" extension.
set suffixes+=.class

" Enable gf on import statements.  Convert . in the package
" name to / and append .java to the name, then search the path.
setlocal includeexpr=substitute(v:fname,'\\.','/','g')
setlocal suffixesadd=.java
if exists("g:ftplugin_java_source_path")
    let &l:path=g:ftplugin_java_source_path . ',' . &l:path
endif

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal formatoptions-=t formatoptions+=croql

" Set 'comments' to format dashed lists in comments. Behaves just like C.
setlocal comments& comments^=sO:*\ -,mO:*\ \ ,exO:*/

setlocal commentstring=//%s

" Change the :browse e filter to primarily show Java-related files.
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
    let  b:browsefilter="Java Files (*.java)\t*.java\n" .
		\	"Properties Files (*.prop*)\t*.prop*\n" .
		\	"Manifest Files (*.mf)\t*.mf\n"
    if has("win32")
	let b:browsefilter .= "All Files (*.*)\t*\n"
    else
	let b:browsefilter .= "All Files (*)\t*\n"
    endif
endif

" Undo the stuff we changed.
let b:undo_ftplugin = "setlocal suffixes< suffixesadd<" .
		\     " formatoptions< comments< commentstring< path< includeexpr<" .
		\     " | unlet! b:browsefilter"

" Restore the saved compatibility options.
let &cpo = s:save_cpo
unlet s:save_cpo
