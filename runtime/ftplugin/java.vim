" Vim filetype plugin file
" Language:		Java
" Maintainer:		Aliaksei Budavei <0x000c70 AT gmail DOT com>
" Former Maintainer:	Dan Sharp
" Repository:		https://github.com/zzzyxwvut/java-vim.git
" Last Change:		2024 Dec 16
"			2024 Jan 14 by Vim Project (browsefilter)
"			2024 May 23 by Riley Bruins <ribru17@gmail.com> ('commentstring')

" Make sure the continuation lines below do not cause problems in
" compatibility mode.
let s:save_cpo = &cpo
set cpo-=C

if (exists("g:java_ignore_javadoc") || exists("g:java_ignore_markdown")) &&
	\ exists("*javaformat#RemoveCommonMarkdownWhitespace")
    delfunction javaformat#RemoveCommonMarkdownWhitespace
    unlet! g:loaded_javaformat
endif

if exists("b:did_ftplugin")
    let &cpo = s:save_cpo
    unlet s:save_cpo
    finish
endif

let b:did_ftplugin = 1

" For filename completion, prefer the .java extension over the .class
" extension.
set suffixes+=.class

" Enable gf on import statements.  Convert . in the package
" name to / and append .java to the name, then search the path.
setlocal includeexpr=substitute(v:fname,'\\.','/','g')
setlocal suffixesadd=.java

" Clean up in case this file is sourced again.
unlet! s:zip_func_upgradable

