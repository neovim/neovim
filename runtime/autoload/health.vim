" Dictionary where we keep all of the healtch check functions we've found.
" They will only be run if they are true
let g:health_checkers = get(g:, 'health_checkers', {})
let s:current_checker = get(s:, 'current_checker', '')

""
" Function to run the health checkers
" It manages the output and any file local settings
function! health#check(bang) abort
  let l:report = '# Checking health'

  if g:health_checkers == {}
    call s:add_checker(s:_default_checkers())
  endif

  for l:checker in items(g:health_checkers)
    " Disabled checkers will not run their registered check functions
    if l:checker[1]
      let s:current_checker = l:checker[0]
      let l:report .= "\n\n--------------------------------------------------------------------------------\n"
      let l:report .= printf("\n## Checker %s says:\n", s:current_checker)

      let l:report .= capture('silent! call ' . l:checker[0] . '()')
    endif
  endfor

  let l:report .= "\n--------------------------------------------------------------------------------\n"

  if a:bang
    new
    setlocal bufhidden=wipe
    set syntax=health
    set filetype=health
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

" Report functions {{{

" Pass arguments through
" fun! Foo(arg, ...)
"     if a:0
"         exe 'call Bar(a:arg1, a:arg2, ' . join(map(range(a:0), '"a:000[" . v:val . "]"'), ', ') . ')'
"     else
"         call Bar(a:arg, "foo")
"     endif
" endfunction

""
" Start a report section.
" It should represent a general area of tests that can be understood
" from the argument {name}
" To start a new report section, use this function again
function! health#report_start(name) abort " {{{
  echo '  - Checking: ' . a:name
endfunction " }}}

""
" Format a message for a specific report item
function! s:format_report_message(status, msg, ...) abort " {{{
  let l:output = '    - ' . a:status . ': ' . a:msg

  " Check optional parameters
  if a:0 > 0
    " Suggestions go in the first optional parameter can be a string or list
    if type(a:1) == type("")
      let l:output .= "\n      - SUGGESTIONS:"
      let l:output .= "\n        - " . a:1
    elseif type(a:1) == type([])
      " Report each suggestion
      let l:output .= "\n      - SUGGESTIONS:"
      for l:suggestion in a:1
        let l:output .= "\n        - " . l:suggestion
      endfor
    else
      echoerr "A string or list is required as the optional argument for suggestions"
    endif
  endif

  return output
endfunction " }}}

""
" Report informative text
function! health#report_info(msg) abort " {{{
  echo s:format_report_message('INFO', a:msg)
endfunction " }}}

""
" Use {msg} to represent the check that has passed
function! health#report_ok(msg) abort " {{{
  echo s:format_report_message('SUCCESS', a:msg)
endfunction " }}}

""
" Use {msg} to represent a failed health check and optionally a list of suggestions on how to fix it.
function! health#report_warn(msg, ...) abort " {{{
  if a:0 > 0 && type(a:1) == type([])
    echo s:format_report_message('WARNING', a:msg, a:1)
  else
    echo s:format_report_message('WARNING', a:msg)
  endif
endfunction " }}}

""
" Use {msg} to represent a critically failed health check and optionally a list of suggestions on how to fix it.
function! health#report_error(msg, ...) abort " {{{
  if a:0 > 0 && type(a:1) == type([])
    echo s:format_report_message('ERROR', a:msg, a:1)
  else
    echo s:format_report_message('ERROR', a:msg)
  endif
endfunction " }}}

" }}}
" Health checker management {{{

""
" Register a single health checker
function! s:add_single_checker(checker_name) abort " {{{
  if has_key(g:health_checkers, a:checker_name)
    " TODO: What to do if it's already there?
    return
  else
      let g:health_checkers[a:checker_name] = v:true
  endif
endfunction " }}}

""
" Register at least one healthcheckers.
" {checker_name} can be specified by either a list of strings or a single string.
function! s:add_checker(checker_name) abort " {{{
  if type(a:checker_name) == type('')
    call s:add_single_checker(a:checker_name)
  elseif type(a:checker_name) == type([])
    for checker in a:checker_name
      call s:add_single_checker(checker)
    endfor
  endif
endfunction " }}}

function! health#disable_checker(checker_name) abort " {{{
  if has_key(g:health_checkers, a:checker_name)
    let g:health_checkers[a:checker_name] = v:false
  else
    " TODO: What to do if it's not already there?
    return
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
" }}}
