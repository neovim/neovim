" Adapted from fatih/vim-go: autoload/go/fmt.vim
"
" Copyright 2011 The Go Authors. All rights reserved.
" Use of this source code is governed by a BSD-style
" license that can be found in the LICENSE file.
"
" Upstream: https://github.com/ziglang/zig.vim

function! zig#fmt#Format() abort
  " Save cursor position and many other things.
  let view = winsaveview()

  if !executable('zig')
    echohl Error | echomsg "no zig binary found in PATH" | echohl None
    return
  endif

  let cmdline = 'zig fmt --stdin --ast-check'
  let current_buf = bufnr('')

  " The formatted code is output on stdout, the errors go on stderr.
  if exists('*systemlist')
    silent let out = systemlist(cmdline, current_buf)
  else
    silent let out = split(system(cmdline, current_buf))
  endif
  if len(out) == 1
    if out[0] == "error: unrecognized parameter: '--ast-check'"
      let cmdline = 'zig fmt --stdin'
      if exists('*systemlist')
        silent let out = systemlist(cmdline, current_buf)
      else
        silent let out = split(system(cmdline, current_buf))
      endif
    endif
  endif
  let err = v:shell_error


  if err == 0
    " remove undo point caused via BufWritePre.
    try | silent undojoin | catch | endtry

    " Replace the file content with the formatted version.
    if exists('*deletebufline')
      call deletebufline(current_buf, len(out), line('$'))
    else
      silent execute ':' . len(out) . ',' . line('$') . ' delete _'
    endif
    call setline(1, out)

    " No errors detected, close the loclist.
    call setloclist(0, [], 'r')
    lclose
  elseif get(g:, 'zig_fmt_parse_errors', 1)
    let errors = s:parse_errors(expand('%'), out)

    call setloclist(0, [], 'r', {
        \ 'title': 'Errors',
        \ 'items': errors,
        \ })

    let max_win_height = get(g:, 'zig_fmt_max_window_height', 5)
    " Prevent the loclist from becoming too long.
    let win_height = min([max_win_height, len(errors)])
    " Open the loclist, but only if there's at least one error to show.
    execute 'silent! lwindow ' . win_height
  endif

  call winrestview(view)

  if err != 0
    echohl Error | echomsg "zig fmt returned error" | echohl None
    return
  endif

  " Run the syntax highlighter on the updated content and recompute the folds if
  " needed.
  syntax sync fromstart
endfunction

" parse_errors parses the given errors and returns a list of parsed errors
function! s:parse_errors(filename, lines) abort
  " list of errors to be put into location list
  let errors = []
  for line in a:lines
    let tokens = matchlist(line, '^\(.\{-}\):\(\d\+\):\(\d\+\)\s*\(.*\)')
    if !empty(tokens)
      call add(errors,{
            \"filename": a:filename,
            \"lnum":     tokens[2],
            \"col":      tokens[3],
            \"text":     tokens[4],
            \ })
    endif
  endfor

  return errors
endfunction
" vim: sw=2 ts=2 et
