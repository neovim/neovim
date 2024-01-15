" Function to left and right align text.
"
" Written by:	Preben "Peppe" Guldberg <c928400@student.dtu.dk>
" Created:	980806 14:13 (or around that time anyway)
" Revised:	001103 00:36 (See "Revisions" below)


" function Justify( [ textwidth [, maxspaces [, indent] ] ] )
"
" Justify()  will  left  and  right  align  a  line  by  filling  in  an
" appropriate amount of spaces.  Extra  spaces  are  added  to  existing
" spaces starting from the right side of the line.  As an  example,  the
" following documentation has been justified.
"
" The function takes the following arguments:

" textwidth argument
" ------------------
" If not specified, the value of the 'textwidth'  option  is  used.   If
" 'textwidth' is zero a value of 80 is used.
"
" Additionally the arguments 'tw' and '' are  accepted.   The  value  of
" 'textwidth' will be used. These are handy, if you just want to specify
" the maxspaces argument.

" maxspaces argument
" ------------------
" If specified, alignment will only be done, if the  longest  space  run
" after alignment is no longer than maxspaces.
"
" An argument of '' is accepted, should the user  like  to  specify  all
" arguments.
"
" To aid user defined commands, negative  values  are  accepted  aswell.
" Using a negative value specifies the default behaviour: any length  of
" space runs will be used to justify the text.

" indent argument
" ---------------
" This argument specifies how a line should be indented. The default  is
" to keep the current indentation.
"
" Negative  values:  Keep  current   amount   of   leading   whitespace.
" Positive values: Indent all lines with leading whitespace  using  this
" amount of whitespace.
"
" Note that the value 0, needs to be quoted as  a  string.   This  value
" leads to a left flushed text.
"
" Additionally units of  'shiftwidth'/'sw'  and  'tabstop'/'ts'  may  be
" added. In this case, if the value of indent is positive, the amount of
" whitespace to be  added  will  be  multiplied  by  the  value  of  the
" 'shiftwidth' and 'tabstop' settings.  If these  units  are  used,  the
"  argument must  be  given  as  a  string,  eg.   Justify('','','2sw').
"
" If the values of 'sw' or 'tw' are negative, they  are  treated  as  if
" they were 0, which means that the text is flushed left.  There  is  no
" check if a negative number prefix is used to  change  the  sign  of  a
" negative 'sw' or 'ts' value.
"
" As with the other arguments,  ''  may  be  used  to  get  the  default
" behaviour.


" Notes:
"
" If the line, adjusted for space runs and leading/trailing  whitespace,
" is wider than the used textwidth, the line will be left untouched  (no
" whitespace removed).  This should be equivalent to  the  behaviour  of
" :left, :right and :center.
"
" If the resulting line is shorter than the used textwidth  it  is  left
" untouched.
"
" All space runs in the line  are  truncated  before  the  alignment  is
" carried out.
"
" If you have set 'noexpandtab', :retab!  is used to replace space  runs
"  with whitespace  using  the  value  of  'tabstop'.   This  should  be
" conformant with :left, :right and :center.
"
" If joinspaces is set, an extra space is added after '.', '?' and  '!'.
" If 'cpoptions' include 'j', extra space  is  only  added  after  '.'.
" (This may on occasion conflict with maxspaces.)


" Related mappings:
"
" Mappings that will align text using the current text width,  using  at
" most four spaces in a  space  run  and  keeping  current  indentation.
nmap _j :%call Justify('tw',4)<CR>
vmap _j :call Justify('tw',4)<CR>
"
" Mappings that will remove space runs and format lines (might be useful
" prior to aligning the text).
nmap ,gq :%s/\s\+/ /g<CR>gq1G
vmap ,gq :s/\s\+/ /g<CR>gvgq


