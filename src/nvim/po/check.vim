" Vim script for checking .po files.
"
" Go through the file and verify that:
" - All %...s items in "msgid" are identical to the ones in "msgstr".
" - An error or warning code in "msgid" matches the one in "msgstr".

if 1	" Only execute this if the eval feature is available.

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

" This only works when 'wrapscan' is set.
let s:save_wrapscan = &wrapscan
set wrapscan

" Start at the first "msgid" line.
1
/^msgid
let startline = line('.')
let error = 0

while 1
  if getline(line('.') - 1) !~ "no-c-format"
    let fromline = GetMline()
    if getline('.') !~ '^msgstr'
      echo 'Missing "msgstr" in line ' . line('.')
      let error = 1
    endif
    let toline = GetMline()
    if fromline != toline
      echo 'Mismatching % in line ' . (line('.') - 1)
      echo 'msgid: ' . fromline
      echo 'msgstr: ' . toline
      let error = 1
    endif
  endif

  " Find next msgid.
  " Wrap around at the end of the file, quit when back at the first one.
  /^msgid
  if line('.') == startline
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
  echo 'Mismatching error/warning code in line ' . line('.')
  let error = 1
endif

if error == 0
  echo "OK"
endif

let &wrapscan = s:save_wrapscan
unlet s:save_wrapscan

endif
