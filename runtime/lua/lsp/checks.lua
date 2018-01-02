-- add_check('textDocument/completion', false)
-- add_check('textDocument/

local util = require('neovim.util')

local checks_table = {}

local add_check = function(method, callback)
  if checks_table[method] == nil then
    checks_table[method] = {}
  end

  table.insert(checks_table[method], callback)
end

local should_send = function(client, request)
  if checks_table[request.method] == nil then
    return true
  end

  for _, check in ipairs(checks_table[request.method]) do
    if not check then
      return false
    end

    if not check(client, request) then
      return false
    end
  end

  return true
end

-- Base checks
add_check('textDocument/didOpen', function(client, request)
  local uri = util.get_key(request, 'params', 'textDocument', 'uri')

  if type(uri) ~= 'string' then
    return false
  end

  if client.__data__['textDocument/didOpen'] == nil then
    client.__data__['textDocument/didOpen'] = {}
  end

  if client.__data__['textDocument/didOpen'][uri] then
    return false
  end

  client.__data__['textDocument/didOpen'][uri] = true
  return true
end)

-- add_check('textDocument/didChange', function(client, request)
--   local uri = util.get_key(request, 'params', 'textDocument', 'uri')

--   if type(uri) ~= 'string' then
--     return false
--   end

--   if client.__data__['textDocument/didChange'] == nil then
--     client.__data__['textDocument/didChange'] = {}
--   end

return {
  add_check = add_check,
  should_send = should_send,
}
