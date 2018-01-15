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
      info = completion_item.documentation,
    })
  end

  return result
end


completion.map_CompletionItemKind_to_vim = function(item_kind)
  if item_kind == nil then
    return nil
  end

  if item_kind == CompletionItemKind.Variable then
    return 'v'
  end

  if item_kind == CompletionItemKind.Function then
    return 'f'
  end

  if item_kind == CompletionItemKind.Field
      or item_kind == CompletionItemKind.Property
      then
    return 'm'
  end

end



return completion
