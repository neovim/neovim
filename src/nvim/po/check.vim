" Vim script for checking .po files.
"
" Go through the file and verify that:
" - All %...s items in "msgid" are identical to the ones in "msgstr".
" - An error or warning code in "msgid" matches the one in "msgstr".

if 1	" Only execute this if the eval feature is available.

let filename = "check-" . expand("%:t:r") . ".log"
exe 'redir! > ' . filename

" Function to get a split line at the cursor.
" Used for both msgid and msgstr lines.
" Removes all text except % items and returns the result.
func! GetMline()
  let idline = substitute(getline('.'), '"\(.*\)"$', '\1', '')
  while line('.') < line('$')
    +
    let line = getline('.')
    if line[0] != '"'
      break
    endif
    let idline .= substitute(line, '"\(.*\)"$', '\1', '')
  endwhile

  " remove '%', not used for formatting.
  let idline = substitute(idline, "'%'", '', 'g')

  " remove '%' used for plural forms.
  let idline = substitute(idline, '\\nPlural-Forms: .\+;\\n', '', '')

  " remove everything but % items.
  return substitute(idline, '[^%]*\(%[-+ #''.0-9*]*l\=[dsuxXpoc%]\)\=', '\1', 'g')
endfunc

" This only works when 'wrapscan' is not set.
let s:save_wrapscan = &wrapscan
set nowrapscan

" Start at the first "msgid" line.
1
/^msgid\>

" When an error is detected this is set to the line number.
" Note: this is used in the Makefile.
let error = 0

while 1
  if getline(line('.') - 1) !~ "no-c-format"
    " go over the "msgid" and "msgid_plural" lines
    let prevfromline = 'foobar'
    while 1
      let fromline = GetMline()
      if prevfromline != 'foobar' && prevfromline != fromline
	echomsg 'Mismatching % in line ' . (line('.') - 1)
	echomsg 'msgid: ' . prevfromline
	echomsg 'msgid ' . fromline
	if error == 0
	  let error = line('.')
	endif
      endif
      if getline('.') !~ 'msgid_plural'
	break
      endif
      let prevfromline = fromline
    endwhile

    if getline('.') !~ '^msgstr'
      echomsg 'Missing "msgstr" in line ' . line('.')
      if error == 0
	let error = line('.')
      endif
    endif

    " check all the 'msgstr' lines
    while getline('.') =~ '^msgstr'
      let toline = GetMline()
      if fromline != toline
	echomsg 'Mismatching % in line ' . (line('.') - 1)
	echomsg 'msgid: ' . fromline
	echomsg 'msgstr: ' . toline
	if error == 0
	  let error = line('.')
	endif
      endif
      if line('.') == line('$')
	break
      endif
    endwhile
  endif

  " Find next msgid.  Quit when there is no more.
  let lnum = line('.')
  silent! /^msgid\>
  if line('.') == lnum
    break
  endif
endwhile

" Check that error code in msgid matches the one in msgstr.
"
" Examples of mismatches found with msgid "E123: ..."
" - msgstr "E321: ..."    error code mismatch
" - msgstr "W123: ..."    warning instead of error
" - msgstr "E123 ..."     missing colon
" - msgstr "..."          missing error code
"
1
if search('msgid "\("\n"\)\?\([EW][0-9]\+:\).*\nmsgstr "\("\n"\)\?[^"]\@=\2\@!') > 0
  echomsg 'Mismatching error/warning code in line ' . line('.')
  if error == 0
    let error = line('.')
  endif
endif

if error == 0
  echomsg "OK"
else
  exe error
endif

redir END

let &wrapscan = s:save_wrapscan
unlet s:save_wrapscan

endif
