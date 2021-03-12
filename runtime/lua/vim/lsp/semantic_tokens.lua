local M = {}

local last_tick = {}
local active_requests = {}

---@private
local function get_bit(n, k)
  --todo(theHamsta): remove once `bit` module is available for non-LuaJIT
  if _G.bit then
    return _G.bit.band(_G.bit.rshift(n, k), 1)
  else
    return math.floor((n / math.pow(2, k)) % 2)
  end
end

---@private
local function modifiers_from_number(x, modifiers_table)
  local modifiers = {}
  for i = 0, #modifiers_table - 1 do
    local bit = get_bit(x, i)
    if bit == 1 then
      table.insert(modifiers, 1, modifiers_table[i + 1])
    end
  end

  return modifiers
end

--- |lsp-handler| for the method `textDocument/semanticTokens/full`
---
--- This function can be configured with |vim.lsp.with()| with the following options for `config`
---
--- `on_token`: A function with signature `function(ctx, token)` that is called
---             whenever a semantic token is received from the server from context `ctx`
---             (see |lsp-handler| for the definition of `ctx`). This can be used for highlighting the tokens.
---             `token` is a table:
---
--- <pre>
---   {
---         line             -- line number 0-based
---         start_char       -- start character 0-based (in Unicode characters, not in byte offset as
---                          -- required by most of Neovim's API. Conversion might be needed for further
---                          -- processing!)
---         length           -- length in characters of this token
---         type             -- token type as string (see https://code.visualstudio.com/api/language-extensions/semantic-highlight-guide#semantic-token-classification)
---         modifiers        -- token modifier as string (see https://code.visualstudio.com/api/language-extensions/semantic-highlight-guide#semantic-token-classification)
---         offset_encoding  -- offset encoding used by the language server (see |lsp-sync|)
---   }
--- </pre>
---
--- `on_invalidate_range`: A function with signature `function(ctx, line_start, line_end)` called whenever tokens
---                        in a specific line range (`line_start`, `line_end`) should be considered invalidated
---                        (see |lsp-handler| for the definition of `ctx`). `line_end` can be -1 to
---                        indicate invalidation until the end of the buffer.
function M.on_full(err, response, ctx, config)
  active_requests[ctx.bufnr] = false
  local client = vim.lsp.get_client_by_id(ctx.client_id)
  if not client then
    return
  end
  if config and config.on_invalidate_range then
    config.on_invalidate_range(ctx, 0, -1)
  end
  -- if tick has changed our response is outdated!
  -- FIXME: this is should be done properly here and in the codelens implementation. Handlers should
  -- not be responsible of checking whether their responses are still valid.
  if
    err
    or not response
    or not config.on_token
    or last_tick[ctx.bufnr] ~= vim.api.nvim_buf_get_changedtick(ctx.bufnr)
  then
    return
  end
  local legend = client.server_capabilities.semanticTokensProvider.legend
  local token_types = legend.tokenTypes
  local token_modifiers = legend.tokenModifiers
  local data = response.data

  local line
  local start_char = 0
  for i = 1, #data, 5 do
    local delta_line = data[i]
    line = line and line + delta_line or delta_line
    local delta_start = data[i + 1]
    start_char = delta_line == 0 and start_char + delta_start or delta_start

    -- data[i+3] +1 because Lua tables are 1-indexed
    local token_type = token_types[data[i + 3] + 1]
    local modifiers = modifiers_from_number(data[i + 4], token_modifiers)

    local token = {
      line = line,
      start_char = start_char,
      length = data[i + 2],
      type = token_type,
      modifiers = modifiers,
      offset_encoding = client.offset_encoding,
    }

    if token_type and config and config.on_token then
      config.on_token(ctx, token)
    end
  end
end

--- |lsp-handler| for the method `textDocument/semanticTokens/refresh`
---
function M.on_refresh(err, _, ctx, _)
  if not err then
    for _, bufnr in ipairs(vim.lsp.get_buffers_by_client_id(ctx.client_id)) do
      M.refresh(bufnr)
    end
  end
  return vim.NIL
end

---@private
function M._save_tick(bufnr)
  last_tick[bufnr] = vim.api.nvim_buf_get_changedtick(bufnr)
  active_requests[bufnr] = true
end

--- Refresh the semantic tokens for the current buffer
---
--- It is recommended to trigger this using an autocmd or via keymap.
---
--- <pre>
---   autocmd BufEnter,CursorHold,InsertLeave <buffer> lua require 'vim.lsp.semantic_tokens'.refresh(vim.api.nvim_get_current_buf())
--- </pre>
---
--- @param bufnr number
function M.refresh(bufnr)
  vim.validate({ bufnr = { bufnr, 'number' } })
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  if not active_requests[bufnr] then
    local params = { textDocument = { uri = vim.uri_from_bufnr(bufnr) } }
    if not last_tick[bufnr] or last_tick[bufnr] < vim.api.nvim_buf_get_changedtick(bufnr) then
      M._save_tick(bufnr)
      vim.lsp.buf_request(bufnr, 'textDocument/semanticTokens/full', params)
    end
  end
end

return M
