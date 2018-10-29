" This script tests a color scheme for some errors. Load the scheme and source
" this script. e.g. :e colors/desert.vim | :so check_colors.vim
" Will output possible errors.

let s:save_cpo= &cpo
set cpo&vim

func! Test_check_colors()
  call cursor(1,1)
  let err={}

  " 1) Check g:colors_name is existing
  if !search('\<\%(g:\)\?colors_name\>', 'cnW')
    let err['colors_name'] = 'g:colors_name not set'
  else
    let err['colors_name'] = 'OK'
  endif

  " 2) Check for some well-defined highlighting groups
  " Some items, check several groups, e.g. Diff, Spell
  let hi_groups = ['ColorColumn', 'Diff', 'ErrorMsg', 'Folded',
        \ 'FoldColumn', 'IncSearch', 'LineNr', 'ModeMsg', 'MoreMsg', 'NonText',
        \ 'Normal', 'Pmenu', 'Todo', 'Search', 'Spell', 'StatusLine', 'TabLine',
        \ 'Title', 'Visual', 'WarningMsg', 'WildMenu']
  let groups={}
  for group in hi_groups
    if search('\c@suppress\s\+'.group, 'cnW')
      " skip check, if the script contains a line like
      " @suppress Visual:
      let groups[group] = 'Ignoring '.group
      continue
    endif
    if !search('hi\%[ghlight] \+'.group, 'cnW')
      let groups[group] = 'No highlight definition for '.group
      continue
    endif
    if !search('hi\%[ghlight] \+'.group. '.*fg=', 'cnW')
      let groups[group] = 'Missing foreground color for '.group
      continue
    endif
    if search('hi\%[ghlight] \+'.group. '.*guibg=', 'cnW') &&
        \ !search('hi\%[ghlight] \+'.group. '.*ctermbg=', 'cnW')
      let groups[group] = 'Missing bg terminal color for '.group
      continue
    endif
    call search('hi\%[ghlight] \+'.group, 'cW')
    " only check in the current line
    if !search('guifg', 'cnW', line('.'))   || !search('ctermfg', 'cnW', line('.'))
      " do not check for background colors, they could be intentionally left out
      let groups[group] = 'Missing fg definition for '.group
    endif
    call cursor(1,1)
  endfor
  let err['highlight'] = groups

  " 3) Check, that it does not set background highlighting
  " Doesn't ':hi Normal ctermfg=253 ctermfg=233' also set the background sometimes?
  let bg_set='\(set\?\|setl\(ocal\)\?\) .*\(background\|bg\)=\(dark\|light\)'
  let bg_let='let \%([&]\%([lg]:\)\?\)\%(background\|bg\)\s*=\s*\([''"]\?\)\w\+\1'
  let bg_pat='\%('.bg_set. '\|'.bg_let.'\)'
  let line=search(bg_pat, 'cnW')
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
  let pat='hi\%[ghlight]\s*clear\n\s*if\s*exists(\([''"]\)syntax_on\1)\n\s*syn\%[tax]\s*reset\n\s*endif'
  if !search(pat, 'cnW')
    let err['init'] = 'No initialization'
  endif

  " 6) Does not use :syn on
  if search('syn\%[tax]\s\+on', 'cnW')
    let err['background'] = 'Should not issue :syn on'
  endif

  " 7) Does not define filetype specfic groups like vimCommand, htmlTag,
  let hi_groups = ['vim', 'html', 'python', 'sh', 'ruby']
  for group in hi_groups
    let pat='\Chi\%[ghlight]\s*\zs'.group.'\w\+\>'
    if search(pat, 'cnW')
      let line = search(pat, 'cW')
      let err['filetype'] = get(err, 'filetype', 'Should not define: ') . matchstr(getline('.'), pat). ' '
    endif
    call cursor(1,1)
  endfor
  let g:err = err

  " print Result
  call Result(err)
endfu

fu! Result(err)
  let do_roups = 0
  echohl Title|echomsg "---------------"|echohl Normal
  for key in sort(keys(a:err))
    if key is# 'highlight'
      let do_groups = 1
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
