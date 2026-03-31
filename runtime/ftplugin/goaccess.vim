" Vim filetype plugin
" Language: GoAccess configuration
" Maintainer: Adam Monsen <haircut@gmail.com>
" Last Change: 2024 Aug 1

if exists('b:did_ftplugin')
  finish
endif

let b:did_ftplugin = 1

setl comments=:# commentstring=#\ %s

let b:undo_ftplugin = 'setl com< cms<'
