local util = require('vim.lsp.util')
local CompletionItemKind = require('vim.lsp.protocol').CompletionItemKind

local TextDocument = {}

--- Apply the TextDocumentEdit response.
-- @params TextDocumentEdit [table] see https://microsoft.github.io/language-server-protocol/specification
TextDocument.apply_TextDocumentEdit = function(TextDocumentEdit)
  local text_document = TextDocumentEdit.textDocument

  for _, TextEdit in ipairs(TextDocumentEdit.edits) do
    TextDocument.apply_TextEdit(text_document, TextEdit)
  end
end

--- Apply the TextEdit response.
-- @params TextEdit [table] see https://microsoft.github.io/language-server-protocol/specification
TextDocument.apply_TextEdit = function(TextEdit)
  local range = TextEdit.range

  local range_start = range['start']
  local range_end = range['end']

  local new_text = TextEdit.newText

  if range_start.character ~= 0 or range_end.character ~= 0 then
    vim.api.nvim_err_writeln('apply_TextEdit currently only supports character ranges starting at 0')
    return
  end

  vim.api.nvim_buf_set_lines(0, range_start.line, range_end.line, false, vim.split(new_text, "\n", true))
end

-- textDocument/completion response returns one of CompletionItem[], CompletionList or null.
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
local get_CompletionItems = function(data)
  if util.is_completion_list(data) then
    return data.items
  elseif data ~= nil then
    return data
  else
    return {}
  end
end

local map_CompletionItemKind_to_vim_complete_kind = function(item_kind)
  if CompletionItemKind[item_kind] then
    return CompletionItemKind[item_kind]
  else
    return ''
  end
end

--- Getting vim complete-items with incomplete flag.
-- @params CompletionItem[], CompletionList or nil (https://microsoft.github.io/language-server-protocol/specification#textDocument_completion)
-- @return { matches = complete-items table, incomplete = boolean  }
TextDocument.completion_list_to_matches = function(data)
  local items = get_CompletionItems(data)

  local matches = {}

  for _, completion_item in ipairs(items) do
    table.insert(matches, {
      word = completion_item.label,
      kind = map_CompletionItemKind_to_vim_complete_kind(completion_item.kind),
      menue = completion_item.detail,
      info = completion_item.documentation,
      icase = 1,
      dup = 0,
    })
  end

  return matches
end


return TextDocument
