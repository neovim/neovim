" Vim autoload file for editing compressed files.
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 10
" Former Maintainer: Bram Moolenaar <Bram@vim.org>

" These functions are used by the gzip plugin.

" Function to check that executing "cmd [-f]" works.
" The result is cached in s:have_"cmd" for speed.
fun s:check(cmd)
  let name = substitute(a:cmd, '\(\S*\).*', '\1', '')
  if !exists("s:have_" . name)
    " safety check, don't execute anything from the current directory
    let f = dist#vim#IsSafeExecutable('gzip', name)
    if !f
      echoerr "Warning: NOT executing " .. name .. " from current directory!"
    endif
    let e = executable(name)
    if e < 0
      let r = system(name . " --version")
      let e = (r !~ "not found" && r != "")
    endif
    exe "let s:have_" . name . "=" . (e && f)
  endif
  exe "return s:have_" . name
endfun

" Set b:gzip_comp_arg to the gzip argument to be used for compression, based on
" the flags in the compressed file.
" The only compression methods that can be detected are max speed (-1) and max
" compression (-9).
fun s:set_compression(line)
  " get the Compression Method
  let l:cm = char2nr(a:line[2])
  " if it's 8 (DEFLATE), we can check for the compression level
  if l:cm == 8
    " get the eXtra FLags
    let l:xfl = char2nr(a:line[8])
    " max compression
    if l:xfl == 2
      let b:gzip_comp_arg = "-9"
    " min compression
    elseif l:xfl == 4
      let b:gzip_comp_arg = "-1"
    endif
  endif
endfun


" After reading compressed file: Uncompress text in buffer with "cmd"
fun gzip#read(cmd)
  " don't do anything if the cmd is not supported
  if !s:check(a:cmd)
    return
  endif

  " for gzip check current compression level and set b:gzip_comp_arg.
  silent! unlet b:gzip_comp_arg
  if a:cmd[0] == 'g'
    call s:set_compression(getline(1))
  endif

  " make 'patchmode' empty, we don't want a copy of the written file
  let pm_save = &pm
  set pm=
  " remove 'a' and 'A' from 'cpo' to avoid the alternate file changes
  let cpo_save = &cpo
  set cpo-=a cpo-=A
  " set 'modifiable'
  let ma_save = &ma
  setlocal ma
  " set 'write'
  let write_save = &write
  set write
  " Reset 'foldenable', otherwise line numbers get adjusted.
  if has("folding")
    let fen_save = &fen
    setlocal nofen
  endif

  " when filtering the whole buffer, it will become empty
  let empty = line("'[") == 1 && line("']") == line("$")
  let tmp = tempname()
  let tmpe = tmp . "." . expand("<afile>:e")
  if exists('*fnameescape')
    let tmp_esc = fnameescape(tmp)
    let tmpe_esc = fnameescape(tmpe)
  else
    let tmp_esc = escape(tmp, ' ')
    let tmpe_esc = escape(tmpe, ' ')
  endif
  " write the just read lines to a temp file "'[,']w tmp.gz"
  execute "silent '[,']w " . tmpe_esc
  " uncompress the temp file: call system("gzip -dn tmp.gz")
  call system(a:cmd . " " . s:escape(tmpe))
  if !filereadable(tmp)
    " uncompress didn't work!  Keep the compressed file then.
    echoerr "Error: Could not read uncompressed file"
    let ok = 0
  else
    let ok = 1
    " delete the compressed lines; remember the line number
    let l = line("'[") - 1
    if exists(":lockmarks")
      lockmarks '[,']d _
    else
      '[,']d _
    endif
    " read in the uncompressed lines "'[-1r tmp"
    " Use ++edit if the buffer was empty, keep the 'ff' and 'fenc' options.
    setlocal nobin
    if exists(":lockmarks")
      if empty
	execute "silent lockmarks " . l . "r ++edit " . tmp_esc
      else
	execute "silent lockmarks " . l . "r " . tmp_esc
      endif
    else
      execute "silent " . l . "r " . tmp_esc
    endif

    " if buffer became empty, delete trailing blank line
    if empty
      silent $delete _
      1
    endif
    " delete the temp file and the used buffers
    call delete(tmp)
    silent! exe "bwipe " . tmp_esc
    silent! exe "bwipe " . tmpe_esc
  endif
  " Store the OK flag, so that we can use it when writing.
  let b:uncompressOk = ok

  " Restore saved option values.
  let &pm = pm_save
  let &cpo = cpo_save
  let &l:ma = ma_save
  let &write = write_save
  if has("folding")
    let &l:fen = fen_save
  endif

  " When uncompressed the whole buffer, do autocommands
  if ok && empty
    if exists('*fnameescape')
      let fname = fnameescape(expand("%:r"))
    else
      let fname = escape(expand("%:r"), " \t\n*?[{`$\\%#'\"|!<")
    endif
    if &verbose >= 8
      execute "doau BufReadPost " . fname
    else
      execute "silent! doau BufReadPost " . fname
    endif
  endif
endfun

" After writing compressed file: Compress written file with "cmd"
fun gzip#write(cmd)
  if exists('b:uncompressOk') && !b:uncompressOk
    echomsg "Not compressing file because uncompress failed; reset b:uncompressOk to compress anyway"
  " don't do anything if the cmd is not supported
  elseif s:check(a:cmd)
    " Rename the file before compressing it.
    let nm = resolve(expand("<afile>"))
    let nmt = s:tempname(nm)
    if rename(nm, nmt) == 0
      if exists("b:gzip_comp_arg")
	call system(a:cmd . " " . b:gzip_comp_arg . " -- " . s:escape(nmt))
      else
	call system(a:cmd . " -- " . s:escape(nmt))
      endif
      call rename(nmt . "." . expand("<afile>:e"), nm)
    endif
  endif
endfun

" Before appending to compressed file: Uncompress file with "cmd"
fun gzip#appre(cmd)
  " don't do anything if the cmd is not supported
  if s:check(a:cmd)
    let nm = expand("<afile>")

    " for gzip check current compression level and set b:gzip_comp_arg.
    silent! unlet b:gzip_comp_arg
    if a:cmd[0] == 'g'
      call s:set_compression(readfile(nm, "b", 1)[0])
    endif

    " Rename to a weird name to avoid the risk of overwriting another file
    let nmt = expand("<afile>:p:h") . "/X~=@l9q5"
    let nmte = nmt . "." . expand("<afile>:e")
    if rename(nm, nmte) == 0
      if &patchmode != "" && getfsize(nm . &patchmode) == -1
	" Create patchmode file by creating the decompressed file new
	call system(a:cmd . " -c -- " . s:escape(nmte) . " > " . s:escape(nmt))
	call rename(nmte, nm . &patchmode)
      else
	call system(a:cmd . " -- " . s:escape(nmte))
      endif
      call rename(nmt, nm)
    endif
  endif
endfun

" find a file name for the file to be compressed.  Use "name" without an
" extension if possible.  Otherwise use a weird name to avoid overwriting an
" existing file.
fun s:tempname(name)
  let fn = fnamemodify(a:name, ":r")
  if !filereadable(fn) && !isdirectory(fn)
    return fn
  endif
  return fnamemodify(a:name, ":p:h") . "/X~=@l9q5"
endfun

fun s:escape(name)
  " shellescape() was added by patch 7.0.111
  if exists("*shellescape")
    return shellescape(a:name)
  endif
  return "'" . a:name . "'"
endfun

" vim: set sw=2 :
