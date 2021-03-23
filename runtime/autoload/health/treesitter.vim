function! health#treesitter#check() abort
  call health#report_start('Checking treesitter configuration')
  lua require 'nvim/treesitter'.check_health()
endfunction

