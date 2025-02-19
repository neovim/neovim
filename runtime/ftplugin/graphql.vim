" Vim filetype plugin
" Language:	graphql
" Maintainer:	Jon Parise <jon@indelible.org>
" Filenames:	*.graphql *.graphqls *.gql
" URL:		https://github.com/jparise/vim-graphql
" License:	MIT <https://opensource.org/license/mit>
" Last Change:	2024 Dec 21

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal formatoptions-=t
setlocal iskeyword+=$,@-@
setlocal softtabstop=2
setlocal shiftwidth=2
setlocal expandtab

let b:undo_ftplugin = 'setlocal com< cms< fo< isk< sts< sw< et<'
