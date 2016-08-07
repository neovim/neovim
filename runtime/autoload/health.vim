" Dictionary of all health check functions we have found.
" They will only be run if the value is true
let g:health_checkers = get(g:, 'health_checkers', {})
let s:current_checker = get(s:, 'current_checker', '')

function! s:enhance_syntax() abort
  syntax keyword healthError ERROR
  highlight link healthError Error

  syntax keyword healthWarning WARNING
  highlight link healthWarning WarningMsg

  syntax keyword healthInfo INFO
  highlight link healthInfo ModeMsg

  syntax keyword healthSuccess SUCCESS
  highlight link healthSuccess Function

  syntax keyword healthSuggestion SUGGESTION
  highlight link healthSuggestion String
endfunction

" Runs the health checkers. Manages the output and buffer-local settings.
function! health#check(bang) abort
  let l:report = ''

  if empty(g:health_checkers)
    call health#add_checker(s:_default_checkers())
  endif

  for l:checker in items(g:health_checkers)
    " Disabled checkers will not run their registered check functions
    if l:checker[1]
      let s:current_checker = l:checker[0]
      let l:report .= printf("\n%s\n================================================================================",
                            \ s:current_checker)

      let l:report .= execute('call ' . l:checker[0] . '()')
    endif
  endfor

  if a:bang
    new
    setlocal bufhidden=wipe
    set filetype=markdown
    call s:enhance_syntax()
    call setline(1, split(report, "\n"))
    setlocal nomodified
  else
    echo report
    echo "\nTip: Use "
    echohl Identifier
    echon ':CheckHealth!'
    echohl None
    echon ' to open this in a new buffer.'
  endif
endfunction

" Starts a new report.
function! health#report_start(name) abort " {{{
  echo "\n## " . a:name
endfunction " }}}

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

" Format a message for a specific report item
function! s:format_report_message(status, msg, ...) abort " {{{
  let output = '  - ' . a:status . ': ' . s:indent_after_line1(a:msg, 4)
  let suggestions = []

  " Optional parameters
  if a:0 > 0
    let suggestions = type(a:1) == type("") ? [a:1] : a:1
    if type(suggestions) != type([])
      echoerr "Expected String or List"
    endif
  endif

  " Report each suggestion
  if len(suggestions) > 0
    let output .= "\n      - SUGGESTIONS:"
  endif
  for suggestion in suggestions
    let output .= "\n        - " . s:indent_after_line1(suggestion, 10)
  endfor

  return output
endfunction " }}}

" Use {msg} to report information in the current section
function! health#report_info(msg) abort " {{{
  echo s:format_report_message('INFO', a:msg)
endfunction " }}}

" Use {msg} to represent the check that has passed
function! health#report_ok(msg) abort " {{{
  echo s:format_report_message('SUCCESS', a:msg)
endfunction " }}}

" Use {msg} to represent a failed health check and optionally a list of suggestions on how to fix it.
function! health#report_warn(msg, ...) abort " {{{
  if a:0 > 0
    echo s:format_report_message('WARNING', a:msg, a:1)
  else
    echo s:format_report_message('WARNING', a:msg)
  endif
endfunction " }}}

" Use {msg} to represent a critically failed health check and optionally a list of suggestions on how to fix it.
function! health#report_error(msg, ...) abort " {{{
  if a:0 > 0
    echo s:format_report_message('ERROR', a:msg, a:1)
  else
    echo s:format_report_message('ERROR', a:msg)
  endif
endfunction " }}}

" Adds a health checker. Does nothing if the checker already exists.
function! s:add_single_checker(checker_name) abort " {{{
  if has_key(g:health_checkers, a:checker_name)
    return
  else
      let g:health_checkers[a:checker_name] = v:true
  endif
endfunction " }}}

" Enables a health checker.
function! s:enable_single_checker(checker_name) abort " {{{
  let g:health_checkers[a:checker_name] = v:true
endfunction " }}}

" Disables a health checker.
function! s:disable_single_checker(checker_name) abort " {{{
  let g:health_checkers[a:checker_name] = v:false
endfunction " }}}


" Adds a health checker. `checker_name` can be a list of strings or
" a single string. Does nothing if the checker already exists.
function! health#add_checker(checker_name) abort " {{{
  if type(a:checker_name) == type('')
    call s:add_single_checker(a:checker_name)
  elseif type(a:checker_name) == type([])
    for checker in a:checker_name
      call s:add_single_checker(checker)
    endfor
  endif
endfunction " }}}

" Enables a health checker. `checker_name` can be a list of strings or
" a single string.
function! health#enable_checker(checker_name) abort " {{{
  if type(a:checker_name) == type('')
    call s:enable_single_checker(a:checker_name)
  elseif type(a:checker_name) == type([])
    for checker in a:checker_name
      call s:enable_single_checker(checker)
    endfor
  endif
endfunction " }}}

" Disables a health checker. `checker_name` can be a list of strings or
" a single string.
function! health#disable_checker(checker_name) abort " {{{
  if type(a:checker_name) == type('')
    call s:disable_single_checker(a:checker_name)
  elseif type(a:checker_name) == type([])
    for checker in a:checker_name
      call s:disable_single_checker(checker)
    endfor
  endif
endfunction " }}}

function! s:change_file_name_to_health_checker(name) abort " {{{
  return substitute(substitute(substitute(a:name, ".*autoload/", "", ""), "\\.vim", "#check", ""), "/", "#", "g")
endfunction " }}}

function! s:_default_checkers() abort " {{{
  " Get all of the files that are in autoload/health/ folders with a vim
  " suffix
  let checker_files = globpath(&runtimepath, 'autoload/health/*.vim', 1, 1)
  let temp = checker_files[0]

  let checkers_to_source = []
  for file_name in checker_files
    call add(checkers_to_source, s:change_file_name_to_health_checker(file_name))
  endfor
  return checkers_to_source
endfunction " }}}
