local CompletionItemKind = require('vim.lsp.protocol').CompletionItemKind

local completion = {}

--- Getting vim complete-items with incomplete flag.
-- @params CompletionItem[], CompletionList or nil (https://microsoft.github.io/language-server-protocol/specification#textDocument_completion)
-- @return { matches = complete-items table, incomplete = boolean  }
completion.getMatches = function(data)
  local items = completion.getItems(data)

  local result = { matches = {}, incomlete = false }

  if completion.isCompletionList(data) then
    result.incomplete = data.isIncomplete
  end

  for _, completion_item in ipairs(items) do
    table.insert(result.matches, {
      word = completion_item.label,
      kind = completion.map_CompletionItemKind_to_vim(completion_item.kind),
      menue = completion_item.detail,
      info = completion_item.documentation,
      icase = 1,
      dup = 0,
    })
  end

  return result
end

completion.isCompletionList = function(data)
  if type(data) == 'table' then
    if data.items then
      return true
    end
  end
  return false
end

-- textDocument/completion response returns one of CompletionItem[], CompletionList or null.
-- https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
completion.getItems = function(data)
  if completion.isCompletionList(data) then
    return data.items
  elseif data ~= nil then
    return data
  else
    return {}
  end
end

completion.map_CompletionItemKind_to_vim = function(item_kind)
  if CompletionItemKind[item_kind] then
    return CompletionItemKind[item_kind]
  else
    return ''
  end
end

return completion
