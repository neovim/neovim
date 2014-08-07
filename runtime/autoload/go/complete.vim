" Copyright 2011 The Go Authors. All rights reserved.
" Use of this source code is governed by a BSD-style
" license that can be found in the LICENSE file.
"
" This file provides a utility function that performs auto-completion of
" package names, for use by other commands.

let s:goos = $GOOS
let s:goarch = $GOARCH

if len(s:goos) == 0
  if exists('g:golang_goos')
    let s:goos = g:golang_goos
  elseif has('win32') || has('win64')
    let s:goos = 'windows'
  elseif has('macunix')
    let s:goos = 'darwin'
  else
    let s:goos = '*'
  endif
endif

if len(s:goarch) == 0
  if exists('g:golang_goarch')
    let s:goarch = g:golang_goarch
  else
    let s:goarch = '*'
  endif
endif

function! go#complete#PackageMembers(package, member)
  silent! let content = system('godoc ' . a:package)
  if v:shell_error || !len(content)
    return []
  endif
  let lines = filter(split(content, "\n"),"v:val !~ '^\\s\\+$'")
  try
    let mx1 = '^\s\+\(\S+\)\s\+=\s\+.*'
    let mx2 = '^\%(const\|var\|type\|func\) \([A-Z][^ (]\+\).*'
    let candidates =
    \   map(filter(copy(lines), 'v:val =~ mx1'), 'substitute(v:val, mx1, "\\1", "")')
    \ + map(filter(copy(lines), 'v:val =~ mx2'), 'substitute(v:val, mx2, "\\1", "")')
    return filter(candidates, '!stridx(v:val, a:member)')
  catch
    return []
  endtry
endfunction

function! go#complete#Package(ArgLead, CmdLine, CursorPos)
  let dirs = []

  let words = split(a:CmdLine, '\s\+', 1)
  if len(words) > 2
    " Complete package members
    return go#complete#PackageMembers(words[1], words[2])
  endif

  if executable('go')
    let goroot = substitute(system('go env GOROOT'), '\n', '', 'g')
    if v:shell_error
      echomsg '''go env GOROOT'' failed'
    endif
  else
    let goroot = $GOROOT
  endif

  if len(goroot) != 0 && isdirectory(goroot)
    let dirs += [goroot]
  endif

  let pathsep = ':'
  if s:goos == 'windows'
    let pathsep = ';'
  endif
  let workspaces = split($GOPATH, pathsep)
  if workspaces != []
    let dirs += workspaces
  endif

  if len(dirs) == 0
    " should not happen
    return []
  endif

  let ret = {}
  for dir in dirs
    " this may expand to multiple lines
    let root = split(expand(dir . '/pkg/' . s:goos . '_' . s:goarch), "\n")
    call add(root, expand(dir . '/src'))
    for r in root
      for i in split(globpath(r, a:ArgLead.'*'), "\n")
        if isdirectory(i)
          let i .= '/'
        elseif i !~ '\.a$'
          continue
        endif
        let i = substitute(substitute(i[len(r)+1:], '[\\]', '/', 'g'), '\.a$', '', 'g')
        let ret[i] = i
      endfor
    endfor
  endfor
  return sort(keys(ret))
endfunction
