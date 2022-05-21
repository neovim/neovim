" Plugin to update the %changelog section of RPM spec files
" Filename: spec.vim
" Maintainer: Igor Gnatenko i.gnatenko.brain@gmail.com
" Former Maintainer: Gustavo Niemeyer <niemeyer@conectiva.com> (until March 2014)
" Last Change: Mon Jun 01 21:15 MSK 2015 Igor Gnatenko
" Update by Zdenek Dohnal, 2022 May 17

if exists("b:did_ftplugin")
	finish
endif
let b:did_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

if !exists("no_plugin_maps") && !exists("no_spec_maps")
	if !hasmapto("<Plug>SpecChangelog")
		map <buffer> <LocalLeader>c <Plug>SpecChangelog
	endif
endif

if !hasmapto("call <SID>SpecChangelog(\"\")<CR>")
       noremap <buffer> <unique> <script> <Plug>SpecChangelog :call <SID>SpecChangelog("")<CR>
endif

if !exists("*s:GetRelVer")
	function! s:GetRelVer()
		if has('python')
python << PYEND
import sys, datetime, shutil, tempfile
import vim

try:
    import rpm
except ImportError:
    pass
else:
    specfile = vim.current.buffer.name
    if specfile:
        rpm.delMacro("dist")
        spec = rpm.spec(specfile)
        headers = spec.sourceHeader
        version = headers["Version"]
        release = headers["Release"]
        vim.command("let ver = '" + version + "'")
        vim.command("let rel = '" + release + "'")
PYEND
		endif
	endfunction
endif

if !exists("*s:SpecChangelog")
	function s:SpecChangelog(format)
		if strlen(a:format) == 0
			if !exists("g:spec_chglog_format")
				let email = input("Name <email address>: ")
				let g:spec_chglog_format = "%a %b %d %Y " . l:email
				echo "\r"
			endif
			let format = g:spec_chglog_format
		else
			if !exists("g:spec_chglog_format")
				let g:spec_chglog_format = a:format
			endif
			let format = a:format
		endif
		let line = 0
		let name = ""
		let ver = ""
		let rel = ""
		let nameline = -1
		let verline = -1
		let relline = -1
		let chgline = -1
		while (line <= line("$"))
			let linestr = getline(line)
			if name == "" && linestr =~? '^Name:'
				let nameline = line
				let name = substitute(strpart(linestr,5), '^[	 ]*\([^ 	]\+\)[		]*$','\1','')
			elseif ver == "" && linestr =~? '^Version:'
				let verline = line
				let ver = substitute(strpart(linestr,8), '^[	 ]*\([^ 	]\+\)[		]*$','\1','')
			elseif rel == "" && linestr =~? '^Release:'
				let relline = line
				let rel = substitute(strpart(linestr,8), '^[	 ]*\([^ 	]\+\)[		]*$','\1','')
			elseif linestr =~? '^%changelog'
				let chgline = line
				execute line
				break
			endif
			let line = line+1
		endwhile
		if nameline != -1 && verline != -1 && relline != -1
			let include_release_info = exists("g:spec_chglog_release_info")
			let name = s:ParseRpmVars(name, nameline)
			let ver = s:ParseRpmVars(ver, verline)
			let rel = s:ParseRpmVars(rel, relline)
		else
			let include_release_info = 0
		endif

		call s:GetRelVer()

		if chgline == -1
			let option = confirm("Can't find %changelog. Create one? ","&End of file\n&Here\n&Cancel",3)
			if option == 1
				call append(line("$"),"")
				call append(line("$"),"%changelog")
				execute line("$")
				let chgline = line(".")
			elseif option == 2
				call append(line("."),"%changelog")
				normal j
				let chgline = line(".")
			endif
		endif
		if chgline != -1
			let tmptime = v:lc_time
			language time C
			let parsed_format = "* ".strftime(format)." - ".ver."-".rel
			execute "language time" tmptime
			let release_info = "+ ".name."-".ver."-".rel
			let wrong_format = 0
			let wrong_release = 0
			let insert_line = 0
			if getline(chgline+1) != parsed_format
				let wrong_format = 1
			endif
			if include_release_info && getline(chgline+2) != release_info
				let wrong_release = 1
			endif
			if wrong_format || wrong_release
				if include_release_info && !wrong_release && !exists("g:spec_chglog_never_increase_release")
					let option = confirm("Increase release? ","&Yes\n&No",1)
					if option == 1
						execute relline
						normal 
						let rel = substitute(strpart(getline(relline),8), '^[	 ]*\([^ 	]\+\)[		]*$','\1','')
						let release_info = "+ ".name."-".ver."-".rel
					endif
				endif
				let n = 0
				call append(chgline+n, parsed_format)
				if include_release_info
					let n = n + 1
					call append(chgline+n, release_info)
				endif
				let n = n + 1
				call append(chgline+n,"- ")
				let n = n + 1
				call append(chgline+n,"")
				let insert_line = chgline+n
			else
				let line = chgline
				if !exists("g:spec_chglog_prepend")
					while !(getline(line+2) =~ '^\( *\|\*.*\)$')
						let line = line+1
					endwhile
				endif
				call append(line+1,"- ")
				let insert_line = line+2
			endif
			execute insert_line
			startinsert!
		endif
	endfunction
endif

if !exists("*s:ParseRpmVars")
    function s:ParseRpmVars(str, strline)
	let end = -1
	let ret = ""
	while (1)
		let start = match(a:str, "\%{", end+1)
		if start == -1
			let ret = ret . strpart(a:str, end+1)
			break
		endif
		let ret = ret . strpart(a:str, end+1, start-(end+1))
		let end = match(a:str, "}", start)
		if end == -1
			let ret = ret . strpart(a:str, start)
			break
		endif
		let varname = strpart(a:str, start+2, end-(start+2))
		execute a:strline
		let definestr = "^[ \t]*%\\(define\\|global\\)[ \t]\\+".varname."[ \t]\\+\\(.*\\)$"
		let linenum = search(definestr, "bW")
		if linenum != 0
			let ret = ret .  substitute(getline(linenum), definestr, "\\2", "")
		endif
	endwhile
	return ret
    endfunction
endif

" The following lines, along with the macros/matchit.vim plugin,
" make it easy to navigate the different sections of a spec file
" with the % key (thanks to Max Ischenko).

let b:match_ignorecase = 0
let b:match_words =
  \ '^Name:^%description:^%clean:^%(?:auto)?setup:^%build:^%install:^%files:' .
  \ '^%package:^%preun:^%postun:^%changelog'

let &cpo = s:cpo_save
unlet s:cpo_save

let b:undo_ftplugin = "unlet! b:match_ignorecase b:match_words"
