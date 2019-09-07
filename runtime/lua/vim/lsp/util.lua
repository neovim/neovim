local util = {
  ui = require('vim.lsp.util.ui'),
}

util.get_buffer_text = function(bufnr)
  return table.concat(util.get_buffer_lines(bufnr), '\n')
end

util.get_buffer_lines = function(bufnr)
  return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
end

util.get_filename = function(uri)
  return vim.uri_to_fname(uri)
end

util.get_filetype = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  return vim.api.nvim_buf_get_option(bufnr, 'filetype')
end

---
-- Provide a "strongly typed" dictionary in Lua.
--
-- Does not allow insertion or deletion after creation.
-- Only allows retrieval of created keys are allowed.
util.Enum = {
  new = function(self, map)
    return setmetatable(map, self)
  end,

  __index = function(t, k)
    error("attempt to get unknown enum " .. k .. "from " .. tostring(t), 2)
  end,

  __newindex = function(t, k, v)
    error(
      string.format("attempt to update enum table with %s, %s, %s", t, k, v),
      2)
  end
}

---
-- Provide a map that will continue providing empty map upon access.
--
-- This allows you to do something like:
--  local map =- DefaultMap({a = 'b'})
--  if map.b.a.c.d.e.f.g.i == nil then
--      // Do some error stuff here
--  end
util.DefaultMap = {
  new = function(self, dictionary)
    if dictionary == nil then
      dictionary = {}
    end

    return setmetatable(dictionary, self)
  end,

  __index = function(self, key)
    if rawget(self, key) ~= nil then
      return rawget(self, key)
    end

    return setmetatable({}, self)
  end,
}


return util
