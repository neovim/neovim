let s:logger = {'d_events': []}
function s:logger.on_stdout(id, data, event)
  call add(self.d_events, [a:event, a:data])
endfunction
let s:logger.on_stderr = s:logger.on_stdout
function s:logger.on_exit(id, data, event)
  call add(self.d_events, [a:event, ['']])
endfunction

let s:logger.env = #{VIMRUNTIME: $VIMRUNTIME}

" Replace non-printable chars by special sequence, or "<%x>".
let s:escaped_char = {"\n": '\n', "\r": '\r', "\t": '\t'}
function! s:escape_non_printable(char) abort
  let r = get(s:escaped_char, a:char)
  return r is 0 ? printf('<%x>', char2nr(a:char)) : r
endfunction

function Main()
  let argc = +$NVIM_TEST_ARGC
  let args = []
  for i in range(argc)
    call add(args, eval("$NVIM_TEST_ARG" . i))
  endfor
  set lines=25
  set columns=80
  enew
  let job = termopen(args, s:logger)
  let results = jobwait([job], 5 * 60 * 1000)
  " TODO(ZyX-I): Get colors
  let screen = getline(1, '$')
  call jobstop(job)  " kills the job always.
  bwipeout!
  let stringified_events = map(s:logger.d_events,
        \'v:val[0] . ": " . ' .
        \'join(map(v:val[1], '.
        \         '''substitute(v:val, '.
        \                      '"\\v\\C(\\p@!.|\\<)", '.
        \                      '"\\=s:escape_non_printable(submatch(0))", '.
        \                      '"g")''), '.
        \     '''\n'')')
  call setline(1, [
        \ 'Job exited with code ' . results[0],
        \ printf('Screen (%u lines)', len(screen)),
        \ repeat('=', 80),
        \] +  screen + [
        \ repeat('=', 80),
        \ printf('Events (%u lines):', len(stringified_events)),
        \ repeat('=', 80),
        \] + stringified_events + [
        \ repeat('=', 80),
        \])
  write
  if results[0] != 0
    cquit
  else
    qall
  endif
endfunction

call Main()
