" This script tests a color scheme for some errors and lists potential errors.
" Load the scheme and source this script, like this:
"    :edit colors/desert.vim | :so tools/check_colors.vim

let s:save_cpo= &cpo
set cpo&vim

func! Test_check_colors()
  let l:savedview = winsaveview()
  call cursor(1,1)
  let err = {}

  " 1) Check g:colors_name is existing
  if !search('\<\%(g:\)\?colors_name\>', 'cnW')
    let err['colors_name'] = 'g:colors_name not set'
  else
    let err['colors_name'] = 'OK'
  endif

  " 2) Check for some well-defined highlighting groups
  let hi_groups = [
        \ 'ColorColumn',
        \ 'Comment',
        \ 'Conceal',
        \ 'Constant',
        \ 'Cursor',
        \ 'CursorColumn',
        \ 'CursorLine',
        \ 'CursorLineNr',
        \ 'DiffAdd',
        \ 'DiffChange',
        \ 'DiffDelete',
        \ 'DiffText',
        \ 'Directory',
        \ 'EndOfBuffer',
        \ 'Error',
        \ 'ErrorMsg',
        \ 'FoldColumn',
        \ 'Folded',
        \ 'Identifier',
        \ 'Ignore',
        \ 'IncSearch',
        \ 'LineNr',
        \ 'MatchParen',
        \ 'ModeMsg',
        \ 'MoreMsg',
        \ 'NonText',
        \ 'Normal',
        \ 'Pmenu',
        \ 'PmenuSbar',
        \ 'PmenuSel',
        \ 'PmenuThumb',
        \ 'PreProc',
        \ 'Question',
        \ 'QuickFixLine',
        \ 'Search',
        \ 'SignColumn',
        \ 'Special',
        \ 'SpecialKey',
        \ 'SpellBad',
        \ 'SpellCap',
        \ 'SpellLocal',
        \ 'SpellRare',
        \ 'Statement',
        \ 'StatusLine',
        \ 'StatusLineNC',
        \ 'StatusLineTerm',
        \ 'StatusLineTermNC',
        \ 'TabLine',
        \ 'TabLineFill',
        \ 'TabLineSel',
        \ 'Title',
        \ 'Todo',
        \ 'ToolbarButton',
        \ 'ToolbarLine',
        \ 'Type',
        \ 'Underlined',
        \ 'VertSplit',
        \ 'Visual',
        \ 'VisualNOS',
        \ 'WarningMsg',
        \ 'WildMenu',
        \ ]
  let groups = {}
  for group in hi_groups
    if search('\c@suppress\s\+\<' .. group .. '\>', 'cnW')
      " skip check, if the script contains a line like
      " @suppress Visual:
      continue
    endif
    if search('hi\%[ghlight]!\= \+link \+' .. group, 'cnW') " Linked group
      continue
    endif
    if !search('hi\%[ghlight] \+\<' .. group .. '\>', 'cnW')
      let groups[group] = 'No highlight definition for ' .. group
      continue
    endif
    if !search('hi\%[ghlight] \+\<' .. group .. '\>.*[bf]g=', 'cnW')
      let groups[group] = 'Missing foreground or background color for ' .. group
      continue
    endif
    if search('hi\%[ghlight] \+\<' .. group .. '\>.*guibg=', 'cnW') &&
        \ !search('hi\%[ghlight] \+\<' .. group .. '\>.*ctermbg=', 'cnW')
	\ && group != 'Cursor'
      let groups[group] = 'Missing bg terminal color for ' .. group
      continue
    endif
    if !search('hi\%[ghlight] \+\<' .. group .. '\>.*guifg=', 'cnW')
	  \ && group !~ '^Diff'
      let groups[group] = 'Missing guifg definition for ' .. group
      continue
    endif
    if !search('hi\%[ghlight] \+\<' .. group .. '\>.*ctermfg=', 'cnW')
	  \ && group !~ '^Diff'
	  \ && group != 'Cursor'
      let groups[group] = 'Missing ctermfg definition for ' .. group
      continue
    endif
    " do not check for background colors, they could be intentionally left out
    call cursor(1,1)
  endfor
  let err['highlight'] = groups

  " 3) Check, that it does not set background highlighting
  " Doesn't ':hi Normal ctermfg=253 ctermfg=233' also set the background sometimes?
  let bg_set = '\(set\?\|setl\(ocal\)\?\) .*\(background\|bg\)=\(dark\|light\)'
  let bg_let = 'let \%([&]\%([lg]:\)\?\)\%(background\|bg\)\s*=\s*\([''"]\?\)\w\+\1'
  let bg_pat = '\%(' .. bg_set .. '\|' .. bg_let .. '\)'
  let line = search(bg_pat, 'cnW')
  if search(bg_pat, 'cnW')
    exe line
    if search('hi \U\w\+\s\+\S', 'cbnW')
      let err['background'] = 'Should not set background option after :hi statement'
    endif
  else
    let err['background'] = 'OK'
  endif
  call cursor(1,1)

  " 4) Check, that t_Co is checked
  let pat = '[&]t_Co\s*[<>=]=\?\s*\d\+'
  if !search(pat, 'ncW')
    let err['t_Co'] = 'Does not check terminal for capable colors'
  endif

  " 5) Initializes correctly, e.g. should have a section like
  " hi clear
  " if exists("syntax_on")
  " syntax reset
  " endif
  let pat = 'hi\%[ghlight]\s*clear\n\s*if\s*exists(\([''"]\)syntax_on\1)\n\s*syn\%[tax]\s*reset\n\s*endif'
  if !search(pat, 'cnW')
    let err['init'] = 'No initialization'
  endif

  " 6) Does not use :syn on
  if search('syn\%[tax]\s\+on', 'cnW')
    let err['background'] = 'Should not issue :syn on'
  endif

  " 7) Does not define filetype specific groups like vimCommand, htmlTag,
  let hi_groups = filter(getcompletion('', 'filetype'), { _,v -> v !~# '\%[no]syn\%(color\|load\|tax\)' })
  let ft_groups = []
  " let group = '\%('.join(hi_groups, '\|').'\)' " More efficient than a for loop, but less informative
  for group in hi_groups
    let pat = '\Chi\%[ghlight]!\= *\%[link] \+\zs' .. group .. '\w\+\>\ze \+.' " Skips `hi clear`
    if search(pat, 'cW')
      call add(ft_groups, matchstr(getline('.'), pat))
    endif
    call cursor(1,1)
  endfor
  if !empty(ft_groups)
    let err['filetype'] = get(err, 'filetype', 'Should not define: ') . join(uniq(sort(ft_groups)))
  endif

  " 8) Were debugPC and debugBreakpoint defined?
  for group in ['debugPC', 'debugBreakpoint']
    let pat = '\Chi\%[ghlight]!\= *\%[link] \+\zs' .. group .. '\>'
    if search(pat, 'cnW')
      let line = search(pat, 'cW')
      let err['filetype'] = get(err, 'filetype', 'Should not define: ') . matchstr(getline('.'), pat). ' '
    endif
    call cursor(1,1)
  endfor

  " 9) Normal should be defined first, not use reverse, fg or bg
  call cursor(1,1)
  let pat = 'hi\%[ghlight] \+\%(link\|clear\)\@!\w\+\>'
  call search(pat, 'cW') " Look for the first hi def, skipping `hi link` and `hi clear`
  if getline('.') !~# '\m\<Normal\>'
    let err['highlight']['Normal'] = 'Should be defined first'
  elseif getline('.') =~# '\m\%(=\%(fg\|bg\)\)'
    let err['highlight']['Normal'] = "Should not use 'fg' or 'bg'"
  elseif getline('.') =~# '\m=\%(inv\|rev\)erse'
    let err['highlight']['Normal'] = 'Should not use reverse mode'
  endif

  call winrestview(l:savedview)
  let g:err = err

  " print Result
  call Result(err)
endfu

fu! Result(err)
  let do_groups = 0
  echohl Title|echomsg "---------------"|echohl Normal
  for key in sort(keys(a:err))
    if key is# 'highlight'
      let do_groups = !empty(a:err[key])
      continue
    else
      if a:err[key] !~ 'OK'
        echohl Title
      endif
      echomsg printf("%15s: %s", key, a:err[key])
      echohl Normal
    endif
  endfor
  echohl Title|echomsg "---------------"|echohl Normal
  if do_groups
    echohl Title | echomsg "Groups" | echohl Normal
    for v1 in sort(keys(a:err['highlight']))
      echomsg printf("%25s: %s", v1, a:err['highlight'][v1])
    endfor
  endif
endfu

call Test_check_colors()

let &cpo = s:save_cpo
unlet s:save_cpo
