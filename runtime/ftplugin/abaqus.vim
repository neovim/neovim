" Vim filetype plugin file
" Language:     Abaqus finite element input file (www.abaqus.com)
" Maintainer:   Carl Osterwisch <osterwischc@asme.org>
" Last Change:  2012 Apr 30

" Only do this when not done yet for this buffer
if exists("b:did_ftplugin") | finish | endif

" Don't load another plugin for this buffer
let b:did_ftplugin = 1

" Save the compatibility options and temporarily switch to vim defaults
let s:cpo_save = &cpoptions
set cpoptions&vim

" Set the format of the include file specification for Abaqus
" Used in :check gf ^wf [i and other commands
setlocal include=\\<\\cINPUT\\s*=

" Remove characters up to the first = when evaluating filenames
setlocal includeexpr=substitute(v:fname,'.\\{-}=','','')

" Remove comma from valid filename characters since it is used to
" separate keyword parameters
setlocal isfname-=,

" Define format of comment lines (see 'formatoptions' for uses)
setlocal comments=:**
setlocal commentstring=**%s

" Definitions start with a * and assign a NAME, NSET, or ELSET
" Used in [d ^wd and other commands
setlocal define=^\\*\\a.*\\c\\(NAME\\\|NSET\\\|ELSET\\)\\s*=

" Abaqus keywords and identifiers may include a - character
setlocal iskeyword+=-

let b:undo_ftplugin = "setlocal include< includeexpr< isfname<"
    \ . " comments< commentstring< define< iskeyword<"

if has("folding")
    " Fold all lines that do not begin with *
    setlocal foldexpr=getline(v:lnum)[0]!=\"\*\"
    setlocal foldmethod=expr
    let b:undo_ftplugin .= " foldexpr< foldmethod<"
endif

" Set the file browse filter (currently only supported under Win32 gui)
if has("gui_win32") && !exists("b:browsefilter")
    let b:browsefilter = "Abaqus Input Files (*.inp *.inc)\t*.inp;*.inc\n" .
    \ "Abaqus Results (*.dat)\t*.dat\n" .
    \ "Abaqus Messages (*.pre *.msg *.sta)\t*.pre;*.msg;*.sta\n" .
    \ "All Files (*.*)\t*.*\n"
    let b:undo_ftplugin .= "|unlet! b:browsefilter"
endif

" Define patterns for the matchit plugin
if exists("loaded_matchit") && !exists("b:match_words")
    let b:match_ignorecase = 1
    let b:match_words = 
    \ '\*part:\*end\s*part,' .
    \ '\*assembly:\*end\s*assembly,' .
    \ '\*instance:\*end\s*instance,' .
    \ '\*step:\*end\s*step'
    let b:undo_ftplugin .= "|unlet! b:match_ignorecase b:match_words"
endif

" Define keys used to move [count] keywords backward or forward.
noremap <silent><buffer> [[ ?^\*\a<CR>:nohlsearch<CR>
noremap <silent><buffer> ]] /^\*\a<CR>:nohlsearch<CR>

" Define key to toggle commenting of the current line or range
noremap <silent><buffer> <LocalLeader><LocalLeader> 
    \ :call <SID>Abaqus_ToggleComment()<CR>j
function! <SID>Abaqus_ToggleComment() range
    if strpart(getline(a:firstline), 0, 2) == "**"
        " Un-comment all lines in range
        silent execute a:firstline . ',' . a:lastline . 's/^\*\*//'
    else
        " Comment all lines in range
        silent execute a:firstline . ',' . a:lastline . 's/^/**/'
    endif
endfunction

let b:undo_ftplugin .= "|unmap <buffer> [[|unmap <buffer> ]]"
    \ . "|unmap <buffer> <LocalLeader><LocalLeader>"

" Undo must be done in nocompatible mode for <LocalLeader>.
let b:undo_ftplugin = "let s:cpo_save = &cpoptions|"
    \ . "set cpoptions&vim|"
    \ . b:undo_ftplugin
    \ . "|let &cpoptions = s:cpo_save"
    \ . "|unlet s:cpo_save"

" Restore saved compatibility options
let &cpoptions = s:cpo_save
unlet s:cpo_save
