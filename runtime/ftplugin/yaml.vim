" Vim filetype plugin file
" Language:             YAML (YAML Ain't Markup Language)
" Previous Maintainer:  Nikolai Weibull <now@bitwi.se> (inactive)
" Last Change:  2024 Oct 04

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let b:undo_ftplugin = "setl com< cms< et< fo<"

setlocal comments=:# commentstring=#\ %s expandtab
setlocal formatoptions-=t formatoptions+=croql

" rime input method engine uses `*.custom.yaml` as its config files
if expand('%:r:e') ==# 'custom'
  if !exists('current_compiler')
    compiler rime_deployer
    let b:undo_ftplugin ..= "| compiler make"
  endif
  setlocal include=__include:\\s*
  let b:undo_ftplugin ..= " inc<"
endif

if !exists("g:yaml_recommended_style") || g:yaml_recommended_style != 0
  let b:undo_ftplugin ..= " sw< sts<"
  setlocal shiftwidth=2 softtabstop=2
endif

let &cpo = s:cpo_save
unlet s:cpo_save
