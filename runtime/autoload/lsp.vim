function! lsp#add_server_config(config) abort
  if !has_key(a:config, 'filetype')
    echoerr 'config must have filetype key'
    return
  endif

  if !has_key(a:config, 'cmd')
    echoerr 'config must have cmd key'
    return
  else
    if !has_key(a:config.cmd, 'execute_path')
      echoerr 'config.cmd must have execute_path key'
      return
    endif
  endif

  call luaeval('vim.lsp.server_config.add(_A.config)', { 'config': a:config })
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

function! lsp#text_document_definition() abort
  call luaeval("vim.lsp.request_async('textDocument/definition', vim.lsp.protocol.TextDocumentPositionParams())")
  return ''
endfunction
