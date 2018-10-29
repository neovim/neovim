" Vim indent file
" Language:	PHP
" Author:	John Wellesz <John.wellesz (AT) teaser (DOT) fr>
" URL:		http://www.2072productions.com/vim/indent/php.vim
" Home:		https://github.com/2072/PHP-Indenting-for-VIm
" Last Change:	2018 May 18th
" Version:	1.66
"
"
"	Type :help php-indent for available options
"
"	A fully commented version of this file is available on github
"
"
"  If you find a bug, please open a ticket on github.org
"  ( https://github.com/2072/PHP-Indenting-for-VIm/issues ) with an example of
"  code that breaks the algorithm.
"

" NOTE: This script must be used with PHP syntax ON and with the php syntax
"	script by Lutz Eymers (http://www.isp.de/data/php.vim ) or with the
"	script by Peter Hodge (http://www.vim.org/scripts/script.php?script_id=1571 )
"	the later is bunbdled by default with Vim 7.
"
"
"	In the case you have syntax errors in your script such as HereDoc end
"	identifiers not at col 1 you'll have to indent your file 2 times (This
"	script will automatically put HereDoc end identifiers at col 1 if
"	they are followed by a ';').
"

" NOTE: If you are editing files in Unix file format and that (by accident)
"	there are '\r' before new lines, this script won't be able to proceed
"	correctly and will make many mistakes because it won't be able to match
"	'\s*$' correctly.
"	So you have to remove those useless characters first with a command like:
"
"	:%s /\r$//g
"
"	or simply 'let' the option PHP_removeCRwhenUnix to 1 and the script will
"	silently remove them when VIM load this script (at each bufread).



if exists("b:did_indent")
    finish
endif
let b:did_indent = 1


let g:php_sync_method = 0


if exists("PHP_default_indenting")
    let b:PHP_default_indenting = PHP_default_indenting * shiftwidth()
else
    let b:PHP_default_indenting = 0
endif

if exists("PHP_outdentSLComments")
    let b:PHP_outdentSLComments = PHP_outdentSLComments * shiftwidth()
else
    let b:PHP_outdentSLComments = 0
endif

if exists("PHP_BracesAtCodeLevel")
    let b:PHP_BracesAtCodeLevel = PHP_BracesAtCodeLevel
else
    let b:PHP_BracesAtCodeLevel = 0
endif


if exists("PHP_autoformatcomment")
    let b:PHP_autoformatcomment = PHP_autoformatcomment
else
    let b:PHP_autoformatcomment = 1
endif

if exists("PHP_outdentphpescape")
    let b:PHP_outdentphpescape = PHP_outdentphpescape
else
    let b:PHP_outdentphpescape = 1
endif

if exists("PHP_noArrowMatching")
    let b:PHP_noArrowMatching = PHP_noArrowMatching
else
    let b:PHP_noArrowMatching = 0
endif


if exists("PHP_vintage_case_default_indent") && PHP_vintage_case_default_indent
    let b:PHP_vintage_case_default_indent = 1
else
    let b:PHP_vintage_case_default_indent = 0
endif



let b:PHP_lastindented = 0
let b:PHP_indentbeforelast = 0
let b:PHP_indentinghuge = 0
let b:PHP_CurrentIndentLevel = b:PHP_default_indenting
let b:PHP_LastIndentedWasComment = 0
let b:PHP_InsideMultilineComment = 0
let b:InPHPcode = 0
let b:InPHPcode_checked = 0
let b:InPHPcode_and_script = 0
let b:InPHPcode_tofind = ""
let b:PHP_oldchangetick = b:changedtick
let b:UserIsTypingComment = 0
let b:optionsset = 0

setlocal nosmartindent
setlocal noautoindent
setlocal nocindent
setlocal nolisp

setlocal indentexpr=GetPhpIndent()
setlocal indentkeys=0{,0},0),0],:,!^F,o,O,e,*<Return>,=?>,=<?,=*/



let s:searchpairflags = 'bWr'

