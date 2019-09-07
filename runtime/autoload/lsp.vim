""
" Add a server option for a filetype
"
" @param ftype (string|list): A string or list of strings of filetypes to associate with this server
"
" @returns (bool): True if successful, else false
function! lsp#add_server_config(ftype, command, ...) abort
  let config = get(a:, 1, {})

  call luaeval('vim.lsp.server_config.add(_A.ftype, _A.command, _A.config)', {
        \ 'ftype': a:ftype,
        \ 'command': a:command,
        \ 'config': config,
        \ })
endfunction

function! lsp#text_document_hover() abort
  call luaeval("vim.lsp.request_async('textDocument/hover', vim.lsp.protocol.TextDocumentPositionParams())")
endfunction

" Completion with LSP
function! lsp#text_document_completion() abort
  call luaeval("vim.lsp.request_async('textDocument/completion', vim.lsp.protocol.CompletionParams())")
  return ''
endfunction

function! lsp#text_document_signature_help() abort
  call luaeval("vim.lsp.request_async('textDocument/signatureHelp', vim.lsp.protocol.SignatureHelpParams())")
  return ''
endfunction