"""" STRIVE TO REMAIN COMPATIBLE FOR AT LEAST VIM 7.0.

" Documented in ":help ft-java-plugin".
if exists("g:ftplugin_java_source_path") &&
		\ type(g:ftplugin_java_source_path) == type("")
    if filereadable(g:ftplugin_java_source_path)
	if exists("#zip") &&
		    \ g:ftplugin_java_source_path =~# '.\.\%(jar\|zip\)$'
	    if !exists("s:zip_files")
		let s:zip_files = {}
	    endif

	    let s:zip_files[bufnr('%')] = g:ftplugin_java_source_path
	    let s:zip_files[0] = g:ftplugin_java_source_path
	    let s:zip_func_upgradable = 1

	    function! JavaFileTypeZipFile() abort
		let @/ = substitute(v:fname, '\.', '\\/', 'g') . '.java'
		return get(s:zip_files, bufnr('%'), s:zip_files[0])
	    endfunction

	    " E120 for "inex=s:JavaFileTypeZipFile()" before v8.2.3900.
	    setlocal includeexpr=JavaFileTypeZipFile()
	    setlocal suffixesadd<
	endif
    else
	let &l:path = g:ftplugin_java_source_path . ',' . &l:path
    endif
endif

" Set 'formatoptions' to break comment lines but not other lines,
" and insert the comment leader when hitting <CR> or using "o".
setlocal formatoptions-=t formatoptions+=croql

" Set 'comments' to format Markdown Javadoc comments and dashed lists
" in other multi-line comments (it behaves just like C).
setlocal comments& comments^=:///,sO:*\ -,mO:*\ \ ,exO:*/

setlocal commentstring=//\ %s

" Change the :browse e filter to primarily show Java-related files.
if (has("gui_win32") || has("gui_gtk")) && !exists("b:browsefilter")
    let  b:browsefilter="Java Files (*.java)\t*.java\n" .
		\	"Properties Files (*.prop*)\t*.prop*\n" .
		\	"Manifest Files (*.mf)\t*.mf\n"
    if has("win32")
	let b:browsefilter .= "All Files (*.*)\t*\n"
    else
	let b:browsefilter .= "All Files (*)\t*\n"
    endif
endif

"""" Support pre- and post-compiler actions for SpotBugs.
if (!empty(get(g:, 'spotbugs_properties', {})) ||
	\ !empty(get(b:, 'spotbugs_properties', {}))) &&
	\ filereadable($VIMRUNTIME . '/compiler/spotbugs.vim')

    function! s:SpotBugsGetProperty(name, default) abort
	return get(
	    \ {s:spotbugs_properties_scope}spotbugs_properties,
	    \ a:name,
	    \ a:default)
    endfunction

    function! s:SpotBugsHasProperty(name) abort
	return has_key(
	    \ {s:spotbugs_properties_scope}spotbugs_properties,
	    \ a:name)
    endfunction

    function! s:SpotBugsGetProperties() abort
	return {s:spotbugs_properties_scope}spotbugs_properties
    endfunction

    " Work around ":bar"s and ":autocmd"s.
    function! s:ExecuteActionOnce(cleanup_cmd, action_cmd) abort
	try
	    execute a:cleanup_cmd
	finally
	    execute a:action_cmd
	endtry
    endfunction

    if exists("b:spotbugs_properties")
	let s:spotbugs_properties_scope = 'b:'

	" Merge global entries, if any, in buffer-local entries, favouring
	" defined buffer-local ones.
	call extend(
	    \ b:spotbugs_properties,
	    \ get(g:, 'spotbugs_properties', {}),
	    \ 'keep')
    elseif exists("g:spotbugs_properties")
	let s:spotbugs_properties_scope = 'g:'
    endif

    let s:commands = {}

    for s:name in ['DefaultPreCompilerCommand',
	    \ 'DefaultPreCompilerTestCommand',
	    \ 'DefaultPostCompilerCommand']
	if s:SpotBugsHasProperty(s:name)
	    let s:commands[s:name] = remove(
		\ s:SpotBugsGetProperties(),
		\ s:name)
	endif
    endfor

    if s:SpotBugsHasProperty('compiler')
	" XXX: Postpone loading the script until all state, if any, has been
	" collected.
	if !empty(s:commands)
	    let g:spotbugs#state = {
		\ 'compiler': remove(s:SpotBugsGetProperties(), 'compiler'),
		\ 'commands': copy(s:commands),
	    \ }
	else
	    let g:spotbugs#state = {
		\ 'compiler': remove(s:SpotBugsGetProperties(), 'compiler'),
	    \ }
	endif

	" Merge default entries in global (or buffer-local) entries, favouring
	" defined global (or buffer-local) ones.
	call extend(
	    \ {s:spotbugs_properties_scope}spotbugs_properties,
	    \ spotbugs#DefaultProperties(),
	    \ 'keep')
    elseif !empty(s:commands)
	" XXX: Postpone loading the script until all state, if any, has been
	" collected.
	let g:spotbugs#state = {'commands': copy(s:commands)}
    endif

    unlet s:commands s:name
    let s:request = 0

    if s:SpotBugsHasProperty('PostCompilerAction')
	let s:request += 4
    endif

    if s:SpotBugsHasProperty('PreCompilerTestAction')
	let s:dispatcher = printf('call call(%s, [])',
	    \ string(s:SpotBugsGetProperties().PreCompilerTestAction))
	let s:request += 2
    endif

    if s:SpotBugsHasProperty('PreCompilerAction')
	let s:dispatcher = printf('call call(%s, [])',
	    \ string(s:SpotBugsGetProperties().PreCompilerAction))
	let s:request += 1
    endif

    " Adapt the tests for "s:FindClassFiles()" from "compiler/spotbugs.vim".
    if (s:request == 3 || s:request == 7) &&
	    \ (!empty(s:SpotBugsGetProperty('sourceDirPath', [])) &&
		\ !empty(s:SpotBugsGetProperty('classDirPath', [])) &&
	    \ !empty(s:SpotBugsGetProperty('testSourceDirPath', [])) &&
		\ !empty(s:SpotBugsGetProperty('testClassDirPath', [])))
	function! s:DispatchAction(paths_action_pairs) abort
	    let name = expand('%:p')

	    for [paths, Action] in a:paths_action_pairs
		for path in paths
		    if name =~# (path . '.\{-}\.java\=$')
			call Action()
			return
		    endif
		endfor
	    endfor
	endfunction

	let s:dir_cnt = min([
	    \ len(s:SpotBugsGetProperties().sourceDirPath),
	    \ len(s:SpotBugsGetProperties().classDirPath)])
	let s:test_dir_cnt = min([
	    \ len(s:SpotBugsGetProperties().testSourceDirPath),
	    \ len(s:SpotBugsGetProperties().testClassDirPath)])

	" Do not break up path pairs with filtering!
	let s:dispatcher = printf('call s:DispatchAction(%s)',
	    \ string([[s:SpotBugsGetProperties().sourceDirPath[0 : s:dir_cnt - 1],
			\ s:SpotBugsGetProperties().PreCompilerAction],
		\ [s:SpotBugsGetProperties().testSourceDirPath[0 : s:test_dir_cnt - 1],
			\ s:SpotBugsGetProperties().PreCompilerTestAction]]))
	unlet s:test_dir_cnt s:dir_cnt
    endif

    if exists("s:dispatcher")
	function! s:ExecuteActions(pre_action, post_action) abort
	    try
		execute a:pre_action
	    catch /\<E42:/
		execute a:post_action
	    endtry
	endfunction
    endif

    if s:request
	if exists("b:spotbugs_syntax_once") || empty(join(getline(1, 8), ''))
	    let s:actions = [{'event': 'User'}]
	else
	    " XXX: Handle multiple FileType events when vimrc contains more
	    " than one filetype setting for the language, e.g.:
	    "	:filetype plugin indent on
	    "	:autocmd BufRead,BufNewFile *.java setlocal filetype=java ...
	    " XXX: DO NOT ADD b:spotbugs_syntax_once TO b:undo_ftplugin !
	    let b:spotbugs_syntax_once = 1
	    let s:actions = [{
		    \ 'event': 'Syntax',
		    \ 'once': 1,
		\ }, {
		    \ 'event': 'User',
		\ }]
	endif

	for s:idx in range(len(s:actions))
	    if s:request == 7 || s:request == 6 || s:request == 5
		let s:actions[s:idx].cmd = printf('call s:ExecuteActions(%s, %s)',
		    \ string(s:dispatcher),
		    \ string(printf('compiler spotbugs | call call(%s, [])',
			\ string(s:SpotBugsGetProperties().PostCompilerAction))))
	    elseif s:request == 4
		let s:actions[s:idx].cmd = printf(
		    \ 'compiler spotbugs | call call(%s, [])',
		    \ string(s:SpotBugsGetProperties().PostCompilerAction))
	    elseif s:request == 3 || s:request == 2 || s:request == 1
		let s:actions[s:idx].cmd = printf('call s:ExecuteActions(%s, %s)',
		    \ string(s:dispatcher),
		    \ string('compiler spotbugs'))
	    else
		let s:actions[s:idx].cmd = ''
	    endif
	endfor

	if !exists("#java_spotbugs")
	    augroup java_spotbugs
	    augroup END
	endif

	" The events are defined in s:actions.
	silent! autocmd! java_spotbugs User <buffer>
	silent! autocmd! java_spotbugs Syntax <buffer>

	for s:action in s:actions
	    if has_key(s:action, 'once')
		execute printf('autocmd java_spotbugs %s <buffer> ' .
			\ 'call s:ExecuteActionOnce(%s, %s)',
		    \ s:action.event,
		    \ string(printf('autocmd! java_spotbugs %s <buffer>',
			\ s:action.event)),
		    \ string(s:action.cmd))
	    else
		execute printf('autocmd java_spotbugs %s <buffer> %s',
		    \ s:action.event,
		    \ s:action.cmd)
	    endif
	endfor

	unlet! s:action s:actions s:idx s:dispatcher
    endif

    delfunction s:SpotBugsGetProperties
    delfunction s:SpotBugsHasProperty
    delfunction s:SpotBugsGetProperty
    unlet! s:request s:spotbugs_properties_scope
