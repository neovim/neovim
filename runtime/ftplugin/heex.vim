" Elixir filetype plugin
" Language: HEEx
" Maintainer:	Mitchell Hanberg <vimNOSPAM@mitchellhanberg.com>
" Last Change: 2022 Sep 21

if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal shiftwidth=2 softtabstop=2 expandtab

setlocal comments=:<%!--
setlocal commentstring=<%!--\ %s\ --%>

let b:undo_ftplugin = 'set sw< sts< et< com< cms<'
