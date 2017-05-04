

local completion = {}

completion.isCompletionList = function(data)
  if data.isIncomplete ~= nil then
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
    table.insert(result, completion_item.label)
  end

  return result
end



return completion
