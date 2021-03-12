local M = {}

function M.on_semantic_tokens(...)
  print('on_semantic_tokens', vim.inspect(...))
end

local function modifiers_from_number(x, modifiers_table)
  local function get_bit(n, k)
    -- Based on/from https://stackoverflow.com/a/26230537
    -- (n >> k) & 1
    return bit.band(bit.rshift(n, k), 1)
  end

  local modifiers = {}
  for i = 0, #modifiers_table - 1 do
    local bit = get_bit(x, i)
    if bit == 1 then
      table.insert(modifiers, 1, modifiers_table[i + 1])
    end
  end

  return modifiers
end

local function handle_semantic_tokens_full(client, bufnr, response)
  local legend = client.server_capabilities.semanticTokensProvider.legend
  local token_types = legend.tokenTypes
  local token_modifiers = legend.tokenModifiers
  local data = response.data

  local semantic_tokens = {}
  local prev_line, prev_start = nil, 0
  for i = 1, #data, 5 do
    local delta_line = data[i]
    prev_line = prev_line and prev_line + delta_line or delta_line
    local delta_start = data[i + 1]
    prev_start = delta_line == 0 and prev_start + delta_start or delta_start

    -- data[i+3] +1 because Lua tables are 1-indexed
    local token_type = token_types[data[i + 3] + 1]
    local modifiers = modifiers_from_number(data[i + 4], token_modifiers)

    if delta_line == 0 and semantic_tokens[prev_line + 1] then
      table.insert(semantic_tokens[prev_line + 1], #semantic_tokens, {
        start_char = prev_start,
        length = data[i + 2],
        token_type = token_type,
        token_modifiers = modifiers
      })
    else
      semantic_tokens[prev_line + 1] = {
        {
          start_char = prev_start,
          length = data[i + 2],
          token_type = token_type,
          token_modifiers = modifiers
        }
      }
    end
  end
end

function M.request_tokens_full(client_id, bufnr)
  local uri = vim.uri_from_bufnr(bufnr or vim.fn.bufnr())
  local params = { textDocument = { uri = uri }; }
  local client = vim.lsp.get_client_by_id(client_id)

  -- TODO(smolck): Not sure what the other params to this are/mean
  local handler = function(_, _, response, _, _)
    handle_semantic_tokens_full(client, bufnr, response)
  end
  return client.request('textDocument/semanticTokens/full', params, handler)
end

function M.on_refresh()
  -- TODO(smolck): Unimplemented
end

return M
