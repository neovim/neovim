local a = vim.api

local Parser = {}
Parser.__index = Parser

function Parser:parse_tree(force)
  if self.valid and not force then
    return self.tree
  end
  self.tree = self._parser:parse_buf(self.bufnr)
  self.valid = true
  return self.tree
end

local function change_cb(self, ev, bufnr, tick, start_row, oldstopline, stop_row)
  local start_byte = a.nvim_buf_get_offset(bufnr,start_row)
  -- a bit messy, should we expose edited but not reparsed tree?
  -- are multiple edits safe in general?
  local root = self._parser:tree():root()
  -- TODO: add proper lookup function!
  local inode = root:descendant_for_point_range(oldstopline+9000,0, oldstopline,0)
  if inode == nil then
    local stop_byte = a.nvim_buf_get_offset(bufnr,stop_row)
    self._parser:edit(start_byte,stop_byte,stop_byte,start_row,0,stop_row,0,stop_row,0)
  else
    local fakeoldstoprow, fakeoldstopcol, fakebyteoldstop = inode:start()
    local fake_rows = fakeoldstoprow-oldstopline
    local fakestop = stop_row+fake_rows
    local fakebytestop = a.nvim_buf_get_offset(bufnr,fakestop)+fakeoldstopcol
    self._parser:edit(start_byte,fakebyteoldstop,fakebytestop,start_row,0,fakeoldstoprow,fakeoldstopcol,fakestop,fakeoldstopcol)
  end
  self.valid = false
end

local function create_parser(bufnr)
  if bufnr == 0 then
    bufnr = a.nvim_get_current_buf()
  end
  local ft = a.nvim_buf_get_option(bufnr, "filetype")
  local self = setmetatable({bufnr=bufnr, valid=false}, Parser)
  self._parser = vim._create_ts_parser(ft)
  self:parse_tree()
  local function cb(ev, ...)
    -- TODO: use weakref to self, so that the parser is free'd is no plugin is
    -- using it.
    return change_cb(self, ev, ...)
  end
  a.nvim_buf_attach(self.bufnr, false, {on_lines=cb})
  return self
end

-- TODO: weak table with reusable parser per buffer.

return {create_parser=create_parser}

