
" Dictionary where we keep all of the healtch check functions we've found.
" They will only be run if they are true
let g:healthchecks = {
            \ 'health#nvim#check': v:true,
            \ 'health#other#check': v:false,
            \ }

function! health#check(bang) abort
  echom 'Checking health'

  for l:doctor in items(g:healthchecks)
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
