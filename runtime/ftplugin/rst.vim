" reStructuredText filetype plugin file
" Language: reStructuredText documentation format
" Maintainer: Marshall Ward <marshall.ward@gmail.com>
" Original Maintainer: Nikolai Weibull <now@bitwi.se>
" Website: https://github.com/marshallward/vim-restructuredtext
" Latest Revision: 2020-03-31

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

"Disable folding
if !exists('g:rst_fold_enabled')
  let g:rst_fold_enabled = 0
endif

let b:undo_ftplugin = "setl com< cms< et< fo<"

setlocal comments=fb:.. commentstring=..\ %s expandtab
setlocal formatoptions+=tcroql

" reStructuredText standard recommends that tabs be expanded to 8 spaces
" The choice of 3-space indentation is to provide slightly better support for
" directives (..) and ordered lists (1.), although it can cause problems for
" many other cases.
"
" More sophisticated indentation rules should be revisited in the future.

if exists("g:rst_style") && g:rst_style != 0
    setlocal expandtab shiftwidth=3 softtabstop=3 tabstop=8
endif

if g:rst_fold_enabled != 0 && has('patch-7.3.867')  " Introduced the TextChanged event.
  setlocal foldmethod=expr
  setlocal foldexpr=RstFold#GetRstFold()
  setlocal foldtext=RstFold#GetRstFoldText()
  augroup RstFold
    autocmd TextChanged,InsertLeave <buffer> unlet! b:RstFoldCache
  augroup END
endif

let &cpo = s:cpo_save
unlet s:cpo_save
