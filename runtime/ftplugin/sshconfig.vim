" Vim filetype plugin file
" Language:         OpenSSH client configuration file
" Previous Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2023-10-07

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal comments=:# commentstring=#\ %s formatoptions-=t formatoptions+=croql
let b:undo_ftplugin = 'setlocal com< cms< fo<'

if has('unix') && executable('less')
  if !has('gui_running') && !has('nvim')
    command -buffer -nargs=1 SshconfigKeywordPrg
          \ silent exe '!' . 'LESS= MANPAGER="less --pattern=''^\s+' . <q-args> . '$'' --hilite-search" man ' . 'ssh_config' |
          \ redraw!
  elseif exists(':terminal') == 2
    command -buffer -nargs=1 SshconfigKeywordPrg
          \ silent exe 'term ' . 'env LESS= MANPAGER="less --pattern=''' . escape('^\s+' . <q-args> . '$', '\') . ''' --hilite-search" man ' . 'ssh_config'
  endif
  if exists(':SshconfigKeywordPrg') == 2
    setlocal iskeyword+=-
    setlocal keywordprg=:SshconfigKeywordPrg
    let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer SshconfigKeywordPrg'
  endif
endif

let &cpo = s:cpo_save
unlet s:cpo_save
