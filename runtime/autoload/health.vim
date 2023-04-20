function! health#report_start(name) abort
  call v:lua.vim.health.start(a:name)
endfunction

function! health#report_info(msg) abort
  call v:lua.vim.health.info(a:msg)
endfunction

function! health#report_ok(msg) abort
  call v:lua.vim.health.ok(a:msg)
endfunction

function! health#report_warn(msg, ...) abort
  if a:0 > 0
    call v:lua.vim.health.warn(a:msg, a:1)
  else
    call v:lua.vim.health.warn(a:msg)
  endif
endfunction

function! health#report_error(msg, ...) abort
  if a:0 > 0
    call v:lua.vim.health.error(a:msg, a:1)
  else
    call v:lua.vim.health.error(a:msg)
  endif
endfunction
