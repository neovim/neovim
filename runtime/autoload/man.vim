" Maintainer: Anmol Sethi <anmol@aubble.com>

if exists('s:loaded_man')
  finish
endif
let s:loaded_man = 1

let s:find_arg = '-w'
let s:localfile_arg = v:true  " Always use -l if possible. #6683
let s:section_arg = '-s'

function! s:init_section_flag()
  call system(['env', 'MANPAGER=cat', 'man', s:section_arg, '1', 'man'])
  if v:shell_error
    let s:section_arg = '-S'
  endif
endfunction

function! s:init() abort
  call s:init_section_flag()
  " TODO(nhooyr): Does `man -l` on SunOS list searched directories?
  try
    if !has('win32') && $OSTYPE !~? 'cygwin\|linux' && system('uname -s') =~? 'SunOS' && system('uname -r') =~# '^5'
      let s:find_arg = '-l'
    endif
    " Check for -l support.
    call s:get_page(s:get_path('', 'man'))
  catch /E145:/
    " Ignore the error in restricted mode
  catch /command error .*/
    let s:localfile_arg = v:false
  endtry
endfunction

function! man#open_page(count, count1, mods, ...) abort
  if a:0 > 2
    call s:error('too many arguments')
    return
  elseif a:0 == 0
    let ref = &filetype ==# 'man' ? expand('<cWORD>') : expand('<cword>')
    if empty(ref)
      call s:error('no identifier under cursor')
      return
    endif
  elseif a:0 ==# 1
    let ref = a:1
  else
    " Combine the name and sect into a manpage reference so that all
    " verification/extraction can be kept in a single function.
    " If a:2 is a reference as well, that is fine because it is the only
    " reference that will match.
    let ref = a:2.'('.a:1.')'
  endif
  try
    let [sect, name] = man#extract_sect_and_name_ref(ref)
    if a:count ==# a:count1
      " v:count defaults to 0 which is a valid section, and v:count1 defaults to
      " 1, also a valid section. If they are equal, count explicitly set.
      let sect = string(a:count)
    endif
    let [sect, name, path] = s:verify_exists(sect, name)
  catch
    call s:error(v:exception)
    return
  endtry

  call s:push_tag()
  let bufname = 'man://'.name.(empty(sect)?'':'('.sect.')')

  try
    set eventignore+=BufReadCmd
    if a:mods !~# 'tab' && s:find_man()
      execute 'silent keepalt edit' fnameescape(bufname)
    else
      execute 'silent keepalt' a:mods 'split' fnameescape(bufname)
    endif
  finally
    set eventignore-=BufReadCmd
  endtry

  try
    let page = s:get_page(path)
  catch
    if a:mods =~# 'tab' || !s:find_man()
      " a new window was opened
      close
    endif
    call s:error(v:exception)
    return
  endtry

  let b:man_sect = sect
  call s:put_page(page)
endfunction

function! man#read_page(ref) abort
  try
    let [sect, name] = man#extract_sect_and_name_ref(a:ref)
    let [sect, name, path] = s:verify_exists(sect, name)
    let page = s:get_page(path)
  catch
    call s:error(v:exception)
    return
  endtry
  let b:man_sect = sect
  call s:put_page(page)
endfunction

" Handler for s:system() function.
function! s:system_handler(jobid, data, event) dict abort
  if a:event is# 'stdout' || a:event is# 'stderr'
    let self[a:event] .= join(a:data, "\n")
  else
    let self.exit_code = a:data
  endif
endfunction

" Run a system command and timeout after 30 seconds.
function! s:system(cmd, ...) abort
  let opts = {
        \ 'stdout': '',
        \ 'stderr': '',
        \ 'exit_code': 0,
        \ 'on_stdout': function('s:system_handler'),
        \ 'on_stderr': function('s:system_handler'),
        \ 'on_exit': function('s:system_handler'),
        \ }
  let jobid = jobstart(a:cmd, opts)

  if jobid < 1
    throw printf('command error %d: %s', jobid, join(a:cmd))
  endif

  let res = jobwait([jobid], 30000)
  if res[0] == -1
    try
      call jobstop(jobid)
      throw printf('command timed out: %s', join(a:cmd))
    catch /^Vim(call):E900:/
    endtry
  elseif res[0] == -2
    throw printf('command interrupted: %s', join(a:cmd))
  endif
  if opts.exit_code != 0
    throw printf("command error (%d) %s: %s", jobid, join(a:cmd), substitute(opts.stderr, '\_s\+$', '', &gdefault ? '' : 'g'))
  endif

  return opts.stdout
endfunction

function! s:get_page(path) abort
  " Disable hard-wrap by setting $MANWIDTH to a high value.
  " Use soft wrap instead (ftplugin/man.vim sets 'wrap', 'breakindent').
  let manwidth = 9999
  " Force MANPAGER=cat to ensure Vim is not recursively invoked (by man-db).
  " http://comments.gmane.org/gmane.editors.vim.devel/29085
  " Set MAN_KEEP_FORMATTING so Debian man doesn't discard backspaces.
  let cmd = ['env', 'MANPAGER=cat', 'MANWIDTH='.manwidth, 'MAN_KEEP_FORMATTING=1', 'man']
  return s:system(cmd + (s:localfile_arg ? ['-l', a:path] : [a:path]))
endfunction

function! s:put_page(page) abort
  setlocal modifiable
  setlocal noreadonly
  silent keepjumps %delete _
  silent put =a:page
  while getline(1) =~# '^\s*$'
    silent keepjumps 1delete _
  endwhile
  " XXX: nroff justifies text by filling it with whitespace.  That interacts
  " badly with our use of $MANWIDTH=9999.  Hack around this by using a fixed
  " size for those whitespace regions.
  silent! keeppatterns keepjumps %s/\s\{999,}/\=repeat(' ', 10)/g
  lua require("man").highlight_man_page()
  setlocal filetype=man
