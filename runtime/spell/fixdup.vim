" Vim script to fix duplicate words in a .dic file  vim: set ft=vim:
"
" Usage: Edit the .dic file and source this script.

let deleted = 0

" Start below the word count.
let lnum = 2
while lnum <= line('$')
  let word = getline(lnum)
  if word !~ '/'
    if search('^' . word . '/', 'w') != 0
      let deleted += 1
      exe lnum . "d"
      continue		" don't increment lnum, it's already at the next word
    endif
  endif
  let lnum += 1
endwhile

if deleted == 0
  echomsg "No duplicate words found"
elseif deleted == 1
  echomsg "Deleted 1 duplicate word"
else
  echomsg printf("Deleted %d duplicate words", deleted)
endif
