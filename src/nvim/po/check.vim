" Vim script for checking .po files.
"
" Goes through the xx.po file (more than once)
" and verify various congruences
" See the comments in the code

" Last Update: 2025 Aug 06

if 1 " Only execute this if the eval feature is available.

" Using line continuation (set cpo to vim default value)
let s:save_cpo = &cpo
set cpo&vim

" This only works when 'wrapscan' is not set.
let s:save_wrapscan = &wrapscan
set nowrapscan

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
  let idline = substitute(idline, "%%", '', 'g')

  " remove '%' used for plural forms.
  let idline = substitute(idline, '\\nPlural-Forms: .\+;\\n', '', '')

  " remove duplicate positional format arguments
  let idline2 = ""
  while idline2 != idline
    let idline2 = idline
    let idline = substitute(idline, '%\([1-9][0-9]*\)\$\([-+ #''.*]*[0-9]*l\=[dsuxXpoc%]\)\(.*\)%\1$\([-+ #''.*]*\)\(l\=[dsuxXpoc%]\)', '%\1$\2\3\4', 'g')
  endwhile

  " remove everything but % items.
  return substitute(idline, '[^%]*\(%([1-9][0-9]*\$)\=[-+ #''.0-9*]*l\=[dsuxXpoc%]\)\=', '\1', 'g')
endfunc

func! CountNl(first, last)
  let nl = 0
  for lnum in range(a:first, a:last)
    let nl += count(getline(lnum), "\n")
  endfor
  return nl
endfunc

" main

" Start at the first "msgid" line.
let wsv = winsaveview()
1
keeppatterns /^msgid\>

" When an error is detected this is set to the line number.
" Note: this is used in the Makefile.
let error = 0

while 1
  " for each "msgid"

  " check msgid "Text;editor;"
  " translation must have two or more ";" (in case of more categories)
  let lnum = line('.')
  if getline(lnum) =~ 'msgid "Text;.*;"'
    if getline(lnum + 1) !~ '^msgstr "\([^;]\+;\)\+"$'
      echomsg 'Mismatching ; in line ' . (lnum + 1)
      echomsg 'Wrong semicolon count'
      if error == 0
        let error = lnum + 1
      endif
    endif
  endif

  " check for equal number of % in msgid and msgstr
  " it is skipping the no-c-format strings
  if getline(line('.') - 1) !~ "no-c-format"
    " skip the "msgid_plural" lines
    let prevfromline = 'foobar'
    let plural = 0
    while 1
      if getline('.') =~ 'msgid_plural'
        let plural += 1
      endif
      let fromline = GetMline()
      if prevfromline != 'foobar' && prevfromline != fromline
            \ && (plural != 1
            \     || count(prevfromline, '%') + 1 != count(fromline, '%'))
        echomsg 'possibly mismatching % in line ' . (line('.') - 1)
        echomsg 'msgid: ' . prevfromline
        echomsg 'msgid: ' . fromline
        if error == 0
          let error = line('.')
        endif
      endif
      if getline('.') !~ 'msgid_plural'
        break
      endif
      let prevfromline = fromline
    endwhile

    " checks that for each 'msgid' there is a 'msgstr'
    if getline('.') !~ '^msgstr'
      echomsg 'Missing "msgstr" in line ' . line('.')
      if error == 0
        let error = line('.')
      endif
    endif

    " check all the 'msgstr' lines have the same number of '%'
    " only the number of '%' is checked,
    " %d vs. %s or %d vs. %ld  go undetected
    while getline('.') =~ '^msgstr'
      let toline = GetMline()
      if fromline != toline
            \ && (plural == 0 || count(fromline, '%') != count(toline, '%') + 1)
        echomsg 'possibly mismatching % in line ' . (line('.') - 1)
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
  silent! keeppatterns /^msgid\>
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

" Check that the \n at the end of the msgid line is also present in the msgstr
" line.  Skip over the header.
1
keeppatterns /^"MIME-Version:
while 1
  let lnum = search('^msgid\>')
  if lnum <= 0
    break
  endif
  let strlnum = search('^msgstr\>')
  let end = search('^$')
  if end <= 0
    let end = line('$') + 1
  endif
  let origcount = CountNl(lnum, strlnum - 1)
  let transcount = CountNl(strlnum, end - 1)
  " Allow for a few more or less line breaks when there are 2 or more
  if origcount != transcount && (origcount <= 2 || transcount <= 2)
    echomsg 'Mismatching "\n" in line ' . line('.')
    if error == 0
      let error = lnum
    endif
  endif
endwhile

