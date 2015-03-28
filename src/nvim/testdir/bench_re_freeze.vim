"Test for benchmarking the RE engine

so small.vim
if !has("reltime") | finish | endif
func! Measure(file, pattern, arg)
	for re in range(3)
	    let sstart=reltime()
	    let cmd=printf("../../../build/bin/nvim -u NONE -N --cmd ':set re=%d'".
		\ " -c 'call search(\"%s\", \"\", \"\", 10000)' -c ':q!' %s", re, escape(a:pattern, '\\'), empty(a:arg) ? '' : a:arg)
	    call system(cmd. ' '. a:file)
	    $put =printf('file: %s, re: %d, time: %s', a:file, re, reltimestr(reltime(sstart)))
	endfor
endfunc
