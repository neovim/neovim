" Vim ftplugin file
" Language:	Reva Forth
" Version:	7.1
" Last Change:	2008/01/11
" Maintainer:	Ron Aaron <ron@ronware.org>
" URL:		http://ronware.org/reva/
" Filetypes:	*.rf *.frt 
" NOTE: 	Forth allows any non-whitespace in a name, so you need to do:
" 		setlocal iskeyword=!,@,33-35,%,$,38-64,A-Z,91-96,a-z,123-126,128-255
"
" 		This goes with the syntax/reva.vim file.

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
 finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

setlocal sts=4 sw=4 
setlocal com=s1:/*,mb:*,ex:*/,:\|,:\\
setlocal fo=tcrqol
setlocal matchpairs+=\::;
setlocal iskeyword=!,@,33-35,%,$,38-64,A-Z,91-96,a-z,123-126,128-255
