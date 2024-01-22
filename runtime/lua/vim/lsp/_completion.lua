local M = {}
local api = vim.api
local lsp = vim.lsp
local protocol = lsp.protocol
local ms = protocol.Methods

---@param input string unparsed snippet
---@return string parsed snippet
local function parse_snippet(input)
  local ok, parsed = pcall(function()
    return vim.lsp._snippet_grammar.parse(input)
  end)
  return ok and tostring(parsed) or input
end

--- Returns text that should be inserted when selecting completion item. The
--- precedence is as follows: textEdit.newText > insertText > label
---
--- See https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
---
---@param item lsp.CompletionItem
---@return string
local function get_completion_word(item)
  if item.textEdit ~= nil and item.textEdit.newText ~= nil and item.textEdit.newText ~= '' then
    if item.insertTextFormat == protocol.InsertTextFormat.PlainText then
      return item.textEdit.newText
    else
      return parse_snippet(item.textEdit.newText)
    end
  elseif item.insertText ~= nil and item.insertText ~= '' then
    if item.insertTextFormat == protocol.InsertTextFormat.PlainText then
      return item.insertText
    else
      return parse_snippet(item.insertText)
    end
  end
  return item.label
end

---@param result lsp.CompletionList|lsp.CompletionItem[]
---@return lsp.CompletionItem[]
local function get_items(result)
  if result.items then
    return result.items
  end
  return result
end

--- Turns the result of a `textDocument/completion` request into vim-compatible
--- |complete-items|.
---
---@param result lsp.CompletionList|lsp.CompletionItem[] Result of `textDocument/completion`
---@param prefix string prefix to filter the completion items
---@return table[]
---@see complete-items
function M._lsp_to_complete_items(result, prefix)
  local items = get_items(result)
  if vim.tbl_isempty(items) then
    return {}
  end

  local function matches_prefix(item)
    return vim.startswith(get_completion_word(item), prefix)
  end

  items = vim.tbl_filter(matches_prefix, items) --[[@as lsp.CompletionItem[]|]]
  table.sort(items, function(a, b)
    return (a.sortText or a.label) < (b.sortText or b.label)
  end)

  local matches = {}
  for _, item in ipairs(items) do
    local info = ''
    local documentation = item.documentation
    if documentation then
      if type(documentation) == 'string' and documentation ~= '' then
        info = documentation
      elseif type(documentation) == 'table' and type(documentation.value) == 'string' then
        info = documentation.value
      else
        vim.notify(
          ('invalid documentation value %s'):format(vim.inspect(documentation)),
          vim.log.levels.WARN
        )
      end
    end
    local word = get_completion_word(item)
    table.insert(matches, {
      word = word,
      abbr = item.label,
      kind = protocol.CompletionItemKind[item.kind] or 'Unknown',
      menu = item.detail or '',
      info = #info > 0 and info or nil,
      icase = 1,
      dup = 1,
      empty = 1,
      user_data = {
        nvim = {
          lsp = {
            completion_item = item,
          },
        },
      },
    })
  end
  return matches
end

---@param lnum integer 0-indexed
---@param items lsp.CompletionItem[]
local function adjust_start_col(lnum, line, items, encoding)
  local min_start_char = nil
  for _, item in pairs(items) do
    if item.textEdit and item.textEdit.range.start.line == lnum then
      if min_start_char and min_start_char ~= item.textEdit.range.start.character then
        return nil
      end
      min_start_char = item.textEdit.range.start.character
    end
  end
  if min_start_char then
    return vim.lsp.util._str_byteindex_enc(line, min_start_char, encoding)
  else
    return nil
  end
end

---@private
---@param line string line content
---@param lnum integer 0-indexed line number
---@param client_start_boundary integer 0-indexed word boundary
---@param server_start_boundary? integer 0-indexed word boundary, based on textEdit.range.start.character
---@param result lsp.CompletionList|lsp.CompletionItem[]
---@param encoding string
---@return table[] matches
---@return integer? server_start_boundary
function M._convert_results(
  line,
  lnum,
  cursor_col,
  client_start_boundary,
  server_start_boundary,
  result,
  encoding
)
  -- Completion response items may be relative to a position different than `client_start_boundary`.
  -- Concrete example, with lua-language-server:
  --
  -- require('plenary.asy|
  --         ▲       ▲   ▲
  --         │       │   └── cursor_pos:                     20
  --         │       └────── client_start_boundary:          17
  --         └────────────── textEdit.range.start.character: 9
  --                                 .newText = 'plenary.async'
  --                  ^^^
  --                  prefix (We'd remove everything not starting with `asy`,
  --                  so we'd eliminate the `plenary.async` result
  --
  -- `adjust_start_col` is used to prefer the language server boundary.
  --
  local candidates = get_items(result)
  local curstartbyte = adjust_start_col(lnum, line, candidates, encoding)
  if server_start_boundary == nil then
    server_start_boundary = curstartbyte
  elseif curstartbyte ~= nil and curstartbyte ~= server_start_boundary then
    server_start_boundary = client_start_boundary
  end
  local prefix = line:sub((server_start_boundary or client_start_boundary) + 1, cursor_col)
  local matches = M._lsp_to_complete_items(result, prefix)
  return matches, server_start_boundary
end

---@param findstart integer 0 or 1, decides behavior
---@param base integer findstart=0, text to match against
---@return integer|table Decided by {findstart}:
--- - findstart=0: column where the completion starts, or -2 or -3
--- - findstart=1: list of matches (actually just calls |complete()|)
function M.omnifunc(findstart, base)
  assert(base) -- silence luals
  local bufnr = api.nvim_get_current_buf()
  local clients = lsp.get_clients({ bufnr = bufnr, method = ms.textDocument_completion })
  local remaining = #clients
  if remaining == 0 then
    return findstart == 1 and -1 or {}
  end

  local win = api.nvim_get_current_win()
  local cursor = api.nvim_win_get_cursor(win)
  local lnum = cursor[1] - 1
  local cursor_col = cursor[2]
  local line = api.nvim_get_current_line()
  local line_to_cursor = line:sub(1, cursor_col)
  local client_start_boundary = vim.fn.match(line_to_cursor, '\\k*$') --[[@as integer]]
  local server_start_boundary = nil
  local items = {}

  local function on_done()
    local mode = api.nvim_get_mode()['mode']
    if mode == 'i' or mode == 'ic' then
      vim.fn.complete((server_start_boundary or client_start_boundary) + 1, items)
    end
  end

  local util = vim.lsp.util
  for _, client in ipairs(clients) do
    local params = util.make_position_params(win, client.offset_encoding)
    client.request(ms.textDocument_completion, params, function(err, result)
      if err then
        vim.lsp.log.warn(err.message)
      end
      if result and vim.fn.mode() == 'i' then
        local matches
        matches, server_start_boundary = M._convert_results(
          line,
          lnum,
          cursor_col,
          client_start_boundary,
          server_start_boundary,
          result,
          client.offset_encoding
        )
        vim.list_extend(items, matches)
      end
      remaining = remaining - 1
      if remaining == 0 then
        vim.schedule(on_done)
      end
    end, bufnr)
  end

  -- Return -2 to signal that we should continue completion so that we can
  -- async complete.
  return -2
end

return M
