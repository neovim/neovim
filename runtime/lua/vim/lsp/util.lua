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


util.decode_json = function(data)
  return vim.api.nvim_call_function('json_decode', {data})
end

util.encode_json = function(data)
  return vim.api.nvim_call_function('json_encode', {data})
end

util.get_hover_contents_type = function(contents)
  if vim.tbl_islist(contents) == true then
    return 'MarkedString[]'
  elseif type(contents) == 'table' then
    return 'MarkupContent'
  elseif type(contents) == 'string' then
    return 'string'
  else
    return nil
  end
end

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
