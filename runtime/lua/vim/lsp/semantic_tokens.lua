local M = {}

-- TODO(smolck): Temporary
local function prinspect(thing)
  print('prinspect', vim.inspect(thing))
end

function M.on_semantic_tokens(...)
  prinspect(...)
end

function M.handle_semantic_tokens_full(client, bufnr, data)
  local legend = client.server_capabilities.semanticTokensProvider.legend
  local token_types = legend.tokenTypes
  local token_modifiers = legend.tokenModifiers

  print('DATA')
  prinspect(data)
end

function M.request_tokens_full(client_id, bufnr)
  local uri = vim.uri_from_bufnr(bufnr or vim.fn.bufnr())
  local params = { textDocument = { uri = uri }; }
  local client = vim.lsp.get_client_by_id(client_id)

  -- TODO(smolck): Not sure what the other params to this are
  local response = client.request('textDocument/semanticTokens/full', params, function(_, _method, data, _, _)
    M.handle_semantic_tokens_full(client, bufnr, data)
  end)
end

function M.on_refresh()
  print('unimplemented')
end

return M
