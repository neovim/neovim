" Vim filetype plugin file
" Language:             iCalendar
" Maintainer:           Anakin Childerhose <anakin@childerhose.ca>
" Latest Change:        2026 Sept 22
" License:              Vim (see :h license)

if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

let b:undo_ftplugin = ''

let s:cpo_save = &cpo
set cpo&vim

if exists('g:loaded_matchit') && !exists('b:match_words')
  let b:match_words = '\<BEGIN\:.*\>:\<END\:.*\>'
  let b:undo_ftplugin ..= '| unlet! b:match_words'
endif

function s:icalendarComponentFold() abort
  if get(b:, 'icalendar_fold_tick', -1) == b:changedtick
    return get(b:icalendar_fold_levels, v:lnum - 1, '=')
  endif

  let levels = repeat(['='], line('$'))
  let depth = 0
  for match in matchbufline('%', '\C^\%(BEGIN\|END\):.*', 1, '$')
    if match.text =~# '^BEGIN:'
      let depth += 1
      let levels[match.lnum - 1] = '>' .. depth
    elseif match.text =~# '^END:' && depth > 0
      let levels[match.lnum - 1] = '<' .. depth
      let depth -= 1
    endif
  endfor

  let b:icalendar_fold_levels = levels
  let b:icalendar_fold_tick = b:changedtick
  return get(levels, v:lnum - 1, '=')
endfunction

if has('folding') && exists('*matchbufline') && get(g:, 'icalendar_folding', 0)
  setlocal foldexpr=s:icalendarComponentFold()
  setlocal foldmethod=expr
  let b:undo_ftplugin ..= '| setlocal foldexpr< foldmethod< | unlet! b:icalendar_fold_tick b:icalendar_fold_levels'
endif

let &cpo = s:cpo_save
unlet s:cpo_save

" vim: ts=2 sw=2
