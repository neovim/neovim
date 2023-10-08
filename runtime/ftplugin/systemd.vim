" Vim filetype plugin file
" Language:			systemd.unit(5)
" Keyword Lookup Support:	Enno Nagel <enno.nagel+vim@gmail.com>
" Latest Revision:      2023-10-07

if !exists('b:did_ftplugin')
  " Looks a lot like dosini files.
  runtime! ftplugin/dosini.vim
endif

if has('unix') && executable('less')
  if !has('gui_running')
    command -buffer -nargs=1 SystemdKeywordPrg silent exe '!' . KeywordLookup_systemd(<q-args>) | redraw!
  elseif has('terminal')
    command -buffer -nargs=1 SystemdKeywordPrg silent exe 'term ' . KeywordLookup_systemd(<q-args>)
  endif
  if exists(':SystemdKeywordPrg') == 2
    if !exists('*KeywordLookup_systemd')
      function KeywordLookup_systemd(keyword) abort
        let matches = matchlist(getline(search('\v^\s*\[\s*.+\s*\]\s*$', 'nbWz')), '\v^\s*\[\s*(\k+).*\]\s*$')
        if len(matches) > 1
          let section = matches[1]
          return 'LESS= MANPAGER="less --pattern=''(^|,)\s+' . a:keyword . '=$'' --hilite-search" man ' . 'systemd.' . section
        else
          return 'LESS= MANPAGER="less --pattern=''(^|,)\s+' . a:keyword . '=$'' --hilite-search" man ' . 'systemd'
        endif
      endfunction
    endif
    setlocal iskeyword+=-
    setlocal keywordprg=:SystemdKeywordPrg
    if !exists('b:undo_ftplugin') || empty(b:undo_ftplugin)
      let b:undo_ftplugin = 'setlocal keywordprg< iskeyword<'
    else
      let b:undo_ftplugin .= '| setlocal keywordprg< iskeyword< | sil! delc -buffer SystemdKeywordPrg'
    endif
  endif
endif
