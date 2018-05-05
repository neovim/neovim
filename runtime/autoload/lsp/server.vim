""
" Add a server option for a filetype
"
" @param ftype (string|list): A string or list of strings of filetypes to associate with this server
"
" @returns (bool): True if successful, else false
function! lsp#server#add(ftype, command, configuration) abort
  call luaeval('require("lsp.server").add(_A.ftype, _A.command, _A.config)', {
        \ ftype: a:ftype,
        \ command: a:command,
        \ config: a:configuration })
endfunction