if &fileformat == "unix" && exists("PHP_removeCRwhenUnix") && PHP_removeCRwhenUnix
    silent! %s/\r$//g
endif

if exists("*GetPhpIndent")
    call ResetPhpOptions()
    finish
endif


let s:PHP_validVariable = '[a-zA-Z_\x7f-\xff][a-zA-Z0-9_\x7f-\xff]*'
let s:notPhpHereDoc = '\%(break\|return\|continue\|exit\|die\|else\)'
let s:blockstart = '\%(\%(\%(}\s*\)\=else\%(\s\+\)\=\)\=if\>\|\%(}\s*\)\?else\>\|do\>\|while\>\|switch\>\|case\>\|default\>\|for\%(each\)\=\>\|declare\>\|class\>\|trait\>\|use\>\|interface\>\|abstract\>\|final\>\|try\>\|\%(}\s*\)\=catch\>\|\%(}\s*\)\=finally\>\)'
let s:functionDecl = '\<function\>\%(\s\+&\='.s:PHP_validVariable.'\)\=\s*(.*'
let s:endline = '\s*\%(//.*\|#.*\|/\*.*\*/\s*\)\=$'
let s:unstated = '\%(^\s*'.s:blockstart.'.*)\|\%(//.*\)\@<!\<e'.'lse\>\)'.s:endline


let s:terminated = '\%(\%(;\%(\s*\%(?>\|}\)\)\=\|<<<\s*[''"]\=\a\w*[''"]\=$\|^\s*}\|^\s*'.s:PHP_validVariable.':\)'.s:endline.'\)'
let s:PHP_startindenttag = '<?\%(.*?>\)\@!\|<script[^>]*>\%(.*<\/script>\)\@!'
let s:structureHead = '^\s*\%(' . s:blockstart . '\)\|'. s:functionDecl . s:endline . '\|\<new\s\+class\>'


let s:escapeDebugStops = 0
function! DebugPrintReturn(scriptLine)

    if ! s:escapeDebugStops
	echo "debug:" . a:scriptLine
	let c = getchar()
	if c == "\<Del>"
	    let s:escapeDebugStops = 1
	end
    endif

endfunction

function! GetLastRealCodeLNum(startline) " {{{

    let lnum = a:startline

    if b:GetLastRealCodeLNum_ADD && b:GetLastRealCodeLNum_ADD == lnum + 1
	let lnum = b:GetLastRealCodeLNum_ADD
    endif

    while lnum > 1
	let lnum = prevnonblank(lnum)
	let lastline = getline(lnum)

	if b:InPHPcode_and_script && lastline =~ '?>\s*$'
	    let lnum = lnum - 1
	elseif lastline =~ '^\s*?>.*<?\%(php\)\=\s*$'
	    let lnum = lnum - 1
	elseif lastline =~ '^\s*\%(//\|#\|/\*.*\*/\s*$\)'
	    let lnum = lnum - 1
	elseif lastline =~ '\*/\s*$'
	    call cursor(lnum, 1)
	    if lastline !~ '^\*/'
		call search('\*/', 'W')
	    endif
	    let lnum = searchpair('/\*', '', '\*/', s:searchpairflags, 'Skippmatch2()')

	    let lastline = getline(lnum)
	    if lastline =~ '^\s*/\*'
		let lnum = lnum - 1
	    else
		break
	    endif


	elseif lastline =~? '\%(//\s*\|?>.*\)\@<!<?\%(php\)\=\s*$\|^\s*<script\>'

	    while lastline !~ '\(<?.*\)\@<!?>' && lnum > 1
		let lnum = lnum - 1
		let lastline = getline(lnum)
	    endwhile
	    if lastline =~ '^\s*?>'
		let lnum = lnum - 1
	    else
		break
	    endif


	elseif lastline =~? '^\a\w*;\=$' && lastline !~? s:notPhpHereDoc
	    let tofind=substitute( lastline, '\(\a\w*\);\=', '<<<\\s*[''"]\\=\1[''"]\\=$', '')
	    while getline(lnum) !~? tofind && lnum > 1
		let lnum = lnum - 1
	    endwhile
	elseif lastline =~ '^[^''"`]*[''"`][;,]'.s:endline

	    let tofind=substitute( lastline, '^.*\([''"`]\)[;,].*$', '^[^\1]\\+[\1]$\\|^[^\1]\\+[=([]\\s*[\1]', '')
	    let trylnum = lnum
	    while getline(trylnum) !~? tofind && trylnum > 1
		let trylnum = trylnum - 1
	    endwhile

	    if trylnum == 1
		break
	    else
		if lastline =~ ';'.s:endline
		    while getline(trylnum) !~? s:terminated && getline(trylnum) !~? '{'.s:endline && trylnum > 1
			let trylnum = prevnonblank(trylnum - 1)
		    endwhile


		    if trylnum == 1
			break
		    end
		end
		let lnum = trylnum
	    end
	else
	    break
	endif
    endwhile

    if lnum==1 && getline(lnum) !~ '<?'
	let lnum=0
    endif

    if b:InPHPcode_and_script && 1 > b:InPHPcode
	let b:InPHPcode_and_script = 0
    endif

    return lnum
endfunction " }}}

function! Skippmatch2()

    let line = getline(".")

    if line =~ "\\([\"']\\).*/\\*.*\\1" || line =~ '\%(//\|#\).*/\*'
	return 1
    else
	return 0
    endif
endfun

function! Skippmatch()	" {{{
    let synname = synIDattr(synID(line("."), col("."), 0), "name")
    if synname ==? "Delimiter" || synname ==? "phpRegionDelimiter" || synname =~? "^phpParent" || synname ==? "phpArrayParens" || synname =~? '^php\%(Block\|Brace\)' || synname ==? "javaScriptBraces" || synname =~? '^php\%(Doc\)\?Comment' && b:UserIsTypingComment
	return 0
    else
	return 1
    endif
endfun " }}}

function! FindOpenBracket(lnum, blockStarter) " {{{
    call cursor(a:lnum, 1)
    let line = searchpair('{', '', '}', 'bW', 'Skippmatch()')

    if a:blockStarter == 1
	while line > 1
	    let linec = getline(line)

	    if linec =~ s:terminated || linec =~ s:structureHead
		break
	    endif

	    let line = GetLastRealCodeLNum(line - 1)
	endwhile
    endif

    return line
endfun " }}}

let s:blockChars = {'{':1, '[': 1, '(': 1, ')':-1, ']':-1, '}':-1}
function! BalanceDirection (str)

    let balance = 0

    for c in split(a:str, '\zs')
	if has_key(s:blockChars, c)
	    let balance += s:blockChars[c]
	endif
    endfor

    return balance
endfun

function! StripEndlineComments (line)
    return substitute(a:line,"\\(//\\|#\\)\\(\\(\\([^\"']*\\([\"']\\)[^\"']*\\5\\)\\+[^\"']*$\\)\\|\\([^\"']*$\\)\\)",'','')
endfun

function! FindArrowIndent (lnum)  " {{{

    let parrentArrowPos = 0
    let lnum = a:lnum
    while lnum > 1
	let last_line = getline(lnum)
	if last_line =~ '^\s*->'
	    let parrentArrowPos = indent(a:lnum)
	    break
	else
	    call cursor(lnum, 1)
	    let cleanedLnum = StripEndlineComments(last_line)
	    if cleanedLnum =~ '->'
		if ! b:PHP_noArrowMatching
		    let parrentArrowPos = searchpos('->', 'W', lnum)[1] - 1
		else
		    let parrentArrowPos = indent(lnum) + shiftwidth()
		endif
		break
	    elseif cleanedLnum =~ ')'.s:endline && BalanceDirection(last_line) < 0
		call searchpos(')'.s:endline, 'cW', lnum)
		let openedparent = searchpair('(', '', ')', 'bW', 'Skippmatch()')
		if openedparent != lnum
		    let lnum = openedparent
		else
		    let openedparent = -1
		endif

	    else
		let parrentArrowPos = indent(lnum) + shiftwidth()
		break
	    endif
	endif
    endwhile

    return parrentArrowPos