" Check that the eventual continuation of 'msgstr' is well formed
" final '""', '\n"', ' "' '/"' '."' '-"' are OK
" Beware, it can give false positives if the message is split
" in the middle of a word
1
keeppatterns /^"MIME-Version:
while 1
  let lnum = search('^msgid\>')
  if lnum <= 0
    break
  endif
  " "msgstr" goes from strlnum to end-1
  let strlnum = search('^msgstr\>')
  let end = search('^$')
  if end <= 0
    let end = line('$') + 1
  endif
  " only if there is a continuation line...
  if end > strlnum + 1
    let ilnum = strlnum
    while ilnum < end - 1
      let iltype = 0
      if getline( ilnum ) =~ "^msgid_plural"
        let iltype = 2
      endif
      if getline( ilnum ) =~ "^msgstr["
        let iltype = 2
      endif
      if getline( ilnum ) =~ "\"\""
        let iltype = 1
      endif
      if getline( ilnum ) =~ " \"$"
        let iltype = 1
      endif
      if getline( ilnum ) =~ "-\"$"
        let iltype = 1
      endif
      if getline( ilnum ) =~ "/\"$"
        let iltype = 1
      endif
      if getline( ilnum ) =~ "\\.\"$"
        let iltype = 1
      endif
      if getline( ilnum ) =~ "\\\\n\"$"
        let iltype = 1
      endif
      if iltype == 0
        echomsg 'Possibly incorrect final at line: ' . ilnum
        " TODO: make this an error
        " if error == 0
        "   let error = ilnum
        " endif
      endif
      let ilnum += 1
    endwhile
  endif
endwhile

" Check that the file is well formed according to msgfmts understanding
if executable("msgfmt")
  let filename = expand("%")
  " Newer msgfmt does not take OLD_PO_FILE_INPUT argument, must be in
  " environment.
  let $OLD_PO_FILE_INPUT = 'yes'
  let a = system("msgfmt --statistics " . filename)
  if v:shell_error != 0
    let error = matchstr(a, filename.':\zs\d\+\ze:')+0
    for line in split(a, '\n') | echomsg line | endfor
  endif
endif

" Check that the plural form is properly initialized
1
let plural = search('^msgid_plural ', 'n')
if (plural && search('^"Plural-Forms: ', 'n') == 0) || (plural && search('^msgstr\[0\] ".\+"', 'n') != plural + 1)
  if search('^"Plural-Forms: ', 'n') == 0
    echomsg "Missing Plural header"
    if error == 0
      let error = search('\(^"[A-Za-z-_]\+: .*\\n"\n\)\+\zs', 'n') - 1
    endif
  elseif error == 0
    let error = plural
  endif
elseif !plural && search('^"Plural-Forms: ', 'n')
  " We allow for a stray plural header, msginit adds one.
endif

" Check that 8bit encoding is used instead of 8-bit
let cte = search('^"Content-Transfer-Encoding:\s\+8-bit', 'n')
let ctc = search('^"Content-Type:.*;\s\+\<charset=[iI][sS][oO]_', 'n')
let ctu = search('^"Content-Type:.*;\s\+\<charset=utf-8', 'n')
if cte
  echomsg "Warn: Content-Transfer-Encoding should be 8bit instead of 8-bit"
  " TODO: make this an error
  " if error == 0
  "   let error = cte
  " endif
elseif ctc
  echomsg "Warn: Content-Type charset should be 'ISO-...' instead of 'ISO_...'"
  " TODO: make this an error
  " if error == 0
  "   let error = ct
  " endif
elseif ctu
  echomsg "Warn: Content-Type charset should be 'UTF-8' instead of 'utf-8'"
  " TODO: make this an error
  " if error == 0
  "   let error = ct
  " endif
endif

" Check that no lines are longer than 80 chars (except comments)
let overlong = search('^[^#]\%>80v', 'n')
if overlong > 0
  echomsg "Warn: Lines should be wrapped at 80 columns"
  " TODO: make this an error
  " if error == 0
  "   let error = overlong
  " endif
endif

" Check that there is no trailing whitespace
let overlong = search('\s\+$', 'n')
if overlong > 0
  echomsg $"Warn: Trailing whitespace at line: {overlong}"
  " TODO: make this an error
  " if error == 0
  "   let error = overlong
  " endif
endif

if error == 0
  " If all was OK restore the view.
  call winrestview(wsv)
  echomsg "OK"
else
  " Put the cursor on the line with the error.
  exe error
endif

redir END

" restore original wrapscan
let &wrapscan = s:save_wrapscan
unlet s:save_wrapscan

" restore original cpo
let &cpo = s:save_cpo
unlet s:save_cpo

endif

" vim:sts=2:sw=2:et
