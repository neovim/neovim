let s:man_tag_depth = 0
let s:man_sect_arg = ''
let s:man_find_arg = '-w'

try
  if !has('win32') && $OSTYPE !~? 'cygwin\|linux' && system('uname -s') =~? 'SunOS' && system('uname -r') =~? '^5'
    let s:man_sect_arg = '-s'
    let s:man_find_arg = '-l'
  endif
catch /E145:/
  " Ignore the error in restricted mode
endtry

" Load man page {page} from {section}
"   call man#get_page([{section}, ]{page})
function man#get_page(...) abort
  let invoked_from_man = (&filetype ==# 'man')

  if a:0 == 0
    echoerr 'argument required'
    return
  elseif a:0 > 2
    echoerr 'too many arguments'
    return
  endif

  let sect = get(a:000, 0)
  let page = get(a:000, 1, sect)

  let [page, sect] = s:parse_page_and_section(sect, page)

  if !empty(sect) && s:find_page(sect, page) == 0
    let sect = ''
  endif

  if s:find_page(sect, page) == 0
    echo 'No manual entry for '.page
    return
  endif

  exec 'let s:man_tag_buf_'.s:man_tag_depth.' = '.bufnr('%')
  exec 'let s:man_tag_lin_'.s:man_tag_depth.' = '.line('.')
  exec 'let s:man_tag_col_'.s:man_tag_depth.' = '.col('.')
  let s:man_tag_depth = s:man_tag_depth + 1

  let editcmd = 'edit'
  " Use an existing 'man' window, else open a new one.
  if &filetype !=# 'man'
    let thiswin = winnr()
    wincmd b
    if winnr() > 1
      exec thiswin . 'wincmd w'
      while 1
        if &filetype ==# 'man'
          break
        endif
        wincmd w
        if thiswin == winnr()
          break
        endif
      endwhile
    endif

    if &filetype !=# 'man'
      let editcmd = 'tabnew'
    endif
  endif

  silent exec editcmd.' man://'.page.(empty(sect)?'':'('.sect.')')

  setlocal modifiable
  silent keepjumps norm! 1G"_dG
  if empty($MANWIDTH)
    let $MANWIDTH = winwidth(0)
  endif
  silent exec 'r!/usr/bin/man '.s:cmd(sect, page).' | col -b'
  " Remove blank lines from top and bottom.
  while getline(1) =~# '^\s*$'
    silent keepjumps 1delete _
  endwhile
  while getline('$') =~# '^\s*$'
    silent keepjumps $delete _
  endwhile
  setlocal nomodified
  setlocal filetype=man

  if invoked_from_man || editcmd ==# 'tabnew'
    call s:set_window_local_options()
  endif
endfunction

function s:set_window_local_options() abort
  setlocal colorcolumn=0 foldcolumn=0 nonumber
  setlocal nolist norelativenumber nofoldenable
endfunction

function man#pop_page() abort
  if s:man_tag_depth > 0
    let s:man_tag_depth = s:man_tag_depth - 1
    exec "let s:man_tag_buf=s:man_tag_buf_".s:man_tag_depth
    exec "let s:man_tag_lin=s:man_tag_lin_".s:man_tag_depth
    exec "let s:man_tag_col=s:man_tag_col_".s:man_tag_depth
    exec s:man_tag_buf."b"
    exec s:man_tag_lin
    exec "norm! ".s:man_tag_col."|"
    exec "unlet s:man_tag_buf_".s:man_tag_depth
    exec "unlet s:man_tag_lin_".s:man_tag_depth
    exec "unlet s:man_tag_col_".s:man_tag_depth
    unlet s:man_tag_buf s:man_tag_lin s:man_tag_col
  endif
endfunction

" Expects a string like 'access' or 'access(2)'.
function s:parse_page_and_section(sect, str) abort
  try
    let [page, sect] = matchlist(a:str, '\v\C([-.[:alnum:]_]+)%(\(([-.[:alnum:]_]+)\))?')[1:2]
    if empty(sect)
      let sect = a:sect
    endif
  catch
    echoerr 'man.vim: failed to parse: "'.a:str.'"'
  endtry

  return [page, sect]
endfunction

function s:cmd(sect, page) abort
  if !empty(a:sect)
    return s:man_sect_arg.' '.a:sect.' '.a:page
  endif
  return a:page
endfunction

function s:find_page(sect, page) abort
  let where = system('/usr/bin/man '.s:man_find_arg.' '.s:cmd(a:sect, a:page))
  return (where =~# '^ */')
endfunction