endfun "}}}

function! FindTheIfOfAnElse (lnum, StopAfterFirstPrevElse) " {{{

    if getline(a:lnum) =~# '^\s*}\s*else\%(if\)\=\>'
	let beforeelse = a:lnum
    else
	let beforeelse = GetLastRealCodeLNum(a:lnum - 1)
    endif

    if !s:level
	let s:iftoskip = 0
    endif

    if getline(beforeelse) =~# '^\s*\%(}\s*\)\=else\%(\s*if\)\@!\>'
	let s:iftoskip = s:iftoskip + 1
    endif

    if getline(beforeelse) =~ '^\s*}'
	let beforeelse = FindOpenBracket(beforeelse, 0)

	if getline(beforeelse) =~ '^\s*{'
	    let beforeelse = GetLastRealCodeLNum(beforeelse - 1)
	endif
    endif


    if !s:iftoskip && a:StopAfterFirstPrevElse && getline(beforeelse) =~# '^\s*\%([}]\s*\)\=else\%(if\)\=\>'
	return beforeelse
    endif

    if getline(beforeelse) !~# '^\s*if\>' && beforeelse>1 || s:iftoskip && beforeelse>1

	if s:iftoskip && getline(beforeelse) =~# '^\s*if\>'
	    let s:iftoskip = s:iftoskip - 1
	endif

	let s:level =  s:level + 1
	let beforeelse = FindTheIfOfAnElse(beforeelse, a:StopAfterFirstPrevElse)
    endif

    return beforeelse

endfunction " }}}

let s:defaultORcase = '^\s*\%(default\|case\).*:'

function! FindTheSwitchIndent (lnum) " {{{

    let test = GetLastRealCodeLNum(a:lnum - 1)

    if test <= 1
	return indent(1) - shiftwidth() * b:PHP_vintage_case_default_indent
    end

    while getline(test) =~ '^\s*}' && test > 1
	let test = GetLastRealCodeLNum(FindOpenBracket(test, 0) - 1)

	if getline(test) =~ '^\s*switch\>'
	    let test = GetLastRealCodeLNum(test - 1)
	endif
    endwhile

    if getline(test) =~# '^\s*switch\>'
	return indent(test)
    elseif getline(test) =~# s:defaultORcase
	return indent(test) - shiftwidth() * b:PHP_vintage_case_default_indent
    else
	return FindTheSwitchIndent(test)
    endif

endfunction "}}}

let s:SynPHPMatchGroups = {'phpparent':1, 'delimiter':1, 'define':1, 'storageclass':1, 'structure':1, 'exception':1}
function! IslinePHP (lnum, tofind) " {{{
    let cline = getline(a:lnum)

    if a:tofind==""
	let tofind = "^\\s*[\"'`]*\\s*\\zs\\S"
    else
	let tofind = a:tofind
    endif

    let tofind = tofind . '\c'

    let coltotest = match (cline, tofind) + 1

    let synname = synIDattr(synID(a:lnum, coltotest, 0), "name")

    if synname ==? 'phpStringSingle' || synname ==? 'phpStringDouble' || synname ==? 'phpBacktick'
	if cline !~ '^\s*[''"`]'
	    return "SpecStringEntrails"
	else
	    return synname
	end
    end

    if get(s:SynPHPMatchGroups, tolower(synname)) || synname =~ '^php' ||  synname =~? '^javaScript'
	return synname
    else
	return ""
    endif
endfunction " }}}

let s:autoresetoptions = 0
if ! s:autoresetoptions
    let s:autoresetoptions = 1
endif

