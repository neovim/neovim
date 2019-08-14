local CompletionItemKind = require('lsp.protocol').CompletionItemKind

local completion = {}

completion.isCompletionList = function(data)
  if data.items ~= nil then
    return true
  else
    return false
  end
end

completion.getItems = function(data)
  if completion.isCompletionList(data) then
    return data.items
  else
    return data
  end
end

completion.getLabels = function(data)
  local items = completion.getItems(data)

  local result = {}
  for _, completion_item in ipairs(items) do
    table.insert(result, {
      word = completion_item.label,
      kind = completion.map_CompletionItemKind_to_vim(completion_item.kind),
      info = completion_item.detail,
      dup = 0,
    })
  end

  return result
end


completion.map_CompletionItemKind_to_vim = function(item_kind)
  if CompletionItemKind[item_kind - 1] then
    return CompletionItemKind[item_kind - 1]
  else
    return ''
  end
end

return completion
