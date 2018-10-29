" Vim filetype plugin file (GUI menu and folding)
" Language:     Debian control files
" Maintainer:   Debian Vim Maintainers
" Former Maintainer:    Pierre Habouzit <madcoder@debian.org>
" Last Change:  2018-01-28
" URL:          https://salsa.debian.org/vim-team/vim-debian/blob/master/ftplugin/debcontrol.vim

" Do these settings once per buffer
if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin=1

" {{{1 Local settings (do on every load)
if exists('g:debcontrol_fold_enable')
  setlocal foldmethod=expr
  setlocal foldexpr=DebControlFold(v:lnum)
  setlocal foldtext=DebControlFoldText()
endif
setlocal textwidth=0

" Clean unloading
let b:undo_ftplugin = 'setlocal tw< foldmethod< foldexpr< foldtext<'

" }}}1

" {{{1 folding

function! s:getField(f, lnum)
  let line = getline(a:lnum)
  let fwdsteps = 0
  while line !~ '^'.a:f.':'
    let fwdsteps += 1
    let line = getline(a:lnum + fwdsteps)
    if line ==# ''
      return 'unknown'
    endif
  endwhile
  return substitute(line, '^'.a:f.': *', '', '')
endfunction

function! DebControlFoldText()
  if v:folddashes ==# '-'  " debcontrol entry fold
    let type = substitute(getline(v:foldstart), ':.*', '', '')
    if type ==# 'Source'
      let ftext = substitute(foldtext(), ' *Source: *', ' ', '')
      return ftext . ' -- ' . s:getField('Maintainer', v:foldstart) . ' '
    endif
    let arch  = s:getField('Architecture', v:foldstart)
    let ftext = substitute(foldtext(), ' *Package: *', ' [' . arch . '] ', '')
    return ftext . ': ' . s:getField('Description', v:foldstart) . ' '
  endif
  return foldtext()
endfunction

function! DebControlFold(l)

  " This is for not merging blank lines around folds to them
  if getline(a:l) =~# '^Source:'
    return '>1'
  endif

  if getline(a:l) =~# '^Package:'
    return '>1'
  endif

  return '='
endfunction

" }}}1
