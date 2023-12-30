local M = {}

--- Parse option string based on list type
--- @param str string The option string to parse
--- @param list_type 'comma'|'onecomma'|'commacolon'|'onecommacolon'|'flags'|'flagscomma'
--- @param validator? table Optional validators for keys/values
---
--- @return table? result
function M.parse_list_option(str, list_type, validator)
  if str == '' then
    return {}
  end
  validator = validator or {}
  --- @type table<string, any>
  local result = {}

  --- @type fun():string?
  local iter
  --- @type boolean
  local parse_kv

  if list_type:match('^comma') then
    iter = vim.gsplit(str, ',', { plain = true, trimempty = true })
    parse_kv = list_type:match('colon$') ~= nil
  elseif list_type:match('^flags') then
    local sep = list_type == 'flagscomma' and ',' or ''
    iter = sep == '' and str:gmatch('.') or vim.gsplit(str, sep, { plain = true, trimempty = true })
    parse_kv = false
  else
    return result
  end

  for part in iter do
    if parse_kv then
      local key, value = part:match('^([^:]+):(.+)$')
      if not key then
        return nil
      end

      if validator.parsers then
        if not validator.parsers[key] then
          return result
        end
        --- @type any
        local parsed = validator.parsers[key](value)
        if not parsed then
          return result
        end
        value = parsed
      end

      result[key] = value
    end
  end
  return result
end

--- Parse previewpopup option and return height, width as array
--- @param str string
---
--- @return table<integer, integer>? array with [height, width]
function M.parse_previewpopup_values(str)
  local result = M.parse_list_option(str, 'commacolon', {
    parsers = {
      height = function(v)
        local n = tonumber(v)
        return (n and n >= 1 and math.floor(n) == n) and n or nil
      end,
      width = function(v)
        local n = tonumber(v)
        return (n and n >= 1 and math.floor(n) == n) and n or nil
      end,
    },
  })

  if not result or next(result) == nil then
    error('Invaild argument', 0)
  end

  return { result.height or 0, result.width or 0 }
end

return M