endfunction

function! man#show_toc() abort
  let bufname = bufname('%')
  let info = getloclist(0, {'winid': 1})
  if !empty(info) && getwinvar(info.winid, 'qf_toc') ==# bufname
    lopen
    return
  endif

  let toc = []
  let lnum = 2
  let last_line = line('$') - 1
  while lnum && lnum < last_line
    let text = getline(lnum)
    if text =~# '^\%( \{3\}\)\=\S.*$'
      call add(toc, {'bufnr': bufnr('%'), 'lnum': lnum, 'text': text})
    endif
    let lnum = nextnonblank(lnum + 1)
  endwhile

  call setloclist(0, toc, ' ')
  call setloclist(0, [], 'a', {'title': 'Man TOC'})
  lopen
  let w:qf_toc = bufname
endfunction

" attempt to extract the name and sect out of 'name(sect)'
" otherwise just return the largest string of valid characters in ref
function! man#extract_sect_and_name_ref(ref) abort
  if a:ref[0] ==# '-' " try ':Man -pandoc' with this disabled.
    throw 'manpage name cannot start with ''-'''
  endif
  let ref = matchstr(a:ref, '[^()]\+([^()]\+)')
  if empty(ref)
    let name = matchstr(a:ref, '[^()]\+')
    if empty(name)
      throw 'manpage reference cannot contain only parentheses'
    endif
    return [get(b:, 'man_default_sects', ''), name]
  endif
  let left = split(ref, '(')
  " see ':Man 3X curses' on why tolower.
  " TODO(nhooyr) Not sure if this is portable across OSs
  " but I have not seen a single uppercase section.
  return [tolower(split(left[1], ')')[0]), left[0]]
endfunction

function! s:get_path(sect, name) abort
  " Some man implementations (OpenBSD) return all available paths from the
  " search command, so we get() the first one. #8341
  if empty(a:sect)
    return substitute(get(split(s:system(['man', s:find_arg, a:name])), 0, ''), '\n\+$', '', '')
  endif
  " '-s' flag handles:
  "   - tokens like 'printf(echo)'
  "   - sections starting with '-'
  "   - 3pcap section (found on macOS)
  "   - commas between sections (for section priority)
  return substitute(get(split(s:system(['man', s:find_arg, s:section_arg, a:sect, a:name])), 0, ''), '\n\+$', '', '')
endfunction

function! s:verify_exists(sect, name) abort
  try
    let path = s:get_path(a:sect, a:name)
  catch /^command error (/
    try
      let path = s:get_path(get(b:, 'man_default_sects', ''), a:name)
    catch /^command error (/
      let path = s:get_path('', a:name)
    endtry
  endtry
  " Extract the section from the path, because sometimes the actual section is
  " more specific than what we provided to `man` (try `:Man 3 App::CLI`).
  " Also on linux, name seems to be case-insensitive. So for `:Man PRIntf`, we
  " still want the name of the buffer to be 'printf'.
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
    execute 'silent' tag['buf'].'buffer'
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
  let name = matchstr(tail, '^.\+\ze\.')
  return [sect, name]
endfunction

function! s:find_man() abort
  if &filetype ==# 'man'
    return 1
  elseif winnr('$') ==# 1
    return 0
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

function! s:error(msg) abort
  redraw
  echohl ErrorMsg
  echon 'man.vim: ' a:msg
  echohl None
endfunction

" see man#extract_sect_and_name_ref on why tolower(sect)
function! man#complete(arg_lead, cmd_line, cursor_pos) abort
  let args = split(a:cmd_line)
  let cmd_offset = index(args, 'Man')
  if cmd_offset > 0
    " Prune all arguments up to :Man itself. Otherwise modifier commands like
    " :tab, :vertical, etc. would lead to a wrong length.
    let args = args[cmd_offset:]
  endif
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
    return s:complete(sect, '', name)
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
  return s:complete(sect, sect, name)
endfunction

function! s:complete(sect, psect, name) abort
  try
    let mandirs = join(split(s:system(['man', s:find_arg]), ':\|\n'), ',')
  catch
    call s:error(v:exception)
    return
  endtry
  let pages = globpath(mandirs,'man?/'.a:name.'*.'.a:sect.'*', 0, 1)
  " We remove duplicates in case the same manpage in different languages was found.
  return uniq(sort(map(pages, 's:format_candidate(v:val, a:psect)'), 'i'))
endfunction

function! s:format_candidate(path, psect) abort
  if a:path =~# '\.\%(pdf\|in\)$' " invalid extensions
    return
  endif
  let [sect, name] = s:extract_sect_and_name_path(a:path)
  if sect ==# a:psect
    return name
  elseif sect =~# a:psect.'.\+$'
    " We include the section if the user provided section is a prefix
    " of the actual section.
    return name.'('.sect.')'
  endif
endfunction

function! man#init_pager() abort
  if getline(1) =~# '^\s*$'
    silent keepjumps 1delete _
  else
    keepjumps 1
  endif
  lua require("man").highlight_man_page()
  " This is not perfect. See `man glDrawArraysInstanced`. Since the title is
  " all caps it is impossible to tell what the original capitilization was.
  let ref = substitute(matchstr(getline(1), '^[^)]\+)'), ' ', '_', 'g')
  try
    let b:man_sect = man#extract_sect_and_name_ref(ref)[0]
  catch
    let b:man_sect = ''
  endtry
  execute 'silent file man://'.fnameescape(ref)
endfunction

call s:init()
