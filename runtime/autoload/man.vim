" Maintainer: Anmol Sethi <anmol@aubble.com>

if &shell =~# 'fish$'
  let s:man_cmd = 'man ^/dev/null'
else
  let s:man_cmd = 'man 2>/dev/null'
endif

let s:man_find_arg = "-w"

" TODO(nhooyr) I do not think completion will work on SunOS because I'm not sure if `man -l`
" displays the list of directories that are searched by man for manpages.
" I also do not think Solaris supports the '-P' flag used above and uses only $PAGER.
try
  if !has('win32') && $OSTYPE !~? 'cygwin\|linux' && system('uname -s') =~? 'SunOS' && system('uname -r') =~# '^5'
    let s:man_find_arg = '-l'
  endif
catch /E145:/
  " Ignore the error in restricted mode
endtry

" We need count and count1 to ensure the section was explicitly set
" by the user. count defaults to 0 which is a valid section and
" count1 defaults to 1 which is also a valid section. Only when they
" are equal was the count explicitly set.
function! man#open_page(count, count1, mods, ...) abort
  if a:0 > 2
    call s:error('too many arguments')
    return
  elseif a:0 ==# 1
    if empty(a:1)
      call s:error('no identifier under cursor')
      return
    endif
    let ref = a:1
  else
    " We combine the name and sect into a manpage reference so that all
    " verification/extraction can be kept in a single function.
    " If a:2 is a reference as well, that is fine because it is the only
    " reference that will match.
    let ref = a:2.'('.a:1.')'
  endif
  try
    let [sect, name] = s:extract_sect_and_name_ref(ref)
    if a:count ==# a:count1
      " user explicitly set a count
      let sect = string(a:count)
    endif
    let [sect, name, path] = s:verify_exists(sect, name)
  catch
    call s:error(v:exception)
    return
  endtry
  call s:push_tag()
  let bufname = 'man://'.name.(empty(sect)?'':'('.sect.')')
  if a:mods !~# 'tab' && s:find_man()
    if s:manwidth() ==# getbufvar(bufname, 'manwidth')
      silent execute 'buf' bufname
      call man#set_window_local_options()
      keepjumps 1
      return
    endif
    noautocmd execute 'edit' bufname
  elseif s:manwidth() ==# getbufvar(bufname, 'manwidth')
    execute a:mods 'split' bufname
    call man#set_window_local_options()
    keepjumps 1
    return
  else
    noautocmd execute a:mods 'split' bufname
  endif
  call s:read_page(path)
endfunction

function! man#read_page(ref) abort
  try
    let [sect, name] = s:extract_sect_and_name_ref(a:ref)
    " The third element is the path.
    call s:read_page(s:verify_exists(sect, name)[2])
  catch
    call s:error(v:exception)
    return
  endtry
endfunction

function! s:read_page(path) abort
  setlocal modifiable
  setlocal noreadonly
  keepjumps %delete _
  let b:manwidth = s:manwidth()
  " Ensure Vim is not recursively invoked (man-db does this)
  " by forcing man to use cat as the pager.
  " More info here http://comments.gmane.org/gmane.editors.vim.devel/29085
  silent execute 'read !env MANPAGER=cat MANWIDTH='.b:manwidth s:man_cmd a:path
  " remove all the backspaced text
  silent execute 'keeppatterns keepjumps %substitute,.\b,,e'.(&gdefault?'':'g')
  while getline(1) =~# '^\s*$'
    silent keepjumps 1delete _
  endwhile
  setlocal filetype=man
endfunction

" attempt to extract the name and sect out of 'name(sect)'
" otherwise just return the largest string of valid characters in ref
function! s:extract_sect_and_name_ref(ref) abort
  if a:ref[0] ==# '-' " try ':Man -pandoc' with this disabled.
    throw 'manpage name starts with ''-'''
  endif
  let ref = matchstr(a:ref, '[^()]\+([^()]\+)')
  if empty(ref)
    let name = matchstr(a:ref, '[^()]\+')
    if empty(name)
      throw 'manpage reference contains only parantheses'
    endif
    return ['', name]
  endif
  let left = split(ref, '(')
  " see ':Man 3X curses' on why tolower.
  " TODO(nhooyr) Not sure if this is portable across OSs
  " but I have not seen a single uppercase section.
  return [tolower(split(left[1], ')')[0]), left[0]]
endfunction

function! s:verify_exists(sect, name) abort
  let path = system(s:man_cmd.' '.s:man_find_arg.' '.s:man_args(a:sect, a:name))
  if path !~# '^\/'
    if empty(a:sect)
      throw 'no manual entry for '.a:name
    endif
    let path = system(s:man_cmd.' '.s:man_find_arg.' '.shellescape(a:name))
    if path !~# '^\/'
      throw 'no manual entry for '.a:name.'('.a:sect.') or '.a:name
    endif
  endif
  if a:name =~# '\/'
    " We do not need to extract the section/name from the path if the name is
    " just a path.
    return ['', a:name, path]
  endif
  " We need to extract the section from the path because sometimes
  " the actual section of the manpage is more specific than the section
  " we provided to `man`. Try ':Man 3 App::CLI'.
  " Also on linux, it seems that the name is case insensitive. So if one does
  " ':Man PRIntf', we still want the name of the buffer to be 'printf' or
  " whatever the correct capitilization is.
  let path = path[:len(path)-2]
  return s:extract_sect_and_name_path(path) + [path]
