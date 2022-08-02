" Maintainer: Anmol Sethi <hi@nhooyr.io>

if exists('s:loaded_man')
  finish
endif
let s:loaded_man = 1

let s:find_arg = '-w'
let s:localfile_arg = v:true  " Always use -l if possible. #6683

function! man#init() abort
  try
    " Check for -l support.
    call s:get_page(s:get_path('', 'man'))
  catch /command error .*/
    let s:localfile_arg = v:false
  endtry
endfunction

function! man#open_page(count, mods, ...) abort
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
    let [sect, name] = s:extract_sect_and_name_ref(ref)
    if a:count >= 0
      let sect = string(a:count)
    endif
    let path = s:verify_exists(sect, name)
    let [sect, name] = s:extract_sect_and_name_path(path)
  catch
    call s:error(v:exception)
    return
  endtry

  let [l:buf, l:save_tfu] = [bufnr(), &tagfunc]
  try
    setlocal tagfunc=man#goto_tag
    let l:target = l:name . '(' . l:sect . ')'
    if a:mods !~# 'tab' && s:find_man()
      execute 'silent keepalt tag' l:target
    else
      execute 'silent keepalt' a:mods 'stag' l:target
    endif
    call s:set_options(v:false)
  finally
    call setbufvar(l:buf, '&tagfunc', l:save_tfu)
  endtry

  let b:man_sect = sect
endfunction

" Called when a man:// buffer is opened.
function! man#read_page(ref) abort
  try
    let [sect, name] = s:extract_sect_and_name_ref(a:ref)
    let path = s:verify_exists(sect, name)
    let [sect, name] = s:extract_sect_and_name_path(path)
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

function! s:set_options(pager) abort
  setlocal noswapfile buftype=nofile bufhidden=hide
  setlocal nomodified readonly nomodifiable
  let b:pager = a:pager
  setlocal filetype=man
endfunction

function! s:get_page(path) abort
  " Disable hard-wrap by using a big $MANWIDTH (max 1000 on some systems #9065).
  " Soft-wrap: ftplugin/man.vim sets wrap/breakindent/….
  " Hard-wrap: driven by `man`.
  let manwidth = !get(g:, 'man_hardwrap', 1) ? 999 : (empty($MANWIDTH) ? winwidth(0) : $MANWIDTH)
  " Force MANPAGER=cat to ensure Vim is not recursively invoked (by man-db).
  " http://comments.gmane.org/gmane.editors.vim.devel/29085
  " Set MAN_KEEP_FORMATTING so Debian man doesn't discard backspaces.
  let cmd = ['env', 'MANPAGER=cat', 'MANWIDTH='.manwidth, 'MAN_KEEP_FORMATTING=1', 'man']
  return s:system(cmd + (s:localfile_arg ? ['-l', a:path] : [a:path]))
endfunction

function! s:put_page(page) abort
  setlocal modifiable noreadonly noswapfile
  silent keepjumps %delete _
  silent put =a:page
  while getline(1) =~# '^\s*$'
    silent keepjumps 1delete _
  endwhile
  " XXX: nroff justifies text by filling it with whitespace.  That interacts
  " badly with our use of $MANWIDTH=999.  Hack around this by using a fixed
  " size for those whitespace regions.
  silent! keeppatterns keepjumps %s/\s\{199,}/\=repeat(' ', 10)/g
  1
  lua require("man").highlight_man_page()
  call s:set_options(v:false)
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
      " if text is a section title
      call add(toc, {'bufnr': bufnr('%'), 'lnum': lnum, 'text': text})
    elseif text =~# '^\s\+\%(+\|-\)\S\+'
      " if text is a flag title. we strip whitespaces and prepend two
      " spaces to have a consistent format in the loclist.
      let text = '  ' .. substitute(text, '^\s*\(.\{-}\)\s*$', '\1', '')
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
function! s:extract_sect_and_name_ref(ref) abort
  if a:ref[0] ==# '-' " try ':Man -pandoc' with this disabled.
    throw 'manpage name cannot start with ''-'''
  endif
  let ref = matchstr(a:ref, '[^()]\+([^()]\+)')
  if empty(ref)
    let name = matchstr(a:ref, '[^()]\+')
    if empty(name)
      throw 'manpage reference cannot contain only parentheses'
    endif
    return ['', s:spaces_to_underscores(name)]
  endif
  let left = split(ref, '(')
  " see ':Man 3X curses' on why tolower.
  " TODO(nhooyr) Not sure if this is portable across OSs
  " but I have not seen a single uppercase section.
  return [tolower(split(left[1], ')')[0]), s:spaces_to_underscores(left[0])]
