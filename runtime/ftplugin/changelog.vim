" Vim filetype plugin file
" Language:         generic Changelog file
" Maintainer:       Nikolai Weibull <now@bitwi.se>
" Latest Revision:  2014-01-10
" Variables:
"   g:changelog_timeformat (deprecated: use g:changelog_dateformat instead) -
"       description: the timeformat used in ChangeLog entries.
"       default: "%Y-%m-%d".
"   g:changelog_dateformat -
"       description: the format sent to strftime() to generate a date string.
"       default: "%Y-%m-%d".
"   g:changelog_username -
"       description: the username to use in ChangeLog entries
"       default: try to deduce it from environment variables and system files.
" Local Mappings:
"   <Leader>o -
"       adds a new changelog entry for the current user for the current date.
" Global Mappings:
"   <Leader>o -
"       switches to the ChangeLog buffer opened for the current directory, or
"       opens it in a new buffer if it exists in the current directory.  Then
"       it does the same as the local <Leader>o described above.
" Notes:
"   run 'runtime ftplugin/changelog.vim' to enable the global mapping for
"   changelog files.
" TODO:
"  should we perhaps open the ChangeLog file even if it doesn't exist already?
"  Problem is that you might end up with ChangeLog files all over the place.

" If 'filetype' isn't "changelog", we must have been to add ChangeLog opener
if &filetype == 'changelog'
  if exists('b:did_ftplugin')
    finish
  endif
  let b:did_ftplugin = 1

  let s:cpo_save = &cpo
  set cpo&vim

  " Set up the format used for dates.
  if !exists('g:changelog_dateformat')
    if exists('g:changelog_timeformat')
      let g:changelog_dateformat = g:changelog_timeformat
    else
      let g:changelog_dateformat = "%Y-%m-%d"
    endif
  endif

  function! s:username()
    if exists('g:changelog_username')
      return g:changelog_username
    elseif $EMAIL != ""
      return $EMAIL
    elseif $EMAIL_ADDRESS != ""
      return $EMAIL_ADDRESS
    endif
    
    let login = s:login()
    return printf('%s <%s@%s>', s:name(login), login, s:hostname())
  endfunction

  function! s:login()
    return s:trimmed_system_with_default('whoami', 'unknown')
  endfunction

  function! s:trimmed_system_with_default(command, default)
    return s:first_line(s:system_with_default(a:command, a:default))
  endfunction

  function! s:system_with_default(command, default)
    let output = system(a:command)
    if v:shell_error
      return default
    endif
    return output
  endfunction

  function! s:first_line(string)
    return substitute(a:string, '\n.*$', "", "")
  endfunction

  function! s:name(login)
    for name in [s:gecos_name(a:login), $NAME, s:capitalize(a:login)]
      if name != ""
        return name
      endif
    endfor
  endfunction

  function! s:gecos_name(login)
    for line in s:try_reading_file('/etc/passwd')
      if line =~ '^' . a:login . ':'
        return substitute(s:passwd_field(line, 5), '&', s:capitalize(a:login), "")
      endif
    endfor
    return ""
  endfunction

  function! s:try_reading_file(path)
    try
      return readfile(a:path)
    catch
      return []
    endtry
  endfunction

  function! s:passwd_field(line, field)
    let fields = split(a:line, ':', 1)
    if len(fields) < a:field
      return ""
    endif
    return fields[a:field - 1]
  endfunction

  function! s:capitalize(word)
    return toupper(a:word[0]) . strpart(a:word, 1)
  endfunction

  function! s:hostname()
    return s:trimmed_system_with_default('hostname', 'localhost')
  endfunction

  " Format used for new date entries.
  if !exists('g:changelog_new_date_format')
    let g:changelog_new_date_format = "%d  %u\n\n\t* %p%c\n\n"
  endif

  " Format used for new entries to current date entry.
  if !exists('g:changelog_new_entry_format')
    let g:changelog_new_entry_format = "\t* %p%c"
  endif

  " Regular expression used to find a given date entry.
  if !exists('g:changelog_date_entry_search')
    let g:changelog_date_entry_search = '^\s*%d\_s*%u'
  endif

  " Regular expression used to find the end of a date entry
  if !exists('g:changelog_date_end_entry_search')
    let g:changelog_date_end_entry_search = '^\s*$'
  endif


  " Substitutes specific items in new date-entry formats and search strings.
  " Can be done with substitute of course, but unclean, and need \@! then.
  function! s:substitute_items(str, date, user, prefix)
    let str = a:str
    let middles = {'%': '%', 'd': a:date, 'u': a:user, 'p': a:prefix, 'c': '{cursor}'}
    let i = stridx(str, '%')
    while i != -1
      let inc = 0
      if has_key(middles, str[i + 1])
        let mid = middles[str[i + 1]]
        let str = strpart(str, 0, i) . mid . strpart(str, i + 2)
        let inc = strlen(mid) - 1
      endif
      let i = stridx(str, '%', i + 1 + inc)
    endwhile
    return str
  endfunction

  " Position the cursor once we've done all the funky substitution.
  function! s:position_cursor()
    if search('{cursor}') > 0
      let lnum = line('.')
      let line = getline(lnum)
      let cursor = stridx(line, '{cursor}')
      call setline(lnum, substitute(line, '{cursor}', '', ''))
    endif
    startinsert!
  endfunction

  " Internal function to create a new entry in the ChangeLog.
  function! s:new_changelog_entry(prefix)
    " Deal with 'paste' option.
    let save_paste = &paste
    let &paste = 1
    call cursor(1, 1)
    " Look for an entry for today by our user.
    let date = strftime(g:changelog_dateformat)
    let search = s:substitute_items(g:changelog_date_entry_search, date,
                                  \ s:username(), a:prefix)
    if search(search) > 0
      " Ok, now we look for the end of the date entry, and add an entry.
      call cursor(nextnonblank(line('.') + 1), 1)
      if search(g:changelog_date_end_entry_search, 'W') > 0
	let p = (line('.') == line('$')) ? line('.') : line('.') - 1
      else
        let p = line('.')
      endif
      let ls = split(s:substitute_items(g:changelog_new_entry_format, '', '', a:prefix),
                   \ '\n')
      call append(p, ls)
      call cursor(p + 1, 1)
    else
      " Flag for removing empty lines at end of new ChangeLogs.
      let remove_empty = line('$') == 1

      " No entry today, so create a date-user header and insert an entry.
      let todays_entry = s:substitute_items(g:changelog_new_date_format,
                                          \ date, s:username(), a:prefix)
      " Make sure we have a cursor positioning.
      if stridx(todays_entry, '{cursor}') == -1
        let todays_entry = todays_entry . '{cursor}'
      endif

      " Now do the work.
      call append(0, split(todays_entry, '\n'))

      " Remove empty lines at end of file.
      if remove_empty
        $-/^\s*$/-1,$delete
      endif

      " Reposition cursor once we're done.
      call cursor(1, 1)
    endif

    call s:position_cursor()

    " And reset 'paste' option
    let &paste = save_paste
  endfunction

  if exists(":NewChangelogEntry") != 2
    noremap <buffer> <silent> <Leader>o <Esc>:call <SID>new_changelog_entry('')<CR>
    command! -nargs=0 NewChangelogEntry call s:new_changelog_entry('')
  endif

  let b:undo_ftplugin = "setl com< fo< et< ai<"

  setlocal comments=
  setlocal formatoptions+=t
  setlocal noexpandtab
  setlocal autoindent

  if &textwidth == 0
    setlocal textwidth=78
    let b:undo_ftplugin .= " tw<"
  endif

  let &cpo = s:cpo_save
  unlet s:cpo_save
