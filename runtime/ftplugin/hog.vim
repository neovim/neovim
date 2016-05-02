" Vim filetype plugin
" Language:     hog (snort.conf)
" Maintainer: . Victor Roemer, <vroemer@badsec.org>.
" Last Change:  Mar 1, 2013

if exists("b:did_ftplugin")
    finish
endif
let b:did_ftplugin = 1

let s:undo_ftplugin = "setl fo< com< cms< def< inc<"

let s:cpo_save = &cpo
set cpo&vim

setlocal formatoptions=croq
setlocal comments=:#
setlocal commentstring=\c#\ %s
setlocal define=\c^\s\{-}var
setlocal include=\c^\s\{-}include

" Move around configurations 
let s:hog_keyword_match = '\c^\s*\<\(preprocessor\\|config\\|output\\|include\\|ipvar\\|portvar\\|var\\|dynamicpreprocessor\\|' . 
                        \ 'dynamicengine\\|dynamicdetection\\|activate\\|alert\\|drop\\|block\\|dynamic\\|log\\|pass\\|reject\\|sdrop\\|sblock\)\>'

exec "nnoremap <buffer><silent> ]] :call search('" . s:hog_keyword_match . "', 'W' )<CR>"
exec "nnoremap <buffer><silent> [[ :call search('" . s:hog_keyword_match . "', 'bW' )<CR>"

if exists("loaded_matchit")
    let b:match_words =
                  \ '^\s*\<\%(preprocessor\|config\|output\|include\|ipvar\|portvar' . 
                  \ '\|var\|dynamicpreprocessor\|dynamicengine\|dynamicdetection' . 
                  \ '\|activate\|alert\|drop\|block\|dynamic\|log\|pass\|reject' . 
                  \ '\|sdrop\|sblock\>\):$,\::\,:;'
    let b:match_skip = 'r:\\.\{-}$\|^\s*#.\{-}$\|^\s*$'
endif

let &cpo = s:cpo_save
unlet s:cpo_save
