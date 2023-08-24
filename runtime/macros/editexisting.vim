" Vim Plugin:	Edit the file with an existing Vim if possible
" Maintainer:	The Vim Project <https://github.com/vim/vim>
" Last Change:	2023 Aug 13

" This is a plugin, drop it in your (Unix) ~/.vim/plugin or (Win32)
" $VIM/vimfiles/plugin directory.  Or make a symbolic link, so that you
" automatically use the latest version.

" This plugin serves two purposes:
" 1. On startup, if we were invoked with one file name argument and the file
"    is not modified then try to find another Vim instance that is editing
"    this file.  If there is one then bring it to the foreground and exit.
" 2. When a file is edited and a swap file exists for it, try finding that
"    other Vim and bring it to the foreground.  Requires Vim 7, because it
"    uses the SwapExists autocommand event.
if v:version < 700
  finish
endif

" Function that finds the Vim instance that is editing "filename" and brings
" it to the foreground.
func s:EditElsewhere(filename)
  let fname_esc = substitute(a:filename, "'", "''", "g")

  let servers = serverlist()
  while servers != ''
    " Get next server name in "servername"; remove it from "servers".
    let i = match(servers, "\n")
    if i == -1
      let servername = servers
      let servers = ''
    else
      let servername = strpart(servers, 0, i)
      let servers = strpart(servers, i + 1)
    endif

    " Skip ourselves.
    if servername ==? v:servername
      continue
    endif

    " Check if this server is editing our file.
    if remote_expr(servername, "bufloaded('" . fname_esc . "')")
      " Yes, bring it to the foreground.
      if has("win32")
	call remote_foreground(servername)
      endif
      call remote_expr(servername, "foreground()")

      if remote_expr(servername, "exists('*EditExisting')")
	" Make sure the file is visible in a window (not hidden).
	" If v:swapcommand exists and is set, send it to the server.
	if exists("v:swapcommand")
	  let c = substitute(v:swapcommand, "'", "''", "g")
	  call remote_expr(servername, "EditExisting('" . fname_esc . "', '" . c . "')")
	else
	  call remote_expr(servername, "EditExisting('" . fname_esc . "', '')")
	endif
      endif

      if !(has('vim_starting') && has('gui_running') && has('gui_win32'))
	" Tell the user what is happening.  Not when the GUI is starting
	" though, it would result in a message box.
	echomsg "File is being edited by " . servername
	sleep 2
      endif
      return 'q'
    endif
  endwhile
  return ''
endfunc

" When the plugin is loaded and there is one file name argument: Find another
" Vim server that is editing this file right now.
if argc() == 1 && !&modified
  if s:EditElsewhere(expand("%:p")) == 'q'
    quit
  endif
endif

" Setup for handling the situation that an existing swap file is found.
try
  au! SwapExists * let v:swapchoice = s:EditElsewhere(expand("<afile>:p"))
catch
  " Without SwapExists we don't do anything for ":edit" commands
endtry

" Function used on the server to make the file visible and possibly execute a
" command.
func! EditExisting(fname, command)
  " Get the window number of the file in the current tab page.
  let winnr = bufwinnr(a:fname)
  if winnr <= 0
    " Not found, look in other tab pages.
    let bufnr = bufnr(a:fname)
    for i in range(tabpagenr('$'))
      if index(tabpagebuflist(i + 1), bufnr) >= 0
	" Make this tab page the current one and find the window number.
	exe 'tabnext ' . (i + 1)
	let winnr = bufwinnr(a:fname)
	break
      endif
    endfor
  endif

  if winnr > 0
    exe winnr . "wincmd w"
  elseif exists('*fnameescape')
    exe "split " . fnameescape(a:fname)
  else
    exe "split " . escape(a:fname, " \t\n*?[{`$\\%#'\"|!<")
  endif

  if a:command != ''
    exe "normal! " . a:command
  endif

  redraw
endfunc
