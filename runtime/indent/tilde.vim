"Description: Indent scheme for the tilde weblanguage
"Author: Tobias Rundström <tobi@tobi.nu>
"URL: http://tilde.tildesoftware.net
"Last Change: May  8 09:15:09 CEST 2002

if exists ("b:did_indent")
	finish
endif

let b:did_indent = 1

setlocal autoindent
setlocal indentexpr=GetTildeIndent(v:lnum)
setlocal indentkeys=o,O,)

if exists("*GetTildeIndent")
	finish
endif

function GetTildeIndent(lnum)
	let plnum = prevnonblank(v:lnum-1)

	if plnum == 0
		return 0
	endif

	if getline(v:lnum) =~ '^\s*\~\(endif\|else\|elseif\|end\)\>'
		return indent(v:lnum) - &sw
	endif

	if getline(plnum) =~ '^\s*\~\(if\|foreach\|foreach_row\|xml_loop\|file_loop\|file_write\|file_append\|imap_loopsections\|imap_index\|imap_list\|ldap_search\|post_loopall\|post_loop\|file_loop\|sql_loop_num\|sql_dbmsselect\|search\|sql_loop\|post\|for\|function_define\|silent\|while\|setvalbig\|mail_create\|systempipe\|mail_send\|dual\|elseif\|else\)\>'
		return indent(plnum) + &sw
	else
		return -1
	endif
endfunction
