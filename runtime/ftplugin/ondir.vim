" Vim filetype plugin file
" Language:     ondir <https://github.com/alecthomas/ondir>
" Maintainer:   Jon Parise <jon@indelible.org>

if exists('b:did_ftplugin')
  finish
endif

let s:cpo_save = &cpoptions

setlocal comments=:# commentstring=#\ %s

let b:undo_ftplugin = 'setl comments< commentstring<'

let &cpoptions = s:cpo_save
unlet s:cpo_save

" vim: et ts=4 sw=2 sts=2:
