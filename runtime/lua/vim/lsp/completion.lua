local M = {}
local util = vim.lsp.util
local api = vim.api
local protocol = vim.lsp.protocol


---@private
local function adjust_start_col(lnum, line, items, encoding)
  local min_start_char = nil
  for _, item in pairs(items) do
    if item.filterText == nil and item.textEdit and item.textEdit.range.start.line == lnum - 1 then
      if min_start_char and min_start_char ~= item.textEdit.range.start.character then
        return nil
      end
      min_start_char = item.textEdit.range.start.character
    end
  end
  if min_start_char then
    return util._str_byteindex_enc(line, min_start_char, encoding)
  else
    return nil
  end
end


--- Extract the completion items from a `textDocument/completion` response.
---
---@param result table `CompletionItem[] | CompletionList | null`
---@returns (table) `CompletionItem[]`
---@see https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
function M.get_completion_items(result)
  if type(result) == 'table' and result.items then
    -- result is a `CompletionList`
    return result.items
  else
    -- result is `CompletionItem[] | nil`
    return result or {}
  end
end


---@private
--- Returns text that should be inserted when selecting completion item. The
--- precedence is as follows: textEdit.newText > insertText > label
--see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
local function get_completion_word(item)
  if item.textEdit ~= nil and item.textEdit.newText ~= nil and item.textEdit.newText ~= "" then
    local insert_text_format = protocol.InsertTextFormat[item.insertTextFormat]
    if insert_text_format == "PlainText" or insert_text_format == nil then
      return item.textEdit.newText
    else
      return vim.lsp.util.parse_snippet(item.textEdit.newText)
    end
  elseif item.insertText ~= nil and item.insertText ~= "" then
    local insert_text_format = protocol.InsertTextFormat[item.insertTextFormat]
    if insert_text_format == "PlainText" or insert_text_format == nil then
      return item.insertText
    else
      return vim.lsp.util.parse_snippet(item.insertText)
    end
  end
  return item.label
end


local function prefix_match(prefix)
  return function(item)
    local word = get_completion_word(item)
    return vim.startswith(word, prefix)
  end
end


local function compare_completion_item(a, b)
  return (a.sortText or a.label) < (b.sortText or b.label)
end


--- Convert LSP completion response into |complete-items|.
---
---@param lsp_items table `CompletionItem[] | CompletionList | null`
---@param prefix string prefix used to filter items
---@returns (table) list of |complete-items|
function M.lsp_to_vim_items(lsp_items, prefix)
  local items = M.get_completion_items(lsp_items)
  if vim.tbl_isempty(items) then
    return {}
  end
  items = vim.tbl_filter(prefix_match(prefix), items)
  table.sort(items, compare_completion_item)

  local matches = {}
  for _, item in ipairs(items) do
    local info = ' '
    local documentation = item.documentation
    if documentation then
      if type(documentation) == 'string' and documentation ~= '' then
        info = documentation
      elseif type(documentation) == 'table' and type(documentation.value) == 'string' then
        info = documentation.value
      end
    end
    local word = get_completion_word(item)
    table.insert(matches, {
      word = word,
      abbr = item.label,
      kind = protocol.CompletionItemKind[item.kind] or 'Unknown',
      menu = item.detail or '',
      info = info,
      icase = 1,
      dup = 1,
      empty = 1,
      user_data = {
        nvim = {
          lsp = {
            completion_item = item
          }
        }
      },
    })
  end

  return matches
end


--- Implements 'omnifunc' compatible LSP completion.
---
---@see |complete-functions|
---@see |complete-items|
---@see |CompleteDone|
---
---@param findstart number 0 or 1, decides behavior
---
---@returns (number) Decided by {findstart}:
--- - findstart=0: column where the completion starts, or -2 or -3
--- - findstart=1: list of matches (actually just calls |complete()|)
function M.omnifunc(findstart)
  local bufnr = api.nvim_get_current_buf()
  local clients = vim.lsp.buf_get_clients(bufnr)
  if vim.tbl_isempty(clients) then
    if findstart == 1 then
      return -1
    else
      return {}
    end
  end

  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_get_current_line()
  local line_to_cursor = line:sub(1, pos[2])

  -- Get the start position of the current keyword
  local textMatch = vim.fn.match(line_to_cursor, '\\k*$')

  local params = util.make_position_params()

  local items = {}
  vim.lsp.buf_request(bufnr, 'textDocument/completion', params, function(err, result, ctx)
    if err or not result or vim.fn.mode() ~= "i" then return end

    -- Completion response items may be relative to a position different than `textMatch`.
    -- Concrete example, with sumneko/lua-language-server:
    --
    -- require('plenary.asy|
    --         ▲       ▲   ▲
    --         │       │   └── cursor_pos: 20
    --         │       └────── textMatch: 17
    --         └────────────── textEdit.range.start.character: 9
    --                                 .newText = 'plenary.async'
    --                  ^^^
    --                  prefix (We'd remove everything not starting with `asy`,
    --                  so we'd eliminate the `plenary.async` result
    --
    -- `adjust_start_col` is used to prefer the language server boundary.
    --
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    local encoding = client and client.offset_encoding or 'utf-16'
    local candidates = M.get_completion_items(result)
    local startbyte = adjust_start_col(pos[1], line, candidates, encoding) or textMatch
    local prefix = line:sub(startbyte + 1, pos[2])
    local matches = util.text_document_completion_list_to_complete_items(result, prefix)
    vim.list_extend(items, matches)
    vim.fn.complete(startbyte + 1, items)
  end)

  -- Return -2 to signal that we should continue completion so that we can
  -- async complete.
  return -2
end

return M
