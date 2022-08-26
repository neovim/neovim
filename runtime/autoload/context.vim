" Language:           ConTeXt typesetting engine
" Maintainer:         Nicola Vitacolonna <nvitacolonna@gmail.com>
" Latest Revision:    2016 Oct 21

let s:keepcpo= &cpo
set cpo&vim

" Helper functions {{{
function! s:context_echo(message, mode)
  redraw
  echo "\r"
  execute 'echohl' a:mode
  echomsg '[ConTeXt]' a:message
  echohl None
endf

function! s:sh()
  return has('win32') || has('win64') || has('win16') || has('win95')
        \ ? ['cmd.exe', '/C']
        \ : ['/bin/sh', '-c']
endfunction

" For backward compatibility
if exists('*win_getid')

  function! s:win_getid()
    return win_getid()
  endf

  function! s:win_id2win(winid)
    return win_id2win(a:winid)
  endf

else

  function! s:win_getid()
    return winnr()
  endf

  function! s:win_id2win(winnr)
    return a:winnr
  endf

endif
" }}}

" ConTeXt jobs {{{
if has('job')

  let g:context_jobs = []

  " Print the status of ConTeXt jobs
  function! context#job_status()
    let l:jobs = filter(g:context_jobs, 'job_status(v:val) == "run"')
    let l:n = len(l:jobs)
    call s:context_echo(
          \ 'There '.(l:n == 1 ? 'is' : 'are').' '.(l:n == 0 ? 'no' : l:n)
          \ .' job'.(l:n == 1 ? '' : 's').' running'
          \ .(l:n == 0 ? '.' : ' (' . join(l:jobs, ', ').').'),
          \ 'ModeMsg')
  endfunction

  " Stop all ConTeXt jobs
  function! context#stop_jobs()
    let l:jobs = filter(g:context_jobs, 'job_status(v:val) == "run"')
    for job in l:jobs
      call job_stop(job)
    endfor
    sleep 1
    let l:tmp = []
    for job in l:jobs
      if job_status(job) == "run"
        call add(l:tmp, job)
      endif
    endfor
    let g:context_jobs = l:tmp
    if empty(g:context_jobs)
      call s:context_echo('Done. No jobs running.', 'ModeMsg')
    else
      call s:context_echo('There are still some jobs running. Please try again.', 'WarningMsg')
    endif
  endfunction

  function! context#callback(path, job, status)
    if index(g:context_jobs, a:job) != -1 && job_status(a:job) != 'run' " just in case
      call remove(g:context_jobs, index(g:context_jobs, a:job))
    endif
    call s:callback(a:path, a:job, a:status)
  endfunction

  function! context#close_cb(channel)
    call job_status(ch_getjob(a:channel)) " Trigger exit_cb's callback for faster feedback
  endfunction

  function! s:typeset(path)
    call add(g:context_jobs,
          \ job_start(add(s:sh(), context#command() . ' ' . shellescape(fnamemodify(a:path, ":t"))), {
          \   'close_cb' : 'context#close_cb',
          \   'exit_cb'  : function(get(b:, 'context_callback', get(g:, 'context_callback', 'context#callback')),
          \                         [a:path]),
          \   'in_io'    : 'null'
          \ }))
  endfunction

else " No jobs

  function! context#job_status()
    call s:context_echo('Not implemented', 'WarningMsg')
  endfunction!

  function! context#stop_jobs()
    call s:context_echo('Not implemented', 'WarningMsg')
  endfunction

  function! context#callback(path, job, status)
    call s:callback(a:path, a:job, a:status)
  endfunction

  function! s:typeset(path)
    execute '!' . context#command() . ' ' . shellescape(fnamemodify(a:path, ":t"))
    call call(get(b:, 'context_callback', get(g:, 'context_callback', 'context#callback')),
          \ [a:path, 0, v:shell_error])
  endfunction

endif " has('job')

function! s:callback(path, job, status) abort
  if a:status < 0 " Assume the job was terminated
    return
  endif
  " Get info about the current window
  let l:winid = s:win_getid()             " Save window id
  let l:efm = &l:errorformat              " Save local errorformat
  let l:cwd = fnamemodify(getcwd(), ":p") " Save local working directory
  " Set errorformat to parse ConTeXt errors
  execute 'setl efm=' . escape(b:context_errorformat, ' ')
  try " Set cwd to expand error file correctly
    execute 'lcd' fnameescape(fnamemodify(a:path, ':h'))
  catch /.*/
    execute 'setl efm=' . escape(l:efm, ' ')
    throw v:exception
  endtry
  try
    execute 'cgetfile' fnameescape(fnamemodify(a:path, ':r') . '.log')
    botright cwindow
  finally " Restore cwd and errorformat
    execute s:win_id2win(l:winid) . 'wincmd w'
    execute 'lcd ' . fnameescape(l:cwd)
    execute 'setl efm=' . escape(l:efm, ' ')
  endtry
  if a:status == 0
    call s:context_echo('Success!', 'ModeMsg')
  else
    call s:context_echo('There are errors. ', 'ErrorMsg')
  endif
endfunction

function! context#command()
  return get(b:, 'context_mtxrun', get(g:, 'context_mtxrun', 'mtxrun'))
        \ . ' --script context --autogenerate --nonstopmode'
        \ . ' --synctex=' . (get(b:, 'context_synctex', get(g:, 'context_synctex', 0)) ? '1' : '0')
        \ . ' ' . get(b:, 'context_extra_options', get(g:, 'context_extra_options', ''))
endfunction

" Accepts an optional path (useful for big projects, when the file you are
" editing is not the project's root document). If no argument is given, uses
" the path of the current buffer.
function! context#typeset(...) abort
  let l:path = fnamemodify(strlen(a:000[0]) > 0 ? a:1 : expand("%"), ":p")
  let l:cwd = fnamemodify(getcwd(), ":p") " Save local working directory
  call s:context_echo('Typesetting...',  'ModeMsg')
  execute 'lcd' fnameescape(fnamemodify(l:path, ":h"))
  try
    call s:typeset(l:path)
  finally " Restore local working directory
    execute 'lcd ' . fnameescape(l:cwd)
  endtry
endfunction!
"}}}

let &cpo = s:keepcpo
unlet s:keepcpo

" vim: sw=2 fdm=marker
