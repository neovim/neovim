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
  if util.is_CompletionList(data) then
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
TextDocument.CompletionList_to_matches = function(data)
  local items = get_CompletionItems(data)

  local matches = {}

  for _, completion_item in ipairs(items) do
    table.insert(matches, {
      word = completion_item.label,
      kind = map_CompletionItemKind_to_vim_complete_kind(completion_item.kind) or '',
      menue = completion_item.detail or '',
      info = completion_item.documentation or '',
      icase = 1,
      dup = 0,
    })
  end

  return matches
end

--- Convert SignatureHelp response to preview contents.
-- https://microsoft.github.io/language-server-protocol/specifications/specification-3-14/#textDocument_signatureHelp
TextDocument.SignatureHelp_to_preview_contents = function(data)
  local contents = {}
  local activeSignature = 1

  if data.activeSignature then activeSignature = data.activeSignature + 1 end
  local signature = data.signatures[activeSignature]

  for _, line in pairs(vim.split(signature.label, '\n')) do
    table.insert(contents, line)
  end

  if not (signature.documentation == nil) then
    if type(signature.documentation) == 'table' then
      for _, line in pairs(vim.split(signature.documentation.value, '\n')) do
        table.insert(contents, line)
      end
    else
      for _, line in pairs(vim.split(signature.documentation, '\n')) do
        table.insert(contents, line)
      end
    end
    table.insert(contents, signature.documentation)
  end

  return contents
end


--- Convert Hover response to preview contents.
-- https://microsoft.github.io/language-server-protocol/specifications/specification-3-14/#textDocument_hover
TextDocument.HoverContents_to_preview_contents = function(data)
  local contents = {}
  local contents_type = util.get_HoverContents_type(data.contents)

  if contents_type == 'MarkedString[]' and not vim.tbl_isempty(data.contents) then
    for _, item in ipairs(data.contents) do
      if type(item) == 'table' then
        table.insert(contents, '```'..item.language)
        for _, line in pairs(vim.split(item.value, '\n')) do
          table.insert(contents, line)
        end
        table.insert(contents, '```')
      elseif item == nil then
        table.insert(contents, '')
      else
        for _, line in pairs(vim.split(item, '\n')) do
          table.insert(contents, line)
        end
      end
    end
  elseif contents_type == 'MarkupContent' and not vim.tbl_isempty(data.contents) then
    -- MarkupContent
    if data.contents.kind ~= nil then
      for _, line in pairs(vim.split(data.contents.value, '\n')) do
        table.insert(contents, line)
      end
    -- { language: string; value: string }
    elseif data.contents.language ~= nil then
      table.insert(contents, '```'..data.contents.language)
      for _, line in pairs(vim.split(data.contents.value, '\n')) do
        table.insert(contents, line)
      end
      table.insert(contents, '```')
    else
      for _, line in pairs(vim.split(data.contents, '\n')) do
        table.insert(contents, line)
      end
    end
  elseif contents_type == 'MarkedString' then
    if data.contents.language then
      table.insert(contents, '```'..data.contents.language)
      for _, line in pairs(vim.split(data.contents.value, '\n')) do
        table.insert(contents, line)
      end
      table.insert(contents, '```')
    elseif data.contents ~= '' then
      for _, line in pairs(vim.split(data.contents, '\n')) do
        table.insert(contents, line)
      end
    end
  end

  if contents[1] == '' or contents[1] == nil then
    table.insert(contents, 'LSP [textDocument/hover]: No information available')
  end

  return contents
end

return TextDocument
