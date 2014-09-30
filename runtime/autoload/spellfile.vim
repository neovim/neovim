" Vim script to download a missing spell file
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last Change:	2012 Jan 08

if !exists('g:spellfile_URL')
  " Prefer using http:// when netrw should be able to use it, since
  " more firewalls let this through.
  if executable("curl") || executable("wget") || executable("fetch")
    let g:spellfile_URL = 'http://ftp.vim.org/pub/vim/runtime/spell'
  else
    let g:spellfile_URL = 'ftp://ftp.vim.org/pub/vim/runtime/spell'
  endif
endif
let s:spellfile_URL = ''    " Start with nothing so that s:donedict is reset.

" This function is used for the spellfile plugin.
function! spellfile#LoadFile(lang)
  " If the netrw plugin isn't loaded we silently skip everything.
  if !exists(":Nread")
    if &verbose
      echomsg 'spellfile#LoadFile(): Nread command is not available.'
    endif
    return
  endif

  " If the URL changes we try all files again.
  if s:spellfile_URL != g:spellfile_URL
    let s:donedict = {}
    let s:spellfile_URL = g:spellfile_URL
  endif

  " I will say this only once!
  if has_key(s:donedict, a:lang . &enc)
    if &verbose
      echomsg 'spellfile#LoadFile(): Tried this language/encoding before.'
    endif
    return
  endif
  let s:donedict[a:lang . &enc] = 1

  " Find spell directories we can write in.
  let [dirlist, dirchoices] = spellfile#GetDirChoices()
  if len(dirlist) == 0
    let dir_to_create = spellfile#WritableSpellDir()
    if &verbose || dir_to_create != ''
      echomsg 'spellfile#LoadFile(): There is no writable spell directory.'
    endif
    if dir_to_create != ''
      if confirm("Shall I create " . dir_to_create, "&Yes\n&No", 2) == 1
	" After creating the directory it should show up in the list.
	call mkdir(dir_to_create, "p")
	let [dirlist, dirchoices] = spellfile#GetDirChoices()
      endif
    endif
    if len(dirlist) == 0
      return
    endif
  endif

  let msg = 'Cannot find spell file for "' . a:lang . '" in ' . &enc
  let msg .= "\nDo you want me to try downloading it?"
  if confirm(msg, "&Yes\n&No", 2) == 1
    let enc = &encoding
    if enc == 'iso-8859-15'
      let enc = 'latin1'
    endif
    let fname = a:lang . '.' . enc . '.spl'

    " Split the window, read the file into a new buffer.
    " Remember the buffer number, we check it below.
    new
    let newbufnr = winbufnr(0)
    setlocal bin fenc=
    echo 'Downloading ' . fname . '...'
    call spellfile#Nread(fname)
    if getline(2) !~ 'VIMspell'
      " Didn't work, perhaps there is an ASCII one.
      " Careful: Nread() may have opened a new window for the error message,
      " we need to go back to our own buffer and window.
      if newbufnr != winbufnr(0)
	let winnr = bufwinnr(newbufnr)
	if winnr == -1
	  " Our buffer has vanished!?  Open a new window.
	  echomsg "download buffer disappeared, opening a new one"
	  new
	  setlocal bin fenc=
	else
	  exe winnr . "wincmd w"
	endif
      endif
      if newbufnr == winbufnr(0)
	" We are back the old buffer, remove any (half-finished) download.
        g/^/d
      else
	let newbufnr = winbufnr(0)
      endif

      let fname = a:lang . '.ascii.spl'
      echo 'Could not find it, trying ' . fname . '...'
      call spellfile#Nread(fname)
      if getline(2) !~ 'VIMspell'
	echo 'Sorry, downloading failed'
	exe newbufnr . "bwipe!"
	return
      endif
    endif

    " Delete the empty first line and mark the file unmodified.
    1d
    set nomod

    let msg = "In which directory do you want to write the file:"
    for i in range(len(dirlist))
      let msg .= "\n" . (i + 1) . '. ' . dirlist[i]
    endfor
    let dirchoice = confirm(msg, dirchoices) - 2
    if dirchoice >= 0
      if exists('*fnameescape')
	let dirname = fnameescape(dirlist[dirchoice])
      else
	let dirname = escape(dirlist[dirchoice], ' ')
      endif
      setlocal fenc=
      exe "write " . dirname . '/' . fname

      " Also download the .sug file, if the user wants to.
      let msg = "Do you want me to try getting the .sug file?\n"
      let msg .= "This will improve making suggestions for spelling mistakes,\n"
      let msg .= "but it uses quite a bit of memory."
      if confirm(msg, "&No\n&Yes") == 2
	g/^/d
	let fname = substitute(fname, '\.spl$', '.sug', '')
	echo 'Downloading ' . fname . '...'
	call spellfile#Nread(fname)
	if getline(2) =~ 'VIMsug'
	  1d
	  exe "write " . dirname . '/' . fname
	  set nomod
	else
	  echo 'Sorry, downloading failed'
	  " Go back to our own buffer/window, Nread() may have taken us to
	  " another window.
	  if newbufnr != winbufnr(0)
	    let winnr = bufwinnr(newbufnr)
	    if winnr != -1
	      exe winnr . "wincmd w"
	    endif
	  endif
	  if newbufnr == winbufnr(0)
	    set nomod
	  endif
	endif
      endif
    endif

    " Wipe out the buffer we used.
    exe newbufnr . "bwipe"
  endif
endfunc

" Read "fname" from the server.
function! spellfile#Nread(fname)
  " We do our own error handling, don't want a window for it.
  if exists("g:netrw_use_errorwindow")
    let save_ew = g:netrw_use_errorwindow
  endif
  let g:netrw_use_errorwindow=0

  if g:spellfile_URL =~ '^ftp://'
    " for an ftp server use a default login and password to avoid a prompt
    let machine = substitute(g:spellfile_URL, 'ftp://\([^/]*\).*', '\1', '')
    let dir = substitute(g:spellfile_URL, 'ftp://[^/]*/\(.*\)', '\1', '')
    exe 'Nread "' . machine . ' anonymous vim7user ' . dir . '/' . a:fname . '"'
  else
    exe 'Nread ' g:spellfile_URL . '/' . a:fname
  endif

  if exists("save_ew")
    let g:netrw_use_errorwindow = save_ew
  else
    unlet g:netrw_use_errorwindow
  endif
endfunc

" Get a list of writable spell directories and choices for confirm().
function! spellfile#GetDirChoices()
  let dirlist = []
  let dirchoices = '&Cancel'
  for dir in split(globpath(&rtp, 'spell'), "\n")
    if filewritable(dir) == 2
      call add(dirlist, dir)
      let dirchoices .= "\n&" . len(dirlist)
    endif
  endfor
  return [dirlist, dirchoices]
endfunc

function! spellfile#WritableSpellDir()
  if has("unix")
    " For Unix always use the $HOME/.vim directory
    return $HOME . "/.vim/spell"
  endif
  for dir in split(&rtp, ',')
    if filewritable(dir) == 2
      return dir . "/spell"
    endif
  endfor
  return ''
endfunction
