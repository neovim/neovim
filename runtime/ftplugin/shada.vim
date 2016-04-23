if exists('b:did_ftplugin')
  finish
endif

let b:did_ftplugin = 1

function! ShaDaIndent(lnum)
  if a:lnum == 1 || getline(a:lnum) =~# '\mwith timestamp.*:$'
    return 0
  else
    return shiftwidth()
  endif
endfunction

setlocal expandtab tabstop=2 softtabstop=2 shiftwidth=2
setlocal indentexpr=ShaDaIndent(v:lnum) indentkeys=<:>,o,O

let b:undo_ftplugin = 'setlocal et< ts< sts< sw< indentexpr< indentkeys<'