" User defined command:
"
" The following is an ex command that works as a shortcut to the Justify
" function.  Arguments to Justify() can  be  added  after  the  command.
com! -range -nargs=* Justify <line1>,<line2>call Justify(<f-args>)
"
" The following commands are all equivalent:
"
" 1. Simplest use of Justify():
"       :call Justify()
"       :Justify
"
" 2. The _j mapping above via the ex command:
"       :%Justify tw 4
"
" 3.  Justify  visualised  text  at  72nd  column  while  indenting  all
" previously indented text two shiftwidths
"       :'<,'>call Justify(72,'','2sw')
"       :'<,'>Justify 72 -1 2sw
"
" This documentation has been justified  using  the  following  command:
":se et|kz|1;/^" function Justify(/+,'z-g/^" /s/^" //|call Justify(70,3)|s/^/" /

" Revisions:
" 001103: If 'joinspaces' was set, calculations could be wrong.
"	  Tabs at start of line could also lead to errors.
"	  Use setline() instead of "exec 's/foo/bar/' - safer.
"	  Cleaned up the code a bit.
"
" Todo:	  Convert maps to the new script specific form

" Error function
function! Justify_error(message)
    echohl Error
    echo "Justify([tw, [maxspaces [, indent]]]): " . a:message
    echohl None
endfunction


" Now for the real thing
function! Justify(...) range

    if a:0 > 3
    call Justify_error("Too many arguments (max 3)")
    return 1
    endif

    " Set textwidth (accept 'tw' and '' as arguments)
    if a:0 >= 1
	if a:1 =~ '^\(tw\)\=$'
	    let tw = &tw
	elseif a:1 =~ '^\d\+$'
	    let tw = a:1
	else
	    call Justify_error("tw must be a number (>0), '' or 'tw'")
	    return 2
	endif
    else
	let tw = &tw
    endif
    if tw == 0
	let tw = 80
    endif

    " Set maximum number of spaces between WORDs
    if a:0 >= 2
	if a:2 == ''
	    let maxspaces = tw
	elseif a:2 =~ '^-\d\+$'
	    let maxspaces = tw
	elseif a:2 =~ '^\d\+$'
	    let maxspaces = a:2
	else
	    call Justify_error("maxspaces must be a number or ''")
	    return 3
	endif
    else
	let maxspaces = tw
    endif
    if maxspaces <= 1
	call Justify_error("maxspaces should be larger than 1")
	return 4
    endif

    " Set the indentation style (accept sw and ts units)
    let indent_fix = ''
    if a:0 >= 3
	if (a:3 == '') || a:3 =~ '^-[1-9]\d*\(shiftwidth\|sw\|tabstop\|ts\)\=$'
	    let indent = -1
	elseif a:3 =~ '^-\=0\(shiftwidth\|sw\|tabstop\|ts\)\=$'
	    let indent = 0
	elseif a:3 =~ '^\d\+\(shiftwidth\|sw\|tabstop\|ts\)\=$'
	    let indent = substitute(a:3, '\D', '', 'g')
	elseif a:3 =~ '^\(shiftwidth\|sw\|tabstop\|ts\)$'
	    let indent = 1
	else
	    call Justify_error("indent: a number with 'sw'/'ts' unit")
	    return 5
	endif
	if indent >= 0
	    while indent > 0
		let indent_fix = indent_fix . ' '
		let indent = indent - 1
	    endwhile
	    let indent_sw = 0
	    if a:3 =~ '\(shiftwidth\|sw\)'
		let indent_sw = &sw
	    elseif a:3 =~ '\(tabstop\|ts\)'
		let indent_sw = &ts
	    endif
	    let indent_fix2 = ''
	    while indent_sw > 0
		let indent_fix2 = indent_fix2 . indent_fix
		let indent_sw = indent_sw - 1
	    endwhile
	    let indent_fix = indent_fix2
	endif
    else
	let indent = -1
    endif

    " Avoid substitution reports
    let save_report = &report
    set report=1000000

    " Check 'joinspaces' and 'cpo'
    if &js == 1
	if &cpo =~ 'j'
	    let join_str = '\(\. \)'
	else
	    let join_str = '\([.!?!] \)'
	endif
    endif

    let cur = a:firstline
    while cur <= a:lastline

	let str_orig = getline(cur)
	let save_et = &et
	set et
	exec cur . "retab"
	let &et = save_et
	let str = getline(cur)

	let indent_str = indent_fix
	let indent_n = strlen(indent_str)
	" Shall we remember the current indentation
	if indent < 0
	    let indent_orig = matchstr(str_orig, '^\s*')
	    if strlen(indent_orig) > 0
		let indent_str = indent_orig
		let indent_n = strlen(matchstr(str, '^\s*'))
	    endif
	endif

	" Trim trailing, leading and running whitespace
	let str = substitute(str, '\s\+$', '', '')
	let str = substitute(str, '^\s\+', '', '')
	let str = substitute(str, '\s\+', ' ', 'g')
	let str_n = strdisplaywidth(str)

	" Possible addition of space after punctuation
	if exists("join_str")
	    let str = substitute(str, join_str, '\1 ', 'g')
	endif
	let join_n = strdisplaywidth(str) - str_n

	" Can extraspaces be added?
	" Note that str_n may be less than strlen(str) [joinspaces above]
	if strdisplaywidth(str) <= tw - indent_n && str_n > 0
	    " How many spaces should be added
	    let s_add = tw - str_n - indent_n - join_n
	    let s_nr  = strlen(substitute(str, '\S', '', 'g') ) - join_n
	    let s_dup = s_add / s_nr
	    let s_mod = s_add % s_nr

	    " Test if the changed line fits with tw
	    if 0 <= (str_n + (maxspaces - 1)*s_nr + indent_n) - tw

		" Duplicate spaces
		while s_dup > 0
		    let str = substitute(str, '\( \+\)', ' \1', 'g')
		    let s_dup = s_dup - 1
		endwhile

		" Add extra spaces from the end
		while s_mod > 0
		    let str = substitute(str, '\(\(\s\+\S\+\)\{' . s_mod .  '}\)$', ' \1', '')
		    let s_mod = s_mod - 1
		endwhile

		" Indent the line
		if indent_n > 0
		    let str = substitute(str, '^', indent_str, '' )
		endif

		" Replace the line
		call setline(cur, str)

		" Convert to whitespace
		if &et == 0
		    exec cur . 'retab!'
		endif

	    endif   " Change of line
	endif	" Possible change

	let cur = cur + 1
    endwhile

    norm ^

    let &report = save_report

endfunction

" EOF	vim: tw=78 ts=8 sw=4 sts=4 noet ai
