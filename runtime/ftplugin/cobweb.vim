" Language:	Cobweb
" Description:	Vim ftplugin for Cobweb
" Maintainer:	FabricSoul <fabric.soul7@gmail.com>
" Last Change:	2025 Apr 20
" For bugs, patches and license go to https://github.com/UkoeHB/vim-cob/tree/main
"
if exists('b:did_ftplugin')
    finish
endif
let b:did_ftplugin = 1

let s:save_cpo = &cpo
set cpo&vim

setlocal commentstring=//\ %s

" Setup indentation to 4 spaces
" To disable add the this line to your vim config
" let g:caf_recommended_style = 0
if get(g:, 'caf_recommended_style', 1)
    setlocal shiftwidth=4 softtabstop=4 expandtab
endif

" Add NERDCommenter delimiters
let s:delims = { 'left': '//' }
if exists('g:NERDDelimiterMap')
    if !has_key(g:NERDDelimiterMap, 'caf')
        let g:NERDDelimiterMap.caf = s:delims
    endif
elseif exists('g:NERDCustomDelimiters')
    if !has_key(g:NERDCustomDelimiters, 'caf')
        let g:NERDCustomDelimiters.caf = s:delims
    endif
else
    let g:NERDCustomDelimiters = { 'caf': s:delims }
endif
unlet s:delims

let &cpo = s:save_cpo
unlet s:save_cpo
