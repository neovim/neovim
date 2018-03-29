" Author: Kevin Ballard
" Description: Helper functions for Rust commands/mappings
" Last Modified: May 27, 2014
" For bugs, patches and license go to https://github.com/rust-lang/rust.vim

" Jump {{{1

function! rust#Jump(mode, function) range
	let cnt = v:count1
	normal! m'
	if a:mode ==# 'v'
		norm! gv
	endif
	let foldenable = &foldenable
	set nofoldenable
	while cnt > 0
		execute "call <SID>Jump_" . a:function . "()"
		let cnt = cnt - 1
	endwhile
	let &foldenable = foldenable
endfunction

function! s:Jump_Back()
	call search('{', 'b')
	keepjumps normal! w99[{
endfunction

function! s:Jump_Forward()
	normal! j0
	call search('{', 'b')
	keepjumps normal! w99[{%
	call search('{')
endfunction

" Run {{{1

function! rust#Run(bang, args)
	let args = s:ShellTokenize(a:args)
	if a:bang
		let idx = index(l:args, '--')
		if idx != -1
			let rustc_args = idx == 0 ? [] : l:args[:idx-1]
			let args = l:args[idx+1:]
		else
			let rustc_args = l:args
			let args = []
		endif
	else
		let rustc_args = []
	endif

	let b:rust_last_rustc_args = l:rustc_args
	let b:rust_last_args = l:args

	call s:WithPath(function("s:Run"), rustc_args, args)
endfunction

function! s:Run(dict, rustc_args, args)
	let exepath = a:dict.tmpdir.'/'.fnamemodify(a:dict.path, ':t:r')
	if has('win32')
		let exepath .= '.exe'
	endif

	let relpath = get(a:dict, 'tmpdir_relpath', a:dict.path)
	let rustc_args = [relpath, '-o', exepath] + a:rustc_args

	let rustc = exists("g:rustc_path") ? g:rustc_path : "rustc"

	let pwd = a:dict.istemp ? a:dict.tmpdir : ''
	let output = s:system(pwd, shellescape(rustc) . " " . join(map(rustc_args, 'shellescape(v:val)')))
	if output != ''
		echohl WarningMsg
		echo output
		echohl None
	endif
	if !v:shell_error
		exe '!' . shellescape(exepath) . " " . join(map(a:args, 'shellescape(v:val)'))
	endif
endfunction

" Expand {{{1

function! rust#Expand(bang, args)
	let args = s:ShellTokenize(a:args)
	if a:bang && !empty(l:args)
		let pretty = remove(l:args, 0)
	else
		let pretty = "expanded"
	endif
	call s:WithPath(function("s:Expand"), pretty, args)
endfunction

function! s:Expand(dict, pretty, args)
	try
		let rustc = exists("g:rustc_path") ? g:rustc_path : "rustc"

		if a:pretty =~? '^\%(everybody_loops$\|flowgraph=\)'
			let flag = '--xpretty'
		else
			let flag = '--pretty'
		endif
		let relpath = get(a:dict, 'tmpdir_relpath', a:dict.path)
		let args = [relpath, '-Z', 'unstable-options', l:flag, a:pretty] + a:args
		let pwd = a:dict.istemp ? a:dict.tmpdir : ''
		let output = s:system(pwd, shellescape(rustc) . " " . join(map(args, 'shellescape(v:val)')))
		if v:shell_error
			echohl WarningMsg
			echo output
			echohl None
		else
			new
			silent put =output
			1
			d
			setl filetype=rust
			setl buftype=nofile
			setl bufhidden=hide
			setl noswapfile
			" give the buffer a nice name
			let suffix = 1
			let basename = fnamemodify(a:dict.path, ':t:r')
			while 1
				let bufname = basename
				if suffix > 1 | let bufname .= ' ('.suffix.')' | endif
				let bufname .= '.pretty.rs'
				if bufexists(bufname)
					let suffix += 1
					continue
				endif
				exe 'silent noautocmd keepalt file' fnameescape(bufname)
				break
			endwhile
		endif
	endtry
endfunction

function! rust#CompleteExpand(lead, line, pos)
	if a:line[: a:pos-1] =~ '^RustExpand!\s*\S*$'
		" first argument and it has a !
		let list = ["normal", "expanded", "typed", "expanded,identified", "flowgraph=", "everybody_loops"]
		if !empty(a:lead)
			call filter(list, "v:val[:len(a:lead)-1] == a:lead")
		endif
		return list
	endif

	return glob(escape(a:lead, "*?[") . '*', 0, 1)
endfunction

" Emit {{{1

function! rust#Emit(type, args)
	let args = s:ShellTokenize(a:args)
	call s:WithPath(function("s:Emit"), a:type, args)
endfunction

function! s:Emit(dict, type, args)
	try
		let output_path = a:dict.tmpdir.'/output'

		let rustc = exists("g:rustc_path") ? g:rustc_path : "rustc"

		let relpath = get(a:dict, 'tmpdir_relpath', a:dict.path)
		let args = [relpath, '--emit', a:type, '-o', output_path] + a:args
		let pwd = a:dict.istemp ? a:dict.tmpdir : ''
		let output = s:system(pwd, shellescape(rustc) . " " . join(map(args, 'shellescape(v:val)')))
		if output != ''
			echohl WarningMsg
			echo output
			echohl None
		endif
		if !v:shell_error
			new
			exe 'silent keepalt read' fnameescape(output_path)
			1
			d
			if a:type == "llvm-ir"
				setl filetype=llvm
				let extension = 'll'
			elseif a:type == "asm"
				setl filetype=asm
				let extension = 's'
			endif
			setl buftype=nofile
			setl bufhidden=hide
			setl noswapfile
			if exists('l:extension')
				" give the buffer a nice name
				let suffix = 1
				let basename = fnamemodify(a:dict.path, ':t:r')
				while 1
					let bufname = basename
					if suffix > 1 | let bufname .= ' ('.suffix.')' | endif
					let bufname .= '.'.extension
					if bufexists(bufname)
						let suffix += 1
						continue
					endif
					exe 'silent noautocmd keepalt file' fnameescape(bufname)
					break
				endwhile
			endif
		endif
	endtry
endfunction

" Utility functions {{{1

" Invokes func(dict, ...)
" Where {dict} is a dictionary with the following keys:
"   'path' - The path to the file
"   'tmpdir' - The path to a temporary directory that will be deleted when the
"              function returns.
"   'istemp' - 1 if the path is a file inside of {dict.tmpdir} or 0 otherwise.
" If {istemp} is 1 then an additional key is provided:
"   'tmpdir_relpath' - The {path} relative to the {tmpdir}.
"
" {dict.path} may be a path to a file inside of {dict.tmpdir} or it may be the
" existing path of the current buffer. If the path is inside of {dict.tmpdir}
" then it is guaranteed to have a '.rs' extension.
function! s:WithPath(func, ...)
	let buf = bufnr('')
	let saved = {}
	let dict = {}
	try
		let saved.write = &write
		set write
		let dict.path = expand('%')
		let pathisempty = empty(dict.path)

		" Always create a tmpdir in case the wrapped command wants it
		let dict.tmpdir = tempname()
		call mkdir(dict.tmpdir)

		if pathisempty || !saved.write
			let dict.istemp = 1
			" if we're doing this because of nowrite, preserve the filename
			if !pathisempty
				let filename = expand('%:t:r').".rs"
			else
				let filename = 'unnamed.rs'
			endif
			let dict.tmpdir_relpath = filename
			let dict.path = dict.tmpdir.'/'.filename

			let saved.mod = &mod
			set nomod

			silent exe 'keepalt write! ' . fnameescape(dict.path)
			if pathisempty
				silent keepalt 0file
			endif
		else
			let dict.istemp = 0
			update
		endif

		call call(a:func, [dict] + a:000)
	finally
		if bufexists(buf)
			for [opt, value] in items(saved)
				silent call setbufvar(buf, '&'.opt, value)
				unlet value " avoid variable type mismatches
			endfor
		endif
		if has_key(dict, 'tmpdir') | silent call s:RmDir(dict.tmpdir) | endif
	endtry
endfunction

function! rust#AppendCmdLine(text)
	call setcmdpos(getcmdpos())
	let cmd = getcmdline() . a:text
	return cmd
endfunction

" Tokenize the string according to sh parsing rules
function! s:ShellTokenize(text)
	" states:
	" 0: start of word
	" 1: unquoted
	" 2: unquoted backslash
	" 3: double-quote
	" 4: double-quoted backslash
	" 5: single-quote
	let l:state = 0
	let l:current = ''
	let l:args = []
	for c in split(a:text, '\zs')
		if l:state == 0 || l:state == 1 " unquoted
			if l:c ==# ' '
				if l:state == 0 | continue | endif
				call add(l:args, l:current)
				let l:current = ''
				let l:state = 0
			elseif l:c ==# '\'
				let l:state = 2
			elseif l:c ==# '"'
				let l:state = 3
			elseif l:c ==# "'"
				let l:state = 5
			else
				let l:current .= l:c
				let l:state = 1
			endif
		elseif l:state == 2 " unquoted backslash
			if l:c !=# "\n" " can it even be \n?
				let l:current .= l:c
			endif
			let l:state = 1
		elseif l:state == 3 " double-quote
			if l:c ==# '\'
				let l:state = 4
			elseif l:c ==# '"'
				let l:state = 1
			else
				let l:current .= l:c
			endif
		elseif l:state == 4 " double-quoted backslash
			if stridx('$`"\', l:c) >= 0
				let l:current .= l:c
			elseif l:c ==# "\n" " is this even possible?
				" skip it
			else
				let l:current .= '\'.l:c
			endif
			let l:state = 3
		elseif l:state == 5 " single-quoted
			if l:c == "'"
				let l:state = 1
			else
				let l:current .= l:c
			endif
		endif
	endfor
	if l:state != 0
		call add(l:args, l:current)
	endif
	return l:args
endfunction

function! s:RmDir(path)
	" sanity check; make sure it's not empty, /, or $HOME
	if empty(a:path)
		echoerr 'Attempted to delete empty path'
		return 0
	elseif a:path == '/' || a:path == $HOME
		echoerr 'Attempted to delete protected path: ' . a:path
		return 0
	endif
	return system("rm -rf " . shellescape(a:path))
endfunction

" Executes {cmd} with the cwd set to {pwd}, without changing Vim's cwd.
" If {pwd} is the empty string then it doesn't change the cwd.
function! s:system(pwd, cmd)
	let cmd = a:cmd
	if !empty(a:pwd)
		let cmd = 'cd ' . shellescape(a:pwd) . ' && ' . cmd
	endif
	return system(cmd)
endfunction

" Playpen Support {{{1
" Parts of gist.vim by Yasuhiro Matsumoto <mattn.jp@gmail.com> reused
" gist.vim available under the BSD license, available at
" http://github.com/mattn/gist-vim
function! s:has_webapi()
    if !exists("*webapi#http#post")
	try
	    call webapi#http#post()
	catch
	endtry
    endif
    return exists("*webapi#http#post")
endfunction

function! rust#Play(count, line1, line2, ...) abort
    redraw

    let l:rust_playpen_url = get(g:, 'rust_playpen_url', 'https://play.rust-lang.org/')
    let l:rust_shortener_url = get(g:, 'rust_shortener_url', 'https://is.gd/')

    if !s:has_webapi()
	echohl ErrorMsg | echomsg ':RustPlay depends on webapi.vim (https://github.com/mattn/webapi-vim)' | echohl None
	return
    endif

    let bufname = bufname('%')
    if a:count < 1
	let content = join(getline(a:line1, a:line2), "\n")
    else
	let save_regcont = @"
	let save_regtype = getregtype('"')
	silent! normal! gvy
	let content = @"
	call setreg('"', save_regcont, save_regtype)
    endif

    let body = l:rust_playpen_url."?code=".webapi#http#encodeURI(content)

    if strlen(body) > 5000
	echohl ErrorMsg | echomsg 'Buffer too large, max 5000 encoded characters ('.strlen(body).')' | echohl None
	return
    endif

    let payload = "format=simple&url=".webapi#http#encodeURI(body)
    let res = webapi#http#post(l:rust_shortener_url.'create.php', payload, {})
    let url = res.content

    redraw | echomsg 'Done: '.url
endfunction

" }}}1

" vim: set noet sw=8 ts=8:
