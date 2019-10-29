local autocmd = {}

local function augroup_name(filetype, server_name)
	assert(filetype:match("^%S+$"), "filetype cannot contain spaces")
	assert(server_name:match("^%S+$"), "server_name cannot contain spaces")
	return ("LSP_%s_%s_textDocument"):format(filetype, server_name)
end

local function lsp_augroup(filetype, server_name, commands)
	vim.api.nvim_command('augroup '..augroup_name(filetype, server_name))
	vim.api.nvim_command('autocmd!')
	for _, command in ipairs(commands) do
		vim.api.nvim_command(command)
	end
  vim.api.nvim_command('augroup END')
end

function autocmd.register_text_document_autocmd(filetype, server_name)
  assert(type(filetype) == 'string', "'filetype' argument is required.")

	lsp_augroup(filetype, server_name, {
    string.format("autocmd BufRead * :lua vim.lsp.get_client(%q, %q):set_buf_change_handler(vim.api.nvim_get_current_buf())", filetype, server_name);
    string.format("autocmd BufReadPost * :lua vim.lsp.notify('textDocument/didOpen', vim.lsp.protocol.DidOpenTextDocumentParams(), nil, %q, %q)", filetype, server_name);
    string.format("autocmd BufWinLeave * :lua vim.lsp.notify('textDocument/didClose', vim.lsp.protocol.DidCloseTextDocumentParams(), nil, %q, %q)", filetype, server_name);
    string.format("autocmd BufWritePost * :lua vim.lsp.notify('textDocument/didSave', vim.lsp.protocol.DidSaveTextDocumentParams(), nil, %q, %q)", filetype, server_name);
	})
end

function autocmd.unregister_autocmd(filetype, server_name)
  assert(type(filetype) == 'string', "'filetype' argument is required.")

	lsp_augroup(filetype, server_name, {})
end

return autocmd
