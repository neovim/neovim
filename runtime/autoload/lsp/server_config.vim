""
" Add a server option for a filetype
"
" @param ftype (string|list): A string or list of strings of filetypes to associate with this server
"
" @returns (bool): True if successful, else false
function! lsp#server_config#add(ftype, command, ...) abort
  let config = get(a:, 1, {})

  call luaeval('require("lsp.api").server_config.add(_A.ftype, _A.command, _A.config)', {
        \ 'ftype': a:ftype,
        \ 'command': a:command,
        \ 'config': config,
        \ })
endfunction