function! ResetPhpOptions()
    if ! b:optionsset && &filetype =~ "php"
	if b:PHP_autoformatcomment

	    setlocal comments=s1:/*,mb:*,ex:*/,://,:#

	    setlocal formatoptions-=t
	    setlocal formatoptions+=q
	    setlocal formatoptions+=r
	    setlocal formatoptions+=o
	    setlocal formatoptions+=c
	    setlocal formatoptions+=b
	endif
	let b:optionsset = 1
    endif
endfunc

call ResetPhpOptions()

function! GetPhpIndentVersion()
    return "1.66-bundle"
endfun

function! GetPhpIndent()

    let b:GetLastRealCodeLNum_ADD = 0

    let UserIsEditing=0
    if	b:PHP_oldchangetick != b:changedtick
	let b:PHP_oldchangetick = b:changedtick
	let UserIsEditing=1
    endif

    if b:PHP_default_indenting
	let b:PHP_default_indenting = g:PHP_default_indenting * shiftwidth()
    endif

    let cline = getline(v:lnum)

    if !b:PHP_indentinghuge && b:PHP_lastindented > b:PHP_indentbeforelast
	if b:PHP_indentbeforelast
	    let b:PHP_indentinghuge = 1
	endif
	let b:PHP_indentbeforelast = b:PHP_lastindented
    endif

    if b:InPHPcode_checked && prevnonblank(v:lnum - 1) != b:PHP_lastindented
	if b:PHP_indentinghuge
	    let b:PHP_indentinghuge = 0
	    let b:PHP_CurrentIndentLevel = b:PHP_default_indenting
	endif
	let real_PHP_lastindented = v:lnum
	let b:PHP_LastIndentedWasComment=0
	let b:PHP_InsideMultilineComment=0
	let b:PHP_indentbeforelast = 0

	let b:InPHPcode = 0
	let b:InPHPcode_checked = 0
	let b:InPHPcode_and_script = 0
	let b:InPHPcode_tofind = ""

    elseif v:lnum > b:PHP_lastindented
	let real_PHP_lastindented = b:PHP_lastindented
    else
	let real_PHP_lastindented = v:lnum
    endif

    let b:PHP_lastindented = v:lnum


    if !b:InPHPcode_checked " {{{ One time check
	let b:InPHPcode_checked = 1
	let b:UserIsTypingComment = 0

	let synname = ""
	if cline !~ '<?.*?>'
	    let synname = IslinePHP (prevnonblank(v:lnum), "")
	endif

	if synname!=""
	    if synname ==? "SpecStringEntrails"
		let b:InPHPcode = -1 " thumb down
		let b:InPHPcode_tofind = ""
	    elseif synname !=? "phpHereDoc" && synname !=? "phpHereDocDelimiter"
		let b:InPHPcode = 1
		let b:InPHPcode_tofind = ""

		if synname =~? '^php\%(Doc\)\?Comment'
		    let b:UserIsTypingComment = 1
		    let b:InPHPcode_checked = 0
		endif

		if synname =~? '^javaScript'
		    let b:InPHPcode_and_script = 1
		endif

	    else
		let b:InPHPcode = 0

		let lnum = v:lnum - 1
		while getline(lnum) !~? '<<<\s*[''"]\=\a\w*[''"]\=$' && lnum > 1
		    let lnum = lnum - 1
		endwhile

		let b:InPHPcode_tofind = substitute( getline(lnum), '^.*<<<\s*[''"]\=\(\a\w*\)[''"]\=$', '^\\s*\1;\\=$', '')
	    endif
	else
	    let b:InPHPcode = 0
	    let b:InPHPcode_tofind = s:PHP_startindenttag
	endif
    endif "!b:InPHPcode_checked }}}


    " Test if we are indenting PHP code {{{
    let lnum = prevnonblank(v:lnum - 1)
    let last_line = getline(lnum)
    let endline= s:endline

    if b:InPHPcode_tofind!=""
	if cline =~? b:InPHPcode_tofind
	    let b:InPHPcode_tofind = ""
	    let b:UserIsTypingComment = 0

	    if b:InPHPcode == -1
		let b:InPHPcode = 1
		return -1
	    end

	    let b:InPHPcode = 1

	    if cline =~ '\*/'
		call cursor(v:lnum, 1)
		if cline !~ '^\*/'
		    call search('\*/', 'W')
		endif
		let lnum = searchpair('/\*', '', '\*/', s:searchpairflags, 'Skippmatch2()')

		let b:PHP_CurrentIndentLevel = b:PHP_default_indenting

		let b:PHP_LastIndentedWasComment = 0

		if cline =~ '^\s*\*/'
		    return indent(lnum) + 1
		else
		    return indent(lnum)
		endif

	    elseif cline =~? '<script\>'
		let b:InPHPcode_and_script = 1
		let b:GetLastRealCodeLNum_ADD = v:lnum
	    endif
	endif
    endif

    if 1 == b:InPHPcode

	if !b:InPHPcode_and_script && last_line =~ '\%(<?.*\)\@<!?>\%(.*<?\)\@!' && IslinePHP(lnum, '?>')=~?"Delimiter"
	    if cline !~? s:PHP_startindenttag
		let b:InPHPcode = 0
		let b:InPHPcode_tofind = s:PHP_startindenttag
	    elseif cline =~? '<script\>'
		let b:InPHPcode_and_script = 1
	    endif

	elseif last_line =~ '^[^''"`]\+[''"`]$' " a string identifier with nothing after it and no other string identifier before
	    let b:InPHPcode = -1
	    let b:InPHPcode_tofind = substitute( last_line, '^.*\([''"`]\).*$', '^[^\1]*\1[;,]$', '')
	elseif last_line =~? '<<<\s*[''"]\=\a\w*[''"]\=$'
	    let b:InPHPcode = 0
	    let b:InPHPcode_tofind = substitute( last_line, '^.*<<<\s*[''"]\=\(\a\w*\)[''"]\=$', '^\\s*\1;\\=$', '')

	elseif !UserIsEditing && cline =~ '^\s*/\*\%(.*\*/\)\@!' && getline(v:lnum + 1) !~ '^\s*\*'
	    let b:InPHPcode = 0
	    let b:InPHPcode_tofind = '\*/'

	elseif cline =~? '^\s*</script>'
	    let b:InPHPcode = 0
	    let b:InPHPcode_tofind = s:PHP_startindenttag
	endif
    endif " }}}


    if 1 > b:InPHPcode && !b:InPHPcode_and_script
	return -1
    endif

    " Indent successive // or # comment the same way the first is {{{
    let addSpecial = 0
    if cline =~ '^\s*\%(//\|#\|/\*.*\*/\s*$\)'
	let addSpecial = b:PHP_outdentSLComments
	if b:PHP_LastIndentedWasComment == 1
	    return indent(real_PHP_lastindented)
	endif
	let b:PHP_LastIndentedWasComment = 1
    else
	let b:PHP_LastIndentedWasComment = 0
    endif " }}}

    " Indent multiline /* comments correctly {{{

    if b:PHP_InsideMultilineComment || b:UserIsTypingComment
	if cline =~ '^\s*\*\%(\/\)\@!'
	    if last_line =~ '^\s*/\*'
		return indent(lnum) + 1
	    else
		return indent(lnum)
	    endif
	else
	    let b:PHP_InsideMultilineComment = 0
	endif
    endif

    if !b:PHP_InsideMultilineComment && cline =~ '^\s*/\*\%(.*\*/\)\@!'
	if getline(v:lnum + 1) !~ '^\s*\*'
	    return -1
	endif
	let b:PHP_InsideMultilineComment = 1
    endif " }}}


    " Things always indented at col 1 (PHP delimiter: <?, ?>, Heredoc end) {{{
    if cline =~# '^\s*<?' && cline !~ '?>' && b:PHP_outdentphpescape
	return 0
    endif

    if	cline =~ '^\s*?>' && cline !~# '<?' && b:PHP_outdentphpescape
	return 0
    endif

    if cline =~? '^\s*\a\w*;$\|^\a\w*$\|^\s*[''"`][;,]' && cline !~? s:notPhpHereDoc
	return 0
    endif " }}}

    let s:level = 0

    let lnum = GetLastRealCodeLNum(v:lnum - 1)

    let last_line = getline(lnum)
    let ind = indent(lnum)

    if ind==0 && b:PHP_default_indenting
	let ind = b:PHP_default_indenting
    endif

    if lnum == 0
	return b:PHP_default_indenting + addSpecial
    endif


    if cline =~ '^\s*}\%(}}\)\@!'
	let ind = indent(FindOpenBracket(v:lnum, 1))
	let b:PHP_CurrentIndentLevel = b:PHP_default_indenting
	return ind
    endif

    if cline =~ '^\s*\*/'
	call cursor(v:lnum, 1)
	if cline !~ '^\*/'
	    call search('\*/', 'W')
	endif
	let lnum = searchpair('/\*', '', '\*/', s:searchpairflags, 'Skippmatch2()')

	let b:PHP_CurrentIndentLevel = b:PHP_default_indenting

	if cline =~ '^\s*\*/'
	    return indent(lnum) + 1
	else
	    return indent(lnum)
	endif
    endif


    if last_line =~ '[;}]'.endline && last_line !~ '^[)\]]' && last_line !~# s:defaultORcase
	if ind==b:PHP_default_indenting
	    return b:PHP_default_indenting + addSpecial
	elseif b:PHP_indentinghuge && ind==b:PHP_CurrentIndentLevel && cline !~# '^\s*\%(else\|\%(case\|default\).*:\|[})];\=\)' && last_line !~# '^\s*\%(\%(}\s*\)\=else\)' && getline(GetLastRealCodeLNum(lnum - 1))=~';'.endline
	    return b:PHP_CurrentIndentLevel + addSpecial
	endif
    endif

    let LastLineClosed = 0

    let terminated = s:terminated

    let unstated  = s:unstated


    if ind != b:PHP_default_indenting && cline =~# '^\s*else\%(if\)\=\>'
	let b:PHP_CurrentIndentLevel = b:PHP_default_indenting
	return indent(FindTheIfOfAnElse(v:lnum, 1))
    elseif cline =~# s:defaultORcase
	return FindTheSwitchIndent(v:lnum) + shiftwidth() * b:PHP_vintage_case_default_indent
    elseif cline =~ '^\s*)\=\s*{'
	let previous_line = last_line
	let last_line_num = lnum

	while last_line_num > 1

	    if previous_line =~ terminated || previous_line =~ s:structureHead

		let ind = indent(last_line_num)

		if  b:PHP_BracesAtCodeLevel
		    let ind = ind + shiftwidth()
		endif

		return ind
	    endif

	    let last_line_num = GetLastRealCodeLNum(last_line_num - 1)
	    let previous_line = getline(last_line_num)
	endwhile
    elseif cline =~ '^\s*->'
	return FindArrowIndent(lnum)
    elseif last_line =~# unstated && cline !~ '^\s*);\='.endline
	let ind = ind + shiftwidth() " we indent one level further when the preceding line is not stated
	return ind + addSpecial

    elseif (ind != b:PHP_default_indenting || last_line =~ '^[)\]]' ) && last_line =~ terminated
	let previous_line = last_line
	let last_line_num = lnum
	let LastLineClosed = 1

	let isSingleLineBlock = 0
	while 1
	    if ! isSingleLineBlock && previous_line =~ '^\s*}\|;\s*}'.endline

		call cursor(last_line_num, 1)
		if previous_line !~ '^}'
		    call search('}\|;\s*}'.endline, 'W')
		end
		let oldLastLine = last_line_num
		let last_line_num = searchpair('{', '', '}', 'bW', 'Skippmatch()')

		if getline(last_line_num) =~ '^\s*{'
		    let last_line_num = GetLastRealCodeLNum(last_line_num - 1)
		elseif oldLastLine == last_line_num
		    let isSingleLineBlock = 1
		    continue
		endif

		let previous_line = getline(last_line_num)

		continue
	    else
		let isSingleLineBlock = 0

		if getline(last_line_num) =~# '^\s*else\%(if\)\=\>'
		    let last_line_num = FindTheIfOfAnElse(last_line_num, 0)
		    continue
		endif


		let last_match = last_line_num

		let one_ahead_indent = indent(last_line_num)
		let last_line_num = GetLastRealCodeLNum(last_line_num - 1)
		let two_ahead_indent = indent(last_line_num)
		let after_previous_line = previous_line
		let previous_line = getline(last_line_num)


		if previous_line =~# s:defaultORcase.'\|{'.endline
		    break
		endif

		if after_previous_line=~# '^\s*'.s:blockstart.'.*)'.endline && previous_line =~# '[;}]'.endline
		    break
		endif

		if one_ahead_indent == two_ahead_indent || last_line_num < 1
		    if previous_line =~# '\%(;\|^\s*}\)'.endline || last_line_num < 1
			break
		    endif
		endif
	    endif
	endwhile

	if indent(last_match) != ind
	    let ind = indent(last_match)
	    let b:PHP_CurrentIndentLevel = b:PHP_default_indenting

	    return ind + addSpecial
	endif
    endif

    if (last_line !~ '^\s*}\%(}}\)\@!')
	let plinnum = GetLastRealCodeLNum(lnum - 1)
    else
	let plinnum = GetLastRealCodeLNum(FindOpenBracket(lnum, 1) - 1)
    endif

    let AntepenultimateLine = getline(plinnum)

    let last_line = StripEndlineComments(last_line)

    if ind == b:PHP_default_indenting
	if last_line =~ terminated && last_line !~# s:defaultORcase
	    let LastLineClosed = 1
	endif
    endif

    if !LastLineClosed

	let openedparent = -1


	if last_line =~# '[{(\[]'.endline || last_line =~? '\h\w*\s*(.*,$' && AntepenultimateLine !~ '[,(\[]'.endline && BalanceDirection(last_line) > 0

	    let dontIndent = 0
	    if last_line =~ '\S\+\s*{'.endline && last_line !~ '^\s*[)\]]\+\(\s*:\s*'.s:PHP_validVariable.'\)\=\s*{'.endline && last_line !~ s:structureHead
		let dontIndent = 1
	    endif

	    if !dontIndent && (!b:PHP_BracesAtCodeLevel || last_line !~# '^\s*{')
		let ind = ind + shiftwidth()
	    endif

	    if b:PHP_BracesAtCodeLevel || b:PHP_vintage_case_default_indent == 1
		let b:PHP_CurrentIndentLevel = ind

	    endif

	elseif last_line =~ '),'.endline && BalanceDirection(last_line) < 0
	    call cursor(lnum, 1)
	    call searchpos('),'.endline, 'cW')
	    let openedparent = searchpair('(', '', ')', 'bW', 'Skippmatch()')
	    if openedparent != lnum
		let ind = indent(openedparent)
	    endif

	elseif last_line =~ s:structureHead
	    let ind = ind + shiftwidth()


	elseif AntepenultimateLine =~ '{'.endline && AntepenultimateLine !~? '^\s*use\>' || AntepenultimateLine =~ terminated || AntepenultimateLine =~# s:defaultORcase
	    let ind = ind + shiftwidth()
	endif


	if openedparent >= 0
	    let last_line = StripEndlineComments(getline(openedparent))
	endif
    endif

    if cline =~ '^\s*[)\]];\='
	let ind = ind - shiftwidth()
    endif

    if last_line =~ '^\s*->' && last_line !~? s:structureHead && BalanceDirection(last_line) <= 0
	let ind = ind - shiftwidth()
    endif

    let b:PHP_CurrentIndentLevel = ind
    return ind + addSpecial
endfunction
