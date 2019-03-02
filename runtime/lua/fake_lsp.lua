local responses = {}
local counter = 1

responses[1] = {
  result = {
      contents = { { value = 'hover_content', language = 'txt' } },
      range = {
        start = { line = 0, character = 0 },
        ['end'] = { line = 0, character = 2 }
      }
    }
  }

local function onEvent(payload)
  local response = responses[counter]
  counter = counter + 1

  if not response or not payload.id then
    return { jsonrpc = '2.0' }
  end

  response.jsonrpc = '2.0'
  response.id = payload.id
  response.counter = counter

  return response
end

-- responses will ahve their 'jsonrpc' and 'id' fields set automatically
-- will be returned by 'onEvent' in order, and nil after that
local function setResponses(new)
  responses = new
end

return {
  onEvent = onEvent,
  setResponses = setResponses
}
