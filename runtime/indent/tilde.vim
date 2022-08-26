"Description: Indent scheme for the tilde weblanguage
"Author: Tobias Rundström <tobi@tobi.nu> (Invalid email address)
"URL: http://tilde.tildesoftware.net
"Last Change: May  8 09:15:09 CEST 2002
"	      2022 April: b:undo_indent added by Doug Kearns

if exists ("b:did_indent")
	finish
endif

let b:did_indent = 1

setlocal autoindent
setlocal indentexpr=GetTildeIndent(v:lnum)
setlocal indentkeys=o,O,)

let b:undo_indent = "setl ai< inde< indk<"

if exists("*GetTildeIndent")
	finish
endif

function GetTildeIndent(lnum)
	let plnum = prevnonblank(v:lnum-1)

	if plnum == 0
		return 0
	endif

	if getline(v:lnum) =~ '^\s*\~\(endif\|else\|elseif\|end\)\>'
		return indent(v:lnum) - shiftwidth()
	endif

	if getline(plnum) =~ '^\s*\~\(if\|foreach\|foreach_row\|xml_loop\|file_loop\|file_write\|file_append\|imap_loopsections\|imap_index\|imap_list\|ldap_search\|post_loopall\|post_loop\|file_loop\|sql_loop_num\|sql_dbmsselect\|search\|sql_loop\|post\|for\|function_define\|silent\|while\|setvalbig\|mail_create\|systempipe\|mail_send\|dual\|elseif\|else\)\>'
		return indent(plnum) + shiftwidth()
	else
		return -1
	endif
endfunction
