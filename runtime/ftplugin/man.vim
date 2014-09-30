" Vim filetype plugin file
" Language:	man
" Maintainer:	SungHyun Nam <goweol@gmail.com>
" Last Change:	2013 Jul 17

" To make the ":Man" command available before editing a manual page, source
" this script from your startup vimrc file.

" If 'filetype' isn't "man", we must have been called to only define ":Man".
if &filetype == "man"

  " Only do this when not done yet for this buffer
  if exists("b:did_ftplugin")
    finish
  endif
  let b:did_ftplugin = 1

  " Ensure Vim is not recursively invoked (man-db does this)
  " when doing ctrl-[ on a man page reference.
  if exists("$MANPAGER")
    let $MANPAGER = ""
  endif

  " allow dot and dash in manual page name.
  setlocal iskeyword+=\.,-

  " Add mappings, unless the user didn't want this.
  if !exists("no_plugin_maps") && !exists("no_man_maps")
    if !hasmapto('<Plug>ManBS')
      nmap <buffer> <LocalLeader>h <Plug>ManBS
    endif
    nnoremap <buffer> <Plug>ManBS :%s/.\b//g<CR>:setl nomod<CR>''

    nnoremap <buffer> <c-]> :call <SID>PreGetPage(v:count)<CR>
    nnoremap <buffer> <c-t> :call <SID>PopPage()<CR>
  endif

  let b:undo_ftplugin = "setlocal iskeyword<"

endif

if exists(":Man") != 2
  com -nargs=+ Man call s:GetPage(<f-args>)
  nmap <Leader>K :call <SID>PreGetPage(0)<CR>
endif

" Define functions only once.
if !exists("s:man_tag_depth")

let s:man_tag_depth = 0

let s:man_sect_arg = ""
let s:man_find_arg = "-w"
try
  if !has("win32") && $OSTYPE !~ 'cygwin\|linux' && system('uname -s') =~ "SunOS" && system('uname -r') =~ "^5"
    let s:man_sect_arg = "-s"
    let s:man_find_arg = "-l"
  endif
catch /E145:/
  " Ignore the error in restricted mode
endtry

func <SID>PreGetPage(cnt)
  if a:cnt == 0
    let old_isk = &iskeyword
    setl iskeyword+=(,)
    let str = expand("<cword>")
    let &l:iskeyword = old_isk
    let page = substitute(str, '(*\(\k\+\).*', '\1', '')
    let sect = substitute(str, '\(\k\+\)(\([^()]*\)).*', '\2', '')
    if match(sect, '^[0-9 ]\+$') == -1
      let sect = ""
    endif
    if sect == page
      let sect = ""
    endif
  else
    let sect = a:cnt
    let page = expand("<cword>")
  endif
  call s:GetPage(sect, page)
endfunc

func <SID>GetCmdArg(sect, page)
  if a:sect == ''
    return a:page
  endif
  return s:man_sect_arg.' '.a:sect.' '.a:page
endfunc

func <SID>FindPage(sect, page)
  let where = system("/usr/bin/man ".s:man_find_arg.' '.s:GetCmdArg(a:sect, a:page))
  if where !~ "^/"
    if matchstr(where, " [^ ]*$") !~ "^ /"
      return 0
    endif
  endif
  return 1
endfunc

func <SID>GetPage(...)
  if a:0 >= 2
    let sect = a:1
    let page = a:2
  elseif a:0 >= 1
    let sect = ""
    let page = a:1
  else
    return
  endif

  " To support:	    nmap K :Man <cword>
  if page == '<cword>'
    let page = expand('<cword>')
  endif

  if sect != "" && s:FindPage(sect, page) == 0
    let sect = ""
  endif
  if s:FindPage(sect, page) == 0
    echo "\nCannot find a '".page."'."
    return
  endif
  exec "let s:man_tag_buf_".s:man_tag_depth." = ".bufnr("%")
  exec "let s:man_tag_lin_".s:man_tag_depth." = ".line(".")
  exec "let s:man_tag_col_".s:man_tag_depth." = ".col(".")
  let s:man_tag_depth = s:man_tag_depth + 1

  " Use an existing "man" window if it exists, otherwise open a new one.
  if &filetype != "man"
    let thiswin = winnr()
    exe "norm! \<C-W>b"
    if winnr() > 1
      exe "norm! " . thiswin . "\<C-W>w"
      while 1
	if &filetype == "man"
	  break
	endif
	exe "norm! \<C-W>w"
	if thiswin == winnr()
	  break
	endif
      endwhile
    endif
    if &filetype != "man"
      new
      setl nonu fdc=0
    endif
  endif
  silent exec "edit $HOME/".page.".".sect."~"
  " Avoid warning for editing the dummy file twice
  setl buftype=nofile noswapfile

  setl ma nonu nornu nofen
  silent exec "norm 1GdG"
  let $MANWIDTH = winwidth(0)
  silent exec "r!/usr/bin/man ".s:GetCmdArg(sect, page)." | col -b"
  " Remove blank lines from top and bottom.
  while getline(1) =~ '^\s*$'
    silent norm ggdd
  endwhile
  while getline('$') =~ '^\s*$'
    silent norm Gdd
  endwhile
  1
  setl ft=man nomod
  setl bufhidden=hide
  setl nobuflisted
endfunc

func <SID>PopPage()
  if s:man_tag_depth > 0
    let s:man_tag_depth = s:man_tag_depth - 1
    exec "let s:man_tag_buf=s:man_tag_buf_".s:man_tag_depth
    exec "let s:man_tag_lin=s:man_tag_lin_".s:man_tag_depth
    exec "let s:man_tag_col=s:man_tag_col_".s:man_tag_depth
    exec s:man_tag_buf."b"
    exec s:man_tag_lin
    exec "norm ".s:man_tag_col."|"
    exec "unlet s:man_tag_buf_".s:man_tag_depth
    exec "unlet s:man_tag_lin_".s:man_tag_depth
    exec "unlet s:man_tag_col_".s:man_tag_depth
    unlet s:man_tag_buf s:man_tag_lin s:man_tag_col
  endif
endfunc

endif

" vim: set sw=2:
