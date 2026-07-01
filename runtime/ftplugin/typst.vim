" Vim filetype plugin file
" Language:             Typst
" Maintainer:           Maxim Kim <habamax@gmail.com>
" Previous Maintainers: Gregory Anders
"                       Luca Saccarola <github.e41mv@aleeas.com>
" Last Change:          2026 Jun 29
" Based on the ftplugin from https://github.com/kaarmu/typst.vim

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=//\ %s
setlocal comments=s1:/*,mb:*,ex:*/,://
setlocal formatoptions+=croqn
" Numbered Lists
setlocal formatlistpat=^\\s*\\d\\+[\\]:.)}\\t\ ]\\s*
" Unordered (-), Ordered (+) and definition (/) Lists
setlocal formatlistpat+=\\\|^\\s*[-+/\]\\s\\+
setlocal suffixesadd=.typ

let b:undo_ftplugin = "setl cms< com< fo< flp< sua<"

if get(g:, "typst_conceal", 0)
  setlocal conceallevel=2
  let b:undo_ftplugin ..= " cole<"
endif

if get(g:, 'typst_recommended_style',
      \ get(g:, 'filetype_recommended_style', 1))
  setlocal expandtab
  setlocal softtabstop=2
  setlocal shiftwidth=2
  let b:undo_ftplugin ..= " | setl et< sts< sw<"
endif

if has("folding") && get(g:, "typst_folding", 0)
  setlocal foldexpr=typst#foldexpr()
  setlocal foldmethod=expr
  let b:undo_ftplugin ..= " | setl foldexpr< foldmethod<"
endif

if !exists("current_compiler")
  compiler typst
  let b:undo_ftplugin ..= " | compiler make"
endif

if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
  let  b:browsefilter = "Typst Markup file (*.typ)\t*.typ\n"
  if has("win32")
    let b:browsefilter ..= "All Files (*.*)\t*\n"
  else
    let b:browsefilter ..= "All Files (*)\t*\n"
  endif
  let b:undo_ftplugin ..= " | unlet! b:browsefilter"
endif
