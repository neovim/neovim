" Vim compiler file
" Language:    TOML
" Maintainer:  Konfekt
" Last Change: 2025 Oct 29

if exists("current_compiler") | finish | endif
let current_compiler = "tombi"

let s:cpo_save = &cpo
set cpo&vim

if !executable('tombi')
  echoerr "tombi compiler: 'tombi' executable not found in PATH"
  let &cpo = s:cpo_save
  unlet s:cpo_save
  finish
endif

" NO_COLOR support requires tombi 0.6.40 or later
if !exists('s:tombi_nocolor')
  " Expect output like: 'tombi 0.6.40' or '0.6.40'
  let s:out = trim(system('tombi --version'))
  let s:tombi_ver = matchstr(s:out, '\v\s\d+\.\d+\.\d+$')

  function s:VersionGE(ver, req) abort
    " Compare semantic versions a.b.c ≥ x.y.z
    let l:pa = map(split(a:ver, '\.'), 'str2nr(v:val)')
    let l:pb = map(split(a:req, '\.'), 'str2nr(v:val)')
    while len(l:pa) < 3 | call add(l:pa, 0) | endwhile
    while len(l:pb) < 3 | call add(l:pb, 0) | endwhile
    for i in range(0, 2)
      if l:pa[i] > l:pb[i] | return 1
      elseif l:pa[i] < l:pb[i] | return 0
      endif
    endfor
    return 1
  endfunction
  let s:tombi_nocolor = s:VersionGE(s:tombi_ver, '0.6.40')
  delfunction s:VersionGE
endif

if s:tombi_nocolor
  if has('win32')
    if &shell =~# '\v<%(cmd|cmd)>'
      CompilerSet makeprg=set\ NO_COLOR=1\ &&\ tombi\ lint
    elseif &shell =~# '\v<%(powershell|pwsh)>'
      CompilerSet makeprg=$env:NO_COLOR=\"1\";\ tombi\ lint
    else
      echoerr "tombi compiler: Unsupported shell for Windows"
    endif
  else " if has('unix')
    CompilerSet makeprg=env\ NO_COLOR=1\ tombi\ lint
  endif
else
  " Older tombi: strip ANSI color codes with sed.
  if executable('sed')
    CompilerSet makeprg=tombi\ lint\ $*\ \|\ sed\ -E\ \"s/\\x1B(\\[[0-9;]*[JKmsu]\|\\(B)//g\"
  else
    echoerr "tombi compiler: tombi version < 0.6.40 requires 'sed' to strip ANSI color codes"
  endif
endif

CompilerSet errorformat=%E%*\\sError:\ %m,%Z%*\\sat\ %f:%l:%c
CompilerSet errorformat+=%W%*\\sWarning:\ %m,%Z%*\\sat\ %f:%l:%c
CompilerSet errorformat+=%-G1\ file\ failed\ to\ be\ linted
CompilerSet errorformat+=%-G1\ file\ linted\ successfully

let &cpo = s:cpo_save
unlet s:cpo_save
