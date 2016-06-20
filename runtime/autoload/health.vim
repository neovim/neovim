
" Dictionary where we keep all of the healtch check functions we've found.
" They will only be run if they are true
let g:health_checkers = get(g:, 'health_checkers', {})
let s:current_checker = get(s:, 'current_checker', '')

function! health#check(bang) abort
  echom 'Checking health'

  for l:checker in items(g:health_checkers)
    " Disabled checkers will not run their registered check functions
    if l:checker[1]
      let s:current_checker = l:checker[0]
      echo 'Checker ' . s:current_checker . 'says: ' . l:checker[1]

      call {l:checker[0]}(a:bang)
    endif
  endfor

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

function! health#reportn(sender, msg) abrot
  echon a:sender . ' reportn ' . a:msg
endfunction

" Potential future functions
" function! health#dictate(sender, msg) abort
"   echo a:sender . ' dictates ' . a:msg
" endfunction

" function! health#prescribe(sender, msg) abort
"   echo a:sender . ' prescribes ' . a:msg
" endfunction

" function! health#suggest(sender, msg) abort
"   echo a:sender . ' suggests ' . a:msg
" endfunction

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
" health#add_checker is a function to register a (or several) healthcheckers.
" {checker_name} can be specified by either a list of strings or a single string.
" The string should be the name of the function to check, which should follow
" the naming convention of `health#plugin_name#check`
function! health#add_checker(checker_name) abort
  if type(a:checker_name) == type('')
    s:add_single_checker(a:checker_name)
  elseif type(a:checker_name) == type([])
    for checker in a:checker_name
      s:add_single_checker(checker)
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
