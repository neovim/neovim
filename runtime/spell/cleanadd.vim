" Vim script to clean the ll.xxxxx.add files of commented out entries
" Author:	Antonio Colombo, Bram Moolenaar
" Last Update:	2008 Jun 3

" Time in seconds after last time an ll.xxxxx.add file was updated
" Default is one second.
" If you invoke this script often set it to something bigger, e.g. 60 * 60
" (one hour)
if !exists("g:spell_clean_limit")
  let g:spell_clean_limit = 1
endif

" Loop over all the runtime/spell/*.add files.
" Delete all comment lines, except the ones starting with ##.
for s:fname in split(globpath(&rtp, "spell/*.add"), "\n")
  if filewritable(s:fname) && localtime() - getftime(s:fname) > g:spell_clean_limit
    if exists('*fnameescape')
      let s:f = fnameescape(s:fname)
    else
      let s:f = escape(s:fname, ' \|<')
    endif
    silent exe "tab split " . s:f
    echo "Processing" s:f
    silent! g/^#[^#]/d
    silent update
    close
    unlet s:f
  endif
endfor
unlet s:fname

echo "Done"
