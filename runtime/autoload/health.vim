
" Dictionary where we keep all of the healtch check functions we've found.
" They will only be run if they are true
let g:health_checkers = get(g:, 'health_checkers', {})

function! health#check(bang) abort
  echom 'Checking health'

  for l:doctor in items(g:health_checkers)
      if l:doctor[1]
          echo 'Doctor ' . l:doctor[0] . 'says: ' . l:doctor[1]

          call {l:doctor[0]}(a:bang)
      endif
  endfor

endfunction

" Report functions
function! health#dictate(sender, msg) abort
  echo a:sender . ' dictates ' . a:msg
endfunction

function! health#prescribe(sender, msg) abort
  echo a:sender . ' prescribes ' . a:msg
endfunction

function! health#suggest(sender, msg) abort
  echo a:sender . ' suggests ' . a:msg
endfunction

" Health checker management
function! health#add_checker(checker_name) abort
    if has_key(g:health_checkers, a:checker_name)
        " TODO: What to do if it's already there?
        return
    else
        let g:health_checkers[a:checker_name] = v:true
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
