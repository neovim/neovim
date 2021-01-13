
function! health#lsp#check() abort
    lua require 'health/lsp'.check_health()
endfunc

