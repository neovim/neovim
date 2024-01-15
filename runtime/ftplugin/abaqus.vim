" Vim filetype plugin file
" Language:     Abaqus finite element input file (www.abaqus.com)
" Maintainer:   Carl Osterwisch <costerwi@gmail.com>
" Last Change:  2022 Oct 08
"               2024 Jan 14 by Vim Project (browsefilter)

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
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
    let b:browsefilter = "Abaqus Input Files (*.inp *.inc)\t*.inp;*.inc\n" .
    \ "Abaqus Results (*.dat)\t*.dat\n" .
    \ "Abaqus Messages (*.pre, *.msg, *.sta)\t*.pre;*.msg;*.sta\n"
    if has("win32")
        let b:browsefilter .= "All Files (*.*)\t*\n"
    else
        let b:browsefilter .= "All Files (*)\t*\n"
    endif
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

if !exists("no_plugin_maps") && !exists("no_abaqus_maps")
  " Map [[ and ]] keys to move [count] keywords backward or forward
  nnoremap <silent><buffer> ]] :call <SID>Abaqus_NextKeyword(1)<CR>
  nnoremap <silent><buffer> [[ :call <SID>Abaqus_NextKeyword(-1)<CR>
  function! <SID>Abaqus_NextKeyword(direction)
    .mark '
    if a:direction < 0
      let flags = 'b'
    else
      let flags = ''
    endif
    let l:count = abs(a:direction) * v:count1
    while l:count > 0 && search("^\\*\\a", flags)
      let l:count -= 1
    endwhile
  endfunction

  " Map \\ to toggle commenting of the current line or range
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

  " Map \s to swap first two comma separated fields
  noremap <silent><buffer> <LocalLeader>s :call <SID>Abaqus_Swap()<CR>
  function! <SID>Abaqus_Swap() range
    silent execute a:firstline . ',' . a:lastline . 's/\([^*,]*\),\([^,]*\)/\2,\1/'
  endfunction

  let b:undo_ftplugin .= "|unmap <buffer> [[|unmap <buffer> ]]"
      \ . "|unmap <buffer> <LocalLeader><LocalLeader>"
      \ . "|unmap <buffer> <LocalLeader>s"
endif

" Undo must be done in nocompatible mode for <LocalLeader>.
let b:undo_ftplugin = "let b:cpo_save = &cpoptions|"
    \ . "set cpoptions&vim|"
    \ . b:undo_ftplugin
    \ . "|let &cpoptions = b:cpo_save"
    \ . "|unlet b:cpo_save"

" Restore saved compatibility options
let &cpoptions = s:cpo_save
unlet s:cpo_save
