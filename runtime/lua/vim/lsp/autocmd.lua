local autocmd = {}

autocmd.register_text_document_did_open_autocmd = function(filetype)
  vim.api.nvim_command(
    string.format("autocmd BufReadPost * :lua vim.lsp.notify('textDocument/didOpen', vim.lsp.protocol.DidOpenTextDocumentParams(), nil, nil, %s))", filetype)
  )
  end

autocmd.register_text_document_did_save_autocmd = function(filetype)
  vim.api.nvim_command(
    string.format("autocmd BufWritePost * :lua vim.lsp.notify('textDocument/didSave', vim.lsp.protocol.DidSaveTextDocumentParams(), nil, nil, %s)", filetype)
  )
end

autocmd.register_text_document_did_close_autocmd = function(filetype)
  vim.api.nvim_command(
    string.format("autocmd BufWinLeave * :lua vim.lsp.notify('textDocument/didClose', vim.lsp.protocol.DidCloseTextDocumentParams(), nil, nil, %s)", filetype)
  )
end

autocmd.register_attach_buf_autocmd = function(client)
  vim.api.nvim_command(
    string.format("autocmd BufRead * :lua %s.set_buf_change_handler(%s, vim.api.nvim_get_current_buf()", client, client)
  )
end

autocmd.register_text_document_autocmd = function(filetype)
  assert(type(filetype) == 'string', '')

  vim.api.nvim_command('augroup Lsp-'..filetype)
  vim.api.nvim_command('autocmd!')
  autocmd.register_text_document_did_open_autocmd(filetype)
  autocmd.register_text_document_did_save_autocmd(filetype)
  autocmd.register_text_document_did_close_autocmd(filetype)
  vim.api.nvim_command('augroup END')
end

autocmd.unregister_autocmd = function(filetype)
  assert(type(filetype) == 'string', '')

  vim.api.nvim_command('augroup Lsp-'..filetype)
  vim.api.nvim_command('autocmd!')
  vim.api.nvim_command('augroup END')
end

return autocmd
