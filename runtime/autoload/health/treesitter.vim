function! health#treesitter#check() abort
  call health#report_start('Checking treesitter configuration')
  lua require 'vim.treesitter.health'.check_health()
endfunction

