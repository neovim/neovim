local util = require('vim.lsp.util')
local CompletionItemKind = require('vim.lsp.protocol').CompletionItemKind

local TextDocument = {}
local local_fn = {}

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

--- Getting vim complete-items with incomplete flag.
-- @params CompletionItem[], CompletionList or nil (https://microsoft.github.io/language-server-protocol/specification#textDocument_completion)
-- @return { matches = complete-items table, incomplete = boolean  }
TextDocument.CompletionList_to_matches = function(data)
  local items = local_fn.get_CompletionItems(data)

  local matches = {}

  for _, completion_item in ipairs(items) do
    local info = ' '
    local documentation = completion_item.documentation
    if documentation then
      if type(documentation) == 'string' and documentation ~= '' then
        info = documentation
      elseif type(documentation) == 'table' and type(documentation.value) == 'string' then
        info = documentation.value
      end
    end

    local word
    if completion_item.insertText ~= nil then
      word = completion_item.insertText
    else
      word = completion_item.label
    end

    table.insert(matches, {
      word = local_fn.remove_prefix(word),
      abbr = completion_item.label,
      kind = local_fn.map_CompletionItemKind_to_vim_complete_kind(completion_item.kind) or '',
      menue = completion_item.detail or '',
      info = info,
      icase = 1,
      dup = 0,
      empty = 1,
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

-- textDocument/completion response returns one of CompletionItem[], CompletionList or null.
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
local_fn.get_CompletionItems = function(data)
  if util.is_CompletionList(data) then
    return data.items
  elseif data ~= nil then
    return data
  else
    return {}
  end
end

local_fn.map_CompletionItemKind_to_vim_complete_kind = function(item_kind)
  if CompletionItemKind[item_kind] then
    return CompletionItemKind[item_kind]
  else
    return ''
  end
end

local_fn.remove_prefix = function(word)
  local current_line = vim.api.nvim_call_function(
    'strpart',
    { vim.api.nvim_call_function('getline', { '.' }), 0, vim.api.nvim_call_function('col', { '.' })  - 1 }
  )

  local prefix_length = 0
  local max_prefix_length = vim.api.nvim_call_function('min', { { string.len(word), string.len(current_line) } })
  local word_prefix
  local i = 1

  while i <= max_prefix_length do
    local current_line_suffix = vim.api.nvim_call_function('strpart', { current_line, string.len(current_line) - i, i })
    word_prefix = vim.api.nvim_call_function('strpart', { word, 0, i })
    if current_line_suffix == word_prefix then prefix_length = i end
    i = i + 1
  end

  return vim.api.nvim_call_function('strpart', { word, prefix_length })
end


return TextDocument
