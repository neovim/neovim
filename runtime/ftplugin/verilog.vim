" Vim filetype plugin file
" Language:	Verilog HDL
" Maintainer:	Chih-Tsun Huang <cthuang@cs.nthu.edu.tw>
" Last Change:	2017 Aug 25 by Chih-Tsun Huang
" URL:	    	http://www.cs.nthu.edu.tw/~cthuang/vim/ftplugin/verilog.vim
"
" Credits:
"   Suggestions for improvement, bug reports by
"     Shao <shaominghai2005@163.com>

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

" Set 'cpoptions' to allow line continuations
let s:cpo_save = &cpo
set cpo&vim

" Undo the plugin effect
let b:undo_ftplugin = "setlocal fo< com< tw<"
    \ . "| unlet! b:browsefilter b:match_ignorecase b:match_words"

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal fo-=t fo+=croqlm1

" Set 'comments' to format dashed lists in comments.
setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://

" Format comments to be up to 78 characters long
if &textwidth == 0 
  setlocal tw=78
endif

" Win32 can filter files in the browse dialog
if has("gui_win32") && !exists("b:browsefilter")
  let b:browsefilter = "Verilog Source Files (*.v)\t*.v\n" .
	\ "All Files (*.*)\t*.*\n"
endif

" Let the matchit plugin know what items can be matched.
if exists("loaded_matchit")
  let b:match_ignorecase=0
  let b:match_words=
    \ '\<begin\>:\<end\>,' .
    \ '\<case\>\|\<casex\>\|\<casez\>:\<endcase\>,' .
    \ '\<module\>:\<endmodule\>,' .
    \ '\<if\>:`\@<!\<else\>,' .
    \ '\<function\>:\<endfunction\>,' .
    \ '`ifn\?def\>:`elsif\>:`else\>:`endif\>,' .
    \ '\<task\>:\<endtask\>,' .
    \ '\<specify\>:\<endspecify\>,' .
    \ '\<config\>:\<endconfig\>,' .
    \ '\<generate\>:\<endgenerate\>,' .
    \ '\<fork\>:\<join\>,' .
    \ '\<primitive\>:\<endprimitive\>,' .
    \ '\<table\>:\<endtable\>'
endif

" Reset 'cpoptions' back to the user's setting
let &cpo = s:cpo_save
unlet s:cpo_save