endfunction

" replace spaces in a man page name with underscores
" intended for PostgreSQL, which has man pages like 'CREATE_TABLE(7)';
" while editing SQL source code, it's nice to visually select 'CREATE TABLE'
" and hit 'K', which requires this transformation
function! s:spaces_to_underscores(str)
  return substitute(a:str, ' ', '_', 'g')
endfunction

function! s:get_path(sect, name) abort
  " Some man implementations (OpenBSD) return all available paths from the
  " search command. Previously, this function would simply select the first one.
  "
  " However, some searches will report matches that are incorrect:
  " man -w strlen may return string.3 followed by strlen.3, and therefore
  " selecting the first would get us the wrong page. Thus, we must find the
  " first matching one.
  "
  " There's yet another special case here. Consider the following:
  " If you run man -w strlen and string.3 comes up first, this is a problem. We
  " should search for a matching named one in the results list.
  " However, if you search for man -w clock_gettime, you will *only* get
  " clock_getres.2, which is the right page. Searching the resuls for
  " clock_gettime will no longer work. In this case, we should just use the
  " first one that was found in the correct section.
  "
  " Finally, we can avoid relying on -S or -s here since they are very
  " inconsistently supported. Instead, call -w with a section and a name.
  if empty(a:sect)
    let results = split(s:system(['man', s:find_arg, a:name]))
  else
    let results = split(s:system(['man', s:find_arg, a:sect, a:name]))
  endif

  if empty(results)
    return ''
  endif

  " find any that match the specified name
  let namematches = filter(copy(results), 'fnamemodify(v:val, ":t") =~ a:name')
  let sectmatches = []

  if !empty(namematches) && !empty(a:sect)
    let sectmatches = filter(copy(namematches), 'fnamemodify(v:val, ":e") == a:sect')
  endif

  return substitute(get(sectmatches, 0, get(namematches, 0, results[0])), '\n\+$', '', '')
endfunction

