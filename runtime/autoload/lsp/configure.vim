
""
" Change the autocmds that are associated with messages.
"   Use with caution, as you may break the implementation provided by the
"   plugin.
function! lsp#configure#autocmds(method, autocmd_list) abort
  " autocmd! LanguageServerProtocol 

  call luaeval("require('lsp.autocmds').reset_method(_A)", a:method)
  call luaeval("require('lsp.autocmds').set_method(_A.method, _A.list)", {
        \ 'method': a:method,
        \ 'list': a:autocmd_list,
      \ })

endfunction

""
" Configure logging levels
function! lsp#configure#console_log_level(level) abort
  call execute(printf(':lua require("neovim.log").console_level = "%s"', a:level))
endfunction

function! lsp#configure#file_log_level(level) abort
  call execute(printf(':lua require("neovim.log").file_level = "%s"', a:level))
endfunction