endif

function! JavaFileTypeCleanUp() abort
    setlocal suffixes< suffixesadd< formatoptions< comments< commentstring< path< includeexpr<
    unlet! b:browsefilter

    " The concatenated removals may be misparsed as a User autocmd.
    silent! autocmd! java_spotbugs User <buffer>
    silent! autocmd! java_spotbugs Syntax <buffer>
endfunction

" Undo the stuff we changed.
let b:undo_ftplugin = 'call JavaFileTypeCleanUp() | delfunction JavaFileTypeCleanUp'

" See ":help vim9-mix".
if !has("vim9script")
    let &cpo = s:save_cpo
    unlet s:save_cpo
    finish
endif

if exists("s:zip_func_upgradable")
    delfunction! JavaFileTypeZipFile

    def! s:JavaFileTypeZipFile(): string
	@/ = substitute(v:fname, '\.', '\\/', 'g') .. '.java'
	return get(zip_files, bufnr('%'), zip_files[0])
    enddef

    setlocal includeexpr=s:JavaFileTypeZipFile()
    setlocal suffixesadd<
endif

if exists("*s:DispatchAction")
    def! s:DispatchAction(paths_action_pairs: list<list<any>>)
	const name: string = expand('%:p')

	for [paths: list<string>, Action: func: any] in paths_action_pairs
	    for path in paths
		if name =~# (path .. '.\{-}\.java\=$')
		    Action()
		    return
		endif
	    endfor
	endfor
    enddef
endif

" Restore the saved compatibility options.
let &cpo = s:save_cpo
unlet s:save_cpo
" vim: fdm=syntax sw=4 ts=8 noet sta
