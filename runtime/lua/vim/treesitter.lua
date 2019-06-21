local a = vim.api

local Parser = {}
Parser.__index = Parser

-- TODO(bfredl): currently we retain parsers for the lifetime of the buffer.
-- Consider use weak references to release parser if all plugins are done with
-- it.
local parsers = {}

function Parser:parse()
  if self.valid then
    return self.tree
  end
  self.tree = self._parser:parse_buf(self.bufnr)
  self.valid = true
  return self.tree
end

local function on_lines(self, bufnr, _, start_row, oldstopline, stop_row)
  local start_byte = a.nvim_buf_get_offset(bufnr,start_row)
  -- a bit messy, should we expose edited but not reparsed tree?
  -- are multiple edits safe in general?
  local root = self._parser:tree():root()
  -- TODO: add proper lookup function!
  local inode = root:descendant_for_point_range(oldstopline+9000,0, oldstopline,0)
  if inode == nil then
    local stop_byte = a.nvim_buf_get_offset(bufnr,stop_row)
    self._parser:edit(start_byte,stop_byte,stop_byte,
                      start_row,0,stop_row,0,stop_row,0)
  else
    local fakeoldstoprow, fakeoldstopcol, fakebyteoldstop = inode:start()
    local fake_rows = fakeoldstoprow-oldstopline
    local fakestop = stop_row+fake_rows
    local fakebytestop = a.nvim_buf_get_offset(bufnr,fakestop)+fakeoldstopcol
    self._parser:edit(start_byte, fakebyteoldstop, fakebytestop,
                      start_row, 0,
                      fakeoldstoprow, fakeoldstopcol,
                      fakestop, fakeoldstopcol)
  end
  self.valid = false
end

local function create_parser(bufnr, ft, id)
  if bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  local self = setmetatable({bufnr=bufnr, valid=false}, Parser)
  self._parser = vim._create_ts_parser(ft)
  self:parse()
    -- TODO: use weakref to self, so that the parser is free'd is no plugin is
    -- using it.
  local function lines_cb(_, ...)
    return on_lines(self, ...)
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

local function get_parser(bufnr, ft)
  if bufnr == nil or bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  if ft == nil then
    ft = a.nvim_buf_get_option(bufnr, "filetype")
  end
  local id = tostring(bufnr)..'_'..ft

  if parsers[id] == nil then
    parsers[id] = create_parser(bufnr, ft, id)
  end
  return parsers[id]
end

return {
  get_parser=get_parser,
  create_parser=create_parser,
  add_language=vim._ts_add_language,
  inspect_language=vim._ts_inspect_language,
}