endfunction

let s:tag_stack = []

function! s:push_tag() abort
  let s:tag_stack += [{
        \ 'buf':  bufnr('%'),
        \ 'lnum': line('.'),
        \ 'col':  col('.'),
        \ }]
endfunction

function! man#pop_tag() abort
  if !empty(s:tag_stack)
    let tag = remove(s:tag_stack, -1)
    execute tag['buf'].'b'
    call cursor(tag['lnum'], tag['col'])
  endif
endfunction

" extracts the name and sect out of 'path/name.sect'
function! s:extract_sect_and_name_path(path) abort
  let tail = fnamemodify(a:path, ':t')
  if a:path =~# '\.\%([glx]z\|bz2\|lzma\|Z\)$' " valid extensions
    let tail = fnamemodify(tail, ':r')
  endif
  let sect = matchstr(tail, '\.\zs[^.]\+$')
  let name = matchstr(tail, '^.\+\ze\.[^.]\+$')
  return [sect, name]
endfunction

function! s:find_man() abort
  if &filetype ==# 'man'
    return 1
  endif
  let thiswin = winnr()
  while 1
    wincmd w
    if &filetype ==# 'man'
      return 1
    elseif thiswin ==# winnr()
      return 0
    endif
  endwhile
endfunction

function! s:manwidth() abort
  " The reason for respecting $MANWIDTH even if it is wider/smaller than the
  " current window is that the current window might only be temporarily
  " narrow/wide. Since we don't reflow, we should just assume the
  " user knows what they're doing and respect $MANWIDTH.
  if empty($MANWIDTH)
    " If $MANWIDTH is not set, we do not assign directly to $MANWIDTH because
    " then $MANWIDTH will always stay the same value as we only use
    " winwidth(0) when $MANWIDTH is empty. Instead we set it locally for the command.
    return winwidth(0)
  endif
  return $MANWIDTH
endfunction

function! man#set_window_local_options() abort
  setlocal nonumber
  setlocal norelativenumber
  setlocal foldcolumn=0
  setlocal colorcolumn=0
  setlocal nolist
  setlocal nofoldenable
endfunction

function! s:man_args(sect, name) abort
  if empty(a:sect)
    return shellescape(a:name)
  endif
  " The '-s' flag is very useful.
  " We do not need to worry about stuff like 'printf(echo)'
  " (two manpages would be interpreted by man without -s)
  " We do not need to check if the sect starts with '-'
  " Lastly, the 3pcap section on macOS doesn't work without -s
  return '-s '.shellescape(a:sect).' '.shellescape(a:name)
endfunction

function! s:error(msg) abort
  redraw
  echohl ErrorMsg
  echon 'man.vim: ' a:msg
  echohl None
endfunction

let s:mandirs = join(split(system(s:man_cmd.' '.s:man_find_arg), ':\|\n'), ',')

" see s:extract_sect_and_name_ref on why tolower(sect)
function! man#complete(arg_lead, cmd_line, cursor_pos) abort
  let args = split(a:cmd_line)
  let l = len(args)
  if l > 3
    return
  elseif l ==# 1
    let name = ''
    let sect = ''
  elseif a:arg_lead =~# '^[^()]\+([^()]*$'
    " cursor (|) is at ':Man printf(|' or ':Man 1 printf(|'
    " The later is is allowed because of ':Man pri<TAB>'.
    " It will offer 'priclass.d(1m)' even though section is specified as 1.
    let tmp = split(a:arg_lead, '(')
    let name = tmp[0]
    let sect = tolower(get(tmp, 1, ''))
  elseif args[1] !~# '^[^()]\+$'
    " cursor (|) is at ':Man 3() |' or ':Man (3|' or ':Man 3() pri|'
    " or ':Man 3() pri |'
    return
  elseif l ==# 2
    if empty(a:arg_lead)
      " cursor (|) is at ':Man 1 |'
      let name = ''
      let sect = tolower(args[1])
    else
      " cursor (|) is at ':Man pri|'
      if a:arg_lead =~# '\/'
        " if the name is a path, complete files
        " TODO(nhooyr) why does this complete the last one automatically
        return glob(a:arg_lead.'*', 0, 1)
      endif
      let name = a:arg_lead
      let sect = ''
    endif
  elseif a:arg_lead !~# '^[^()]\+$'
    " cursor (|) is at ':Man 3 printf |' or ':Man 3 (pr)i|'
    return
  else
    " cursor (|) is at ':Man 3 pri|'
    let name = a:arg_lead
    let sect = tolower(args[1])
  endif
  " We remove duplicates incase the same manpage in different languages was found.
  return uniq(sort(map(globpath(s:mandirs,'man?/'.name.'*.'.sect.'*', 0, 1), 's:format_candidate(v:val, sect)'), 'i'))
endfunction

function! s:format_candidate(path, sect) abort
  if a:path =~# '\.\%(pdf\|in\)$' " invalid extensions
    return
  endif
  let [sect, name] = s:extract_sect_and_name_path(a:path)
  if sect ==# a:sect
    return name
  elseif sect =~# a:sect.'[^.]\+$'
    " We include the section if the user provided section is a prefix
    " of the actual section.
    return name.'('.sect.')'
  endif
endfunction
