
local json = {}

-- TODO: Use the FFI module to decode and encode items, since that should be faster

json.decode = function(data)
  return vim.api.nvim_call_function('json_decode', {data})
end
json.encode = function(data)
  return vim.api.nvim_call_function('json_encode', {data})
end

return json
