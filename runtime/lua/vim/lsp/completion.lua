--- Parses snippets in a completion entry.
---
---@param input string unparsed snippet
---@returns string parsed snippet
function M.parse_snippet(input)
  local ok, parsed = pcall(function()
    return tostring(snippet.parse(input))
  end)
  if not ok then
    return input
  end
  return parsed
end


---@private
--- Sorts by CompletionItem.sortText.
---
--see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
local function sort_completion_items(items)
  table.sort(items, function(a, b)
    return (a.sortText or a.label) < (b.sortText or b.label)
  end)
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
      return M.parse_snippet(item.textEdit.newText)
    end
  elseif item.insertText ~= nil and item.insertText ~= "" then
    local insert_text_format = protocol.InsertTextFormat[item.insertTextFormat]
    if insert_text_format == "PlainText" or insert_text_format == nil then
      return item.insertText
    else
      return M.parse_snippet(item.insertText)
    end
  end
  return item.label
end

---@private
--- Some language servers return complementary candidates whose prefixes do not
--- match are also returned. So we exclude completion candidates whose prefix
--- does not match.
local function remove_unmatch_completion_items(items, prefix)
  return vim.tbl_filter(function(item)
    local word = get_completion_word(item)
    return vim.startswith(word, prefix)
  end, items)
end

--- Acording to LSP spec, if the client set `completionItemKind.valueSet`,
--- the client must handle it properly even if it receives a value outside the
--- specification.
---
---@param completion_item_kind (`vim.lsp.protocol.completionItemKind`)
---@returns (`vim.lsp.protocol.completionItemKind`)
---@see https://microsoft.github.io/language-server-protocol/specifications/specification-current/#textDocument_completion
function M._get_completion_item_kind_name(completion_item_kind)
  return protocol.CompletionItemKind[completion_item_kind] or "Unknown"
end

--- Can be used to extract the completion items from a
--- `textDocument/completion` request, which may return one of
--- `CompletionItem[]`, `CompletionList` or null.
---@param result (table) The result of a `textDocument/completion` request
---@returns (table) List of completion items
---@see https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
function M.extract_completion_items(result)
  if type(result) == 'table' and result.items then
    -- result is a `CompletionList`
    return result.items
  elseif result ~= nil then
    -- result is `CompletionItem[]`
    return result
  else
    -- result is `null`
    return {}
  end
end

--- Turns the result of a `textDocument/completion` request into vim-compatible
--- |complete-items|.
---
---@param result The result of a `textDocument/completion` call, e.g. from
---|vim.lsp.buf.completion()|, which may be one of `CompletionItem[]`,
--- `CompletionList` or `null`
---@param prefix (string) the prefix to filter the completion items
---@returns { matches = complete-items table, incomplete = bool }
---@see |complete-items|
function M.text_document_completion_list_to_complete_items(result, prefix)
  local items = M.extract_completion_items(result)
  if vim.tbl_isempty(items) then
    return {}
  end

  items = remove_unmatch_completion_items(items, prefix)
  sort_completion_items(items)

  local matches = {}

  for _, completion_item in ipairs(items) do
    local info = ' '
    local documentation = completion_item.documentation
    if documentation then
      if type(documentation) == 'string' and documentation ~= '' then
        info = documentation
      elseif type(documentation) == 'table' and type(documentation.value) == 'string' then
        info = documentation.value
      -- else
        -- TODO(ashkan) Validation handling here?
      end
    end

    local word = get_completion_word(completion_item)
    table.insert(matches, {
      word = word,
      abbr = completion_item.label,
      kind = M._get_completion_item_kind_name(completion_item.kind),
      menu = completion_item.detail or '',
      info = info,
      icase = 1,
      dup = 1,
      empty = 1,
      user_data = {
        nvim = {
          lsp = {
            completion_item = completion_item
          }
        }
      },
    })
  end

  return matches
end

