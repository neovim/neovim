" VHDL filetype plugin
" Language:    VHDL
" Maintainer:  R.Shankar <shankar.pec?gmail.com>
" Modified By: Gerald Lai <laigera+vim?gmail.com>
" Last Change: 2011 Dec 11

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin")
  finish
endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
"setlocal fo-=t fo+=croqlm1

" Set 'comments' to format dashed lists in comments.
"setlocal comments=sO:*\ -,mO:*\ \ ,exO:*/,s1:/*,mb:*,ex:*/,://

" Format comments to be up to 78 characters long
"setlocal tw=75

" Win32 can filter files in the browse dialog
"if has("gui_win32") && !exists("b:browsefilter")
"  let b:browsefilter = "Verilog Source Files (*.v)\t*.v\n" .
"   \ "All Files (*.*)\t*.*\n"
"endif

" Let the matchit plugin know what items can be matched.
if ! exists("b:match_words")  &&  exists("loaded_matchit")
  let b:match_ignorecase=1
  let s:notend = '\%(\<end\s\+\)\@<!'
  let b:match_words =
    \ s:notend.'\<if\>:\<elsif\>:\<else\>:\<end\s\+if\>,'.
    \ s:notend.'\<case\>:\<when\>:\<end\s\+case\>,'.
    \ s:notend.'\<loop\>:\<end\s\+loop\>,'.
    \ s:notend.'\<for\>:\<end\s\+for\>,'.
    \ s:notend.'\<generate\>:\<end\s\+generate\>,'.
    \ s:notend.'\<record\>:\<end\s\+record\>,'.
    \ s:notend.'\<units\>:\<end\s\+units\>,'.
    \ s:notend.'\<process\>:\<end\s\+process\>,'.
    \ s:notend.'\<block\>:\<end\s\+block\>,'.
    \ s:notend.'\<function\>:\<end\s\+function\>,'.
    \ s:notend.'\<entity\>:\<end\s\+entity\>,'.
    \ s:notend.'\<component\>:\<end\s\+component\>,'.
    \ s:notend.'\<architecture\>:\<end\s\+architecture\>,'.
    \ s:notend.'\<package\>:\<end\s\+package\>,'.
    \ s:notend.'\<procedure\>:\<end\s\+procedure\>,'.
    \ s:notend.'\<configuration\>:\<end\s\+configuration\>'
endif

" count repeat
function! <SID>CountWrapper(cmd)
  let i = v:count1
  if a:cmd[0] == ":"
    while i > 0
      execute a:cmd
      let i = i - 1
    endwhile
  else
    execute "normal! gv\<Esc>"
    execute "normal ".i.a:cmd
    let curcol = col(".")
    let curline = line(".")
    normal! gv
    call cursor(curline, curcol)
  endif
endfunction

" explore motion
" keywords: "architecture", "block", "configuration", "component", "entity", "function", "package", "procedure", "process", "record", "units"
let b:vhdl_explore = '\%(architecture\|block\|configuration\|component\|entity\|function\|package\|procedure\|process\|record\|units\)'
noremap  <buffer><silent>[[ :<C-u>cal <SID>CountWrapper(':cal search("\\%(--.*\\)\\@<!\\%(\\<end\\s\\+\\)\\@<!\\<".b:vhdl_explore."\\>\\c\\<Bar>\\%^","bW")')<CR>
noremap  <buffer><silent>]] :<C-u>cal <SID>CountWrapper(':cal search("\\%(--.*\\)\\@<!\\%(\\<end\\s\\+\\)\\@<!\\<".b:vhdl_explore."\\>\\c\\<Bar>\\%$","W")')<CR>
noremap  <buffer><silent>[] :<C-u>cal <SID>CountWrapper(':cal search("\\%(--.*\\)\\@<!\\<end\\s\\+".b:vhdl_explore."\\>\\c\\<Bar>\\%^","bW")')<CR>
noremap  <buffer><silent>][ :<C-u>cal <SID>CountWrapper(':cal search("\\%(--.*\\)\\@<!\\<end\\s\\+".b:vhdl_explore."\\>\\c\\<Bar>\\%$","W")')<CR>
vnoremap <buffer><silent>[[ :<C-u>cal <SID>CountWrapper('[[')<CR>
vnoremap <buffer><silent>]] :<C-u>cal <SID>CountWrapper(']]')<CR>
vnoremap <buffer><silent>[] :<C-u>cal <SID>CountWrapper('[]')<CR>
vnoremap <buffer><silent>][ :<C-u>cal <SID>CountWrapper('][')<CR>

let &cpo = s:cpo_save
unlet s:cpo_save
