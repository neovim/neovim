" Extra default keymaps and keyboard behavior

" Exit quickly if
" 1) the user has disabled the plugin
" 2) this file is already loaded
if exists('g:nvim#extra_maps#use') && g:nvim#extra_maps#use == 0
  || exists('g:nvim#extra_maps#loaded') && g:nvim#extra_maps#loaded == 1
  finish
endif

" Set defaults:
" The user can disable parts of the plugin separatedly
" by setting any of these to 0
if !exists("g:nvim#extra_maps#leave_term_mode")
  let g:nvim#extra_maps#leave_term_mode = 1
endif
if !exists("g:nvim#extra_maps#Y_eol")
  let g:nvim#extra_maps#Y_eol = 1
endif
if !exists("g:nvim#extra_maps#undo_ctrl_u")
  let g:nvim#extra_maps#undo_ctrl_u = 1
endif
if !exists("g:nvim#extra_maps#smart_home")
  let g:nvim#extra_maps#smart_home = 1
endif

" Do a mapping
function! s:DefMap(var, lhs, mode, map)
  " We don't want to mask user defined mappings, so we check
  if g:nvim#extra_maps#{a:var} is 1 && maparg(a:lhs, a:mode) == ''
    exe a:mode.'noremap '. a:map
  endif
endfunction

" Do the mappings:
call s:DefMap('leave_term_mode', '<esc><esc>', 't', '<esc><esc> <C-\><c-n>')
call s:DefMap('Y_eol', 'Y', '', 'Y y$')
call s:DefMap('undo_ctrl_u', '<C-u>', 'i', '<C-u> <C-g>u<C-u>')
call s:DefMap('smart_home', '<home>', '', '<expr> <home> virtcol(".") - 1 <= indent(".") && col(".") > 1 ? "0" : "_"')

let g:nvim#extra_maps#loaded = 1

" vim: set sw=2 et :
