local a = vim.api

-- TODO(bfredl): currently we retain parsers for the lifetime of the buffer.
-- Consider use weak references to release parser if all plugins are done with
-- it.
local parsers = {}

local Parser = {}
Parser.__index = Parser

function Parser:parse()
  if self.valid then
    return self.tree
  end
  self.tree = self._parser:parse_buf(self.bufnr)
  self.valid = true
  return self.tree
end

function Parser:_on_lines(bufnr, _, start_row, old_stop_row, stop_row, old_byte_size)
  local start_byte = a.nvim_buf_get_offset(bufnr,start_row)
  local stop_byte = a.nvim_buf_get_offset(bufnr,stop_row)
  local old_stop_byte = start_byte + old_byte_size
  self._parser:edit(start_byte,old_stop_byte,stop_byte,
                    start_row,0,old_stop_row,0,stop_row,0)
  self.valid = false
end

local module = {
  add_language=vim._ts_add_language,
  inspect_language=vim._ts_inspect_language,
}

function module.create_parser(bufnr, ft, id)
  if bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  local self = setmetatable({bufnr=bufnr, valid=false}, Parser)
  self._parser = vim._create_ts_parser(ft)
  self:parse()
    -- TODO(bfredl): use weakref to self, so that the parser is free'd is no plugin is
    -- using it.
  local function lines_cb(_, ...)
    return self:_on_lines(...)
  end
  local detach_cb = nil
  if id ~= nil then
    detach_cb = function()
      if parsers[id] == self then
        parsers[id] = nil
      end
    end
  end
  a.nvim_buf_attach(self.bufnr, false, {on_lines=lines_cb, on_detach=detach_cb})
  return self
end

function module.get_parser(bufnr, ft)
  if bufnr == nil or bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  if ft == nil then
    ft = a.nvim_buf_get_option(bufnr, "filetype")
  end
  local id = tostring(bufnr)..'_'..ft

  if parsers[id] == nil then
    parsers[id] = module.create_parser(bufnr, ft, id)
  end
  return parsers[id]
end

return module