else
  let s:cpo_save = &cpo
  set cpo&vim

  " Add the Changelog opening mapping
  nnoremap <silent> <Leader>o :call <SID>open_changelog()<CR>

  function! s:open_changelog()
    let path = expand('%:p:h')
    if exists('b:changelog_path')
      let changelog = b:changelog_path
    else
      if exists('b:changelog_name')
        let name = b:changelog_name
      else
        let name = 'ChangeLog'
      endif
      while isdirectory(path)
        let changelog = path . '/' . name
        if filereadable(changelog)
          break
        endif
        let parent = substitute(path, '/\+[^/]*$', "", "")
        if path == parent
          break
        endif
        let path = parent
      endwhile
    endif
    if !filereadable(changelog)
      return
    endif

    if exists('b:changelog_entry_prefix')
      let prefix = call(b:changelog_entry_prefix, [])
    else
      let prefix = substitute(strpart(expand('%:p'), strlen(path)), '^/\+', "", "")
    endif

    let buf = bufnr(changelog)
    if buf != -1
      if bufwinnr(buf) != -1
        execute bufwinnr(buf) . 'wincmd w'
      else
        execute 'sbuffer' buf
      endif
    else
      execute 'split' fnameescape(changelog)
    endif

    call s:new_changelog_entry(prefix)
  endfunction

  let &cpo = s:cpo_save
  unlet s:cpo_save
endif
