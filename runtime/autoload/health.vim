
" Dictionary where we keep all of the healtch check functions we've found.
" They will only be run if they are true
let g:health_checkers = get(g:, 'health_checkers', {})
let s:current_checker = get(s:, 'current_checker', '')

function! health#check(bang) abort
  let l:report = 'Checking health'


  for l:checker in items(g:health_checkers)
    " Disabled checkers will not run their registered check functions
    if l:checker[1]
      let s:current_checker = l:checker[0]
      let l:report .= printf("\nChecker %s says: %s", s:current_checker, l:checker[1])

      let l:report .= capture('silent! call ' . l:checker[0] . '()')

    endif
  endfor

  if a:bang
    new
    setlocal bufhidden=wipe
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

" Report functions
function! health#report(msg) abort
  if s:current_checker
    echo s:current_checker . ' reports ' . a:msg
  elseif
    " TODO: Not sure what to do if it's called without one, maybe just this?
    echo 'Reports ' . a:msg
  endif
endfunction

""
" This function starts a report.
" It should represent a general area of tests that can be understood
" from the argument {name}
" To start a new report, use this function again
function! health#report_start(name) abort
  echo '  - Diagnosing: ' . a:name
endfunction

""
" This function reports general information about the state of the environment
" Use {msg} to represent the information you wish to record about the
" environment
function! health#report_info(msg) abort
  echo '    - INFO: ' . a:msg
endfunction

""
" This function reports a succesful check within a report
" Use {msg} to represent the check that has passed
function! health#report_ok(msg) abort
  echo '    - SUCCESS: ' . a:msg
endfunction

""
" This function represents a check that has not gone correctly within a report
" However, even with the unsuccesful check, it makes sense to continue
" checking other health items. Use {msg} to represent the failed health check
" and optionally a list of suggestions on how to fix it.
function! health#report_warn(msg, ...) abort
  " Optional argument of suggestions
  if type(a:0) == type([])
    let l:suggestions = a:0
  else
    let l:suggestions = []
  endif

  echo '    - WARNING: ' . a:msg
  " echon '    - ' | echohl Error | echon 'WARNING ' | echohl None | echo ': ' . a:msg
  for l:suggestion in l:suggestions
    echo '      - SUGGESTION: ' . l:suggestion
  endfor

endfunction

""
" This function represents a check that has failed and because of it does not
" make sense to continue testing the health of the health checker.
" You can optionally give a list of suggestions as a second argument on how to
" fix it where applicable.
function! health#report_error(msg, ...) abort
  " Optional argument of suggestions
  if type(a:0) == type([])
    let l:suggestions = a:0
  else
    let l:suggestions = []
  endif

  " echo '    - ERROR  : ' . a:msg
  echon '    - '
  echohl Identifier | echon 'ERROR ' | echohl None | echon ': ' . a:msg
  for l:suggestion in l:suggestions
    echo '      - SUGGESTION: ' . l:suggestion
  endfor
endfunction

function! s:trim(s) abort
  return substitute(a:s, '^\_s*\|\_s*$', '', 'g')
endfunction

" Text wrapping that returns a list of lines
function! s:textwrap(text, width) abort
  let pattern = '.*\%(\s\+\|\_$\)\zs\%<'.a:width.'c'
  return map(split(a:text, pattern), 's:trim(v:val)')
endfunction

""
" Echo wrapped notes
function! health#report_notes(notes) abort
  if empty(a:notes)
    return
  endif

  echo '    - NOTE:'
  for msg in a:notes
    if msg =~# '\n'
      let msg_lines = []
      for msgl in filter(split(msg, '\n'), 'v:val !~# ''^\s*$''')
        call extend(msg_lines, s:textwrap(msgl, 74))
      endfor
    else
      let msg_lines = s:textwrap(msg, 74)
    endif

    if !len(msg_lines)
      continue
    endif
    echo '    - ' msg_lines[0]
    if len(msg_lines) > 1
      echo join(map(msg_lines[1:], '"      ".v:val'), "\n")
    endif
  endfor
endfunction

" Health checker management

""
" s:add_single_checker is a function to handle adding a checker of name
" {checker_name} to the list of health_checkers. It also enables it.
function! s:add_single_checker(checker_name) abort
  if has_key(g:health_checkers, a:checker_name)
    " TODO: What to do if it's already there?
    return
  else
    let g:health_checkers[a:checker_name] = v:true
  endif
endfunction

""
" health#add_checker is a function to register at least one healthcheckers.
" {checker_name} can be specified by either a list of strings or a single string.
" The string should be the name of the function to check, which should follow
" the naming convention of `health#plugin_name#check`
function! health#add_checker(checker_name) abort
  if type(a:checker_name) == type('')
    call s:add_single_checker(a:checker_name)
  elseif type(a:checker_name) == type([])
    for checker in a:checker_name
      call s:add_single_checker(checker)
    endfor
  endif
endfunction

function! health#enable_checker(checker_name) abort
  if has_key(g:health_checkers, a:checker_name)
    let g:health_checkers[a:checker_name] = v:true
  else
    " TODO: What to do if it's not already there?
    return
  endif
endfunction

function! health#disable_checker(checker_name) abort
  if has_key(g:health_checkers, a:checker_name)
    let g:health_checkers[a:checker_name] = v:false
  else
    " TODO: What to do if it's not already there?
    return
  endif
endfunction
