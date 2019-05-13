function! s:enhance_syntax() abort
  syntax case match

  syntax keyword healthError ERROR[:]
        \ containedin=markdownCodeBlock,mkdListItemLine
  highlight default link healthError Error

  syntax keyword healthWarning WARNING[:]
        \ containedin=markdownCodeBlock,mkdListItemLine
  highlight default link healthWarning WarningMsg

  syntax keyword healthSuccess OK[:]
        \ containedin=markdownCodeBlock,mkdListItemLine
  highlight default healthSuccess guibg=#5fff00 guifg=#080808 ctermbg=82 ctermfg=232

  syntax match healthHelp "|.\{-}|" contains=healthBar
        \ containedin=markdownCodeBlock,mkdListItemLine
  syntax match healthBar  "|" contained conceal
  highlight default link healthHelp Identifier

  " We do not care about markdown syntax errors in :checkhealth output.
  highlight! link markdownError Normal
endfunction

" Runs the specified healthchecks.
" Runs all discovered healthchecks if a:plugin_names is empty.
function! health#check(plugin_names) abort
  let healthchecks = empty(a:plugin_names)
        \ ? s:discover_health_checks()
        \ : s:to_fn_names(a:plugin_names)

  tabnew
  setlocal wrap breakindent linebreak
  setlocal filetype=markdown
  setlocal conceallevel=2 concealcursor=nc
  setlocal keywordprg=:help
  let &l:iskeyword='!-~,^*,^|,^",192-255'
  call s:enhance_syntax()

  if empty(healthchecks)
    call setline(1, 'ERROR: No healthchecks found.')
  else
    redraw|echo 'Running healthchecks...'
    for c in healthchecks
      let output = ''
      call append('$', split(printf("\n%s\n%s", c, repeat('=',72)), "\n"))
      try
        let output = "\n\n".execute('call '.c.'()')
      catch
        if v:exception =~# '^Vim\%((\a\+)\)\=:E117.*\V'.c
          let output = execute(
                \ 'call health#report_error(''No healthcheck found for "'
                \ .s:to_plugin_name(c)
                \ .'" plugin.'')')
        else
          let output = execute(
                \ 'call health#report_error(''Failed to run healthcheck for "'
                \ .s:to_plugin_name(c)
                \ .'" plugin. Exception:''."\n".v:throwpoint."\n".v:exception)')
        endif
      endtry
      call append('$', split(output, "\n") + [''])
      redraw
    endfor
  endif

  " needed for plasticboy/vim-markdown, because it uses fdm=expr
  normal! zR
  setlocal nomodified
  setlocal bufhidden=hide
  redraw|echo ''
endfunction

" Starts a new report.
function! health#report_start(name) abort
  echo "\n## " . a:name
endfunction

" Indents lines *except* line 1 of a string if it contains newlines.
function! s:indent_after_line1(s, columns) abort
  let lines = split(a:s, "\n", 0)
  if len(lines) < 2  " We do not indent line 1, so nothing to do.
    return a:s
  endif
  for i in range(1, len(lines)-1)  " Indent lines after the first.
    let lines[i] = substitute(lines[i], '^\s*', repeat(' ', a:columns), 'g')
  endfor
  return join(lines, "\n")
endfunction

" Changes ':h clipboard' to ':help |clipboard|'.
function! s:help_to_link(s) abort
  return substitute(a:s, '\v:h%[elp] ([^|][^"\r\n ]+)', ':help |\1|', 'g')
endfunction

" Format a message for a specific report item.
" a:1: Optional advice (string or list)
function! s:format_report_message(status, msg, ...) abort " {{{
  let output = '  - ' . a:status . ': ' . s:indent_after_line1(a:msg, 4)

  " Optional parameters
  if a:0 > 0
    let advice = type(a:1) == type('') ? [a:1] : a:1
    if type(advice) != type([])
      throw 'a:1: expected String or List'
    endif

    " Report each suggestion
    if !empty(advice)
      let output .= "\n    - ADVICE:"
      for suggestion in advice
        let output .= "\n      - " . s:indent_after_line1(suggestion, 10)
      endfor
    endif
  endif

  return s:help_to_link(output)
endfunction " }}}

" Use {msg} to report information in the current section
function! health#report_info(msg) abort " {{{
  echo s:format_report_message('INFO', a:msg)
endfunction " }}}

" Reports a successful healthcheck.
function! health#report_ok(msg) abort " {{{
  echo s:format_report_message('OK', a:msg)
endfunction " }}}

" Reports a health warning.
" a:1: Optional advice (string or list)
function! health#report_warn(msg, ...) abort " {{{
  if a:0 > 0
    echo s:format_report_message('WARNING', a:msg, a:1)
  else
    echo s:format_report_message('WARNING', a:msg)
  endif
endfunction " }}}

" Reports a failed healthcheck.
" a:1: Optional advice (string or list)
function! health#report_error(msg, ...) abort " {{{
  if a:0 > 0
    echo s:format_report_message('ERROR', a:msg, a:1)
  else
    echo s:format_report_message('ERROR', a:msg)
  endif
endfunction " }}}

function! s:filepath_to_function(name) abort
  return substitute(substitute(substitute(a:name, '.*autoload[\/]', '', ''),
        \ '\.vim', '#check', ''), '[\/]', '#', 'g')
endfunction

function! s:discover_health_checks() abort
  let healthchecks = globpath(&runtimepath, 'autoload/health/*.vim', 1, 1)
  let healthchecks = map(healthchecks, '<SID>filepath_to_function(v:val)')
  return healthchecks
endfunction

" Translates a list of plugin names to healthcheck function names.
function! s:to_fn_names(plugin_names) abort
  let healthchecks = []
  let plugin_names = type('') ==# type(a:plugin_names)
        \ ? split(a:plugin_names, '', v:false)
        \ : a:plugin_names
  for p in plugin_names
    call add(healthchecks, 'health#'.p.'#check')
  endfor
  return healthchecks
endfunction

" Extracts 'foo' from 'health#foo#check'.
function! s:to_plugin_name(fn_name) abort
  return substitute(a:fn_name,
        \ '\v.*health\#(.+)\#check.*', '\1', '')
endfunction