" s:verify_exists attempts to find the path to a manpage
" based on the passed section and name.
"
" 1. If the passed section is empty, b:man_default_sects is used.
" 2. If manpage could not be found with the given sect and name,
"    then another attempt is made with b:man_default_sects.
" 3. If it still could not be found, then we try again without a section.
" 4. If still not found but $MANSECT is set, then we try again with $MANSECT
"    unset.
"
" This function is careful to avoid duplicating a search if a previous
" step has already done it. i.e if we use b:man_default_sects in step 1,
" then we don't do it again in step 2.
function! s:verify_exists(sect, name) abort
  let sect = a:sect

  if empty(sect)
    " no section specified, so search with b:man_default_sects
    if exists('b:man_default_sects')
      let sects = split(b:man_default_sects, ',')
      for sec in sects
        try
          let res = s:get_path(sec, a:name)
          if !empty(res)
            return res
          endif
        catch /^command error (/
        endtry
      endfor
    endif
  else
    " try with specified section
    try
      let res = s:get_path(sect, a:name)
      if !empty(res)
        return res
      endif
    catch /^command error (/
    endtry

    " try again with b:man_default_sects
    if exists('b:man_default_sects')
      let sects = split(b:man_default_sects, ',')
      for sec in sects
        try
          let res = s:get_path(sec, a:name)
          if !empty(res)
            return res
          endif
        catch /^command error (/
        endtry
      endfor
    endif
  endif

  " if none of the above worked, we will try with no section
  try
    let res = s:get_path('', a:name)
    if !empty(res)
      return res
    endif
  catch /^command error (/
  endtry

  " if that still didn't work, we will check for $MANSECT and try again with it
  " unset
  if !empty($MANSECT)
    try
      let MANSECT = $MANSECT
      call setenv('MANSECT', v:null)
      let res = s:get_path('', a:name)
      if !empty(res)
        return res
      endif
    catch /^command error (/
    finally
      call setenv('MANSECT', MANSECT)
    endtry
  endif

  " finally, if that didn't work, there is no hope
  throw 'no manual entry for ' . a:name
endfunction

" Extracts the name/section from the 'path/name.sect', because sometimes the actual section is
" more specific than what we provided to `man` (try `:Man 3 App::CLI`).
" Also on linux, name seems to be case-insensitive. So for `:Man PRIntf`, we
" still want the name of the buffer to be 'printf'.
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
  let l:win = 1
  while l:win <= winnr('$')
    let l:buf = winbufnr(l:win)
    if getbufvar(l:buf, '&filetype', '') ==# 'man'
      execute l:win.'wincmd w'
      return 1
    endif
    let l:win += 1
  endwhile
  return 0
endfunction

function! s:error(msg) abort
  redraw
  echohl ErrorMsg
  echon 'man.vim: ' a:msg
  echohl None
endfunction

" see s:extract_sect_and_name_ref on why tolower(sect)
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

function! s:get_paths(sect, name, do_fallback) abort
  " callers must try-catch this, as some `man` implementations don't support `s:find_arg`
  try
    let mandirs = join(split(s:system(['man', s:find_arg]), ':\|\n'), ',')
    let paths = globpath(mandirs, 'man?/'.a:name.'*.'.a:sect.'*', 0, 1)
    try
      " Prioritize the result from verify_exists as it obeys b:man_default_sects.
      let first = s:verify_exists(a:sect, a:name)
      let paths = filter(paths, 'v:val !=# first')
      let paths = [first] + paths
    catch
    endtry
    return paths
  catch
    if !a:do_fallback
      throw v:exception
    endif

    " Fallback to a single path, with the page we're trying to find.
    try
      return [s:verify_exists(a:sect, a:name)]
    catch
      return []
    endtry
  endtry
endfunction

function! s:complete(sect, psect, name) abort
  let pages = s:get_paths(a:sect, a:name, v:false)
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

" Called when Nvim is invoked as $MANPAGER.
function! man#init_pager() abort
  if getline(1) =~# '^\s*$'
    silent keepjumps 1delete _
  else
    keepjumps 1
  endif
  lua require("man").highlight_man_page()
  " Guess the ref from the heading (which is usually uppercase, so we cannot
  " know the correct casing, cf. `man glDrawArraysInstanced`).
  let ref = substitute(matchstr(getline(1), '^[^)]\+)'), ' ', '_', 'g')
  try
    let b:man_sect = s:extract_sect_and_name_ref(ref)[0]
  catch
    let b:man_sect = ''
  endtry
  if -1 == match(bufname('%'), 'man:\/\/')  " Avoid duplicate buffers, E95.
    execute 'silent file man://'.tolower(fnameescape(ref))
  endif

  call s:set_options(v:true)
endfunction

function! man#goto_tag(pattern, flags, info) abort
  let [l:sect, l:name] = s:extract_sect_and_name_ref(a:pattern)

  let l:paths = s:get_paths(l:sect, l:name, v:true)
  let l:structured = []

  for l:path in l:paths
    let [l:sect, l:name] = s:extract_sect_and_name_path(l:path)
    let l:structured += [{
          \ 'name': l:name,
          \ 'title': l:name . '(' . l:sect . ')'
          \ }]
  endfor

  if &cscopetag
    " return only a single entry so we work well with :cstag (#11675)
    let l:structured = l:structured[:0]
  endif

  return map(l:structured, {
  \  _, entry -> {
  \      'name': entry.name,
  \      'filename': 'man://' . entry.title,
  \      'cmd': '1'
  \    }
  \  })
endfunction

call man#init()
