-- TODO(tjdevries): Make the metamethods work for __len
--                      I can't seem to get that to work the way I want it to.
local FixList = {}

FixList.new = function(self, set, get, open, close, title)
  local obj = setmetatable({
    list = {},
    title = title or ' ',

    _set = set,
    _get = get,
    _open = open,
    _close = close,
  }, {
    __index = self,
  })

  return obj
end

FixList.add = function(self, line, col, text, filename, message_type)
  table.insert(self.list, {
    lnum = line,
    col = col,
    text = text,
    filename = filename,
    ['type'] = message_type
  })
end

FixList.len = function(self)
  return #(self.list)
end

FixList.set = function(self, ...)
  vim.api.nvim_call_function(self._set, { ... })
end

FixList.get = function(self, what)
  return vim.api.nvim_call_function(self._get, { what })
end

FixList.close = function(self)
  vim.api.nvim_command(self._close)
end

FixList.open = function(self, goto_new_window)
  vim.api.nvim_command(self._open)

  if not goto_new_window then
    vim.api.nvim_command('wincmd p')
  end
end

FixList.is_open = function(_)
  error('FixList.is_open: Not Implemented')
end

return FixList
