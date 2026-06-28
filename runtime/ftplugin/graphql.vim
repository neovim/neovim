" Vim filetype plugin
" Language:	graphql
" Maintainer:	Jon Parise <jon@indelible.org>
" Filenames:	*.graphql *.graphqls *.gql
" URL:		https://github.com/jparise/vim-graphql
" License:	MIT <https://opensource.org/license/mit>
" Last Change:	2024 Dec 21
"		2026 Jun 27 by Vim Project (add recommended style guard)

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

setlocal comments=:#
setlocal commentstring=#\ %s
setlocal formatoptions-=t
setlocal iskeyword+=$,@-@
if get(g:, 'graphql_recommended_style',
      \ get(g:, 'filetype_recommended_style', 1))
  setlocal softtabstop=2
  setlocal shiftwidth=2
  setlocal expandtab
endif

let b:undo_ftplugin = 'setlocal com< cms< fo< isk< sts< sw< et<'
