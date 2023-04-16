function! s:deprecate(type) abort
  let deprecate = v:lua.vim.deprecate('health#report_' . a:type, 'vim.health.' . a:type, '0.11')
  redraw | echo 'Running healthchecks...'
  if deprecate isnot v:null
    call v:lua.vim.health.warn(deprecate)
  endif
endfunction

function! health#report_start(name) abort
  call v:lua.vim.health.start(a:name)
  call s:deprecate('start')
endfunction

function! health#report_info(msg) abort
  call v:lua.vim.health.info(a:msg)
  call s:deprecate('info')
endfunction

function! health#report_ok(msg) abort
  call v:lua.vim.health.ok(a:msg)
  call s:deprecate('ok')
endfunction

function! health#report_warn(msg, ...) abort
  if a:0 > 0
    call v:lua.vim.health.warn(a:msg, a:1)
  else
    call v:lua.vim.health.warn(a:msg)
  endif
  call s:deprecate('warn')
endfunction

function! health#report_error(msg, ...) abort
  if a:0 > 0
    call v:lua.vim.health.error(a:msg, a:1)
  else
    call v:lua.vim.health.error(a:msg)
  endif
  call s:deprecate('error')
endfunction
