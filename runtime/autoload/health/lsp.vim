function! health#lsp#check() abort
  call health#report_start('Checking language server client configuration')
  lua require 'vim.lsp.health'.check_health()
endfunction

