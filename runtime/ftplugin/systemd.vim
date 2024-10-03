" Vim filetype plugin file
" Language:			systemd.unit(5)
" Keyword Lookup Support:	Enno Nagel <enno.nagel+vim@gmail.com>
" Latest Revision:		2024-10-02 (small fixes to &keywordprg)

if exists("b:did_ftplugin")
  finish
endif
" Looks a lot like dosini files.
runtime! ftplugin/dosini.vim

if has('unix') && executable('less') && exists(':terminal') == 2
  command! -buffer -nargs=1 SystemdKeywordPrg silent exe 'term ++close ' KeywordLookup_systemd(<q-args>)
  silent! function KeywordLookup_systemd(keyword) abort
    let matches = matchlist(getline(search('\v^\s*\[\s*.+\s*\]\s*$', 'nbWz')), '\v^\s*\[\s*(\k+).*\]\s*$')
    if len(matches) > 1
      let section = matches[1]
      return 'env LESS= MANPAGER="less --pattern=''(^|,)\\s+' . a:keyword . '=$'' --hilite-search" man ' . 'systemd.' . section
    else
      return 'env LESS= MANPAGER="less --pattern=''(^|,)\\s+' . a:keyword . '=$'' --hilite-search" man ' . 'systemd'
    endif
  endfunction
  setlocal iskeyword+=-
  setlocal keywordprg=:SystemdKeywordPrg
  if !exists('b:undo_ftplugin') || empty(b:undo_ftplugin)
    let b:undo_ftplugin = 'setlocal keywordprg< iskeyword< | sil! delc -buffer SystemdKeywordPrg'
  else
    let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer SystemdKeywordPrg'
  endif
endif
