" Vim filetype plugin file
" Language:             Tera
" Maintainer:           Muntasir Mahmud <muntasir.joypurhat@gmail.com>
" Last Change:          2025 Mar 08
" 2025 Apr 16 by Vim Project (set 'cpoptions' for line continuation, #17121)

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal autoindent

setlocal commentstring={#\ %s\ #}
setlocal comments=s:{#,e:#}

if exists("loaded_matchit")
  let b:match_ignorecase = 0
  let b:match_words = '{#:##\|#},{% *if:{% *else\>:{% *elif\>:{% *endif %},{% *for\>:{% *endfor %},{% *macro\>:{% *endmacro %},{% *block\>:{% *endblock %},{% *filter\>:{% *endfilter %},{% *set\>:{% *endset %},{% *raw\>:{% *endraw %},{% *with\>:{% *endwith %}'
endif

setlocal includeexpr=substitute(v:fname,'\\([^.]*\\)$','\\1','g')
setlocal suffixesadd=.tera

setlocal expandtab
setlocal shiftwidth=2
setlocal softtabstop=2

let b:undo_ftplugin = "setlocal autoindent< commentstring< comments< " ..
      \ "includeexpr< suffixesadd< expandtab< shiftwidth< softtabstop<"
let b:undo_ftplugin .= "|unlet! b:match_ignorecase b:match_words"

let &cpo = s:cpo_save
unlet s:cpo_save
