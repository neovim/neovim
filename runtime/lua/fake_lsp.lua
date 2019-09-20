local responses = {}
local counter = 1

local function onEvent(payload)
  local response = responses[counter]
  counter = counter + 1

  if not response or not payload.id then
    return { jsonrpc = '1.0' }
  end

  -- allow non-tables to test for garbage responses
  if type(response) == "table" then
    response.jsonrpc = '2.0'
    response.id = payload.id
    response.counter = counter - 1
  end

  return response
end

-- responses will have their 'jsonrpc' and 'id' fields set automatically
-- will be returned by 'onEvent' in order, and nil after that
local function setResponses(new)
  assert(new)
  responses = new.params

  return { jsonrpc = '2.0',  id = new.id, result = responses }
end

return {
  onEvent = onEvent,
  setResponses = setResponses,
}
