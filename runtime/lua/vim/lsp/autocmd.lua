local autocmd = {}

autocmd.register_text_document_did_open_autocmd = function(filetype, server_name)
  vim.api.nvim_command(
    string.format("autocmd BufReadPost * :lua vim.lsp.notify('textDocument/didOpen', vim.lsp.protocol.DidOpenTextDocumentParams(), nil, '%s', '%s')", filetype, server_name))
  end

autocmd.register_text_document_did_save_autocmd = function(filetype, server_name)
  vim.api.nvim_command(
    string.format("autocmd BufWritePost * :lua vim.lsp.notify('textDocument/didSave', vim.lsp.protocol.DidSaveTextDocumentParams(), nil, '%s', '%s')", filetype, server_name)
  )
end

autocmd.register_text_document_did_close_autocmd = function(filetype, server_name)
  vim.api.nvim_command(
    string.format("autocmd BufWinLeave * :lua vim.lsp.notify('textDocument/didClose', vim.lsp.protocol.DidCloseTextDocumentParams(), nil, '%s', '%s')", filetype, server_name)
  )
end

autocmd.register_attach_buf_autocmd = function(filetype, server_name)
  vim.api.nvim_command(
    string.format("autocmd BufRead * :lua vim.lsp.get_client('%s', '%s'):set_buf_change_handler(vim.api.nvim_get_current_buf())", filetype, server_name)
  )
end

autocmd.register_text_document_autocmd = function(filetype, server_name)
  assert(type(filetype) == 'string', "'filetype' argument is required.")

  vim.api.nvim_command('augroup LSP-'..filetype..'-'..server_name..'-textDocument')
  vim.api.nvim_command('autocmd!')
  autocmd.register_text_document_did_open_autocmd(filetype, server_name)
  autocmd.register_text_document_did_save_autocmd(filetype, server_name)
  autocmd.register_text_document_did_close_autocmd(filetype, server_name)
  autocmd.register_attach_buf_autocmd(filetype, server_name)
  vim.api.nvim_command('augroup END')
end

autocmd.unregister_autocmd = function(filetype, server_name)
  assert(type(filetype) == 'string', '')

  vim.api.nvim_command('augroup LSP-'..filetype..'-'..server_name..'-textDocument')
  vim.api.nvim_command('autocmd!')
  vim.api.nvim_command('augroup END')
end

return autocmd
