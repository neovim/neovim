function! lsp#add_server_config(config) abort
  if !has_key(a:config, 'filetype')
    echoerr 'config must have filetype key'
    return
  endif

  if !has_key(a:config, 'cmd')
    echoerr 'config must have cmd key'
    return
  endif

  call luaeval('vim.lsp.server_config.add(_A.config)', { 'config': a:config })
endfunction

function! lsp#text_document_hover() abort
  call luaeval("vim.lsp.request_async('textDocument/hover', vim.lsp.protocol.TextDocumentPositionParams())")
endfunction

function! lsp#text_document_completion() abort
  call luaeval("vim.lsp.request_async('textDocument/completion', vim.lsp.protocol.CompletionParams())")
  return ''
endfunction

function! lsp#omnifunc(findstart, base) abort
  return luaeval("vim.lsp.omnifunc(_A.findstart, _A.base)", { 'findstart': a:findstart, 'base': a:base })
endfunction

function! lsp#text_document_signature_help() abort
  call luaeval("vim.lsp.request_async('textDocument/signatureHelp', vim.lsp.protocol.SignatureHelpParams())")
  return ''
endfunction

function! lsp#text_document_declaration() abort
  call luaeval("vim.lsp.request_async('textDocument/declaration', vim.lsp.protocol.TextDocumentPositionParams())")
  return ''
endfunction

function! lsp#text_document_definition() abort
  call luaeval("vim.lsp.request_async('textDocument/definition', vim.lsp.protocol.TextDocumentPositionParams())")
  return ''
endfunction

function! lsp#text_document_type_definition() abort
  call luaeval("vim.lsp.request_async('textDocument/typeDefinition', vim.lsp.protocol.TextDocumentPositionParams())")
  return ''
endfunction

function! lsp#text_document_implementation() abort
  call luaeval("vim.lsp.request_async('textDocument/implementation', vim.lsp.protocol.TextDocumentPositionParams())")
  return ''
endfunction
